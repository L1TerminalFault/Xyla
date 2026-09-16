#pragma once

#include "core/actions/xylaActionManager.hpp"
#include "core/animation/keyframeContextMenuController.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineClip.hpp"
#include "core/timeline/timelineTrack.hpp"
#include "ui/models/timelineLinkGraph.hpp"
#include "ui/snapEngine.hpp"

#include <QAbstractListModel>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <qtmetamacros.h>
#include <vector>

namespace xyla {

class ProjectManager;
class MediaPool;
class XylaUndoStack;

class TimelineModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(
      qint64 durationFrames READ getDurationFrames NOTIFY durationFramesChanged)
  Q_PROPERTY(int trackCount READ rowCount NOTIFY trackCountChanged)

  Q_PROPERTY(QString selectedClipId READ getSelectedClipId WRITE
                 setSelectedClipId NOTIFY selectedClipIdChanged)
  Q_PROPERTY(QStringList selectedClipIds READ getSelectedClipIds NOTIFY
                 selectedClipsChanged)
  Q_PROPERTY(QVariantMap selectedClipData READ getSelectedClipData NOTIFY
                 selectedClipDataChanged)

  Q_PROPERTY(int selectedTrackIndex READ getSelectedTrackIndex WRITE
                 setSelectedTrackIndex NOTIFY selectedTrackIndexChanged)
  Q_PROPERTY(QString selectedTrackId READ getSelectedTrackId NOTIFY
                 selectedTrackIndexChanged)

  Q_PROPERTY(double zoomFactor READ getZoomFactor WRITE setZoomFactor NOTIFY
                 zoomFactorChanged)
  Q_PROPERTY(double horizontalOffset READ getHorizontalOffset WRITE
                 setHorizontalOffset NOTIFY horizontalOffsetChanged)

  Q_PROPERTY(bool snappingEnabled READ getSnappingEnabled WRITE
                 setSnappingEnabled NOTIFY snappingEnabledChanged)
  Q_PROPERTY(bool globalRippleMode READ getGlobalRippleMode WRITE
                 setGlobalRippleMode NOTIFY globalRippleModeChanged)

  Q_PROPERTY(int groupDragDeltaFrames READ getGroupDragDeltaFrames NOTIFY
                 groupDragChanged)
  Q_PROPERTY(int groupDragDeltaTracks READ getGroupDragDeltaTracks NOTIFY
                 groupDragChanged)
  Q_PROPERTY(QString groupDragLeaderId READ getGroupDragLeaderId NOTIFY
                 groupDragChanged)

public:
  enum TrackRoles {
    TrackIdRole = Qt::UserRole + 1,
    TrackNameRole,
    TrackKindRole,
    TrackLockedRole,
    TrackMutedRole,
    TrackSelectedRole
  };
  Q_ENUM(TrackRoles)

  explicit TimelineModel(ProjectManager *projectManager = nullptr,
                         MediaPool *mediaPool = nullptr,
                         XylaUndoStack *undoStack = nullptr,
                         QObject *parent = nullptr);
  ~TimelineModel() override = default;

  ProjectManager *projectManager() noexcept;
  [[nodiscard]] XylaUndoStack *undoStack() const noexcept;
  void setPlaybackManagerP(PlaybackManager *playbackManagerP);
  void registerActions(xyla::XylaActionManager *actionMgr,
                       xyla::PlaybackManager *playbackMgr);

  [[nodiscard]] qint64 getDurationFrames() const;
  [[nodiscard]] double getZoomFactor() const noexcept;
  void setZoomFactor(double factor);

  [[nodiscard]] double getHorizontalOffset() const noexcept;
  void setHorizontalOffset(double offset);

  [[nodiscard]] bool getSnappingEnabled() const noexcept;
  void setSnappingEnabled(bool enabled);

  [[nodiscard]] bool getGlobalRippleMode() const noexcept;
  void setGlobalRippleMode(bool enabled);

  void markDirty();

  [[nodiscard]] xyla::TimelineTrack *getTrack(int index) const noexcept;
  [[nodiscard]] size_t trackCount() const noexcept;
  [[nodiscard]] const std::vector<std::shared_ptr<TimelineTrack>> &
  tracks() const noexcept;
  void addTrack(std::shared_ptr<TimelineTrack> track);

  [[nodiscard]] int getSelectedTrackIndex() const noexcept;
  [[nodiscard]] QString getSelectedTrackId() const noexcept;
  Q_INVOKABLE void selectTrack(int trackIndex);
  Q_INVOKABLE void selectTrackById(const QString &trackId);
  void setSelectedTrackIndex(int trackIndex);

  Q_INVOKABLE int getTrackKind(int trackIndex) const;
  Q_INVOKABLE int firstAudioTrackIndex() const;
  Q_INVOKABLE int firstVideoTrackIndex() const;
  Q_INVOKABLE int findMatchingAudioTrack(int videoTrackIndex) const;

  Q_INVOKABLE void addVideoTrack();
  Q_INVOKABLE void addAudioTrack();
  Q_INVOKABLE void createDefaultTracks(int videoCount, int audioCount);

  Q_INVOKABLE bool isTrackLocked(int trackIndex) const;
  Q_INVOKABLE void setTrackLocked(int trackIndex, bool locked);
  Q_INVOKABLE void toggleTrackLock(int trackIndex);

  Q_INVOKABLE bool isTrackMuted(int trackIndex) const;
  Q_INVOKABLE void setTrackMuted(int trackIndex, bool muted);
  Q_INVOKABLE void toggleTrackMute(int trackIndex);

  Q_INVOKABLE bool isClipLocked(const QString &clipId) const;
  Q_INVOKABLE void setClipLocked(const QString &clipId, bool locked);
  Q_INVOKABLE void toggleClipLock(const QString &clipId);

  [[nodiscard]] QString getSelectedClipId() const noexcept;
  void setSelectedClipId(const QString &clipId);

  [[nodiscard]] QStringList getSelectedClipIds() const noexcept;
  [[nodiscard]] QVariantMap getSelectedClipData() const;

  Q_INVOKABLE void selectClip(const QString &clipId, bool toggle = false,
                              bool isRange = false);
  Q_INVOKABLE void selectBox(int64_t startFrame, int64_t endFrame,
                             int startTrack, int endTrack, bool toggle = false);
  Q_INVOKABLE void clearSelection();
  Q_INVOKABLE void deleteSelectedClips();

  Q_INVOKABLE void startSelectionBatch();
  Q_INVOKABLE void commitSelectionBatch();

  Q_INVOKABLE void linkSelectedClips();
  Q_INVOKABLE void unlinkSelectedClips();
  Q_INVOKABLE QStringList getLinkedClipIds(const QString &clipId) const;
  Q_INVOKABLE bool isClipOrGroupLocked(const QString &clipId) const;
  Q_INVOKABLE bool canLinkSelection() const;
  Q_INVOKABLE bool canUnlinkSelection() const;

  [[nodiscard]] TimelineClip *findClip(const QString &clipId);
  [[nodiscard]] const TimelineClip *findClip(const QString &clipId) const;
  [[nodiscard]] TimelineClip *resolveVideoClip(const QString &clipId);
  [[nodiscard]] TimelineClip *
  resolveClipForProperty(const QString &clipId,
                         const anim::PropertyDescriptor &desc);

  Q_INVOKABLE QVariantList getAllClips() const;
  Q_INVOKABLE QVariantList getClipsForTrack(int trackIndex) const;
  Q_INVOKABLE QVariantList getClipWaveformPeaks(const QString &assetId,
                                                int64_t startFrame,
                                                int64_t durationFrames,
                                                int targetPixels) const;

  Q_INVOKABLE QString addClip(const QString &assetId, const QString &name,
                              int trackIndex, int64_t startFrame,
                              int64_t durationFrames,
                              int64_t sourceInFrame = 0);
  Q_INVOKABLE bool removeClip(const QString &clipId, int trackIndex = -1);
  Q_INVOKABLE bool insertClip(const QString &assetId, int64_t sourceIn,
                              int64_t sourceOut, int64_t playheadFrame = -1,
                              int targetTrack = -1);
  Q_INVOKABLE bool overwriteClip(const QString &assetId, int64_t sourceIn,
                                 int64_t sourceOut, int64_t playheadFrame = -1,
                                 int targetTrack = -1);

  Q_INVOKABLE bool moveClip(const QString &clipId, int fromTrack, int toTrack,
                            int64_t newStartFrame);
  Q_INVOKABLE bool moveClips(const QStringList &clipIds, int64_t deltaFrames,
                             int deltaTracks);
  Q_INVOKABLE bool rippleMoveClip(const QString &clipId, int toTrack,
                                  int64_t dropFrame, bool global = false);

  Q_INVOKABLE bool trimClip(const QString &clipId, int trackIndex,
                            int64_t newStartFrame, int64_t newDuration,
                            int64_t newSourceInFrame, bool isRipple = false);
  Q_INVOKABLE bool rippleTrimToPlayhead(int64_t playheadFrame, bool trimIn);

  Q_INVOKABLE bool cutClip(const QString &clipId, int64_t frame);
  Q_INVOKABLE bool cutAtPlayhead(int64_t playheadFrame);

  Q_INVOKABLE QVariantMap querySnap(int64_t candidateStart, int64_t duration,
                                    int targetTrack, int64_t playheadFrame,
                                    double zoomFactor,
                                    const QStringList &ignoreClipIds,
                                    double snapPixelThreshold = 8.0) const;

  [[nodiscard]] int getGroupDragDeltaFrames() const noexcept;
  [[nodiscard]] int getGroupDragDeltaTracks() const noexcept;
  [[nodiscard]] QString getGroupDragLeaderId() const noexcept;
  Q_INVOKABLE void updateGroupDrag(const QString &leaderId, int deltaFrames,
                                   int deltaTracks);
  Q_INVOKABLE void clearGroupDrag();

  void applyDirectAdd(TimelineClip clip, int trackIndex);
  void applyDirectRemove(const QString &clipId, int trackIndex);
  void applyDirectMove(const QString &clipId, int srcTrack, int dstTrack,
                       int64_t newStart);
  void applyDirectTrim(const QString &clipId, int trackIndex, int64_t start,
                       int64_t dur, int64_t in, bool isRipple = false,
                       bool global = false, bool isUndo = false);
  void applyDirectCut(const QString &clipId, int trackIndex, int64_t cutFrame,
                      const QString &newRightClipId,
                      const QString &newRightGroupId = "");
  void applyDirectUncut(const QString &leftClipId, int trackIndex,
                        const QString &rightClipId);
  void applyDirectRippleMove(const QString &clipId, int srcTrack, int dstTrack,
                             int64_t dropFrame, bool global,
                             FrameIndex &outOriginalStart,
                             QString &outSplitRightId);
  void applyDirectUndoRippleMove(const QString &clipId, int srcTrack,
                                 int dstTrack, int64_t dropFrame, bool global,
                                 FrameIndex originalStart,
                                 const QString &splitRightId);
  void applyDirectLink(const QStringList &clipIds, const QString &groupId);
  void applyDirectRestoreLinkGroups(
      const std::vector<std::pair<QString, QString>> &groups);
  void applyDirectClipLock(const QString &clipId, bool locked);
  void applyDirectTrackLock(int trackIndex, bool locked);
  void applyDirectSelection(const QStringList &selection);

  Q_INVOKABLE void updateClipProperty(const QString &clipId,
                                      const QString &propertyAddress,
                                      const QVariant &value);
  Q_INVOKABLE float getClipEvaluatedProperty(const QString &clipId,
                                             const QString &propertyId,
                                             int64_t frame) const;
  Q_INVOKABLE bool hasKeyframe(const QString &clipId, const QString &propertyId,
                               int64_t frame) const;
  Q_INVOKABLE void toggleKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame,
                                  const QVariant &currentValue);
  Q_INVOKABLE void updateKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t oldFrame,
                                  int64_t newFrame, float newValue, int interp,
                                  float inX, float inY, float outX, float outY);
  Q_INVOKABLE void removeKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame);
  Q_INVOKABLE void removeKeyframes(const QVariantList &keyframeList);
  Q_INVOKABLE void moveKeyframe(const QString &clipId,
                                const QString &propertyId, int64_t oldFrame,
                                int64_t newFrame);
  Q_INVOKABLE void moveKeyframes(const QVariantList &keyframeList,
                                 int64_t deltaFrames);
  Q_INVOKABLE QVariantList getClipAnimChannels(const QString &clipId,
                                               int64_t currentFrame) const;
  Q_INVOKABLE void setClipUniformScale(const QString &clipId, bool uniform);
  void pasteKeyframes(const std::vector<anim::ClipboardKeyframe> &keys,
                      int64_t offset, anim::MergeMode mode);

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
  void clearTimeline();

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

signals:
  void durationFramesChanged();
  void visualFrameInvalidated();
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
  void deleteSelectedKeyframesRequested();
  void copyKeyframesRequested();
  void pasteKeyframesRequested();
  void selectedTrackIndexChanged(int trackIndex);

private:
  void notifyTimelineChanged(int trackA = -1, int trackB = -1);
  void shiftAllTracksAfter(FrameIndex fromFrame, int64_t deltaFrames,
                           const QString &ignoreClipId = "");

  int m_selectedTrackIndex{0};
  bool m_isBatchingSelection{false};
  QStringList m_selectionBatchStart;
  double m_zoomFactor{1.0};
  double m_horizontalOffset{0.0};

  ProjectManager *m_projectManager{nullptr};
  MediaPool *m_mediaPool{nullptr};
  PlaybackManager *m_playbackManager{nullptr};
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
  mutable SnapEngine m_snapEngine;

  TimelineLinkGraph m_linkGraph;
};

} // namespace xyla
