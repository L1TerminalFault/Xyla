#pragma once

#include "core/media/mediaPool.hpp"
#include "playback/playbackManager.hpp"
#include "ui/models/timelineModel.hpp"
#include <QObject>

namespace xyla {

class TimelineCompositor : public QObject {
  Q_OBJECT

public:
  explicit TimelineCompositor(PlaybackManager *playbackManager,
                              TimelineModel *timelineModel,
                              MediaPool *mediaPool, QObject *parent = nullptr);
  ~TimelineCompositor() override = default;

public slots:
  void onFrameChanged(FrameIndex frameIndex, double timeSeconds);

signals:
  void frameComposited();

private:
  PlaybackManager *m_playbackManager{nullptr};
  TimelineModel *m_timelineModel{nullptr};
  MediaPool *m_mediaPool{nullptr};
};

} // namespace xyla
