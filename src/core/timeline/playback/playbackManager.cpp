#include "playbackManager.hpp"
#include "core/log/logger.hpp"
#include <algorithm>

namespace xyla {

PlaybackManager::PlaybackManager(ProjectManager *projectManager,
                                 MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool) {

  // Use high-precision timer
  m_playbackTimer.setTimerType(Qt::PreciseTimer);

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
  if (m_isPlaying && !m_isPlayingReverse)
    return;

  m_isPlayingReverse = false;
  m_playbackStartTime = std::chrono::high_resolution_clock::now();
  m_startFrame = m_currentFrame;

  // Pace timer to target FPS instead of flooding main thread at 120Hz
  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      fps = proj->fps();
    }
  }

  int intervalMs = static_cast<int>(1000.0 / fps);
  m_playbackTimer.setInterval(std::max(1, intervalMs));
  m_playbackTimer.start();

  m_isPlaying = true;
  emit playingStateChanged(m_isPlaying);
}

void PlaybackManager::playFromStart() {
  pause();
  seekFrame(0);
  play();
}

void PlaybackManager::playReverse() {
  if (m_isPlaying && m_isPlayingReverse)
    return;

  m_isPlayingReverse = true;

  // Lock wall-clock start time
  m_playbackStartTime = std::chrono::high_resolution_clock::now();
  m_startFrame = m_currentFrame;

  m_playbackTimer.setInterval(8);
  m_playbackTimer.start();

  m_isPlaying = true;
  emit playingStateChanged(m_isPlaying);
  XYLA_LOG_INFO("PlaybackManager", "Playback started reverse at 1.0x speed.");
}

void PlaybackManager::pause() {
  if (!m_isPlaying)
    return;

  m_playbackTimer.stop();
  m_isPlaying = false;
  m_isPlayingReverse = false;
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

  // Reset wall-clock start reference if seeking while playing
  if (m_isPlaying) {
    m_playbackStartTime = std::chrono::high_resolution_clock::now();
    m_startFrame = m_currentFrame;
  }

  emit frameChanged(m_currentFrame, currentTimeSeconds());
}

void PlaybackManager::stepForward(FrameIndex frames) {
  seekFrame(m_currentFrame + frames);
}

void PlaybackManager::stepBackward(FrameIndex frames) {
  seekFrame(m_currentFrame - frames);
}

void PlaybackManager::jumpForwardSeconds(double seconds) {
  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      fps = proj->fps();
  }
  stepForward(static_cast<FrameIndex>(seconds * fps));
}

void PlaybackManager::jumpBackwardSeconds(double seconds) {
  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      fps = proj->fps();
  }
  stepBackward(static_cast<FrameIndex>(seconds * fps));
}

void PlaybackManager::onPlaybackTick() {
  if (!m_isPlaying && !m_isPlayingReverse)
    return;

  auto now = std::chrono::high_resolution_clock::now();
  double elapsedSeconds =
      std::chrono::duration<double>(now - m_playbackStartTime).count();

  double fps = 30.0; // Get actual project/sequence FPS here
  int64_t frameDelta = static_cast<int64_t>(elapsedSeconds * fps);

  FrameIndex nextFrame =
      m_isPlaying ? (m_startFrame + frameDelta) : (m_startFrame - frameDelta);

  if (nextFrame != m_currentFrame) {
    m_currentFrame = std::max<FrameIndex>(0, nextFrame);

    // CRITICAL: This signal MUST fire on every tick during play!
    emit frameChanged(m_currentFrame, currentTimeSeconds());
  }
}

void PlaybackManager::onActiveProjectChanged() {
  pause();
  m_currentFrame = 0;
  emit frameChanged(0, 0.0);
}

} // namespace xyla
