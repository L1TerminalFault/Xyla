#pragma once

#include "core/timeline/timelineClip.hpp"
#include "core/undo/xylaCommand.hpp"
#include <QString>
#include <QStringList>
#include <vector>

namespace xyla {

class TimelineModel;

class MoveClipsCommand : public XylaCommand {
public:
  struct ClipMoveRecord {
    QString clipId;
    int srcTrack;
    int dstTrack;
    int64_t oldStart;
    int64_t newStart;
  };

  MoveClipsCommand(TimelineModel *model, std::vector<ClipMoveRecord> moves);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_moves.size() > 1 ? "Move Clips" : "Move Clip";
  }

private:
  TimelineModel *m_model{nullptr};
  std::vector<ClipMoveRecord> m_moves;
};

class AddClipsCommand : public XylaCommand {
public:
  struct AddClipInfo {
    TimelineClip clip;
    int trackIndex;
  };

  AddClipsCommand(TimelineModel *model, std::vector<AddClipInfo> clips);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_clips.size() > 1 ? "Add Clips" : "Add Clip";
  }

private:
  TimelineModel *model_{nullptr};
  std::vector<AddClipInfo> m_clips;
};

class DeleteClipsCommand : public XylaCommand {
public:
  struct DeletedClipInfo {
    TimelineClip clip;
    int trackIndex;
  };

  DeleteClipsCommand(TimelineModel *model,
                     std::vector<DeletedClipInfo> deletedClips);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_deletedClips.size() > 1 ? "Delete Clips" : "Delete Clip";
  }

private:
  TimelineModel *m_model{nullptr};
  std::vector<DeletedClipInfo> m_deletedClips;
};

class TrimClipCommand : public XylaCommand {
public:
  TrimClipCommand(TimelineModel *model, QString clipId, int trackIndex,
                  int64_t oldStart, int64_t oldDur, int64_t oldIn,
                  int64_t newStart, int64_t newDur, int64_t newIn,
                  bool isRipple, bool global);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_isRipple ? "Ripple Trim Clip" : "Trim Clip";
  }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  int m_trackIndex{0};
  int64_t m_oldStart{0}, m_oldDur{0}, m_oldIn{0};
  int64_t m_newStart{0}, m_newDur{0}, m_newIn{0};
  bool m_isRipple{false};
  bool m_global{false};
  QStringList m_selection;
};

class MultiCutCommand : public XylaCommand {
public:
  struct CutInfo {
    QString id;
    int track;
    FrameIndex frame;
    QString rightId;
    QString rightGroupId;
  };

  MultiCutCommand(TimelineModel *model, std::vector<CutInfo> cuts);

  void redo() override;
  void undo() override;
  QString text() const override { return "Multi Cut"; }

private:
  TimelineModel *m_model{nullptr};
  std::vector<CutInfo> m_cuts;
};

class MultiRippleTrimCommand : public XylaCommand {
public:
  struct TrimAction {
    QString clipId;
    int trackIndex;
    int64_t oldStart, oldDur, oldIn;
    int64_t newStart, newDur, newIn;
  };

  MultiRippleTrimCommand(TimelineModel *model, std::vector<TrimAction> actions,
                         int64_t deltaFrames, bool global);

  void redo() override;
  void undo() override;
  QString text() const override { return "Multi Ripple Trim"; }

private:
  TimelineModel *m_model{nullptr};
  std::vector<TrimAction> m_actions;
  int64_t m_deltaFrames{0};
  bool m_global{false};
};

class SelectClipsCommand : public XylaCommand {
public:
  SelectClipsCommand(TimelineModel *model, QStringList oldSelection,
                     QStringList newSelection);

  void redo() override;
  void undo() override;
  QString text() const override { return "Change Selection"; }
  bool mergeWith(const XylaCommand *other) override;

private:
  TimelineModel *m_model{nullptr};
  QStringList m_oldSelection;
  QStringList m_newSelection;
};

class CutClipCommand : public XylaCommand {
public:
  CutClipCommand(TimelineModel *model, QString clipId, int trackIndex,
                 FrameIndex cutFrame, QString rightGroupId = "",
                 QString rightClipId = "");

  void redo() override;
  void undo() override;
  QString text() const override { return "Cut Clip"; }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  int m_trackIndex{0};
  FrameIndex m_cutFrame{0};
  QString m_rightClipId;
  QString m_rightGroupId;
};

class RippleMoveCommand : public XylaCommand {
public:
  RippleMoveCommand(TimelineModel *model, QString clipId, int srcTrack,
                    int dstTrack, FrameIndex dropFrame, bool global);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_global ? "Global Ripple Move" : "Ripple Move";
  }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  int m_srcTrack{0};
  int m_dstTrack{0};
  FrameIndex m_dropFrame{0};
  bool m_global{false};
  FrameIndex m_originalStart{0};
  QString m_splitClipId;
};

class LockClipCommand : public XylaCommand {
public:
  LockClipCommand(TimelineModel *model, QString clipId, bool locked);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_locked ? "Lock Clip" : "Unlock Clip";
  }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  bool m_locked{false};
};

class LockTrackCommand : public XylaCommand {
public:
  LockTrackCommand(TimelineModel *model, int trackIndex, bool locked);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_locked ? QString("Lock Track %1").arg(m_trackIndex + 1)
                    : QString("Unlock Track %1").arg(m_trackIndex + 1);
  }

private:
  TimelineModel *m_model{nullptr};
  int m_trackIndex{0};
  bool m_locked{false};
};

class LinkClipsCommand : public XylaCommand {
public:
  LinkClipsCommand(TimelineModel *model, QStringList clipIds,
                   QString newGroupId,
                   std::vector<std::pair<QString, QString>> previousGroups);

  void redo() override;
  void undo() override;
  QString text() const override { return "Link Clips"; }

private:
  TimelineModel *m_model{nullptr};
  QStringList m_clipIds;
  QString m_newGroupId;
  std::vector<std::pair<QString, QString>> m_previousGroups;
};

class UnlinkClipsCommand : public XylaCommand {
public:
  UnlinkClipsCommand(TimelineModel *model, QStringList clipIds,
                     std::vector<std::pair<QString, QString>> previousGroups);

  void redo() override;
  void undo() override;
  QString text() const override { return "Unlink Clips"; }

private:
  TimelineModel *m_model{nullptr};
  QStringList m_clipIds;
  std::vector<std::pair<QString, QString>> m_previousGroups;
};

class DeleteKeyframesCommand : public XylaCommand {
public:
  struct KeyframeRecord {
    QString clipId;
    QString propId;
    int64_t absFrame{0};
    int64_t relFrame{0};
    float value{0.0f};
    anim::Interpolation interpolation{anim::Interpolation::Linear};
    anim::BezierHandles bezier{};
  };

  DeleteKeyframesCommand(TimelineModel *model,
                         std::vector<KeyframeRecord> records);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_records.size() > 1 ? "Delete Keyframes" : "Delete Keyframe";
  }

private:
  TimelineModel *m_model{nullptr};
  std::vector<KeyframeRecord> m_records;
};

class MoveKeyframesCommand : public XylaCommand {
public:
  struct MoveRecord {
    QString clipId;
    QString propId;
    int64_t oldAbsFrame{0};
    int64_t newAbsFrame{0};
    int64_t oldRelFrame{0};
    int64_t newRelFrame{0};
  };

  MoveKeyframesCommand(TimelineModel *model, std::vector<MoveRecord> moves);

  void redo() override;
  void undo() override;
  QString text() const override {
    return m_moves.size() > 1 ? "Move Keyframes" : "Move Keyframe";
  }

private:
  TimelineModel *m_model{nullptr};
  std::vector<MoveRecord> m_moves;
};

class PasteKeyframesCommand : public XylaCommand {
public:
  struct KeyRecord {
    QString clipId;
    QString propId;
    int64_t relFrame{0};
    float value{0.0f};
    anim::Interpolation interpolation{anim::Interpolation::Linear};
    anim::BezierHandles bezier{};
  };

  PasteKeyframesCommand(TimelineModel *model, std::vector<KeyRecord> pastedKeys,
                        std::vector<KeyRecord> overwrittenKeys);

  void redo() override;
  void undo() override;
  QString text() const override { return "Paste Keyframes"; }

private:
  TimelineModel *m_model{nullptr};
  std::vector<KeyRecord> m_pastedKeys;
  std::vector<KeyRecord> m_overwrittenKeys;
};

class UpdateKeyframeCommand : public XylaCommand {
public:
  struct KeyframeState {
    int64_t relFrame{0};
    float value{0.0f};
    anim::Interpolation interpolation{anim::Interpolation::Linear};
    anim::BezierHandles bezier{};
  };

  struct Record {
    QString clipId;
    QString propId;
    KeyframeState oldState;
    KeyframeState newState;
  };

  UpdateKeyframeCommand(TimelineModel *model, std::vector<Record> records,
                        const QString &description = "Adjust Keyframe");

  void redo() override;
  void undo() override;
  QString text() const override { return m_description; }

private:
  void applyState(const QString &clipId, const QString &propId,
                  const KeyframeState &from, const KeyframeState &to);

  TimelineModel *m_model{nullptr};
  std::vector<Record> m_records;
  QString m_description;
};

class ThreePointEditCommand : public XylaCommand {
public:
  struct TrackEditRecord {
    int trackIndex;
    std::vector<TimelineClip> beforeClips;
    std::vector<TimelineClip> afterClips;
  };

  ThreePointEditCommand(TimelineModel *model,
                        std::vector<TrackEditRecord> records,
                        const QString &description = "3-Point Edit");

  void redo() override;
  void undo() override;
  QString text() const override { return m_description; }

private:
  TimelineModel *m_model{nullptr};
  std::vector<TrackEditRecord> m_records;
  QString m_description;
};
} // namespace xyla
