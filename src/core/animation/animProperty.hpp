#pragma once

#include "animCurve.hpp"
#include "keyframe.hpp"

#include <QJsonObject>
#include <memory>
#include <vector>

namespace xyla::anim {

class AnimProperty {
public:
  // construction and lifecycle
  AnimProperty() = default;
  explicit AnimProperty(float staticValue);
  AnimProperty(const AnimProperty &other);
  AnimProperty &operator=(const AnimProperty &other);
  AnimProperty(AnimProperty &&other) noexcept = default;
  AnimProperty &operator=(AnimProperty &&other) noexcept = default;
  ~AnimProperty() = default;

  // serialization
  [[nodiscard]] QJsonObject serialize() const;
  static AnimProperty deserialize(const QJsonObject &obj,
                                  float defaultVal = 0.0f);
  void deserializeInto(const QJsonObject &obj, float defaultVal = 0.0f);

  // evaluation and queries
  [[nodiscard]] float evaluate(FrameIndex frame) const noexcept;
  [[nodiscard]] float getStaticValue() const noexcept;
  [[nodiscard]] bool getIsAnimated() const noexcept;
  [[nodiscard]] bool getIsMuted() const noexcept;
  [[nodiscard]] bool getIsLocked() const noexcept;

  [[nodiscard]] bool hasKeyframe(FrameIndex frame) const noexcept;
  [[nodiscard]] const Keyframe<float> *
  findKeyframe(FrameIndex frame) const noexcept;
  [[nodiscard]] const std::vector<Keyframe<float>> &
  getKeyframes() const noexcept;
  [[nodiscard]] std::vector<FrameIndex> getKeyframeFrames() const;
  [[nodiscard]] const AnimCurve *getCurve() const noexcept;

  // mutations
  void setStaticValue(float value) noexcept;
  void setIsMuted(bool muted) noexcept;
  void setIsLocked(bool locked) noexcept;

  void setKeyframe(FrameIndex frame, float value,
                   Interpolation interp = Interpolation::Linear,
                   BezierHandles bezier = {});
  bool removeKeyframe(FrameIndex frame);
  bool moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame);
  void clearKeyframes() noexcept;

private:
  float m_staticValue{0.0f};
  bool m_isMuted{false};
  bool m_isLocked{false};
  std::unique_ptr<AnimCurve> m_curve{nullptr};
};

} // namespace xyla::anim
