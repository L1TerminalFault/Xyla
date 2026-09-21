#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/log/logger.hpp"
#include "core/media/mediaPool.hpp"
#include "core/timeline/playback/playbackManager.hpp"

#include <QObject>
#include <QVariantList>
#include <atomic>
#include <qaccessible_base.h>

namespace xyla {

class TimelineCompositor : public QObject {
  Q_OBJECT

  Q_PROPERTY(
      int64_t cachedStartFrame READ cachedStartFrame NOTIFY cacheRangeChanged)
  Q_PROPERTY(
      int64_t cachedEndFrame READ cachedEndFrame NOTIFY cacheRangeChanged)
  Q_PROPERTY(
      QVariantList cachedRanges READ cachedRanges NOTIFY cachedRangesChanged)

public:
  explicit TimelineCompositor(PlaybackManager *playbackManager = nullptr,
                              TimelineModel *timelineModel = nullptr,
                              MediaPool *mediaPool = nullptr,
                              QObject *parent = nullptr);

  ~TimelineCompositor() override = default;

  [[nodiscard]] int64_t cachedStartFrame() const noexcept {
    return m_cachedStartFrame;
  }
  [[nodiscard]] int64_t cachedEndFrame() const noexcept {
    return m_cachedEndFrame;
  }
  [[nodiscard]] QVariantList cachedRanges() const { return m_cachedRanges; }
  void setAnimationManager(anim::AnimationManager *animMgrPtr) {
    if (!animMgrPtr) {
      XYLA_LOG_ERROR(
          "timeline compositor",
          "attempt to set null animation manager to timeline compositor");
    }
    m_animMgr = animMgrPtr;
  }

public slots:
  void onFrameChanged(FrameIndex frameIndex, double timeSeconds);
  void processPendingRender();
  void updateTimelineCacheRanges();

signals:
  void frameComposited();
  void cacheRangeChanged(int64_t startFrame, int64_t endFrame);
  void cachedRangesChanged(const QVariantList &ranges);

private:
  PlaybackManager *m_playbackManager{nullptr};
  TimelineModel *m_timelineModel{nullptr};
  MediaPool *m_mediaPool{nullptr};
  anim::AnimationManager *m_animMgr{nullptr};

  std::atomic<int64_t> m_latestRequestedFrame{-1};
  std::atomic<int64_t> m_currentTimelineFrame{-1};
  int64_t m_lastCompositedFrame{-1};

  std::atomic<bool> m_renderInProgress{false};
  std::atomic<bool> m_hasPendingRequest{false};

  int64_t m_cachedStartFrame{-1};
  int64_t m_cachedEndFrame{-1};
  QVariantList m_cachedRanges;
};

} // namespace xyla
