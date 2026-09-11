#include "core/media/mediaPool.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include "core/render/nodes/utilityNodes.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodes/transformNode.hpp"
#include "core/render/nodes/colorGradeNode.hpp"
// #include "core/render/nodes/blurNode.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodes/utilityNodes.hpp"
#include <QUuid>
#include <QUuid>

namespace xyla {

// Helper: Convert QVariant to SocketValue
static render::SocketValue qVariantToSocketValue(const QVariant &var) {
  if (!var.isValid() || var.isNull()) {
    return std::monostate{};
  }
  if (var.userType() == QMetaType::Bool) {
    return var.toBool();
  }
  if (var.userType() == QMetaType::Int) {
    return var.toInt();
  }
  if (var.userType() == QMetaType::Double || var.userType() == QMetaType::Float) {
    return var.toDouble();
  }
  if (var.userType() == QMetaType::QString) {
    return var.toString();
  }
  if (var.canConvert<QVariantList>()) {
    QVariantList list = var.toList();
    if (list.size() == 2) {
      return std::array<float, 2>{list[0].toFloat(), list[1].toFloat()};
    }
    if (list.size() == 4) {
      return std::array<float, 4>{list[0].toFloat(), list[1].toFloat(),
                                  list[2].toFloat(), list[3].toFloat()};
    }
  }
  return var.toDouble(); // Default numeric fallback
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

QVariantMap TimelineModel::selectedClipData() const {
  if (m_selectedClipId.isEmpty())
    return {};

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;
    auto *clip = m_tracks[t]->findClip(m_selectedClipId);
    if (clip) {
      QVariantMap data;
      data["clipId"] = clip->clipId();
      data["name"] = clip->name();
      data["assetId"] = clip->assetId();
      data["trackIndex"] = static_cast<int>(t); // <--- ADD THIS LINE!
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

  bool hasVideo = false;
  bool hasAudio = false;

  if (m_mediaPool) {
    auto asset = m_mediaPool->getAsset(assetId);
    if (asset) {
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    } else {
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

  if (!hasVideo && !hasAudio) {
    hasVideo = true;
  }

  std::vector<AddClipsCommand::AddClipInfo> clipsToAdd;
  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);

  // Case A: Audio Only
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

    clipsToAdd.push_back({std::move(audioClip), audioTrackIndex});
  }
  // Case B: Video (or Video + Audio)
  else {
    int videoTrackIndex = trackIndex;
    if (m_tracks[trackIndex]->kind() != TrackKind::Video) {
      int firstVideo = firstVideoTrackIndex();
      if (firstVideo != -1) {
        videoTrackIndex = firstVideo;
      }
    }

    int64_t clampedVideoStart = m_tracks[videoTrackIndex]->clampPlacement(
        startFrame, durationFrames, "");

    QString sharedGroupId =
        hasAudio ? QUuid::createUuid().toString(QUuid::WithoutBraces) : "";

    TimelineClip videoClip(primaryClipId, assetId, name, clampedVideoStart,
                           durationFrames, sourceInFrame, videoTrackIndex);
    if (!sharedGroupId.isEmpty()) {
      videoClip.setLinkGroupId(sharedGroupId);
    }

    clipsToAdd.push_back({std::move(videoClip), videoTrackIndex});

    // Linked Audio Track
    if (hasAudio) {
      int audioTrackIndex = findMatchingAudioTrack(videoTrackIndex);

      if (audioTrackIndex >= 0 &&
          static_cast<size_t>(audioTrackIndex) < m_tracks.size() &&
          m_tracks[audioTrackIndex] &&
          m_tracks[audioTrackIndex]->kind() == TrackKind::Audio) {

        QString audioClipId =
            QUuid::createUuid().toString(QUuid::WithoutBraces);
        int64_t clampedAudioStart = m_tracks[audioTrackIndex]->clampPlacement(
            startFrame, durationFrames, "");

        TimelineClip audioClip(audioClipId, assetId, name, clampedAudioStart,
                               durationFrames, sourceInFrame, audioTrackIndex);
        audioClip.setLinkGroupId(sharedGroupId);

        clipsToAdd.push_back({std::move(audioClip), audioTrackIndex});
      }
    }
  }

  // ATOMIC DISPATCH: Push all clips as a single undo step!
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
  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size() &&
      m_tracks[trackIndex]) {
    m_tracks[trackIndex]->addClip(std::move(clip));
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
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

void TimelineModel::applyDirectRemove(const QString &clipId, int trackIndex) {
  removeClip(clipId, trackIndex);
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

    auto &color = clip->color();

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
      auto *prop = clip->findAnimProperty(key);
      if (prop) {
        prop->setStaticValue(value.toFloat());
      }
    }

    emit clipPropertiesChanged(id);
  }

  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

// WARNING: ADDED JUST HERE

// Resolve graph by clip or standalone fallback
static std::shared_ptr<render::NodeGraph> resolveTargetGraph(
    TimelineModel *model, const QString &clipOrGraphId) {
  // If it's a known graph ID in the manager, return directly
  if (render::NodeGraphManager::instance().hasGraph(clipOrGraphId)) {
    return render::NodeGraphManager::instance().getGraph(clipOrGraphId);
  }
  // Otherwise check if it's a clip ID
  auto *clip = model->findClip(clipOrGraphId);
  if (clip) {
    return clip->nodeGraph();
  }
  // Fallback to standalone active graph
  return render::NodeGraphManager::instance().getGraph(model->standaloneActiveGraphId());
}

QVariantList TimelineModel::getAllProjectGraphs() const {
  return render::NodeGraphManager::instance().listAllGraphsSummary();
}

QString TimelineModel::createNewProjectGraph(const QString &name) {
  auto graph = render::NodeGraphManager::instance().createGraph(name);
  if (!graph) return "";
  markDirty();
  emit projectGraphsChanged(); // <--- EMIT HERE
  emit visualFrameInvalidated();
  return graph->id();
}
// QString TimelineModel::createNewProjectGraph(const QString &name) {
//   auto graph = render::NodeGraphManager::instance().createGraph(name);
//   if (!graph) return "";
//
//   // Pre-seed with user editable In and Out nodes
//   auto srcNode = std::make_shared<render::SourceNode>("src_in", "Video In", "");
//   srcNode->setPosition(-160.0, 0.0);
//   auto outNode = std::make_shared<render::OutputNode>("src_out", "Video Out");
//   outNode->setPosition(160.0, 0.0);
//
//   graph->addNode(srcNode);
//   graph->addNode(outNode);
//   graph->connectSockets("src_in", "video_out", "src_out", "video_in");
//
//   markDirty();
//   emit visualFrameInvalidated();
//   return graph->id();
// }

bool TimelineModel::deleteProjectGraph(const QString &graphId) {
  bool res = render::NodeGraphManager::instance().removeGraph(graphId);
  if (res) {
    // Detach from all clips in the project
    for (auto &track : m_tracks) {
      if (!track) continue;
      for (const auto &clipRef : track->clips()) {
        auto *mutableClip = track->findClip(clipRef.clipId());
        if (mutableClip) {
          mutableClip->detachNodeGraphId(graphId);
        }
      }
    }
    markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return res;
}

QString TimelineModel::getGraphName(const QString &graphId) const {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  return g ? g->name() : "";
}

void TimelineModel::setGraphName(const QString &graphId, const QString &newName) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (g && !g->isReadOnly()) {
    g->setName(newName);
    markDirty();
    emit projectGraphsChanged(); // <--- EMIT HERE
  }
}

QVariantList TimelineModel::getClipAttachedGraphs(const QString &clipId) const {
  QVariantList list;
  auto clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip) return list;

  for (size_t i = 0; i < clip->nodeGraphIds().size(); ++i) {
    const auto &gId = clip->nodeGraphIds()[i];
    auto g = render::NodeGraphManager::instance().getGraph(gId);
    if (!g) continue;

    QVariantMap m;
    m["id"] = g->id();
    m["name"] = g->name();
    m["isDefault"] = (i == 0 || gId == render::DEFAULT_IO_GRAPH_ID);
    m["isReadOnly"] = g->isReadOnly();
    list.append(m);
  }
  return list;
}

bool TimelineModel::attachGraphToClip(const QString &clipId, const QString &graphId) {
  auto clip = findClip(clipId);
  if (!clip) return false;
  clip->attachNodeGraphId(graphId);
  clip->setActiveGraphId(graphId);
  markDirty();
  emit visualFrameInvalidated();
  return true;
}

bool TimelineModel::detachGraphFromClip(const QString &clipId, const QString &graphId) {
  auto clip = findClip(clipId);
  if (!clip) return false;
  bool res = clip->detachNodeGraphId(graphId);
  if (res) {
    markDirty();
    emit visualFrameInvalidated();
  }
  return res;
}

QString TimelineModel::getClipActiveGraphId(const QString &clipId) const {
  auto clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip) return render::DEFAULT_IO_GRAPH_ID;
  return clip->activeGraphId();
}

bool TimelineModel::setClipActiveGraphId(const QString &clipId, const QString &graphId) {
  auto clip = findClip(clipId);
  if (!clip) return false;
  clip->setActiveGraphId(graphId);
  markDirty();
  emit visualFrameInvalidated();
  return true;
}

QVariantList TimelineModel::getGraphNodes(const QString &graphId) const {
  auto g = resolveTargetGraph(const_cast<TimelineModel *>(this), graphId);
  return g ? g->toVariantList() : QVariantList();
}

QVariantList TimelineModel::getGraphLinks(const QString &graphId) const {
  auto g = resolveTargetGraph(const_cast<TimelineModel *>(this), graphId);
  return g ? g->linksToVariantList() : QVariantList();
}

QString TimelineModel::addNodeToGraph(const QString &graphId, const QString &typeName, double x, double y) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return "";

  QString id = typeName.toLower() + "_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  std::shared_ptr<render::Node> node = nullptr;

  if (typeName == "Reroute") {
    node = std::make_shared<render::RerouteNode>(id);
  } else if (typeName == "CommentNode") {
    node = std::make_shared<render::CommentNode>(id, "Notes");
  } else if (typeName == "GroupNode") {
    node = std::make_shared<render::GroupNode>(id, "New Group");
  } else if (typeName == "Transform" || typeName == "TransformNode") {
    node = std::make_shared<render::TransformNode>(id, "Transform");
  } else if (typeName == "ColorGrade" || typeName == "ColorGradeNode") {
    node = std::make_shared<render::ColorGradeNode>(id, "Color Grade");
  }
  // else if (typeName == "Blur" || typeName == "BlurNode") {
  //   node = std::make_shared<render::BlurNode>(id, "Blur");
  // }

  if (node) {
    node->setPosition(x, y);
    g->addNode(node);
    markDirty();
    emit visualFrameInvalidated();
    return node->id();
  }
  return "";
}

bool TimelineModel::removeNodeFromGraph(const QString &graphId, const QString &nodeId) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return false;
  bool res = g->removeNode(nodeId);
  if (res) {
    markDirty();
    emit visualFrameInvalidated();
  }
  return res;
}

bool TimelineModel::connectGraphSockets(const QString &graphId, const QString &fromNode, const QString &fromSocket, const QString &toNode, const QString &toSocket) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return false;
  bool res = g->connectSockets(fromNode, fromSocket, toNode, toSocket);
  if (res) {
    markDirty();
    emit visualFrameInvalidated();
  }
  return res;
}

bool TimelineModel::disconnectGraphSockets(const QString &graphId, const QString &fromNode, const QString &fromSocket, const QString &toNode, const QString &toSocket) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return false;
  bool res = g->disconnectSockets(fromNode, fromSocket, toNode, toSocket);
  if (res) {
    markDirty();
    emit visualFrameInvalidated();
  }
  return res;
}

void TimelineModel::setGraphNodePosition(const QString &graphId, const QString &nodeId, double x, double y) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g) return;
  auto n = g->findNode(nodeId);
  if (n) {
    n->setPosition(x, y);
  }
}

void TimelineModel::updateGraphSocketValue(const QString &graphId, const QString &nodeId, const QString &socketId, const QVariant &value) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return;
  auto n = g->findNode(nodeId);
  if (n) {
    n->setInputSocketValue(socketId, qVariantToSocketValue(value));
    g->markDirty();
    markDirty();
    emit visualFrameInvalidated();
  }
}

QString TimelineModel::addRerouteToGraph(const QString &graphId, double x, double y) {
  return addNodeToGraph(graphId, "Reroute", x, y);
}

QString TimelineModel::addCommentToGraph(const QString &graphId, const QString &text, double x, double y, double w, double h) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return "";

  auto cNode = std::make_shared<render::CommentNode>(
      "comment_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8), text, w, h);
  cNode->setPosition(x, y);
  g->addNode(cNode);
  markDirty();
  emit visualFrameInvalidated();
  return cNode->id();
}

QString TimelineModel::createGroupInGraph(const QString &graphId, const QString &title, const QStringList &nodeIds) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g || g->isReadOnly()) return "";

  auto gNode = std::make_shared<render::GroupNode>(
      "group_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8), title);
  gNode->setMemberNodeIds(nodeIds);
  g->addNode(gNode);
  markDirty();
  emit visualFrameInvalidated();
  return gNode->id();
}

void TimelineModel::toggleGroupCollapsedInGraph(const QString &graphId, const QString &groupId) {
  auto g = resolveTargetGraph(this, graphId);
  if (!g) return;
  auto n = g->findNode(groupId);
  if (auto group = std::dynamic_pointer_cast<render::GroupNode>(n)) {
    group->setCollapsed(!group->isCollapsed());
    emit visualFrameInvalidated();
  }
}

QVariantList TimelineModel::getAvailableNodeTypes() const {
  QVariantList list;

  auto addType = [&](const QString &typeName, const QString &displayName, 
                     const QString &category, const QString &icon) {
    QVariantMap m;
    m["typeName"] = typeName;
    m["displayName"] = displayName;
    m["category"] = category;
    m["iconSource"] = icon;
    list.append(m);
  };

  // Effects
  addType("Transform", "Transform", "Spatial", "qrc:/assets/icons/maximize.svg");
  addType("ColorGrade", "Color Grade", "Color", "qrc:/assets/icons/palette.svg");
  addType("Blur", "Blur", "Filter", "qrc:/assets/icons/filter.svg");

  // Utilities
  addType("Reroute", "Reroute Dot", "Utility", "qrc:/assets/icons/circle.svg");
  addType("CommentNode", "Comment Box", "Annotation", "qrc:/assets/icons/message.svg");
  addType("GroupNode", "Group Container", "Organization", "qrc:/assets/icons/box.svg");

  return list;
}
// WARNING: ADDED JUST HERE

} // namespace xyla
