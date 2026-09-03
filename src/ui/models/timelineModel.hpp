#pragma once

#include "core/render/nodeGraph.hpp"
#include "core/timeline/timelineClip.hpp"
#include "core/timeline/timelineTrack.hpp"
#include <QAbstractListModel>
#include <QJSValue>
#include <QPointer>
#include <QStringList>
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
  Q_PROPERTY(QStringList selectedClipIds READ selectedClipIds NOTIFY
                 selectedClipsChanged)
  Q_PROPERTY(bool snappingEnabled READ snappingEnabled WRITE setSnappingEnabled
                 NOTIFY snappingEnabledChanged)
  Q_PROPERTY(QVariantMap selectedClipData READ selectedClipData NOTIFY
                 selectedClipDataChanged)

  Q_PROPERTY(int groupDragDeltaFrames READ groupDragDeltaFrames NOTIFY
                 groupDragChanged)
  Q_PROPERTY(int groupDragDeltaTracks READ groupDragDeltaTracks NOTIFY
                 groupDragChanged)
  Q_PROPERTY(
      QString groupDragLeaderId READ groupDragLeaderId NOTIFY groupDragChanged)
  Q_PROPERTY(bool globalRippleMode READ globalRippleMode WRITE
                 setGlobalRippleMode NOTIFY globalRippleModeChanged)

public:
  enum TrackRoles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    TrackKindRole,
    TrackLockedRole
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
  [[nodiscard]] bool snappingEnabled() const noexcept {
    return m_snappingEnabled;
  }
  void setSnappingEnabled(bool enabled) {
    if (m_snappingEnabled != enabled) {
      m_snappingEnabled = enabled;
      emit snappingEnabledChanged(m_snappingEnabled);
    }
  }
  void setSelectedClipId(const QString &clipId);
  [[nodiscard]] QStringList selectedClipIds() const noexcept {
    return m_selectedClipIds;
  }
  [[nodiscard]] QVariantMap selectedClipData() const;

  [[nodiscard]] int groupDragDeltaFrames() const noexcept {
    return m_groupDragDeltaFrames;
  }
  [[nodiscard]] int groupDragDeltaTracks() const noexcept {
    return m_groupDragDeltaTracks;
  }
  [[nodiscard]] QString groupDragLeaderId() const noexcept {
    return m_groupDragLeaderId;
  }
  bool globalRippleMode() const noexcept { return m_globalRippleMode; }
  void setGlobalRippleMode(bool enabled);
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

  Q_INVOKABLE QVariantMap querySnap(int64_t candidateStart, int64_t duration,
                                    int targetTrack, int64_t playheadFrame,
                                    double zoomFactor,
                                    const QStringList &ignoreClipIds,
                                    double snapPixelThreshold = 8.0) const;
  Q_INVOKABLE QVariantList getAllClips() const;
  Q_INVOKABLE QVariantList getClipsForTrack(int trackIndex) const;
  Q_INVOKABLE QString addClip(const QString &assetId, const QString &name,
                              int trackIndex, int64_t startFrame,
                              int64_t durationFrames,
                              int64_t sourceInFrame = 0);
  Q_INVOKABLE bool removeClip(const QString &clipId, int trackIndex = -1);

  Q_INVOKABLE bool moveClip(const QString &clipId, int fromTrack, int toTrack,
                            int64_t newStartFrame);
  Q_INVOKABLE bool moveClips(const QStringList &clipIds, int64_t deltaFrames,
                             int deltaTracks);
  Q_INVOKABLE bool trimClip(const QString &clipId, int trackIndex,
                            int64_t newStartFrame, int64_t newDuration,
                            int64_t newSourceInFrame, bool isRipple = false);
  Q_INVOKABLE bool cutClip(const QString &clipId, int64_t frame);
  Q_INVOKABLE bool cutAtPlayhead(int64_t playheadFrame);

  // Track Locking
  Q_INVOKABLE bool isTrackLocked(int trackIndex) const;
  Q_INVOKABLE void setTrackLocked(int trackIndex, bool locked);
  Q_INVOKABLE void toggleTrackLock(int trackIndex);

  // Clip Locking
  Q_INVOKABLE bool isClipLocked(const QString &clipId) const;
  Q_INVOKABLE void setClipLocked(const QString &clipId, bool locked);
  Q_INVOKABLE void toggleClipLock(const QString &clipId);

  // linking
  Q_INVOKABLE void linkSelectedClips();
  Q_INVOKABLE void unlinkSelectedClips();
  Q_INVOKABLE QStringList getLinkedClipIds(const QString &clipId) const;
  Q_INVOKABLE bool isClipOrGroupLocked(const QString &clipId) const;
  Q_INVOKABLE bool canLinkSelection() const;
  Q_INVOKABLE bool canUnlinkSelection() const;

  // used by undo and redo
  void applyDirectLink(const QStringList &clipIds, const QString &groupId);
  void applyDirectRestoreLinkGroups(
      const std::vector<std::pair<QString, QString>> &groups);
  void applyDirectClipLock(const QString &clipId, bool locked);
  void applyDirectTrackLock(int trackIndex, bool locked);

  void applyDirectAdd(TimelineClip clip, int trackIndex);
  void applyDirectRemove(const QString &clipId, int trackIndex);
  void applyDirectMove(const QString &clipId, int srcTrack, int dstTrack,
                       int64_t newStart);
  void applyDirectTrim(const QString &clipId, int trackIndex, int64_t start,
                       int64_t dur, int64_t in);
  void applyDirectSelection(const QStringList &selection);
  void applyDirectCut(const QString &clipId, int trackIndex, int64_t cutFrame,
                      const QString &newRightClipId);
  void applyDirectUncut(const QString &leftClipId, int trackIndex,
                        const QString &rightClipId);

  Q_INVOKABLE void selectClip(const QString &clipId, bool toggle = false,
                              bool isRange = false);
  Q_INVOKABLE void selectBox(int64_t startFrame, int64_t endFrame,
                             int startTrack, int endTrack, bool toggle = false);
  Q_INVOKABLE void clearSelection();
  Q_INVOKABLE void deleteSelectedClips();

  Q_INVOKABLE void updateGroupDrag(const QString &leaderId, int deltaFrames,
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

  Q_INVOKABLE void clearGroupDrag() { updateGroupDrag("", 0, 0); }

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
  Q_INVOKABLE bool rippleMoveClip(const QString &clipId, int toTrack,
                                  int64_t dropFrame, bool global = false);

  void applyDirectRippleMove(const QString &clipId, int srcTrack, int dstTrack,
                             int64_t dropFrame, bool global,
                             FrameIndex &outOriginalStart,
                             QString &outSplitRightId);
  void applyDirectUndoRippleMove(const QString &clipId, int srcTrack,
                                 int dstTrack, int64_t dropFrame, bool global,
                                 FrameIndex originalStart,
                                 const QString &splitRightId);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  TimelineClip *findClip(const QString &clipId);

signals:
  void selectedClipIdChanged(const QString &clipId);
  void selectedClipsChanged(const QStringList &clipIds);
  void selectedClipDataChanged();
  void trackDataChanged(int trackIndex);
  void trackCountChanged();
  void clipPropertiesChanged(const QString &clipId);
  void groupDragChanged();
  void globalRippleModeChanged(bool enabled);
  void snappingEnabledChanged(bool enabled);

private:
  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};
  XylaUndoStack *m_undoStack{nullptr};

  bool m_snappingEnabled{true};
  bool m_globalRippleMode{false};
  QString m_selectedClipId;
  QString m_lastSelectedClipId;
  QStringList m_selectedClipIds;

  int m_groupDragDeltaFrames{0};
  int m_groupDragDeltaTracks{0};
  QString m_groupDragLeaderId;

  std::vector<std::shared_ptr<TimelineTrack>> m_tracks;
};

} // namespace xyla
