#include "timelineCommands.hpp"
#include "ui/models/timelineModel.hpp"
#include <quuid.h>

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

TrimClipCommand::TrimClipCommand(TimelineModel *model, QString clipId,
                                 int trackIndex, int64_t oldStart,
                                 int64_t oldDur, int64_t oldIn,
                                 int64_t newStart, int64_t newDur,
                                 int64_t newIn)
    : m_model(model), m_clipId(std::move(clipId)), m_trackIndex(trackIndex),
      m_oldStart(oldStart), m_oldDur(oldDur), m_oldIn(oldIn),
      m_newStart(newStart), m_newDur(newDur), m_newIn(newIn) {
  if (m_model) {
    auto currentSelection = m_model->selectedClipIds();
    if (currentSelection.contains(m_clipId)) {
      m_selection = currentSelection;
    } else {
      m_selection = m_model->getLinkedClipIds(m_clipId);
    }
  }
}

void TrimClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_newStart, m_newDur,
                           m_newIn);
  if (!m_selection.isEmpty()) {
    m_model->applyDirectSelection(m_selection);
  }
}

void TrimClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_oldStart, m_oldDur,
                           m_oldIn);
  if (!m_selection.isEmpty()) {
    m_model->applyDirectSelection(m_selection);
  }
}

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

// Cut Clip
CutClipCommand::CutClipCommand(TimelineModel *model, QString clipId,
                               int trackIndex, FrameIndex cutFrame)
    : m_model(model), m_clipId(std::move(clipId)), m_trackIndex(trackIndex),
      m_cutFrame(cutFrame) {
  m_rightClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void CutClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectCut(m_clipId, m_trackIndex, m_cutFrame, m_rightClipId);
  m_model->applyDirectSelection({m_rightClipId});
}

void CutClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectUncut(m_clipId, m_trackIndex, m_rightClipId);
  m_model->applyDirectSelection({m_clipId});
}

// Ripple Move Clip
RippleMoveCommand::RippleMoveCommand(TimelineModel *model, QString clipId,
                                     int srcTrack, int dstTrack,
                                     FrameIndex dropFrame, bool global)
    : m_model(model), m_clipId(std::move(clipId)), m_srcTrack(srcTrack),
      m_dstTrack(dstTrack), m_dropFrame(dropFrame), m_global(global) {}

void RippleMoveCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectRippleMove(m_clipId, m_srcTrack, m_dstTrack, m_dropFrame,
                                 m_global, m_originalStart, m_splitClipId);
  m_model->applyDirectSelection({m_clipId});
}

void RippleMoveCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectUndoRippleMove(m_clipId, m_srcTrack, m_dstTrack,
                                     m_dropFrame, m_global, m_originalStart,
                                     m_splitClipId);
  m_model->applyDirectSelection({m_clipId});
}

LockClipCommand::LockClipCommand(TimelineModel *model, QString clipId,
                                 bool locked)
    : m_model(model), m_clipId(std::move(clipId)), m_locked(locked) {}

void LockClipCommand::redo() {
  if (m_model) {
    m_model->applyDirectClipLock(m_clipId, m_locked);
  }
}

void LockClipCommand::undo() {
  if (m_model) {
    m_model->applyDirectClipLock(m_clipId, !m_locked);
  }
}

LockTrackCommand::LockTrackCommand(TimelineModel *model, int trackIndex,
                                   bool locked)
    : m_model(model), m_trackIndex(trackIndex), m_locked(locked) {}

void LockTrackCommand::redo() {
  if (m_model) {
    m_model->applyDirectTrackLock(m_trackIndex, m_locked);
  }
}

void LockTrackCommand::undo() {
  if (m_model) {
    m_model->applyDirectTrackLock(m_trackIndex, !m_locked);
  }
}

LinkClipsCommand::LinkClipsCommand(
    TimelineModel *model, QStringList clipIds, QString newGroupId,
    std::vector<std::pair<QString, QString>> previousGroups)
    : m_model(model), m_clipIds(std::move(clipIds)),
      m_newGroupId(std::move(newGroupId)),
      m_previousGroups(std::move(previousGroups)) {}

void LinkClipsCommand::redo() {
  if (m_model) {
    m_model->applyDirectLink(m_clipIds, m_newGroupId);
  }
}

void LinkClipsCommand::undo() {
  if (m_model) {
    m_model->applyDirectRestoreLinkGroups(m_previousGroups);
  }
}

UnlinkClipsCommand::UnlinkClipsCommand(
    TimelineModel *model, QStringList clipIds,
    std::vector<std::pair<QString, QString>> previousGroups)
    : m_model(model), m_clipIds(std::move(clipIds)),
      m_previousGroups(std::move(previousGroups)) {}

void UnlinkClipsCommand::redo() {
  if (m_model) {
    m_model->applyDirectLink(m_clipIds, "");
  }
}

void UnlinkClipsCommand::undo() {
  if (m_model) {
    m_model->applyDirectRestoreLinkGroups(m_previousGroups);
  }
}
} // namespace xyla
