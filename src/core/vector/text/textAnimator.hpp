#pragma once

#include "core/animation/animProperty.hpp"
#include "core/animation/propertyHandle.hpp"
#include "core/vector/vectorContour.hpp"

#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QString>
#include <array>
#include <memory>

namespace xyla::anim {
class AnimationManager;
class AnimationPropertyTable;
} // namespace xyla::anim

namespace xyla::vector {

// Canonical property IDs for both Base values and Animator Deltas
enum class TextPropertyId : uint8_t {
  // Typography
  FontSize = 0,
  Tracking,
  LineSpacing,

  // Fill & Stroke Style
  FillRed,
  FillGreen,
  FillBlue,
  FillAlpha,
  StrokeWidth,
  StrokeRed,
  StrokeGreen,
  StrokeBlue,
  StrokeAlpha,

  // Trim
  TrimStart,
  TrimEnd,
  TrimOffset,

  // Kinetic Glyph Transforms
  TranslationX,
  TranslationY,
  ScaleX,
  ScaleY,
  Rotation,
  Opacity,
  Blur,

  Count
};

constexpr size_t kTextPropertyCount =
    static_cast<size_t>(TextPropertyId::Count);

struct ChannelHandles {
  std::array<anim::PropertyHandle, kTextPropertyCount> base{};
  std::array<anim::PropertyHandle, kTextPropertyCount> animatorDelta{};
};

// Pre-evaluated flat cache populated ONCE per frame before character layout
struct EvaluatedTextFrameState {
  std::array<float, kTextPropertyCount> baseValues{};
  std::array<float, kTextPropertyCount> animatorDeltas{};
  bool animatorActive{false};
};

enum class TextAnimatorKind : uint8_t { RangeSelector = 0, Glitch, Custom };

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

struct EvaluatedCharacterTransform {
  Vec2 translation{0.0f, 0.0f};
  Vec2 scale{0.0f, 0.0f};
  float rotationDegrees{0.0f};
  float opacityDelta{0.0f};
  float trackingOffset{0.0f};
  float strokeWidthOffset{0.0f};
  float blurOffset{0.0f};
  std::array<float, 4> fillColorDelta{0.0f, 0.0f, 0.0f, 0.0f};
  std::array<float, 4> strokeColorDelta{0.0f, 0.0f, 0.0f, 0.0f};
};

class ITextAnimator {
public:
  virtual ~ITextAnimator() = default;

  [[nodiscard]] virtual std::unique_ptr<ITextAnimator> clone() const = 0;
  [[nodiscard]] virtual TextAnimatorKind kind() const noexcept = 0;
  [[nodiscard]] virtual QString name() const = 0;

  [[nodiscard]] virtual bool isEnabled() const noexcept = 0;
  virtual void setEnabled(bool enabled) noexcept = 0;

  virtual void bindAnimationManager(const QString &clipId,
                                    anim::AnimationManager &animMgr,
                                    ChannelHandles &handles) = 0;

  // HOT PATH: Character transformation with zero string lookups
  virtual EvaluatedCharacterTransform evaluateCharacter(
      size_t charIndex, size_t totalChars, int64_t localFrame,
      const QString &sourceText, const EvaluatedTextFrameState &frameState,
      const anim::AnimationPropertyTable &table) const noexcept = 0;

  virtual QJsonObject serialize() const = 0;
  virtual void deserialize(const QJsonObject &obj) = 0;
};

class RangeTextAnimator : public ITextAnimator {
public:
  RangeTextAnimator();
  ~RangeTextAnimator() override = default;

  [[nodiscard]] std::unique_ptr<ITextAnimator> clone() const override {
    return std::make_unique<RangeTextAnimator>(*this);
  }

  [[nodiscard]] TextAnimatorKind kind() const noexcept override {
    return TextAnimatorKind::RangeSelector;
  }

  [[nodiscard]] QString name() const override { return m_name; }
  void setName(QString name) { m_name = std::move(name); }

  [[nodiscard]] bool isEnabled() const noexcept override { return m_enabled; }
  void setEnabled(bool enabled) noexcept override { m_enabled = enabled; }

  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr,
                            ChannelHandles &handles) override;

  EvaluatedCharacterTransform evaluateCharacter(
      size_t charIndex, size_t totalChars, int64_t localFrame,
      const QString &sourceText, const EvaluatedTextFrameState &frameState,
      const anim::AnimationPropertyTable &table) const noexcept override;

  QJsonObject serialize() const override;
  void deserialize(const QJsonObject &obj) override;

  // Selector Properties (Table Handles)
  anim::PropertyHandle startHandle;
  anim::PropertyHandle endHandle;
  anim::PropertyHandle offsetHandle;

  // Selector Settings
  SelectorShape shape{SelectorShape::Square};
  CombineMode combine{CombineMode::Add};
  BasedOn basedOn{BasedOn::Characters};
  int chunkSize{2};
  QString customSeparator{QStringLiteral("|")};
  QString regexPattern{QStringLiteral("\\w+")};
  bool randomize{false};
  uint32_t randomSeed{12345};

private:
  float
  evaluateWeight(size_t charIndex, size_t totalChars, int64_t localFrame,
                 const QString &sourceText,
                 const anim::AnimationPropertyTable &table) const noexcept;

  void computeUnitIndices(const QString &text, size_t totalChars,
                          size_t charIndex, size_t &outUnitIndex,
                          size_t &outTotalUnits) const noexcept;

  QString m_name{QStringLiteral("Range Animator")};
  bool m_enabled{true};
};

} // namespace xyla::vector
