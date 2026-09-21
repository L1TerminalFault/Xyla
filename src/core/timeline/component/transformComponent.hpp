#pragma once

#include "clipComponent.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/log/logger.hpp"
#include <memory>

namespace xyla {

enum class TransformPropertyId : uint8_t {
  PosX = 0,
  PosY,
  ScaleX,
  ScaleY,
  Rotation,
  Opacity,
  Count
};

struct TransformHandles {
  std::array<anim::PropertyHandle,
             static_cast<size_t>(TransformPropertyId::Count)>
      channels;
};

class TransformComponent : public ClipComponent {
public:
  TransformComponent() = default;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override {
    return std::make_unique<TransformComponent>(*this);
  }
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
        // Splitting into independent axes: clone ScaleX's curve/keyframes onto
        // ScaleY
        slotY->animProp = slotX->animProp;
      } else {
        // Collapsing to uniform: reset ScaleY keyframes and match ScaleX's
        // static value
        slotY->animProp.clearKeyframes();
        slotY->animProp.setStaticValue(slotX->animProp.getStaticValue());
      }
    }
  }

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::IntrinsicTransform;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("transform");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Transform");
  }

  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override {
    m_animMgr = &animMgr;
    const QString prefix = clipId + QStringLiteral(".transform.");

    auto reg = [&](TransformPropertyId id, const QString &name, float def,
                   const QString &group) {
      handles.channels[static_cast<size_t>(id)] = animMgr.registerFloatProperty(
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

  [[nodiscard]] anim::AnimProperty *findProperty(const QString &) override {
    // Pure Table Architecture: Curves and keyframes are accessed via handles on
    // AnimationPropertyTable
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &) const override {
    return nullptr;
  }

  void collectChannelInfo(const QString &, int64_t, int64_t,
                          std::vector<anim::AnimChannelInfo> &) const override {
    // Channels are published directly by AnimationPropertyTable /
    // AnimationManager
  }
  [[nodiscard]] bool isUniformScale() const noexcept { return m_uniformScale; }

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
      const auto handle = handles.channels[static_cast<size_t>(propId)];
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
    if (!ok)
      return false;

    if (id == QLatin1String("posX") || id == QLatin1String("positionX"))
      return setTableHandle(TransformPropertyId::PosX, fVal);

    if (id == QLatin1String("posY") || id == QLatin1String("positionY"))
      return setTableHandle(TransformPropertyId::PosY, fVal);

    if (id == QLatin1String("scale")) {
      bool okX = setTableHandle(TransformPropertyId::ScaleX, fVal);
      bool okY = setTableHandle(TransformPropertyId::ScaleY, fVal);
      return okX && okY;
    }

    if (id == QLatin1String("scaleX")) {
      bool okX = setTableHandle(TransformPropertyId::ScaleX, fVal);
      if (m_uniformScale) {
        okX &= setTableHandle(TransformPropertyId::ScaleY, fVal);
      }
      return okX;
    }

    if (id == QLatin1String("scaleY")) {
      if (m_uniformScale) {
        bool okX = setTableHandle(TransformPropertyId::ScaleX, fVal);
        bool okY = setTableHandle(TransformPropertyId::ScaleY, fVal);
        return okX && okY;
      }
      return setTableHandle(TransformPropertyId::ScaleY, fVal);
    }

    if (id == QLatin1String("rotation"))
      return setTableHandle(TransformPropertyId::Rotation, fVal);

    if (id == QLatin1String("opacity"))
      return setTableHandle(TransformPropertyId::Opacity, fVal);

    return false;
  }

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;
    obj[QStringLiteral("uniformScale")] = m_uniformScale;
    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    m_uniformScale = obj.value(QStringLiteral("uniformScale")).toBool(true);
  }

  [[nodiscard]] anim::PropertyHandle
  handle(TransformPropertyId id) const noexcept {
    return handles.channels[static_cast<size_t>(id)];
  }

  bool m_uniformScale{true};
  TransformHandles handles;

private:
  anim::AnimationManager *m_animMgr{nullptr};
};

} // namespace xyla
