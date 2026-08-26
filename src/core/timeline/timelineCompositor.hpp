#pragma once

#include "core/media/mediaPool.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "ui/models/timelineModel.hpp"
#include <QObject>
#include <atomic>

namespace xyla {

class TimelineCompositor : public QObject {
  Q_OBJECT

  Q_PROPERTY(
      qlonglong cachedStartFrame READ cachedStartFrame NOTIFY cacheRangeChanged)
  Q_PROPERTY(
      qlonglong cachedEndFrame READ cachedEndFrame NOTIFY cacheRangeChanged)

public:
  TimelineCompositor(PlaybackManager *playbackManager,
                     TimelineModel *timelineModel, MediaPool *mediaPool,
                     QObject *parent = nullptr);
  ~TimelineCompositor() override = default;

  [[nodiscard]] qlonglong cachedStartFrame() const noexcept {
    return static_cast<qlonglong>(m_cachedStartFrame);
  }
  [[nodiscard]] qlonglong cachedEndFrame() const noexcept {
    return static_cast<qlonglong>(m_cachedEndFrame);
  }

signals:
  void frameComposited();
  void cacheRangeChanged(qlonglong startFrame, qlonglong endFrame);

private slots:
  void onFrameChanged(FrameIndex frameIndex, double timeSeconds);
  void processPendingRender();

private:
  PlaybackManager *m_playbackManager{nullptr};
  TimelineModel *m_timelineModel{nullptr};
  MediaPool *m_mediaPool{nullptr};

  int64_t m_cachedStartFrame{-1};
  int64_t m_cachedEndFrame{-1};

  std::atomic<FrameIndex> m_latestRequestedFrame{-1};
  std::atomic<FrameIndex> m_currentTimelineFrame{0};
  std::atomic<bool> m_renderInProgress{false};
  std::atomic<bool> m_hasPendingRequest{false};
};

} // namespace xyla
