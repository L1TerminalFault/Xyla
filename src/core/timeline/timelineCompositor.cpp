#include "timelineCompositor.hpp"
#include "core/render/FramePrefetcher.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QMetaObject>
#include <cmath>
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
          &render::VideoFrameCache::cacheRangeChanged, this,
          [this](qint64 startMediaFrame, qint64 endMediaFrame) {
            if (startMediaFrame < 0 || endMediaFrame < 0 || !m_timelineModel ||
                !m_playbackManager) {
              m_cachedStartFrame = -1;
              m_cachedEndFrame = -1;
              emit cacheRangeChanged(-1, -1);
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
              emit cacheRangeChanged(-1, -1);
              return;
            }

            auto *decoder = m_mediaPool
                                ? m_mediaPool->getDecoder(activeClip->assetId())
                                : nullptr;
            double nativeFps = decoder ? decoder->nativeFps() : 30.0;
            double projectFps = 30.0;
            if (m_playbackManager->currentTimeSeconds() > 0.0) {
              projectFps = m_playbackManager->currentFrame() /
                           m_playbackManager->currentTimeSeconds();
            }

            double startSec = static_cast<double>(startMediaFrame) /
                              (nativeFps > 0.0 ? nativeFps : 30.0);
            double endSec = static_cast<double>(endMediaFrame) /
                            (nativeFps > 0.0 ? nativeFps : 30.0);

            int64_t startTimelineFrame =
                activeClip->startFrame() +
                static_cast<int64_t>(std::round(
                    startSec * (projectFps > 0.0 ? projectFps : 30.0))) -
                activeClip->sourceInFrame();

            int64_t endTimelineFrame =
                activeClip->startFrame() +
                static_cast<int64_t>(std::round(
                    endSec * (projectFps > 0.0 ? projectFps : 30.0))) -
                activeClip->sourceInFrame();

            m_cachedStartFrame = startTimelineFrame;
            m_cachedEndFrame = endTimelineFrame;
            emit cacheRangeChanged(static_cast<qlonglong>(m_cachedStartFrame),
                                   static_cast<qlonglong>(m_cachedEndFrame));
          });
}

void TimelineCompositor::onFrameChanged(FrameIndex frameIndex,
                                        double timeSeconds) {
  Q_UNUSED(timeSeconds);

  m_currentTimelineFrame.store(frameIndex);
  m_latestRequestedFrame.store(frameIndex);
  m_hasPendingRequest.store(true);

  if (!m_renderInProgress.load()) {
    QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                              Qt::QueuedConnection);
  }
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
    render::XylaRenderer::instance().clearLatestFrame();
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    emit cacheRangeChanged(-1, -1);
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
    emit frameComposited();
    m_renderInProgress.store(false);
    return;
  }

  double projectFps = 30.0;
  if (m_playbackManager && m_playbackManager->currentTimeSeconds() > 0.0) {
    projectFps = m_playbackManager->currentFrame() /
                 m_playbackManager->currentTimeSeconds();
  }

  double nativeFps = decoder->nativeFps();
  double sourceTimeSec = static_cast<double>(timelineSourceFrame) /
                         (projectFps > 0.0 ? projectFps : 30.0);

  int64_t actualMediaFrame = static_cast<int64_t>(
      std::round(sourceTimeSec * (nativeFps > 0.0 ? nativeFps : 30.0)));

  bool isPlaying = m_playbackManager ? m_playbackManager->isPlaying() : false;
  int direction = 1;
  if (m_playbackManager) {
    direction = m_playbackManager->isPlayingReverse() ? -1 : 1;
  }

  // FIX: Pass isPlaying flag to suspend prefetcher during active 1x playback
  render::FramePrefetcher::instance().updatePlayhead(
      activeClip->assetId(), actualMediaFrame, decoder, direction, isPlaying);

  bool allowBlockingDecode = isPlaying;

  auto [yView, uvView] = render::VideoFrameCache::instance().getFramePlanes(
      activeClip->assetId(), actualMediaFrame, decoder, isPlaying,
      allowBlockingDecode);

  if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE &&
      activeClip->nodeGraph()) {
    render::XylaRenderer::instance().renderFrame(
        activeClip->nodeGraph(), yView, uvView, 1920, 1080,
        activeClip->pushConstantValues());
  }

  emit frameComposited();

  m_renderInProgress.store(false);

  if (m_hasPendingRequest.load()) {
    QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                              Qt::QueuedConnection);
  }
}

} // namespace xyla
