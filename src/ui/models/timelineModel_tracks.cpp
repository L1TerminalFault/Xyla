#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QUuid>
#include <algorithm>
#include <cmath>

namespace xyla {

// construction and lifecycle

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

// system bindings

ProjectManager *TimelineModel::projectManager() noexcept {
  return m_projectManager;
}

XylaUndoStack *TimelineModel::undoStack() const noexcept { return m_undoStack; }

void TimelineModel::setPlaybackManagerP(PlaybackManager *playbackManagerP) {
  m_playbackManager = playbackManagerP;
}

void TimelineModel::markDirty() {
  if (m_projectManager) {
    m_projectManager->setHasUnsavedChanges(true);
  }
}

// qabstractlistmodel overrides

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
  if (!track) {
    return {};
  }

  switch (role) {
  case TrackIdRole:
    return track->getTrackId();
  case TrackNameRole:
    return track->getName();
  case TrackKindRole:
    return static_cast<int>(track->getKind());
  case TrackLockedRole:
    return track->getIsLocked();
  case TrackMutedRole:
    return track->getIsMuted();
  case TrackSelectedRole:
    return (index.row() == m_selectedTrackIndex);
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
  roles[TrackSelectedRole] = "isTrackSelected";
  return roles;
}

// timeline metrics and navigation

qint64 TimelineModel::getDurationFrames() const {
  int64_t maxFrame = 0;
  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    for (const auto &clip : track->getClips()) {
      if (clip.getTiming().endFrame() > maxFrame) {
        maxFrame = clip.getTiming().endFrame();
      }
    }
  }
  return maxFrame;
}

double TimelineModel::getZoomFactor() const noexcept { return m_zoomFactor; }

void TimelineModel::setZoomFactor(double factor) {
  factor = std::clamp(factor, 0.1, 10.0);
  if (std::abs(m_zoomFactor - factor) > 0.0001) {
    m_zoomFactor = factor;
    emit zoomFactorChanged(m_zoomFactor);
  }
}

double TimelineModel::getHorizontalOffset() const noexcept {
  return m_horizontalOffset;
}

void TimelineModel::setHorizontalOffset(double offset) {
  offset = std::max(0.0, offset);
  if (std::abs(m_horizontalOffset - offset) > 0.0001) {
    m_horizontalOffset = offset;
    emit horizontalOffsetChanged(m_horizontalOffset);
  }
}

bool TimelineModel::getSnappingEnabled() const noexcept {
  return m_snappingEnabled;
}

void TimelineModel::setSnappingEnabled(bool enabled) {
  if (m_snappingEnabled != enabled) {
    m_snappingEnabled = enabled;
    emit snappingEnabledChanged(m_snappingEnabled);
  }
}

bool TimelineModel::getGlobalRippleMode() const noexcept {
  return m_globalRippleMode;
}

// track management

size_t TimelineModel::trackCount() const noexcept { return m_tracks.size(); }

const std::vector<std::shared_ptr<TimelineTrack>> &
TimelineModel::tracks() const noexcept {
  return m_tracks;
}

void TimelineModel::addTrack(std::shared_ptr<TimelineTrack> track) {
  if (!track)
    return;

  int insertIndex = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), insertIndex, insertIndex);
  m_tracks.push_back(std::move(track));
  endInsertRows();

  emit trackCountChanged();
  markDirty();
}

void TimelineModel::addVideoTrack() {
  int videoCount = 0;
  for (const auto &t : m_tracks) {
    if (t && t->getKind() == TrackKind::Video) {
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
  markDirty();
}

void TimelineModel::addAudioTrack() {
  int audioCount = 0;
  for (const auto &t : m_tracks) {
    if (t && t->getKind() == TrackKind::Audio) {
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
  markDirty();
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
  markDirty();
}

int TimelineModel::getTrackKind(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? static_cast<int>(track->getKind()) : -1;
}

int TimelineModel::firstAudioTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getKind() == TrackKind::Audio) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int TimelineModel::firstVideoTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getKind() == TrackKind::Video) {
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
      if (m_tracks[i]->getKind() == TrackKind::Video) {
        videoTracks.push_back(static_cast<int>(i));
      } else if (m_tracks[i]->getKind() == TrackKind::Audio) {
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

// track and clip states

bool TimelineModel::isTrackLocked(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? track->getIsLocked() : false;
}

void TimelineModel::setTrackLocked(int trackIndex, bool locked) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<xyla::LockTrackCommand>(this, trackIndex, locked));
    return;
  }
  applyDirectTrackLock(trackIndex, locked);
}

void TimelineModel::applyDirectTrackLock(int trackIndex, bool locked) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->getIsLocked() != locked) {
    track->setIsLocked(locked);
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                     {TrackLockedRole});
    markDirty();
  }
}

void TimelineModel::toggleTrackLock(int trackIndex) {
  setTrackLocked(trackIndex, !isTrackLocked(trackIndex));
}

bool TimelineModel::isTrackMuted(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? track->getIsMuted() : false;
}

void TimelineModel::setTrackMuted(int trackIndex, bool muted) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->getIsMuted() != muted) {
    track->setIsMuted(muted);
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                     {TrackMutedRole});
    markDirty();
  }
}

void TimelineModel::toggleTrackMute(int trackIndex) {
  setTrackMuted(trackIndex, !isTrackMuted(trackIndex));
}

// track selection

int TimelineModel::getSelectedTrackIndex() const noexcept {
  return m_selectedTrackIndex;
}

QString TimelineModel::getSelectedTrackId() const noexcept {
  auto *track = getTrack(m_selectedTrackIndex);
  return track ? track->getTrackId() : QString();
}

void TimelineModel::setSelectedTrackIndex(int trackIndex) {
  selectTrack(trackIndex);
}

void TimelineModel::selectTrack(int trackIndex) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size()) {
    return;
  }

  if (m_selectedTrackIndex == trackIndex) {
    return;
  }

  int prevIndex = m_selectedTrackIndex;
  m_selectedTrackIndex = trackIndex;

  if (auto *prevTrack = getTrack(prevIndex)) {
    prevTrack->setIsSelected(false);
    emit dataChanged(index(prevIndex, 0), index(prevIndex, 0),
                     {TrackSelectedRole});
  }

  if (auto *curTrack = getTrack(m_selectedTrackIndex)) {
    curTrack->setIsSelected(true);
    emit dataChanged(index(m_selectedTrackIndex, 0),
                     index(m_selectedTrackIndex, 0), {TrackSelectedRole});
  }

  emit selectedTrackIndexChanged(m_selectedTrackIndex);
}

void TimelineModel::selectTrackById(const QString &trackId) {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getTrackId() == trackId) {
      selectTrack(static_cast<int>(i));
      return;
    }
  }
}

// serialization

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
  markDirty();
}

// selection management

QString TimelineModel::getSelectedClipId() const noexcept {
  return m_selectedClipId;
}

QStringList TimelineModel::getSelectedClipIds() const noexcept {
  return m_selectedClipIds;
}

// group drag state

int TimelineModel::getGroupDragDeltaFrames() const noexcept {
  return m_groupDragDeltaFrames;
}

int TimelineModel::getGroupDragDeltaTracks() const noexcept {
  return m_groupDragDeltaTracks;
}

QString TimelineModel::getGroupDragLeaderId() const noexcept {
  return m_groupDragLeaderId;
}

void TimelineModel::updateGroupDrag(const QString &leaderId, int deltaFrames,
                                    int deltaTracks) {
  if (m_groupDragLeaderId != leaderId ||
      m_groupDragDeltaFrames != deltaFrames ||
      m_groupDragDeltaTracks != deltaTracks) {
    m_groupDragLeaderId = leaderId;
    m_groupDragDeltaFrames = deltaFrames;
    m_groupDragDeltaTracks = deltaTracks;
    emit groupDragChanged();
  }
}

void TimelineModel::clearGroupDrag() { updateGroupDrag("", 0, 0); }

xyla::TimelineTrack *TimelineModel::getTrack(int index) const noexcept {
  if (index < 0 || static_cast<size_t>(index) >= m_tracks.size()) {
    return nullptr;
  }
  return m_tracks[static_cast<size_t>(index)].get();
}
} // namespace xyla
