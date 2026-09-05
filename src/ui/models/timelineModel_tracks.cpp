#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QUuid>
#include <algorithm>

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

  auto it = std::find(videoTracks.begin(), videoTracks.end(), videoTrackIndex);
  size_t vRank =
      (it != videoTracks.end()) ? std::distance(videoTracks.begin(), it) : 0;

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

void TimelineModel::addVideoTrack() {
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

void TimelineModel::addAudioTrack() {
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

bool TimelineModel::isTrackLocked(int trackIndex) const {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return false;
  return m_tracks[trackIndex]->isLocked();
}

void TimelineModel::setTrackLocked(int trackIndex, bool locked) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size() ||
      !m_tracks[trackIndex])
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<xyla::LockTrackCommand>(this, trackIndex, locked));
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

  emit trackDataChanged(trackIndex);
  emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                   {TrackMutedRole});
}

void TimelineModel::toggleTrackMute(int trackIndex) {
  setTrackMuted(trackIndex, !isTrackMuted(trackIndex));
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

} // namespace xyla
