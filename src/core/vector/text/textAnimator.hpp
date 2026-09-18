#pragma once

#include "core/animation/animProperty.hpp"
#include "core/vector/vectorContour.hpp"
#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QString>
#include <array>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace xyla::vector {

enum class SelectorShape : int {
  Square = 0,
  RampUp = 1,
  RampDown = 2,
  Triangle = 3,
  Round = 4,
  Smooth = 5,
  Gaussian = 6
};

enum class CombineMode : int {
  Add = 0,
  Subtract = 1,
  Intersect = 2,
  Min = 3,
  Max = 4
};

enum class BasedOn : int {
  Characters = 0,
  CharactersExcludingSpaces = 1,
  Words = 2,
  Lines = 3,
  CharacterChunks = 4,
  CustomSeparator = 5,
  Regex = 6
};

// Available animated property descriptor for UI registration and search
struct AnimatorPropertyDescriptor {
  QString propertyId;
  QString displayName;
  QString category;
  QString unit;
  float defaultValue{0.0f};
  float minValue{-1000.0f};
  float maxValue{1000.0f};
  float stepSize{1.0f};
  int decimals{1};

  QJsonObject serialize() const;
};

// Dynamic delta applied to a target property
struct AnimatorDelta {
  QString propertyId;
  float value{0.0f};

  QJsonObject serialize() const;
  static AnimatorDelta deserialize(const QJsonObject &obj);
};

// Evaluated transform accumulated across all active animators for a single
// character
struct EvaluatedCharacterTransform {
  Vec2 translation{0.0f, 0.0f};
  Vec2 scale{
      0.0f,
      0.0f}; // Additive delta: 0.0 means no scale change (+0% to base 1.0)
  float rotationDegrees{0.0f};
  float opacityDelta{
      0.0f}; // Additive delta: e.g. -1.0 means subtract 100% opacity
  float trackingOffset{0.0f};
  float strokeWidthOffset{0.0f};
  float blurOffset{0.0f};
  std::array<float, 4> fillColorDelta{0.0f, 0.0f, 0.0f, 0.0f};
  std::array<float, 4> strokeColorDelta{0.0f, 0.0f, 0.0f, 0.0f};
  std::unordered_map<std::string, float> customFloatDeltas;
};

class TextRangeSelector {
public:
  anim::AnimProperty start{0.0f};
  anim::AnimProperty end{1.0f};
  anim::AnimProperty offset{0.0f};

  SelectorShape shape{SelectorShape::Square};
  CombineMode combine{CombineMode::Add};
  BasedOn basedOn{BasedOn::Characters};

  int chunkSize{2};
  QString customSeparator{QStringLiteral("|")};
  QString regexPattern{QStringLiteral("\\w+")};

  bool randomize{false};
  uint32_t randomSeed{12345};

  std::shared_ptr<anim::AnimCurve> responseCurve;

  float evaluateWeight(size_t charIndex, size_t totalChars, int64_t localFrame,
                       const QString &sourceText) const noexcept;

  void computeUnitIndices(const QString &text, size_t totalChars,
                          size_t charIndex, size_t &outUnitIndex,
                          size_t &outTotalUnits) const noexcept;

  QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
};

class TextAnimator {
public:
  TextAnimator();

  QString name{QStringLiteral("Animator")};
  bool enabled{true};

  std::vector<TextRangeSelector> selectors;
  std::vector<AnimatorDelta> deltas; // Dynamic property deltas

  // Delta collection management
  float getDeltaValue(const QString &propId,
                      float fallback = 0.0f) const noexcept;
  void setDeltaValue(const QString &propId, float value);
  bool removeDelta(const QString &propId);
  bool hasDelta(const QString &propId) const noexcept;

  float evaluateCombinedWeight(size_t charIndex, size_t totalChars,
                               int64_t localFrame,
                               const QString &sourceText) const noexcept;

  EvaluatedCharacterTransform
  evaluateCharacter(size_t charIndex, size_t totalChars, int64_t localFrame,
                    const QString &sourceText) const noexcept;

  QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);

  static const std::vector<AnimatorPropertyDescriptor> &
  getAvailableProperties();
};

} // namespace xyla::vector
