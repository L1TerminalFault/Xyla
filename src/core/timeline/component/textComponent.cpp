#include "textComponent.hpp"
#include <QJsonArray>

namespace xyla {

QJsonObject GradientStop::serialize() const {
  QJsonObject obj;
  obj["position"] = static_cast<double>(position);
  obj["color"] = color.name(QColor::HexArgb);
  return obj;
}

GradientStop GradientStop::deserialize(const QJsonObject &obj) {
  GradientStop gs;
  gs.position = static_cast<float>(obj.value("position").toDouble(0.0));
  gs.color = QColor(obj.value("color").toString(QStringLiteral("#ffffffff")));
  return gs;
}

QJsonObject GradientConfig::serialize() const {
  QJsonObject obj;
  obj["type"] = static_cast<int>(type);
  obj["scope"] = static_cast<int>(scope);
  obj["angleDegrees"] = static_cast<double>(angleDegrees);
  obj["startX"] = static_cast<double>(startX);
  obj["startY"] = static_cast<double>(startY);
  obj["endX"] = static_cast<double>(endX);
  obj["endY"] = static_cast<double>(endY);
  obj["radialRadius"] = static_cast<double>(radialRadius);

  QJsonArray stopArr;
  for (const auto &s : stops) {
    stopArr.append(s.serialize());
  }
  obj["stops"] = stopArr;
  return obj;
}

void GradientConfig::deserialize(const QJsonObject &obj) {
  type = static_cast<GradientType>(obj.value("type").toInt(0));
  scope = static_cast<GradientScope>(obj.value("scope").toInt(0));
  angleDegrees = static_cast<float>(obj.value("angleDegrees").toDouble(0.0));
  startX = static_cast<float>(obj.value("startX").toDouble(0.0));
  startY = static_cast<float>(obj.value("startY").toDouble(0.0));
  endX = static_cast<float>(obj.value("endX").toDouble(1.0));
  endY = static_cast<float>(obj.value("endY").toDouble(0.0));
  radialRadius = static_cast<float>(obj.value("radialRadius").toDouble(0.5));

  stops.clear();
  if (obj.contains("stops") && obj["stops"].isArray()) {
    for (const auto &v : obj["stops"].toArray()) {
      stops.push_back(GradientStop::deserialize(v.toObject()));
    }
  }
}

TextComponent::TextComponent() = default;

std::unique_ptr<ClipComponent> TextComponent::clone() const {
  return std::make_unique<TextComponent>(*this);
}

anim::AnimProperty *TextComponent::findProperty(const QString &propertyId) {
  QString id = propertyId.startsWith("text.") ? propertyId.mid(5) : propertyId;

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
  obj["fontWeight"] = fontWeight;
  obj["italic"] = italic;
  obj["underline"] = underline;
  obj["strikethrough"] = strikethrough;

  obj["hAlignment"] = static_cast<int>(horizontalAlignment);
  obj["vAlignment"] = static_cast<int>(verticalAlignment);
  obj["strokePosition"] = static_cast<int>(strokePosition);

  obj["fontSize"] = fontSize.serialize();
  obj["tracking"] = tracking.serialize();
  obj["lineSpacing"] = lineSpacing.serialize();
  obj["fillRed"] = fillRed.serialize();
  obj["fillGreen"] = fillGreen.serialize();
  obj["fillBlue"] = fillBlue.serialize();
  obj["fillAlpha"] = fillAlpha.serialize();
  obj["fillGradient"] = fillGradient.serialize();

  obj["strokeWidth"] = strokeWidth.serialize();
  obj["strokeRed"] = strokeRed.serialize();
  obj["strokeGreen"] = strokeGreen.serialize();
  obj["strokeBlue"] = strokeBlue.serialize();
  obj["strokeAlpha"] = strokeAlpha.serialize();
  obj["strokeGradient"] = strokeGradient.serialize();

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
  text = obj.value("text").toString(QStringLiteral("Title"));
  fontFamily = obj.value("fontFamily").toString(QStringLiteral("Inter"));
  fontWeight = obj.value("fontWeight").toInt(400);
  italic = obj.value("italic").toBool(false);
  underline = obj.value("underline").toBool(false);
  strikethrough = obj.value("strikethrough").toBool(false);

  horizontalAlignment = static_cast<TextHAlignment>(
      obj.value("hAlignment")
          .toInt(obj.value("alignment")
                     .toInt(static_cast<int>(TextHAlignment::Center))));
  verticalAlignment = static_cast<TextVAlignment>(
      obj.value("vAlignment").toInt(static_cast<int>(TextVAlignment::Middle)));
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
  if (obj.contains("fillGradient"))
    fillGradient.deserialize(obj["fillGradient"].toObject());

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
  if (obj.contains("strokeGradient"))
    strokeGradient.deserialize(obj["strokeGradient"].toObject());

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
  if (id == "fontWeight") {
    fontWeight = value.toInt();
    return true;
  }
  if (id == "italic") {
    italic = value.toBool();
    return true;
  }
  if (id == "underline") {
    underline = value.toBool();
    return true;
  }
  if (id == "strikethrough") {
    strikethrough = value.toBool();
    return true;
  }

  if (id == "horizontalAlignment" || id == "alignment" || id == "hAlignment") {
    horizontalAlignment = static_cast<TextHAlignment>(value.toInt());
    return true;
  }
  if (id == "verticalAlignment" || id == "vAlignment") {
    verticalAlignment = static_cast<TextVAlignment>(value.toInt());
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

  // --- Gradient Configuration Serialization Routing ---
  if (id == "fillGradient") {
    QJsonObject obj;
    if (value.userType() == QMetaType::QJsonObject) {
      obj = value.toJsonObject();
    } else if (value.canConvert<QVariantMap>()) {
      obj = QJsonObject::fromVariantMap(value.toMap());
    }
    fillGradient.deserialize(obj);
    return true;
  }
  if (id == "strokeGradient") {
    QJsonObject obj;
    if (value.userType() == QMetaType::QJsonObject) {
      obj = value.toJsonObject();
    } else if (value.canConvert<QVariantMap>()) {
      obj = QJsonObject::fromVariantMap(value.toMap());
    }
    strokeGradient.deserialize(obj);
    return true;
  }
  // --- Animator Collection Handling ---
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
            QString targetProp = parts.mid(3).join('.');
            anim.setDeltaValue(targetProp, value.toFloat());
            return true;
          }
        }

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

        anim.setDeltaValue(animProp, value.toFloat());
        return true;
      }
    }
  }

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
