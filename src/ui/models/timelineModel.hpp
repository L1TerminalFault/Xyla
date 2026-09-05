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
  Q_PROPERTY(double zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY
                 zoomFactorChanged)
  Q_PROPERTY(double horizontalOffset READ horizontalOffset WRITE
                 setHorizontalOffset NOTIFY horizontalOffsetChanged)
  Q_PROPERTY(int trackCount READ rowCount NOTIFY trackCountChanged)
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
    TrackLockedRole,
    TrackMutedRole
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

  [[nodiscard]] QStringList selectedClipIds() const noexcept {
    return m_selectedClipIds;
  }
  [[nodiscard]] QVariantMap selectedClipData() const;

  [[nodiscard]] bool snappingEnabled() const noexcept {
    return m_snappingEnabled;
  }
  void setSnappingEnabled(bool enabled) {
    if (m_snappingEnabled != enabled) {
      m_snappingEnabled = enabled;
      emit snappingEnabledChanged(m_snappingEnabled);
    }
  }

  void markDirty();

  [[nodiscard]] int groupDragDeltaFrames() const noexcept {
    return m_groupDragDeltaFrames;
  }
  [[nodiscard]] int groupDragDeltaTracks() const noexcept {
    return m_groupDragDeltaTracks;
  }
  [[nodiscard]] QString groupDragLeaderId() const noexcept {
    return m_groupDragLeaderId;
  }
  [[nodiscard]] bool globalRippleMode() const noexcept {
    return m_globalRippleMode;
  }
  void setGlobalRippleMode(bool enabled);

  // --- Track Accessors & Navigation ---
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

  Q_INVOKABLE int getTrackKind(int trackIndex) const {
    if (trackIndex >= 0 && static_cast<size_t>(trackIndex) < m_tracks.size()) {
      return static_cast<int>(m_tracks[trackIndex]->kind());
    }
    return -1;
  }

  Q_INVOKABLE int firstAudioTrackIndex() const;
  Q_INVOKABLE int firstVideoTrackIndex() const;
  Q_INVOKABLE int findMatchingAudioTrack(int videoTrackIndex) const;

  Q_INVOKABLE void addVideoTrack();
  Q_INVOKABLE void addAudioTrack();

  Q_INVOKABLE QVariantMap querySnap(int64_t candidateStart, int64_t duration,
                                    int targetTrack, int64_t playheadFrame,
                                    double zoomFactor,
                                    const QStringList &ignoreClipIds,
                                    double snapPixelThreshold = 8.0) const;

  [[nodiscard]] double zoomFactor() const noexcept { return m_zoomFactor; }
  void setZoomFactor(double factor) {
    factor = std::clamp(factor, 0.1, 10.0);
    if (std::abs(m_zoomFactor - factor) > 0.0001) {
      m_zoomFactor = factor;
      emit zoomFactorChanged(m_zoomFactor);
    }
  }

  [[nodiscard]] double horizontalOffset() const noexcept {
    return m_horizontalOffset;
  }
  void setHorizontalOffset(double offset) {
    offset = std::max(0.0, offset);
    if (std::abs(m_horizontalOffset - offset) > 0.0001) {
      m_horizontalOffset = offset;
      emit horizontalOffsetChanged(m_horizontalOffset);
    }
  }

  Q_INVOKABLE QVariantList getAllClips() const;
  Q_INVOKABLE QVariantList getClipsForTrack(int trackIndex) const;

  // Primary ingestion entry point (auto-splits and links A/V clips)
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

  // Track Locking & Muting
  Q_INVOKABLE bool isTrackLocked(int trackIndex) const;
  Q_INVOKABLE void setTrackLocked(int trackIndex, bool locked);
  Q_INVOKABLE void toggleTrackLock(int trackIndex);

  Q_INVOKABLE bool isTrackMuted(int trackIndex) const;
  Q_INVOKABLE void setTrackMuted(int trackIndex, bool muted);
  Q_INVOKABLE void toggleTrackMute(int trackIndex);

  // Clip Locking
  Q_INVOKABLE bool isClipLocked(const QString &clipId) const;
  Q_INVOKABLE void setClipLocked(const QString &clipId, bool locked);
  Q_INVOKABLE void toggleClipLock(const QString &clipId);

  // Linking
  Q_INVOKABLE void linkSelectedClips();
  Q_INVOKABLE void unlinkSelectedClips();
  Q_INVOKABLE QStringList getLinkedClipIds(const QString &clipId) const;
  Q_INVOKABLE bool isClipOrGroupLocked(const QString &clipId) const;
  Q_INVOKABLE bool canLinkSelection() const;
  Q_INVOKABLE bool canUnlinkSelection() const;

  // Waveform Rendering helper for QML
  Q_INVOKABLE QVariantList getClipWaveformPeaks(const QString &assetId,
                                                int64_t startFrame,
                                                int64_t durationFrames,
                                                int targetPixels) const;
  // Direct mutations used by undo/redo commands
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
                       int64_t dur, int64_t in, bool isRipple = false,
                       bool global = false, bool isUndo = false);
  Q_INVOKABLE bool rippleTrimToPlayhead(int64_t playheadFrame, bool trimIn);
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
  Q_INVOKABLE void startSelectionBatch();
  Q_INVOKABLE void commitSelectionBatch();
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

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
  void clearTimeline();

  Q_INVOKABLE void createDefaultTracks(int videoCount, int audioCount);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  TimelineClip *findClip(const QString &clipId);

signals:
  void zoomFactorChanged(double zoomFactor);
  void horizontalOffsetChanged(double horizontalOffset);
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
  bool m_isBatchingSelection{false};
  QStringList m_selectionBatchStart;
  double m_zoomFactor{1.0};
  double m_horizontalOffset{0.0};
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
