#pragma once

#include <cmath>
#include <cstdint>
#include <vector>

namespace xyla::vector {

struct Vec2 {
  float x{0.0f};
  float y{0.0f};

  constexpr Vec2() noexcept = default;
  constexpr Vec2(float px, float py) noexcept : x(px), y(py) {}

  constexpr Vec2 operator+(const Vec2 &o) const noexcept {
    return {x + o.x, y + o.y};
  }
  constexpr Vec2 operator-(const Vec2 &o) const noexcept {
    return {x - o.x, y - o.y};
  }
  constexpr Vec2 operator*(float s) const noexcept { return {x * s, y * s}; }
  constexpr Vec2 operator/(float s) const noexcept {
    float inv = (std::abs(s) > 1e-6f) ? 1.0f / s : 0.0f;
    return {x * inv, y * inv};
  }

  [[nodiscard]] float lengthSquared() const noexcept { return x * x + y * y; }
  [[nodiscard]] float length() const noexcept {
    return std::sqrt(lengthSquared());
  }

  [[nodiscard]] Vec2 normalized() const noexcept {
    float len = length();
    return (len > 1e-6f) ? (*this / len) : Vec2{0.0f, 0.0f};
  }

  [[nodiscard]] Vec2 perpendicular() const noexcept { return {-y, x}; }
  [[nodiscard]] float dot(const Vec2 &o) const noexcept {
    return x * o.x + y * o.y;
  }
};

enum class SegmentType : uint8_t { Line = 0, Quadratic, Cubic };

struct BezierSegment {
  SegmentType type{SegmentType::Line};
  Vec2 p0{0.0f, 0.0f};
  Vec2 p1{0.0f, 0.0f};
  Vec2 p2{0.0f, 0.0f};
  Vec2 p3{0.0f, 0.0f};

  float length{0.0f};
  float cumulativeStartLength{0.0f};

  [[nodiscard]] Vec2 evaluate(float t) const noexcept;
  [[nodiscard]] Vec2 evaluateDerivative(float t) const noexcept;
  [[nodiscard]] Vec2 evaluateNormal(float t) const noexcept;
  [[nodiscard]] float computeArcLength() const noexcept;
  void subdivideCubicToQuadratic(float tolerance,
                                 std::vector<BezierSegment> &out) const;
};

class VectorContour {
public:
  VectorContour() = default;
  explicit VectorContour(bool isClosed) : m_isClosed(isClosed) {}

  void addLine(Vec2 start, Vec2 end);
  void addQuadratic(Vec2 start, Vec2 control, Vec2 end);
  void addCubic(Vec2 start, Vec2 control1, Vec2 control2, Vec2 end);

  void close() noexcept { m_isClosed = true; }
  [[nodiscard]] bool isClosed() const noexcept { return m_isClosed; }

  void computeArcLengths() noexcept;
  [[nodiscard]] float totalLength() const noexcept { return m_totalLength; }

  [[nodiscard]] const std::vector<BezierSegment> &segments() const noexcept {
    return m_segments;
  }

  [[nodiscard]] Vec2 samplePositionAtLength(float s) const noexcept;
  [[nodiscard]] Vec2 sampleNormalAtLength(float s) const noexcept;

private:
  std::vector<BezierSegment> m_segments;
  float m_totalLength{0.0f};
  bool m_isClosed{false};
};

} // namespace xyla::vector
