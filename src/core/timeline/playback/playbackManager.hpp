#pragma once

#include "core/media/mediaPool.hpp"
#include "core/timeline/timelineTypes.hpp"
#include "project/projectManager.hpp"
#include <QObject>
#include <QTimer>

namespace xyla {

class PlaybackManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(FrameIndex currentFrame READ currentFrame WRITE seekFrame NOTIFY
                 frameChanged)
  Q_PROPERTY(
      double currentTimeSeconds READ currentTimeSeconds NOTIFY frameChanged)
  Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingStateChanged)

public:
  explicit PlaybackManager(ProjectManager *projectManager, MediaPool *mediaPool,
                           QObject *parent = nullptr);
  ~PlaybackManager() override = default;

  [[nodiscard]] FrameIndex currentFrame() const noexcept {
    return m_currentFrame;
  }
  [[nodiscard]] double currentTimeSeconds() const noexcept;
  [[nodiscard]] bool isPlaying() const noexcept { return m_isPlaying; }

public slots:
  void play();
  void pause();
  void togglePlay();
  void seekFrame(FrameIndex frame);
  void stepForward(FrameIndex frames = 1);
  void stepBackward(FrameIndex frames = 1);

signals:
  void frameChanged(FrameIndex frame, double timeSeconds);
  void playingStateChanged(bool isPlaying);

private slots:
  void onPlaybackTick();
  void onActiveProjectChanged();

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};
  QTimer m_playbackTimer;
  FrameIndex m_currentFrame{0};
  bool m_isPlaying{false};
};

} // namespace xyla
