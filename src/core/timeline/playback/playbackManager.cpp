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

  // Lock wall-clock start time
  m_playbackStartTime = std::chrono::high_resolution_clock::now();
  m_startFrame = m_currentFrame;

  m_playbackTimer.setInterval(8); // High frequency tick (~120Hz)
  m_playbackTimer.start();

  m_isPlaying = true;
  emit playingStateChanged(m_isPlaying);
  XYLA_LOG_INFO("PlaybackManager", "Playback started forward at 1.0x speed.");
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

// FIX: Wall-Clock Synchronized Playback Tick (Guarantees exact 1.0x speed)
void PlaybackManager::onPlaybackTick() {
  if (!m_isPlaying)
    return;

  auto now = std::chrono::high_resolution_clock::now();
  double elapsedSec =
      std::chrono::duration<double>(now - m_playbackStartTime).count();

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      fps = proj->fps();
  }

  FrameIndex elapsedFrames =
      static_cast<FrameIndex>(std::round(elapsedSec * fps));

  FrameIndex targetFrame = 0;
  if (m_isPlayingReverse) {
    targetFrame = std::max<FrameIndex>(0, m_startFrame - elapsedFrames);
    if (targetFrame == 0 && m_startFrame <= elapsedFrames) {
      pause();
    }
  } else {
    targetFrame = m_startFrame + elapsedFrames;
  }

  if (m_currentFrame != targetFrame) {
    m_currentFrame = targetFrame;
    emit frameChanged(m_currentFrame, currentTimeSeconds());
  }
}

void PlaybackManager::onActiveProjectChanged() {
  pause();
  m_currentFrame = 0;
  emit frameChanged(0, 0.0);
}

} // namespace xyla
