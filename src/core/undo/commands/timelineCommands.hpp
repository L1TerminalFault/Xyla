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

class AddClipCommand : public XylaCommand {
public:
  AddClipCommand(TimelineModel *model, TimelineClip clip, int trackIndex);

  void redo() override;
  void undo() override;
  QString text() const override { return "Add Clip"; }

private:
  TimelineModel *m_model{nullptr};
  TimelineClip m_clip;
  int m_trackIndex{0};
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
                  int64_t newStart, int64_t newDur, int64_t newIn);

  void redo() override;
  void undo() override;
  QString text() const override { return "Trim Clip"; }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  int m_trackIndex{0};
  int64_t m_oldStart{0}, m_oldDur{0}, m_oldIn{0};
  int64_t m_newStart{0}, m_newDur{0}, m_newIn{0};
  QStringList m_selection;
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
                 FrameIndex cutFrame);

  void redo() override;
  void undo() override;
  QString text() const override { return "Cut Clip"; }

private:
  TimelineModel *m_model{nullptr};
  QString m_clipId;
  int m_trackIndex{0};
  FrameIndex m_cutFrame{0};
  QString m_rightClipId;
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
} // namespace xyla
