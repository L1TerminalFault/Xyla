#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

namespace xyla::anim {

using FrameIndex = int64_t;

enum class InterpolationType : uint8_t { Hold = 0, Linear = 1, Bezier = 2 };

struct BezierHandles {
  float outHandleX{0.333f};
  float outHandleY{0.0f};
  float inHandleX{0.666f};
  float inHandleY{0.0f};
};

template <typename T> struct Keyframe {
  FrameIndex frame{0};
  T value{};
  InterpolationType interpolation{InterpolationType::Linear};
  BezierHandles bezier{};

  bool operator<(const Keyframe<T> &other) const noexcept {
    return frame < other.frame;
  }
  bool operator<(FrameIndex targetFrame) const noexcept {
    return frame < targetFrame;
  }
};

inline float interpolate(float a, float b, float t) noexcept {
  return std::lerp(a, b, t);
}

inline double interpolate(double a, double b, float t) noexcept {
  return std::lerp(a, b, static_cast<double>(t));
}

inline std::array<float, 2> interpolate(const std::array<float, 2> &a,
                                        const std::array<float, 2> &b,
                                        float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t)};
}

inline std::array<float, 4> interpolate(const std::array<float, 4> &a,
                                        const std::array<float, 4> &b,
                                        float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t),
          std::lerp(a[2], b[2], t), std::lerp(a[3], b[3], t)};
}

inline float evalBezier(float t, float p1, float p2) noexcept {
  const float oneMinusT = 1.0f - t;
  const float t2 = t * t;
  return (3.0f * oneMinusT * oneMinusT * t * p1) +
         (3.0f * oneMinusT * t2 * p2) + (t2 * t);
}

template <typename T> class AnimatableProperty {
public:
  AnimatableProperty() = default;
  explicit AnimatableProperty(T staticVal)
      : m_staticValue(std::move(staticVal)) {}

  [[nodiscard]] T evaluate(FrameIndex frame) const noexcept {
    if (!m_isAnimated || m_keyframes.empty()) {
      return m_staticValue;
    }

    const size_t count = m_keyframes.size();
    if (count == 1 || frame <= m_keyframes.front().frame) {
      return m_keyframes.front().value;
    }
    if (frame >= m_keyframes.back().frame) {
      return m_keyframes.back().value;
    }

    // Fast Cache hit for forward playback
    if (m_lastIdx + 1 < count) {
      if (frame >= m_keyframes[m_lastIdx].frame &&
          frame < m_keyframes[m_lastIdx + 1].frame) {
        return interpolateSegment(m_lastIdx, frame);
      }
    }

    auto it =
        std::lower_bound(m_keyframes.begin(), m_keyframes.end(), frame,
                         [](const Keyframe<T> &kf, FrameIndex f) noexcept {
                           return kf.frame < f;
                         });

    size_t rightIdx = std::distance(m_keyframes.begin(), it);
    size_t leftIdx = (rightIdx > 0) ? rightIdx - 1 : 0;
    m_lastIdx = leftIdx;

    return interpolateSegment(leftIdx, frame);
  }

  void setStaticValue(T val) noexcept { m_staticValue = std::move(val); }

  [[nodiscard]] const T &staticValue() const noexcept { return m_staticValue; }

  [[nodiscard]] bool isAnimated() const noexcept { return m_isAnimated; }

  void setAnimated(bool animated) noexcept { m_isAnimated = animated; }

  void setKeyframe(FrameIndex frame, T val,
                   InterpolationType interp = InterpolationType::Linear) {
    m_isAnimated = true;
    auto it =
        std::lower_bound(m_keyframes.begin(), m_keyframes.end(), frame,
                         [](const Keyframe<T> &kf, FrameIndex f) noexcept {
                           return kf.frame < f;
                         });

    if (it != m_keyframes.end() && it->frame == frame) {
      it->value = std::move(val);
      it->interpolation = interp;
    } else {
      Keyframe<T> kf;
      kf.frame = frame;
      kf.value = std::move(val);
      kf.interpolation = interp;
      m_keyframes.insert(it, std::move(kf));
    }
  }

  bool removeKeyframe(FrameIndex frame) noexcept {
    auto it =
        std::lower_bound(m_keyframes.begin(), m_keyframes.end(), frame,
                         [](const Keyframe<T> &kf, FrameIndex f) noexcept {
                           return kf.frame < f;
                         });

    if (it != m_keyframes.end() && it->frame == frame) {
      m_keyframes.erase(it);
      if (m_keyframes.empty()) {
        m_isAnimated = false;
      }
      return true;
    }
    return false;
  }

  [[nodiscard]] const std::vector<Keyframe<T>> &keyframes() const noexcept {
    return m_keyframes;
  }

  void clearKeyframes() noexcept {
    m_keyframes.clear();
    m_isAnimated = false;
  }

private:
  inline T interpolateSegment(size_t leftIdx, FrameIndex frame) const noexcept {
    const auto &k0 = m_keyframes[leftIdx];
    const auto &k1 = m_keyframes[leftIdx + 1];

    if (k0.interpolation == InterpolationType::Hold) {
      return k0.value;
    }

    const float duration = static_cast<float>(k1.frame - k0.frame);
    float t = static_cast<float>(frame - k0.frame) / duration;

    if (k0.interpolation == InterpolationType::Bezier) {
      t = evalBezier(t, k0.bezier.outHandleY, k0.bezier.inHandleY);
    }

    return interpolate(k0.value, k1.value, t);
  }

  T m_staticValue{};
  bool m_isAnimated{false};
  std::vector<Keyframe<T>> m_keyframes;
  mutable size_t m_lastIdx{0};
};

} // namespace xyla::anim
