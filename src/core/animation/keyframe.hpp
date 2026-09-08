#pragma once

#include <cstdint>

namespace xyla::anim {

using FrameIndex = int64_t;

enum class Interpolation : uint8_t { Hold = 0, Linear = 1, Bezier = 2 };

struct BezierHandles {
  float outX{0.333f};
  float outY{0.0f};
  float inX{0.666f};
  float inY{0.0f};
};

template <typename T> struct Keyframe {
  FrameIndex frame{0};
  T value{};
  Interpolation interpolation{Interpolation::Linear};
  BezierHandles bezier{};

  bool operator<(const Keyframe &other) const noexcept {
    return frame < other.frame;
  }

  bool operator<(FrameIndex target) const noexcept { return frame < target; }
};

} // namespace xyla::anim
