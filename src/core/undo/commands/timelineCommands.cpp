#include "timelineCommands.hpp"
#include "ui/models/timelineModel.hpp"
#include <QUuid>

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
  m_model->markDirty();
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
  m_model->markDirty();
}

// 2. Add Clip
AddClipsCommand::AddClipsCommand(TimelineModel *model,
                                 std::vector<AddClipInfo> clips)
    : model_(model), m_clips(std::move(clips)) {}

void AddClipsCommand::redo() {
  if (!model_)
    return;
  QStringList addedIds;
  for (const auto &info : m_clips) {
    model_->applyDirectAdd(info.clip, info.trackIndex);
    addedIds.append(info.clip.clipId());
  }
  model_->applyDirectSelection(addedIds);
  model_->markDirty();
}

void AddClipsCommand::undo() {
  if (!model_)
    return;
  for (const auto &info : m_clips) {
    model_->applyDirectRemove(info.clip.clipId(), info.trackIndex);
  }
  model_->applyDirectSelection({});
  model_->markDirty();
} // 3. Delete Clips
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
  m_model->markDirty();
}

void DeleteClipsCommand::undo() {
  if (!m_model)
    return;
  QStringList restoredIds;
  for (const auto &info : m_deletedClips) {
    m_model->applyDirectAdd(info.clip, info.trackIndex);
    restoredIds.append(info.clip.clipId());
  }
  m_model->applyDirectSelection(restoredIds);
  m_model->markDirty();
}

// 4. Trim Clip
TrimClipCommand::TrimClipCommand(TimelineModel *model, QString clipId,
                                 int trackIndex, int64_t oldStart,
                                 int64_t oldDur, int64_t oldIn,
                                 int64_t newStart, int64_t newDur,
                                 int64_t newIn, bool isRipple, bool global)
    : m_model(model), m_clipId(std::move(clipId)), m_trackIndex(trackIndex),
      m_oldStart(oldStart), m_oldDur(oldDur), m_oldIn(oldIn),
      m_newStart(newStart), m_newDur(newDur), m_newIn(newIn),
      m_isRipple(isRipple), m_global(global) {
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
                           m_newIn, m_isRipple, m_global);
  if (!m_selection.isEmpty()) {
    m_model->applyDirectSelection(m_selection);
  }
  m_model->markDirty();
}

void TrimClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectTrim(m_clipId, m_trackIndex, m_oldStart, m_oldDur,
                           m_oldIn, m_isRipple, m_global);
  if (!m_selection.isEmpty()) {
    m_model->applyDirectSelection(m_selection);
  }
  m_model->markDirty();
}

// 5. Multi Cut
MultiCutCommand::MultiCutCommand(TimelineModel *model,
                                 std::vector<CutInfo> cuts)
    : m_model(model), m_cuts(std::move(cuts)) {}

void MultiCutCommand::redo() {
  if (!m_model)
    return;
  QStringList newSelected;
  for (const auto &c : m_cuts) {
    m_model->applyDirectCut(c.id, c.track, c.frame, c.rightId, c.rightGroupId);
    newSelected.append(c.rightId);
  }
  m_model->applyDirectSelection(newSelected);
  m_model->markDirty();
}

void MultiCutCommand::undo() {
  if (!m_model)
    return;
  QStringList origSelected;
  for (auto it = m_cuts.rbegin(); it != m_cuts.rend(); ++it) {
    m_model->applyDirectUncut(it->id, it->track, it->rightId);
    origSelected.append(it->id);
  }
  m_model->applyDirectSelection(origSelected);
  m_model->markDirty();
}

// 6. Multi Ripple Trim
MultiRippleTrimCommand::MultiRippleTrimCommand(TimelineModel *model,
                                               std::vector<TrimAction> actions,
                                               int64_t deltaFrames, bool global)
    : m_model(model), m_actions(std::move(actions)), m_deltaFrames(deltaFrames),
      m_global(global) {}

void MultiRippleTrimCommand::redo() {
  if (!m_model)
    return;
  for (const auto &a : m_actions) {
    m_model->applyDirectTrim(a.clipId, a.trackIndex, a.newStart, a.newDur,
                             a.newIn, true, m_global);
  }
}

void MultiRippleTrimCommand::undo() {
  if (!m_model)
    return;
  for (const auto &a : m_actions) {
    m_model->applyDirectTrim(a.clipId, a.trackIndex, a.oldStart, a.oldDur,
                             a.oldIn, true, m_global, true);
  }
}

// 7. Select Clips
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
  return false;
}

// 8. Cut Clip (Single)
CutClipCommand::CutClipCommand(TimelineModel *model, QString clipId,
                               int trackIndex, FrameIndex cutFrame,
                               QString rightGroupId, QString rightClipId)
    : m_model(model), m_clipId(std::move(clipId)), m_trackIndex(trackIndex),
      m_cutFrame(cutFrame), m_rightGroupId(std::move(rightGroupId)) {
  m_rightClipId = rightClipId.isEmpty()
                      ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                      : rightClipId;
}

void CutClipCommand::redo() {
  if (!m_model)
    return;
  m_model->applyDirectCut(m_clipId, m_trackIndex, m_cutFrame, m_rightClipId,
                          m_rightGroupId);
  m_model->applyDirectSelection({m_rightClipId});
  m_model->markDirty();
}

void CutClipCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectUncut(m_clipId, m_trackIndex, m_rightClipId);
  m_model->applyDirectSelection({m_clipId});
  m_model->markDirty();
}

// 9. Ripple Move Clip
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
  m_model->markDirty();
}

void RippleMoveCommand::undo() {
  if (!m_model)
    return;
  m_model->applyDirectUndoRippleMove(m_clipId, m_srcTrack, m_dstTrack,
                                     m_dropFrame, m_global, m_originalStart,
                                     m_splitClipId);
  m_model->applyDirectSelection({m_clipId});
  m_model->markDirty();
}

// 10. Lock Clip
LockClipCommand::LockClipCommand(TimelineModel *model, QString clipId,
                                 bool locked)
    : m_model(model), m_clipId(std::move(clipId)), m_locked(locked) {}

void LockClipCommand::redo() {
  if (m_model) {
    m_model->applyDirectClipLock(m_clipId, m_locked);
    m_model->markDirty();
  }
}

void LockClipCommand::undo() {
  if (m_model) {
    m_model->applyDirectClipLock(m_clipId, !m_locked);
    m_model->markDirty();
  }
}

// 11. Lock Track
LockTrackCommand::LockTrackCommand(TimelineModel *model, int trackIndex,
                                   bool locked)
    : m_model(model), m_trackIndex(trackIndex), m_locked(locked) {}

void LockTrackCommand::redo() {
  if (m_model) {
    m_model->applyDirectTrackLock(m_trackIndex, m_locked);
    m_model->markDirty();
  }
}

void LockTrackCommand::undo() {
  if (m_model) {
    m_model->applyDirectTrackLock(m_trackIndex, !m_locked);
    m_model->markDirty();
  }
}

// 12. Link Clips
LinkClipsCommand::LinkClipsCommand(
    TimelineModel *model, QStringList clipIds, QString newGroupId,
    std::vector<std::pair<QString, QString>> previousGroups)
    : m_model(model), m_clipIds(std::move(clipIds)),
      m_newGroupId(std::move(newGroupId)),
      m_previousGroups(std::move(previousGroups)) {}

void LinkClipsCommand::redo() {
  if (m_model) {
    m_model->applyDirectLink(m_clipIds, m_newGroupId);
    m_model->markDirty();
  }
}

void LinkClipsCommand::undo() {
  if (m_model) {
    m_model->applyDirectRestoreLinkGroups(m_previousGroups);
    m_model->markDirty();
  }
}

// 13. Unlink Clips
UnlinkClipsCommand::UnlinkClipsCommand(
    TimelineModel *model, QStringList clipIds,
    std::vector<std::pair<QString, QString>> previousGroups)
    : m_model(model), m_clipIds(std::move(clipIds)),
      m_previousGroups(std::move(previousGroups)) {}

void UnlinkClipsCommand::redo() {
  if (m_model) {
    m_model->applyDirectLink(m_clipIds, "");
    m_model->markDirty();
  }
}

void UnlinkClipsCommand::undo() {
  if (m_model) {
    m_model->applyDirectRestoreLinkGroups(m_previousGroups);
    m_model->markDirty();
  }
}

DeleteKeyframesCommand::DeleteKeyframesCommand(
    TimelineModel *model, std::vector<KeyframeRecord> records)
    : m_model(model), m_records(std::move(records)) {}

void DeleteKeyframesCommand::redo() {
  if (!m_model)
    return;

  std::unordered_set<QString> affectedClips;

  for (const auto &rec : m_records) {
    auto *clip = m_model->findClip(rec.clipId);
    if (!clip)
      continue;
    auto *prop = clip->findAnimProperty(rec.propId);
    if (!prop)
      continue;

    prop->removeKeyframe(rec.relFrame);
    affectedClips.insert(rec.clipId);
  }

  for (const auto &cId : affectedClips) {
    emit m_model->clipPropertiesChanged(cId);
  }
  emit m_model->selectedClipDataChanged();
  m_model->markDirty();
  emit m_model->visualFrameInvalidated();
}

void DeleteKeyframesCommand::undo() {
  if (!m_model)
    return;

  std::unordered_set<QString> affectedClips;

  for (const auto &rec : m_records) {
    auto *clip = m_model->findClip(rec.clipId);
    if (!clip)
      continue;
    auto *prop = clip->findAnimProperty(rec.propId);
    if (!prop)
      continue;

    prop->setKeyframe(rec.relFrame, rec.value, rec.interpolation, rec.bezier);
    affectedClips.insert(rec.clipId);
  }

  for (const auto &cId : affectedClips) {
    emit m_model->clipPropertiesChanged(cId);
  }
  emit m_model->selectedClipDataChanged();
  m_model->markDirty();
  emit m_model->visualFrameInvalidated();
}
} // namespace xyla
