#pragma once

// ============================================================================
// TimelineClip
// ============================================================================
//
// WARNING: This class is acting as God Object, Consider separating it on next refactor
//
// Represents a single clip placed on the timeline.
//
// TimelineClip currently acts as the central data/model object for:
//   - clip identity and metadata
//   - timeline timing and placement
//   - clip state (lock/mute/scale/blend mode)
//   - visual and audio properties
//   - clip components
//   - animation property access
//   - node graph references
//   - clip editing operations (split/uncut)
//   - serialization
//   - specialized clip creation
//
// NOTE:
// This class intentionally keeps the current architecture and ownership model
// for now. The sections below are organized by responsibility to make future
// extraction/refactoring easier without changing current behavior.
//
// Future refactor candidates:
//   - ClipTiming                  -> dedicated timing/domain type
//   - Clip state                  -> dedicated ClipState type
//   - Node graph management       -> dedicated graph-reference type
//   - Serialization               -> dedicated serializer
//   - Specialized clip factories  -> dedicated factory
//   - Render/GPU data             -> render-side types
//
// ============================================================================

#include "core/animation/AnimationManager.hpp"
#include "core/animation/animProperty.hpp"
#include "core/render/nodeGraph.hpp"
#include "core/timeline/clip/clipTypes.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include "core/timeline/component/clipComponent.hpp"
#include "timelineTypes.hpp"

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <memory>
#include <vector>

namespace xyla {

class TimelineClip {
public:
  explicit TimelineClip(TimelineClipCreateInfo info);

  TimelineClip(const TimelineClip &other);
  TimelineClip &operator=(const TimelineClip &other);

  TimelineClip(TimelineClip &&other) noexcept = default;
  TimelineClip &operator=(TimelineClip &&other) noexcept = default;

  ~TimelineClip() = default;

  // ==========================================================================
  // Clip Creation
  // ==========================================================================
  //
  // Convenience constructors for specialized clip types.
  //
  // Future refactor:
  // Move these into a TimelineClipFactory or dedicated creation functions.
  //

  static TimelineClip createTitleClip(
      TimelineClipCreateInfo info,
      const QString &initialText = "Title");

  static TimelineClip createSvgClip(
      TimelineClipCreateInfo info,
      const QString &svgPath);

  // ==========================================================================
  // Property / Animation
  // ==========================================================================
  //
  // Updates an animatable clip property at a specific local frame and
  // provides access to animation properties by key/path.
  //
  // Future refactor:
  // Animation-related responsibilities could be moved behind a dedicated
  // animation/property interface.
  //

  bool setProperty(
      const QString &propertyId,
      const QVariant &value,
      FrameIndex localFrame);

  void bindAnimationManager(anim::AnimationManager &animMgr);

  [[nodiscard]] anim::AnimProperty *
  findPropertyByPath(const QString &path);

  [[nodiscard]] const anim::AnimProperty *
  findPropertyByPath(const QString &path) const;

  [[nodiscard]] anim::AnimProperty *
  findAnimProperty(const QString &key);

  [[nodiscard]] const anim::AnimProperty *
  findAnimProperty(const QString &key) const;

  // ==========================================================================
  // Serialization / Conversion
  // ==========================================================================
  //
  // Converts the clip to/from the currently supported persistence formats.
  //
  // Future refactor:
  // Move serialization/conversion into a dedicated TimelineClipSerializer.
  //

  [[nodiscard]] QJsonObject serialize() const;

  static TimelineClip deserialize(const QJsonObject &obj);

  [[nodiscard]] QVariantMap toVariantMap() const;

  // ==========================================================================
  // Identity / Metadata
  // ==========================================================================
  //
  // Basic clip identification and user-facing metadata.
  //

  [[nodiscard]] const QString &getClipId() const noexcept;
  void setClipId(QString clipId);

  [[nodiscard]] const QString &getAssetId() const noexcept;
  void setAssetId(QString assetId);

  [[nodiscard]] const QString &getName() const noexcept;
  void setName(QString name);

  // ==========================================================================
  // Timeline Timing
  // ==========================================================================
  //
  // Defines where the clip exists on the timeline and how its source media
  // maps to the timeline.
  //
  // Future refactor:
  // ClipTiming is a natural candidate for further extraction and refinement.
  //

  [[nodiscard]] const ClipTiming &getTiming() const noexcept;
  void setTiming(const ClipTiming &timing);

  // ==========================================================================
  // Clip Editing
  // ==========================================================================
  //
  // Operations that modify the temporal structure of a clip.
  //
  // split():
  //   Splits the clip at a timeline frame and returns the right-side clip.
  //
  // canUncutWith():
  //   Checks whether this clip and the supplied right clip can be merged.
  //
  // uncut():
  //   Merges a previously split clip when the required conditions are met.
  //
  // IMPORTANT:
  // Preserve the current split/uncut semantics during organizational
  // refactoring.
  //

  [[nodiscard]] TimelineClip split(
      const QString &newRightClipId,
      FrameIndex cutFrame);

  [[nodiscard]] bool canUncutWith(
      const TimelineClip &rightClip) const noexcept;

  bool uncut(const TimelineClip &rightClip);

  // ==========================================================================
  // Clip State
  // ==========================================================================
  //
  // General-purpose state flags and rendering behavior.
  //
  // Future refactor:
  // These fields could eventually become a dedicated ClipState structure.
  //

  [[nodiscard]] bool getIsLocked() const noexcept;
  void setIsLocked(bool locked) noexcept;

  [[nodiscard]] bool getIsMuted() const noexcept;
  void setIsMuted(bool muted) noexcept;

  [[nodiscard]] int getBlendMode() const noexcept;
  void setBlendMode(int mode);

  [[nodiscard]] bool getIsUniformScale() const noexcept;
  void setIsUniformScale(bool uniform) noexcept;

  // ==========================================================================
  // Intrinsic Clip Data
  // ==========================================================================
  //
  // Access to the clip's transform, color, and audio data.
  //
  // These currently remain exposed directly because existing code depends on
  // the current data model.
  //

  [[nodiscard]] ClipColorData &getColor() noexcept;
  [[nodiscard]] const ClipColorData &getColor() const noexcept;

  [[nodiscard]] ClipAudioData &getAudio() noexcept;
  [[nodiscard]] const ClipAudioData &getAudio() const noexcept;

  // ==========================================================================
  // Components
  // ==========================================================================
  //
  // Manages optional behavior/data components attached to the clip.
  //
  // Components are owned by TimelineClip through unique_ptr.
  //

  template <typename T>
  [[nodiscard]] T *getComponent() {
    for (auto &component : m_components) {
      if (auto *ptr = dynamic_cast<T *>(component.get())) {
        return ptr;
      }
    }

    return nullptr;
  }

  template <typename T>
  [[nodiscard]] const T *getComponent() const {
    for (const auto &component : m_components) {
      if (const auto *ptr = dynamic_cast<const T *>(component.get())) {
        return ptr;
      }
    }

    return nullptr;
  }

  void addComponent(std::unique_ptr<ClipComponent> component);

  bool removeComponent(const QString &componentId);

  [[nodiscard]] ClipComponent *
  findComponent(const QString &componentId);

  [[nodiscard]] const ClipComponent *
  findComponent(const QString &componentId) const;

  [[nodiscard]] const std::vector<std::unique_ptr<ClipComponent>> &
  getComponents() const noexcept;

  // ==========================================================================
  // Node Graph References
  // ==========================================================================
  //
  // Manages the node graphs associated with the clip and identifies the
  // currently active graph.
  //
  // Future refactor:
  // Extract graph-reference management from TimelineClip. In particular,
  // graph IDs/index management and actual NodeGraph access could eventually
  // become separate responsibilities.
  //

  [[nodiscard]] const std::vector<QString> &
  getNodeGraphIds() const noexcept;

  size_t getActiveGraphIndex() const noexcept;

  void setActiveGraphIndex(size_t index);

  [[nodiscard]] QString getActiveGraphId() const;

  void setActiveGraphId(const QString &graphId);

  [[nodiscard]] std::shared_ptr<render::NodeGraph>
  getNodeGraph() const;

  void setNodeGraph(
      std::shared_ptr<render::NodeGraph> graph);

  void attachNodeGraphId(const QString &graphId);

  bool detachNodeGraphId(const QString &graphId);

  void setAttachedNodeGraphIds(const QStringList &ids);

  void copyGraphReferencesFrom(
      const TimelineClip &other) noexcept;

  // ==========================================================================
  // Node Graph Presentation Data
  // ==========================================================================
  //
  // Provides QVariant-based node/link data for consumers such as UI,
  // QML, inspectors, or other Qt-facing systems.
  //

  [[nodiscard]] QVariantList getNodeGraphNodes() const;

  [[nodiscard]] QVariantList getNodeGraphLinks() const;

private:
  // ==========================================================================
  // Identity / Metadata
  // ==========================================================================

  QString m_clipId;
  QString m_assetId;
  QString m_name;

  // ==========================================================================
  // Timeline
  // ==========================================================================

  ClipTiming m_timing;

  // ==========================================================================
  // Clip State
  // ==========================================================================

  bool m_isLocked{false};
  bool m_isMuted{false};
  bool m_uniformScale{true};
  int m_blendMode{0};

  // ==========================================================================
  // Intrinsic Data
  // ==========================================================================

  ClipTransformData m_transform;
  ClipColorData m_color;
  ClipAudioData m_audio;

  // ==========================================================================
  // Components
  // ==========================================================================

  std::vector<std::unique_ptr<ClipComponent>> m_components;

  // ==========================================================================
  // Node Graph References
  // ==========================================================================

  std::vector<QString> m_nodeGraphIds;
  size_t m_activeGraphIndex{0};
};

} // namespace xyla
