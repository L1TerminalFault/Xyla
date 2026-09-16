#pragma once

#include "keyframe.hpp"
#include <QJsonObject>
#include <vector>

namespace xyla::anim {

class AnimCurve {
public:
  AnimCurve() = default;

  // Serialization
  [[nodiscard]] QJsonObject serialize() const;
  static AnimCurve deserialize(const QJsonObject &obj);

  // Evaluation & Queries
  [[nodiscard]] float evaluate(FrameIndex frame) const noexcept;
  [[nodiscard]] bool isEmpty() const noexcept;
  [[nodiscard]] size_t getKeyframeCount() const noexcept;
  [[nodiscard]] bool hasKeyframe(FrameIndex frame) const noexcept;
  [[nodiscard]] const Keyframe<float> *
  findKeyframe(FrameIndex frame) const noexcept;

  [[nodiscard]] const std::vector<Keyframe<float>> &
  getKeyframes() const noexcept;
  [[nodiscard]] std::vector<FrameIndex> getKeyframeFrames() const;

  // Keyframe Mutations
  void setKeyframe(FrameIndex frame, float value,
                   Interpolation interp = Interpolation::Linear,
                   BezierHandles bezier = {});

  bool removeKeyframe(FrameIndex frame);
  bool moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame);
  void clearKeyframes() noexcept;

private:
  std::vector<Keyframe<float>> m_keys;
};

} // namespace xyla::anim
