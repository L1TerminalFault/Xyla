#include "textComponent.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/log/logger.hpp"
#include <QJsonArray>

namespace xyla {

QJsonObject GradientStop::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("position")] = static_cast<double>(position);
  obj[QStringLiteral("color")] = color.name(QColor::HexArgb);
  return obj;
}

GradientStop GradientStop::deserialize(const QJsonObject &obj) {
  GradientStop gs;
  gs.position =
      static_cast<float>(obj.value(QStringLiteral("position")).toDouble(0.0));
  gs.color = QColor(
      obj.value(QStringLiteral("color")).toString(QStringLiteral("#ffffffff")));
  return gs;
}

QJsonObject GradientConfig::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("type")] = static_cast<int>(type);
  obj[QStringLiteral("scope")] = static_cast<int>(scope);
  obj[QStringLiteral("angleDegrees")] = static_cast<double>(angleDegrees);
  obj[QStringLiteral("startX")] = static_cast<double>(startX);
  obj[QStringLiteral("startY")] = static_cast<double>(startY);
  obj[QStringLiteral("endX")] = static_cast<double>(endX);
  obj[QStringLiteral("endY")] = static_cast<double>(endY);
  obj[QStringLiteral("radialRadius")] = static_cast<double>(radialRadius);

  QJsonArray stopArr;
  for (const auto &s : stops) {
    stopArr.append(s.serialize());
  }
  obj[QStringLiteral("stops")] = stopArr;
  return obj;
}

void GradientConfig::deserialize(const QJsonObject &obj) {
  type = static_cast<GradientType>(obj.value(QStringLiteral("type")).toInt(0));
  scope =
      static_cast<GradientScope>(obj.value(QStringLiteral("scope")).toInt(0));
  angleDegrees = static_cast<float>(
      obj.value(QStringLiteral("angleDegrees")).toDouble(0.0));
  startX =
      static_cast<float>(obj.value(QStringLiteral("startX")).toDouble(0.0));
  startY =
      static_cast<float>(obj.value(QStringLiteral("startY")).toDouble(0.0));
  endX = static_cast<float>(obj.value(QStringLiteral("endX")).toDouble(1.0));
  endY = static_cast<float>(obj.value(QStringLiteral("endY")).toDouble(0.0));
  radialRadius = static_cast<float>(
      obj.value(QStringLiteral("radialRadius")).toDouble(0.5));

  stops.clear();
  if (obj.contains(QStringLiteral("stops")) &&
      obj[QStringLiteral("stops")].isArray()) {
    for (const auto &v : obj[QStringLiteral("stops")].toArray()) {
      stops.push_back(GradientStop::deserialize(v.toObject()));
    }
  }
}

QJsonObject RichTextSpan::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("startChar")] = static_cast<int>(startChar);
  obj[QStringLiteral("length")] = static_cast<int>(length);
  if (fontFamily)
    obj[QStringLiteral("fontFamily")] = *fontFamily;
  if (fontWeight)
    obj[QStringLiteral("fontWeight")] = *fontWeight;
  if (italic)
    obj[QStringLiteral("italic")] = *italic;
  if (underline)
    obj[QStringLiteral("underline")] = *underline;
  if (strikethrough)
    obj[QStringLiteral("strikethrough")] = *strikethrough;
  if (fontSize)
    obj[QStringLiteral("fontSize")] = static_cast<double>(*fontSize);
  if (fillColor)
    obj[QStringLiteral("fillColor")] = fillColor->name(QColor::HexArgb);
  if (strokeColor)
    obj[QStringLiteral("strokeColor")] = strokeColor->name(QColor::HexArgb);
  if (strokeWidth)
    obj[QStringLiteral("strokeWidth")] = static_cast<double>(*strokeWidth);
  if (tracking)
    obj[QStringLiteral("tracking")] = static_cast<double>(*tracking);
  return obj;
}

RichTextSpan RichTextSpan::deserialize(const QJsonObject &obj) {
  RichTextSpan s;
  s.startChar =
      static_cast<uint32_t>(obj.value(QStringLiteral("startChar")).toInt(0));
  s.length =
      static_cast<uint32_t>(obj.value(QStringLiteral("length")).toInt(0));
  if (obj.contains(QStringLiteral("fontFamily")))
    s.fontFamily = obj.value(QStringLiteral("fontFamily")).toString();
  if (obj.contains(QStringLiteral("fontWeight")))
    s.fontWeight = obj.value(QStringLiteral("fontWeight")).toInt();
  if (obj.contains(QStringLiteral("italic")))
    s.italic = obj.value(QStringLiteral("italic")).toBool();
  if (obj.contains(QStringLiteral("underline")))
    s.underline = obj.value(QStringLiteral("underline")).toBool();
  if (obj.contains(QStringLiteral("strikethrough")))
    s.strikethrough = obj.value(QStringLiteral("strikethrough")).toBool();
  if (obj.contains(QStringLiteral("fontSize")))
    s.fontSize =
        static_cast<float>(obj.value(QStringLiteral("fontSize")).toDouble());
  if (obj.contains(QStringLiteral("fillColor")))
    s.fillColor = QColor(obj.value(QStringLiteral("fillColor")).toString());
  if (obj.contains(QStringLiteral("strokeColor")))
    s.strokeColor = QColor(obj.value(QStringLiteral("strokeColor")).toString());
  if (obj.contains(QStringLiteral("strokeWidth")))
    s.strokeWidth =
        static_cast<float>(obj.value(QStringLiteral("strokeWidth")).toDouble());
  if (obj.contains(QStringLiteral("tracking")))
    s.tracking =
        static_cast<float>(obj.value(QStringLiteral("tracking")).toDouble());
  return s;
}

TextComponent::TextComponent() {
  animator = std::make_unique<vector::RangeTextAnimator>();
}

TextComponent::TextComponent(const TextComponent &other)
    : ClipComponent(other), text(other.text), fontFamily(other.fontFamily),
      fontWeight(other.fontWeight), italic(other.italic),
      underline(other.underline), strikethrough(other.strikethrough),
      horizontalAlignment(other.horizontalAlignment),
      verticalAlignment(other.verticalAlignment),
      strokePosition(other.strokePosition), fillGradient(other.fillGradient),
      strokeGradient(other.strokeGradient), richTextSpans(other.richTextSpans),
      handles(other.handles), m_animMgr(other.m_animMgr) {
  if (other.animator) {
    animator = other.animator->clone();
  }
}

TextComponent &TextComponent::operator=(const TextComponent &other) {
  if (this == &other)
    return *this;
  ClipComponent::operator=(other);
  text = other.text;
  fontFamily = other.fontFamily;
  fontWeight = other.fontWeight;
  italic = other.italic;
  underline = other.underline;
  strikethrough = other.strikethrough;
  horizontalAlignment = other.horizontalAlignment;
  verticalAlignment = other.verticalAlignment;
  strokePosition = other.strokePosition;
  fillGradient = other.fillGradient;
  strokeGradient = other.strokeGradient;
  richTextSpans = other.richTextSpans;
  handles = other.handles;
  m_animMgr = other.m_animMgr;
  if (other.animator)
    animator = other.animator->clone();
  else
    animator.reset();
  return *this;
}

std::unique_ptr<ClipComponent> TextComponent::clone() const {
  return std::make_unique<TextComponent>(*this);
}

void TextComponent::bindAnimationManager(const QString &clipId,
                                         anim::AnimationManager &animMgr) {
  m_animMgr = &animMgr;
  const QString prefix = clipId + QStringLiteral(".text.");

  // Static Metadata
  animMgr.registerStaticProperty(clipId, prefix + QStringLiteral("text"), text,
                                 QStringLiteral("Text"));
  animMgr.registerStaticProperty(clipId, prefix + QStringLiteral("fontFamily"),
                                 fontFamily, QStringLiteral("Font Family"));
  animMgr.registerStaticProperty(clipId, prefix + QStringLiteral("fontWeight"),
                                 fontWeight, QStringLiteral("Font Weight"));

  // Register Canonical Base Channels into the Table
  auto regBase = [&](vector::TextPropertyId id, const QString &name, float def,
                     const QString &grp) {
    handles.base[static_cast<size_t>(id)] =
        animMgr.registerFloatProperty(clipId, prefix + name, def, name, grp);
  };

  regBase(vector::TextPropertyId::FontSize, QStringLiteral("fontSize"), 72.0f,
          QStringLiteral("Typography"));
  regBase(vector::TextPropertyId::Tracking, QStringLiteral("tracking"), 0.0f,
          QStringLiteral("Typography"));
  regBase(vector::TextPropertyId::LineSpacing, QStringLiteral("lineSpacing"),
          1.2f, QStringLiteral("Typography"));

  regBase(vector::TextPropertyId::FillRed, QStringLiteral("fillRed"), 1.0f,
          QStringLiteral("Fill"));
  regBase(vector::TextPropertyId::FillGreen, QStringLiteral("fillGreen"), 1.0f,
          QStringLiteral("Fill"));
  regBase(vector::TextPropertyId::FillBlue, QStringLiteral("fillBlue"), 1.0f,
          QStringLiteral("Fill"));
  regBase(vector::TextPropertyId::FillAlpha, QStringLiteral("fillAlpha"), 1.0f,
          QStringLiteral("Fill"));

  regBase(vector::TextPropertyId::StrokeWidth, QStringLiteral("strokeWidth"),
          0.0f, QStringLiteral("Stroke"));
  regBase(vector::TextPropertyId::StrokeRed, QStringLiteral("strokeRed"), 0.0f,
          QStringLiteral("Stroke"));
  regBase(vector::TextPropertyId::StrokeGreen, QStringLiteral("strokeGreen"),
          0.0f, QStringLiteral("Stroke"));
  regBase(vector::TextPropertyId::StrokeBlue, QStringLiteral("strokeBlue"),
          0.0f, QStringLiteral("Stroke"));
  regBase(vector::TextPropertyId::StrokeAlpha, QStringLiteral("strokeAlpha"),
          1.0f, QStringLiteral("Stroke"));

  regBase(vector::TextPropertyId::TrimStart, QStringLiteral("trimStart"), 0.0f,
          QStringLiteral("Trim"));
  regBase(vector::TextPropertyId::TrimEnd, QStringLiteral("trimEnd"), 1.0f,
          QStringLiteral("Trim"));
  regBase(vector::TextPropertyId::TrimOffset, QStringLiteral("trimOffset"),
          0.0f, QStringLiteral("Trim"));

  // Bind the single animator channels
  if (animator) {
    animator->bindAnimationManager(clipId, animMgr, handles);
  }
}

anim::AnimProperty *TextComponent::findProperty(const QString &propertyId) {
  Q_UNUSED(propertyId);
  // Pure Table Architecture: Curves and keyframes are accessed via handles on
  // AnimationPropertyTable
  return nullptr;
}

const anim::AnimProperty *
TextComponent::findProperty(const QString &propertyId) const {
  Q_UNUSED(propertyId);
  return nullptr;
}

void TextComponent::collectChannelInfo(
    const QString &clipId, int64_t clipStartFrame, int64_t relPlayheadFrame,
    std::vector<anim::AnimChannelInfo> &out) const {
  Q_UNUSED(clipId);
  Q_UNUSED(clipStartFrame);
  Q_UNUSED(relPlayheadFrame);
  Q_UNUSED(out);
  // Animation channels are published directly by
  // AnimationPropertyTable/AnimationManager
}

bool TextComponent::setProperty(const QString &propertyId,
                                const QVariant &value, FrameIndex localFrame) {
  QString id = propertyId.startsWith(QLatin1String("text.")) ? propertyId.mid(5)
                                                             : propertyId;

  // 1. Static Typography & Text Metadata
  if (id == QLatin1String("text")) {
    text = value.toString();
    return true;
  }
  if (id == QLatin1String("fontFamily")) {
    fontFamily = value.toString();
    return true;
  }
  if (id == QLatin1String("fontWeight")) {
    fontWeight = value.toInt();
    return true;
  }
  if (id == QLatin1String("italic")) {
    italic = value.toBool();
    return true;
  }
  if (id == QLatin1String("underline")) {
    underline = value.toBool();
    return true;
  }
  if (id == QLatin1String("strikethrough")) {
    strikethrough = value.toBool();
    return true;
  }
  if (id == QLatin1String("horizontalAlignment") ||
      id == QLatin1String("hAlignment")) {
    horizontalAlignment = static_cast<TextHAlignment>(value.toInt());
    return true;
  }
  if (id == QLatin1String("verticalAlignment") ||
      id == QLatin1String("vAlignment")) {
    verticalAlignment = static_cast<TextVAlignment>(value.toInt());
    return true;
  }
  if (id == QLatin1String("strokePosition")) {
    strokePosition = static_cast<StrokePosition>(value.toInt());
    return true;
  }
  if (id == QLatin1String("fillGradient")) {
    if (value.userType() == QMetaType::QJsonObject) {
      fillGradient.deserialize(value.toJsonObject());
      return true;
    } else if (value.canConvert<QVariantMap>()) {
      fillGradient.deserialize(QJsonObject::fromVariantMap(value.toMap()));
      return true;
    }
  }
  if (id == QLatin1String("strokeGradient")) {
    if (value.userType() == QMetaType::QJsonObject) {
      strokeGradient.deserialize(value.toJsonObject());
      return true;
    } else if (value.canConvert<QVariantMap>()) {
      strokeGradient.deserialize(QJsonObject::fromVariantMap(value.toMap()));
      return true;
    }
  }

  // Helper lambda: O(1) mutation directly into AnimationPropertyTable via
  // PropertyHandle
  auto setTableHandle = [&](vector::TextPropertyId propId,
                            const QVariant &val) -> bool {
    if (!m_animMgr) {
      XYLA_LOG_WARN(
          "TextComponent",
          "setTableHandle failed: m_animMgr is NULL on TextComponent!");
      return false;
    }

    const auto handle = handles.base[static_cast<size_t>(propId)];
    if (!handle.isValid()) {
      XYLA_LOG_WARN("TextComponent",
                    std::format("setTableHandle failed: handle.index is "
                                "UINT32_MAX (invalid) for propId {}!",
                                static_cast<int>(propId)));
      return false;
    }

    bool ok = m_animMgr->setProperty(handle, val, localFrame);
    if (!ok) {
      XYLA_LOG_WARN("TextComponent",
                    std::format("setTableHandle failed: m_animMgr->setProperty "
                                "returned FALSE for propId {}!",
                                static_cast<int>(propId)));
    }
    return ok;
  };
  ;

  // 2. Table-Backed Channels (Typography)
  if (id == QLatin1String("fontSize"))
    return setTableHandle(vector::TextPropertyId::FontSize, value);
  if (id == QLatin1String("tracking"))
    return setTableHandle(vector::TextPropertyId::Tracking, value);
  if (id == QLatin1String("lineSpacing"))
    return setTableHandle(vector::TextPropertyId::LineSpacing, value);

  // 3. Table-Backed Channels (Fill & Stroke Colors)
  if (id == QLatin1String("fillColor")) {
    QColor c = value.canConvert<QColor>() ? value.value<QColor>()
                                          : QColor(value.toString());
    if (c.isValid()) {
      bool ok = true;
      ok &= setTableHandle(vector::TextPropertyId::FillRed,
                           static_cast<float>(c.redF()));
      ok &= setTableHandle(vector::TextPropertyId::FillGreen,
                           static_cast<float>(c.greenF()));
      ok &= setTableHandle(vector::TextPropertyId::FillBlue,
                           static_cast<float>(c.blueF()));
      ok &= setTableHandle(vector::TextPropertyId::FillAlpha,
                           static_cast<float>(c.alphaF()));
      return ok;
    }
  }
  if (id == QLatin1String("strokeColor")) {
    QColor c = value.canConvert<QColor>() ? value.value<QColor>()
                                          : QColor(value.toString());
    if (c.isValid()) {
      bool ok = true;
      ok &= setTableHandle(vector::TextPropertyId::StrokeRed,
                           static_cast<float>(c.redF()));
      ok &= setTableHandle(vector::TextPropertyId::StrokeGreen,
                           static_cast<float>(c.greenF()));
      ok &= setTableHandle(vector::TextPropertyId::StrokeBlue,
                           static_cast<float>(c.blueF()));
      ok &= setTableHandle(vector::TextPropertyId::StrokeAlpha,
                           static_cast<float>(c.alphaF()));
      return ok;
    }
  }
  if (id == QLatin1String("strokeWidth"))
    return setTableHandle(vector::TextPropertyId::StrokeWidth, value);

  // 4. Table-Backed Channels (Trim Paths)
  if (id == QLatin1String("trimStart"))
    return setTableHandle(vector::TextPropertyId::TrimStart, value);
  if (id == QLatin1String("trimEnd"))
    return setTableHandle(vector::TextPropertyId::TrimEnd, value);
  if (id == QLatin1String("trimOffset"))
    return setTableHandle(vector::TextPropertyId::TrimOffset, value);

  return false;
}

QJsonObject TextComponent::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("text")] = text;
  obj[QStringLiteral("fontFamily")] = fontFamily;
  obj[QStringLiteral("fontWeight")] = fontWeight;
  obj[QStringLiteral("italic")] = italic;
  obj[QStringLiteral("underline")] = underline;
  obj[QStringLiteral("strikethrough")] = strikethrough;

  obj[QStringLiteral("hAlignment")] = static_cast<int>(horizontalAlignment);
  obj[QStringLiteral("vAlignment")] = static_cast<int>(verticalAlignment);
  obj[QStringLiteral("strokePosition")] = static_cast<int>(strokePosition);

  obj[QStringLiteral("fillGradient")] = fillGradient.serialize();
  obj[QStringLiteral("strokeGradient")] = strokeGradient.serialize();

  QJsonArray spanArr;
  for (const auto &span : richTextSpans) {
    spanArr.append(span.serialize());
  }
  obj[QStringLiteral("richTextSpans")] = spanArr;

  if (animator) {
    QJsonObject animObj = animator->serialize();
    animObj[QStringLiteral("kind")] = static_cast<int>(animator->kind());
    obj[QStringLiteral("animator")] = animObj;
  }

  return obj;
}

void TextComponent::deserialize(const QJsonObject &obj) {
  text = obj.value(QStringLiteral("text")).toString(QStringLiteral("Title"));
  fontFamily =
      obj.value(QStringLiteral("fontFamily")).toString(QStringLiteral("Inter"));
  fontWeight = obj.value(QStringLiteral("fontWeight")).toInt(400);
  italic = obj.value(QStringLiteral("italic")).toBool(false);
  underline = obj.value(QStringLiteral("underline")).toBool(false);
  strikethrough = obj.value(QStringLiteral("strikethrough")).toBool(false);

  horizontalAlignment = static_cast<TextHAlignment>(
      obj.value(QStringLiteral("hAlignment"))
          .toInt(static_cast<int>(TextHAlignment::Center)));
  verticalAlignment = static_cast<TextVAlignment>(
      obj.value(QStringLiteral("vAlignment"))
          .toInt(static_cast<int>(TextVAlignment::Middle)));
  strokePosition = static_cast<StrokePosition>(
      obj.value(QStringLiteral("strokePosition"))
          .toInt(static_cast<int>(StrokePosition::Center)));

  if (obj.contains(QStringLiteral("fillGradient")))
    fillGradient.deserialize(obj[QStringLiteral("fillGradient")].toObject());
  if (obj.contains(QStringLiteral("strokeGradient")))
    strokeGradient.deserialize(
        obj[QStringLiteral("strokeGradient")].toObject());

  richTextSpans.clear();
  if (obj.contains(QStringLiteral("richTextSpans")) &&
      obj[QStringLiteral("richTextSpans")].isArray()) {
    for (const auto &v : obj[QStringLiteral("richTextSpans")].toArray()) {
      richTextSpans.push_back(RichTextSpan::deserialize(v.toObject()));
    }
  }

  if (obj.contains(QStringLiteral("animator")) &&
      obj[QStringLiteral("animator")].isObject()) {
    QJsonObject aObj = obj[QStringLiteral("animator")].toObject();
    auto k = static_cast<vector::TextAnimatorKind>(
        aObj.value(QStringLiteral("kind")).toInt(0));
    if (k == vector::TextAnimatorKind::RangeSelector) {
      animator = std::make_unique<vector::RangeTextAnimator>();
      animator->deserialize(aObj);
    }
  }
}

} // namespace xyla
