#include "timelineCompositor.hpp"
#include "core/log/logger.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include <cmath>
#include <vulkan/vulkan.h>

namespace xyla {

// Initializes compositor signals with playback clock
TimelineCompositor::TimelineCompositor(PlaybackManager *playbackManager,
                                       TimelineModel *timelineModel,
                                       MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_playbackManager(playbackManager),
      m_timelineModel(timelineModel), m_mediaPool(mediaPool) {
  if (m_playbackManager) {
    connect(m_playbackManager, &PlaybackManager::frameChanged, this,
            &TimelineCompositor::onFrameChanged, Qt::DirectConnection);
  }
}

// Evaluates active timeline track and triggers GPU compute shader pass
void TimelineCompositor::onFrameChanged(FrameIndex frameIndex,
                                        double timeSeconds) {
  Q_UNUSED(timeSeconds);
  if (!m_timelineModel)
    return;

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
    emit frameComposited();
    return;
  }

  FrameIndex timelineSourceFrame =
      (frameIndex - activeClip->startFrame()) + activeClip->sourceInFrame();

  auto *decoder =
      m_mediaPool ? m_mediaPool->getDecoder(activeClip->assetId()) : nullptr;

  if (!decoder) {
    XYLA_LOG_ERROR("TimelineCompositor",
                   "Decoder instance NULL for assetId: " +
                       activeClip->assetId().toStdString());
    emit frameComposited();
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

  // XYLA_LOG_INFO("TimelineCompositor",
  //               QString("Timeline frame %1 | Clip '%2' | Media frame %3")
  //                   .arg(frameIndex)
  //                   .arg(activeClip->name())
  //                   .arg(actualMediaFrame)
  //                   .toStdString());

  VkImageView srcView = render::VideoFrameCache::instance().getFrame(
      activeClip->assetId(), actualMediaFrame, decoder);

  if (srcView == VK_NULL_HANDLE) {
    XYLA_LOG_WARN("TimelineCompositor",
                  "VideoFrameCache returned VK_NULL_HANDLE for media frame " +
                      std::to_string(actualMediaFrame));
  } else if (!activeClip->nodeGraph()) {
    XYLA_LOG_WARN("TimelineCompositor", "Clip nodeGraph is NULL for clip: " +
                                            activeClip->name().toStdString());
  } else {
    render::XylaRenderer::instance().renderFrame(
        activeClip->nodeGraph(), srcView, 1920, 1080,
        activeClip->pushConstantValues());
  }

  emit frameComposited();
}

} // namespace xyla
