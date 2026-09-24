#pragma once

// ============================================================================
// ClipComponent
// ============================================================================
//
// Base interface for all components attached to a TimelineClip.
//
// A component may provide:
//   - component-specific state
//   - editable properties
//   - animated properties
//   - animation-channel information
//   - serialization/deserialization
//
// Ownership:
//   TimelineClip owns components through std::unique_ptr.
//
// Copying:
//   Components are polymorphically copied through clone().
//
// Animation:
//   Components may register and expose animated properties through the
//   AnimationManager.
//
// Serialization:
//   Each component is responsible only for its own state. TimelineClip is
//   responsible for serializing the component collection.
//
// The interface intentionally stays small. Components should not gain
// timeline-level responsibilities.
// ============================================================================

#include "core/animation/AnimationManager.hpp"
#include "core/animation/animChannel.hpp"
#include "core/animation/animProperty.hpp"
#include "core/timeline/playback/playbackManager.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariant>

#include <cstdint>
#include <memory>
#include <vector>

namespace xyla {

// ============================================================================
// Component Kind
// ============================================================================
//
// Identifies the broad category of a component.
//
// These values currently identify component behavior inside the application.
// If they ever become part of a persisted/external format, their numeric
// values should be treated as stable.
// ============================================================================

enum class ComponentKind : std::uint8_t {
  IntrinsicTransform = 0,
  IntrinsicColor,
  IntrinsicAudio,
  GeneratorText,
  VideoModifier,
  AudioModifier
};

// ============================================================================
// ClipComponent
// ============================================================================

class ClipComponent {
public:
  virtual ~ClipComponent() = default;

  // --------------------------------------------------------------------------
  // Polymorphic Copying
  // --------------------------------------------------------------------------

  // Creates an independent copy of this component.
  //
  // Required because TimelineClip owns components through unique_ptr.
  [[nodiscard]] virtual std::unique_ptr<ClipComponent>
  clone() const = 0;

  // --------------------------------------------------------------------------
  // Component Properties
  // --------------------------------------------------------------------------

  // Attempts to modify a component property at a local clip frame.
  //
  // Returns:
  //   true  - property was recognized and changed
  //   false - property is not handled by this component
  //
  // Components without editable properties may use the default implementation.
  virtual bool setProperty(
      const QString &propertyId,
      const QVariant &value,
      FrameIndex localFrame) {
    Q_UNUSED(propertyId);
    Q_UNUSED(value);
    Q_UNUSED(localFrame);

    return false;
  }

  // --------------------------------------------------------------------------
  // Component Identity
  // --------------------------------------------------------------------------

  [[nodiscard]] virtual ComponentKind
  kind() const noexcept = 0;

  // Stable programmatic identifier.
  //
  // Example:
  //   "audio"
  //   "transform"
  //   "text"
  [[nodiscard]] virtual QString
  componentId() const noexcept = 0;

  // Human-readable name intended for UI.
  //
  // Example:
  //   "Audio"
  //   "Transform"
  //   "Text"
  [[nodiscard]] virtual QString
  displayName() const = 0;

  // --------------------------------------------------------------------------
  // Animation
  // --------------------------------------------------------------------------

  // Gives the component access to the owning clip's AnimationManager.
  //
  // Components without animated properties do not need to override this.
  virtual void bindAnimationManager(
      const QString &clipId,
      anim::AnimationManager &animMgr) {
    Q_UNUSED(clipId);
    Q_UNUSED(animMgr);
  }

  // Finds an animated property owned by this component.
  [[nodiscard]] virtual anim::AnimProperty *
  findProperty(const QString &propertyId) = 0;

  [[nodiscard]] virtual const anim::AnimProperty *
  findProperty(const QString &propertyId) const = 0;

  // Collects animation-channel information for playback/UI systems.
  virtual void collectChannelInfo(
      const QString &clipId,
      int64_t clipStartFrame,
      int64_t relativePlayheadFrame,
      std::vector<anim::AnimChannelInfo> &out) const = 0;

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  // Serializes component-specific state.
  [[nodiscard]] virtual QJsonObject
  serialize() const = 0;

  // Restores component-specific state.
  virtual void deserialize(
      const QJsonObject &obj) = 0;
};

} // namespace xyla
