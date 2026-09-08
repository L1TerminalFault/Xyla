#pragma once

#include <algorithm>
#include <array>
#include <cmath>

namespace xyla::anim {

inline float lerp(float a, float b, float t) noexcept {
  return std::lerp(a, b, t);
}

inline std::array<float, 2> lerp(const std::array<float, 2> &a,
                                 const std::array<float, 2> &b,
                                 float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t)};
}

inline std::array<float, 3> lerp(const std::array<float, 3> &a,
                                 const std::array<float, 3> &b,
                                 float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t),
          std::lerp(a[2], b[2], t)};
}

inline std::array<float, 4> lerp(const std::array<float, 4> &a,
                                 const std::array<float, 4> &b,
                                 float t) noexcept {
  return {std::lerp(a[0], b[0], t), std::lerp(a[1], b[1], t),
          std::lerp(a[2], b[2], t), std::lerp(a[3], b[3], t)};
}

// Evaluates a 1D cubic Bezier for the value axis given parameter t ∈ [0,1].
// p1 / p2 are the Y components of the outgoing / incoming handles.
inline float evalBezierY(float t, float p1, float p2) noexcept {
  const float u = 1.0f - t;
  const float tt = t * t;
  const float uu = u * u;
  return (3.0f * uu * t * p1) + (3.0f * u * tt * p2) + (tt * t);
}

// Finds t ∈ [0,1] such that the X (time) Bezier equals the target x.
// Uses Newton-Raphson with a fixed iteration limit.
inline float solveBezierT(float x, float p1x, float p2x) noexcept {
  float t = x; // initial guess
  for (int i = 0; i < 8; ++i) {
    const float u = 1.0f - t;
    const float tt = t * t;
    const float uu = u * u;
    const float current =
        (3.0f * uu * t * p1x) + (3.0f * u * tt * p2x) + (tt * t);
    const float derivative = (3.0f * uu * p1x) + (6.0f * u * t * (p2x - p1x)) +
                             (3.0f * tt * (1.0f - p2x));
    if (std::abs(derivative) < 1e-6f)
      break;
    t -= (current - x) / derivative;
    t = std::clamp(t, 0.0f, 1.0f);
  }
  return t;
}

} // namespace xyla::anim
