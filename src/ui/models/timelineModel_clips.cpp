#include "core/log/logger.hpp"
#include "core/media/mediaPool.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QUuid>
#include <algorithm>
#include <unordered_set>

namespace xyla {

// queries and resolvers

TimelineClip *TimelineModel::findClip(const QString &clipId) {
  if (clipId.isEmpty()) {
    return nullptr;
  }
  for (auto &track : m_tracks) {
    if (!track)
      continue;
    if (auto *c = track->findClip(clipId)) {
      return c;
    }
  }
  return nullptr;
}

QVariantMap TimelineModel::getSelectedClipData() const {
  if (m_selectedClipId.isEmpty()) {
    return {};
  }

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    const auto *clip = m_tracks[t]->findClip(m_selectedClipId);
    if (clip) {
      QVariantMap data;
      data["clipId"] = clip->getClipId();
      data["name"] = clip->getName();
      data["assetId"] = clip->getAssetId();
      data["trackIndex"] = static_cast<int>(t);
      data["startFrame"] = static_cast<double>(clip->getTiming().startFrame);
      data["durationFrames"] =
          static_cast<double>(clip->getTiming().durationFrames);
      data["sourceInFrame"] =
          static_cast<double>(clip->getTiming().sourceInFrame);
      data["trackIndex"] = static_cast<int>(t);
      data["trackKind"] = static_cast<int>(m_tracks[t]->getKind());
      data["isAudio"] = (m_tracks[t]->getKind() == TrackKind::Audio);

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip->getAssetId(), currentFps);
        if (totalFrames > 0) {
          data["sourceDurationFrames"] = static_cast<double>(totalFrames);
        }
      }

      auto graph = clip->getNodeGraph();
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

QVariantList TimelineModel::getAllClips() const {
  QVariantList all;
  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    const bool isAudioTrack = (m_tracks[t]->getKind() == TrackKind::Audio);
    const int trackKindInt = static_cast<int>(m_tracks[t]->getKind());

    for (const auto &clip : m_tracks[t]->getClips()) {
      QVariantMap map;
      map["clipId"] = clip.getClipId();
      map["name"] = clip.getName();
      map["assetId"] = clip.getAssetId();
      map["linkGroupId"] = clip.getLinkGroupId();
      map["startFrame"] = static_cast<double>(clip.getTiming().startFrame);
      map["durationFrames"] =
          static_cast<double>(clip.getTiming().durationFrames);
      map["sourceInFrame"] =
          static_cast<double>(clip.getTiming().sourceInFrame);
      map["trackIndex"] = static_cast<int>(t);

      // RESTORE TRACK KIND & IS AUDIO:
      map["trackKind"] = trackKindInt;
      map["isAudio"] = isAudioTrack;

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip.getAssetId(), currentFps);
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
  auto *track = getTrack(trackIndex);
  if (!track)
    return {};

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;
  const bool isAudioTrack = (track->getKind() == TrackKind::Audio);
  const int trackKindInt = static_cast<int>(track->getKind());

  QVariantList list;
  for (const auto &clip : track->getClips()) {
    QVariantMap map;
    map["clipId"] = clip.getClipId();
    map["name"] = clip.getName();
    map["assetId"] = clip.getAssetId();
    map["linkGroupId"] = clip.getLinkGroupId();
    map["startFrame"] = static_cast<double>(clip.getTiming().startFrame);
    map["durationFrames"] =
        static_cast<double>(clip.getTiming().durationFrames);
    map["sourceInFrame"] = static_cast<double>(clip.getTiming().sourceInFrame);
    map["trackIndex"] = trackIndex;

    // RESTORE TRACK KIND & IS AUDIO:
    map["trackKind"] = trackKindInt;
    map["isAudio"] = isAudioTrack;

    if (m_mediaPool) {
      qlonglong totalFrames =
          m_mediaPool->getAssetDurationFrames(clip.getAssetId(), currentFps);
      if (totalFrames > 0) {
        map["sourceDurationFrames"] = static_cast<double>(totalFrames);
      }
    }

    list.append(map);
  }
  return list;
}

// clip lifecycle

QString TimelineModel::addClip(const QString &assetId, const QString &name,
                               int trackIndex, int64_t startFrame,
                               int64_t durationFrames, int64_t sourceInFrame) {
  if (assetId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineModel", "addClip rejected: assetId is empty!");
    return "";
  }

  if (durationFrames <= 0) {
    XYLA_LOG_ERROR("TimelineModel",
                   std::format("addClip rejected: durationFrames must be > 0! "
                               "Received: {} for asset: '{}'",
                               durationFrames, assetId.toStdString()));
    return "";
  }

  auto *targetTrk = getTrack(trackIndex);
  if (!targetTrk) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format(
            "addClip rejected: trackIndex {} is out of range! Total tracks: {}",
            trackIndex, m_tracks.size()));
    return "";
  }

  if (targetTrk->getIsLocked()) {
    XYLA_LOG_WARN(
        "TimelineModel",
        std::format("addClip rejected: track {} is locked.", trackIndex));
    return "";
  }

  bool hasVideo = false;
  bool hasAudio = false;

  if (m_mediaPool) {
    auto asset = m_mediaPool->getAsset(assetId);
    if (!asset) {
      QString realId = m_mediaPool->getAssetId(assetId);
      if (!realId.isEmpty()) {
        asset = m_mediaPool->getAsset(realId);
      }
    }

    if (asset) {
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    } else {
      XYLA_LOG_ERROR(
          "TimelineModel",
          std::format("addClip failed: asset '{}' not found in MediaPool!",
                      assetId.toStdString()));
      return "";
    }
  } else {
    XYLA_LOG_ERROR("TimelineModel", "addClip failed: MediaPool is null!");
    return "";
  }

  std::vector<AddClipsCommand::AddClipInfo> clipsToAdd;
  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);

  // Case A: Audio Only Asset
  if (!hasVideo && hasAudio) {
    int audioTrackIndex = trackIndex;
    if (targetTrk->getKind() != TrackKind::Audio) {
      int firstAudio = firstAudioTrackIndex();
      if (firstAudio == -1) {
        XYLA_LOG_ERROR(
            "TimelineModel",
            "addClip failed: no audio tracks exist to place audio asset!");
        return "";
      }
      audioTrackIndex = firstAudio;
    }

    TimelineClipCreateInfo info{.clipId = primaryClipId,
                                .assetId = assetId,
                                .name = name,
                                .timing = {
                                    .startFrame = startFrame,
                                    .durationFrames = durationFrames,
                                    .sourceInFrame = sourceInFrame,
                                    .trackIndex = audioTrackIndex,
                                    .speed = 1.0,
                                }};

    clipsToAdd.push_back({TimelineClip(info), audioTrackIndex});
  }
  // Case B: Video (or Video + Audio)
  else {
    int videoTrackIndex = trackIndex;
    if (targetTrk->getKind() != TrackKind::Video) {
      int firstVideo = firstVideoTrackIndex();
      if (firstVideo == -1) {
        XYLA_LOG_ERROR(
            "TimelineModel",
            "addClip failed: no video tracks exist to place video asset!");
        return "";
      }
      videoTrackIndex = firstVideo;
    }

    QString sharedGroupId =
        hasAudio ? QUuid::createUuid().toString(QUuid::WithoutBraces) : "";

    TimelineClipCreateInfo videoInfo{.clipId = primaryClipId,
                                     .assetId = assetId,
                                     .name = name,
                                     .timing = {
                                         .startFrame = startFrame,
                                         .durationFrames = durationFrames,
                                         .sourceInFrame = sourceInFrame,
                                         .trackIndex = videoTrackIndex,
                                         .speed = 1.0,
                                     }};

    TimelineClip videoClip(videoInfo);
    if (!sharedGroupId.isEmpty()) {
      videoClip.setLinkGroupId(sharedGroupId);
    }
    clipsToAdd.push_back({std::move(videoClip), videoTrackIndex});

    // Linked Audio Track
    if (hasAudio) {
      int audioTrackIndex = findMatchingAudioTrack(videoTrackIndex);
      auto *audioTrk = getTrack(audioTrackIndex);

      if (audioTrk && audioTrk->getKind() == TrackKind::Audio) {
        QString audioClipId =
            QUuid::createUuid().toString(QUuid::WithoutBraces);

        TimelineClipCreateInfo audioInfo{.clipId = audioClipId,
                                         .assetId = assetId,
                                         .name = name,
                                         .timing = {
                                             .startFrame = startFrame,
                                             .durationFrames = durationFrames,
                                             .sourceInFrame = sourceInFrame,
                                             .trackIndex = audioTrackIndex,
                                             .speed = 1.0,
                                         }};

        TimelineClip audioClip(audioInfo);
        audioClip.setLinkGroupId(sharedGroupId);
        clipsToAdd.push_back({std::move(audioClip), audioTrackIndex});
      }
    }
  }

  // Atomic dispatch via undo stack
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<AddClipsCommand>(this, std::move(clipsToAdd)));
  } else {
    for (const auto &item : clipsToAdd) {
      applyDirectAdd(item.clip, item.trackIndex);
    }
    applyDirectSelection(getLinkedClipIds(primaryClipId));
  }

  return primaryClipId;
}

void TimelineModel::applyDirectAdd(TimelineClip clip, int trackIndex) {
  if (auto *track = getTrack(trackIndex)) {
    track->insertClip(std::move(clip));
    notifyTimelineChanged(trackIndex);
  }
}

bool TimelineModel::removeClip(const QString &clipId, int trackIndex) {
  if (clipId.isEmpty())
    return false;

  bool removed = false;
  int affectedTrack = -1;

  if (auto *track = getTrack(trackIndex)) {
    if (track->removeClip(clipId)) {
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
    notifyTimelineChanged(affectedTrack);
  }

  return removed;
}

void TimelineModel::applyDirectRemove(const QString &clipId, int trackIndex) {
  removeClip(clipId, trackIndex);
}

void TimelineModel::deleteSelectedClips() {
  if (m_selectedClipIds.isEmpty())
    return;

  std::vector<DeleteClipsCommand::DeletedClipInfo> toDelete;
  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      toDelete.push_back({*c, c->getTiming().trackIndex});
    }
  }

  clearSelection();

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<DeleteClipsCommand>(this, std::move(toDelete)));
  } else {
    for (const auto &info : toDelete) {
      applyDirectRemove(info.clip.getClipId(), info.trackIndex);
    }
  }
}

// selection management

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

void TimelineModel::applyDirectSelection(const QStringList &selection) {
  m_selectedClipIds = selection;
  m_selectedClipId =
      m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
  m_lastSelectedClipId = m_selectedClipId;

  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit selectedClipDataChanged();
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
    for (const auto &c : m_tracks[t]->getClips()) {
      if (c.getTiming().startFrame < maxF && c.getTiming().endFrame() > minF) {
        QStringList linked = getLinkedClipIds(c.getClipId());
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

void TimelineModel::selectClip(const QString &clipId, bool toggle,
                               bool isRange) {
  auto *clickedClip = findClip(clipId);
  if (!clickedClip)
    return;

  QStringList newSelection;

  if (isRange && !m_lastSelectedClipId.isEmpty()) {
    auto *anchorClip = findClip(m_lastSelectedClipId);
    if (anchorClip) {
      int minT = std::min(anchorClip->getTiming().trackIndex,
                          clickedClip->getTiming().trackIndex);
      int maxT = std::max(anchorClip->getTiming().trackIndex,
                          clickedClip->getTiming().trackIndex);

      int64_t minF = std::min(anchorClip->getTiming().startFrame,
                              clickedClip->getTiming().startFrame);
      int64_t maxF = std::max(anchorClip->getTiming().endFrame(),
                              clickedClip->getTiming().endFrame());

      for (int t = minT; t <= maxT; ++t) {
        if (!getTrack(t))
          continue;

        for (const auto &c : m_tracks[t]->getClips()) {
          if (c.getTiming().startFrame < maxF &&
              c.getTiming().endFrame() > minF) {
            QStringList linked = getLinkedClipIds(c.getClipId());
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

// linking

QStringList TimelineModel::getLinkedClipIds(const QString &clipId) const {
  QStringList result;
  const auto *clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip || clip->getLinkGroupId().isEmpty()) {
    if (clip)
      result.append(clipId);
    return result;
  }

  const QString &groupId = clip->getLinkGroupId();
  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    for (const auto &c : track->getClips()) {
      if (c.getLinkGroupId() == groupId) {
        result.append(c.getClipId());
      }
    }
  }
  return result;
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
    if (c->getLinkGroupId().isEmpty()) {
      return true;
    }
    if (i == 0) {
      firstGroupId = c->getLinkGroupId();
    } else if (c->getLinkGroupId() != firstGroupId) {
      allSameGroup = false;
    }
  }
  return !allSameGroup;
}

bool TimelineModel::canUnlinkSelection() const {
  for (const auto &id : m_selectedClipIds) {
    const auto *c = const_cast<TimelineModel *>(this)->findClip(id);
    if (c && !c->getLinkGroupId().isEmpty()) {
      return true;
    }
  }
  return false;
}

void TimelineModel::linkSelectedClips() {
  if (m_selectedClipIds.size() < 2)
    return;

  std::vector<std::pair<QString, QString>> previousGroups;
  for (const auto &id : m_selectedClipIds) {
    if (const auto *c = findClip(id)) {
      previousGroups.emplace_back(id, c->getLinkGroupId());
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
          previousGroups.emplace_back(lid, c->getLinkGroupId());
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

// clip locking

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

void TimelineModel::toggleClipLock(const QString &clipId) {
  setClipLocked(clipId, !isClipLocked(clipId));
}

bool TimelineModel::isClipOrGroupLocked(const QString &clipId) const {
  const auto *clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip)
    return false;

  if (clip->getIsLocked() || isTrackLocked(clip->getTiming().trackIndex)) {
    return true;
  }

  if (!clip->getLinkGroupId().isEmpty()) {
    const QString &groupId = clip->getLinkGroupId();
    for (const auto &track : m_tracks) {
      if (!track)
        continue;
      bool trackLocked = track->getIsLocked();
      for (const auto &c : track->getClips()) {
        if (c.getLinkGroupId() == groupId) {
          if (c.getIsLocked() || trackLocked)
            return true;
        }
      }
    }
  }

  return false;
}

void TimelineModel::applyDirectClipLock(const QString &clipId, bool locked) {
  QString groupId;
  if (const auto *c = findClip(clipId)) {
    groupId = c->getLinkGroupId();
  }

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (m_tracks[t]) {
      bool trackChanged = false;
      for (const auto &c : m_tracks[t]->getClips()) {
        if (c.getClipId() == clipId ||
            (!groupId.isEmpty() && c.getLinkGroupId() == groupId)) {
          if (auto *target = m_tracks[t]->findClip(c.getClipId())) {
            if (target->getIsLocked() != locked) {
              target->setIsLocked(locked);
              emit clipPropertiesChanged(c.getClipId());
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

// color property binding

void TimelineModel::updateClipColorProperty(const QString &clipId,
                                            const QString &key,
                                            const QVariant &value) {
  if (clipId.isEmpty())
    return;

  QStringList targetIds = m_selectedClipIds.contains(clipId)
                              ? m_selectedClipIds
                              : QStringList{clipId};

  for (const QString &id : targetIds) {
    auto *clip = findClip(id);
    if (!clip)
      continue;

    auto &color = clip->getColor();

    if (key == "lift") {
      QVariantList list = value.toList();
      if (list.size() >= 3) {
        color.liftR.setStaticValue(list[0].toFloat());
        color.liftG.setStaticValue(list[1].toFloat());
        color.liftB.setStaticValue(list[2].toFloat());
      }
    } else if (key == "gamma") {
      QVariantList list = value.toList();
      if (list.size() >= 3) {
        color.gammaR.setStaticValue(list[0].toFloat());
        color.gammaG.setStaticValue(list[1].toFloat());
        color.gammaB.setStaticValue(list[2].toFloat());
      }
    } else if (key == "gain") {
      QVariantList list = value.toList();
      if (list.size() >= 3) {
        color.gainR.setStaticValue(list[0].toFloat());
        color.gainG.setStaticValue(list[1].toFloat());
        color.gainB.setStaticValue(list[2].toFloat());
      }
    } else if (key == "offset") {
      QVariantList list = value.toList();
      if (list.size() >= 3) {
        color.offsetR.setStaticValue(list[0].toFloat());
        color.offsetG.setStaticValue(list[1].toFloat());
        color.offsetB.setStaticValue(list[2].toFloat());
      }
    } else {
      if (auto *prop = clip->findAnimProperty(key)) {
        prop->setStaticValue(value.toFloat());
      }
    }

    emit clipPropertiesChanged(id);
  }

  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

// 3-point editing

bool TimelineModel::insertClip(const QString &assetId, int64_t sourceIn,
                               int64_t sourceOut, int64_t playheadFrame,
                               int targetTrack) {
  if (assetId.isEmpty() || m_tracks.empty())
    return false;

  if (playheadFrame < 0) {
    playheadFrame = m_playbackManager ? m_playbackManager->currentFrame() : 0;
  }
  if (targetTrack < 0) {
    targetTrack = m_selectedTrackIndex >= 0 ? m_selectedTrackIndex
                                            : firstVideoTrackIndex();
  }
  if (!getTrack(targetTrack))
    return false;

  int64_t durationFrames = std::max<int64_t>(1, sourceOut - sourceIn + 1);

  QString assetName = "Clip";
  bool hasVideo = false;
  bool hasAudio = false;
  if (m_mediaPool) {
    if (auto asset = m_mediaPool->getAsset(assetId)) {
      assetName = asset->name();
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    }
  }
  if (!hasVideo && !hasAudio)
    hasVideo = true;

  struct TargetInfo {
    int trackIndex;
    bool isAudio;
  };
  std::vector<TargetInfo> targets;

  if (!hasVideo && hasAudio) {
    int aTrack = (getTrack(targetTrack)->getKind() == TrackKind::Audio)
                     ? targetTrack
                     : firstAudioTrackIndex();
    if (aTrack >= 0)
      targets.push_back({aTrack, true});
  } else {
    int vTrack = (getTrack(targetTrack)->getKind() == TrackKind::Video)
                     ? targetTrack
                     : firstVideoTrackIndex();
    if (vTrack >= 0)
      targets.push_back({vTrack, false});

    if (hasAudio) {
      int aTrack = findMatchingAudioTrack(vTrack);
      if (auto *tr = getTrack(aTrack)) {
        if (tr->getKind() == TrackKind::Audio)
          targets.push_back({aTrack, true});
      }
    }
  }

  if (targets.empty())
    return false;

  QString sharedGroupId =
      (targets.size() > 1) ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                           : "";
  std::vector<ThreePointEditCommand::TrackEditRecord> editRecords;

  std::unordered_set<int> tracksToRipple;
  if (m_globalRippleMode) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t] && !m_tracks[t]->getIsLocked())
        tracksToRipple.insert(static_cast<int>(t));
    }
  } else {
    for (const auto &tgt : targets)
      tracksToRipple.insert(tgt.trackIndex);
  }

  for (int tIdx : tracksToRipple) {
    auto *track = getTrack(tIdx);
    if (!track || track->getIsLocked())
      continue;

    ThreePointEditCommand::TrackEditRecord rec;
    rec.trackIndex = tIdx;
    rec.beforeClips = track->getClips();

    std::vector<TimelineClip> currentClips;

    // 1. Split any clip spanning the playhead
    for (const auto &c : track->getClips()) {
      if (c.getTiming().containsFrame(playheadFrame)) {
        // Left Piece
        TimelineClip leftClip = c;
        ClipTiming lt = leftClip.getTiming();
        lt.durationFrames = playheadFrame - c.getTiming().startFrame;
        leftClip.setTiming(lt);
        currentClips.push_back(leftClip);

        // Right Piece
        TimelineClipCreateInfo rightInfo{
            .clipId = QUuid::createUuid().toString(QUuid::WithoutBraces),
            .assetId = c.getAssetId(),
            .name = c.getName(),
            .timing = {
                .startFrame = playheadFrame,
                .durationFrames = c.getTiming().endFrame() - playheadFrame,
                .sourceInFrame = c.getTiming().sourceInFrame +
                                 (playheadFrame - c.getTiming().startFrame),
                .trackIndex = tIdx,
                .speed = c.getTiming().speed,
            }};
        currentClips.push_back(TimelineClip(rightInfo));
      } else {
        currentClips.push_back(c);
      }
    }

    // 2. Ripple downstream clips
    for (auto &c : currentClips) {
      if (c.getTiming().startFrame >= playheadFrame) {
        ClipTiming t = c.getTiming();
        t.startFrame += durationFrames;
        c.setTiming(t);
      }
    }

    // 3. Place new clip
    for (const auto &tgt : targets) {
      if (tgt.trackIndex == tIdx) {
        TimelineClipCreateInfo newInfo{
            .clipId = QUuid::createUuid().toString(QUuid::WithoutBraces),
            .assetId = assetId,
            .name = assetName,
            .timing = {
                .startFrame = playheadFrame,
                .durationFrames = durationFrames,
                .sourceInFrame = sourceIn,
                .trackIndex = tIdx,
                .speed = 1.0,
            }};
        TimelineClip newClip(newInfo);
        if (!sharedGroupId.isEmpty()) {
          newClip.setLinkGroupId(sharedGroupId);
        }
        currentClips.push_back(newClip);
      }
    }

    std::sort(currentClips.begin(), currentClips.end(),
              [](const TimelineClip &a, const TimelineClip &b) {
                return a.getTiming().startFrame < b.getTiming().startFrame;
              });

    rec.afterClips = currentClips;
    editRecords.push_back(std::move(rec));
  }

  auto cmd = std::make_unique<ThreePointEditCommand>(
      this, std::move(editRecords), "Insert Clip");
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::move(cmd));
  } else {
    cmd->redo();
  }

  return true;
}

bool TimelineModel::overwriteClip(const QString &assetId, int64_t sourceIn,
                                  int64_t sourceOut, int64_t playheadFrame,
                                  int targetTrack) {
  if (assetId.isEmpty() || m_tracks.empty())
    return false;

  if (playheadFrame < 0) {
    playheadFrame = m_playbackManager ? m_playbackManager->currentFrame() : 0;
  }
  if (targetTrack < 0) {
    targetTrack = m_selectedTrackIndex >= 0 ? m_selectedTrackIndex
                                            : firstVideoTrackIndex();
  }
  if (!getTrack(targetTrack))
    return false;

  int64_t durationFrames = std::max<int64_t>(1, sourceOut - sourceIn + 1);
  int64_t rangeStart = playheadFrame;
  int64_t rangeEnd = playheadFrame + durationFrames;

  QString assetName = "Clip";
  bool hasVideo = false;
  bool hasAudio = false;
  if (m_mediaPool) {
    if (auto asset = m_mediaPool->getAsset(assetId)) {
      assetName = asset->name();
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    }
  }
  if (!hasVideo && !hasAudio)
    hasVideo = true;

  struct TargetInfo {
    int trackIndex;
    bool isAudio;
  };
  std::vector<TargetInfo> targets;

  if (!hasVideo && hasAudio) {
    int aTrack = (getTrack(targetTrack)->getKind() == TrackKind::Audio)
                     ? targetTrack
                     : firstAudioTrackIndex();
    if (aTrack >= 0)
      targets.push_back({aTrack, true});
  } else {
    int vTrack = (getTrack(targetTrack)->getKind() == TrackKind::Video)
                     ? targetTrack
                     : firstVideoTrackIndex();
    if (vTrack >= 0)
      targets.push_back({vTrack, false});

    if (hasAudio) {
      int aTrack = findMatchingAudioTrack(vTrack);
      if (auto *tr = getTrack(aTrack)) {
        if (tr->getKind() == TrackKind::Audio)
          targets.push_back({aTrack, true});
      }
    }
  }

  if (targets.empty())
    return false;

  QString sharedGroupId =
      (targets.size() > 1) ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                           : "";
  std::vector<ThreePointEditCommand::TrackEditRecord> editRecords;

  for (const auto &tgt : targets) {
    auto *track = getTrack(tgt.trackIndex);
    if (!track || track->getIsLocked())
      continue;

    ThreePointEditCommand::TrackEditRecord rec;
    rec.trackIndex = tgt.trackIndex;
    rec.beforeClips = track->getClips();

    std::vector<TimelineClip> finalClips;

    for (const auto &c : track->getClips()) {
      if (c.getTiming().endFrame() <= rangeStart ||
          c.getTiming().startFrame >= rangeEnd) {
        finalClips.push_back(c);
        continue;
      }

      // Case 1: Overwrite inside clip -> Split
      if (c.getTiming().startFrame < rangeStart &&
          c.getTiming().endFrame() > rangeEnd) {
        TimelineClip leftClip = c;
        ClipTiming lt = leftClip.getTiming();
        lt.durationFrames = rangeStart - c.getTiming().startFrame;
        leftClip.setTiming(lt);
        finalClips.push_back(leftClip);

        TimelineClipCreateInfo rightInfo{
            .clipId = QUuid::createUuid().toString(QUuid::WithoutBraces),
            .assetId = c.getAssetId(),
            .name = c.getName(),
            .timing = {
                .startFrame = rangeEnd,
                .durationFrames = c.getTiming().endFrame() - rangeEnd,
                .sourceInFrame = c.getTiming().sourceInFrame +
                                 (rangeEnd - c.getTiming().startFrame),
                .trackIndex = tgt.trackIndex,
                .speed = c.getTiming().speed,
            }};
        finalClips.push_back(TimelineClip(rightInfo));
      }
      // Case 2: Swallowed -> Deleted
      else if (c.getTiming().startFrame >= rangeStart &&
               c.getTiming().endFrame() <= rangeEnd) {
        continue;
      }
      // Case 3: Cut tail
      else if (c.getTiming().startFrame < rangeStart &&
               c.getTiming().endFrame() <= rangeEnd) {
        TimelineClip trimmed = c;
        ClipTiming t = trimmed.getTiming();
        t.durationFrames = rangeStart - c.getTiming().startFrame;
        trimmed.setTiming(t);
        finalClips.push_back(trimmed);
      }
      // Case 4: Cut head
      else if (c.getTiming().startFrame >= rangeStart &&
               c.getTiming().endFrame() > rangeEnd) {
        TimelineClip trimmed = c;
        ClipTiming t = trimmed.getTiming();
        int64_t cutOffset = rangeEnd - c.getTiming().startFrame;
        t.startFrame = rangeEnd;
        t.durationFrames = c.getTiming().durationFrames - cutOffset;
        t.sourceInFrame = c.getTiming().sourceInFrame + cutOffset;
        trimmed.setTiming(t);
        finalClips.push_back(trimmed);
      }
    }

    TimelineClipCreateInfo newInfo{
        .clipId = QUuid::createUuid().toString(QUuid::WithoutBraces),
        .assetId = assetId,
        .name = assetName,
        .timing = {
            .startFrame = rangeStart,
            .durationFrames = durationFrames,
            .sourceInFrame = sourceIn,
            .trackIndex = tgt.trackIndex,
            .speed = 1.0,
        }};
    TimelineClip newClip(newInfo);
    if (!sharedGroupId.isEmpty()) {
      newClip.setLinkGroupId(sharedGroupId);
    }
    finalClips.push_back(newClip);

    std::sort(finalClips.begin(), finalClips.end(),
              [](const TimelineClip &a, const TimelineClip &b) {
                return a.getTiming().startFrame < b.getTiming().startFrame;
              });

    rec.afterClips = finalClips;
    editRecords.push_back(std::move(rec));
  }

  auto cmd = std::make_unique<ThreePointEditCommand>(
      this, std::move(editRecords), "Overwrite Clip");
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::move(cmd));
  } else {
    cmd->redo();
  }

  return true;
}

} // namespace xyla
