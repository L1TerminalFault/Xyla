#include "timelineCommands.hpp"
#include "ui/models/timelineModel.hpp"

namespace xyla {

// Move
MoveClipsCommand::MoveClipsCommand(TimelineModel *model,
                                   std::vector<ClipMoveRecord> moves)
    : m_model(model), m_moves(std::move(moves)) {}

void MoveClipsCommand::redo() {
  if (!m_model)
    return;
  for (const auto &m : m_moves) {
    m_model->applyDirectMove(m.clipId, m.srcTrack, m.dstTrack, m.newStart);
  }
}

void MoveClipsCommand::undo() {
  if (!m_model)
    return;
  for (const auto &m : m_moves) {
    m_model->applyDirectMove(m.clipId, m.dstTrack, m.srcTrack, m.oldStart);
  }
}

// Add
AddClipCommand::AddClipCommand(TimelineModel *model, TimelineClip clip,
                               int trackIndex)
    : m_model(model), m_clip(std::move(clip)), m_trackIndex(trackIndex) {}

void AddClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectAdd(m_clip, m_trackIndex);
}

void AddClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectRemove(m_clip.clipId(), m_trackIndex);
}

// Delete
DeleteClipsCommand::DeleteClipsCommand(
    TimelineModel *model, std::vector<DeletedClipInfo> deletedClips)
    : m_model(model), m_deletedClips(std::move(deletedClips)) {}

void DeleteClipsCommand::redo() {
  if (!m_model)
    return;
  for (const auto &info : m_deletedClips) {
    m_model->applyDirectRemove(info.clip.clipId(), info.trackIndex);
  }
}

void DeleteClipsCommand::undo() {
  if (!m_model)
    return;
  for (const auto &info : m_deletedClips) {
    m_model->applyDirectAdd(info.clip, info.trackIndex);
  }
}

// Trim
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
}

void TrimClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_oldStart, m_oldDur,
                           m_oldIn);
}

} // namespace xyla
