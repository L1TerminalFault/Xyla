#pragma once

// ============================================================================
// AudioComponent
// ============================================================================
//
// Timeline clip component responsible for audio-specific state and animation.
//
// Responsibilities:
//   - stores audio component state
//   - registers audio animation properties
//   - stores runtime animation handles
//   - applies animated property changes
//   - serializes/deserializes audio-specific state
//
// Current properties:
//   - volume
//   - pan
//
// Current non-animated state:
//   - channelMode
//
// The component does not own AnimationManager. It only keeps a non-owning
// pointer to the manager supplied by bindAnimationManager().
//
// Property names and serialized JSON keys are intentionally kept stable.
// ============================================================================

#include "clipComponent.hpp"

#include "core/animation/propertyHandle.hpp"
#include "core/log/logger.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariant>

#include <array>
#include <cstddef>
#include <cstdint>
#include <format>
#include <memory>

namespace xyla {

// ============================================================================
// AudioPropertyId
// ============================================================================
//
// Identifies properties owned by AudioComponent.
//
// The enum is used as an index into AudioHandles.
// ============================================================================

enum class AudioPropertyId : std::uint8_t {
  Volume = 0,
  Pan,
  Count
};

// ============================================================================
// AudioHandles
// ============================================================================
//
// Runtime handles for properties registered in AnimationManager.
//
// These are implementation details of AudioComponent and should generally not
// be manipulated directly by consumers.
// ============================================================================

struct AudioHandles {
  static constexpr std::size_t PropertyCount =
      static_cast<std::size_t>(
          AudioPropertyId::Count);

  std::array<
      anim::PropertyHandle,
      PropertyCount>
      channels;
};

// ============================================================================
// AudioComponent
// ============================================================================

class AudioComponent final : public ClipComponent {
public:
  AudioComponent() = default;

  ~AudioComponent() override = default;

  // --------------------------------------------------------------------------
  // Copying
  // --------------------------------------------------------------------------
  //
  // Components are copied by TimelineClip through clone().
  //
  // m_animMgr is intentionally copied as a non-owning pointer. This preserves
  // the current behavior. The owning clip/animation system remains responsible
  // for rebinding when appropriate.
  //

  AudioComponent(
      const AudioComponent &other)
      : ClipComponent(other),
        channelMode(other.channelMode),
        handles(other.handles),
        m_animMgr(other.m_animMgr) {}

  AudioComponent &operator=(
      const AudioComponent &other) {
    if (this == &other) {
      return *this;
    }

    ClipComponent::operator=(other);

    channelMode = other.channelMode;
    handles = other.handles;
    m_animMgr = other.m_animMgr;

    return *this;
  }

  // --------------------------------------------------------------------------
  // Polymorphic Copy
  // --------------------------------------------------------------------------

  [[nodiscard]] std::unique_ptr<ClipComponent>
  clone() const override {
    return std::make_unique<AudioComponent>(*this);
  }

  // --------------------------------------------------------------------------
  // Component Identity
  // --------------------------------------------------------------------------

  [[nodiscard]] ComponentKind
  kind() const noexcept override {
    return ComponentKind::IntrinsicAudio;
  }

  [[nodiscard]] QString
  componentId() const noexcept override {
    return QStringLiteral("audio");
  }

  [[nodiscard]] QString
  displayName() const override {
    return QStringLiteral("Audio");
  }

  // --------------------------------------------------------------------------
  // Animation Registration
  // --------------------------------------------------------------------------

  void bindAnimationManager(
      const QString &clipId,
      anim::AnimationManager &animMgr) override {
    m_animMgr = &animMgr;

    const QString prefix =
        clipId + QStringLiteral(".audio.");

    auto registerProperty =
        [&](AudioPropertyId id,
            const QString &name,
            float defaultValue,
            const QString &group) {
          handles.channels[
              static_cast<std::size_t>(id)] =
              animMgr.registerFloatProperty(
                  clipId,
                  prefix + name,
                  defaultValue,
                  name,
                  group);
        };

    registerProperty(
        AudioPropertyId::Volume,
        QStringLiteral("volume"),
        1.0f,
        QStringLiteral("Audio"));

    registerProperty(
        AudioPropertyId::Pan,
        QStringLiteral("pan"),
        0.0f,
        QStringLiteral("Audio"));
  }

  // --------------------------------------------------------------------------
  // Animation Property Lookup
  // --------------------------------------------------------------------------
  //
  // Audio properties currently operate through PropertyHandle rather than
  // direct AnimProperty access.
  //
  // Until the AnimationManager API provides a clean property lookup path,
  // returning nullptr is intentional.
  //

  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &) override {
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &) const override {
    return nullptr;
  }

  // --------------------------------------------------------------------------
  // Animation Channel Information
  // --------------------------------------------------------------------------
  //
  // Audio currently does not contribute channel information through this
  // interface.
  //

  void collectChannelInfo(
      const QString &,
      int64_t,
      int64_t,
      std::vector<anim::AnimChannelInfo> &) const override {}

  // --------------------------------------------------------------------------
  // Property Editing
  // --------------------------------------------------------------------------
  //
  // Handles both:
  //
  //   audio.channelMode
  //   audio.volume
  //   audio.pan
  //
  // and their unqualified forms:
  //
  //   channelMode
  //   volume
  //   pan
  //
  // The existing property names are intentionally unchanged.
  //

  bool setProperty(
      const QString &propertyId,
      const QVariant &value,
      FrameIndex localFrame) override {
    QString id = propertyId;

    constexpr QLatin1StringView Prefix{"audio."};

    if (id.startsWith(Prefix)) {
      id.remove(0, Prefix.size());
    }

    // ------------------------------------------------------------------------
    // Non-animated property
    // ------------------------------------------------------------------------

    if (id == QLatin1String("channelMode")) {
      channelMode = value.toInt();
      return true;
    }

    // ------------------------------------------------------------------------
    // Animated property helper
    // ------------------------------------------------------------------------

    auto setAnimatedProperty =
        [&](AudioPropertyId propertyId,
            float propertyValue) -> bool {
          if (!m_animMgr) {
            XYLA_LOG_WARN(
                "AudioComponent",
                "setAnimatedProperty failed: "
                "AnimationManager is null.");

            return false;
          }

          const anim::PropertyHandle propertyHandle =
              handles.channels[
                  static_cast<std::size_t>(propertyId)];

          if (!propertyHandle.isValid()) {
            XYLA_LOG_WARN(
                "AudioComponent",
                std::format(
                    "setAnimatedProperty failed: "
                    "invalid handle for property {}.",
                    static_cast<int>(propertyId)));

            return false;
          }

          return m_animMgr->setProperty(
              propertyHandle,
              propertyValue,
              localFrame);
        };

    // ------------------------------------------------------------------------
    // Convert input
    // ------------------------------------------------------------------------

    bool conversionOk = false;

    const float floatValue =
        value.toFloat(&conversionOk);

    if (!conversionOk) {
      return false;
    }

    // ------------------------------------------------------------------------
    // Volume
    // ------------------------------------------------------------------------

    if (id == QLatin1String("volume")) {
      return setAnimatedProperty(
          AudioPropertyId::Volume,
          floatValue);
    }

    // ------------------------------------------------------------------------
    // Pan
    // ------------------------------------------------------------------------

    if (id == QLatin1String("pan")) {
      return setAnimatedProperty(
          AudioPropertyId::Pan,
          floatValue);
    }

    return false;
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  [[nodiscard]] QJsonObject
  serialize() const override {
    QJsonObject obj;

    // Keep the existing persistence key stable.
    obj[QStringLiteral("channelMode")] =
        channelMode;

    return obj;
  }

  void deserialize(
      const QJsonObject &obj) override {
    channelMode =
        obj.value(QStringLiteral("channelMode"))
            .toInt(0);
  }

  // --------------------------------------------------------------------------
  // Property Handles
  // --------------------------------------------------------------------------

  [[nodiscard]] anim::PropertyHandle
  handle(AudioPropertyId id) const noexcept {
    return handles.channels[
        static_cast<std::size_t>(id)];
  }

  // --------------------------------------------------------------------------
  // State
  // --------------------------------------------------------------------------
  //
  // These remain public because existing code may access them directly.
  //
  // If we later confirm there are no direct consumers, these should become
  // private with explicit accessors.
  //

  int channelMode{0};

private:
  // Runtime handles are implementation details and should not be modified
  // directly by users of AudioComponent.
  AudioHandles handles;

  // Non-owning pointer to the animation system.
  anim::AnimationManager *m_animMgr{nullptr};
};

} // namespace xyla
