#pragma once

#include "project/projectManager.hpp"
#include <QObject>
#include <QTimer>
#include <atomic>
#include <chrono>

namespace xyla {

class MediaPool;

using FrameIndex = int64_t;

class PlaybackManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(FrameIndex currentFrame READ currentFrame WRITE seekFrame NOTIFY
                 frameChanged)
  Q_PROPERTY(
      double currentTimeSeconds READ currentTimeSeconds NOTIFY frameChanged)
  Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingStateChanged)
  Q_PROPERTY(
      bool isPlayingReverse READ isPlayingReverse NOTIFY playingStateChanged)
  Q_PROPERTY(bool isScrubbing READ isScrubbing NOTIFY scrubbingStateChanged)

public:
  explicit PlaybackManager(ProjectManager *projectManager = nullptr,
                           MediaPool *mediaPool = nullptr,
                           QObject *parent = nullptr);
  ~PlaybackManager() override = default;

  [[nodiscard]] ProjectManager *projectManager() const noexcept {
    return m_projectManager;
  }

  [[nodiscard]] FrameIndex currentFrame() const noexcept {
    return m_currentFrame.load(std::memory_order_relaxed);
  }
  [[nodiscard]] double currentTimeSeconds() const noexcept;
  [[nodiscard]] bool isPlaying() const noexcept {
    return m_isPlaying.load(std::memory_order_relaxed);
  }
  [[nodiscard]] bool isPlayingReverse() const noexcept {
    return m_isPlayingReverse.load(std::memory_order_relaxed);
  }
  [[nodiscard]] bool isScrubbing() const noexcept {
    return m_isScrubbing.load(std::memory_order_relaxed);
  }
  [[nodiscard]] double scrubVelocity() const noexcept {
    return m_scrubVelocity.load(std::memory_order_relaxed);
  }

  Q_INVOKABLE void play();
  Q_INVOKABLE void playFromStart();
  Q_INVOKABLE void playReverse();
  Q_INVOKABLE void pause();
  Q_INVOKABLE void togglePlay();
  Q_INVOKABLE void seekFrame(FrameIndex frame);
  Q_INVOKABLE void stepForward(FrameIndex frames = 1);
  Q_INVOKABLE void stepBackward(FrameIndex frames = 1);
  Q_INVOKABLE void jumpForwardSeconds(double seconds = 5.0);
  Q_INVOKABLE void jumpBackwardSeconds(double seconds = 5.0);

  // Scrubbing API
  Q_INVOKABLE void startScrubbing();
  Q_INVOKABLE void stopScrubbing();
  Q_INVOKABLE void scrubToFrame(FrameIndex frame);

signals:
  void frameChanged(FrameIndex frame, double timeSeconds);
  void playingStateChanged(bool isPlaying);
  void scrubbingStateChanged(bool isScrubbing);

private slots:
  void onPlaybackTick();
  void onActiveProjectChanged();

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};

  // Atomic state flags for thread-safe cross-thread reads
  std::atomic<FrameIndex> m_currentFrame{0};
  std::atomic<bool> m_isPlaying{false};
  std::atomic<bool> m_isPlayingReverse{false};
  std::atomic<bool> m_isScrubbing{false};

  // Real-time playhead velocity calculation
  std::atomic<double> m_scrubVelocity{0.0};
  std::chrono::steady_clock::time_point m_lastScrubTime;

  QTimer m_playbackTimer;
  QTimer m_scrubTimeoutTimer;

  std::chrono::high_resolution_clock::time_point m_playbackStartTime;
  FrameIndex m_startFrame{0};
};

} // namespace xyla
