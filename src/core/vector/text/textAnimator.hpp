#pragma once

#include "core/animation/animCurve.hpp"
#include "core/animation/animProperty.hpp"
#include "core/vector/vectorContour.hpp"
#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QString>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace xyla::vector {

enum class SelectorShape {
  Square = 0,
  RampUp = 1,
  RampDown = 2,
  Triangle = 3,
  Round = 4,
  Smooth = 5,
  Gaussian = 6
};

enum class CombineMode {
  Add = 0,
  Subtract = 1,
  Intersect = 2,
  Min = 3,
  Max = 4
};

enum class BasedOn {
  Characters = 0,
  CharactersExcludingSpaces = 1,
  Words = 2,
  Lines = 3,
  CharacterChunks = 4, // e.g. 2 letters at a time
  CustomSeparator = 5, // delimiter e.g. "|" or ","
  Regex = 6            // matched tokens via QRegularExpression
};

struct PropertyDelta {
  QString propertyId;
  float floatValue{0.0f};
  Vec2 vec2Value{0.0f, 0.0f};
  QColor colorValue{Qt::white};

  [[nodiscard]] QJsonObject serialize() const;
  static PropertyDelta deserialize(const QJsonObject &obj);
};

struct EvaluatedCharacterTransform {
  Vec2 translation{0.0f, 0.0f};
  Vec2 scale{1.0f, 1.0f};
  float rotationDegrees{0.0f};
  float opacity{1.0f};
  float trackingOffset{0.0f};
  float strokeWidthOffset{0.0f};
  float fillColorMultiplier[4]{1.0f, 1.0f, 1.0f, 1.0f};
  float strokeColorMultiplier[4]{1.0f, 1.0f, 1.0f, 1.0f};

  std::unordered_map<std::string, float> customFloatDeltas;
};

class TextRangeSelector {
public:
  anim::AnimProperty start{0.0f};  // Keyframeable 0.0 to 1.0
  anim::AnimProperty end{1.0f};    // Keyframeable 0.0 to 1.0
  anim::AnimProperty offset{0.0f}; // Keyframeable -100% to +100%

  SelectorShape shape{SelectorShape::Square};
  CombineMode combine{CombineMode::Add};

  BasedOn basedOn{BasedOn::Characters};
  int chunkSize{2};
  QString customSeparator{QStringLiteral("|")};
  QString regexPattern{QStringLiteral("\\w+")};

  bool randomize{false};
  uint32_t randomSeed{12345};

  std::shared_ptr<anim::AnimCurve> responseCurve{nullptr};

  [[nodiscard]] float
  evaluateWeight(size_t charIndex, size_t totalChars, int64_t localFrame = 0,
                 const QString &sourceText = QString()) const noexcept;

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);

private:
  void computeUnitIndices(const QString &text, size_t totalChars,
                          size_t charIndex, size_t &outUnitIndex,
                          size_t &outTotalUnits) const noexcept;
};

class TextAnimator {
public:
  QString name{QStringLiteral("Animator")};
  bool enabled{true};

  std::vector<TextRangeSelector> selectors;

  Vec2 deltaPosition{0.0f, 0.0f};
  Vec2 deltaScale{0.0f, 0.0f};
  float deltaRotation{0.0f};
  float deltaOpacity{0.0f};
  float deltaTracking{0.0f};
  float deltaStrokeWidth{0.0f};
  float deltaFillColor[4]{0.0f, 0.0f, 0.0f, 0.0f};
  float deltaStrokeColor[4]{0.0f, 0.0f, 0.0f, 0.0f};

  std::vector<PropertyDelta> customDeltas;

  TextAnimator();

  [[nodiscard]] float
  evaluateCombinedWeight(size_t charIndex, size_t totalChars,
                         int64_t localFrame = 0,
                         const QString &sourceText = QString()) const noexcept;

  [[nodiscard]] EvaluatedCharacterTransform
  evaluateCharacter(size_t charIndex, size_t totalChars, int64_t localFrame = 0,
                    const QString &sourceText = QString()) const noexcept;

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
};

} // namespace xyla::vector
