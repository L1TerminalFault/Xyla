#pragma once

#include "core/audio/audioEngine.hpp"
#include "core/audio/nodes/masterOutputNode.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"
#include <QAbstractListModel>
#include <QObject>
#include <QString>
#include <QTimer>
#include <vector>

namespace xyla {

class TimelineModel;

class MixerModel : public QAbstractListModel {
  Q_OBJECT

public:
  enum MixerRoles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    VolumeRole,
    PanRole,
    MutedRole,
    SoloRole,
    PeakLRole,
    PeakRRole,
    IsMasterRole
  };
  Q_ENUM(MixerRoles)

  explicit MixerModel(TimelineModel *timelineModel = nullptr,
                      QObject *parent = nullptr);
  ~MixerModel() override = default;

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  Q_INVOKABLE void setVolume(int rowIndex, float volume);
  Q_INVOKABLE void setPan(int rowIndex, float pan);
  Q_INVOKABLE void setMuted(int rowIndex, bool muted);
  Q_INVOKABLE void setSolo(int rowIndex, bool solo);

public slots:
  void refreshChannels();

private slots:
  void pollPeaks();

private:
  TimelineModel *m_timelineModel{nullptr};
  QTimer m_peakPollTimer;

  struct ChannelInfo {
    QString trackId;
    QString name;
    bool isMaster{false};
    audio::MixerTrackNode *trackNode{nullptr};
    float lastPeakL{0.0f};
    float lastPeakR{0.0f};
  };

  std::vector<ChannelInfo> m_channels;
};

} // namespace xyla
