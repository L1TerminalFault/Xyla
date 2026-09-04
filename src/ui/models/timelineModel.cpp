#include "timelineModel.hpp"
#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/media/mediaPool.hpp"
#include "core/render/nodes/colorGradeNode.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/sourceNode.hpp"
#include "core/render/nodes/transformNode.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"

#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>
#include <algorithm>
#include <limits>
#include <qjsonarray.h>

namespace xyla {

TimelineModel::TimelineModel(ProjectManager *projectManager,
                             MediaPool *mediaPool, XylaUndoStack *undoStack,
                             QObject *parent)
    : QAbstractListModel(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool), m_undoStack(undoStack) {

  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v2", "Video 2", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v1", "Video 1", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a1", "Audio 1", TrackKind::Audio));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a2", "Audio 2", TrackKind::Audio));
}

int TimelineModel::firstAudioTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->kind() == TrackKind::Audio) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int TimelineModel::firstVideoTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->kind() == TrackKind::Video) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int TimelineModel::findMatchingAudioTrack(int videoTrackIndex) const {
  // 1. Gather all video track indices and all audio track indices
  std::vector<int> videoTracks;
  std::vector<int> audioTracks;

  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i]) {
      if (m_tracks[i]->kind() == TrackKind::Video) {
        videoTracks.push_back(static_cast<int>(i));
      } else if (m_tracks[i]->kind() == TrackKind::Audio) {
        audioTracks.push_back(static_cast<int>(i));
      }
    }
  }

  if (audioTracks.empty())
    return -1;

  // Find the position of videoTrackIndex within the video tracks list
  auto it = std::find(videoTracks.begin(), videoTracks.end(), videoTrackIndex);
  size_t vRank =
      (it != videoTracks.end()) ? std::distance(videoTracks.begin(), it) : 0;

  // In standard layout (Video 1 is closest to Audio 1):
  // Reverse rank so Video 1 maps directly to Audio 1
  size_t targetAudioRank = 0;
  if (!videoTracks.empty()) {
    size_t distFromDivider = (videoTracks.size() - 1) - vRank;
    targetAudioRank = std::min(distFromDivider, audioTracks.size() - 1);
  }

  return audioTracks[targetAudioRank];
}

void TimelineModel::addTrack(std::shared_ptr<TimelineTrack> track) {
  if (!track)
    return;
  beginInsertRows(QModelIndex(), static_cast<int>(m_tracks.size()),
                  static_cast<int>(m_tracks.size()));
  m_tracks.push_back(std::move(track));
  endInsertRows();
  emit trackCountChanged();
}

void TimelineModel::setSelectedClipId(const QString &clipId) {
  if (m_selectedClipId != clipId) {
    m_selectedClipId = clipId;
    if (m_selectedClipId.isEmpty()) {
      m_selectedClipIds.clear();
      m_lastSelectedClipId.clear();
    } else if (!m_selectedClipIds.contains(m_selectedClipId)) {
      m_selectedClipIds = QStringList{m_selectedClipId};
      m_lastSelectedClipId = m_selectedClipId;
    }
    emit selectedClipIdChanged(m_selectedClipId);
    emit selectedClipsChanged(m_selectedClipIds);
    emit selectedClipDataChanged();
  }
}

void TimelineModel::startSelectionBatch() {
  m_isBatchingSelection = true;
  m_selectionBatchStart = m_selectedClipIds;
}

void TimelineModel::commitSelectionBatch() {
  if (!m_isBatchingSelection)
    return;
  m_isBatchingSelection = false;

  if (m_selectionBatchStart != m_selectedClipIds) {
    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<SelectClipsCommand>(
          this, m_selectionBatchStart, m_selectedClipIds));
    }
  }
  m_selectionBatchStart.clear();
}

void TimelineModel::selectBox(int64_t startFrame, int64_t endFrame,
                              int startTrack, int endTrack, bool toggle) {
  int minT = std::max(0, std::min(startTrack, endTrack));
  int maxT = std::min(static_cast<int>(m_tracks.size()) - 1,
                      std::max(startTrack, endTrack));

  int64_t minF = std::max<int64_t>(0, std::min(startFrame, endFrame));
  int64_t maxF = std::max(startFrame, endFrame);

  QStringList boxSelection;
  for (int t = minT; t <= maxT; ++t) {
    if (!m_tracks[t])
      continue;
    for (const auto &c : m_tracks[t]->clips()) {
      if (c.startFrame() < maxF && c.endFrame() > minF) {
        QStringList linked = getLinkedClipIds(c.clipId());
        for (const auto &lid : linked) {
          if (!boxSelection.contains(lid)) {
            boxSelection.append(lid);
          }
        }
      }
    }
  }

  QStringList newSelection;
  if (toggle) {
    newSelection =
        m_isBatchingSelection ? m_selectionBatchStart : m_selectedClipIds;
    for (const auto &id : boxSelection) {
      if (newSelection.contains(id)) {
        newSelection.removeAll(id);
      } else {
        newSelection.append(id);
      }
    }
  } else {
    newSelection = boxSelection;
  }

  if (m_isBatchingSelection) {
    applyDirectSelection(newSelection);
  } else {
    if (newSelection == m_selectedClipIds)
      return;
    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                       newSelection));
    } else {
      applyDirectSelection(newSelection);
    }
  }
}

void TimelineModel::clearSelection() {
  if (m_selectedClipIds.isEmpty() && m_selectedClipId.isEmpty())
    return;

  QStringList emptyList;
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     emptyList));
  } else {
    applyDirectSelection(emptyList);
  }
}

bool TimelineModel::removeClip(const QString &clipId, int trackIndex) {
  if (clipId.isEmpty())
    return false;

  bool removed = false;
  int affectedTrack = -1;

  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size()) {
    if (m_tracks[trackIndex] && m_tracks[trackIndex]->removeClip(clipId)) {
      removed = true;
      affectedTrack = trackIndex;
    }
  } else {
    for (size_t i = 0; i < m_tracks.size(); ++i) {
      if (m_tracks[i] && m_tracks[i]->removeClip(clipId)) {
        removed = true;
        affectedTrack = static_cast<int>(i);
        break;
      }
    }
  }

  if (removed) {
    m_selectedClipIds.removeAll(clipId);
    if (m_selectedClipId == clipId) {
      m_selectedClipId =
          m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
      emit selectedClipIdChanged(m_selectedClipId);
      emit selectedClipDataChanged();
    }
    emit selectedClipsChanged(m_selectedClipIds);

    if (affectedTrack >= 0) {
      emit trackDataChanged(affectedTrack);
    }
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  }

  return removed;
}

void TimelineModel::deleteSelectedClips() {
  if (m_selectedClipIds.isEmpty())
    return;

  std::vector<DeleteClipsCommand::DeletedClipInfo> toDelete;
  for (const auto &id : m_selectedClipIds) {
    auto *c = findClip(id);
    if (c) {
      toDelete.push_back({*c, c->trackIndex()});
    }
  }

  clearSelection();

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<DeleteClipsCommand>(this, std::move(toDelete)));
  } else {
    for (const auto &info : toDelete) {
      applyDirectRemove(info.clip.clipId(), info.trackIndex);
    }
  }
}

QVariantMap TimelineModel::selectedClipData() const {
  if (m_selectedClipId.isEmpty())
    return {};

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    auto *clip = track->findClip(m_selectedClipId);
    if (clip) {
      QVariantMap data;
      data["clipId"] = clip->clipId();
      data["name"] = clip->name();
      data["assetId"] = clip->assetId();
      data["startFrame"] = static_cast<double>(clip->startFrame());
      data["durationFrames"] = static_cast<double>(clip->durationFrames());
      data["sourceInFrame"] = static_cast<double>(clip->sourceInFrame());

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip->assetId(), currentFps);
        if (totalFrames > 0) {
          data["sourceDurationFrames"] = static_cast<double>(totalFrames);
        }
      }

      auto graph = clip->nodeGraph();
      if (graph) {
        data["nodes"] = graph->toVariantList();
        data["links"] = graph->linksToVariantList();
        data["editorNodes"] = graph->listEditorNodes();
        data["defaultEditorNodeId"] = graph->defaultEditorNodeId();
      }
      return data;
    }
  }
  return {};
}

TimelineClip *TimelineModel::findClip(const QString &clipId) {
  if (clipId.isEmpty())
    return nullptr;
  for (auto &track : m_tracks) {
    if (!track)
      continue;
    auto *c = track->findClip(clipId);
    if (c)
      return c;
  }
  return nullptr;
}

QVariantList TimelineModel::getAllClips() const {
  QVariantList all;
  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    for (const auto &clip : m_tracks[t]->clips()) {
      QVariantMap map;
      map["clipId"] = clip.clipId();
      map["name"] = clip.name();
      map["assetId"] = clip.assetId();
      map["startFrame"] = static_cast<double>(clip.startFrame());
      map["durationFrames"] = static_cast<double>(clip.durationFrames());
      map["sourceInFrame"] = static_cast<double>(clip.sourceInFrame());
      map["trackIndex"] = static_cast<int>(t);

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip.assetId(), currentFps);
        if (totalFrames > 0) {
          map["sourceDurationFrames"] = static_cast<double>(totalFrames);
        }
      }

      all.append(map);
    }
  }
  return all;
}

QVariantList TimelineModel::getClipsForTrack(int trackIndex) const {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size())
    return {};

  const auto &track = m_tracks[trackIndex];
  if (!track)
    return {};

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  QVariantList list;
  for (const auto &clip : track->clips()) {
    QVariantMap map;
    map["clipId"] = clip.clipId();
    map["name"] = clip.name();
    map["assetId"] = clip.assetId();
    map["startFrame"] = static_cast<double>(clip.startFrame());
    map["durationFrames"] = static_cast<double>(clip.durationFrames());
    map["sourceInFrame"] = static_cast<double>(clip.sourceInFrame());
    map["trackIndex"] = trackIndex;

    if (m_mediaPool) {
      qlonglong totalFrames =
          m_mediaPool->getAssetDurationFrames(clip.assetId(), currentFps);
      if (totalFrames > 0) {
        map["sourceDurationFrames"] = static_cast<double>(totalFrames);
      }
    }

    list.append(map);
  }
  return list;
}

QString TimelineModel::addClip(const QString &assetId, const QString &name,
                               int trackIndex, int64_t startFrame,
                               int64_t durationFrames, int64_t sourceInFrame) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      durationFrames <= 0 || !m_tracks[trackIndex]) {
    return "";
  }

  // 1. Robust stream detection (check MediaPool asset metadata)
  bool hasVideo = false;
  bool hasAudio = false;

  if (m_mediaPool) {
    auto asset = m_mediaPool->getAsset(assetId);
    if (asset) {
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    } else {
      // Fallback: If assetId was passed as clean path, try via getAssetId
      QString realId = m_mediaPool->getAssetId(assetId);
      if (!realId.isEmpty()) {
        asset = m_mediaPool->getAsset(realId);
        if (asset) {
          hasVideo = !asset->metadata().videoStreams.empty();
          hasAudio = !asset->metadata().audioStreams.empty();
        }
      }
    }
  }

  // Safe fallback if metadata was unprobed: default to video
  if (!hasVideo && !hasAudio) {
    hasVideo = true;
  }

  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);

  // =========================================================================
  // CASE A: Pure Audio File (Music / Voiceover / Sound FX)
  // =========================================================================
  if (!hasVideo && hasAudio) {
    int audioTrackIndex = trackIndex;
    if (m_tracks[trackIndex]->kind() != TrackKind::Audio) {
      int firstAudio = firstAudioTrackIndex();
      if (firstAudio != -1) {
        audioTrackIndex = firstAudio;
      }
    }

    int64_t clampedStart = m_tracks[audioTrackIndex]->clampPlacement(
        startFrame, durationFrames, "");

    TimelineClip audioClip(primaryClipId, assetId, name, clampedStart,
                           durationFrames, sourceInFrame, audioTrackIndex);

    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(
          std::make_unique<AddClipCommand>(this, audioClip, audioTrackIndex));
    } else {
      applyDirectAdd(audioClip, audioTrackIndex);
    }

    setSelectedClipId(primaryClipId);
    return primaryClipId;
  }

  // =========================================================================
  // CASE B: Video Track Insertion (Video only OR Video + Audio)
  // =========================================================================
  int videoTrackIndex = trackIndex;
  if (m_tracks[trackIndex]->kind() != TrackKind::Video) {
    int firstVideo = firstVideoTrackIndex();
    if (firstVideo != -1) {
      videoTrackIndex = firstVideo;
    }
  }

  int64_t clampedVideoStart =
      m_tracks[videoTrackIndex]->clampPlacement(startFrame, durationFrames, "");

  // Generate shared link group ID if this file has both audio and video
  QString sharedGroupId =
      hasAudio ? QUuid::createUuid().toString(QUuid::WithoutBraces) : "";

  TimelineClip videoClip(primaryClipId, assetId, name, clampedVideoStart,
                         durationFrames, sourceInFrame, videoTrackIndex);
  if (!sharedGroupId.isEmpty()) {
    videoClip.setLinkGroupId(sharedGroupId);
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<AddClipCommand>(this, videoClip, videoTrackIndex));
  } else {
    applyDirectAdd(videoClip, videoTrackIndex);
  }

  // Spawning the paired audio clip strictly on an AUDIO track
  if (hasAudio) {
    int audioTrackIndex = findMatchingAudioTrack(videoTrackIndex);

    // Guaranteed check: audioTrackIndex MUST be TrackKind::Audio
    if (audioTrackIndex >= 0 &&
        static_cast<size_t>(audioTrackIndex) < m_tracks.size() &&
        m_tracks[audioTrackIndex] &&
        m_tracks[audioTrackIndex]->kind() == TrackKind::Audio) {

      QString audioClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
      int64_t clampedAudioStart = m_tracks[audioTrackIndex]->clampPlacement(
          startFrame, durationFrames, "");

      TimelineClip audioClip(audioClipId, assetId, name, clampedAudioStart,
                             durationFrames, sourceInFrame, audioTrackIndex);
      audioClip.setLinkGroupId(sharedGroupId);

      if (auto *stack = XylaUndoStack::instance()) {
        stack->push(
            std::make_unique<AddClipCommand>(this, audioClip, audioTrackIndex));
      } else {
        applyDirectAdd(audioClip, audioTrackIndex);
      }
    }
  }

  setSelectedClipId(primaryClipId);
  return primaryClipId;
}

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
  int minTrack = static_cast<int>(m_tracks.size());
  int maxTrack = -1;
  int64_t minStart = std::numeric_limits<int64_t>::max();

  for (const auto &id : clipIds) {
    auto *c = findClip(id);
    if (c) {
      movingClips.push_back(*c);
      minTrack = std::min(minTrack, c->trackIndex());
      maxTrack = std::max(maxTrack, c->trackIndex());
      minStart = std::min(minStart, c->startFrame());
    }
  }

  if (movingClips.empty())
    return false;

  if (minStart + deltaFrames < 0) {
    deltaFrames = -minStart;
  }
  if (minTrack + deltaTracks < 0) {
    deltaTracks = -minTrack;
  }
  if (maxTrack + deltaTracks >= static_cast<int>(m_tracks.size())) {
    deltaTracks = static_cast<int>(m_tracks.size()) - 1 - maxTrack;
  }

  for (const auto &c : movingClips) {
    int srcTrackIdx = c.trackIndex();
    int targetTrackIdx = srcTrackIdx + deltaTracks;

    if (targetTrackIdx < 0 ||
        static_cast<size_t>(targetTrackIdx) >= m_tracks.size() ||
        srcTrackIdx < 0 ||
        static_cast<size_t>(srcTrackIdx) >= m_tracks.size()) {
      return false;
    }

    const auto &srcTrack = m_tracks[srcTrackIdx];
    const auto &dstTrack = m_tracks[targetTrackIdx];
    if (!srcTrack || !dstTrack)
      return false;

    if (srcTrack->kind() != dstTrack->kind()) {
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

  std::vector<MoveClipsCommand::ClipMoveRecord> moves;
  for (const auto &c : movingClips) {
    int dstTrack = c.trackIndex() + deltaTracks;
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

void TimelineModel::applyDirectAdd(TimelineClip clip, int trackIndex) {
  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size() &&
      m_tracks[trackIndex]) {
    m_tracks[trackIndex]->addClip(std::move(clip));
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  }
}

void TimelineModel::applyDirectRemove(const QString &clipId, int trackIndex) {
  removeClip(clipId, trackIndex);
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

QVariantList TimelineModel::getClipWaveformPeaks(const QString &assetId,
                                                 int64_t startFrame,
                                                 int64_t durationFrames,
                                                 double zoomFactor) const {
  QVariantList peaksList;

  auto clipBuffer = audio::AudioTimelineManager::instance().getClipBuffer(
      assetId.toStdString());
  if (!clipBuffer) {
    // If not in cache, request pre-warm immediately
    return peaksList;
  }

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  double sampleRate = 48000.0;
  int64_t startSample = static_cast<int64_t>(
      (static_cast<double>(startFrame) / fps) * sampleRate);
  size_t sampleCount = static_cast<size_t>(
      (static_cast<double>(durationFrames) / fps) * sampleRate);

  double samplesPerPixel = (sampleRate / fps) / std::max(0.1, zoomFactor);

  auto pyramid = audio::WaveformGenerator::instance().generateAsync(clipBuffer);
  if (!pyramid)
    return peaksList;

  auto peaks = pyramid->getPeaks(0, startSample, sampleCount, samplesPerPixel);
  for (const auto &p : peaks) {
    QVariantMap map;
    map["min"] = p.min;
    map["max"] = p.max;
    peaksList.append(map);
  }

  return peaksList;
}

bool TimelineModel::isTrackMuted(int trackIndex) const {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return false;
  return m_tracks[trackIndex]->isMuted();
}

void TimelineModel::setTrackMuted(int trackIndex, bool muted) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  // Toggle internal flag and notify QML + Audio Manager
  emit trackDataChanged(trackIndex);
  emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                   {TrackMutedRole});
}

void TimelineModel::toggleTrackMute(int trackIndex) {
  setTrackMuted(trackIndex, !isTrackMuted(trackIndex));
}

QVariantList TimelineModel::listEditorNodes(const QString &clipId) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    return clip->nodeGraph()->listEditorNodes();
  }
  return {};
}

QString TimelineModel::defaultEditorNodeId(const QString &clipId) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    return clip->nodeGraph()->defaultEditorNodeId();
  }
  return "";
}

QString TimelineModel::addNode(const QString &clipId, const QString &typeName,
                               double x, double y) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (!clip || !clip->nodeGraph())
    return "";

  if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
      typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : clip->nodeGraph()->nodes()) {
      if (n && n->typeName() == "OutputNode") {
        return "";
      }
    }
  } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
             typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : clip->nodeGraph()->nodes()) {
      if (n && n->typeName() == "SourceNode") {
        return "";
      }
    }
  }

  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  std::shared_ptr<render::Node> newNode;

  if (typeName.compare("Transform", Qt::CaseInsensitive) == 0 ||
      typeName.compare("TransformNode", Qt::CaseInsensitive) == 0) {
    newNode =
        std::make_shared<render::TransformNode>(prefix + "_xform", "Transform");
  } else if (typeName.compare("ColorGrade", Qt::CaseInsensitive) == 0 ||
             typeName.compare("Color Grade", Qt::CaseInsensitive) == 0 ||
             typeName.compare("ColorGradeNode", Qt::CaseInsensitive) == 0) {
    newNode = std::make_shared<render::ColorGradeNode>(prefix + "_grade",
                                                       "Color Grade");
  } else if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
             typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
    newNode =
        std::make_shared<render::OutputNode>(prefix + "_out", "Video Out");
  } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
             typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
    newNode = std::make_shared<render::SourceNode>(prefix + "_src", "Video In",
                                                   clip->assetId());
  }

  if (newNode) {
    newNode->setPosition(x, y);
    clip->nodeGraph()->addNode(newNode);

    emit selectedClipDataChanged();
    emit clipPropertiesChanged(clip->clipId());
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    return newNode->id();
  }
  return "";
}

bool TimelineModel::removeNode(const QString &clipId, const QString &nodeId) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    bool ok = clip->nodeGraph()->removeNode(nodeId);
    if (ok) {
      emit selectedClipDataChanged();
      emit clipPropertiesChanged(clip->clipId());
      emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    }
    return ok;
  }
  return false;
}

bool TimelineModel::connectSockets(const QString &clipId,
                                   const QString &fromNodeId,
                                   const QString &fromSocketId,
                                   const QString &toNodeId,
                                   const QString &toSocketId) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    bool ok = clip->nodeGraph()->connectSockets(fromNodeId, fromSocketId,
                                                toNodeId, toSocketId);
    if (ok) {
      emit selectedClipDataChanged();
      emit clipPropertiesChanged(clip->clipId());
      emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    }
    return ok;
  }
  return false;
}

bool TimelineModel::disconnectSockets(const QString &clipId,
                                      const QString &fromNodeId,
                                      const QString &fromSocketId,
                                      const QString &toNodeId,
                                      const QString &toSocketId) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    bool ok = clip->nodeGraph()->disconnectSockets(fromNodeId, fromSocketId,
                                                   toNodeId, toSocketId);
    if (ok) {
      emit selectedClipDataChanged();
      emit clipPropertiesChanged(clip->clipId());
      emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    }
    return ok;
  }
  return false;
}

void TimelineModel::setNodePosition(const QString &clipId,
                                    const QString &nodeId, double x, double y) {
  auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
  if (clip && clip->nodeGraph()) {
    auto node = clip->nodeGraph()->findNode(nodeId);
    if (node) {
      node->setPosition(x, y);
    }
  }
}

void TimelineModel::updateSocketValue(const QString &clipId,
                                      const QString &nodeId,
                                      const QString &socketId,
                                      const QVariant &value) {
  QVariant unpacked = value;
  if (unpacked.canConvert<QJSValue>()) {
    QJSValue jsVal = unpacked.value<QJSValue>();
    if (jsVal.isArray() || jsVal.isObject()) {
      unpacked = jsVal.toVariant();
    } else if (jsVal.isNumber()) {
      unpacked = jsVal.toNumber();
    } else if (jsVal.isBool()) {
      unpacked = jsVal.toBool();
    } else if (jsVal.isString()) {
      unpacked = jsVal.toString();
    }
  }

  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (!m_tracks[i])
      continue;

    auto *clip =
        m_tracks[i]->findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
    if (!clip || !clip->nodeGraph())
      continue;

    auto node = clip->nodeGraph()->findNode(nodeId);
    if (!node)
      continue;

    render::SocketValue val;
    bool assigned = false;

    if (unpacked.typeId() == QMetaType::QVariantList ||
        unpacked.typeId() == QMetaType::QStringList) {
      QVariantList list = unpacked.toList();
      if (list.size() >= 4) {
        val = render::ColorVal{static_cast<float>(list[0].toDouble()),
                               static_cast<float>(list[1].toDouble()),
                               static_cast<float>(list[2].toDouble()),
                               static_cast<float>(list[3].toDouble())};
        assigned = true;
      } else if (list.size() >= 2) {
        val = render::Vec2Val{static_cast<float>(list[0].toDouble()),
                              static_cast<float>(list[1].toDouble())};
        assigned = true;
      } else if (list.size() == 1) {
        val = static_cast<float>(list[0].toDouble());
        assigned = true;
      }
    } else if (unpacked.typeId() == QMetaType::QVariantMap) {
      QVariantMap map = unpacked.toMap();
      if (map.contains("x") && map.contains("y")) {
        val = render::Vec2Val{static_cast<float>(map["x"].toDouble()),
                              static_cast<float>(map["y"].toDouble())};
        assigned = true;
      }
    } else if (unpacked.canConvert<QVector2D>()) {
      QVector2D v = unpacked.value<QVector2D>();
      val = render::Vec2Val{v.x(), v.y()};
      assigned = true;
    } else if (unpacked.canConvert<QPointF>()) {
      QPointF pt = unpacked.toPointF();
      val = render::Vec2Val{static_cast<float>(pt.x()),
                            static_cast<float>(pt.y())};
      assigned = true;
    } else if (unpacked.typeId() == QMetaType::Int ||
               unpacked.typeId() == QMetaType::LongLong) {
      val = unpacked.toInt();
      assigned = true;
    } else if (unpacked.canConvert<double>()) {
      val = static_cast<float>(unpacked.toDouble());
      assigned = true;
    } else if (unpacked.typeId() == QMetaType::Bool) {
      val = unpacked.toBool();
      assigned = true;
    }

    if (assigned) {
      node->setInputSocketValue(socketId, val);
      clip->nodeGraph()->markDirty();

      emit trackDataChanged(static_cast<int>(i));
      emit clipPropertiesChanged(clip->clipId());
      emit selectedClipDataChanged();
      emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    }
    return;
  }
}

int TimelineModel::rowCount(const QModelIndex &parent) const {
  Q_UNUSED(parent);
  return static_cast<int>(m_tracks.size());
}

QVariant TimelineModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      static_cast<size_t>(index.row()) >= m_tracks.size())
    return {};

  const auto &track = m_tracks[index.row()];
  if (!track)
    return {};

  switch (role) {
  case TrackIdRole:
    return track->trackId();
  case TrackNameRole:
    return track->name();
  case TrackKindRole:
    return static_cast<int>(track->kind());
  case TrackLockedRole:
    return track->isLocked();
  case TrackMutedRole:
    return track->isMuted();
  default:
    return {};
  }
}

QHash<int, QByteArray> TimelineModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[TrackIdRole] = "trackId";
  roles[TrackNameRole] = "trackName";
  roles[TrackKindRole] = "trackKind";
  roles[TrackLockedRole] = "trackLocked";
  roles[TrackMutedRole] = "trackMuted";
  return roles;
}

void TimelineModel::applyDirectSelection(const QStringList &selection) {
  m_selectedClipIds = selection;
  m_selectedClipId =
      m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
  m_lastSelectedClipId = m_selectedClipId;

  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit selectedClipDataChanged();
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

bool TimelineModel::isTrackLocked(int trackIndex) const {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return false;
  return m_tracks[trackIndex]->isLocked();
}

bool TimelineModel::isClipLocked(const QString &clipId) const {
  return isClipOrGroupLocked(clipId);
}

void TimelineModel::setClipLocked(const QString &clipId, bool locked) {
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<LockClipCommand>(this, clipId, locked));
    return;
  }
  applyDirectClipLock(clipId, locked);
}

void TimelineModel::applyDirectClipLock(const QString &clipId, bool locked) {
  QString groupId;
  if (const auto *c = findClip(clipId)) {
    groupId = c->linkGroupId();
  }

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (m_tracks[t]) {
      bool trackChanged = false;
      for (const auto &c : m_tracks[t]->clips()) {
        if (c.clipId() == clipId ||
            (!groupId.isEmpty() && c.linkGroupId() == groupId)) {
          if (auto *target = m_tracks[t]->findClip(c.clipId())) {
            if (target->isLocked() != locked) {
              target->setLocked(locked);
              emit clipPropertiesChanged(c.clipId());
              trackChanged = true;
            }
          }
        }
      }
      if (trackChanged) {
        emit trackDataChanged(static_cast<int>(t));
      }
    }
  }
  emit selectedClipDataChanged();
  markDirty();
}

void TimelineModel::toggleClipLock(const QString &clipId) {
  setClipLocked(clipId, !isClipLocked(clipId));
}

void TimelineModel::setTrackLocked(int trackIndex, bool locked) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<LockTrackCommand>(this, trackIndex, locked));
    return;
  }
  applyDirectTrackLock(trackIndex, locked);
}

void TimelineModel::applyDirectTrackLock(int trackIndex, bool locked) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  if (m_tracks[trackIndex]->isLocked() != locked) {
    m_tracks[trackIndex]->setLocked(locked);
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                     {TrackLockedRole});
  }
}

void TimelineModel::toggleTrackLock(int trackIndex) {
  setTrackLocked(trackIndex, !isTrackLocked(trackIndex));
}

QStringList TimelineModel::getLinkedClipIds(const QString &clipId) const {
  QStringList result;
  const auto *clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip || clip->linkGroupId().isEmpty()) {
    if (clip)
      result.append(clipId);
    return result;
  }

  const QString &groupId = clip->linkGroupId();
  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    for (const auto &c : track->clips()) {
      if (c.linkGroupId() == groupId) {
        result.append(c.clipId());
      }
    }
  }
  return result;
}

bool TimelineModel::isClipOrGroupLocked(const QString &clipId) const {
  const auto *clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip)
    return false;

  if (clip->isLocked() || isTrackLocked(clip->trackIndex()))
    return true;

  if (!clip->linkGroupId().isEmpty()) {
    const QString &groupId = clip->linkGroupId();
    for (const auto &track : m_tracks) {
      if (!track)
        continue;
      bool trackLocked = track->isLocked();
      for (const auto &c : track->clips()) {
        if (c.linkGroupId() == groupId) {
          if (c.isLocked() || trackLocked)
            return true;
        }
      }
    }
  }

  return false;
}

bool TimelineModel::canLinkSelection() const {
  if (m_selectedClipIds.size() < 2)
    return false;

  QString firstGroupId;
  bool allSameGroup = true;
  for (int i = 0; i < m_selectedClipIds.size(); ++i) {
    const auto *c =
        const_cast<TimelineModel *>(this)->findClip(m_selectedClipIds[i]);
    if (!c)
      continue;
    if (c->linkGroupId().isEmpty()) {
      return true;
    }
    if (i == 0) {
      firstGroupId = c->linkGroupId();
    } else if (c->linkGroupId() != firstGroupId) {
      allSameGroup = false;
    }
  }
  return !allSameGroup;
}

bool TimelineModel::canUnlinkSelection() const {
  for (const auto &id : m_selectedClipIds) {
    const auto *c = const_cast<TimelineModel *>(this)->findClip(id);
    if (c && !c->linkGroupId().isEmpty())
      return true;
  }
  return false;
}

void TimelineModel::linkSelectedClips() {
  if (m_selectedClipIds.size() < 2)
    return;

  std::vector<std::pair<QString, QString>> previousGroups;
  for (const auto &id : m_selectedClipIds) {
    if (const auto *c = findClip(id)) {
      previousGroups.emplace_back(id, c->linkGroupId());
    }
  }

  QString newGroupId = QUuid::createUuid().toString(QUuid::WithoutBraces);

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<LinkClipsCommand>(
        this, m_selectedClipIds, newGroupId, std::move(previousGroups)));
    return;
  }

  applyDirectLink(m_selectedClipIds, newGroupId);
}

void TimelineModel::unlinkSelectedClips() {
  if (m_selectedClipIds.isEmpty())
    return;

  QStringList allToUnlink;
  std::vector<std::pair<QString, QString>> previousGroups;

  for (const auto &id : m_selectedClipIds) {
    QStringList linked = getLinkedClipIds(id);
    for (const auto &lid : linked) {
      if (!allToUnlink.contains(lid)) {
        allToUnlink.append(lid);
        if (const auto *c = findClip(lid)) {
          previousGroups.emplace_back(lid, c->linkGroupId());
        }
      }
    }
  }

  if (allToUnlink.isEmpty())
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<UnlinkClipsCommand>(
        this, allToUnlink, std::move(previousGroups)));
    return;
  }

  applyDirectLink(allToUnlink, "");
}

void TimelineModel::applyDirectLink(const QStringList &clipIds,
                                    const QString &groupId) {
  for (const auto &id : clipIds) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        if (auto *c = m_tracks[t]->findClip(id)) {
          c->setLinkGroupId(groupId);
          emit clipPropertiesChanged(id);
          emit trackDataChanged(static_cast<int>(t));
          break;
        }
      }
    }
  }
  emit selectedClipDataChanged();
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
}

void TimelineModel::applyDirectRestoreLinkGroups(
    const std::vector<std::pair<QString, QString>> &groups) {
  for (const auto &[id, groupId] : groups) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t]) {
        if (auto *c = m_tracks[t]->findClip(id)) {
          c->setLinkGroupId(groupId);
          emit clipPropertiesChanged(id);
          emit trackDataChanged(static_cast<int>(t));
          break;
        }
      }
    }
  }
}

void TimelineModel::selectClip(const QString &clipId, bool toggle,
                               bool isRange) {
  auto *clickedClip = findClip(clipId);
  if (!clickedClip)
    return;

  QStringList newSelection;

  if (isRange && !m_lastSelectedClipId.isEmpty()) {
    auto *anchorClip = findClip(m_lastSelectedClipId);
    if (anchorClip) {
      int minT = std::min(anchorClip->trackIndex(), clickedClip->trackIndex());
      int maxT = std::max(anchorClip->trackIndex(), clickedClip->trackIndex());

      int64_t minF =
          std::min(anchorClip->startFrame(), clickedClip->startFrame());
      int64_t maxF = std::max(anchorClip->endFrame(), clickedClip->endFrame());

      for (int t = minT; t <= maxT; ++t) {
        if (t < 0 || static_cast<size_t>(t) >= m_tracks.size() || !m_tracks[t])
          continue;

        for (const auto &c : m_tracks[t]->clips()) {
          if (c.startFrame() < maxF && c.endFrame() > minF) {
            QStringList linked = getLinkedClipIds(c.clipId());
            for (const auto &lid : linked) {
              if (!newSelection.contains(lid)) {
                newSelection.append(lid);
              }
            }
          }
        }
      }
    } else {
      newSelection = getLinkedClipIds(clipId);
      m_lastSelectedClipId = clipId;
    }
  } else if (toggle) {
    newSelection = m_selectedClipIds;
    QStringList targetIds = getLinkedClipIds(clipId);

    bool allIn = true;
    for (const auto &id : targetIds) {
      if (!newSelection.contains(id)) {
        allIn = false;
        break;
      }
    }

    if (allIn) {
      for (const auto &id : targetIds) {
        newSelection.removeAll(id);
      }
    } else {
      for (const auto &id : targetIds) {
        if (!newSelection.contains(id)) {
          newSelection.append(id);
        }
      }
      m_lastSelectedClipId = clipId;
    }
  } else {
    newSelection = getLinkedClipIds(clipId);
    m_lastSelectedClipId = clipId;
  }

  if (newSelection == m_selectedClipIds)
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     newSelection));
  } else {
    applyDirectSelection(newSelection);
  }
}

void TimelineModel::markDirty() {
  if (m_projectManager) {
    m_projectManager->setHasUnsavedChanges(true);
  }
}

QJsonObject TimelineModel::serialize() const {
  QJsonObject obj;
  obj["globalRippleMode"] = m_globalRippleMode;
  obj["snappingEnabled"] = m_snappingEnabled;
  obj["zoomFactor"] = m_zoomFactor;
  obj["horizontalOffset"] = m_horizontalOffset;

  QJsonArray tracksArray;
  for (const auto &track : m_tracks) {
    if (track) {
      tracksArray.append(track->serialize());
    }
  }
  obj["tracks"] = tracksArray;

  return obj;
}

void TimelineModel::deserialize(const QJsonObject &obj) {
  beginResetModel();

  m_tracks.clear();
  m_selectedClipIds.clear();
  m_selectedClipId.clear();
  m_groupDragLeaderId.clear();
  m_groupDragDeltaFrames = 0;
  m_groupDragDeltaTracks = 0;

  m_globalRippleMode = obj.value("globalRippleMode").toBool(false);
  m_snappingEnabled = obj.value("snappingEnabled").toBool(true);
  m_zoomFactor = obj.value("zoomFactor").toDouble(1.0);
  m_horizontalOffset = obj.value("horizontalOffset").toDouble(0.0);

  QJsonArray tracksArray = obj.value("tracks").toArray();
  for (const auto &trackVal : tracksArray) {
    if (trackVal.isObject()) {
      auto track = TimelineTrack::deserialize(trackVal.toObject());
      if (track) {
        m_tracks.push_back(std::move(track));
      }
    }
  }

  endResetModel();

  emit trackCountChanged();
  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit globalRippleModeChanged(m_globalRippleMode);
  emit snappingEnabledChanged(m_snappingEnabled);
  emit zoomFactorChanged(m_zoomFactor);
  emit horizontalOffsetChanged(m_horizontalOffset);
}

void TimelineModel::clearTimeline() {
  beginResetModel();
  m_tracks.clear();
  m_selectedClipIds.clear();
  m_selectedClipId.clear();
  endResetModel();
  emit trackCountChanged();
}

Q_INVOKABLE void TimelineModel::addVideoTrack() {
  int videoCount = 0;
  for (const auto &t : m_tracks) {
    if (t->kind() == TrackKind::Video) {
      videoCount++;
    }
  }

  auto track = std::make_shared<TimelineTrack>(
      QUuid::createUuid().toString(QUuid::WithoutBraces),
      QString("Video %1").arg(videoCount + 1), TrackKind::Video);

  beginInsertRows(QModelIndex(), 0, 0);
  m_tracks.insert(m_tracks.begin(), track);
  endInsertRows();

  emit trackCountChanged();
}

Q_INVOKABLE void TimelineModel::addAudioTrack() {
  int audioCount = 0;
  for (const auto &t : m_tracks) {
    if (t->kind() == TrackKind::Audio) {
      audioCount++;
    }
  }

  auto track = std::make_shared<TimelineTrack>(
      QUuid::createUuid().toString(QUuid::WithoutBraces),
      QString("Audio %1").arg(audioCount + 1), TrackKind::Audio);

  int insertIndex = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), insertIndex, insertIndex);
  m_tracks.push_back(track);
  endInsertRows();

  emit trackCountChanged();
}

void TimelineModel::createDefaultTracks(int videoCount, int audioCount) {
  beginResetModel();
  m_tracks.clear();

  for (int i = 0; i < videoCount; ++i) {
    int videoNum = videoCount - i;
    auto track = std::make_shared<TimelineTrack>(
        QUuid::createUuid().toString(QUuid::WithoutBraces),
        QString("Video %1").arg(videoNum), TrackKind::Video);
    m_tracks.push_back(track);
  }

  for (int i = 0; i < audioCount; ++i) {
    int audioNum = i + 1;
    auto track = std::make_shared<TimelineTrack>(
        QUuid::createUuid().toString(QUuid::WithoutBraces),
        QString("Audio %1").arg(audioNum), TrackKind::Audio);
    m_tracks.push_back(track);
  }

  endResetModel();
  emit trackCountChanged();
}

} // namespace xyla
