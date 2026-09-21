#include "timelineCompositor.hpp"
#include "core/log/logger.hpp"
#include "core/memory/xylaArena.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/vectorRenderer.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "project/projectManager.hpp"

#include <QMetaObject>
#include <cmath>
#include <vector>
#include <vulkan/vulkan.h>

namespace xyla {

TimelineCompositor::TimelineCompositor(PlaybackManager *playbackManager,
                                       TimelineModel *timelineModel,
                                       MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_playbackManager(playbackManager),
      m_timelineModel(timelineModel), m_mediaPool(mediaPool) {

  if (m_playbackManager) {
    connect(m_playbackManager, &PlaybackManager::frameChanged, this,
            &TimelineCompositor::onFrameChanged, Qt::QueuedConnection);
  }

  if (m_timelineModel) {
    connect(m_timelineModel, &QAbstractItemModel::dataChanged, this, [this]() {
      m_lastCompositedFrame = -1;
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    });
    connect(m_timelineModel, &QAbstractItemModel::rowsInserted, this, [this]() {
      m_lastCompositedFrame = -1;
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    });
  }

  connect(
      &render::VideoFrameCache::instance(),
      &render::VideoFrameCache::frameReady, this,
      [this](const QString &assetId, qint64 frameIndex) {
        Q_UNUSED(assetId);
        Q_UNUSED(frameIndex);
        if (m_playbackManager) {
          m_latestRequestedFrame.store(m_playbackManager->currentFrame(),
                                       std::memory_order_release);
        }
        m_hasPendingRequest.store(true, std::memory_order_release);
        if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
          QMetaObject::invokeMethod(this,
                                    &TimelineCompositor::processPendingRender,
                                    Qt::QueuedConnection);
        }
      },
      Qt::QueuedConnection);
  // Wake up and render immediately as soon as Qt initializes the Vulkan device!
  connect(
      &render::XylaRenderer::instance(),
      &render::XylaRenderer::vulkanContextReady, this,
      [this]() {
        XYLA_LOG_INFO("TimelineCompositor",
                      "Vulkan context is ready! Requesting initial render.");
        m_lastCompositedFrame = -1;
        if (m_playbackManager) {
          onFrameChanged(m_playbackManager->currentFrame(), 0.0);
        } else {
          onFrameChanged(0, 0.0);
        }
      },
      Qt::QueuedConnection);
  connect(&render::VideoFrameCache::instance(),
          &render::VideoFrameCache::cacheRangesUpdated, this,
          &TimelineCompositor::updateTimelineCacheRanges, Qt::QueuedConnection);
}

void TimelineCompositor::updateTimelineCacheRanges() {
  if (!m_timelineModel || !m_playbackManager) {
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    return;
  }

  auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
  auto marker = scratchpad.getMarker();

  FrameIndex currentTimelineFrame = m_playbackManager->currentFrame();
  int trackCount = m_timelineModel->rowCount();
  TimelineClip *activeClip = nullptr;

  for (int i = 0; i < trackCount; ++i) {
    auto *track = m_timelineModel->getTrack(i);
    if (track && track->getKind() == TrackKind::Video) {
      auto *clip = track->findClipAtFrame(currentTimelineFrame);
      if (clip && !clip->getIsMuted()) {
        activeClip = clip;
        break;
      }
    }
  }

  if (!activeClip) {
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    scratchpad.resetToMarker(marker);

    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    return;
  }

  auto *decoder =
      m_mediaPool ? m_mediaPool->getDecoder(activeClip->getAssetId()) : nullptr;
  double nativeFps =
      (decoder && decoder->nativeFps() > 0.0) ? decoder->nativeFps() : 30.0;

  double projectFps = 30.0;
  if (m_playbackManager->projectManager() &&
      m_playbackManager->projectManager()->hasActiveProject()) {
    if (const auto *proj =
            m_playbackManager->projectManager()->activeProject()) {
      if (proj->fps() > 0.0) {
        projectFps = proj->fps();
      }
    }
  }

  QVariantList mediaRanges =
      render::VideoFrameCache::instance().getCacheRangesForAsset(
          activeClip->getAssetId());

  QVariantList timelineRanges;
  int64_t overallStart = -1;
  int64_t overallEnd = -1;

  for (const QVariant &item : mediaRanges) {
    QVariantMap seg = item.toMap();
    qint64 startMediaFrame = seg["start"].toLongLong();
    qint64 endMediaFrame = seg["end"].toLongLong();

    double startSec = static_cast<double>(startMediaFrame) / nativeFps;
    double endSec = static_cast<double>(endMediaFrame) / nativeFps;

    int64_t startTL = activeClip->getTiming().startFrame +
                      static_cast<int64_t>(std::round(startSec * projectFps)) -
                      activeClip->getTiming().sourceInFrame;

    int64_t endTL = activeClip->getTiming().startFrame +
                    static_cast<int64_t>(std::round(endSec * projectFps)) -
                    activeClip->getTiming().sourceInFrame;

    QVariantMap timelineSeg;
    timelineSeg["start"] = static_cast<qlonglong>(startTL);
    timelineSeg["end"] = static_cast<qlonglong>(endTL);
    timelineRanges.append(timelineSeg);

    if (overallStart == -1 || startTL < overallStart)
      overallStart = startTL;
    if (overallEnd == -1 || endTL > overallEnd)
      overallEnd = endTL;
  }

  bool rangesChanged = (m_cachedRanges != timelineRanges);
  m_cachedRanges = timelineRanges;
  m_cachedStartFrame = overallStart;
  m_cachedEndFrame = overallEnd;

  scratchpad.resetToMarker(marker);

  if (rangesChanged) {
    emit cacheRangeChanged(m_cachedStartFrame, m_cachedEndFrame);
    emit cachedRangesChanged(m_cachedRanges);
  }
}

void TimelineCompositor::onFrameChanged(FrameIndex frameIndex,
                                        double timeSeconds) {
  Q_UNUSED(timeSeconds);

  bool isScrubbing =
      m_playbackManager ? m_playbackManager->isScrubbing() : false;
  if (!isScrubbing) {
    m_lastCompositedFrame = -1;
  }

  m_latestRequestedFrame.store(frameIndex, std::memory_order_release);
  m_hasPendingRequest.store(true, std::memory_order_release);

  if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
    QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                              Qt::QueuedConnection);
  }
}

void TimelineCompositor::processPendingRender() {
  if (!render::XylaRenderer::instance().isInitialized() ||
      render::XylaRenderer::instance().device() == VK_NULL_HANDLE) {
    m_renderInProgress.store(false, std::memory_order_release);
    XYLA_LOG_WARN("TimelineCompositor", "processPendingRender skipped: Vulkan "
                                        "device is uninitialized or null.");
    return;
  }

  while (true) {
    if (!m_timelineModel) {
      m_renderInProgress.store(false, std::memory_order_release);
      XYLA_LOG_WARN("TimelineCompositor",
                    "processPendingRender aborted: m_timelineModel is null.");
      return;
    }

    FrameIndex frameIndex =
        m_latestRequestedFrame.exchange(-1, std::memory_order_acq_rel);
    if (frameIndex < 0 && m_playbackManager) {
      frameIndex = m_playbackManager->currentFrame();
    }

    if (frameIndex < 0) {
      m_renderInProgress.store(false, std::memory_order_release);
      return;
    }

    auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
    auto marker = scratchpad.getMarker();

    double projectFps = 30.0;
    if (m_playbackManager && m_playbackManager->projectManager() &&
        m_playbackManager->projectManager()->hasActiveProject()) {
      if (const auto *proj =
              m_playbackManager->projectManager()->activeProject()) {
        if (proj->fps() > 0.0) {
          projectFps = proj->fps();
        }
      }
    }

    bool isPlaying = m_playbackManager ? m_playbackManager->isPlaying() : false;
    bool isScrubbing =
        m_playbackManager ? m_playbackManager->isScrubbing() : false;
    int direction =
        (m_playbackManager && m_playbackManager->isPlayingReverse()) ? -1 : 1;
    double scrubVelocity =
        m_playbackManager ? m_playbackManager->scrubVelocity() : 0.0;

    int trackCount = m_timelineModel->rowCount();
    std::vector<render::RenderLayer> activeLayers;
    bool waitingForVideoDecoder = false;

    render::RenderContext renderCtx{.width = 1920,
                                    .height = 1080,
                                    .qualityScale = isScrubbing ? 1.0f : 1.0f,
                                    .frame = frameIndex};

    for (int i = trackCount - 1; i >= 0; --i) {
      auto *track = m_timelineModel->getTrack(i);
      if (!track || track->getKind() != TrackKind::Video ||
          track->getIsMuted()) {
        continue;
      }

      auto *clip = track->findClipAtFrame(frameIndex);
      if (clip && !clip->getIsMuted()) {
        FrameIndex timelineSourceFrame =
            clip->getTiming().timelineToSourceFrame(frameIndex);
        FrameIndex localFrame =
            clip->getTiming().timelineToLocalFrame(frameIndex);

        // 1. Vector Text
        if (auto *textComp = clip->getComponent<TextComponent>()) {
          auto table = m_timelineModel->animationTable();
          if (!table) {
            XYLA_LOG_WARN(
                "TimelineCompositor",
                std::format(
                    "TextClip '{}': animationTable is NULL on TimelineModel!",
                    clip->getClipId().toStdString()));
            continue;
          }

          VkImageView textRgbaView = VK_NULL_HANDLE;
          if (!render::VectorRenderer::instance().renderText(
                  *textComp, *table, localFrame, 1920, 1080, &textRgbaView)) {
            XYLA_LOG_WARN(
                "TimelineCompositor",
                std::format("TextClip '{}': VectorRenderer::renderText failed "
                            "at local frame {}.",
                            clip->getClipId().toStdString(), localFrame));
            continue;
          }

          auto graph = clip->getNodeGraph();
          if (!graph) {
            XYLA_LOG_WARN(
                "TimelineCompositor",
                std::format(
                    "TextClip '{}': clip->getNodeGraph() returned null!",
                    clip->getClipId().toStdString()));
            continue;
          }

          render::RenderLayer layer;
          layer.graph = graph;
          layer.yView = VK_NULL_HANDLE;
          layer.uvView = VK_NULL_HANDLE;
          layer.rgbaView = textRgbaView;
          layer.frame = localFrame;
          layer.overrideValues = clip->getPushConstantValues(localFrame);
          activeLayers.push_back(layer);
          continue;
        }

        // 2. SVG
        if (auto *svgComp = clip->getComponent<SvgComponent>()) {
          VkImageView svgRgbaView = VK_NULL_HANDLE;
          if (!render::VectorRenderer::instance().renderSvg(
                  *svgComp, localFrame, 1920, 1080, &svgRgbaView)) {
            XYLA_LOG_WARN("TimelineCompositor",
                          std::format("SvgClip '{}': VectorRenderer::renderSvg "
                                      "failed at local frame {}.",
                                      clip->getClipId().toStdString(),
                                      localFrame));
            continue;
          }

          auto graph = clip->getNodeGraph();
          if (!graph) {
            XYLA_LOG_WARN(
                "TimelineCompositor",
                std::format("SvgClip '{}': clip->getNodeGraph() returned null!",
                            clip->getClipId().toStdString()));
            continue;
          }

          render::RenderLayer layer;
          layer.graph = graph;
          layer.yView = VK_NULL_HANDLE;
          layer.uvView = VK_NULL_HANDLE;
          layer.rgbaView = svgRgbaView;
          layer.frame = localFrame;
          layer.overrideValues = clip->getPushConstantValues(localFrame);
          activeLayers.push_back(layer);
          continue;
        }

        // 3. Video
        auto *decoder = dynamic_cast<VulkanVideoDecoder *>(
            m_mediaPool ? m_mediaPool->getDecoder(clip->getAssetId())
                        : nullptr);

        if (!decoder) {
          XYLA_LOG_WARN(
              "TimelineCompositor",
              std::format("VideoClip '{}': Decoder not found for asset '{}'.",
                          clip->getClipId().toStdString(),
                          clip->getAssetId().toStdString()));
          continue;
        }

        double nativeFps =
            decoder->nativeFps() > 0.0 ? decoder->nativeFps() : 30.0;
        int64_t actualMediaFrame = static_cast<int64_t>(
            std::floor((static_cast<double>(timelineSourceFrame) * nativeFps) /
                       projectFps));

        render::FramePrefetcher::instance().updatePlayhead(
            clip->getAssetId(), actualMediaFrame, m_mediaPool, direction,
            isPlaying, isScrubbing, scrubVelocity);

        auto [yView, uvView] =
            render::VideoFrameCache::instance().getFramePlanes(
                clip->getAssetId(), actualMediaFrame, decoder, isPlaying,
                isScrubbing, false, scrubVelocity);

        if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
          auto graph = clip->getNodeGraph();
          if (!graph) {
            XYLA_LOG_WARN(
                "TimelineCompositor",
                std::format(
                    "VideoClip '{}': clip->getNodeGraph() returned null!",
                    clip->getClipId().toStdString()));
            continue;
          }

          render::RenderLayer layer;
          layer.graph = graph;
          layer.yView = yView;
          layer.uvView = uvView;
          layer.rgbaView = VK_NULL_HANDLE;
          layer.frame = localFrame;
          layer.overrideValues = clip->getPushConstantValues(localFrame);
          activeLayers.push_back(layer);
        } else {
          waitingForVideoDecoder = true;
        }
      }
    }

    if (!waitingForVideoDecoder || !activeLayers.empty()) {
      if (!render::XylaRenderer::instance().renderFrame(activeLayers,
                                                        renderCtx)) {
        XYLA_LOG_WARN(
            "TimelineCompositor",
            std::format("XylaRenderer::renderFrame failed for frame {}.",
                        frameIndex));
      }
      m_lastCompositedFrame = frameIndex;
      m_currentTimelineFrame.store(frameIndex, std::memory_order_release);
      emit frameComposited();
    }

    scratchpad.resetToMarker(marker);

    if (m_latestRequestedFrame.load(std::memory_order_acquire) < 0) {
      m_hasPendingRequest.store(false, std::memory_order_release);
      m_renderInProgress.store(false, std::memory_order_release);

      if (m_latestRequestedFrame.load(std::memory_order_acquire) >= 0) {
        if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
          continue;
        }
      }
      break;
    }
  }
}

} // namespace xyla
