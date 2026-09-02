#include "timelineModel.hpp"
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

namespace xyla {

TimelineModel::TimelineModel(ProjectManager *projectManager,
                             MediaPool *mediaPool, XylaUndoStack *undoStack,
                             QObject *parent)
    : QAbstractListModel(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool), m_undoStack(undoStack) {

  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v1", "V1", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v2", "V2", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a1", "A1", TrackKind::Audio));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a2", "A2", TrackKind::Audio));
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

void TimelineModel::selectClip(const QString &clipId, bool toggle,
                               bool isRange) {
  if (clipId.isEmpty()) {
    clearSelection();
    return;
  }

  auto *targetClip = findClip(clipId);
  if (!targetClip)
    return;

  QStringList newSelection;

  // 1. Shift+Click: 2D Spatial Bounding Range Selection
  if (isRange && !m_lastSelectedClipId.isEmpty()) {
    auto *anchorClip = findClip(m_lastSelectedClipId);
    if (anchorClip) {
      int minTrack =
          std::min(anchorClip->trackIndex(), targetClip->trackIndex());
      int maxTrack =
          std::max(anchorClip->trackIndex(), targetClip->trackIndex());

      FrameIndex minFrame =
          std::min(anchorClip->startFrame(), targetClip->startFrame());
      FrameIndex maxFrame =
          std::max(anchorClip->endFrame(), targetClip->endFrame());

      for (int t = minTrack; t <= maxTrack; ++t) {
        if (t < 0 || static_cast<size_t>(t) >= m_tracks.size() || !m_tracks[t])
          continue;

        for (const auto &c : m_tracks[t]->clips()) {
          if (c.startFrame() < maxFrame && c.endFrame() > minFrame) {
            newSelection.append(c.clipId());
          }
        }
      }
    }
  }
  // 2. Ctrl/Cmd+Click: Toggle Selection
  else if (toggle) {
    newSelection = m_selectedClipIds;
    if (newSelection.contains(clipId)) {
      newSelection.removeAll(clipId);
    } else {
      newSelection.append(clipId);
    }
  }
  // 3. Normal Single Click
  else {
    newSelection = QStringList{clipId};
  }

  if (newSelection == m_selectedClipIds)
    return;

  m_lastSelectedClipId = clipId;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     newSelection));
  } else {
    applyDirectSelection(newSelection);
  }
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
        boxSelection.append(c.clipId());
      }
    }
  }

  QStringList newSelection;
  if (toggle) {
    newSelection = m_selectedClipIds;
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

  if (newSelection == m_selectedClipIds)
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     newSelection));
  } else {
    applyDirectSelection(newSelection);
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
      !m_tracks[trackIndex])
    return "";

  int64_t clampedStart =
      m_tracks[trackIndex]->clampPlacement(startFrame, durationFrames, "");

  QString clipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  TimelineClip newClip(clipId, assetId, name, clampedStart, durationFrames,
                       sourceInFrame, trackIndex);

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<AddClipCommand>(this, newClip, trackIndex));
  } else {
    applyDirectAdd(newClip, trackIndex);
  }

  setSelectedClipId(clipId);
  return clipId;
}

bool TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             int64_t newStartFrame) {
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
    int targetTrackIdx = c.trackIndex() + deltaTracks;
    if (targetTrackIdx < 0 ||
        static_cast<size_t>(targetTrackIdx) >= m_tracks.size())
      return false;

    const auto &track = m_tracks[targetTrackIdx];
    if (!track)
      return false;

    int64_t newStart = c.startFrame() + deltaFrames;
    int64_t newEnd = newStart + c.durationFrames();

    for (const auto &other : track->clips()) {
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
  Q_UNUSED(isRipple);
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

  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size() &&
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
        clip->sourceInFrame(), newStartFrame, newDuration, newSourceInFrame));
    return true;
  }

  applyDirectTrim(clipId, trackIndex, newStartFrame, newDuration,
                  newSourceInFrame);
  return true;
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

void TimelineModel::applyDirectTrim(const QString &clipId, int trackIndex,
                                    int64_t start, int64_t dur, int64_t in) {
  auto *clip = findClip(clipId);
  if (!clip)
    return;

  clip->setStartFrame(start);
  clip->setDurationFrames(dur);
  clip->setSourceInFrame(in);
  if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size() &&
      m_tracks[trackIndex]) {
    m_tracks[trackIndex]->sortClips();
    emit trackDataChanged(trackIndex);
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
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
      static_cast<size_t>(index.row()) >= m_tracks.size()) {
    return {};
  }

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
  default:
    return {};
  }
}

QHash<int, QByteArray> TimelineModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[TrackIdRole] = "trackId";
  roles[TrackNameRole] = "trackName";
  roles[TrackKindRole] = "trackKind";
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
  QStringList targets = m_selectedClipIds;

  // If nothing is selected, cut all clips across all tracks intersecting
  // playhead
  if (targets.isEmpty()) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (!m_tracks[t])
        continue;
      auto *c = m_tracks[t]->findClipAtFrame(playheadFrame);
      if (c) {
        targets.append(c->clipId());
      }
    }
  }

  if (targets.isEmpty())
    return false;

  bool cutAny = false;
  for (const auto &id : targets) {
    if (cutClip(id, playheadFrame)) {
      cutAny = true;
    }
  }
  return cutAny;
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

  // 1. Shrink left clip
  clip->setDurationFrames(leftDuration);

  // 2. Create right clip (cloning nodes/settings)
  TimelineClip rightClip(newRightClipId, clip->assetId(), clip->name(),
                         cutFrame, rightDuration, rightSourceIn, trackIndex);
  rightClip.setSpeed(clip->speed());
  rightClip.setMuted(clip->isMuted());
  rightClip.setBlendMode(clip->blendMode());
  rightClip.setTransform(clip->positionX(), clip->positionY(), clip->scaleX(),
                         clip->scaleY(), clip->opacity());

  if (clip->nodeGraph()) {
    // Optional: clone or share graph depending on architecture. Usually sharing
    // or deep copy: rightClip.setNodeGraph(clip->nodeGraph()->clone()); // if
    // clone exists, else:
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

  // Recombine durations
  int64_t restoredDuration =
      leftClip->durationFrames() + rightClip->durationFrames();
  leftClip->setDurationFrames(restoredDuration);

  // Remove right clip
  m_tracks[trackIndex]->removeClip(rightClipId);
  m_tracks[trackIndex]->sortClips();

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
}
} // namespace xyla
