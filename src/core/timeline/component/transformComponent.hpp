#pragma once

#include "clipComponent.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include <memory>

namespace xyla {

class TransformComponent : public ClipComponent, public ClipTransformData {
public:
  TransformComponent() = default;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override {
    return std::make_unique<TransformComponent>(*this);
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

  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &propertyId) override {
    QString id = propertyId.startsWith(QStringLiteral("transform."))
                     ? propertyId.mid(10)
                     : propertyId;

    if (id == "posX" || id == "positionX")
      return &posX;
    if (id == "posY" || id == "positionY")
      return &posY;
    if (id == "scale" || id == "scaleX")
      return &scaleX;
    if (id == "scaleY")
      return uniformScale ? &scaleX : &scaleY;
    if (id == "rotation")
      return &rotation;
    if (id == "opacity")
      return &opacity;
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &propertyId) const override {
    return const_cast<TransformComponent *>(this)->findProperty(propertyId);
  }

  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override {
    QString id = propertyId.startsWith(QStringLiteral("transform."))
                     ? propertyId.mid(10)
                     : propertyId;

    // Handle uniform scale toggle
    if (id == "uniformScale" || id == "isUniformScale") {
      uniformScale = value.toBool();
      return true;
    }

    auto applyAnim = [&](anim::AnimProperty &p, float val) {
      if (p.getIsAnimated()) {
        p.setKeyframe(localFrame, val);
      } else {
        p.setStaticValue(val);
      }
    };

    bool ok = false;
    float fVal = value.toFloat(&ok);
    if (!ok) {
      return false;
    }

    // When uniform scale is active, keep scaleX and scaleY in sync
    if (id == "scale" || (uniformScale && (id == "scaleX" || id == "scaleY"))) {
      applyAnim(scaleX, fVal);
      applyAnim(scaleY, fVal);
      return true;
    }

    if (auto *prop = findProperty(id)) {
      applyAnim(*prop, fVal);
      return true;
    }

    return false;
  }

  void
  collectChannelInfo(const QString &clipId, int64_t clipStartFrame,
                     int64_t relPlayheadFrame,
                     std::vector<anim::AnimChannelInfo> &out) const override {
    auto appendProp = [&](const anim::AnimProperty &p, const QString &id,
                          const QString &name, const QString &group,
                          const QString &parent, const QString &color) {
      if (!p.getIsAnimated())
        return;

      anim::AnimChannelInfo info;
      info.clipId = clipId;
      info.id = QStringLiteral("transform.") + id;
      info.name = name;
      info.group = group;
      info.parent = parent;
      info.color = color;
      info.isAnimated = true;

      for (const auto &k : p.getKeyframes()) {
        int64_t absF = k.frame + clipStartFrame;
        info.keyframeFrames.push_back(absF);
        if (k.frame == relPlayheadFrame)
          info.hasKeyframeAtPlayhead = true;

        anim::KeyframeDetail det;
        det.frame = absF;
        det.value = k.value;
        det.interpolation = static_cast<int>(k.interpolation);
        det.inX = k.bezier.inX;
        det.inY = k.bezier.inY;
        det.outX = k.bezier.outX;
        det.outY = k.bezier.outY;
        info.details.push_back(det);
      }
      out.push_back(std::move(info));
    };

    appendProp(posX, "posX", "Position X", "Transform", "Position", "#EF4444");
    appendProp(posY, "posY", "Position Y", "Transform", "Position", "#22C55E");

    if (uniformScale) {
      appendProp(scaleX, "scale", "Scale", "Transform", "", "#3B82F6");
    } else {
      appendProp(scaleX, "scaleX", "Scale X", "Transform", "Scale", "#3B82F6");
      appendProp(scaleY, "scaleY", "Scale Y", "Transform", "Scale", "#3B82F6");
    }

    appendProp(rotation, "rotation", "Rotation", "Transform", "", "#EAB308");
    appendProp(opacity, "opacity", "Opacity", "Compositing", "", "#A855F7");
  }

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;
    obj["posX"] = posX.serialize();
    obj["posY"] = posY.serialize();
    obj["scaleX"] = scaleX.serialize();
    obj["scaleY"] = scaleY.serialize();
    obj["rotation"] = rotation.serialize();
    obj["opacity"] = opacity.serialize();
    obj["uniformScale"] = uniformScale;
    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    if (obj.contains("posX"))
      posX.deserializeInto(obj["posX"].toObject(), 0.0f);
    if (obj.contains("posY"))
      posY.deserializeInto(obj["posY"].toObject(), 0.0f);
    if (obj.contains("scaleX"))
      scaleX.deserializeInto(obj["scaleX"].toObject(), 1.0f);
    if (obj.contains("scaleY"))
      scaleY.deserializeInto(obj["scaleY"].toObject(), 1.0f);
    if (obj.contains("rotation"))
      rotation.deserializeInto(obj["rotation"].toObject(), 0.0f);
    if (obj.contains("opacity"))
      opacity.deserializeInto(obj["opacity"].toObject(), 1.0f);
    uniformScale = obj.value("uniformScale").toBool(true);
  }

  bool uniformScale{true};
};

} // namespace xyla
