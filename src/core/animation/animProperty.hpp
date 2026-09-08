#pragma once

#include "animMath.hpp"
#include "keyframe.hpp"

#include <algorithm>
#include <vector>

namespace xyla::anim {

class AnimProperty {
public:
  AnimProperty() = default;
  explicit AnimProperty(float staticValue) : m_staticValue(staticValue) {}

  [[nodiscard]] float evaluate(FrameIndex frame) const noexcept {
    if (!m_isAnimated || m_keys.empty())
      return m_staticValue;

    if (frame <= m_keys.front().frame)
      return m_keys.front().value;
    if (frame >= m_keys.back().frame)
      return m_keys.back().value;

    auto it = std::lower_bound(m_keys.begin(), m_keys.end(), frame);
    if (it != m_keys.end() && it->frame == frame)
      return it->value;

    const size_t right = static_cast<size_t>(std::distance(m_keys.begin(), it));
    const size_t left = right - 1;
    const Keyframe<float> &k0 = m_keys[left];
    const Keyframe<float> &k1 = m_keys[right];

    if (k0.interpolation == Interpolation::Hold)
      return k0.value;

    const float tNorm = static_cast<float>(frame - k0.frame) /
                        static_cast<float>(k1.frame - k0.frame);

    if (k0.interpolation == Interpolation::Linear)
      return lerp(k0.value, k1.value, tNorm);

    // Bezier
    const float t = solveBezierT(tNorm, k0.bezier.outX, k1.bezier.inX);
    const float y = evalBezierY(t, k0.bezier.outY, k1.bezier.inY);
    return lerp(k0.value, k1.value, y);
  }

  void setStaticValue(float v) noexcept { m_staticValue = v; }
  [[nodiscard]] float staticValue() const noexcept { return m_staticValue; }

  [[nodiscard]] bool isAnimated() const noexcept { return m_isAnimated; }

  [[nodiscard]] bool hasKeyframe(FrameIndex frame) const noexcept {
    auto it = std::lower_bound(m_keys.begin(), m_keys.end(), frame);
    return it != m_keys.end() && it->frame == frame;
  }

  void setKeyframe(FrameIndex frame, float value,
                   Interpolation interp = Interpolation::Linear) {
    m_isAnimated = true;
    auto it = std::lower_bound(m_keys.begin(), m_keys.end(), frame);
    if (it != m_keys.end() && it->frame == frame) {
      it->value = value;
      it->interpolation = interp;
    } else {
      m_keys.insert(it, Keyframe<float>{frame, value, interp, {}});
    }
  }

  bool removeKeyframe(FrameIndex frame) noexcept {
    auto it = std::lower_bound(m_keys.begin(), m_keys.end(), frame);
    if (it == m_keys.end() || it->frame != frame)
      return false;
    m_keys.erase(it);
    if (m_keys.empty())
      m_isAnimated = false;
    return true;
  }

  bool moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame) {
    if (oldFrame == newFrame)
      return true;
    auto it = std::lower_bound(m_keys.begin(), m_keys.end(), oldFrame);
    if (it == m_keys.end() || it->frame != oldFrame)
      return false;

    Keyframe<float> key = *it;
    m_keys.erase(it);
    key.frame = newFrame;
    setKeyframe(key.frame, key.value, key.interpolation);
    // Preserve handles
    auto placed = std::lower_bound(m_keys.begin(), m_keys.end(), newFrame);
    if (placed != m_keys.end() && placed->frame == newFrame)
      placed->bezier = key.bezier;
    return true;
  }

  void clearKeyframes() noexcept {
    m_keys.clear();
    m_isAnimated = false;
  }

  [[nodiscard]] const std::vector<Keyframe<float>> &keyframes() const noexcept {
    return m_keys;
  }

  [[nodiscard]] std::vector<FrameIndex> keyframeFrames() const {
    std::vector<FrameIndex> frames;
    frames.reserve(m_keys.size());
    for (const auto &k : m_keys)
      frames.push_back(k.frame);
    return frames;
  }

private:
  float m_staticValue{0.0f};
  bool m_isAnimated{false};
  std::vector<Keyframe<float>> m_keys;
};

} // namespace xyla::anim
