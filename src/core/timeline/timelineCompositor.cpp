#include "timelineCompositor.hpp"
#include "core/log/logger.hpp"
#include "core/memory/xylaArena.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/vectorRenderer.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "core/timeline/component/transformComponent.hpp"
#include "project/projectManager.hpp"
#include "ui/models/timelineModel.hpp"

#include <QMetaObject>
#include <cmath>

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
    auto invalidateAndTrigger = [this]() {
      m_lastCompositedFrame = -1;
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    };
    connect(m_timelineModel, &TimelineModel::visualFrameInvalidated, this,
            invalidateAndTrigger);
    connect(m_timelineModel, &QAbstractItemModel::dataChanged, this,
            invalidateAndTrigger);
    connect(m_timelineModel, &QAbstractItemModel::rowsInserted, this,
            invalidateAndTrigger);
  }

  connect(
      &render::VideoFrameCache::instance(),
      &render::VideoFrameCache::frameReady, this,
      [this](const QString &, qint64) {
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

  connect(
      &render::XylaRenderer::instance(),
      &render::XylaRenderer::vulkanContextReady, this,
      [this]() {
        m_lastCompositedFrame = -1;
        const auto targetFrame =
            m_playbackManager ? m_playbackManager->currentFrame() : 0;
        onFrameChanged(targetFrame, 0.0);
      },
      Qt::QueuedConnection);

  connect(&render::VideoFrameCache::instance(),
          &render::VideoFrameCache::cacheRangesUpdated, this,
          &TimelineCompositor::updateTimelineCacheRanges, Qt::QueuedConnection);
}

double TimelineCompositor::getProjectFps() const noexcept {
  if (m_playbackManager && m_playbackManager->projectManager() &&
      m_playbackManager->projectManager()->hasActiveProject()) {
    if (const auto *proj =
            m_playbackManager->projectManager()->activeProject()) {
      if (proj->fps() > 0.0)
        return proj->fps();
    }
  }
  return 30.0;
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
  const auto marker = scratchpad.getMarker();

  const FrameIndex currentTimelineFrame = m_playbackManager->currentFrame();
  const int trackCount = m_timelineModel->rowCount();
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
  const double nativeFps =
      (decoder && decoder->nativeFps() > 0.0) ? decoder->nativeFps() : 30.0;
  const double projectFps = getProjectFps();

  const QVariantList mediaRanges =
      render::VideoFrameCache::instance().getCacheRangesForAsset(
          activeClip->getAssetId());
  QVariantList timelineRanges;
  int64_t overallStart = -1;
  int64_t overallEnd = -1;

  for (const QVariant &item : mediaRanges) {
    const QVariantMap seg = item.toMap();
    const double startSec =
        static_cast<double>(seg[QStringLiteral("start")].toLongLong()) /
        nativeFps;
    const double endSec =
        static_cast<double>(seg[QStringLiteral("end")].toLongLong()) /
        nativeFps;

    const int64_t startTL =
        activeClip->getTiming().startFrame +
        static_cast<int64_t>(std::round(startSec * projectFps)) -
        activeClip->getTiming().sourceInFrame;

    const int64_t endTL =
        activeClip->getTiming().startFrame +
        static_cast<int64_t>(std::round(endSec * projectFps)) -
        activeClip->getTiming().sourceInFrame;

    QVariantMap timelineSeg;
    timelineSeg[QStringLiteral("start")] = static_cast<qlonglong>(startTL);
    timelineSeg[QStringLiteral("end")] = static_cast<qlonglong>(endTL);
    timelineRanges.append(timelineSeg);

    if (overallStart == -1 || startTL < overallStart)
      overallStart = startTL;
    if (overallEnd == -1 || endTL > overallEnd)
      overallEnd = endTL;
  }

  const bool rangesChanged = (m_cachedRanges != timelineRanges);
  m_cachedRanges = timelineRanges;
  m_cachedStartFrame = overallStart;
  m_cachedEndFrame = overallEnd;

  scratchpad.resetToMarker(marker);

  if (rangesChanged) {
    emit cacheRangeChanged(m_cachedStartFrame, m_cachedEndFrame);
    emit cachedRangesChanged(m_cachedRanges);
  }
}

void TimelineCompositor::onFrameChanged(FrameIndex frameIndex, double) {
  const bool isScrubbing =
      m_playbackManager && m_playbackManager->isScrubbing();
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

std::optional<render::RenderLayer>
TimelineCompositor::buildTextLayer(TimelineClip *clip, FrameIndex localFrame) {
  auto *textComp = clip->getComponent<TextComponent>();
  if (!textComp)
    return std::nullopt;

  auto table = m_timelineModel->animationTable();
  if (!table) {
    XYLA_LOG_WARN("TimelineCompositor", "TextClip missing AnimationTable.");
    return std::nullopt;
  }

  VkImageView textRgbaView = VK_NULL_HANDLE;
  if (!render::VectorRenderer::instance().renderText(
          *textComp, *table, localFrame, 1920, 1080, &textRgbaView)) {
    return std::nullopt;
  }

  auto graph = clip->getNodeGraph();
  if (!graph)
    return std::nullopt;

  render::RenderLayer layer;
  layer.graph = graph;
  layer.rgbaView = textRgbaView;
  layer.frame = localFrame;
  layer.animMgr = m_animMgr;
  if (auto *xform = clip->getComponent<TransformComponent>()) {
    layer.transformHandles = xform->handles;
  }
  return layer;
}

std::optional<render::RenderLayer>
TimelineCompositor::buildSvgLayer(TimelineClip *clip, FrameIndex localFrame) {
  auto *svgComp = clip->getComponent<SvgComponent>();
  if (!svgComp)
    return std::nullopt;

  VkImageView svgRgbaView = VK_NULL_HANDLE;
  if (!render::VectorRenderer::instance().renderSvg(*svgComp, localFrame, 1920,
                                                    1080, &svgRgbaView)) {
    return std::nullopt;
  }

  auto graph = clip->getNodeGraph();
  if (!graph)
    return std::nullopt;

  render::RenderLayer layer;
  layer.graph = graph;
  layer.rgbaView = svgRgbaView;
  layer.frame = localFrame;
  layer.animMgr = m_animMgr;
  if (auto *xform = clip->getComponent<TransformComponent>()) {
    layer.transformHandles = xform->handles;
  }
  return layer;
}

std::optional<render::RenderLayer> TimelineCompositor::buildVideoLayer(
    TimelineClip *clip, FrameIndex timelineSourceFrame, FrameIndex localFrame,
    double projectFps, bool isPlaying, bool isScrubbing, int direction,
    double scrubVelocity, bool &outWaitingForDecoder) {

  auto *decoder = dynamic_cast<VulkanVideoDecoder *>(
      m_mediaPool ? m_mediaPool->getDecoder(clip->getAssetId()) : nullptr);
  if (!decoder) {
    XYLA_LOG_WARN("TimelineCompositor",
                  std::format("Decoder not available for asset: {}",
                              clip->getAssetId().toStdString()));
    return std::nullopt;
  }

  const double nativeFps =
      decoder->nativeFps() > 0.0 ? decoder->nativeFps() : 30.0;
  const auto actualMediaFrame = static_cast<int64_t>(std::floor(
      (static_cast<double>(timelineSourceFrame) * nativeFps) / projectFps));

  render::FramePrefetcher::instance().updatePlayhead(
      clip->getAssetId(), actualMediaFrame, m_mediaPool, direction, isPlaying,
      isScrubbing, scrubVelocity);

  auto [yView, uvView] = render::VideoFrameCache::instance().getFramePlanes(
      clip->getAssetId(), actualMediaFrame, decoder, isPlaying, isScrubbing,
      false, scrubVelocity);

  if (yView == VK_NULL_HANDLE || uvView == VK_NULL_HANDLE) {
    outWaitingForDecoder = true;
    return std::nullopt;
  }

  auto graph = clip->getNodeGraph();
  if (!graph)
    return std::nullopt;

  render::RenderLayer layer;
  layer.graph = graph;
  layer.yView = yView;
  layer.uvView = uvView;
  layer.frame = localFrame;
  layer.animMgr = m_animMgr;
  if (auto *xform = clip->getComponent<TransformComponent>()) {
    layer.transformHandles = xform->handles;
  }
  return layer;
}

std::optional<render::RenderLayer> TimelineCompositor::buildLayerForClip(
    TimelineClip *clip, FrameIndex frameIndex, double projectFps,
    bool isPlaying, bool isScrubbing, int direction, double scrubVelocity,
    bool &outWaitingForDecoder) {

  const FrameIndex timelineSourceFrame =
      clip->getTiming().timelineToSourceFrame(frameIndex);
  const FrameIndex localFrame =
      clip->getTiming().timelineToLocalFrame(frameIndex);

  if (clip->hasComponent<TextComponent>()) {
    return buildTextLayer(clip, localFrame);
  }
  if (clip->hasComponent<SvgComponent>()) {
    return buildSvgLayer(clip, localFrame);
  }
  return buildVideoLayer(clip, timelineSourceFrame, localFrame, projectFps,
                         isPlaying, isScrubbing, direction, scrubVelocity,
                         outWaitingForDecoder);
}

void TimelineCompositor::processPendingRender() {
  if (!render::XylaRenderer::instance().isInitialized() ||
      render::XylaRenderer::instance().device() == VK_NULL_HANDLE) {
    m_renderInProgress.store(false, std::memory_order_release);
    XYLA_LOG_WARN("TimelineCompositor",
                  "Vulkan render device is uninitialized.");
    return;
  }

  while (true) {
    if (!m_timelineModel) {
      m_renderInProgress.store(false, std::memory_order_release);
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
    const auto marker = scratchpad.getMarker();

    const double projectFps = getProjectFps();
    const bool isPlaying = m_playbackManager && m_playbackManager->isPlaying();
    const bool isScrubbing =
        m_playbackManager && m_playbackManager->isScrubbing();
    const int direction =
        (m_playbackManager && m_playbackManager->isPlayingReverse()) ? -1 : 1;
    const double scrubVelocity =
        m_playbackManager ? m_playbackManager->scrubVelocity() : 0.0;

    const int trackCount = m_timelineModel->rowCount();
    std::vector<render::RenderLayer> activeLayers;
    bool waitingForVideoDecoder = false;

    render::RenderContext renderCtx =
        render::RenderContext::createFullFrame(1920, 1080, frameIndex, 1.0f);

    for (int i = trackCount - 1; i >= 0; --i) {
      auto *track = m_timelineModel->getTrack(i);
      if (!track || track->getKind() != TrackKind::Video ||
          track->getIsMuted()) {
        continue;
      }

      auto *clip = track->findClipAtFrame(frameIndex);
      if (!clip || clip->getIsMuted()) {
        continue;
      }

      if (auto layer = buildLayerForClip(
              clip, frameIndex, projectFps, isPlaying, isScrubbing, direction,
              scrubVelocity, waitingForVideoDecoder)) {
        activeLayers.push_back(*layer);
      }
    }

    if (!waitingForVideoDecoder || !activeLayers.empty()) {
      render::XylaRenderer::instance().renderFrame(activeLayers, renderCtx);
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
