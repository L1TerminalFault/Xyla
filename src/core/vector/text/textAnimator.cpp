#include "textAnimator.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/animation/AnimationPropertyTable.hpp"

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

RangeTextAnimator::RangeTextAnimator() = default;

void RangeTextAnimator::bindAnimationManager(const QString &clipId,
                                             anim::AnimationManager &animMgr,
                                             ChannelHandles &handles) {
  const QString prefix = clipId + QStringLiteral(".text.animator.");

  // Register Selector Keyframing Channels
  startHandle = animMgr.registerFloatProperty(
      clipId, prefix + QStringLiteral("start"), 0.0f, QStringLiteral("Start"),
      QStringLiteral("Selector"));
  endHandle = animMgr.registerFloatProperty(
      clipId, prefix + QStringLiteral("end"), 1.0f, QStringLiteral("End"),
      QStringLiteral("Selector"));
  offsetHandle = animMgr.registerFloatProperty(
      clipId, prefix + QStringLiteral("offset"), 0.0f, QStringLiteral("Offset"),
      QStringLiteral("Selector"));

  // Register Animator Delta Channels into table (Default 0.0 delta = no change)
  auto regDelta = [&](TextPropertyId id, const QString &name,
                      const QString &group) {
    handles.animatorDelta[static_cast<size_t>(id)] =
        animMgr.registerFloatProperty(clipId, prefix + name, 0.0f,
                                      name + QStringLiteral(" Delta"), group);
  };

  regDelta(TextPropertyId::TranslationX, QStringLiteral("deltaTranslationX"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::TranslationY, QStringLiteral("deltaTranslationY"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::ScaleX, QStringLiteral("deltaScaleX"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::ScaleY, QStringLiteral("deltaScaleY"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::Rotation, QStringLiteral("deltaRotation"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::Opacity, QStringLiteral("deltaOpacity"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::Tracking, QStringLiteral("deltaTracking"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::StrokeWidth, QStringLiteral("deltaStrokeWidth"),
           QStringLiteral("Transform"));
  regDelta(TextPropertyId::Blur, QStringLiteral("deltaBlur"),
           QStringLiteral("Transform"));
}

void RangeTextAnimator::computeUnitIndices(
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
    outTotalUnits = std::max<size_t>(1, static_cast<size_t>(parts.size()));
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

float RangeTextAnimator::evaluateWeight(
    size_t charIndex, size_t totalChars, int64_t localFrame,
    const QString &sourceText,
    const anim::AnimationPropertyTable &table) const noexcept {
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

  const float u = (static_cast<float>(effectiveIndex) + 0.5f) /
                  static_cast<float>(totalUnits);

  // Fast O(1) table queries via handles
  float s = table.evaluateFloat(startHandle, localFrame);
  float e = table.evaluateFloat(endHandle, localFrame);
  float off = table.evaluateFloat(offsetHandle, localFrame) * 0.01f;

  float uEval = u - off;
  if (s > e) {
    std::swap(s, e);
  }

  float range = e - s;
  if (range <= 1e-5f) {
    return (uEval < s) ? 0.0f : 1.0f;
  }

  if (shape == SelectorShape::RampDown) {
    if (uEval <= s)
      return 1.0f;
    if (uEval >= e)
      return 0.0f;
    return 1.0f - ((uEval - s) / range);
  }

  if (shape == SelectorShape::RampUp) {
    if (uEval <= s)
      return 0.0f;
    if (uEval >= e)
      return 1.0f;
    return (uEval - s) / range;
  }

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

  return std::clamp(weight, 0.0f, 1.0f);
}

EvaluatedCharacterTransform RangeTextAnimator::evaluateCharacter(
    size_t charIndex, size_t totalChars, int64_t localFrame,
    const QString &sourceText, const EvaluatedTextFrameState &frameState,
    const anim::AnimationPropertyTable &table) const noexcept {
  EvaluatedCharacterTransform t;
  if (!m_enabled || !frameState.animatorActive)
    return t;

  const float w =
      evaluateWeight(charIndex, totalChars, localFrame, sourceText, table);
  if (w <= 0.00001f)
    return t;

  // Zero string lookups — pure flat-array SIMD scaling
  const auto &d = frameState.animatorDeltas;
  t.translation.x = d[static_cast<size_t>(TextPropertyId::TranslationX)] * w;
  t.translation.y = d[static_cast<size_t>(TextPropertyId::TranslationY)] * w;
  t.scale.x = d[static_cast<size_t>(TextPropertyId::ScaleX)] * w;
  t.scale.y = d[static_cast<size_t>(TextPropertyId::ScaleY)] * w;
  t.rotationDegrees = d[static_cast<size_t>(TextPropertyId::Rotation)] * w;
  t.opacityDelta = d[static_cast<size_t>(TextPropertyId::Opacity)] * w;
  t.trackingOffset = d[static_cast<size_t>(TextPropertyId::Tracking)] * w;
  t.strokeWidthOffset = d[static_cast<size_t>(TextPropertyId::StrokeWidth)] * w;
  t.blurOffset = d[static_cast<size_t>(TextPropertyId::Blur)] * w;

  return t;
}

QJsonObject RangeTextAnimator::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("name")] = m_name;
  obj[QStringLiteral("enabled")] = m_enabled;
  obj[QStringLiteral("shape")] = static_cast<int>(shape);
  obj[QStringLiteral("combine")] = static_cast<int>(combine);
  obj[QStringLiteral("basedOn")] = static_cast<int>(basedOn);
  obj[QStringLiteral("chunkSize")] = chunkSize;
  obj[QStringLiteral("customSeparator")] = customSeparator;
  obj[QStringLiteral("regexPattern")] = regexPattern;
  obj[QStringLiteral("randomize")] = randomize;
  obj[QStringLiteral("randomSeed")] = static_cast<int>(randomSeed);
  return obj;
}

void RangeTextAnimator::deserialize(const QJsonObject &obj) {
  m_name = obj.value(QStringLiteral("name"))
               .toString(QStringLiteral("Range Animator"));
  m_enabled = obj.value(QStringLiteral("enabled")).toBool(true);
  shape =
      static_cast<SelectorShape>(obj.value(QStringLiteral("shape")).toInt(0));
  combine =
      static_cast<CombineMode>(obj.value(QStringLiteral("combine")).toInt(0));
  basedOn = static_cast<BasedOn>(obj.value(QStringLiteral("basedOn")).toInt(0));
  chunkSize = obj.value(QStringLiteral("chunkSize")).toInt(2);
  customSeparator = obj.value(QStringLiteral("customSeparator"))
                        .toString(QStringLiteral("|"));
  regexPattern = obj.value(QStringLiteral("regexPattern"))
                     .toString(QStringLiteral("\\w+"));
  randomize = obj.value(QStringLiteral("randomize")).toBool(false);
  randomSeed = static_cast<uint32_t>(
      obj.value(QStringLiteral("randomSeed")).toInt(12345));
}

} // namespace xyla::vector
