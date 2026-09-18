#include "textComponent.hpp"
#include <QColor>
#include <QJsonArray>
#include <QStringList>
#include <algorithm>

namespace xyla {

TextComponent::TextComponent() = default;

std::unique_ptr<ClipComponent> TextComponent::clone() const {
  return std::make_unique<TextComponent>(*this);
}

anim::AnimProperty *TextComponent::findProperty(const QString &propertyId) {
  QString id = propertyId.startsWith("text.") ? propertyId.mid(5) : propertyId;

  // Handle animator range selector keyframe properties: e.g. "animator.0.start"
  if (id.startsWith("animator.")) {
    const auto parts = id.split('.');
    if (parts.size() >= 3) {
      bool ok = false;
      int idx = parts[1].toInt(&ok);
      if (ok && idx >= 0 && idx < static_cast<int>(animators.size())) {
        auto &anim = animators[idx];
        if (!anim.selectors.empty()) {
          QString propName = parts[2];
          if (propName == "start")
            return &anim.selectors[0].start;
          if (propName == "end")
            return &anim.selectors[0].end;
          if (propName == "offset")
            return &anim.selectors[0].offset;
        }
      }
    }
  }

  if (id == "fontSize")
    return &fontSize;
  if (id == "tracking")
    return &tracking;
  if (id == "lineSpacing")
    return &lineSpacing;
  if (id == "fillRed")
    return &fillRed;
  if (id == "fillGreen")
    return &fillGreen;
  if (id == "fillBlue")
    return &fillBlue;
  if (id == "fillAlpha")
    return &fillAlpha;
  if (id == "strokeWidth")
    return &strokeWidth;
  if (id == "strokeRed")
    return &strokeRed;
  if (id == "strokeGreen")
    return &strokeGreen;
  if (id == "strokeBlue")
    return &strokeBlue;
  if (id == "strokeAlpha")
    return &strokeAlpha;
  if (id == "trimStart")
    return &trimStart;
  if (id == "trimEnd")
    return &trimEnd;
  if (id == "trimOffset")
    return &trimOffset;
  return nullptr;
}

const anim::AnimProperty *
TextComponent::findProperty(const QString &propertyId) const {
  return const_cast<TextComponent *>(this)->findProperty(propertyId);
}

void TextComponent::collectChannelInfo(
    const QString &clipId, int64_t clipStartFrame, int64_t relPlayheadFrame,
    std::vector<anim::AnimChannelInfo> &out) const {
  auto appendProp = [&](const anim::AnimProperty &p, const QString &id,
                        const QString &name, const QString &group,
                        const QString &color) {
    if (!p.getIsAnimated())
      return;

    anim::AnimChannelInfo info;
    info.clipId = clipId;
    info.id = QStringLiteral("text.") + id;
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

  appendProp(fontSize, "fontSize", "Font Size", "Text", "#60A5FA");
  appendProp(tracking, "tracking", "Tracking", "Text", "#60A5FA");
  appendProp(lineSpacing, "lineSpacing", "Line Spacing", "Text", "#60A5FA");
  appendProp(strokeWidth, "strokeWidth", "Stroke Width", "Stroke", "#F59E0B");
  appendProp(trimStart, "trimStart", "Trim Start", "Trim Paths", "#10B981");
  appendProp(trimEnd, "trimEnd", "Trim End", "Trim Paths", "#10B981");
  appendProp(trimOffset, "trimOffset", "Trim Offset", "Trim Paths", "#10B981");

  for (size_t i = 0; i < animators.size(); ++i) {
    const auto &anim = animators[i];
    if (anim.selectors.empty())
      continue;
    const auto &sel = anim.selectors[0];
    QString prefix = QString("animator.%1.").arg(i);
    appendProp(sel.start, prefix + "start", anim.name + " Start", "Animators",
               "#10B981");
    appendProp(sel.end, prefix + "end", anim.name + " End", "Animators",
               "#10B981");
    appendProp(sel.offset, prefix + "offset", anim.name + " Offset",
               "Animators", "#3B82F6");
  }
}

QJsonObject TextComponent::serialize() const {
  QJsonObject obj;
  obj["text"] = text;
  obj["fontFamily"] = fontFamily;
  obj["alignment"] = static_cast<int>(alignment);
  obj["strokePosition"] = static_cast<int>(strokePosition);
  obj["fontSize"] = fontSize.serialize();
  obj["tracking"] = tracking.serialize();
  obj["lineSpacing"] = lineSpacing.serialize();
  obj["fillRed"] = fillRed.serialize();
  obj["fillGreen"] = fillGreen.serialize();
  obj["fillBlue"] = fillBlue.serialize();
  obj["fillAlpha"] = fillAlpha.serialize();
  obj["strokeWidth"] = strokeWidth.serialize();
  obj["strokeRed"] = strokeRed.serialize();
  obj["strokeGreen"] = strokeGreen.serialize();
  obj["strokeBlue"] = strokeBlue.serialize();
  obj["strokeAlpha"] = strokeAlpha.serialize();
  obj["trimStart"] = trimStart.serialize();
  obj["trimEnd"] = trimEnd.serialize();
  obj["trimOffset"] = trimOffset.serialize();

  QJsonArray animArr;
  for (const auto &anim : animators) {
    animArr.append(anim.serialize());
  }
  obj["animators"] = animArr;

  return obj;
}

void TextComponent::deserialize(const QJsonObject &obj) {
  text = obj.value("text").toString(QStringLiteral("Sample Title"));
  fontFamily = obj.value("fontFamily").toString(QStringLiteral("Inter"));
  alignment = static_cast<vector::TextAlignment>(
      obj.value("alignment")
          .toInt(static_cast<int>(vector::TextAlignment::Center)));
  strokePosition = static_cast<StrokePosition>(
      obj.value("strokePosition")
          .toInt(static_cast<int>(StrokePosition::Center)));

  if (obj.contains("fontSize"))
    fontSize.deserializeInto(obj["fontSize"].toObject(), 72.0f);
  if (obj.contains("tracking"))
    tracking.deserializeInto(obj["tracking"].toObject(), 0.0f);
  if (obj.contains("lineSpacing"))
    lineSpacing.deserializeInto(obj["lineSpacing"].toObject(), 1.2f);
  if (obj.contains("fillRed"))
    fillRed.deserializeInto(obj["fillRed"].toObject(), 1.0f);
  if (obj.contains("fillGreen"))
    fillGreen.deserializeInto(obj["fillGreen"].toObject(), 1.0f);
  if (obj.contains("fillBlue"))
    fillBlue.deserializeInto(obj["fillBlue"].toObject(), 1.0f);
  if (obj.contains("fillAlpha"))
    fillAlpha.deserializeInto(obj["fillAlpha"].toObject(), 1.0f);
  if (obj.contains("strokeWidth"))
    strokeWidth.deserializeInto(obj["strokeWidth"].toObject(), 0.0f);
  if (obj.contains("strokeRed"))
    strokeRed.deserializeInto(obj["strokeRed"].toObject(), 0.0f);
  if (obj.contains("strokeGreen"))
    strokeGreen.deserializeInto(obj["strokeGreen"].toObject(), 0.0f);
  if (obj.contains("strokeBlue"))
    strokeBlue.deserializeInto(obj["strokeBlue"].toObject(), 0.0f);
  if (obj.contains("strokeAlpha"))
    strokeAlpha.deserializeInto(obj["strokeAlpha"].toObject(), 1.0f);
  if (obj.contains("trimStart"))
    trimStart.deserializeInto(obj["trimStart"].toObject(), 0.0f);
  if (obj.contains("trimEnd"))
    trimEnd.deserializeInto(obj["trimEnd"].toObject(), 1.0f);
  if (obj.contains("trimOffset"))
    trimOffset.deserializeInto(obj["trimOffset"].toObject(), 0.0f);

  animators.clear();
  if (obj.contains("animators") && obj["animators"].isArray()) {
    for (const auto &v : obj["animators"].toArray()) {
      vector::TextAnimator a;
      a.deserialize(v.toObject());
      animators.push_back(std::move(a));
    }
  }
}

bool TextComponent::setProperty(const QString &propertyId,
                                const QVariant &value, FrameIndex localFrame) {
  QString id = propertyId.startsWith("text.") ? propertyId.mid(5) : propertyId;

  auto applyAnim = [&](anim::AnimProperty &p, float v) {
    if (p.getIsAnimated()) {
      p.setKeyframe(localFrame, v);
    } else {
      p.setStaticValue(v);
    }
  };

  if (id == "text") {
    text = value.toString();
    return true;
  }
  if (id == "fontFamily") {
    fontFamily = value.toString();
    return true;
  }
  if (id == "strokePosition") {
    strokePosition = static_cast<StrokePosition>(value.toInt());
    return true;
  }
  if (id == "fillColor") {
    QColor c = value.canConvert<QColor>() ? value.value<QColor>()
                                          : QColor(value.toString());
    if (c.isValid()) {
      applyAnim(fillRed, static_cast<float>(c.redF()));
      applyAnim(fillGreen, static_cast<float>(c.greenF()));
      applyAnim(fillBlue, static_cast<float>(c.blueF()));
      applyAnim(fillAlpha, static_cast<float>(c.alphaF()));
      return true;
    }
  }
  if (id == "strokeColor") {
    QColor c = value.canConvert<QColor>() ? value.value<QColor>()
                                          : QColor(value.toString());
    if (c.isValid()) {
      applyAnim(strokeRed, static_cast<float>(c.redF()));
      applyAnim(strokeGreen, static_cast<float>(c.greenF()));
      applyAnim(strokeBlue, static_cast<float>(c.blueF()));
      applyAnim(strokeAlpha, static_cast<float>(c.alphaF()));
      return true;
    }
  }

  // Animator item lifecycle
  if (id == "animator.add") {
    vector::TextAnimator newAnim;
    newAnim.name = value.toString().isEmpty() ? QStringLiteral("Animator")
                                              : value.toString();
    animators.push_back(std::move(newAnim));
    return true;
  }
  if (id == "animator.remove") {
    int idx = value.toInt();
    if (idx >= 0 && idx < static_cast<int>(animators.size())) {
      animators.erase(animators.begin() + idx);
      return true;
    }
    return false;
  }

  // Routing into animator: "animator.<idx>.<field>"
  if (id.startsWith("animator.")) {
    const auto parts = id.split('.');
    if (parts.size() >= 3) {
      bool ok = false;
      int idx = parts[1].toInt(&ok);
      if (ok && idx >= 0 && idx < static_cast<int>(animators.size())) {
        auto &anim = animators[idx];
        QString animProp = parts[2];

        if (animProp == "enabled") {
          anim.enabled = value.toBool();
          return true;
        }
        if (animProp == "name") {
          anim.name = value.toString();
          return true;
        }

        // Dynamic Delta Management:
        // "animator.<idx>.delta.<add|remove|propertyId>"
        if (animProp == "delta") {
          if (parts.size() >= 4) {
            QString sub = parts[3];
            if (sub == "add") {
              anim.setDeltaValue(value.toString(), 0.0f);
              return true;
            }
            if (sub == "remove") {
              return anim.removeDelta(value.toString());
            }
            // animator.<idx>.delta.<propName> = value
            QString targetProp = parts.mid(3).join('.');
            anim.setDeltaValue(targetProp, value.toFloat());
            return true;
          }
        }

        // Selectors
        if (!anim.selectors.empty()) {
          auto &sel = anim.selectors[0];
          if (animProp == "start") {
            applyAnim(sel.start, value.toFloat());
            return true;
          }
          if (animProp == "end") {
            applyAnim(sel.end, value.toFloat());
            return true;
          }
          if (animProp == "offset") {
            applyAnim(sel.offset, value.toFloat());
            return true;
          }
          if (animProp == "shape") {
            sel.shape = static_cast<vector::SelectorShape>(value.toInt());
            return true;
          }
          if (animProp == "basedOn") {
            sel.basedOn = static_cast<vector::BasedOn>(value.toInt());
            return true;
          }
          if (animProp == "chunkSize") {
            sel.chunkSize = std::max(1, value.toInt());
            return true;
          }
          if (animProp == "customSeparator") {
            sel.customSeparator = value.toString();
            return true;
          }
          if (animProp == "regexPattern") {
            sel.regexPattern = value.toString();
            return true;
          }
          if (animProp == "randomize") {
            sel.randomize = value.toBool();
            return true;
          }
          if (animProp == "randomSeed") {
            sel.randomSeed = static_cast<uint32_t>(value.toInt());
            return true;
          }
        }

        // Direct delta updates from legacy or named paths
        anim.setDeltaValue(animProp, value.toFloat());
        return true;
      }
    }
  }

  // Base fallback numeric properties
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

} // namespace xyla
