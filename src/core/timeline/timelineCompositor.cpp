#include "timelineCompositor.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "project/projectManager.hpp"
#include <QMetaObject>
#include <cmath>
#include <qdebug.h>
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
    // Re-trigger render when clips are added, moved, or dropped on timeline
    connect(m_timelineModel, &QAbstractItemModel::dataChanged, this, [this]() {
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    });
    connect(m_timelineModel, &QAbstractItemModel::rowsInserted, this, [this]() {
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
        if (!m_renderInProgress.load()) {
          m_hasPendingRequest.store(true);
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

  FrameIndex currentTimelineFrame = m_playbackManager->currentFrame();
  int trackCount = m_timelineModel->rowCount();
  TimelineClip *activeClip = nullptr;

  for (int i = 0; i < trackCount; ++i) {
    auto *track = m_timelineModel->getTrack(i);
    if (track && track->kind() == TrackKind::Video) {
      auto *clip = track->findClipAtFrame(currentTimelineFrame);
      if (clip && !clip->isMuted()) {
        activeClip = clip;
        break;
      }
    }
  }

  if (!activeClip) {
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    return;
  }

  auto *decoder =
      m_mediaPool ? m_mediaPool->getDecoder(activeClip->assetId()) : nullptr;
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
          activeClip->assetId());

  QVariantList timelineRanges;
  int64_t overallStart = -1;
  int64_t overallEnd = -1;

  for (const QVariant &item : mediaRanges) {
    QVariantMap seg = item.toMap();
    qint64 startMediaFrame = seg["start"].toLongLong();
    qint64 endMediaFrame = seg["end"].toLongLong();

    double startSec = static_cast<double>(startMediaFrame) / nativeFps;
    double endSec = static_cast<double>(endMediaFrame) / nativeFps;

    int64_t startTL = activeClip->startFrame() +
                      static_cast<int64_t>(std::round(startSec * projectFps)) -
                      activeClip->sourceInFrame();

    int64_t endTL = activeClip->startFrame() +
                    static_cast<int64_t>(std::round(endSec * projectFps)) -
                    activeClip->sourceInFrame();

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

  if (rangesChanged) {
    emit cacheRangeChanged(m_cachedStartFrame, m_cachedEndFrame);
    emit cachedRangesChanged(m_cachedRanges);
  }
}

void TimelineCompositor::onFrameChanged(FrameIndex frameIndex,
                                        double timeSeconds) {
  Q_UNUSED(timeSeconds);
  m_latestRequestedFrame.store(frameIndex);
  m_hasPendingRequest.store(true);
  processPendingRender();
}

void TimelineCompositor::processPendingRender() {
  if (!m_timelineModel)
    return;

  m_renderInProgress.store(true);

  FrameIndex frameIndex = m_latestRequestedFrame.exchange(-1);
  if (frameIndex < 0) {
    frameIndex = m_currentTimelineFrame.load();
  }
  m_hasPendingRequest.store(false);

  if (frameIndex < 0) {
    m_renderInProgress.store(false);
    return;
  }

  // --- DEDUPLICATION CHECK: Skip redundant render passes on identical frames
  // ---
  if (frameIndex == m_lastCompositedFrame && !m_hasPendingRequest.load()) {
    m_renderInProgress.store(false);
    return;
  }
  m_lastCompositedFrame = frameIndex;
  m_currentTimelineFrame.store(frameIndex);

  auto totalStart = std::chrono::high_resolution_clock::now();

  // STAGE 1: Model Track & Clip Lookup
  ScopedStageTimer stage1Timer("1. Clip Lookup");
  int trackCount = m_timelineModel->rowCount();
  TimelineClip *activeClip = nullptr;

  for (int i = 0; i < trackCount; ++i) {
    auto *track = m_timelineModel->getTrack(i);
    if (track && track->kind() == TrackKind::Video) {
      auto *clip = track->findClipAtFrame(frameIndex);
      if (clip && !clip->isMuted()) {
        activeClip = clip;
        break;
      }
    }
  }

  if (!activeClip) {
    qDebug().noquote() << QString("[Compositor] No active clip on track at "
                                  "timeline frame %1 (Track count: %2)")
                              .arg(frameIndex)
                              .arg(trackCount);

    render::XylaRenderer::instance().clearLatestFrame();
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    emit frameComposited();

    m_renderInProgress.store(false);
    if (m_hasPendingRequest.load()) {
      QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                                Qt::QueuedConnection);
    }
    return;
  }

  FrameIndex timelineSourceFrame =
      (frameIndex - activeClip->startFrame()) + activeClip->sourceInFrame();

  auto *decoder = dynamic_cast<VulkanVideoDecoder *>(
      m_mediaPool ? m_mediaPool->getDecoder(activeClip->assetId()) : nullptr);

  if (!decoder) {
    qDebug().noquote() << QString(
                              "[Compositor] Decoder not found for asset ID %1")
                              .arg(activeClip->assetId());
    emit frameComposited();
    m_renderInProgress.store(false);
    return;
  }

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

  double nativeFps = decoder->nativeFps();
  if (nativeFps <= 0.0)
    nativeFps = 30.0;
  if (projectFps <= 0.0)
    projectFps = 30.0;

  int64_t actualMediaFrame = static_cast<int64_t>(std::floor(
      (static_cast<double>(timelineSourceFrame) * nativeFps) / projectFps));

  bool isPlaying = m_playbackManager ? m_playbackManager->isPlaying() : false;
  bool isScrubbing =
      m_playbackManager ? m_playbackManager->isScrubbing() : false;

  int direction = 1;
  if (m_playbackManager) {
    direction = m_playbackManager->isPlayingReverse() ? -1 : 1;
  }

  render::FramePrefetcher::instance().updatePlayhead(
      activeClip->assetId(), actualMediaFrame, decoder, direction, isPlaying,
      isScrubbing);

  double stage1Ms = stage1Timer.elapsedMs();

  // STAGE 2: FFmpeg HW Decode & Vulkan VRAM Cache
  ScopedStageTimer stage2Timer("2. Decode & VRAM Cache");
  auto [yView, uvView] = render::VideoFrameCache::instance().getFramePlanes(
      activeClip->assetId(), actualMediaFrame, decoder, isPlaying, isScrubbing);
  double stage2Ms = stage2Timer.elapsedMs();

  // STAGE 3: Vulkan Compute Shader Dispatch
  double stage3Ms = 0.0;
  if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
    ScopedStageTimer stage3Timer("3. Compute Dispatch");
    render::XylaRenderer::instance().renderFrame(
        activeClip->nodeGraph(), yView, uvView, 1920, 1080,
        activeClip->pushConstantValues());
    stage3Ms = stage3Timer.elapsedMs();
  } else {
    qDebug().noquote()
        << QString("[Compositor] YUV texture views null for media frame %1")
               .arg(actualMediaFrame);
  }

  emit frameComposited();
  m_renderInProgress.store(false);

  auto totalEnd = std::chrono::high_resolution_clock::now();
  double totalMs =
      std::chrono::duration<double, std::milli>(totalEnd - totalStart).count();

  if (isScrubbing || totalMs > 2.0) {
    qDebug().noquote()
        << QString("[ScrubProfiler] Frame: %1 | Total: %2ms | [Lookup: %3ms | "
                   "Decode/Cache: %4ms | Render: %5ms]")
               .arg(frameIndex, 5)
               .arg(totalMs, 6, 'f', 2)
               .arg(stage1Ms, 5, 'f', 2)
               .arg(stage2Ms, 5, 'f', 2)
               .arg(stage3Ms, 5, 'f', 2);
  }

  if (m_hasPendingRequest.load()) {
    QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                              Qt::QueuedConnection);
  }
}

} // namespace xyla
