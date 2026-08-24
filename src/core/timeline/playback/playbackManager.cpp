#include "playbackManager.hpp"
#include "core/log/logger.hpp"
#include <algorithm>

namespace xyla {

PlaybackManager::PlaybackManager(ProjectManager *projectManager,
                                 MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool) {
  connect(&m_playbackTimer, &QTimer::timeout, this,
          &PlaybackManager::onPlaybackTick);

  if (m_projectManager) {
    connect(m_projectManager, &ProjectManager::activeProjectChanged, this,
            &PlaybackManager::onActiveProjectChanged);
  }

  onActiveProjectChanged();
}

double PlaybackManager::currentTimeSeconds() const noexcept {
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      return proj->framesToSeconds(m_currentFrame);
  }
  return static_cast<double>(m_currentFrame) / 30.0;
}

void PlaybackManager::play() {
  if (m_isPlaying)
    return;

  onActiveProjectChanged();
  m_playbackTimer.start();
  m_isPlaying = true;
  emit playingStateChanged(m_isPlaying);
  XYLA_LOG_INFO("PlaybackManager", "Playback started.");
}

void PlaybackManager::pause() {
  if (!m_isPlaying)
    return;

  m_playbackTimer.stop();
  m_isPlaying = false;
  emit playingStateChanged(m_isPlaying);
  XYLA_LOG_INFO("PlaybackManager", "Playback paused.");
}

void PlaybackManager::togglePlay() {
  if (m_isPlaying)
    pause();
  else
    play();
}

void PlaybackManager::seekFrame(FrameIndex frame) {
  FrameIndex targetFrame = std::max<FrameIndex>(0, frame);
  if (m_currentFrame == targetFrame)
    return;

  m_currentFrame = targetFrame;
  emit frameChanged(m_currentFrame, currentTimeSeconds());
}

void PlaybackManager::stepForward(FrameIndex frames) {
  seekFrame(m_currentFrame + frames);
}

void PlaybackManager::stepBackward(FrameIndex frames) {
  seekFrame(m_currentFrame - frames);
}

void PlaybackManager::onPlaybackTick() {
  m_currentFrame++;
  emit frameChanged(m_currentFrame, currentTimeSeconds());
}

void PlaybackManager::onActiveProjectChanged() {
  pause();
  m_currentFrame = 0;

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      fps = proj->fps();
  }

  int intervalMs = static_cast<int>(1000.0 / fps);
  m_playbackTimer.setInterval(std::max(1, intervalMs));
  emit frameChanged(0, 0.0);
}

} // namespace xyla
