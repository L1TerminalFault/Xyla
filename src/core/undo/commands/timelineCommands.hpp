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
} // namespace xyla
