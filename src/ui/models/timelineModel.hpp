#pragma once

#include "core/media/mediaPool.hpp"
#include "core/timeline/timelineTrack.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include <QAbstractListModel>
#include <memory>
#include <vector>

namespace xyla {

class TimelineModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int trackCount READ rowCount NOTIFY trackCountChanged)
  Q_PROPERTY(double zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY
                 zoomFactorChanged)

public:
  enum Roles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    TrackKindRole,
    ClipCountRole
  };

  explicit TimelineModel(ProjectManager *projectManager, MediaPool *mediaPool,
                         XylaUndoStack *undoStack, QObject *parent = nullptr);
  ~TimelineModel() override = default;

  [[nodiscard]] int
  rowCount(const QModelIndex &parent = QModelIndex()) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index,
                              int role = Qt::DisplayRole) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

  [[nodiscard]] double zoomFactor() const noexcept { return m_zoomFactor; }
  void setZoomFactor(double factor);

  Q_INVOKABLE void addVideoTrack(const QString &name = {});
  Q_INVOKABLE void addAudioTrack(const QString &name = {});

  Q_INVOKABLE void addClip(const QString &assetId, const QString &assetName,
                           int trackIndex, qlonglong startFrame,
                           qlonglong durationFrames, qlonglong sourceInFrame);

  Q_INVOKABLE void moveClip(const QString &clipId, int fromTrack, int toTrack,
                            qlonglong newStartFrame);

  Q_INVOKABLE void trimClip(const QString &clipId, int trackIndex,
                            qlonglong newStartFrame,
                            qlonglong newDurationFrames,
                            qlonglong newSourceInFrame, bool isRipple = false);

  Q_INVOKABLE void removeClip(const QString &clipId, int trackIndex);

  Q_INVOKABLE QVariantList getClipsForTrack(int trackIndex) const;

  TimelineTrack *getTrack(int trackIndex);

signals:
  void trackCountChanged();
  void zoomFactorChanged();
  void trackDataChanged(int trackIndex);

private slots:
  void onActiveProjectChanged();

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};
  XylaUndoStack *m_undoStack{nullptr};

  std::vector<std::unique_ptr<TimelineTrack>> m_tracks;
  double m_zoomFactor{1.0};
};

} // namespace xyla
