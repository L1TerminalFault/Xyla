#pragma once

#include "project/projectManager.hpp"
#include <QObject>
#include <QTimer>
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

public:
  explicit PlaybackManager(ProjectManager *projectManager = nullptr,
                           MediaPool *mediaPool = nullptr,
                           QObject *parent = nullptr);
  ~PlaybackManager() override = default;

  [[nodiscard]] FrameIndex currentFrame() const noexcept {
    return m_currentFrame;
  }
  [[nodiscard]] double currentTimeSeconds() const noexcept;
  [[nodiscard]] bool isPlaying() const noexcept { return m_isPlaying; }
  [[nodiscard]] bool isPlayingReverse() const noexcept {
    return m_isPlayingReverse;
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

signals:
  void frameChanged(FrameIndex frame, double timeSeconds);
  void playingStateChanged(bool isPlaying);

private slots:
  void onPlaybackTick();
  void onActiveProjectChanged();

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};

  FrameIndex m_currentFrame{0};
  bool m_isPlaying{false};
  bool m_isPlayingReverse{false};

  QTimer m_playbackTimer;

  // Wall-Clock Time Tracking for 100% Accurate 1.0x Playback Speed
  std::chrono::high_resolution_clock::time_point m_playbackStartTime;
  FrameIndex m_startFrame{0};
};

} // namespace xyla
