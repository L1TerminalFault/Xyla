#pragma once

#include <cstdint>

namespace xyla::anim {

using FrameIndex = int64_t;

enum class InterpolationType : uint8_t { Hold = 0, Linear = 1, Bezier = 2 };

struct BezierControlPoints {
  float outHandleX{0.333f};
  float outHandleY{0.0f};
  float inHandleX{0.666f};
  float inHandleY{0.0f};
};

template <typename T> struct Keyframe {
  FrameIndex frame{0};
  T value{};
  InterpolationType interpolation{InterpolationType::Linear};
  BezierControlPoints bezier{};

  bool operator<(const Keyframe<T> &other) const noexcept {
    return frame < other.frame;
  }
  bool operator<(FrameIndex targetFrame) const noexcept {
    return frame < targetFrame;
  }
};

} // namespace xyla::anim
