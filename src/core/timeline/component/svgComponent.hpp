#pragma once

#include "clipComponent.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/animation/animChannel.hpp"
#include "core/animation/animProperty.hpp"
#include "core/vector/svg/svgDocument.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariant>
#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

namespace xyla {

/**
 * Timeline SVG component.
 *
 * Stores the SVG source and SVG-specific properties such as path trimming
 * and stroke-width overrides. Animation properties are registered with the
 * shared AnimationManager using the "svg." property namespace.
 *
 * NOTE:
 * This class currently derives from ClipComponent for architectural
 * compatibility. Its longer-term role may be reconsidered when the
 * clip/content architecture is refactored.
 */
class SvgComponent : public ClipComponent {
public:
  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  SvgComponent() = default;
  ~SvgComponent() override = default;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override {
    return std::make_unique<SvgComponent>(*this);
  }

  // ---------------------------------------------------------------------------
  // Component Identity
  // ---------------------------------------------------------------------------

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::VideoModifier;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("svg");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Vector Graphic");
  }

  // ---------------------------------------------------------------------------
  // Animation Registration
  // ---------------------------------------------------------------------------

  /**
   * Registers SVG animation properties with the shared animation manager.
   *
   * Properties are exposed under the following namespace:
   *
   *   <clipId>.svg.trimStart
   *   <clipId>.svg.trimEnd
   *   <clipId>.svg.trimOffset
   *   <clipId>.svg.strokeWidthOverride
   */
  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override {
    const QString prefix = clipId + QStringLiteral(".svg.");

    animMgr.registerFloatProperty(
        clipId, prefix + QStringLiteral("trimStart"),
        trimStart.getStaticValue(), QStringLiteral("Trim Start"),
        QStringLiteral("Trim"));

    animMgr.registerFloatProperty(
        clipId, prefix + QStringLiteral("trimEnd"),
        trimEnd.getStaticValue(), QStringLiteral("Trim End"),
        QStringLiteral("Trim"));

    animMgr.registerFloatProperty(
        clipId, prefix + QStringLiteral("trimOffset"),
        trimOffset.getStaticValue(), QStringLiteral("Trim Offset"),
        QStringLiteral("Trim"));

    animMgr.registerFloatProperty(
        clipId, prefix + QStringLiteral("strokeWidthOverride"),
        strokeWidthOverride.getStaticValue(), QStringLiteral("Stroke Width"),
        QStringLiteral("Stroke"));
  }

  // ---------------------------------------------------------------------------
  // Property Access
  // ---------------------------------------------------------------------------

  /**
   * Finds an SVG animation property by its local property ID.
   *
   * Both "svg.trimStart" and "trimStart"-style IDs are accepted.
   */
  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &propertyId) override {
    const QString id = propertyId.startsWith(QLatin1String("svg."))
                           ? propertyId.mid(4)
                           : propertyId;

    if (id == QLatin1String("trimStart"))
      return &trimStart;

    if (id == QLatin1String("trimEnd"))
      return &trimEnd;

    if (id == QLatin1String("trimOffset"))
      return &trimOffset;

    if (id == QLatin1String("strokeWidthOverride"))
      return &strokeWidthOverride;

    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &propertyId) const override {
    return const_cast<SvgComponent *>(this)->findProperty(propertyId);
  }

  /**
   * Sets an SVG property.
   *
   * Static or animated values are written directly to the corresponding
   * AnimProperty. sourcePath is handled separately because it is not an
   * animation property.
   */
  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override {
    const QString id = propertyId.startsWith(QLatin1String("svg."))
                           ? propertyId.mid(4)
                           : propertyId;

    if (id == QLatin1String("sourcePath")) {
      setSourcePath(value.toString());
      return true;
    }

    auto applyAnim = [&](anim::AnimProperty &p, float v) {
      if (p.getIsAnimated()) {
        p.setKeyframe(localFrame, v);
      } else {
        p.setStaticValue(v);
      }
    };

    if (auto *prop = findProperty(id)) {
      bool ok = false;
      float fVal = value.toFloat(&ok);

      if (ok) {
        applyAnim(*prop, fVal);
        return true;
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Animation Channel Information
  // ---------------------------------------------------------------------------

  /**
   * Collects channel/keyframe information for animated SVG properties.
   *
   * Timeline channel frames are converted from the component's local frame
   * space to absolute timeline frame space using clipStartFrame.
   */
  void collectChannelInfo(
      const QString &clipId, int64_t clipStartFrame,
      int64_t relPlayheadFrame,
      std::vector<anim::AnimChannelInfo> &out) const override {
    auto appendProp = [&](const anim::AnimProperty &p, const QString &id,
                          const QString &name, const QString &group,
                          const QString &color) {
      if (!p.getIsAnimated())
        return;

      anim::AnimChannelInfo info;
      info.clipId = clipId;
      info.id = QStringLiteral("svg.") + id;
      info.name = name;
      info.group = group;
      info.color = color;
      info.isAnimated = true;

      for (const auto &k : p.getKeyframes()) {
        const int64_t absF = k.frame + clipStartFrame;

        info.keyframeFrames.push_back(absF);

        if (k.frame == relPlayheadFrame) {
          info.hasKeyframeAtPlayhead = true;
        }

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

    appendProp(trimStart, QStringLiteral("trimStart"),
               QStringLiteral("Trim Start"), QStringLiteral("Trim Paths"),
               QStringLiteral("#10B981"));

    appendProp(trimEnd, QStringLiteral("trimEnd"),
               QStringLiteral("Trim End"), QStringLiteral("Trim Paths"),
               QStringLiteral("#10B981"));

    appendProp(trimOffset, QStringLiteral("trimOffset"),
               QStringLiteral("Trim Offset"), QStringLiteral("Trim Paths"),
               QStringLiteral("#10B981"));

    appendProp(strokeWidthOverride,
               QStringLiteral("strokeWidthOverride"),
               QStringLiteral("Stroke Width"), QStringLiteral("Stroke"),
               QStringLiteral("#F59E0B"));
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;

    obj[QStringLiteral("sourcePath")] = m_sourcePath;
    obj[QStringLiteral("trimStart")] = trimStart.serialize();
    obj[QStringLiteral("trimEnd")] = trimEnd.serialize();
    obj[QStringLiteral("trimOffset")] = trimOffset.serialize();
    obj[QStringLiteral("strokeWidthOverride")] =
        strokeWidthOverride.serialize();

    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    if (obj.contains(QStringLiteral("sourcePath"))) {
      setSourcePath(obj.value(QStringLiteral("sourcePath")).toString());
    }

    if (obj.contains(QStringLiteral("trimStart"))) {
      trimStart.deserializeInto(
          obj[QStringLiteral("trimStart")].toObject(), 0.0f);
    }

    if (obj.contains(QStringLiteral("trimEnd"))) {
      trimEnd.deserializeInto(
          obj[QStringLiteral("trimEnd")].toObject(), 1.0f);
    }

    if (obj.contains(QStringLiteral("trimOffset"))) {
      trimOffset.deserializeInto(
          obj[QStringLiteral("trimOffset")].toObject(), 0.0f);
    }

    if (obj.contains(QStringLiteral("strokeWidthOverride"))) {
      strokeWidthOverride.deserializeInto(
          obj[QStringLiteral("strokeWidthOverride")].toObject(), -1.0f);
    }
  }

  // ---------------------------------------------------------------------------
  // SVG Source
  // ---------------------------------------------------------------------------

  /**
   * Sets the SVG source path and reloads the parsed SVG document.
   *
   * An empty path clears the current document.
   */
  void setSourcePath(const QString &path) {
    m_sourcePath = path;

    if (!path.isEmpty()) {
      m_document = vector::SvgDocument::fromFile(path);
    } else {
      m_document = vector::SvgDocument{};
    }
  }

  [[nodiscard]] const QString &sourcePath() const noexcept {
    return m_sourcePath;
  }

  [[nodiscard]] const vector::SvgDocument &document() const noexcept {
    return m_document;
  }

  // ---------------------------------------------------------------------------
  // Animated Properties
  // ---------------------------------------------------------------------------

  anim::AnimProperty trimStart{0.0f};
  anim::AnimProperty trimEnd{1.0f};
  anim::AnimProperty trimOffset{0.0f};
  anim::AnimProperty strokeWidthOverride{-1.0f};

private:
  // ---------------------------------------------------------------------------
  // Source Data
  // ---------------------------------------------------------------------------

  QString m_sourcePath;
  vector::SvgDocument m_document;
};

} // namespace xyla
