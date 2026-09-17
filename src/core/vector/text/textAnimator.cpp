#include "textAnimator.hpp"
#include <algorithm>
#include <cmath>

namespace xyla::vector {

namespace {

uint32_t hashInteger(uint32_t x) noexcept {
  x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = (x >> 16) ^ x;
  return x;
}

float smoothstepNorm(float edge0, float edge1, float x) noexcept {
  float t = std::clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

} // namespace

QJsonObject PropertyDelta::serialize() const {
  QJsonObject obj;
  obj["propertyId"] = propertyId;
  obj["floatValue"] = static_cast<double>(floatValue);
  obj["vec2X"] = static_cast<double>(vec2Value.x);
  obj["vec2Y"] = static_cast<double>(vec2Value.y);
  obj["color"] = colorValue.name(QColor::HexArgb);
  return obj;
}

PropertyDelta PropertyDelta::deserialize(const QJsonObject &obj) {
  PropertyDelta d;
  d.propertyId = obj.value("propertyId").toString();
  d.floatValue = static_cast<float>(obj.value("floatValue").toDouble(0.0));
  d.vec2Value.x = static_cast<float>(obj.value("vec2X").toDouble(0.0));
  d.vec2Value.y = static_cast<float>(obj.value("vec2Y").toDouble(0.0));
  d.colorValue = QColor(obj.value("color").toString("#ffffffff"));
  return d;
}

void TextRangeSelector::computeUnitIndices(
    const QString &text, size_t totalChars, size_t charIndex,
    size_t &outUnitIndex, size_t &outTotalUnits) const noexcept {
  if (totalChars == 0) {
    outUnitIndex = 0;
    outTotalUnits = 1;
    return;
  }

  switch (basedOn) {
  case BasedOn::Characters:
  default:
    outUnitIndex = charIndex;
    outTotalUnits = totalChars;
    return;

  case BasedOn::CharacterChunks: {
    size_t chunk = static_cast<size_t>(std::max(1, chunkSize));
    outUnitIndex = charIndex / chunk;
    outTotalUnits = (totalChars + chunk - 1) / chunk;
    return;
  }

  case BasedOn::CharactersExcludingSpaces: {
    if (text.isEmpty() || charIndex >= static_cast<size_t>(text.length())) {
      outUnitIndex = charIndex;
      outTotalUnits = totalChars;
      return;
    }
    size_t unit = 0;
    size_t totalNonSpace = 0;
    for (int i = 0; i < text.length(); ++i) {
      if (!text[i].isSpace()) {
        if (static_cast<size_t>(i) == charIndex) {
          outUnitIndex = unit;
        }
        unit++;
        totalNonSpace++;
      } else if (static_cast<size_t>(i) == charIndex) {
        outUnitIndex = unit > 0 ? unit - 1 : 0;
      }
    }
    outTotalUnits = std::max<size_t>(1, totalNonSpace);
    return;
  }

  case BasedOn::Words: {
    if (text.isEmpty() || charIndex >= static_cast<size_t>(text.length())) {
      outUnitIndex = 0;
      outTotalUnits = 1;
      return;
    }
    size_t currentWord = 0;
    bool inWord = false;
    for (int i = 0; i < text.length(); ++i) {
      if (!text[i].isSpace()) {
        if (!inWord) {
          inWord = true;
          if (i > 0)
            currentWord++;
        }
      } else {
        inWord = false;
      }
      if (static_cast<size_t>(i) == charIndex) {
        outUnitIndex = currentWord;
      }
    }
    outTotalUnits = currentWord + 1;
    return;
  }

  case BasedOn::Lines: {
    if (text.isEmpty() || charIndex >= static_cast<size_t>(text.length())) {
      outUnitIndex = 0;
      outTotalUnits = 1;
      return;
    }
    size_t currentLine = 0;
    for (int i = 0; i < text.length(); ++i) {
      if (text[i] == QLatin1Char('\n')) {
        currentLine++;
      }
      if (static_cast<size_t>(i) == charIndex) {
        outUnitIndex = currentLine;
      }
    }
    outTotalUnits = currentLine + 1;
    return;
  }

  case BasedOn::CustomSeparator: {
    if (text.isEmpty() || customSeparator.isEmpty() ||
        charIndex >= static_cast<size_t>(text.length())) {
      outUnitIndex = 0;
      outTotalUnits = 1;
      return;
    }
    const auto parts = text.split(customSeparator);
    outTotalUnits = std::max<size_t>(1, parts.size());
    int accumulated = 0;
    for (size_t p = 0; p < static_cast<size_t>(parts.size()); ++p) {
      accumulated += parts[p].length() + customSeparator.length();
      if (charIndex < static_cast<size_t>(accumulated)) {
        outUnitIndex = p;
        return;
      }
    }
    outUnitIndex = outTotalUnits - 1;
    return;
  }

  case BasedOn::Regex: {
    if (text.isEmpty() || regexPattern.isEmpty() ||
        charIndex >= static_cast<size_t>(text.length())) {
      outUnitIndex = 0;
      outTotalUnits = 1;
      return;
    }
    QRegularExpression re(regexPattern);
    auto it = re.globalMatch(text);
    size_t matchIdx = 0;
    outUnitIndex = 0;
    while (it.hasNext()) {
      auto m = it.next();
      if (static_cast<int>(charIndex) >= m.capturedStart() &&
          static_cast<int>(charIndex) < m.capturedEnd()) {
        outUnitIndex = matchIdx;
      }
      matchIdx++;
    }
    outTotalUnits = std::max<size_t>(1, matchIdx);
    return;
  }
  }
}

float TextRangeSelector::evaluateWeight(
    size_t charIndex, size_t totalChars, int64_t localFrame,
    const QString &sourceText) const noexcept {
  if (totalChars == 0)
    return 0.0f;

  size_t unitIndex = 0;
  size_t totalUnits = 1;
  computeUnitIndices(sourceText, totalChars, charIndex, unitIndex, totalUnits);

  size_t effectiveIndex = unitIndex;
  if (randomize) {
    uint32_t hashed =
        hashInteger(static_cast<uint32_t>(unitIndex) ^ randomSeed);
    effectiveIndex = hashed % totalUnits;
  }

  float u = (static_cast<float>(effectiveIndex) + 0.5f) /
            static_cast<float>(totalUnits);

  float s = std::clamp(start.evaluate(localFrame), 0.0f, 1.0f);
  float e = std::clamp(end.evaluate(localFrame), 0.0f, 1.0f);
  float off = offset.evaluate(localFrame) * 0.01f;

  float uEval = std::fmod(u - off, 1.0f);
  if (uEval < 0.0f)
    uEval += 1.0f;

  if (s > e) {
    std::swap(s, e);
  }

  float range = e - s;
  if (range <= 1e-5f)
    return 0.0f;

  if (uEval < s || uEval > e)
    return 0.0f;

  float norm = (uEval - s) / range;
  float weight = 0.0f;

  switch (shape) {
  case SelectorShape::Square:
    weight = 1.0f;
    break;
  case SelectorShape::RampUp:
    weight = norm;
    break;
  case SelectorShape::RampDown:
    weight = 1.0f - norm;
    break;
  case SelectorShape::Triangle:
    weight = (norm < 0.5f) ? (norm * 2.0f) : ((1.0f - norm) * 2.0f);
    break;
  case SelectorShape::Round:
    weight = std::sin(norm * 3.14159265f);
    break;
  case SelectorShape::Smooth:
    weight = (norm < 0.5f) ? smoothstepNorm(0.0f, 0.5f, norm)
                           : (1.0f - smoothstepNorm(0.5f, 1.0f, norm));
    break;
  case SelectorShape::Gaussian: {
    float x = (norm - 0.5f) * 6.0f;
    weight = std::exp(-0.5f * x * x);
    break;
  }
  }

  if (responseCurve && !responseCurve->isEmpty()) {
    weight = responseCurve->evaluate(weight * 100.0f) * 0.01f;
  }

  return std::clamp(weight, 0.0f, 1.0f);
}

QJsonObject TextRangeSelector::serialize() const {
  QJsonObject obj;

  obj["start"] = static_cast<double>(start.getStaticValue());
  obj["end"] = static_cast<double>(end.getStaticValue());
  obj["offset"] = static_cast<double>(offset.getStaticValue());

  // Full keyframe curves for project serialization:
  obj["startData"] = start.serialize();
  obj["endData"] = end.serialize();
  obj["offsetData"] = offset.serialize();
  obj["shape"] = static_cast<int>(shape);
  obj["combine"] = static_cast<int>(combine);
  obj["basedOn"] = static_cast<int>(basedOn);
  obj["chunkSize"] = chunkSize;
  obj["customSeparator"] = customSeparator;
  obj["regexPattern"] = regexPattern;
  obj["randomize"] = randomize;
  obj["randomSeed"] = static_cast<int>(randomSeed);
  return obj;
}

void TextRangeSelector::deserialize(const QJsonObject &obj) {
  if (obj.contains("startData"))
    start.deserializeInto(obj["startData"].toObject(), 0.0f);
  else if (obj.contains("start")) {
    if (obj["start"].isObject())
      start.deserializeInto(obj["start"].toObject(), 0.0f);
    else
      start.setStaticValue(static_cast<float>(obj["start"].toDouble(0.0)));
  }

  if (obj.contains("endData"))
    end.deserializeInto(obj["endData"].toObject(), 1.0f);
  else if (obj.contains("end")) {
    if (obj["end"].isObject())
      end.deserializeInto(obj["end"].toObject(), 1.0f);
    else
      end.setStaticValue(static_cast<float>(obj["end"].toDouble(1.0)));
  }

  if (obj.contains("offsetData"))
    offset.deserializeInto(obj["offsetData"].toObject(), 0.0f);
  else if (obj.contains("offset")) {
    if (obj["offset"].isObject())
      offset.deserializeInto(obj["offset"].toObject(), 0.0f);
    else
      offset.setStaticValue(static_cast<float>(obj["offset"].toDouble(0.0)));
  }

  shape = static_cast<SelectorShape>(obj.value("shape").toInt(0));
  combine = static_cast<CombineMode>(obj.value("combine").toInt(0));
  basedOn = static_cast<BasedOn>(obj.value("basedOn").toInt(0));
  chunkSize = obj.value("chunkSize").toInt(2);
  customSeparator = obj.value("customSeparator").toString(QStringLiteral("|"));
  regexPattern = obj.value("regexPattern").toString(QStringLiteral("\\w+"));
  randomize = obj.value("randomize").toBool(false);
  randomSeed = static_cast<uint32_t>(obj.value("randomSeed").toInt(12345));
}

TextAnimator::TextAnimator() { selectors.emplace_back(TextRangeSelector{}); }

float TextAnimator::evaluateCombinedWeight(
    size_t charIndex, size_t totalChars, int64_t localFrame,
    const QString &sourceText) const noexcept {
  if (!enabled || selectors.empty())
    return 1.0f;

  float finalWeight = selectors[0].evaluateWeight(charIndex, totalChars,
                                                  localFrame, sourceText);

  for (size_t i = 1; i < selectors.size(); ++i) {
    const auto &sel = selectors[i];
    float w = sel.evaluateWeight(charIndex, totalChars, localFrame, sourceText);

    switch (sel.combine) {
    case CombineMode::Add:
      finalWeight = std::min(1.0f, finalWeight + w);
      break;
    case CombineMode::Subtract:
      finalWeight = std::max(0.0f, finalWeight - w);
      break;
    case CombineMode::Intersect:
      finalWeight = finalWeight * w;
      break;
    case CombineMode::Min:
      finalWeight = std::min(finalWeight, w);
      break;
    case CombineMode::Max:
      finalWeight = std::max(finalWeight, w);
      break;
    }
  }

  return finalWeight;
}

EvaluatedCharacterTransform
TextAnimator::evaluateCharacter(size_t charIndex, size_t totalChars,
                                int64_t localFrame,
                                const QString &sourceText) const noexcept {
  float w =
      evaluateCombinedWeight(charIndex, totalChars, localFrame, sourceText);

  EvaluatedCharacterTransform t;
  t.translation = deltaPosition * w;
  t.scale = Vec2{1.0f, 1.0f} + deltaScale * w;
  t.rotationDegrees = deltaRotation * w;
  t.opacity = 1.0f - (deltaOpacity * w);
  t.trackingOffset = deltaTracking * w;
  t.strokeWidthOffset = deltaStrokeWidth * w;

  t.fillColorMultiplier[0] = 1.0f + deltaFillColor[0] * w;
  t.fillColorMultiplier[1] = 1.0f + deltaFillColor[1] * w;
  t.fillColorMultiplier[2] = 1.0f + deltaFillColor[2] * w;
  t.fillColorMultiplier[3] = 1.0f + deltaFillColor[3] * w;

  t.strokeColorMultiplier[0] = 1.0f + deltaStrokeColor[0] * w;
  t.strokeColorMultiplier[1] = 1.0f + deltaStrokeColor[1] * w;
  t.strokeColorMultiplier[2] = 1.0f + deltaStrokeColor[2] * w;
  t.strokeColorMultiplier[3] = 1.0f + deltaStrokeColor[3] * w;

  for (const auto &delta : customDeltas) {
    t.customFloatDeltas[delta.propertyId.toStdString()] = delta.floatValue * w;
  }

  return t;
}

QJsonObject TextAnimator::serialize() const {
  QJsonObject obj;
  obj["name"] = name;
  obj["enabled"] = enabled;

  QJsonArray selArr;
  for (const auto &s : selectors) {
    selArr.append(s.serialize());
  }
  obj["selectors"] = selArr;

  obj["posX"] = static_cast<double>(deltaPosition.x);
  obj["posY"] = static_cast<double>(deltaPosition.y);
  obj["scaleX"] = static_cast<double>(deltaScale.x);
  obj["scaleY"] = static_cast<double>(deltaScale.y);
  obj["rotation"] = static_cast<double>(deltaRotation);
  obj["opacity"] = static_cast<double>(deltaOpacity);
  obj["tracking"] = static_cast<double>(deltaTracking);
  obj["strokeWidth"] = static_cast<double>(deltaStrokeWidth);

  QJsonArray customArr;
  for (const auto &d : customDeltas) {
    customArr.append(d.serialize());
  }
  obj["customDeltas"] = customArr;

  return obj;
}

void TextAnimator::deserialize(const QJsonObject &obj) {
  name = obj.value("name").toString(QStringLiteral("Animator"));
  enabled = obj.value("enabled").toBool(true);

  selectors.clear();
  if (obj.contains("selectors") && obj["selectors"].isArray()) {
    for (const auto &v : obj["selectors"].toArray()) {
      TextRangeSelector s;
      s.deserialize(v.toObject());
      selectors.push_back(s);
    }
  }
  if (selectors.empty()) {
    selectors.emplace_back(TextRangeSelector{});
  }

  deltaPosition.x = static_cast<float>(obj.value("posX").toDouble(0.0));
  deltaPosition.y = static_cast<float>(obj.value("posY").toDouble(0.0));
  deltaScale.x = static_cast<float>(obj.value("scaleX").toDouble(0.0));
  deltaScale.y = static_cast<float>(obj.value("scaleY").toDouble(0.0));
  deltaRotation = static_cast<float>(obj.value("rotation").toDouble(0.0));
  deltaOpacity = static_cast<float>(obj.value("opacity").toDouble(0.0));
  deltaTracking = static_cast<float>(obj.value("tracking").toDouble(0.0));
  deltaStrokeWidth = static_cast<float>(obj.value("strokeWidth").toDouble(0.0));

  customDeltas.clear();
  if (obj.contains("customDeltas") && obj["customDeltas"].isArray()) {
    for (const auto &v : obj["customDeltas"].toArray()) {
      customDeltas.push_back(PropertyDelta::deserialize(v.toObject()));
    }
  }
}

} // namespace xyla::vector
