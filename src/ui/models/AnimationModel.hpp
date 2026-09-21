#pragma once

#include "core/animation/animChannel.hpp"
#include "core/animation/animProperty.hpp"
#include "core/animation/clipboardKeyframe.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineClip.hpp"

#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <vector>

namespace xyla {

class TimelineModel;
class XylaUndoStack;

class AnimationModel : public QObject {
  Q_OBJECT

public:
  explicit AnimationModel(TimelineModel *timelineModel = nullptr,
                          PlaybackManager *playbackManager = nullptr,
                          XylaUndoStack *undoStack = nullptr,
                          QObject *parent = nullptr)
      : QObject(parent), m_timelineModel(timelineModel),
        m_playbackManager(playbackManager), m_undoStack(undoStack) {}
  ~AnimationModel() override = default;

  void setTimelineModel(TimelineModel *model) noexcept {
    m_timelineModel = model;
  }
  void setPlaybackManager(PlaybackManager *manager) noexcept {
    m_playbackManager = manager;
  }
  void setUndoStack(XylaUndoStack *undoStack) noexcept {
    m_undoStack = undoStack;
  }

  // Keyframe Queries
  Q_INVOKABLE float getClipEvaluatedProperty(const QString &clipId,
                                             const QString &propertyId,
                                             int64_t frame) const;

  Q_INVOKABLE bool hasKeyframe(const QString &clipId, const QString &propertyId,
                               int64_t frame) const;

  Q_INVOKABLE QVariantList getClipAnimChannels(const QString &clipId,
                                               int64_t currentFrame) const;

  // Keyframe Editing & Curve Manipulation
  Q_INVOKABLE void toggleKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame,
                                  const QVariant &currentValue);

  Q_INVOKABLE void updateKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t oldFrame,
                                  int64_t newFrame, float newValue, int interp,
                                  float inX, float inY, float outX, float outY);

  Q_INVOKABLE void removeKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame);

  Q_INVOKABLE void removeKeyframes(const QVariantList &keyframeList);

  Q_INVOKABLE void moveKeyframe(const QString &clipId,
                                const QString &propertyId, int64_t oldFrame,
                                int64_t newFrame);

  Q_INVOKABLE void moveKeyframes(const QVariantList &keyframeList,
                                 int64_t deltaFrames);

  void pasteKeyframes(const std::vector<anim::ClipboardKeyframe> &keys,
                      int64_t offset, anim::MergeMode mode);

  // Clip Resolution Helper
  [[nodiscard]] std::vector<TimelineClip *>
  resolveClipsForProperty(const QString &clipId, const QString &propertyId);

  [[nodiscard]] std::vector<const TimelineClip *>
  resolveClipsForProperty(const QString &clipId,
                          const QString &propertyId) const noexcept;

signals:
  void keyframesChanged(const QString &clipId);
  void channelsInvalidated();
  void deleteSelectedKeyframesRequested();
  void copyKeyframesRequested();
  void pasteKeyframesRequested();

private:
  TimelineModel *m_timelineModel{nullptr};
  PlaybackManager *m_playbackManager{nullptr};
  XylaUndoStack *m_undoStack{nullptr};
};

} // namespace xyla
