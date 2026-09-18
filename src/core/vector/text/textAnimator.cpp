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

const std::vector<AnimatorPropertyDescriptor> s_availableProperties = {
    {"position.x", "Position X", "Transform", "px", 0.0f, -2000.0f, 2000.0f,
     1.0f, 0},
    {"position.y", "Position Y", "Transform", "px", 50.0f, -2000.0f, 2000.0f,
     1.0f, 0},
    {"scale.x", "Scale X", "Transform", "%", -1.0f, -1.0f, 10.0f, 0.05f, 2},
    {"scale.y", "Scale Y", "Transform", "%", -1.0f, -1.0f, 10.0f, 0.05f, 2},
    {"scale", "Scale (Uniform)", "Transform", "%", -1.0f, -1.0f, 10.0f, 0.05f,
     2},
    {"rotation", "Rotation", "Transform", "°", 0.0f, -360.0f, 360.0f, 1.0f, 0},
    {"opacity", "Opacity", "Style", "%", -1.0f, -1.0f, 1.0f, 0.05f, 2},
    {"tracking", "Tracking", "Style", "px", 0.0f, -100.0f, 200.0f, 1.0f, 0},
    {"strokeWidth", "Stroke Width", "Style", "px", 0.0f, -50.0f, 100.0f, 1.0f,
     1},
    {"blur", "Blur", "Style", "px", 10.0f, 0.0f, 100.0f, 1.0f, 0}};

} // namespace

QJsonObject AnimatorPropertyDescriptor::serialize() const {
  QJsonObject obj;
  obj["propertyId"] = propertyId;
  obj["displayName"] = displayName;
  obj["category"] = category;
  obj["unit"] = unit;
  obj["defaultValue"] = static_cast<double>(defaultValue);
  obj["minValue"] = static_cast<double>(minValue);
  obj["maxValue"] = static_cast<double>(maxValue);
  obj["stepSize"] = static_cast<double>(stepSize);
  obj["decimals"] = decimals;
  return obj;
}

QJsonObject AnimatorDelta::serialize() const {
  QJsonObject obj;
  obj["propertyId"] = propertyId;
  obj["value"] = static_cast<double>(value);
  return obj;
}

AnimatorDelta AnimatorDelta::deserialize(const QJsonObject &obj) {
  AnimatorDelta d;
  d.propertyId = obj.value("propertyId").toString();
  d.value = static_cast<float>(obj.value("value").toDouble(0.0));
  return d;
}

const std::vector<AnimatorPropertyDescriptor> &
TextAnimator::getAvailableProperties() {
  return s_availableProperties;
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

  // Character unit position along normalized 0.0 -> 1.0 range
  float u = (static_cast<float>(effectiveIndex) + 0.5f) /
            static_cast<float>(totalUnits);

  // Read start, end, and offset without arbitrary clamping
  float s = start.evaluate(localFrame);
  float e = end.evaluate(localFrame);
  float off = offset.evaluate(localFrame) * 0.01f;

  // Window shifts by offset; characters retain their true spatial order
  float uEval = u - off;

  if (s > e) {
    std::swap(s, e);
  }

  float range = e - s;
  if (range <= 1e-5f) {
    // If window width is zero, act as an instant step boundary
    return (uEval < s) ? 0.0f : 1.0f;
  }

  // --- RAMP DOWN (Full weight before window, ramps down to 0, stays 0 after)
  // ---
  if (shape == SelectorShape::RampDown) {
    if (uEval <= s)
      return 1.0f;
    if (uEval >= e)
      return 0.0f;
    return 1.0f - ((uEval - s) / range);
  }

  // --- RAMP UP (0 before window, ramps up to 1, stays 1 after) ---
  if (shape == SelectorShape::RampUp) {
    if (uEval <= s)
      return 0.0f;
    if (uEval >= e)
      return 1.0f;
    return (uEval - s) / range;
  }

  // --- BOUNDED WINDOW SHAPES (Square, Triangle, Round, Smooth, Gaussian) ---
  if (uEval < s || uEval > e) {
    return 0.0f;
  }

  float norm = (uEval - s) / range;
  float weight = 0.0f;

  switch (shape) {
  case SelectorShape::Square:
    weight = 1.0f;
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
  default:
    weight = 1.0f;
    break;
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
  else if (obj.contains("start"))
    start.setStaticValue(static_cast<float>(obj["start"].toDouble(0.0)));

  if (obj.contains("endData"))
    end.deserializeInto(obj["endData"].toObject(), 1.0f);
  else if (obj.contains("end"))
    end.setStaticValue(static_cast<float>(obj["end"].toDouble(1.0)));

  if (obj.contains("offsetData"))
    offset.deserializeInto(obj["offsetData"].toObject(), 0.0f);
  else if (obj.contains("offset"))
    offset.setStaticValue(static_cast<float>(obj["offset"].toDouble(0.0)));

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

float TextAnimator::getDeltaValue(const QString &propId,
                                  float fallback) const noexcept {
  for (const auto &d : deltas) {
    if (d.propertyId == propId)
      return d.value;
  }
  return fallback;
}

void TextAnimator::setDeltaValue(const QString &propId, float value) {
  for (auto &d : deltas) {
    if (d.propertyId == propId) {
      d.value = value;
      return;
    }
  }
  deltas.push_back({propId, value});
}

bool TextAnimator::removeDelta(const QString &propId) {
  for (auto it = deltas.begin(); it != deltas.end(); ++it) {
    if (it->propertyId == propId) {
      deltas.erase(it);
      return true;
    }
  }
  return false;
}

bool TextAnimator::hasDelta(const QString &propId) const noexcept {
  for (const auto &d : deltas) {
    if (d.propertyId == propId)
      return true;
  }
  return false;
}

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
  if (w <= 0.00001f || deltas.empty()) {
    return t; // 0 weight means 0 delta influence
  }

  // Pure additive math: Delta is scaled by weight
  for (const auto &d : deltas) {
    if (d.propertyId == "position.x" || d.propertyId == "posX") {
      t.translation.x += d.value * w;
    } else if (d.propertyId == "position.y" || d.propertyId == "posY") {
      t.translation.y += d.value * w;
    } else if (d.propertyId == "scale.x" || d.propertyId == "scaleX") {
      t.scale.x += d.value * w;
    } else if (d.propertyId == "scale.y" || d.propertyId == "scaleY") {
      t.scale.y += d.value * w;
    } else if (d.propertyId == "scale") {
      t.scale.x += d.value * w;
      t.scale.y += d.value * w;
    } else if (d.propertyId == "rotation") {
      t.rotationDegrees += d.value * w;
    } else if (d.propertyId == "opacity") {
      t.opacityDelta += d.value * w;
    } else if (d.propertyId == "tracking") {
      t.trackingOffset += d.value * w;
    } else if (d.propertyId == "strokeWidth") {
      t.strokeWidthOffset += d.value * w;
    } else if (d.propertyId == "blur") {
      t.blurOffset += d.value * w;
    } else {
      t.customFloatDeltas[d.propertyId.toStdString()] += d.value * w;
    }
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

  QJsonArray deltaArr;
  for (const auto &d : deltas) {
    deltaArr.append(d.serialize());
  }
  obj["deltas"] = deltaArr;

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

  deltas.clear();
  if (obj.contains("deltas") && obj["deltas"].isArray()) {
    for (const auto &v : obj["deltas"].toArray()) {
      deltas.push_back(AnimatorDelta::deserialize(v.toObject()));
    }
  } else {
    // Backward compatibility with legacy fixed delta fields
    if (obj.contains("posY"))
      setDeltaValue("position.y", static_cast<float>(obj["posY"].toDouble()));
    if (obj.contains("posX"))
      setDeltaValue("position.x", static_cast<float>(obj["posX"].toDouble()));
    if (obj.contains("scaleX"))
      setDeltaValue("scale.x", static_cast<float>(obj["scaleX"].toDouble()));
    if (obj.contains("scaleY"))
      setDeltaValue("scale.y", static_cast<float>(obj["scaleY"].toDouble()));
    if (obj.contains("rotation"))
      setDeltaValue("rotation", static_cast<float>(obj["rotation"].toDouble()));
    if (obj.contains("opacity"))
      setDeltaValue("opacity", static_cast<float>(obj["opacity"].toDouble()));
    if (obj.contains("tracking"))
      setDeltaValue("tracking", static_cast<float>(obj["tracking"].toDouble()));
    if (obj.contains("strokeWidth"))
      setDeltaValue("strokeWidth",
                    static_cast<float>(obj["strokeWidth"].toDouble()));
  }
}

} // namespace xyla::vector
