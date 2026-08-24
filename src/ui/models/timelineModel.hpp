#pragma once

#include "core/timeline/timelineTrack.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include <QAbstractListModel>
#include <memory>
#include <vector>

namespace xyla {

class TimelineModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(int trackCount READ trackCount NOTIFY trackCountChanged)
  Q_PROPERTY(double zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY
                 zoomFactorChanged)

public:
  enum Roles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    TrackKindRole,
    ClipCountRole
  };
  Q_ENUM(Roles)

  explicit TimelineModel(ProjectManager *projectManager,
                         XylaUndoStack *undoStack, QObject *parent = nullptr);
  ~TimelineModel() override = default;

  [[nodiscard]] int
  rowCount(const QModelIndex &parent = QModelIndex()) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index,
                              int role = Qt::DisplayRole) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

  [[nodiscard]] int trackCount() const {
    return static_cast<int>(m_tracks.size());
  }
  [[nodiscard]] double zoomFactor() const { return m_zoomFactor; }

public slots:
  void setZoomFactor(double factor);
  void addVideoTrack(const QString &name = "");
  void addAudioTrack(const QString &name = "");

  void addClip(const QString &assetId, const QString &assetName, int trackIndex,
               qlonglong startFrame, qlonglong durationFrames,
               qlonglong sourceInFrame = 0);

  void moveClip(const QString &clipId, int fromTrack, int toTrack,
                qlonglong newStartFrame);

  void trimClip(const QString &clipId, int trackIndex, qlonglong newStartFrame,
                qlonglong newDurationFrames, qlonglong newSourceInFrame,
                bool isRipple = false);

  void removeClip(const QString &clipId, int trackIndex);

  [[nodiscard]] QVariantList getClipsForTrack(int trackIndex) const;
  [[nodiscard]] TimelineTrack *getTrack(int trackIndex);

signals:
  void trackCountChanged();
  void zoomFactorChanged();
  void trackDataChanged(int trackIndex);

private slots:
  void onActiveProjectChanged();

private:
  ProjectManager *m_projectManager{nullptr};
  XylaUndoStack *m_undoStack{nullptr};
  std::vector<std::unique_ptr<TimelineTrack>> m_tracks;
  double m_zoomFactor{1.0}; // Pixels per frame
};

} // namespace xyla
