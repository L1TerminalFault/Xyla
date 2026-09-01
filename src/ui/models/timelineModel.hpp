#pragma once

#include "core/render/nodeGraph.hpp"
#include "core/timeline/timelineClip.hpp"
#include "core/timeline/timelineTrack.hpp"
#include <QAbstractListModel>
#include <QJSValue>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <vector>

namespace xyla {

class ProjectManager;
class MediaPool;
class XylaUndoStack;

class TimelineModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(QString selectedClipId READ selectedClipId WRITE setSelectedClipId
                 NOTIFY selectedClipIdChanged)
  Q_PROPERTY(QVariantMap selectedClipData READ selectedClipData NOTIFY
                 selectedClipDataChanged)

public:
  enum TrackRoles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    TrackKindRole
  };
  Q_ENUM(TrackRoles)

  explicit TimelineModel(ProjectManager *projectManager = nullptr,
                         MediaPool *mediaPool = nullptr,
                         XylaUndoStack *undoStack = nullptr,
                         QObject *parent = nullptr);
  ~TimelineModel() override = default;

  [[nodiscard]] QString selectedClipId() const noexcept {
    return m_selectedClipId;
  }
  void setSelectedClipId(const QString &clipId);
  [[nodiscard]] QVariantMap selectedClipData() const;

  // --- Track Accessors ---
  [[nodiscard]] size_t trackCount() const noexcept { return m_tracks.size(); }
  [[nodiscard]] TimelineTrack *getTrack(size_t index) const {
    if (index < m_tracks.size()) {
      return m_tracks[index].get();
    }
    return nullptr;
  }
  [[nodiscard]] const std::vector<std::shared_ptr<TimelineTrack>> &
  tracks() const noexcept {
    return m_tracks;
  }
  void addTrack(std::shared_ptr<TimelineTrack> track);

  // --- Timeline QML Invokables ---
  Q_INVOKABLE QVariantList getClipsForTrack(int trackIndex) const;
  Q_INVOKABLE QString addClip(const QString &assetId, const QString &name,
                              int trackIndex, int64_t startFrame,
                              int64_t durationFrames,
                              int64_t sourceInFrame = 0);
  Q_INVOKABLE bool moveClip(const QString &clipId, int fromTrack, int toTrack,
                            int64_t newStartFrame);
  Q_INVOKABLE bool trimClip(const QString &clipId, int trackIndex,
                            int64_t newStartFrame, int64_t newDuration,
                            int64_t newSourceInFrame, bool isRipple = false);
  Q_INVOKABLE bool selectClip(const QString &clipId);

  // --- Node Graph QML Invokables ---
  Q_INVOKABLE QVariantList listEditorNodes(const QString &clipId = "");
  Q_INVOKABLE QString defaultEditorNodeId(const QString &clipId = "");
  Q_INVOKABLE QString addNode(const QString &clipId, const QString &typeName,
                              double x = 0.0, double y = 0.0);
  Q_INVOKABLE bool removeNode(const QString &clipId, const QString &nodeId);
  Q_INVOKABLE bool connectSockets(const QString &clipId,
                                  const QString &fromNodeId,
                                  const QString &fromSocketId,
                                  const QString &toNodeId,
                                  const QString &toSocketId);
  Q_INVOKABLE bool disconnectSockets(const QString &clipId,
                                     const QString &fromNodeId,
                                     const QString &fromSocketId,
                                     const QString &toNodeId,
                                     const QString &toSocketId);
  Q_INVOKABLE void setNodePosition(const QString &clipId, const QString &nodeId,
                                   double x, double y);
  Q_INVOKABLE void updateSocketValue(const QString &clipId,
                                     const QString &nodeId,
                                     const QString &socketId,
                                     const QVariant &value);

  // --- Model methods ---
  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  TimelineClip *findClip(const QString &clipId);

signals:
  void selectedClipIdChanged(const QString &clipId);
  void selectedClipDataChanged();
  void trackDataChanged(int trackIndex);
  void trackCountChanged();
  void clipPropertiesChanged(const QString &clipId);

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};
  XylaUndoStack *m_undoStack{nullptr};

  QString m_selectedClipId;
  std::vector<std::shared_ptr<TimelineTrack>> m_tracks;
};

} // namespace xyla
