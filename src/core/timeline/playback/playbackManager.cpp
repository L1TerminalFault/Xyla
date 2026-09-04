#include "playbackManager.hpp"
#include "core/audio/audioEngine.hpp"
#include "core/log/logger.hpp"
#include <algorithm>
#include <cmath>

namespace xyla {

PlaybackManager::PlaybackManager(ProjectManager *projectManager,
                                 MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool) {

  m_lastScrubTime = std::chrono::steady_clock::now();

  m_playbackTimer.setTimerType(Qt::PreciseTimer);
  connect(&m_playbackTimer, &QTimer::timeout, this,
          &PlaybackManager::onPlaybackTick);

  // Auto-stop scrubbing if mouse movement stops for >100ms
  m_scrubTimeoutTimer.setSingleShot(true);
  connect(&m_scrubTimeoutTimer, &QTimer::timeout, this,
          &PlaybackManager::stopScrubbing);

  if (m_projectManager) {
    connect(m_projectManager, &ProjectManager::activeProjectChanged, this,
            &PlaybackManager::onActiveProjectChanged);
  }

  onActiveProjectChanged();
}

double PlaybackManager::currentTimeSeconds() const noexcept {
  FrameIndex cur = m_currentFrame.load(std::memory_order_relaxed);
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj)
      return proj->framesToSeconds(cur);
  }
  return static_cast<double>(cur) / 30.0;
}

void PlaybackManager::startScrubbing() {
  if (m_isPlaying.load(std::memory_order_relaxed)) {
    pause();
  }
  if (!m_isScrubbing.load(std::memory_order_relaxed)) {
    m_isScrubbing.store(true, std::memory_order_relaxed);
    audio::AudioMasterClock::instance().setScrubbing(true);
    m_lastScrubTime = std::chrono::steady_clock::now();
    m_scrubVelocity.store(0.0, std::memory_order_relaxed);
    emit scrubbingStateChanged(true);
  }
}

void PlaybackManager::stopScrubbing() {
  m_scrubTimeoutTimer.stop();
  if (m_isScrubbing.load(std::memory_order_relaxed)) {
    m_isScrubbing.store(false, std::memory_order_relaxed);
    audio::AudioMasterClock::instance().setScrubbing(false);
    m_scrubVelocity.store(0.0, std::memory_order_relaxed);
    emit scrubbingStateChanged(false);

    // Trigger a final PRECISE render pass on target frame upon release/stop
    emit frameChanged(m_currentFrame.load(std::memory_order_relaxed),
                      currentTimeSeconds());
  }
}

void PlaybackManager::scrubToFrame(FrameIndex frame) {
  startScrubbing();
  m_scrubTimeoutTimer.start(100);

  // Calculate real-time scrubbing velocity (frames per second)
  auto now = std::chrono::steady_clock::now();
  double elapsedSec =
      std::chrono::duration<double>(now - m_lastScrubTime).count();
  FrameIndex curFrame = m_currentFrame.load(std::memory_order_relaxed);

  if (elapsedSec > 0.001) {
    double vel = std::abs(static_cast<double>(frame - curFrame)) / elapsedSec;
    m_scrubVelocity.store(vel, std::memory_order_relaxed);
  }
  m_lastScrubTime = now;

  seekFrame(frame);
}

void PlaybackManager::play() {
  if (m_isPlaying.load(std::memory_order_relaxed) &&
      !m_isPlayingReverse.load(std::memory_order_relaxed))
    return;

  m_isScrubbing.store(false, std::memory_order_relaxed);
  m_isPlayingReverse.store(false, std::memory_order_relaxed);
  m_playbackStartTime = std::chrono::high_resolution_clock::now();
  m_startFrame = m_currentFrame.load(std::memory_order_relaxed);
  audio::AudioEngine::instance().setPlaying(true);

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      fps = proj->fps();
    }
  }

  int intervalMs = static_cast<int>(1000.0 / fps);
  m_playbackTimer.setInterval(std::max(1, intervalMs));
  m_playbackTimer.start();

  m_isPlaying.store(true, std::memory_order_relaxed);
  emit playingStateChanged(true);
  XYLA_LOG_INFO("PlaybackManager", "Playback started at 1.0x speed.");
}

void PlaybackManager::playFromStart() {
  pause();
  seekFrame(0);
  play();
}

void PlaybackManager::playReverse() {
  if (m_isPlaying.load(std::memory_order_relaxed) &&
      m_isPlayingReverse.load(std::memory_order_relaxed))
    return;

  m_isScrubbing.store(false, std::memory_order_relaxed);
  m_isPlayingReverse.store(true, std::memory_order_relaxed);
  m_playbackStartTime = std::chrono::high_resolution_clock::now();
  m_startFrame = m_currentFrame.load(std::memory_order_relaxed);

  m_playbackTimer.setInterval(8);
  m_playbackTimer.start();

  m_isPlaying.store(true, std::memory_order_relaxed);
  emit playingStateChanged(true);
  XYLA_LOG_INFO("PlaybackManager", "Playback started reverse at 1.0x speed.");
}

void PlaybackManager::pause() {
  if (!m_isPlaying.load(std::memory_order_relaxed))
    return;

  m_playbackTimer.stop();
  audio::AudioEngine::instance().setPlaying(false);
  m_isPlaying.store(false, std::memory_order_relaxed);
  m_isPlayingReverse.store(false, std::memory_order_relaxed);
  emit playingStateChanged(false);
  XYLA_LOG_INFO("PlaybackManager", "Playback paused.");
}

void PlaybackManager::togglePlay() {
  if (m_isPlaying.load(std::memory_order_relaxed))
    pause();
  else
    play();
}

void PlaybackManager::seekFrame(FrameIndex frame) {
  FrameIndex targetFrame = std::max<FrameIndex>(0, frame);
  FrameIndex curFrame = m_currentFrame.load(std::memory_order_relaxed);

  if (curFrame == targetFrame && !m_isScrubbing.load(std::memory_order_relaxed))
    return;

  m_currentFrame.store(targetFrame, std::memory_order_relaxed);

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  uint32_t sampleRate = audio::AudioEngine::instance().format().sampleRate;
  if (sampleRate == 0)
    sampleRate = 48000;

  // ONLY seek the audio clock if we are PAUSED or SCRUBBING!
  // NEVER fight the audio clock while playing!
  if (!m_isPlaying.load(std::memory_order_relaxed) ||
      m_isScrubbing.load(std::memory_order_relaxed)) {
    int64_t targetSample = static_cast<int64_t>(
        (static_cast<double>(targetFrame) / fps) * sampleRate);
    audio::AudioEngine::instance().seekTimelineSample(targetSample);
  }

  if (m_isPlaying.load(std::memory_order_relaxed)) {
    m_playbackStartTime = std::chrono::high_resolution_clock::now();
    m_startFrame = targetFrame;
  }

  emit frameChanged(targetFrame, currentTimeSeconds());
}

void PlaybackManager::stepForward(FrameIndex frames) {
  stopScrubbing();
  seekFrame(m_currentFrame.load(std::memory_order_relaxed) + frames);
}

void PlaybackManager::stepBackward(FrameIndex frames) {
  stopScrubbing();
  seekFrame(m_currentFrame.load(std::memory_order_relaxed) - frames);
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
  if (!m_isPlaying.load(std::memory_order_relaxed) &&
      !m_isPlayingReverse.load(std::memory_order_relaxed))
    return;

  auto now = std::chrono::high_resolution_clock::now();
  double elapsedSeconds =
      std::chrono::duration<double>(now - m_playbackStartTime).count();

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  int64_t frameDelta = static_cast<int64_t>(elapsedSeconds * fps);

  FrameIndex nextFrame = m_isPlaying.load(std::memory_order_relaxed)
                             ? (m_startFrame + frameDelta)
                             : (m_startFrame - frameDelta);

  FrameIndex curFrame = m_currentFrame.load(std::memory_order_relaxed);

  if (nextFrame != curFrame) {
    FrameIndex finalFrame = std::max<FrameIndex>(0, nextFrame);
    m_currentFrame.store(finalFrame, std::memory_order_relaxed);
    emit frameChanged(finalFrame, currentTimeSeconds());
  }
}

void PlaybackManager::onActiveProjectChanged() {
  pause();
  m_currentFrame.store(0, std::memory_order_relaxed);
  emit frameChanged(0, 0.0);
}

} // namespace xyla
