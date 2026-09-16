#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QUuid>
#include <algorithm>
#include <cstdint>
#include <limits>

namespace xyla {

// internal helpers

void TimelineModel::notifyTimelineChanged(int trackA, int trackB) {
  if (trackA >= 0) {
    emit trackDataChanged(trackA);
  }
  if (trackB >= 0 && trackB != trackA) {
    emit trackDataChanged(trackB);
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  markDirty();
}

void TimelineModel::shiftAllTracksAfter(FrameIndex fromFrame,
                                        int64_t deltaFrames,
                                        const QString &ignoreClipId) {
  for (auto &track : m_tracks) {
    if (track && !track->getIsLocked()) {
      track->shiftClipsAfter(fromFrame, deltaFrames, ignoreClipId);
    }
  }
}

// cutting operations

bool TimelineModel::cutClip(const QString &clipId, int64_t frame) {
  auto *clip = findClip(clipId);
  if (!clip || !clip->getTiming().containsFrame(frame)) {
    return false;
  }

  QStringList linkedClipIds = getLinkedClipIds(clipId);
  QString newRightGroupId =
      clip->getLinkGroupId().isEmpty()
          ? ""
          : QUuid::createUuid().toString(QUuid::WithoutBraces);

  std::vector<MultiCutCommand::CutInfo> cuts;
  for (const QString &id : linkedClipIds) {
    if (auto *c = findClip(id)) {
      if (c->getTiming().containsFrame(frame)) {
        QString newRightId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        cuts.push_back({id, c->getTiming().trackIndex, frame, newRightId,
                        newRightGroupId});
      }
    }
  }

  if (cuts.empty()) {
    return false;
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiCutCommand>(this, std::move(cuts)));
  } else {
    QStringList newSelected;
    for (const auto &c : cuts) {
      applyDirectCut(c.id, c.track, c.frame, c.rightId, c.rightGroupId);
      newSelected.append(c.rightId);
    }
    applyDirectSelection(newSelected);
  }

  return true;
}

bool TimelineModel::cutAtPlayhead(int64_t playheadFrame) {
  std::vector<TimelineClip *> clipsToCut;
  for (const auto &track : m_tracks) {
    if (!track || track->getIsLocked()) {
      continue;
    }
    if (auto *c = track->findClipAtFrame(playheadFrame)) {
      if (c->getTiming().containsFrame(playheadFrame)) {
        clipsToCut.push_back(c);
      }
    }
  }

  if (clipsToCut.empty()) {
    return false;
  }

  std::unordered_map<QString, QString> oldToNewGroupMap;
  for (auto *c : clipsToCut) {
    const QString &origGroup = c->getLinkGroupId();
    if (!origGroup.isEmpty() && !oldToNewGroupMap.count(origGroup)) {
      oldToNewGroupMap[origGroup] =
          QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
  }

  std::vector<MultiCutCommand::CutInfo> cuts;
  cuts.reserve(clipsToCut.size());

  for (auto *c : clipsToCut) {
    QString rightId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString rightGroupId = c->getLinkGroupId().isEmpty()
                               ? ""
                               : oldToNewGroupMap[c->getLinkGroupId()];
    cuts.push_back({c->getClipId(), c->getTiming().trackIndex, playheadFrame,
                    rightId, rightGroupId});
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiCutCommand>(this, std::move(cuts)));
  } else {
    QStringList newSelected;
    for (const auto &c : cuts) {
      applyDirectCut(c.id, c.track, c.frame, c.rightId, c.rightGroupId);
      newSelected.append(c.rightId);
    }
    applyDirectSelection(newSelected);
  }

  return true;
}

void TimelineModel::applyDirectCut(const QString &clipId, int trackIndex,
                                   int64_t cutFrame,
                                   const QString &newRightClipId,
                                   const QString &newRightGroupId) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->splitClip(clipId, cutFrame, newRightClipId)) {
    if (auto *rightClip = track->findClip(newRightClipId)) {
      rightClip->setLinkGroupId(newRightGroupId);
    }
    notifyTimelineChanged(trackIndex);
  }
}

void TimelineModel::applyDirectUncut(const QString &leftClipId, int trackIndex,
                                     const QString &rightClipId) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->uncutClips(leftClipId, rightClipId)) {
    notifyTimelineChanged(trackIndex);
  }
}

// moving operations

bool TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             int64_t newStartFrame) {
  auto *src = getTrack(fromTrack);
  auto *dst = getTrack(toTrack);
  if (!src || !dst || src->getKind() != dst->getKind()) {
    return false;
  }

  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int64_t deltaFrames = newStartFrame - clip->getTiming().startFrame;
  int deltaTracks = toTrack - fromTrack;
  return moveClips(QStringList{clipId}, deltaFrames, deltaTracks);
}

bool TimelineModel::moveClips(const QStringList &clipIds, int64_t deltaFrames,
                              int deltaTracks) {
  if (clipIds.isEmpty() || (deltaFrames == 0 && deltaTracks == 0)) {
    return false;
  }

  std::vector<TimelineClip> movingClips;
  int64_t minStart = std::numeric_limits<int64_t>::max();

  QString leaderId =
      m_groupDragLeaderId.isEmpty() ? clipIds.first() : m_groupDragLeaderId;
  auto *leaderClip = findClip(leaderId);
  auto *leaderTrack =
      leaderClip ? getTrack(leaderClip->getTiming().trackIndex) : nullptr;
  TrackKind leaderKind =
      leaderTrack ? leaderTrack->getKind() : TrackKind::Video;

  for (const auto &id : clipIds) {
    if (auto *c = findClip(id)) {
      movingClips.push_back(*c);
      minStart =
          std::min(minStart, static_cast<int64_t>(c->getTiming().startFrame));
    }
  }

  if (movingClips.empty())
    return false;

  if (minStart + deltaFrames < 0) {
    deltaFrames = -minStart;
  }

  // Validate placement on target tracks
  for (const auto &c : movingClips) {
    int srcIdx = c.getTiming().trackIndex;
    auto *srcTrack = getTrack(srcIdx);
    if (!srcTrack)
      return false;

    int effectiveDeltaTracks =
        (srcTrack->getKind() == leaderKind) ? deltaTracks : -deltaTracks;
    int targetTrackIdx = srcIdx + effectiveDeltaTracks;
    auto *dstTrack = getTrack(targetTrackIdx);

    if (!dstTrack || srcTrack->getKind() != dstTrack->getKind()) {
      return false;
    }

    ClipTiming targetTiming = c.getTiming();
    targetTiming.startFrame += deltaFrames;

    for (const auto &other : dstTrack->getClips()) {
      if (clipIds.contains(other.getClipId()))
        continue;
      if (targetTiming.startFrame < other.getTiming().endFrame() &&
          targetTiming.endFrame() > other.getTiming().startFrame) {
        return false;
      }
    }
  }

  // Build move records
  std::vector<MoveClipsCommand::ClipMoveRecord> moves;
  for (const auto &c : movingClips) {
    int srcIdx = c.getTiming().trackIndex;
    auto *srcTrack = getTrack(srcIdx);
    int effectiveDeltaTracks =
        (srcTrack->getKind() == leaderKind) ? deltaTracks : -deltaTracks;
    int dstIdx = srcIdx + effectiveDeltaTracks;
    int64_t dstStart = c.getTiming().startFrame + deltaFrames;

    moves.push_back(
        {c.getClipId(), srcIdx, dstIdx, c.getTiming().startFrame, dstStart});
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
  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  bool ok = (srcTrack == dstTrack)
                ? src->moveClip(clipId, newStart)
                : src->transferClipTo(clipId, *dst, newStart);
  if (ok) {
    notifyTimelineChanged(srcTrack, dstTrack);
  }
}

// ripple move and slide operations

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

  int srcTrack = clip->getTiming().trackIndex;
  if (!getTrack(toTrack))
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
  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  auto *clip = src->findClip(clipId);
  if (!clip)
    return;

  outOriginalStart = clip->getTiming().startFrame;
  int64_t clipDuration = clip->getTiming().durationFrames;
  TimelineClip movingClip = *clip;

  dropFrame = std::max<int64_t>(0, dropFrame);
  int64_t deltaFrames = dropFrame - outOriginalStart;
  if (deltaFrames == 0 && srcTrack == dstTrack)
    return;

  // 1. Remove from source
  src->removeClip(clipId);

  // 2. Collapse gap at origin
  if (global) {
    shiftAllTracksAfter(outOriginalStart, -clipDuration, clipId);
  } else {
    src->shiftClipsAfter(outOriginalStart, -clipDuration, clipId);
  }

  // 3. Resolve insertion frame
  int64_t insertFrame = dst->resolveInsertFrame(dropFrame, clipDuration);
  if (global) {
    shiftAllTracksAfter(insertFrame, clipDuration, clipId);
  } else {
    dst->shiftClipsAfter(insertFrame, clipDuration, clipId);
  }

  // 4. Place into destination
  ClipTiming newTiming = movingClip.getTiming();
  newTiming.startFrame = insertFrame;
  newTiming.trackIndex = dstTrack;
  movingClip.setTiming(newTiming);

  dst->insertClip(std::move(movingClip));
  notifyTimelineChanged(srcTrack, dstTrack);
}

void TimelineModel::applyDirectUndoRippleMove(const QString &clipId,
                                              int srcTrack, int dstTrack,
                                              int64_t dropFrame, bool global,
                                              FrameIndex originalStart,
                                              const QString &splitRightId) {
  Q_UNUSED(dropFrame);
  Q_UNUSED(splitRightId);

  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  auto *clip = dst->findClip(clipId);
  if (!clip)
    return;

  int64_t clipDuration = clip->getTiming().durationFrames;
  int64_t currentStart = clip->getTiming().startFrame;
  TimelineClip movingClip = *clip;

  dst->removeClip(clipId);

  if (global) {
    shiftAllTracksAfter(currentStart, -clipDuration, clipId);
    shiftAllTracksAfter(originalStart, clipDuration, clipId);
  } else {
    dst->shiftClipsAfter(currentStart, -clipDuration, clipId);
    src->shiftClipsAfter(originalStart, clipDuration, clipId);
  }

  ClipTiming restoredTiming = movingClip.getTiming();
  restoredTiming.startFrame = originalStart;
  restoredTiming.trackIndex = srcTrack;
  movingClip.setTiming(restoredTiming);

  src->insertClip(std::move(movingClip));
  notifyTimelineChanged(srcTrack, dstTrack);
}

// trimming operations

bool TimelineModel::trimClip(const QString &clipId, int trackIndex,
                             int64_t newStartFrame, int64_t newDuration,
                             int64_t newSourceInFrame, bool isRipple) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int64_t deltaStart = newStartFrame - clip->getTiming().startFrame;
  int64_t deltaDuration = newDuration - clip->getTiming().durationFrames;
  int64_t deltaIn = newSourceInFrame - clip->getTiming().sourceInFrame;

  if (deltaStart == 0 && deltaDuration == 0 && deltaIn == 0) {
    return false;
  }

  QStringList linkedClipIds = getLinkedClipIds(clipId);

  for (const QString &lid : linkedClipIds) {
    auto *linkedClip = findClip(lid);
    if (!linkedClip)
      continue;

    int64_t targetStart =
        std::max<int64_t>(0, linkedClip->getTiming().startFrame + deltaStart);
    int64_t targetDur = std::max<int64_t>(
        1, linkedClip->getTiming().durationFrames + deltaDuration);
    int64_t targetIn =
        std::max<int64_t>(0, linkedClip->getTiming().sourceInFrame + deltaIn);
    int targetTrack = linkedClip->getTiming().trackIndex;

    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<TrimClipCommand>(
          this, lid, targetTrack, linkedClip->getTiming().startFrame,
          linkedClip->getTiming().durationFrames,
          linkedClip->getTiming().sourceInFrame, targetStart, targetDur,
          targetIn, isRipple, m_globalRippleMode));
    } else {
      applyDirectTrim(lid, targetTrack, targetStart, targetDur, targetIn,
                      isRipple, m_globalRippleMode);
    }
  }

  return true;
}

bool TimelineModel::rippleTrimToPlayhead(int64_t playheadFrame, bool trimIn) {
  struct Target {
    QString id;
    int track;
    int64_t start, dur, in;
  };
  std::vector<Target> targets;

  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      if (c->getTiming().containsFrame(playheadFrame)) {
        targets.push_back(
            {id, c->getTiming().trackIndex, c->getTiming().startFrame,
             c->getTiming().durationFrames, c->getTiming().sourceInFrame});
      }
    }
  }

  if (targets.empty()) {
    for (int t = 0; t < static_cast<int>(m_tracks.size()); ++t) {
      if (!m_tracks[t] || m_tracks[t]->getIsLocked())
        continue;
      if (auto *c = m_tracks[t]->findClipAtFrame(playheadFrame)) {
        targets.push_back({c->getClipId(), t, c->getTiming().startFrame,
                           c->getTiming().durationFrames,
                           c->getTiming().sourceInFrame});
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
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  auto *clip = track->findClip(clipId);
  if (!clip)
    return;

  FrameIndex currentEnd = clip->getTiming().endFrame();
  int64_t deltaFrames = dur - clip->getTiming().durationFrames;

  if (!track->trimClip(clipId, start, dur, in)) {
    return;
  }

  if (isRipple && deltaFrames != 0) {
    if (global) {
      shiftAllTracksAfter(currentEnd, deltaFrames, clipId);
    } else {
      track->shiftClipsAfter(currentEnd, deltaFrames, clipId);
    }
  }

  notifyTimelineChanged(trackIndex);
}

// snapping queries

QVariantMap TimelineModel::querySnap(int64_t candidateStart, int64_t duration,
                                     int targetTrack, int64_t playheadFrame,
                                     double zoomFactor,
                                     const QStringList &ignoreClipIds,
                                     double snapPixelThreshold) const {
  if (zoomFactor <= 0.0) {
    return SnapResult1D{}.toVariantMap();
  }

  m_snapEngine.clearAll();

  // 1. Add global anchor points
  m_snapEngine.addPoint(0.0, 0.0, "timeline_origin", 100);
  if (playheadFrame >= 0) {
    m_snapEngine.addPoint(static_cast<double>(playheadFrame), 0.0, "playhead",
                          50);
  }

  // 2. Add clip edges from all unlocked tracks
  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t] || m_tracks[t]->getIsLocked())
      continue;

    for (const auto &c : m_tracks[t]->getClips()) {
      if (ignoreClipIds.contains(c.getClipId()))
        continue;

      m_snapEngine.addPoint(c.getTiming().startFrame, 0.0, "clip_edge", 10);
      m_snapEngine.addPoint(c.getTiming().endFrame(), 0.0, "clip_edge", 10);

      if (static_cast<int>(t) == targetTrack) {
        m_snapEngine.addIntervalX(c.getTiming().startFrame,
                                  c.getTiming().endFrame(), "track_gap");
      }
    }
  }

  // 3. Solve 1D snap
  double worldThreshold = snapPixelThreshold / zoomFactor;
  SnapResult1D result =
      m_snapEngine.snap1D(static_cast<double>(candidateStart),
                          static_cast<double>(duration), worldThreshold);

  return result.toVariantMap();
}

// inspector property and keyframe bindings

void TimelineModel::updateClipTransformProperty(const QString &clipId,
                                                const QString &key,
                                                const QVariant &value) {
  if (clipId.isEmpty())
    return;

  auto *clip = resolveVideoClip(clipId);
  if (!clip)
    clip = findClip(clipId);
  if (!clip)
    return;

  int64_t currentTimelineFrame =
      m_playbackManager ? m_playbackManager->currentFrame() : 0;

  if (key == "blendMode") {
    clip->setBlendMode(value.toInt());
  } else {
    // Local clip animation time [0 ... duration]
    FrameIndex localFrame =
        clip->getTiming().timelineToLocalFrame(currentTimelineFrame);
    float val = value.toFloat();
    if (key == "opacity") {
      val = std::clamp(val, 0.0f, 1.0f);
    }

    auto applyVal = [&](anim::AnimProperty &prop) {
      if (prop.getIsAnimated()) {
        prop.setKeyframe(localFrame, val);
      } else {
        prop.setStaticValue(val);
      }
    };

    if (key == "scale" ||
        (clip->getIsUniformScale() && (key == "scaleX" || key == "scaleY"))) {
      applyVal(clip->getTransform().scaleX);
      applyVal(clip->getTransform().scaleY);
    } else {
      if (auto *prop = clip->findAnimProperty(key)) {
        applyVal(*prop);
      }
    }
  }

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

void TimelineModel::updateClipAudioProperty(const QString &clipId,
                                            const QString &key,
                                            const QVariant &value) {
  if (clipId.isEmpty())
    return;

  auto *clip = findClip(clipId);
  if (!clip)
    return;

  // Resolve linked audio clip if video clip ID was passed
  if (!clip->getLinkGroupId().isEmpty()) {
    QStringList linked = getLinkedClipIds(clipId);
    for (const auto &lid : linked) {
      if (auto *candidate = findClip(lid)) {
        auto *tr = getTrack(candidate->getTiming().trackIndex);
        if (tr && tr->getKind() == TrackKind::Audio) {
          clip = candidate;
          break;
        }
      }
    }
  }

  const int64_t currentTimelineFrame =
      m_playbackManager ? m_playbackManager->currentFrame() : 0;
  const FrameIndex localFrame =
      clip->getTiming().timelineToLocalFrame(currentTimelineFrame);

  if (key == "channelMode") {
    clip->getAudio().channelMode = value.toInt();
  } else if (key == "volume") {
    float val = std::max(0.0f, value.toFloat());
    if (clip->getAudio().volume.getIsAnimated()) {
      clip->getAudio().volume.setKeyframe(localFrame, val);
    } else {
      clip->getAudio().volume.setStaticValue(val);
    }
  } else if (key == "pan") {
    float val = std::clamp(value.toFloat(), -1.0f, 1.0f);
    if (clip->getAudio().pan.getIsAnimated()) {
      clip->getAudio().pan.setKeyframe(localFrame, val);
    } else {
      clip->getAudio().pan.setStaticValue(val);
    }
  }

  audio::AudioTimelineManager::instance().updateClipAudioParams(
      clip->getClipId().toStdString(), clip->getAudio().volume.getStaticValue(),
      clip->getAudio().pan.getStaticValue(), clip->getAudio().channelMode,
      clip->getIsMuted());

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
}

TimelineClip *TimelineModel::resolveVideoClip(const QString &clipId) {
  auto *clip = findClip(clipId);
  if (!clip)
    return nullptr;

  auto *track = getTrack(clip->getTiming().trackIndex);
  if (track && track->getKind() == TrackKind::Video) {
    return clip;
  }

  if (!clip->getLinkGroupId().isEmpty()) {
    QStringList linked = getLinkedClipIds(clipId);
    for (const auto &lid : linked) {
      if (auto *candidate = findClip(lid)) {
        auto *tr = getTrack(candidate->getTiming().trackIndex);
        if (tr && tr->getKind() == TrackKind::Video) {
          return candidate;
        }
      }
    }
  }

  return clip;
}

} // namespace xyla
