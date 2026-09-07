#pragma once

#include "keyframe.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <concepts>

namespace xyla::anim {

// Fast lerp for standard float
inline float interpolateValue(float a, float b, float t) noexcept {
  return std::lerp(a, b, t);
}

// Lerp for 2D vectors
inline std::array<float, 2> interpolateValue(const std::array<float, 2> &a,
                                             const std::array<float, 2> &b,
                                             float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t)};
}

inline std::array<float, 3> interpolateValue(const std::array<float, 3> &a,
                                             const std::array<float, 3> &b,
                                             float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t),
          std::lerp(a[2], b[2], t)};
}

inline std::array<float, 4> interpolateValue(const std::array<float, 4> &a,
                                             const std::array<float, 4> &b,
                                             float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t),
          std::lerp(a[2], b[2], t), std::lerp(a[3], b[3], t)};
}

inline float evaluateCubicBezier(float t, float p1, float p2) noexcept {
  // Standard Bernstein form: B(t) = 3(1-t)^2 * t * p1 + 3(1-t) * t^2 * p2 + t^3
  const float oneMinusT = 1.0f - t;
  const float t2 = t * t;
  return (3.0f * oneMinusT * oneMinusT * t * p1) +
         (3.0f * oneMinusT * t2 * p2) + (t2 * t);
}

} // namespace xyla::anim
