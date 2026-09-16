#pragma once

#include "animCurve.hpp"
#include "keyframe.hpp"

#include <QJsonObject>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace xyla::anim {

enum class AnimMode : uint8_t { Static = 0, Keyframed, Driven };

class AnimProperty;

struct EvaluationContext {
  FrameIndex timelineFrame{0};
  FrameIndex localFrame{0};
  std::function<float(const std::string &propertyAddress)> resolveVariable;
};

using DriverExpressionSolver = std::function<float(
    const std::string &expression, const EvaluationContext &ctx)>;

class AnimProperty {
public:
  AnimProperty() = default;
  explicit AnimProperty(float staticValue);
  AnimProperty(const AnimProperty &other);
  AnimProperty &operator=(const AnimProperty &other);
  AnimProperty(AnimProperty &&other) noexcept = default;
  AnimProperty &operator=(AnimProperty &&other) noexcept = default;
  ~AnimProperty() = default;

  [[nodiscard]] QJsonObject serialize() const;
  static AnimProperty deserialize(const QJsonObject &obj,
                                  float defaultVal = 0.0f);
  void deserializeInto(const QJsonObject &obj, float defaultVal = 0.0f);

  [[nodiscard]] float evaluate(FrameIndex frame) const noexcept;
  [[nodiscard]] float
  evaluateWithContext(const EvaluationContext &ctx) const noexcept;

  [[nodiscard]] AnimMode getMode() const noexcept;
  void setMode(AnimMode mode) noexcept;

  [[nodiscard]] float getStaticValue() const noexcept;
  void setStaticValue(float value) noexcept;

  [[nodiscard]] bool getIsAnimated() const noexcept;
  [[nodiscard]] bool getIsDriven() const noexcept;
  [[nodiscard]] bool getIsMuted() const noexcept;
  void setIsMuted(bool muted) noexcept;
  [[nodiscard]] bool getIsLocked() const noexcept;
  void setIsLocked(bool locked) noexcept;

  [[nodiscard]] const std::string &getDriverExpression() const noexcept;
  void setDriverExpression(std::string expression);
  static void setGlobalDriverSolver(DriverExpressionSolver solver);

  [[nodiscard]] bool hasKeyframe(FrameIndex frame) const noexcept;
  [[nodiscard]] const Keyframe<float> *
  findKeyframe(FrameIndex frame) const noexcept;
  [[nodiscard]] const std::vector<Keyframe<float>> &
  getKeyframes() const noexcept;
  [[nodiscard]] std::vector<FrameIndex> getKeyframeFrames() const;
  [[nodiscard]] const AnimCurve *getCurve() const noexcept;

  void setKeyframe(FrameIndex frame, float value,
                   Interpolation interp = Interpolation::Linear,
                   BezierHandles bezier = {});
  bool removeKeyframe(FrameIndex frame);
  bool moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame);
  void clearKeyframes() noexcept;

private:
  float m_staticValue{0.0f};
  AnimMode m_mode{AnimMode::Static};
  bool m_isMuted{false};
  bool m_isLocked{false};

  std::unique_ptr<AnimCurve> m_curve{nullptr};
  std::string m_driverExpression;

  static DriverExpressionSolver s_driverSolver;
};

} // namespace xyla::anim
