#include "timelineCommands.hpp"
#include "ui/models/timelineModel.hpp"

namespace xyla {

// 1. Move Clips
MoveClipsCommand::MoveClipsCommand(TimelineModel *model,
                                   std::vector<ClipMoveRecord> moves)
    : m_model(model), m_moves(std::move(moves)) {}

void MoveClipsCommand::redo() {
  if (!m_model)
    return;
  QStringList movedIds;
  for (const auto &m : m_moves) {
    m_model->applyDirectMove(m.clipId, m.srcTrack, m.dstTrack, m.newStart);
    movedIds.append(m.clipId);
  }
  m_model->applyDirectSelection(movedIds);
}

void MoveClipsCommand::undo() {
  if (!m_model)
    return;
  QStringList movedIds;
  for (const auto &m : m_moves) {
    m_model->applyDirectMove(m.clipId, m.dstTrack, m.srcTrack, m.oldStart);
    movedIds.append(m.clipId);
  }
  m_model->applyDirectSelection(movedIds);
}

// 2. Add Clip
AddClipCommand::AddClipCommand(TimelineModel *model, TimelineClip clip,
                               int trackIndex)
    : m_model(model), m_clip(std::move(clip)), m_trackIndex(trackIndex) {}

void AddClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectAdd(m_clip, m_trackIndex);
  m_model->applyDirectSelection({m_clip.clipId()});
}

void AddClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectRemove(m_clip.clipId(), m_trackIndex);
  m_model->applyDirectSelection({});
}

// 3. Delete Clips
DeleteClipsCommand::DeleteClipsCommand(
    TimelineModel *model, std::vector<DeletedClipInfo> deletedClips)
    : m_model(model), m_deletedClips(std::move(deletedClips)) {}

void DeleteClipsCommand::redo() {
  if (!m_model)
    return;
  for (const auto &info : m_deletedClips) {
    m_model->applyDirectRemove(info.clip.clipId(), info.trackIndex);
  }
  m_model->applyDirectSelection({});
}

void DeleteClipsCommand::undo() {
  if (!m_model)
    return;
  QStringList restoredIds;
  for (const auto &info : m_deletedClips) {
    m_model->applyDirectAdd(info.clip, info.trackIndex);
    restoredIds.append(info.clip.clipId());
  }
  // Re-select restored clips on undo
  m_model->applyDirectSelection(restoredIds);
}

// 4. Trim Clip
TrimClipCommand::TrimClipCommand(TimelineModel *model, QString clipId,
                                 int trackIndex, int64_t oldStart,
                                 int64_t oldDur, int64_t oldIn,
                                 int64_t newStart, int64_t newDur,
                                 int64_t newIn)
    : m_model(model), m_clipId(std::move(clipId)), m_trackIndex(trackIndex),
      m_oldStart(oldStart), m_oldDur(oldDur), m_oldIn(oldIn),
      m_newStart(newStart), m_newDur(newDur), m_newIn(newIn) {}

void TrimClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_newStart, m_newDur,
                           m_newIn);
  m_model->applyDirectSelection({m_clipId});
}

void TrimClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_oldStart, m_oldDur,
                           m_oldIn);
  m_model->applyDirectSelection({m_clipId});
}

// 5. Select Clips
SelectClipsCommand::SelectClipsCommand(TimelineModel *model,
                                       QStringList oldSelection,
                                       QStringList newSelection)
    : m_model(model), m_oldSelection(std::move(oldSelection)),
      m_newSelection(std::move(newSelection)) {}

void SelectClipsCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectSelection(m_newSelection);
}

void SelectClipsCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectSelection(m_oldSelection);
}

bool SelectClipsCommand::mergeWith(const XylaCommand *other) {
  Q_UNUSED(other);
  return false; // Do not merge: every selection is an independent undo step
}

} // namespace xyla
