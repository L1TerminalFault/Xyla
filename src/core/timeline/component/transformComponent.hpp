#pragma once

#include "clipComponent.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/log/logger.hpp"

#include <array>
#include <cstdint>
#include <memory>

namespace xyla {

// -----------------------------------------------------------------------------
// Transform Animation Properties
// -----------------------------------------------------------------------------

enum class TransformPropertyId : uint8_t {
  PosX = 0,
  PosY,
  ScaleX,
  ScaleY,
  Rotation,
  Opacity,
  Count
};

/**
 * Handles for transform properties registered in the animation property table.
 */
struct TransformHandles {
  std::array<
      anim::PropertyHandle,
      static_cast<size_t>(TransformPropertyId::Count)>
      channels;
};

// -----------------------------------------------------------------------------
// Transform Component
// -----------------------------------------------------------------------------

/**
 * Stores the transform and compositing properties of a timeline clip.
 *
 * Transform values are backed by the AnimationManager property table.
 * Property handles are kept locally so callers can efficiently address
 * the registered animation properties.
 *
 * NOTE:
 * This class currently derives from ClipComponent for architectural
 * compatibility. Its longer-term role may be reconsidered when the
 * clip/content architecture is refactored.
 */
class TransformComponent : public ClipComponent {
public:
  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  TransformComponent() = default;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override {
    return std::make_unique<TransformComponent>(*this);
  }

  // ---------------------------------------------------------------------------
  // Uniform Scale
  // ---------------------------------------------------------------------------

  /**
   * Enables or disables linked X/Y scale editing.
   *
   * When uniform scale is disabled, ScaleX's animation data is copied to
   * ScaleY so both axes initially remain synchronized.
   *
   * When uniform scale is enabled, ScaleY keyframes are cleared and its
   * static value is synchronized with ScaleX.
   */
  void setUniformScale(bool uniform) {
    m_uniformScale = uniform;

    if (!m_animMgr) {
      return;
    }

    const auto hScaleX =
        handles.channels[static_cast<size_t>(TransformPropertyId::ScaleX)];

    const auto hScaleY =
        handles.channels[static_cast<size_t>(TransformPropertyId::ScaleY)];

    if (!hScaleX.isValid() || !hScaleY.isValid()) {
      return;
    }

    auto *slotX = m_animMgr->table()->getSlot(hScaleX);
    auto *slotY = m_animMgr->table()->getSlot(hScaleY);

    if (slotX && slotY) {
      if (!uniform) {
        // Splitting into independent axes: initialize ScaleY from ScaleX.
        slotY->animProp = slotX->animProp;
      } else {
        // Re-linking the axes: remove ScaleY keyframes and synchronize its
        // static value with ScaleX.
        slotY->animProp.clearKeyframes();
        slotY->animProp.setStaticValue(slotX->animProp.getStaticValue());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Component Identity
  // ---------------------------------------------------------------------------

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::IntrinsicTransform;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("transform");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Transform");
  }

  // ---------------------------------------------------------------------------
  // Animation Registration
  // ---------------------------------------------------------------------------

  /**
   * Registers all transform properties with the shared AnimationManager.
   *
   * Properties are exposed under:
   *
   *   <clipId>.transform.posX
   *   <clipId>.transform.posY
   *   <clipId>.transform.scaleX
   *   <clipId>.transform.scaleY
   *   <clipId>.transform.rotation
   *   <clipId>.transform.opacity
   */
  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override {
    m_animMgr = &animMgr;

    const QString prefix = clipId + QStringLiteral(".transform.");

    auto reg = [&](TransformPropertyId id, const QString &name, float def,
                   const QString &group) {
      handles.channels[static_cast<size_t>(id)] =
          animMgr.registerFloatProperty(
              clipId, prefix + name, def, name, group);
    };

    reg(TransformPropertyId::PosX, QStringLiteral("posX"), 0.0f,
        QStringLiteral("Transform"));

    reg(TransformPropertyId::PosY, QStringLiteral("posY"), 0.0f,
        QStringLiteral("Transform"));

    reg(TransformPropertyId::ScaleX, QStringLiteral("scaleX"), 1.0f,
        QStringLiteral("Transform"));

    reg(TransformPropertyId::ScaleY, QStringLiteral("scaleY"), 1.0f,
        QStringLiteral("Transform"));

    reg(TransformPropertyId::Rotation, QStringLiteral("rotation"), 0.0f,
        QStringLiteral("Transform"));

    reg(TransformPropertyId::Opacity, QStringLiteral("opacity"), 1.0f,
        QStringLiteral("Compositing"));
  }

  // ---------------------------------------------------------------------------
  // Property Access
  // ---------------------------------------------------------------------------

  /**
   * Transform animation values are currently stored in the central animation
   * property table, so this component does not expose AnimProperty objects
   * directly.
   */
  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &) override {
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &) const override {
    return nullptr;
  }

  /**
   * Channel information is currently published directly by the
   * AnimationPropertyTable / AnimationManager.
   */
  void collectChannelInfo(const QString &, int64_t, int64_t,
                          std::vector<anim::AnimChannelInfo> &) const override {
  }

  [[nodiscard]] bool isUniformScale() const noexcept {
    return m_uniformScale;
  }

  // ---------------------------------------------------------------------------
  // Property Editing
  // ---------------------------------------------------------------------------

  /**
   * Sets a transform property at the specified local frame.
   *
   * Both canonical property names and a small number of legacy aliases are
   * accepted for position and uniform-scale properties.
   */
  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override {
    QString id = propertyId.startsWith(QLatin1String("transform."))
                     ? propertyId.mid(10)
                     : propertyId;

    if (id == QLatin1String("uniformScale") ||
        id == QLatin1String("isUniformScale")) {
      setUniformScale(value.toBool());
      return true;
    }

    auto setTableHandle = [&](TransformPropertyId propId,
                              const QVariant &val) -> bool {
      if (!m_animMgr) {
        XYLA_LOG_WARN("TransformComponent",
                      "setTableHandle failed: m_animMgr is NULL!");
        return false;
      }

      const auto handle =
          handles.channels[static_cast<size_t>(propId)];

      if (!handle.isValid()) {
        XYLA_LOG_WARN(
            "TransformComponent",
            std::format(
                "setTableHandle failed: handle is invalid for propId {}!",
                static_cast<int>(propId)));

        return false;
      }

      return m_animMgr->setProperty(handle, val, localFrame);
    };

    bool ok = false;
    float fVal = value.toFloat(&ok);

    if (!ok) {
      return false;
    }

    if (id == QLatin1String("posX") ||
        id == QLatin1String("positionX")) {
      return setTableHandle(TransformPropertyId::PosX, fVal);
    }

    if (id == QLatin1String("posY") ||
        id == QLatin1String("positionY")) {
      return setTableHandle(TransformPropertyId::PosY, fVal);
    }

    if (id == QLatin1String("scale")) {
      bool okX =
          setTableHandle(TransformPropertyId::ScaleX, fVal);

      bool okY =
          setTableHandle(TransformPropertyId::ScaleY, fVal);

      return okX && okY;
    }

    if (id == QLatin1String("scaleX")) {
      bool okX =
          setTableHandle(TransformPropertyId::ScaleX, fVal);

      if (m_uniformScale) {
        okX &= setTableHandle(TransformPropertyId::ScaleY, fVal);
      }

      return okX;
    }

    if (id == QLatin1String("scaleY")) {
      if (m_uniformScale) {
        bool okX =
            setTableHandle(TransformPropertyId::ScaleX, fVal);

        bool okY =
            setTableHandle(TransformPropertyId::ScaleY, fVal);

        return okX && okY;
      }

      return setTableHandle(TransformPropertyId::ScaleY, fVal);
    }

    if (id == QLatin1String("rotation")) {
      return setTableHandle(TransformPropertyId::Rotation, fVal);
    }

    if (id == QLatin1String("opacity")) {
      return setTableHandle(TransformPropertyId::Opacity, fVal);
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;
    obj[QStringLiteral("uniformScale")] = m_uniformScale;
    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    m_uniformScale =
        obj.value(QStringLiteral("uniformScale")).toBool(true);
  }

  // ---------------------------------------------------------------------------
  // Animation Handles
  // ---------------------------------------------------------------------------

  [[nodiscard]] anim::PropertyHandle
  handle(TransformPropertyId id) const noexcept {
    return handles.channels[static_cast<size_t>(id)];
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool m_uniformScale{true};

  TransformHandles handles;

private:
  // Non-owning pointer to the animation manager used by this component.
  anim::AnimationManager *m_animMgr{nullptr};
};

} // namespace xyla
