#include "svgComponent.hpp"

namespace xyla {

SvgComponent::SvgComponent() = default;

std::unique_ptr<ClipComponent> SvgComponent::clone() const {
  return std::make_unique<SvgComponent>(*this);
}

void SvgComponent::setSourcePath(const QString &path) {
  m_sourcePath = path;
  m_document = vector::SvgDocument::fromFile(path);
}

anim::AnimProperty *SvgComponent::findProperty(const QString &propertyId) {
  if (propertyId == "trimStart")
    return &trimStart;
  if (propertyId == "trimEnd")
    return &trimEnd;
  if (propertyId == "trimOffset")
    return &trimOffset;
  if (propertyId == "strokeWidthOverride")
    return &strokeWidthOverride;
  return nullptr;
}

const anim::AnimProperty *
SvgComponent::findProperty(const QString &propertyId) const {
  return const_cast<SvgComponent *>(this)->findProperty(propertyId);
}

void SvgComponent::collectChannelInfo(
    const QString &clipId, int64_t clipStartFrame, int64_t relPlayheadFrame,
    std::vector<anim::AnimChannelInfo> &out) const {
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

  appendProp(trimStart, "trimStart", "Trim Start", "Trim Paths", "#10B981");
  appendProp(trimEnd, "trimEnd", "Trim End", "Trim Paths", "#10B981");
  appendProp(trimOffset, "trimOffset", "Trim Offset", "Trim Paths", "#10B981");
  appendProp(strokeWidthOverride, "strokeWidthOverride", "Stroke Width",
             "Geometry", "#F59E0B");
}

QJsonObject SvgComponent::serialize() const {
  QJsonObject obj;
  obj["sourcePath"] = m_sourcePath;
  obj["trimStart"] = trimStart.serialize();
  obj["trimEnd"] = trimEnd.serialize();
  obj["trimOffset"] = trimOffset.serialize();
  obj["strokeWidthOverride"] = strokeWidthOverride.serialize();
  return obj;
}

void SvgComponent::deserialize(const QJsonObject &obj) {
  if (obj.contains("sourcePath")) {
    setSourcePath(obj["sourcePath"].toString());
  }
  if (obj.contains("trimStart"))
    trimStart.deserializeInto(obj["trimStart"].toObject(), 0.0f);
  if (obj.contains("trimEnd"))
    trimEnd.deserializeInto(obj["trimEnd"].toObject(), 1.0f);
  if (obj.contains("trimOffset"))
    trimOffset.deserializeInto(obj["trimOffset"].toObject(), 0.0f);
  if (obj.contains("strokeWidthOverride"))
    strokeWidthOverride.deserializeInto(obj["strokeWidthOverride"].toObject(),
                                        -1.0f);
}

} // namespace xyla
