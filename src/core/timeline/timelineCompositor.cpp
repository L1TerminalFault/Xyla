#include "timelineCompositor.hpp"
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
          // Request the CURRENT playhead frame, never a stale frame
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
  while (true) {
    if (!m_timelineModel) {
      m_renderInProgress.store(false, std::memory_order_release);
      return;
    }

    // Always fetch the latest requested frame
    FrameIndex frameIndex =
        m_latestRequestedFrame.exchange(-1, std::memory_order_acq_rel);
    if (frameIndex < 0 && m_playbackManager) {
      frameIndex = m_playbackManager->currentFrame();
    }

    if (frameIndex < 0) {
      m_renderInProgress.store(false, std::memory_order_release);
      return;
    }

    auto compStart = std::chrono::high_resolution_clock::now();
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
    bool hasVisibleClipsAtPlayhead = false;
    bool waitingForVideoDecoder = false;

    for (int i = trackCount - 1; i >= 0; --i) {
      auto *track = m_timelineModel->getTrack(i);
      if (!track || track->getKind() != TrackKind::Video ||
          track->getIsMuted()) {
        continue;
      }

      auto *clip = track->findClipAtFrame(frameIndex);
      if (clip && !clip->getIsMuted()) {
        hasVisibleClipsAtPlayhead = true;

        FrameIndex timelineSourceFrame =
            clip->getTiming().timelineToSourceFrame(frameIndex);
        FrameIndex localFrame =
            clip->getTiming().timelineToLocalFrame(frameIndex);

        // Vector text
        if (auto *textComp = clip->getComponent<TextComponent>()) {
          VkImageView textRgbaView = VK_NULL_HANDLE;
          if (render::VectorRenderer::instance().renderText(
                  *textComp, localFrame, 1920, 1080, &textRgbaView)) {
            render::RenderLayer layer;
            layer.graph = clip->getNodeGraph();
            layer.yView = VK_NULL_HANDLE;
            layer.uvView = VK_NULL_HANDLE;
            layer.rgbaView = textRgbaView;
            layer.pushConstantValues = clip->getPushConstantValues(localFrame);
            activeLayers.push_back(layer);
          }
          continue;
        }

        // SVG
        if (auto *svgComp = clip->getComponent<SvgComponent>()) {
          VkImageView svgRgbaView = VK_NULL_HANDLE;
          if (render::VectorRenderer::instance().renderSvg(
                  *svgComp, localFrame, 1920, 1080, &svgRgbaView)) {
            render::RenderLayer layer;
            layer.graph = clip->getNodeGraph();
            layer.yView = VK_NULL_HANDLE;
            layer.uvView = VK_NULL_HANDLE;
            layer.rgbaView = svgRgbaView;
            layer.pushConstantValues = clip->getPushConstantValues(localFrame);
            activeLayers.push_back(layer);
          }
          continue;
        }

        // Video
        auto *decoder = dynamic_cast<VulkanVideoDecoder *>(
            m_mediaPool ? m_mediaPool->getDecoder(clip->getAssetId())
                        : nullptr);

        if (decoder) {
          double nativeFps =
              decoder->nativeFps() > 0.0 ? decoder->nativeFps() : 30.0;
          int64_t actualMediaFrame = static_cast<int64_t>(std::floor(
              (static_cast<double>(timelineSourceFrame) * nativeFps) /
              projectFps));

          render::FramePrefetcher::instance().updatePlayhead(
              clip->getAssetId(), actualMediaFrame, m_mediaPool, direction,
              isPlaying, isScrubbing, scrubVelocity);

          auto [yView, uvView] =
              render::VideoFrameCache::instance().getFramePlanes(
                  clip->getAssetId(), actualMediaFrame, decoder, isPlaying,
                  isScrubbing, false, scrubVelocity);

          if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
            render::RenderLayer layer;
            layer.graph = clip->getNodeGraph();
            layer.yView = yView;
            layer.uvView = uvView;
            layer.rgbaView = VK_NULL_HANDLE;
            layer.pushConstantValues = clip->getPushConstantValues(localFrame);
            activeLayers.push_back(layer);
          } else {
            waitingForVideoDecoder = true;
          }
        }
      }
    }

    // Always render so Vulkan swapchain buffers stay in sync!
    if (!waitingForVideoDecoder || !activeLayers.empty()) {
      render::XylaRenderer::instance().renderFrame(activeLayers, 1920, 1080);
      m_lastCompositedFrame = frameIndex;
      m_currentTimelineFrame.store(frameIndex, std::memory_order_release);
      emit frameComposited();
    }

    scratchpad.resetToMarker(marker);

    // Thread-safe termination check:
    // If no new frames were requested during render, exit cleanly.
    if (m_latestRequestedFrame.load(std::memory_order_acquire) < 0) {
      m_hasPendingRequest.store(false, std::memory_order_release);
      m_renderInProgress.store(false, std::memory_order_release);

      // Double-check to prevent race condition between exit and incoming
      // request:
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
