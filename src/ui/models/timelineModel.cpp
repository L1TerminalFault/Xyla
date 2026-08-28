#include "ui/models/timelineModel.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "core/timeline/TrimClipCommand.hpp"
#include <QThreadPool>
#include <QUuid>

namespace xyla {

// Initializes timeline model and binds project listeners
TimelineModel::TimelineModel(ProjectManager *projectManager,
                             MediaPool *mediaPool, XylaUndoStack *undoStack,
                             QObject *parent)
    : QAbstractListModel(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool), m_undoStack(undoStack) {
  if (m_projectManager) {
    connect(m_projectManager, &ProjectManager::activeProjectChanged, this,
            &TimelineModel::onActiveProjectChanged);
  }
  onActiveProjectChanged();
}

// Returns row count for track model
int TimelineModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return static_cast<int>(m_tracks.size());
}

// Retrieves data roles for timeline track delegate
QVariant TimelineModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= static_cast<int>(m_tracks.size())) {
    return {};
  }

  const auto &track = m_tracks[static_cast<size_t>(index.row())];

  switch (role) {
  case TrackIdRole:
    return track->trackId();
  case TrackNameRole:
    return track->name();
  case TrackKindRole:
    return static_cast<int>(track->kind());
  case ClipCountRole:
    return static_cast<int>(track->clips().size());
  default:
    return {};
  }
}

// Hash map of role names for QML integration
QHash<int, QByteArray> TimelineModel::roleNames() const {
  return {{TrackIdRole, "trackId"},
          {TrackNameRole, "trackName"},
          {TrackKindRole, "trackKind"},
          {ClipCountRole, "clipCount"}};
}

// Sets timeline zoom factor
void TimelineModel::setZoomFactor(double factor) {
  if (m_zoomFactor == factor)
    return;
  m_zoomFactor = std::max(0.1, factor);
  emit zoomFactorChanged();
}

// Appends video track to timeline
void TimelineModel::addVideoTrack(const QString &name) {
  int newRow = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), newRow, newRow);

  QString trackId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString trackName =
      name.isEmpty() ? QString("Video %1").arg(newRow + 1) : name;

  m_tracks.push_back(
      std::make_unique<TimelineTrack>(trackId, trackName, TrackKind::Video));
  endInsertRows();
  emit trackCountChanged();
}

// Appends audio track to timeline
void TimelineModel::addAudioTrack(const QString &name) {
  int newRow = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), newRow, newRow);

  QString trackId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString trackName =
      name.isEmpty() ? QString("Audio %1").arg(newRow + 1) : name;

  m_tracks.push_back(
      std::make_unique<TimelineTrack>(trackId, trackName, TrackKind::Audio));
  endInsertRows();
  emit trackCountChanged();
}

// Adds clip to timeline track and asynchronously pre-warms decoders, seeks
// Frame 0, and compiles GPU pipelines
void TimelineModel::addClip(const QString &assetId, const QString &assetName,
                            int trackIndex, qlonglong startFrame,
                            qlonglong durationFrames, qlonglong sourceInFrame) {
  if (trackIndex < 0 || trackIndex >= static_cast<int>(m_tracks.size()))
    return;

  QString clipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  TimelineClip clip(clipId, assetId, assetName, startFrame, durationFrames,
                    sourceInFrame, trackIndex);

  auto nodeGraph = clip.nodeGraph();

  m_tracks[static_cast<size_t>(trackIndex)]->addClip(std::move(clip));

  QThreadPool::globalInstance()->start(
      [this, assetId, sourceInFrame, nodeGraph]() {
        if (m_mediaPool) {
          auto *decoder = m_mediaPool->getDecoder(assetId);
          if (decoder) {
            decoder->seekToFrame(sourceInFrame);
            render::VideoFrameCache::instance().getFrame(assetId, sourceInFrame,
                                                         decoder);
          }
        }
        if (nodeGraph) {
          render::XylaRenderer::instance().precompileGraph(nodeGraph);
        }
      });

  emit trackDataChanged(trackIndex);
}

// Moves clip across tracks or timeline frame positions
void TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             qlonglong newStartFrame) {
  if (fromTrack < 0 || fromTrack >= static_cast<int>(m_tracks.size()))
    return;
  if (toTrack < 0 || toTrack >= static_cast<int>(m_tracks.size()))
    return;

  auto *srcTrack = m_tracks[static_cast<size_t>(fromTrack)].get();
  auto *clip = srcTrack->findClip(clipId);
  if (!clip)
    return;

  if (fromTrack == toTrack) {
    clip->setStartFrame(newStartFrame);
    srcTrack->sortClips();
    emit trackDataChanged(fromTrack);
  } else {
    TimelineClip copy = *clip;
    copy.setStartFrame(newStartFrame);
    copy.setTrackIndex(toTrack);

    srcTrack->removeClip(clipId);
    m_tracks[static_cast<size_t>(toTrack)]->addClip(std::move(copy));

    emit trackDataChanged(fromTrack);
    emit trackDataChanged(toTrack);
  }
}

// Trims clip start, duration, or source in-point
void TimelineModel::trimClip(const QString &clipId, int trackIndex,
                             qlonglong newStartFrame,
                             qlonglong newDurationFrames,
                             qlonglong newSourceInFrame, bool isRipple) {
  if (trackIndex < 0 || trackIndex >= static_cast<int>(m_tracks.size()))
    return;

  auto *track = m_tracks[static_cast<size_t>(trackIndex)].get();
  auto *clip = track->findClip(clipId);
  if (!clip)
    return;

  if (m_undoStack) {
    auto cmd = std::make_unique<TrimClipCommand>(
        track, clipId, clip->startFrame(), newStartFrame,
        clip->durationFrames(), newDurationFrames, clip->sourceInFrame(),
        newSourceInFrame, isRipple);
    m_undoStack->push(std::move(cmd));
  } else {
    qlonglong deltaDuration = newDurationFrames - clip->durationFrames();
    clip->setStartFrame(newStartFrame);
    clip->setDurationFrames(newDurationFrames);
    clip->setSourceInFrame(newSourceInFrame);

    if (isRipple && deltaDuration != 0) {
      track->rippleClipsFrom(clip->startFrame() + 1, deltaDuration, clipId);
    }
  }

  emit trackDataChanged(trackIndex);
}

// Removes clip from timeline track
void TimelineModel::removeClip(const QString &clipId, int trackIndex) {
  if (trackIndex < 0 || trackIndex >= static_cast<int>(m_tracks.size()))
    return;

  if (m_tracks[static_cast<size_t>(trackIndex)]->removeClip(clipId)) {
    emit trackDataChanged(trackIndex);
  }
}

// Returns list of clips for specified track index
QVariantList TimelineModel::getClipsForTrack(int trackIndex) const {
  if (trackIndex < 0 || trackIndex >= static_cast<int>(m_tracks.size()))
    return {};

  QVariantList list;
  const auto &clips = m_tracks[static_cast<size_t>(trackIndex)]->clips();

  for (const auto &c : clips) {
    list.append(c.toVariantMap());
  }
  return list;
}

// Returns track pointer by index
TimelineTrack *TimelineModel::getTrack(int trackIndex) {
  if (trackIndex < 0 || trackIndex >= static_cast<int>(m_tracks.size()))
    return nullptr;
  return m_tracks[static_cast<size_t>(trackIndex)].get();
}

// Resets tracks when active project changes
void TimelineModel::onActiveProjectChanged() {
  beginResetModel();
  m_tracks.clear();

  if (m_projectManager && m_projectManager->hasActiveProject()) {
    const auto *proj = m_projectManager->activeProject();
    if (proj) {
      for (int i = 0; i < proj->videoTrackCount; ++i) {
        QString trackId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QString trackName = QString("Video %1").arg(proj->videoTrackCount - i);
        m_tracks.push_back(std::make_unique<TimelineTrack>(trackId, trackName,
                                                           TrackKind::Video));
      }
      for (int i = 0; i < proj->audioTrackCount; ++i) {
        QString trackId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QString trackName = QString("Audio %1").arg(i + 1);
        m_tracks.push_back(std::make_unique<TimelineTrack>(trackId, trackName,
                                                           TrackKind::Audio));
      }
    }
  }

  endResetModel();
  emit trackCountChanged();
}

void TimelineModel::setSelectedClipId(const QString &id) {
  if (m_selectedClipId != id) {
    m_selectedClipId = id;
    emit selectedClipChanged();
  }
}

void TimelineModel::selectClip(const QString &clipId) {
  setSelectedClipId(clipId);
}

QVariantMap TimelineModel::selectedClip() const {
  return getClipById(m_selectedClipId);
}

QVariantMap TimelineModel::getClipById(const QString &clipId) const {
  if (clipId.isEmpty())
    return {};

  int count = rowCount();
  for (int i = 0; i < count; ++i) {
    QVariantList clips = getClipsForTrack(i);
    for (const QVariant &item : clips) {
      QVariantMap map = item.toMap();
      if (map["clipId"].toString() == clipId) {
        return map;
      }
    }
  }
  return {};
}

void TimelineModel::updateSocketValue(const QString &clipId,
                                      const QString &nodeId,
                                      const QString &socketId,
                                      const QVariant &value) {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (!m_tracks[i])
      continue;
    auto *clip = m_tracks[i]->findClip(clipId);
    if (clip) {
      auto graph = clip->nodeGraph();
      if (graph) {
        auto node = graph->findNode(nodeId);
        if (node) {
          render::SocketValue val;
          if (value.canConvert<QVariantList>()) {
            QVariantList list = value.toList();
            if (list.size() >= 2) {
              val = render::Vec2Val{static_cast<float>(list[0].toDouble()),
                                    static_cast<float>(list[1].toDouble())};
            }
          } else if (value.typeId() == QMetaType::Double ||
                     value.typeId() == QMetaType::Float) {
            val = static_cast<float>(value.toDouble());
          } else if (value.typeId() == QMetaType::Int) {
            val = value.toInt();
          }
          node->setInputSocketValue(socketId, val);
          emit trackDataChanged(static_cast<int>(i));
          emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
          return;
        }
      }
    }
  }
}

void TimelineModel::connectSockets(const QString &clipId,
                                   const QString &fromNode,
                                   const QString &fromSocket,
                                   const QString &toNode,
                                   const QString &toSocket) {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (!m_tracks[i])
      continue;
    auto *clip = m_tracks[i]->findClip(clipId);
    if (clip) {
      auto graph = clip->nodeGraph();
      if (graph &&
          graph->connectSockets(fromNode, fromSocket, toNode, toSocket)) {
        emit trackDataChanged(static_cast<int>(i));
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
        return;
      }
    }
  }
}

void TimelineModel::disconnectSockets(const QString &clipId,
                                      const QString &fromNode,
                                      const QString &fromSocket,
                                      const QString &toNode,
                                      const QString &toSocket) {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (!m_tracks[i])
      continue;
    auto *clip = m_tracks[i]->findClip(clipId);
    if (clip) {
      auto graph = clip->nodeGraph();
      if (graph &&
          graph->disconnectSockets(fromNode, fromSocket, toNode, toSocket)) {
        emit trackDataChanged(static_cast<int>(i));
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
        return;
      }
    }
  }
}

} // namespace xyla
