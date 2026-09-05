#include "core/media/mediaPool.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QUuid>
#include <algorithm>
#include <cstdint>
#include <limits>

namespace xyla {

bool TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             int64_t newStartFrame) {
  if (fromTrack < 0 || toTrack < 0 ||
      static_cast<size_t>(fromTrack) >= m_tracks.size() ||
      static_cast<size_t>(toTrack) >= m_tracks.size()) {
    return false;
  }

  if (m_tracks[fromTrack]->kind() != m_tracks[toTrack]->kind()) {
    return false;
  }

  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int64_t deltaFrames = newStartFrame - clip->startFrame();
  int deltaTracks = toTrack - fromTrack;
  return moveClips(QStringList{clipId}, deltaFrames, deltaTracks);
}

bool TimelineModel::moveClips(const QStringList &clipIds, int64_t deltaFrames,
                              int deltaTracks) {
  if (clipIds.isEmpty() || (deltaFrames == 0 && deltaTracks == 0))
    return false;

  std::vector<TimelineClip> movingClips;
  int64_t minStart = std::numeric_limits<int64_t>::max(); // <--- FIXED: int64_t

  // 1. Identify the leader clip and its track kind to know how to direct tracks
  QString leaderId =
      m_groupDragLeaderId.isEmpty() ? clipIds.first() : m_groupDragLeaderId;
  auto *leaderClip = findClip(leaderId);
  int leaderTrackIdx = leaderClip ? leaderClip->trackIndex() : -1;
  TrackKind leaderKind = (leaderTrackIdx >= 0 &&
                          static_cast<size_t>(leaderTrackIdx) < m_tracks.size())
                             ? m_tracks[leaderTrackIdx]->kind()
                             : TrackKind::Video;

  for (const auto &id : clipIds) {
    auto *c = findClip(id);
    if (c) {
      movingClips.push_back(*c);
      minStart = std::min(minStart, static_cast<int64_t>(c->startFrame()));
    }
  }

  if (movingClips.empty())
    return false;

  if (minStart + deltaFrames < 0) {
    deltaFrames = -minStart;
  }

  // 2. Validate move with OPPOSITE track direction for different track kind
  for (const auto &c : movingClips) {
    int srcTrackIdx = c.trackIndex();
    const auto &srcTrack = m_tracks[srcTrackIdx];
    if (!srcTrack)
      return false;

    // Flip deltaTracks for the opposite kind (audio moves opposite of video)
    int effectiveDeltaTracks =
        (srcTrack->kind() == leaderKind) ? deltaTracks : -deltaTracks;
    int targetTrackIdx = srcTrackIdx + effectiveDeltaTracks;

    if (targetTrackIdx < 0 ||
        static_cast<size_t>(targetTrackIdx) >= m_tracks.size()) {
      return false;
    }

    const auto &dstTrack = m_tracks[targetTrackIdx];
    if (!dstTrack || srcTrack->kind() != dstTrack->kind()) {
      return false;
    }

    int64_t newStart = c.startFrame() + deltaFrames;
    int64_t newEnd = newStart + c.durationFrames();

    for (const auto &other : dstTrack->clips()) {
      if (clipIds.contains(other.clipId()))
        continue;
      if (newStart < other.endFrame() && newEnd > other.startFrame()) {
        return false;
      }
    }
  }

  // 3. Build move records with the mirrored delta tracks
  std::vector<MoveClipsCommand::ClipMoveRecord> moves;
  for (const auto &c : movingClips) {
    int srcTrackIdx = c.trackIndex();
    const auto &srcTrack = m_tracks[srcTrackIdx];

    int effectiveDeltaTracks =
        (srcTrack->kind() == leaderKind) ? deltaTracks : -deltaTracks;
    int dstTrack = srcTrackIdx + effectiveDeltaTracks;
    int64_t dstStart = c.startFrame() + deltaFrames;

    moves.push_back(
        {c.clipId(), c.trackIndex(), dstTrack, c.startFrame(), dstStart});
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MoveClipsCommand>(this, std::move(moves)));
    return true;
  }

  for (const auto &m : moves) {
    applyDirectMove(m.clipId, m.srcTrack, m.dstTrack, m.newStart);
  }
  return true;
}

void TimelineModel::applyDirectMove(const QString &clipId, int srcTrack,
                                    int dstTrack, int64_t newStart) {
  if (srcTrack < 0 || dstTrack < 0 ||
      static_cast<size_t>(srcTrack) >= m_tracks.size() ||
      static_cast<size_t>(dstTrack) >= m_tracks.size())
    return;

  auto *clip = m_tracks[srcTrack]->findClip(clipId);
  if (!clip)
    return;

  if (srcTrack == dstTrack) {
    clip->setStartFrame(newStart);
    m_tracks[srcTrack]->sortClips();
  } else {
    TimelineClip moving = *clip;
    moving.setStartFrame(newStart);
    moving.setTrackIndex(dstTrack);
    m_tracks[srcTrack]->removeClip(clipId);
    m_tracks[dstTrack]->addClip(std::move(moving));
    emit trackDataChanged(srcTrack);
  }

  emit trackDataChanged(dstTrack);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
}

void TimelineModel::setGlobalRippleMode(bool enabled) {
  if (m_globalRippleMode != enabled) {
    m_globalRippleMode = enabled;
    emit globalRippleModeChanged(m_globalRippleMode);
  }
}

bool TimelineModel::rippleMoveClip(const QString &clipId, int toTrack,
                                   int64_t dropFrame, bool global) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int srcTrack = clip->trackIndex();
  if (toTrack < 0 || static_cast<size_t>(toTrack) >= m_tracks.size() ||
      !m_tracks[toTrack])
    return false;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<RippleMoveCommand>(
        this, clipId, srcTrack, toTrack, dropFrame, global));
    return true;
  }

  FrameIndex origStart = 0;
  QString splitRightId;
  applyDirectRippleMove(clipId, srcTrack, toTrack, dropFrame, global, origStart,
                        splitRightId);
  return true;
}

void TimelineModel::applyDirectRippleMove(const QString &clipId, int srcTrack,
                                          int dstTrack, int64_t dropFrame,
                                          bool global,
                                          FrameIndex &outOriginalStart,
                                          QString &outSplitRightId) {
  outSplitRightId.clear();

  if (srcTrack < 0 || dstTrack < 0 ||
      static_cast<size_t>(srcTrack) >= m_tracks.size() ||
      static_cast<size_t>(dstTrack) >= m_tracks.size() || !m_tracks[srcTrack] ||
      !m_tracks[dstTrack])
    return;

  auto *clip = m_tracks[srcTrack]->findClip(clipId);
  if (!clip)
    return;

  outOriginalStart = clip->startFrame();
  int64_t clipDuration = clip->durationFrames();
  TimelineClip movingClip = *clip;

  dropFrame = std::max<int64_t>(0, dropFrame);
  int64_t deltaFrames = dropFrame - outOriginalStart;
  if (deltaFrames == 0 && srcTrack == dstTrack)
    return;

  bool isSlide = (srcTrack == dstTrack);
  if (isSlide) {
    if (deltaFrames > 0) {
      for (const auto &other : m_tracks[srcTrack]->clips()) {
        if (other.clipId() != clipId) {
          if (other.startFrame() > outOriginalStart &&
              other.startFrame() < dropFrame) {
            isSlide = false;
            break;
          }
        }
      }
    } else {
      for (const auto &other : m_tracks[srcTrack]->clips()) {
        if (other.clipId() != clipId) {
          if (other.endFrame() > dropFrame &&
              other.startFrame() < outOriginalStart) {
            isSlide = false;
            break;
          }
        }
      }
    }
  }

  if (isSlide) {
    m_tracks[srcTrack]->removeClip(clipId);

    if (global) {
      for (size_t t = 0; t < m_tracks.size(); ++t) {
        if (m_tracks[t]) {
          m_tracks[t]->shiftClipsFrom(outOriginalStart, deltaFrames, clipId);
        }
      }
    } else {
      m_tracks[srcTrack]->shiftClipsFrom(outOriginalStart, deltaFrames, clipId);
    }

    movingClip.setStartFrame(dropFrame);
    movingClip.setTrackIndex(dstTrack);
    m_tracks[dstTrack]->addClip(std::move(movingClip));

    for (auto &track : m_tracks) {
      if (track)
        track->sortClips();
    }

    emit trackDataChanged(srcTrack);
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    emit selectedClipDataChanged();
    markDirty();
    return;
  }

  m_tracks[srcTrack]->removeClip(clipId);

  if (global) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        m_tracks[t]->shiftClipsFrom(outOriginalStart, -clipDuration, clipId);
      }
    }
  } else {
    m_tracks[srcTrack]->shiftClipsFrom(outOriginalStart, -clipDuration, clipId);
  }

  int64_t insertFrame = dropFrame;
  if (srcTrack == dstTrack) {
    if (dropFrame > outOriginalStart) {
      insertFrame = dropFrame - clipDuration;
    }
  } else if (global && dropFrame > outOriginalStart) {
    insertFrame = dropFrame - clipDuration;
  }
  insertFrame = std::max<int64_t>(0, insertFrame);

  auto *hoveredClip = m_tracks[dstTrack]->findClipAtFrame(insertFrame);
  if (hoveredClip) {
    int64_t hStart = hoveredClip->startFrame();
    int64_t hEnd = hoveredClip->endFrame();
    int64_t hMid = hStart + ((hEnd - hStart) / 2);

    if (insertFrame < hMid) {
      insertFrame = hStart;
    } else {
      insertFrame = hEnd;
    }
  }

  if (global) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        m_tracks[t]->shiftClipsFrom(insertFrame, clipDuration, clipId);
      }
    }
  } else {
    m_tracks[dstTrack]->shiftClipsFrom(insertFrame, clipDuration, clipId);
  }

  movingClip.setStartFrame(insertFrame);
  movingClip.setTrackIndex(dstTrack);
  m_tracks[dstTrack]->addClip(std::move(movingClip));

  for (auto &track : m_tracks) {
    if (track)
      track->sortClips();
  }

  emit trackDataChanged(srcTrack);
  if (srcTrack != dstTrack) {
    emit trackDataChanged(dstTrack);
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  markDirty();
}

void TimelineModel::applyDirectUndoRippleMove(const QString &clipId,
                                              int srcTrack, int dstTrack,
                                              int64_t dropFrame, bool global,
                                              FrameIndex originalStart,
                                              const QString &splitRightId) {
  Q_UNUSED(dropFrame);
  Q_UNUSED(splitRightId);

  if (srcTrack < 0 || dstTrack < 0 ||
      static_cast<size_t>(srcTrack) >= m_tracks.size() ||
      static_cast<size_t>(dstTrack) >= m_tracks.size() || !m_tracks[srcTrack] ||
      !m_tracks[dstTrack])
    return;

  auto *clip = m_tracks[dstTrack]->findClip(clipId);
  if (!clip)
    return;

  int64_t clipDuration = clip->durationFrames();
  int64_t currentStart = clip->startFrame();
  TimelineClip movingClip = *clip;

  m_tracks[dstTrack]->removeClip(clipId);

  if (global) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        m_tracks[t]->shiftClipsFrom(currentStart, -clipDuration, clipId);
      }
    }
  } else {
    m_tracks[dstTrack]->shiftClipsFrom(currentStart, -clipDuration, clipId);
  }

  if (global) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        m_tracks[t]->shiftClipsFrom(originalStart, clipDuration, clipId);
      }
    }
  } else {
    m_tracks[srcTrack]->shiftClipsFrom(originalStart, clipDuration, clipId);
  }

  movingClip.setStartFrame(originalStart);
  movingClip.setTrackIndex(srcTrack);
  m_tracks[srcTrack]->addClip(std::move(movingClip));

  for (auto &track : m_tracks) {
    if (track)
      track->sortClips();
  }

  emit trackDataChanged(srcTrack);
  if (srcTrack != dstTrack) {
    emit trackDataChanged(dstTrack);
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  markDirty();
}

bool TimelineModel::trimClip(const QString &clipId, int trackIndex,
                             int64_t newStartFrame, int64_t newDuration,
                             int64_t newSourceInFrame, bool isRipple) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  newStartFrame = std::max<int64_t>(0, newStartFrame);
  newSourceInFrame = std::max<int64_t>(0, newSourceInFrame);

  if (m_mediaPool) {
    const auto *proj =
        m_projectManager ? m_projectManager->activeProject() : nullptr;
    const double currentFps = proj ? proj->fps() : 30.0;

    qlonglong totalFrames =
        m_mediaPool->getAssetDurationFrames(clip->assetId(), currentFps);
    if (totalFrames > 0) {
      int64_t maxAvail = std::max<int64_t>(1, totalFrames - newSourceInFrame);
      newDuration = std::clamp<int64_t>(newDuration, 1, maxAvail);
    }
  } else {
    newDuration = std::max<int64_t>(1, newDuration);
  }

  if (!isRipple && trackIndex >= 0 &&
      static_cast<size_t>(trackIndex) < m_tracks.size() &&
      m_tracks[trackIndex]) {
    newDuration = m_tracks[trackIndex]->maxTrimDuration(newStartFrame,
                                                        newDuration, clipId);
  }

  if (clip->startFrame() == newStartFrame &&
      clip->durationFrames() == newDuration &&
      clip->sourceInFrame() == newSourceInFrame)
    return false;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<TrimClipCommand>(
        this, clipId, trackIndex, clip->startFrame(), clip->durationFrames(),
        clip->sourceInFrame(), newStartFrame, newDuration, newSourceInFrame,
        isRipple, m_globalRippleMode));
    return true;
  }

  applyDirectTrim(clipId, trackIndex, newStartFrame, newDuration,
                  newSourceInFrame, isRipple, m_globalRippleMode);
  return true;
}

bool TimelineModel::rippleTrimToPlayhead(int64_t playheadFrame, bool trimIn) {
  struct Target {
    QString id;
    int track;
    int64_t start, dur, in;
  };
  std::vector<Target> targets;

  bool foundSelected = false;
  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      if (playheadFrame >= c->startFrame() && playheadFrame <= c->endFrame()) {
        targets.push_back({id, c->trackIndex(), c->startFrame(),
                           c->durationFrames(), c->sourceInFrame()});
        foundSelected = true;
      }
    }
  }

  if (!foundSelected) {
    for (int t = 0; t < static_cast<int>(m_tracks.size()); ++t) {
      if (!m_tracks[t] || m_tracks[t]->isLocked())
        continue;
      if (auto *c = m_tracks[t]->findClipAtFrame(playheadFrame)) {
        targets.push_back({c->clipId(), t, c->startFrame(), c->durationFrames(),
                           c->sourceInFrame()});
      }
    }
  }

  if (targets.empty())
    return false;

  std::vector<MultiRippleTrimCommand::TrimAction> actions;
  int64_t maxDelta = 0;

  for (const auto &t : targets) {
    int64_t delta = 0;
    int64_t newStart = t.start, newDur = t.dur, newIn = t.in;

    if (trimIn && playheadFrame > t.start && playheadFrame < t.start + t.dur) {
      delta = playheadFrame - t.start;
      newStart = playheadFrame;
      newDur = t.dur - delta;
      newIn = t.in + delta;
    } else if (!trimIn && playheadFrame > t.start &&
               playheadFrame <= t.start + t.dur) {
      newDur = playheadFrame - t.start;
      delta = newDur - t.dur;
    } else {
      continue;
    }

    actions.push_back(
        {t.id, t.track, t.start, t.dur, t.in, newStart, newDur, newIn});
    maxDelta = delta;
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiRippleTrimCommand>(
        this, std::move(actions), maxDelta, m_globalRippleMode));
  } else {
    for (const auto &a : actions) {
      applyDirectTrim(a.clipId, a.trackIndex, a.newStart, a.newDur, a.newIn,
                      true, m_globalRippleMode);
    }
  }

  return true;
}

void TimelineModel::applyDirectTrim(const QString &clipId, int trackIndex,
                                    int64_t start, int64_t dur, int64_t in,
                                    bool isRipple, bool global, bool isUndo) {
  Q_UNUSED(isUndo);
  auto *clip = findClip(clipId);
  if (!clip)
    return;

  int64_t currentStart = clip->startFrame();
  int64_t currentDur = clip->durationFrames();
  int64_t currentEnd = currentStart + currentDur;

  int64_t deltaFrames = dur - currentDur;

  clip->setStartFrame(start);
  clip->setDurationFrames(dur);
  clip->setSourceInFrame(in);

  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size() &&
      m_tracks[trackIndex]) {
    m_tracks[trackIndex]->sortClips();
  }

  if (isRipple && deltaFrames != 0) {
    if (global) {
      for (size_t t = 0; t < m_tracks.size(); ++t) {
        if (m_tracks[t]) {
          m_tracks[t]->shiftClipsFrom(currentEnd, deltaFrames, clipId);
          m_tracks[t]->sortClips();
        }
      }
    } else if (trackIndex >= 0 &&
               static_cast<size_t>(trackIndex) < m_tracks.size() &&
               m_tracks[trackIndex]) {
      m_tracks[trackIndex]->shiftClipsFrom(currentEnd, deltaFrames, clipId);
      m_tracks[trackIndex]->sortClips();
    }
  }

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    emit trackDataChanged(static_cast<int>(t));
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  markDirty();
}

bool TimelineModel::cutClip(const QString &clipId, int64_t frame) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  if (frame <= clip->startFrame() || frame >= clip->endFrame())
    return false;

  int trackIdx = clip->trackIndex();
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<CutClipCommand>(this, clipId, trackIdx, frame));
    return true;
  }

  QString newRightId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  applyDirectCut(clipId, trackIdx, frame, newRightId);
  return true;
}

bool TimelineModel::cutAtPlayhead(int64_t playheadFrame) {
  std::vector<MultiCutCommand::CutInfo> cuts;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t] || m_tracks[t]->isLocked())
      continue;
    auto *c = m_tracks[t]->findClipAtFrame(playheadFrame);
    if (c && playheadFrame > c->startFrame() && playheadFrame < c->endFrame()) {
      cuts.push_back({c->clipId(), static_cast<int>(t), playheadFrame,
                      QUuid::createUuid().toString(QUuid::WithoutBraces)});
    }
  }

  if (cuts.empty())
    return false;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiCutCommand>(this, std::move(cuts)));
  } else {
    for (const auto &c : cuts)
      applyDirectCut(c.id, c.track, c.frame, c.rightId);
  }

  markDirty();
  return true;
}

void TimelineModel::applyDirectCut(const QString &clipId, int trackIndex,
                                   int64_t cutFrame,
                                   const QString &newRightClipId) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  auto *clip = m_tracks[trackIndex]->findClip(clipId);
  if (!clip)
    return;

  if (cutFrame <= clip->startFrame() || cutFrame >= clip->endFrame())
    return;

  int64_t originalStart = clip->startFrame();
  int64_t originalDuration = clip->durationFrames();
  int64_t originalSourceIn = clip->sourceInFrame();

  int64_t leftDuration = cutFrame - originalStart;
  int64_t rightDuration = originalDuration - leftDuration;
  int64_t rightSourceIn = originalSourceIn + leftDuration;

  clip->setDurationFrames(leftDuration);

  TimelineClip rightClip(newRightClipId, clip->assetId(), clip->name(),
                         cutFrame, rightDuration, rightSourceIn, trackIndex);
  rightClip.setSpeed(clip->speed());
  rightClip.setMuted(clip->isMuted());
  rightClip.setBlendMode(clip->blendMode());
  rightClip.setTransform(clip->positionX(), clip->positionY(), clip->scaleX(),
                         clip->scaleY(), clip->opacity());
  rightClip.setLinkGroupId(clip->linkGroupId());

  if (clip->nodeGraph()) {
    rightClip.setNodeGraph(clip->nodeGraph());
  }

  m_tracks[trackIndex]->addClip(std::move(rightClip));
  m_tracks[trackIndex]->sortClips();

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
}

void TimelineModel::applyDirectUncut(const QString &leftClipId, int trackIndex,
                                     const QString &rightClipId) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  auto *leftClip = m_tracks[trackIndex]->findClip(leftClipId);
  auto *rightClip = m_tracks[trackIndex]->findClip(rightClipId);

  if (!leftClip || !rightClip)
    return;

  int64_t restoredDuration =
      leftClip->durationFrames() + rightClip->durationFrames();
  leftClip->setDurationFrames(restoredDuration);

  m_tracks[trackIndex]->removeClip(rightClipId);
  m_tracks[trackIndex]->sortClips();

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
}

QVariantMap TimelineModel::querySnap(int64_t candidateStart, int64_t duration,
                                     int targetTrack, int64_t playheadFrame,
                                     double zoomFactor,
                                     const QStringList &ignoreClipIds,
                                     double snapPixelThreshold) const {
  QVariantMap result;
  result["snappedStart"] = static_cast<double>(candidateStart);
  result["isSnapped"] = false;
  result["snapType"] = "none";
  result["guideFrame"] = -1.0;
  result["spacingGapFrames"] = 0;
  result["allMatchingGaps"] = QVariantList();

  if (zoomFactor <= 0.0)
    return result;

  int64_t snapDistFrames =
      std::max<int64_t>(1, std::round(snapPixelThreshold / zoomFactor));
  int64_t candidateEnd = candidateStart + duration;

  std::vector<int64_t> edgePoints;
  edgePoints.push_back(0);
  if (playheadFrame >= 0) {
    edgePoints.push_back(playheadFrame);
  }

  struct GapInterval {
    int64_t start;
    int64_t end;
    int64_t gapDuration;
  };
  std::vector<TimelineClip> targetTrackClips;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    for (const auto &c : m_tracks[t]->clips()) {
      if (ignoreClipIds.contains(c.clipId()))
        continue;

      int64_t cStart = c.startFrame();
      int64_t cEnd = c.endFrame();

      edgePoints.push_back(cStart);
      edgePoints.push_back(cEnd);

      if (static_cast<int>(t) == targetTrack) {
        targetTrackClips.push_back(c);
      }
    }
  }

  int64_t bestEdgeDelta = std::numeric_limits<int64_t>::max();
  int64_t bestEdgeStart = candidateStart;
  int64_t bestGuideFrame = -1;
  bool isPlayheadSnap = false;

  for (int64_t pt : edgePoints) {
    int64_t distLeft = std::abs(candidateStart - pt);
    if (distLeft <= snapDistFrames && distLeft < std::abs(bestEdgeDelta)) {
      bestEdgeDelta = pt - candidateStart;
      bestEdgeStart = pt;
      bestGuideFrame = pt;
      isPlayheadSnap = (pt == playheadFrame);
    }

    int64_t distRight = std::abs(candidateEnd - pt);
    if (distRight <= snapDistFrames && distRight < std::abs(bestEdgeDelta)) {
      bestEdgeDelta = (pt - duration) - candidateStart;
      bestEdgeStart = pt - duration;
      bestGuideFrame = pt;
      isPlayheadSnap = (pt == playheadFrame);
    }
  }

  if (std::abs(bestEdgeDelta) <= snapDistFrames) {
    result["snappedStart"] =
        static_cast<double>(std::max<int64_t>(0, bestEdgeStart));
    result["isSnapped"] = true;
    result["snapType"] = isPlayheadSnap ? "playhead" : "edge";
    result["guideFrame"] = static_cast<double>(bestGuideFrame);
    return result;
  }

  std::sort(targetTrackClips.begin(), targetTrackClips.end(),
            [](const TimelineClip &a, const TimelineClip &b) {
              return a.startFrame() < b.startFrame();
            });

  std::vector<GapInterval> existingGaps;
  if (targetTrackClips.size() >= 2) {
    for (size_t i = 0; i < targetTrackClips.size() - 1; ++i) {
      int64_t gap =
          targetTrackClips[i + 1].startFrame() - targetTrackClips[i].endFrame();
      if (gap > 0) {
        existingGaps.push_back({targetTrackClips[i].endFrame(),
                                targetTrackClips[i + 1].startFrame(), gap});
      }
    }
  }

  if (!existingGaps.empty()) {
    int64_t bestGapDelta = std::numeric_limits<int64_t>::max();
    int64_t bestGapStart = candidateStart;
    int64_t matchedGapFrames = 0;
    int64_t matchedActiveStart = -1;
    int64_t matchedActiveEnd = -1;

    for (const auto &neighbor : targetTrackClips) {
      for (const auto &eg : existingGaps) {
        int64_t refGap = eg.gapDuration;

        int64_t candidateAfterStart = neighbor.endFrame() + refGap;
        int64_t deltaAfter = std::abs(candidateStart - candidateAfterStart);
        if (deltaAfter <= snapDistFrames &&
            deltaAfter < std::abs(bestGapDelta)) {
          bestGapDelta = deltaAfter;
          bestGapStart = candidateAfterStart;
          matchedGapFrames = refGap;
          matchedActiveStart = neighbor.endFrame();
          matchedActiveEnd = candidateAfterStart;
        }

        int64_t candidateBeforeStart =
            neighbor.startFrame() - refGap - duration;
        if (candidateBeforeStart >= 0) {
          int64_t deltaBefore = std::abs(candidateStart - candidateBeforeStart);
          if (deltaBefore <= snapDistFrames &&
              deltaBefore < std::abs(bestGapDelta)) {
            bestGapDelta = deltaBefore;
            bestGapStart = candidateBeforeStart;
            matchedGapFrames = refGap;
            matchedActiveStart = candidateBeforeStart + duration;
            matchedActiveEnd = neighbor.startFrame();
          }
        }
      }
    }

    if (std::abs(bestGapDelta) <= snapDistFrames && matchedActiveStart >= 0) {
      result["snappedStart"] =
          static_cast<double>(std::max<int64_t>(0, bestGapStart));
      result["isSnapped"] = true;
      result["snapType"] = "spacing";
      result["spacingGapFrames"] = static_cast<double>(matchedGapFrames);

      QVariantList allGaps;
      for (const auto &eg : existingGaps) {
        if (eg.gapDuration == matchedGapFrames) {
          QVariantMap gapMap;
          gapMap["start"] = static_cast<double>(eg.start);
          gapMap["end"] = static_cast<double>(eg.end);
          gapMap["gapFrames"] = static_cast<double>(eg.gapDuration);
          gapMap["isActive"] = false;
          allGaps.push_back(gapMap);
        }
      }

      QVariantMap activeGapMap;
      activeGapMap["start"] = static_cast<double>(matchedActiveStart);
      activeGapMap["end"] = static_cast<double>(matchedActiveEnd);
      activeGapMap["gapFrames"] = static_cast<double>(matchedGapFrames);
      activeGapMap["isActive"] = true;
      allGaps.push_back(activeGapMap);

      result["allMatchingGaps"] = allGaps;
      return result;
    }
  }

  return result;
}

} // namespace xyla
