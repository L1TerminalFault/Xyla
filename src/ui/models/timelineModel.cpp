#include "timelineModel.hpp"
#include "core/media/mediaPool.hpp"
#include "core/render/nodes/colorGradeNode.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/sourceNode.hpp"
#include "core/render/nodes/transformNode.hpp"
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

      QStringList newSelection;

      for (int t = minTrack; t <= maxTrack; ++t) {
        if (t < 0 || static_cast<size_t>(t) >= m_tracks.size() || !m_tracks[t])
          continue;

        for (const auto &c : m_tracks[t]->clips()) {
          if (c.startFrame() < maxFrame && c.endFrame() > minFrame) {
            newSelection.append(c.clipId());
          }
        }
      }

      m_selectedClipIds = newSelection;
      m_selectedClipId = clipId;

      emit selectedClipsChanged(m_selectedClipIds);
      emit selectedClipIdChanged(m_selectedClipId);
      emit selectedClipDataChanged();
      return;
    }
  }

  if (toggle) {
    if (m_selectedClipIds.contains(clipId)) {
      m_selectedClipIds.removeAll(clipId);
      m_selectedClipId =
          m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
    } else {
      m_selectedClipIds.append(clipId);
      m_selectedClipId = clipId;
      m_lastSelectedClipId = clipId;
    }
    emit selectedClipsChanged(m_selectedClipIds);
    emit selectedClipIdChanged(m_selectedClipId);
    emit selectedClipDataChanged();
    return;
  }

  m_selectedClipIds = QStringList{clipId};
  m_selectedClipId = clipId;
  m_lastSelectedClipId = clipId;

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
        boxSelection.append(c.clipId());
      }
    }
  }

  if (toggle) {
    for (const auto &id : boxSelection) {
      if (m_selectedClipIds.contains(id)) {
        m_selectedClipIds.removeAll(id);
      } else {
        m_selectedClipIds.append(id);
      }
    }
  } else {
    m_selectedClipIds = boxSelection;
  }

  m_selectedClipId =
      m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();

  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit selectedClipDataChanged();
}

void TimelineModel::clearSelection() {
  if (m_selectedClipIds.isEmpty() && m_selectedClipId.isEmpty())
    return;

  m_selectedClipIds.clear();
  m_selectedClipId.clear();
  m_lastSelectedClipId.clear();

  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit selectedClipDataChanged();
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

  QStringList toDelete = m_selectedClipIds;
  clearSelection();

  std::vector<int> affectedTracks;

  for (const auto &id : toDelete) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t] && m_tracks[t]->removeClip(id)) {
        if (std::find(affectedTracks.begin(), affectedTracks.end(),
                      static_cast<int>(t)) == affectedTracks.end()) {
          affectedTracks.push_back(static_cast<int>(t));
        }
        break;
      }
    }
  }

  for (int trackIdx : affectedTracks) {
    emit trackDataChanged(trackIdx);
  }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
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
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size())
    return "";

  auto &track = m_tracks[trackIndex];
  if (!track)
    return "";

  int64_t clampedStart = track->clampPlacement(startFrame, durationFrames, "");

  QString clipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  TimelineClip newClip(clipId, assetId, name, clampedStart, durationFrames,
                       sourceInFrame, trackIndex);

  track->addClip(std::move(newClip));

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  setSelectedClipId(clipId);
  return clipId;
}

bool TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             int64_t newStartFrame) {
  if (fromTrack < 0 || static_cast<size_t>(fromTrack) >= m_tracks.size() ||
      toTrack < 0 || static_cast<size_t>(toTrack) >= m_tracks.size()) {
    return false;
  }

  auto &srcTrack = m_tracks[fromTrack];
  auto &dstTrack = m_tracks[toTrack];
  if (!srcTrack || !dstTrack)
    return false;

  auto *clip = srcTrack->findClip(clipId);
  if (!clip)
    return false;

  int64_t clampedStart =
      dstTrack->clampPlacement(newStartFrame, clip->durationFrames(), clipId);

  if (fromTrack == toTrack) {
    clip->setStartFrame(clampedStart);
    srcTrack->sortClips();
    emit trackDataChanged(fromTrack);
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    emit selectedClipDataChanged();
    return true;
  }

  TimelineClip movingClip = *clip;
  movingClip.setStartFrame(clampedStart);
  movingClip.setTrackIndex(toTrack);
  srcTrack->removeClip(clipId);
  dstTrack->addClip(std::move(movingClip));

  emit trackDataChanged(fromTrack);
  emit trackDataChanged(toTrack);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  return true;
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

  std::vector<int> affectedTracks;
  for (const auto &c : movingClips) {
    int srcTrack = c.trackIndex();
    if (m_tracks[srcTrack]->removeClip(c.clipId())) {
      if (std::find(affectedTracks.begin(), affectedTracks.end(), srcTrack) ==
          affectedTracks.end()) {
        affectedTracks.push_back(srcTrack);
      }
    }
  }

  for (auto &c : movingClips) {
    int dstTrack = c.trackIndex() + deltaTracks;
    c.setStartFrame(c.startFrame() + deltaFrames);
    c.setTrackIndex(dstTrack);

    m_tracks[dstTrack]->addClip(std::move(c));
    if (std::find(affectedTracks.begin(), affectedTracks.end(), dstTrack) ==
        affectedTracks.end()) {
      affectedTracks.push_back(dstTrack);
    }
  }

  for (int t : affectedTracks) {
    m_tracks[t]->sortClips();
    emit trackDataChanged(t);
  }

  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  return true;
}

bool TimelineModel::trimClip(const QString &clipId, int trackIndex,
                             int64_t newStartFrame, int64_t newDuration,
                             int64_t newSourceInFrame, bool isRipple) {
  Q_UNUSED(isRipple);
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size())
    return false;

  auto &track = m_tracks[trackIndex];
  if (!track)
    return false;

  auto *clip = track->findClip(clipId);
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

  newDuration = track->maxTrimDuration(newStartFrame, newDuration, clipId);

  clip->setStartFrame(newStartFrame);
  clip->setDurationFrames(newDuration);
  clip->setSourceInFrame(newSourceInFrame);
  track->sortClips();

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  return true;
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
} // namespace xyla
