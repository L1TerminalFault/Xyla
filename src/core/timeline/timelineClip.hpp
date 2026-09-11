// #pragma once
//
// #include "core/animation/animProperty.hpp"
// #include "core/animation/propertyDescriptor.hpp"
// #include "core/render/nodeGraph.hpp"
// #include "core/timeline/clipIntrinsicData.hpp"
// #include "timelineTypes.hpp"
//
// #include <QJsonObject>
// #include <QString>
// #include <QVariantList>
// #include <QVariantMap>
// #include <algorithm>
// #include <memory>
// #include <vector>
//
// namespace xyla {
//
// class TimelineClip {
// public:
//   TimelineClip(QString clipId, QString assetId, QString name,
//                FrameIndex startFrame, FrameIndex durationFrames,
//                FrameIndex sourceInFrame = 0, int trackIndex = 0)
//       : m_clipId(std::move(clipId)), m_assetId(std::move(assetId)),
//         m_name(std::move(name)), m_startFrame(startFrame),
//         m_durationFrames(durationFrames), m_sourceInFrame(sourceInFrame),
//         m_trackIndex(trackIndex),
//         m_nodeGraph(render::NodeGraph::createDefaultClipGraph(m_assetId)) {}
//
//   [[nodiscard]] QJsonObject serialize() const;
//   static TimelineClip deserialize(const QJsonObject &obj);
//
//   [[nodiscard]] QVariantMap toVariantMap() const;
//
//   [[nodiscard]] anim::AnimProperty *findAnimProperty(const QString &key);
//   [[nodiscard]] const anim::AnimProperty *
//   findAnimProperty(const QString &key) const;
//
//   // Returns descriptors for every property this clip owns.
//   // Filtering by track kind (Video / Audio) is done by the caller.
//   [[nodiscard]] std::vector<const anim::PropertyDescriptor *>
//   animatableProperties() const;
//
//   [[nodiscard]] const QString &clipId() const noexcept { return m_clipId; }
//   [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
//   [[nodiscard]] const QString &name() const noexcept { return m_name; }
//   [[nodiscard]] FrameIndex startFrame() const noexcept { return m_startFrame; }
//   [[nodiscard]] FrameIndex durationFrames() const noexcept {
//     return m_durationFrames;
//   }
//   [[nodiscard]] FrameIndex endFrame() const noexcept {
//     return m_startFrame + m_durationFrames;
//   }
//   [[nodiscard]] FrameIndex sourceInFrame() const noexcept {
//     return m_sourceInFrame;
//   }
//   [[nodiscard]] FrameIndex sourceOutFrame() const noexcept {
//     return m_sourceInFrame + m_durationFrames;
//   }
//   [[nodiscard]] int trackIndex() const noexcept { return m_trackIndex; }
//   [[nodiscard]] double speed() const noexcept { return m_speed; }
//   [[nodiscard]] bool isMuted() const noexcept { return m_isMuted; }
//   [[nodiscard]] int blendMode() const noexcept { return m_blendMode; }
//   [[nodiscard]] bool isLocked() const noexcept { return m_isLocked; }
//   void setLocked(bool locked) noexcept { m_isLocked = locked; }
//
//   void setStartFrame(FrameIndex frame) noexcept { m_startFrame = frame; }
//   void setDurationFrames(FrameIndex duration) noexcept {
//     m_durationFrames = std::max<FrameIndex>(1, duration);
//   }
//   void setSourceInFrame(FrameIndex frame) noexcept {
//     m_sourceInFrame = std::max<FrameIndex>(0, frame);
//   }
//   void setTrackIndex(int track) noexcept { m_trackIndex = track; }
//   void setSpeed(double speed) noexcept { m_speed = speed; }
//   void setMuted(bool muted) noexcept { m_isMuted = muted; }
//   void setBlendMode(int mode) noexcept { m_blendMode = mode; }
//
//   [[nodiscard]] ClipTransformData &transform() noexcept { return m_transform; }
//   [[nodiscard]] const ClipTransformData &transform() const noexcept {
//     return m_transform;
//   }
//   [[nodiscard]] ClipColorData &color() noexcept { return m_color; }
//   [[nodiscard]] const ClipColorData &color() const noexcept { return m_color; }
//   [[nodiscard]] ClipAudioData &audio() noexcept { return m_audio; }
//   [[nodiscard]] const ClipAudioData &audio() const noexcept { return m_audio; }
//
//   [[nodiscard]] std::shared_ptr<render::NodeGraph> nodeGraph() const noexcept {
//     return m_nodeGraph;
//   }
//   void setNodeGraph(std::shared_ptr<render::NodeGraph> graph) noexcept {
//     m_nodeGraph = std::move(graph);
//   }
//   [[nodiscard]] QVariantList nodeGraphNodes() const {
//     return m_nodeGraph ? m_nodeGraph->toVariantList() : QVariantList();
//   }
//   [[nodiscard]] QVariantList nodeGraphLinks() const {
//     return m_nodeGraph ? m_nodeGraph->linksToVariantList() : QVariantList();
//   }
//
//   [[nodiscard]] QVariantMap
//   pushConstantValues(FrameIndex relativeFrame = 0) const;
//
//   [[nodiscard]] const QString &linkGroupId() const noexcept {
//     return m_linkGroupId;
//   }
//   void setLinkGroupId(QString groupId) noexcept {
//     m_linkGroupId = std::move(groupId);
//   }
//
// private:
//   QString m_clipId;
//   QString m_assetId;
//   QString m_name;
//   std::shared_ptr<render::NodeGraph> m_nodeGraph;
//   QString m_linkGroupId;
//
//   FrameIndex m_startFrame{0};
//   FrameIndex m_durationFrames{30};
//   FrameIndex m_sourceInFrame{0};
//   int m_trackIndex{0};
//   double m_speed{1.0};
//   bool m_isMuted{false};
//   bool m_isLocked{false};
//   int m_blendMode{0};
//
//   ClipTransformData m_transform;
//   ClipColorData m_color;
//   ClipAudioData m_audio;
// };
//
// } // namespace xyla




#pragma once

/* =============================================================================
 * XYLA TIMELINE CLIP (UPDATED MULTI-GRAPH REFERENCE ARCHITECTURE)
 * -----------------------------------------------------------------------------
 * WHAT THIS FILE DOES:
 * 1. Decouples NodeGraph ownership: clip stores a vector of graph IDs (m_nodeGraphIds).
 * 2. Index 0 is GUARANTEED to be "default_io_graph" (the immutable default In/Out).
 * 3. Additional user graph IDs (Index 1, 2, ...) can be attached/detached and shared.
 * 4. `clip->nodeGraph()` queries the central NodeGraphManager using activeGraphId().
 *    This allows TimelineCompositor to render without altering any rendering code!
 * 5. Declares serialize() and deserialize() (implemented in timelineClip.cpp).
 * ============================================================================= */

#include "core/animation/animProperty.hpp"
#include "core/animation/propertyDescriptor.hpp"
#include "core/render/nodeGraph.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include "timelineTypes.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <algorithm>
#include <memory>
#include <vector>

namespace xyla {

class TimelineClip {
public:
  TimelineClip(QString clipId, QString assetId, QString name,
               FrameIndex startFrame, FrameIndex durationFrames,
               FrameIndex sourceInFrame = 0, int trackIndex = 0)
      : m_clipId(std::move(clipId)), m_assetId(std::move(assetId)),
        m_name(std::move(name)), m_startFrame(startFrame),
        m_durationFrames(durationFrames), m_sourceInFrame(sourceInFrame),
        m_trackIndex(trackIndex) {
    // Index 0 is ALWAYS the immutable default In/Out graph
    m_nodeGraphIds.push_back(render::DEFAULT_IO_GRAPH_ID);
    m_activeGraphIndex = 0;
  }

  // --- Graph References ---
  [[nodiscard]] const std::vector<QString> &nodeGraphIds() const noexcept {
    return m_nodeGraphIds;
  }

  [[nodiscard]] size_t activeGraphIndex() const noexcept {
    return m_activeGraphIndex;
  }

  void setActiveGraphIndex(size_t index) noexcept {
    if (index < m_nodeGraphIds.size()) {
      m_activeGraphIndex = index;
    }
  }

  [[nodiscard]] QString activeGraphId() const {
    if (m_activeGraphIndex < m_nodeGraphIds.size()) {
      return m_nodeGraphIds[m_activeGraphIndex];
    }
    return render::DEFAULT_IO_GRAPH_ID;
  }

  void setActiveGraphId(const QString &graphId) {
    for (size_t i = 0; i < m_nodeGraphIds.size(); ++i) {
      if (m_nodeGraphIds[i] == graphId) {
        m_activeGraphIndex = i;
        return;
      }
    }
  }

  // Returns the active NodeGraph from the central repository
  [[nodiscard]] std::shared_ptr<render::NodeGraph> nodeGraph() const noexcept {
    return render::NodeGraphManager::instance().getGraph(activeGraphId());
  }

  void attachNodeGraphId(const QString &graphId) {
    if (graphId.isEmpty()) return;
    for (const auto &id : m_nodeGraphIds) {
      if (id == graphId) return; // Already attached
    }
    m_nodeGraphIds.push_back(graphId);
  }

  bool detachNodeGraphId(const QString &graphId) {
    // Cannot delete or detach Index 0 (default immutable In/Out)
    if (graphId == render::DEFAULT_IO_GRAPH_ID) return false;

    auto it = std::find(m_nodeGraphIds.begin() + 1, m_nodeGraphIds.end(), graphId);
    if (it != m_nodeGraphIds.end()) {
      m_nodeGraphIds.erase(it);
      if (m_activeGraphIndex >= m_nodeGraphIds.size()) {
        m_activeGraphIndex = m_nodeGraphIds.size() - 1;
      }
      return true;
    }
    return false;
  }

  [[nodiscard]] QVariantList nodeGraphNodes() const {
    auto g = nodeGraph();
    return g ? g->toVariantList() : QVariantList();
  }

  [[nodiscard]] QVariantList nodeGraphLinks() const {
    auto g = nodeGraph();
    return g ? g->linksToVariantList() : QVariantList();
  }

  // --- Core Metadata Accessors ---
  [[nodiscard]] const QString &clipId() const noexcept { return m_clipId; }
  [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  [[nodiscard]] FrameIndex startFrame() const noexcept { return m_startFrame; }
  [[nodiscard]] FrameIndex durationFrames() const noexcept { return m_durationFrames; }
  [[nodiscard]] FrameIndex endFrame() const noexcept { return m_startFrame + m_durationFrames; }
  [[nodiscard]] FrameIndex sourceInFrame() const noexcept { return m_sourceInFrame; }
  [[nodiscard]] FrameIndex sourceOutFrame() const noexcept { return m_sourceInFrame + m_durationFrames; }
  [[nodiscard]] int trackIndex() const noexcept { return m_trackIndex; }
  [[nodiscard]] double speed() const noexcept { return m_speed; }
  [[nodiscard]] bool isMuted() const noexcept { return m_isMuted; }
  [[nodiscard]] int blendMode() const noexcept { return m_blendMode; }
  [[nodiscard]] bool isLocked() const noexcept { return m_isLocked; }
  void setLocked(bool locked) noexcept { m_isLocked = locked; }

  void setStartFrame(FrameIndex frame) noexcept { m_startFrame = frame; }
  void setDurationFrames(FrameIndex duration) noexcept {
    m_durationFrames = std::max<FrameIndex>(1, duration);
  }
  void setSourceInFrame(FrameIndex frame) noexcept {
    m_sourceInFrame = std::max<FrameIndex>(0, frame);
  }
  void setTrackIndex(int track) noexcept { m_trackIndex = track; }
  void setSpeed(double speed) noexcept { m_speed = speed; }
  void setMuted(bool muted) noexcept { m_isMuted = muted; }
  void setBlendMode(int mode) noexcept { m_blendMode = mode; }

  [[nodiscard]] ClipTransformData &transform() noexcept { return m_transform; }
  [[nodiscard]] const ClipTransformData &transform() const noexcept { return m_transform; }
  [[nodiscard]] ClipColorData &color() noexcept { return m_color; }
  [[nodiscard]] const ClipColorData &color() const noexcept { return m_color; }
  [[nodiscard]] ClipAudioData &audio() noexcept { return m_audio; }
  [[nodiscard]] const ClipAudioData &audio() const noexcept { return m_audio; }

  [[nodiscard]] QVariantMap pushConstantValues(FrameIndex relativeFrame = 0) const;

  [[nodiscard]] const QString &linkGroupId() const noexcept { return m_linkGroupId; }
  void setLinkGroupId(QString groupId) noexcept { m_linkGroupId = std::move(groupId); }

  [[nodiscard]] anim::AnimProperty *findAnimProperty(const QString &key);
  [[nodiscard]] const anim::AnimProperty *findAnimProperty(const QString &key) const;
  [[nodiscard]] std::vector<const anim::PropertyDescriptor *> animatableProperties() const;

  [[nodiscard]] QVariantMap toVariantMap() const;

  // --- Serialization Declarations (Implemented in timelineClip.cpp) ---
  [[nodiscard]] QJsonObject serialize() const;
  static TimelineClip deserialize(const QJsonObject &obj);

  void copyGraphReferencesFrom(const TimelineClip &other) noexcept {
    m_nodeGraphIds = other.m_nodeGraphIds;
    m_activeGraphIndex = other.m_activeGraphIndex;
  }

  // Backwards-compatibility alias for older code:
  void setNodeGraph(std::shared_ptr<render::NodeGraph> graph) noexcept {
    if (!graph) return;
    attachNodeGraphId(graph->id());
    setActiveGraphId(graph->id());
  }

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;
  QString m_linkGroupId;

  std::vector<QString> m_nodeGraphIds;
  size_t m_activeGraphIndex{0};

  FrameIndex m_startFrame{0};
  FrameIndex m_durationFrames{30};
  FrameIndex m_sourceInFrame{0};
  int m_trackIndex{0};
  double m_speed{1.0};
  bool m_isMuted{false};
  bool m_isLocked{false};
  int m_blendMode{0};

  ClipTransformData m_transform;
  ClipColorData m_color;
  ClipAudioData m_audio;
};

} // namespace xyla
