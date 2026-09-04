#include "mixerModel.hpp"
#include "ui/models/timelineModel.hpp"
#include <qlogging.h>

namespace xyla {

MixerModel::MixerModel(TimelineModel *timelineModel, QObject *parent)
    : QAbstractListModel(parent), m_timelineModel(timelineModel) {
  if (m_timelineModel) {
    connect(m_timelineModel, &TimelineModel::trackCountChanged, this,
            &MixerModel::refreshChannels);
    connect(m_timelineModel, &TimelineModel::trackDataChanged, this,
            &MixerModel::refreshChannels);
  }
  refreshChannels();

  // Poll peaks at ~30 FPS (every 33ms) and emit dataChanged for UI meters
  m_peakPollTimer.setInterval(33);
  connect(&m_peakPollTimer, &QTimer::timeout, this, &MixerModel::pollPeaks);
  m_peakPollTimer.start();
}

void MixerModel::refreshChannels() {

  beginResetModel();
  m_channels.clear();

  auto &engine = audio::AudioEngine::instance();

  if (!m_timelineModel) {
    qDebug() << "mixermodel: timelinemodel is null";
  }
  if (m_timelineModel) {
    int count = m_timelineModel->rowCount();
    qDebug() << "MixerModel::refreshChannels – timeline has" << count
             << "tracks";
    for (int i = 0; i < count; ++i) {
      auto *track = m_timelineModel->getTrack(i);
      qDebug() << "  track" << i << "id:" << track->trackId()
               << "name:" << track->name() << "kind:" << int(track->kind());
      if (track && track->kind() == TrackKind::Audio) {
        std::string mixerNodeId = "track_" + track->trackId().toStdString();
        auto *node = dynamic_cast<audio::MixerTrackNode *>(
            engine.graph().findNode(mixerNodeId));

        ChannelInfo info;
        info.trackId = track->trackId();
        info.name = track->name();
        info.isMaster = false;
        info.trackNode = node;
        m_channels.push_back(info);
      }
    }
  }

  ChannelInfo masterInfo;
  masterInfo.trackId = "master";
  masterInfo.name = "Master";
  masterInfo.isMaster = true;
  masterInfo.trackNode = nullptr;
  m_channels.push_back(masterInfo);

  endResetModel();
}

void MixerModel::pollPeaks() {
  if (m_channels.empty())
    return;

  auto &engine = audio::AudioEngine::instance();
  auto *master = engine.masterNode();

  for (size_t i = 0; i < m_channels.size(); ++i) {
    auto &ch = m_channels[i];
    float curL = 0.0f;
    float curR = 0.0f;

    if (ch.isMaster) {
      if (master) {
        curL = master->peakL();
        curR = master->peakR();
      }
    } else if (ch.trackNode) {
      curL = ch.trackNode->peakL();
      curR = ch.trackNode->peakR();
    }

    // Only emit dataChanged if peaks moved significantly (prevents spamming Qt
    // event loop)
    if (std::abs(curL - ch.lastPeakL) > 0.001f ||
        std::abs(curR - ch.lastPeakR) > 0.001f) {
      ch.lastPeakL = curL;
      ch.lastPeakR = curR;

      QModelIndex idx = index(static_cast<int>(i), 0);
      emit dataChanged(idx, idx, {PeakLRole, PeakRRole});
    }
  }
}

int MixerModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return static_cast<int>(m_channels.size());
}

QVariant MixerModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      static_cast<size_t>(index.row()) >= m_channels.size())
    return {};

  const auto &ch = m_channels[index.row()];
  auto &engine = audio::AudioEngine::instance();

  if (ch.isMaster) {
    auto *master = engine.masterNode();
    switch (role) {
    case TrackIdRole:
      return "master";
    case TrackNameRole:
      return "Master";
    case VolumeRole:
      return master ? master->getParameterByIndex(0) : 0.8f;
    case PanRole:
      return 0.0f;
    case MutedRole:
      return false;
    case SoloRole:
      return false;
    case PeakLRole:
      return master ? master->peakL() : 0.0f;
    case PeakRRole:
      return master ? master->peakR() : 0.0f;
    case IsMasterRole:
      return true;
    default:
      return {};
    }
  } else {
    if (!ch.trackNode)
      return {};
    switch (role) {
    case TrackIdRole:
      return ch.trackId;
    case TrackNameRole:
      return ch.name;
    case VolumeRole:
      return ch.trackNode->getParameterByIndex(0);
    case PanRole:
      return ch.trackNode->getParameterByIndex(1);
    case MutedRole:
      return ch.trackNode->getParameterByIndex(2) >= 0.5f;
    case SoloRole:
      return ch.trackNode->getParameterByIndex(3) >= 0.5f;
    case PeakLRole:
      return ch.trackNode->peakL();
    case PeakRRole:
      return ch.trackNode->peakR();
    case IsMasterRole:
      return false;
    default:
      return {};
    }
  }
}

QHash<int, QByteArray> MixerModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[TrackIdRole] = "trackId";
  roles[TrackNameRole] = "trackName";
  roles[VolumeRole] = "volume";
  roles[PanRole] = "pan";
  roles[MutedRole] = "muted";
  roles[SoloRole] = "solo";
  roles[PeakLRole] = "peakL";
  roles[PeakRRole] = "peakR";
  roles[IsMasterRole] = "isMaster";
  return roles;
}

void MixerModel::setVolume(int rowIndex, float volume) {
  if (rowIndex < 0 || static_cast<size_t>(rowIndex) >= m_channels.size())
    return;
  const auto &ch = m_channels[rowIndex];
  if (ch.isMaster) {
    if (auto *master = audio::AudioEngine::instance().masterNode()) {
      master->setMasterVolume(volume);
    }
  } else if (ch.trackNode) {
    ch.trackNode->setVolume(volume);
  }
}

void MixerModel::setPan(int rowIndex, float pan) {
  if (rowIndex < 0 || static_cast<size_t>(rowIndex) >= m_channels.size())
    return;
  const auto &ch = m_channels[rowIndex];
  if (!ch.isMaster && ch.trackNode) {
    ch.trackNode->setPan(pan);
  }
}

void MixerModel::setMuted(int rowIndex, bool muted) {
  if (rowIndex < 0 || static_cast<size_t>(rowIndex) >= m_channels.size())
    return;
  const auto &ch = m_channels[rowIndex];
  if (!ch.isMaster && ch.trackNode) {
    ch.trackNode->setMuted(muted);
  }
}

void MixerModel::setSolo(int rowIndex, bool solo) {
  if (rowIndex < 0 || static_cast<size_t>(rowIndex) >= m_channels.size())
    return;
  const auto &ch = m_channels[rowIndex];
  if (!ch.isMaster && ch.trackNode) {
    ch.trackNode->setSolo(solo);
  }
}

} // namespace xyla
