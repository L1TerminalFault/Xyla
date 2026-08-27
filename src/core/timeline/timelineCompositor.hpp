#pragma once

#include "core/media/mediaPool.hpp"
#include "playback/playbackManager.hpp"
#include "ui/models/timelineModel.hpp"
#include <QObject>
#include <QVariantList>
#include <atomic>

namespace xyla {

class TimelineCompositor : public QObject {
  Q_OBJECT
  Q_PROPERTY(
      qlonglong cachedStartFrame READ cachedStartFrame NOTIFY cacheRangeChanged)
  Q_PROPERTY(
      qlonglong cachedEndFrame READ cachedEndFrame NOTIFY cacheRangeChanged)
  Q_PROPERTY(
      QVariantList cachedRanges READ cachedRanges NOTIFY cachedRangesChanged)

public:
  explicit TimelineCompositor(PlaybackManager *playbackManager = nullptr,
                              TimelineModel *timelineModel = nullptr,
                              MediaPool *mediaPool = nullptr,
                              QObject *parent = nullptr);
  ~TimelineCompositor() override = default;

  qlonglong cachedStartFrame() const {
    return static_cast<qlonglong>(m_cachedStartFrame);
  }
  qlonglong cachedEndFrame() const {
    return static_cast<qlonglong>(m_cachedEndFrame);
  }
  QVariantList cachedRanges() const { return m_cachedRanges; }

public slots:
  void processPendingRender();

signals:
  void frameComposited();
  void cacheRangeChanged(qlonglong startFrame, qlonglong endFrame);
  void cachedRangesChanged(const QVariantList &ranges);

private slots:
  void onFrameChanged(FrameIndex frameIndex, double timeSeconds);
  void updateTimelineCacheRanges();

private:
  PlaybackManager *m_playbackManager{nullptr};
  TimelineModel *m_timelineModel{nullptr};
  MediaPool *m_mediaPool{nullptr};

  std::atomic<bool> m_renderInProgress{false};
  std::atomic<bool> m_hasPendingRequest{false};
  std::atomic<FrameIndex> m_latestRequestedFrame{-1};
  std::atomic<FrameIndex> m_currentTimelineFrame{-1};

  int64_t m_cachedStartFrame{-1};
  int64_t m_cachedEndFrame{-1};
  QVariantList m_cachedRanges;
};

} // namespace xyla
