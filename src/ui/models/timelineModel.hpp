#pragma once

#include "core/actions/xylaActionManager.hpp"
#include "core/animation/keyframeContextMenuController.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineClip.hpp"
#include "core/timeline/timelineTrack.hpp"
#include "core/render/nodeGraphManager.hpp"
#include <QAbstractListModel>
#include <QJSValue>
#include <QPointer>
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
  Q_PROPERTY(bool rulersEnabled READ rulersEnabled WRITE setRulersEnabled NOTIFY
                 rulersChanged)
  Q_PROPERTY(bool guidesEnabled READ guidesEnabled WRITE setGuidesEnabled NOTIFY
                 guidesChanged)
  Q_PROPERTY(bool guidesLocked READ guidesLocked WRITE setGuidesLocked NOTIFY
                 guidesChanged)
  Q_PROPERTY(
      QVariantList horizontalGuides READ horizontalGuides NOTIFY guidesChanged)
  Q_PROPERTY(
      QVariantList verticalGuides READ verticalGuides NOTIFY guidesChanged)
  Q_PROPERTY(bool actionSafeEnabled READ actionSafeEnabled WRITE
                 setActionSafeEnabled NOTIFY safeMarginsChanged)
  Q_PROPERTY(bool titleSafeEnabled READ titleSafeEnabled WRITE
                 setTitleSafeEnabled NOTIFY safeMarginsChanged)
  Q_PROPERTY(double actionSafePercent READ actionSafePercent WRITE
                 setActionSafePercent NOTIFY safeMarginsChanged)
  Q_PROPERTY(double titleSafePercent READ titleSafePercent WRITE
                 setTitleSafePercent NOTIFY safeMarginsChanged)
  Q_PROPERTY(
      qint64 durationFrames READ durationFrames NOTIFY durationFramesChanged)

  Q_PROPERTY(QString selectedClipId READ selectedClipId WRITE setSelectedClipId
                 NOTIFY selectedClipIdChanged)

  Q_PROPERTY(int selectedTrackIndex READ selectedTrackIndex WRITE
                 setSelectedTrackIndex NOTIFY selectedTrackIndexChanged)
  Q_PROPERTY(QString selectedTrackId READ selectedTrackId NOTIFY
                 selectedTrackIndexChanged)

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
    TrackMutedRole,
    TrackSelectedRole
  };
  Q_ENUM(TrackRoles)

  [[nodiscard]] bool rulersEnabled() const noexcept { return m_rulersEnabled; }
  void setRulersEnabled(bool e) {
    if (m_rulersEnabled != e) {
      m_rulersEnabled = e;
      emit rulersChanged();
      markDirty();
    }
  }

  [[nodiscard]] bool guidesEnabled() const noexcept { return m_guidesEnabled; }
  void setGuidesEnabled(bool e) {
    if (m_guidesEnabled != e) {
      m_guidesEnabled = e;
      emit guidesChanged();
      markDirty();
    }
  }

  [[nodiscard]] bool guidesLocked() const noexcept { return m_guidesLocked; }
  void setGuidesLocked(bool l) {
    if (m_guidesLocked != l) {
      m_guidesLocked = l;
      emit guidesChanged();
      markDirty();
    }
  }

  [[nodiscard]] QVariantList horizontalGuides() const {
    return m_horizontalGuides;
  }
  [[nodiscard]] QVariantList verticalGuides() const { return m_verticalGuides; }

  Q_INVOKABLE void addGuide(const QString &orientation, double pos) {
    if (orientation == "horizontal")
      m_horizontalGuides.append(pos);
    else if (orientation == "vertical")
      m_verticalGuides.append(pos);
    emit guidesChanged();
    markDirty();
  }

  Q_INVOKABLE void updateGuide(const QString &orientation, int index,
                               double newPos) {
    if (orientation == "horizontal" && index >= 0 &&
        index < m_horizontalGuides.size()) {
      m_horizontalGuides[index] = newPos;
    } else if (orientation == "vertical" && index >= 0 &&
               index < m_verticalGuides.size()) {
      m_verticalGuides[index] = newPos;
    }
    emit guidesChanged();
    markDirty();
  }

  Q_INVOKABLE void removeGuide(const QString &orientation, int index) {
    if (orientation == "horizontal" && index >= 0 &&
        index < m_horizontalGuides.size()) {
      m_horizontalGuides.removeAt(index);
    } else if (orientation == "vertical" && index >= 0 &&
               index < m_verticalGuides.size()) {
      m_verticalGuides.removeAt(index);
    }
    emit guidesChanged();
    markDirty();
  }

  Q_INVOKABLE void clearAllGuides() {
    if (!m_horizontalGuides.isEmpty() || !m_verticalGuides.isEmpty()) {
      m_horizontalGuides.clear();
      m_verticalGuides.clear();
      emit guidesChanged();
      markDirty();
    }
  }
  [[nodiscard]] bool actionSafeEnabled() const noexcept {
    return m_actionSafeEnabled;
  }
  void setActionSafeEnabled(bool enabled) {
    if (m_actionSafeEnabled != enabled) {
      m_actionSafeEnabled = enabled;
      emit safeMarginsChanged();
      markDirty();
    }
  }

  [[nodiscard]] bool titleSafeEnabled() const noexcept {
    return m_titleSafeEnabled;
  }
  void setTitleSafeEnabled(bool enabled) {
    if (m_titleSafeEnabled != enabled) {
      m_titleSafeEnabled = enabled;
      emit safeMarginsChanged();
      markDirty();
    }
  }

  [[nodiscard]] double actionSafePercent() const noexcept {
    return m_actionSafePercent;
  }
  void setActionSafePercent(double percent) {
    percent = std::clamp(percent, 50.0, 99.0);
    if (std::abs(m_actionSafePercent - percent) > 0.01) {
      m_actionSafePercent = percent;
      emit safeMarginsChanged();
      markDirty();
    }
  }

  [[nodiscard]] double titleSafePercent() const noexcept {
    return m_titleSafePercent;
  }
  void setTitleSafePercent(double percent) {
    percent = std::clamp(percent, 40.0, 95.0);
    if (std::abs(m_titleSafePercent - percent) > 0.01) {
      m_titleSafePercent = percent;
      emit safeMarginsChanged();
      markDirty();
    }
  }
  void registerActions(xyla::XylaActionManager *actionMgr,
                       xyla::PlaybackManager *playbackMgr);

  [[nodiscard]] qint64 durationFrames() const {
    int64_t maxFrame = 0;
    for (const auto &track : m_tracks) {
      if (!track)
        continue;
      for (const auto &clip : track->clips()) {
        if (clip.endFrame() > maxFrame) {
          maxFrame = clip.endFrame();
        }
      }
    }
    return maxFrame;
  }

  explicit TimelineModel(ProjectManager *projectManager = nullptr,
                         MediaPool *mediaPool = nullptr,
                         XylaUndoStack *undoStack = nullptr,
                         QObject *parent = nullptr);
  ~TimelineModel() override = default;

  [[nodiscard]] QString selectedClipId() const noexcept {
    return m_selectedClipId;
  }
  Q_INVOKABLE void updateClipColorProperty(const QString &clipId,
                                           const QString &key,
                                           const QVariant &value);

  Q_INVOKABLE bool insertClip(const QString &assetId, int64_t sourceIn,
                              int64_t sourceOut, int64_t playheadFrame = -1,
                              int targetTrack = -1);

  Q_INVOKABLE bool overwriteClip(const QString &assetId, int64_t sourceIn,
                                 int64_t sourceOut, int64_t playheadFrame = -1,
                                 int targetTrack = -1);

  Q_INVOKABLE void updateKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t oldFrame,
                                  int64_t newFrame, float newValue, int interp,
                                  float inX, float inY, float outX, float outY);

  Q_INVOKABLE
  void removeKeyframes(const QVariantList &keyframeList);

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


  // WARNING: ADDED JUST HERE
// ===========================================================================
  // DECOUPLED NODE GRAPH SYSTEM (Works with or without a selected clip)
  // ===========================================================================
  // Active standalone graph being inspected/edited when no clip is selected
  Q_INVOKABLE QString standaloneActiveGraphId() const { return m_standaloneActiveGraphId; }
  Q_INVOKABLE void setStandaloneActiveGraphId(const QString &graphId) {
    m_standaloneActiveGraphId = graphId;
    emit activeGraphChanged();
  }

  // Returns list of all available node types that can be created in the editor
  Q_INVOKABLE QVariantList getAvailableNodeTypes() const;

  // Query and manage all project-level graphs
  Q_INVOKABLE QVariantList getAllProjectGraphs() const;
  Q_INVOKABLE QString createNewProjectGraph(const QString &name = "New Graph");
  Q_INVOKABLE bool deleteProjectGraph(const QString &graphId);
  Q_INVOKABLE QString getGraphName(const QString &graphId) const;
  Q_INVOKABLE void setGraphName(const QString &graphId, const QString &newName);

  // Clip Graph References
  Q_INVOKABLE QVariantList getClipAttachedGraphs(const QString &clipId) const;
  Q_INVOKABLE bool attachGraphToClip(const QString &clipId, const QString &graphId);
  Q_INVOKABLE bool detachGraphFromClip(const QString &clipId, const QString &graphId);
  Q_INVOKABLE QString getClipActiveGraphId(const QString &clipId) const;
  Q_INVOKABLE bool setClipActiveGraphId(const QString &clipId, const QString &graphId);

  // Direct Graph Mutation by GraphId (Works even if clipId is empty!)
  Q_INVOKABLE QVariantList getGraphNodes(const QString &graphId) const;
  Q_INVOKABLE QVariantList getGraphLinks(const QString &graphId) const;
  Q_INVOKABLE QString addNodeToGraph(const QString &graphId, const QString &typeName, double x = 0.0, double y = 0.0);
  Q_INVOKABLE bool removeNodeFromGraph(const QString &graphId, const QString &nodeId);
  Q_INVOKABLE bool connectGraphSockets(const QString &graphId, const QString &fromNode, const QString &fromSocket, const QString &toNode, const QString &toSocket);
  Q_INVOKABLE bool disconnectGraphSockets(const QString &graphId, const QString &fromNode, const QString &fromSocket, const QString &toNode, const QString &toSocket);
  Q_INVOKABLE void setGraphNodePosition(const QString &graphId, const QString &nodeId, double x, double y);
  Q_INVOKABLE void updateGraphSocketValue(const QString &graphId, const QString &nodeId, const QString &socketId, const QVariant &value);

  // Special Nodes (Reroute, Comment, Group)
  Q_INVOKABLE QString addRerouteToGraph(const QString &graphId, double x, double y);
  Q_INVOKABLE QString addCommentToGraph(const QString &graphId, const QString &text, double x, double y, double w, double h);
  Q_INVOKABLE QString createGroupInGraph(const QString &graphId, const QString &title, const QStringList &nodeIds);
  Q_INVOKABLE void toggleGroupCollapsedInGraph(const QString &graphId, const QString &groupId);

  // WARNING: ADDED JUST HERE


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
                      const QString &newRightClipId,
                      const QString &newRightGroupId = "");
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

  Q_INVOKABLE void updateClipTransformProperty(const QString &clipId,
                                               const QString &key,
                                               const QVariant &value);
  Q_INVOKABLE float getClipEvaluatedProperty(const QString &clipId,
                                             const QString &propertyId,
                                             int64_t frame) const;
  Q_INVOKABLE void updateClipAudioProperty(const QString &clipId,
                                           const QString &key,
                                           const QVariant &value);
  Q_INVOKABLE bool hasKeyframe(const QString &clipId, const QString &propertyId,
                               int64_t frame) const;
  Q_INVOKABLE void toggleKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame,
                                  const QVariant &currentValue);
  [[nodiscard]] TimelineClip *resolveVideoClip(const QString &clipId);

  // Returns the specific clip in the clip's link group that handles the given
  TimelineClip *resolveClipForProperty(const QString &clipId,
                                       const anim::PropertyDescriptor &desc);

  Q_INVOKABLE void removeKeyframe(const QString &clipId,
                                  const QString &propertyId, int64_t frame);
  Q_INVOKABLE void moveKeyframe(const QString &clipId,
                                const QString &propertyId, int64_t oldFrame,
                                int64_t newFrame);
  Q_INVOKABLE void moveKeyframes(const QVariantList &keyframeList,
                                 int64_t deltaFrames);
  Q_INVOKABLE QVariantList getClipAnimChannels(const QString &clipId,
                                               int64_t currentFrame) const;
  Q_INVOKABLE void setClipUniformScale(const QString &clipId, bool uniform);
  void setPlaybackManagerP(PlaybackManager *playbackManagerP) {
    m_playbackManager = playbackManagerP;
  }
  void pasteKeyframes(const std::vector<anim::ClipboardKeyframe> &keys,
                      int64_t offset, anim::MergeMode mode);
  [[nodiscard]] XylaUndoStack *undoStack() const noexcept {
    return m_undoStack;
  }

  [[nodiscard]] int selectedTrackIndex() const noexcept {
    return m_selectedTrackIndex;
  }
  [[nodiscard]] QString selectedTrackId() const noexcept {
    if (m_selectedTrackIndex >= 0 &&
        static_cast<size_t>(m_selectedTrackIndex) < m_tracks.size()) {
      return m_tracks[m_selectedTrackIndex]->trackId();
    }
    return QString();
  }

  Q_INVOKABLE void selectTrack(int trackIndex);
  Q_INVOKABLE void selectTrackById(const QString &trackId);
  void setSelectedTrackIndex(int trackIndex) { selectTrack(trackIndex); }
signals:
  void rulersChanged();
  void guidesChanged();
  void safeMarginsChanged();
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
  void activeGraphChanged();
  void projectGraphsChanged();

private:
  bool m_rulersEnabled{false};
  bool m_guidesEnabled{true};
  bool m_guidesLocked{false};
  QVariantList m_horizontalGuides;
  QVariantList m_verticalGuides;
  bool m_actionSafeEnabled{false};
  bool m_titleSafeEnabled{false};
  double m_actionSafePercent{90.0};
  double m_titleSafePercent{80.0};
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

  QString m_standaloneActiveGraphId{render::DEFAULT_IO_GRAPH_ID};
};

} // namespace xyla
