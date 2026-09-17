#include "vectorContour.hpp"
#include <algorithm>

namespace xyla::vector {

Vec2 BezierSegment::evaluate(float t) const noexcept {
  t = std::clamp(t, 0.0f, 1.0f);
  float u = 1.0f - t;
  switch (type) {
  case SegmentType::Line:
    return p0 * u + p1 * t;
  case SegmentType::Quadratic:
    return p0 * (u * u) + p1 * (2.0f * u * t) + p2 * (t * t);
  case SegmentType::Cubic:
    return p0 * (u * u * u) + p1 * (3.0f * u * u * t) +
           p2 * (3.0f * u * t * t) + p3 * (t * t * t);
  }
  return p0;
}

Vec2 BezierSegment::evaluateDerivative(float t) const noexcept {
  t = std::clamp(t, 0.0f, 1.0f);
  float u = 1.0f - t;
  switch (type) {
  case SegmentType::Line:
    return p1 - p0;
  case SegmentType::Quadratic:
    return (p1 - p0) * (2.0f * u) + (p2 - p1) * (2.0f * t);
  case SegmentType::Cubic:
    return (p1 - p0) * (3.0f * u * u) + (p2 - p1) * (6.0f * u * t) +
           (p3 - p2) * (3.0f * t * t);
  }
  return {0.0f, 0.0f};
}

Vec2 BezierSegment::evaluateNormal(float t) const noexcept {
  return evaluateDerivative(t).perpendicular().normalized();
}

float BezierSegment::computeArcLength() const noexcept {
  if (type == SegmentType::Line) {
    return (p1 - p0).length();
  }

  static constexpr float kAbscissae[5] = {0.0f, -0.5384693101f, 0.5384693101f,
                                          -0.9061798459f, 0.9061798459f};
  static constexpr float kWeights[5] = {0.5688888889f, 0.4786286705f,
                                        0.4786286705f, 0.2369268850f,
                                        0.2369268850f};

  float lengthSum = 0.0f;
  for (size_t i = 0; i < 5; ++i) {
    float t = 0.5f * (kAbscissae[i] + 1.0f);
    Vec2 deriv = evaluateDerivative(t);
    lengthSum += kWeights[i] * deriv.length();
  }
  return lengthSum * 0.5f;
}

void BezierSegment::subdivideCubicToQuadratic(
    float tolerance, std::vector<BezierSegment> &out) const {
  if (type != SegmentType::Cubic) {
    out.push_back(*this);
    return;
  }

  Vec2 midTangent0 = (p1 - p0) * 3.0f;
  Vec2 midTangent1 = (p3 - p2) * 3.0f;

  Vec2 q1 = (p1 * 3.0f - p0 + p2 * 3.0f - p3) * 0.25f;

  Vec2 cubicMid = evaluate(0.5f);
  Vec2 quadMid = (p0 + q1 * 2.0f + p3) * 0.25f;

  if ((cubicMid - quadMid).length() <= tolerance) {
    BezierSegment quad;
    quad.type = SegmentType::Quadratic;
    quad.p0 = p0;
    quad.p1 = q1;
    quad.p2 = p3;
    quad.length = quad.computeArcLength();
    out.push_back(quad);
    return;
  }

  Vec2 p01 = (p0 + p1) * 0.5f;
  Vec2 p12 = (p1 + p2) * 0.5f;
  Vec2 p23 = (p2 + p3) * 0.5f;
  Vec2 p012 = (p01 + p12) * 0.5f;
  Vec2 p123 = (p12 + p23) * 0.5f;
  Vec2 p0123 = (p012 + p123) * 0.5f;

  BezierSegment left;
  left.type = SegmentType::Cubic;
  left.p0 = p0;
  left.p1 = p01;
  left.p2 = p012;
  left.p3 = p0123;
  left.subdivideCubicToQuadratic(tolerance, out);

  BezierSegment right;
  right.type = SegmentType::Cubic;
  right.p0 = p0123;
  right.p1 = p123;
  right.p2 = p23;
  right.p3 = p3;
  right.subdivideCubicToQuadratic(tolerance, out);
}

void VectorContour::addLine(Vec2 start, Vec2 end) {
  BezierSegment seg;
  seg.type = SegmentType::Line;
  seg.p0 = start;
  seg.p1 = end;
  m_segments.push_back(seg);
}

void VectorContour::addQuadratic(Vec2 start, Vec2 control, Vec2 end) {
  BezierSegment seg;
  seg.type = SegmentType::Quadratic;
  seg.p0 = start;
  seg.p1 = control;
  seg.p2 = end;
  m_segments.push_back(seg);
}

void VectorContour::addCubic(Vec2 start, Vec2 control1, Vec2 control2,
                             Vec2 end) {
  BezierSegment seg;
  seg.type = SegmentType::Cubic;
  seg.p0 = start;
  seg.p1 = control1;
  seg.p2 = control2;
  seg.p3 = end;
  m_segments.push_back(seg);
}

void VectorContour::computeArcLengths() noexcept {
  m_totalLength = 0.0f;
  for (auto &seg : m_segments) {
    seg.cumulativeStartLength = m_totalLength;
    seg.length = seg.computeArcLength();
    m_totalLength += seg.length;
  }
}

Vec2 VectorContour::samplePositionAtLength(float s) const noexcept {
  if (m_segments.empty())
    return {0.0f, 0.0f};

  if (m_isClosed && m_totalLength > 1e-6f) {
    s = std::fmod(s, m_totalLength);
    if (s < 0.0f)
      s += m_totalLength;
  } else {
    s = std::clamp(s, 0.0f, m_totalLength);
  }

  for (const auto &seg : m_segments) {
    if (s <= seg.cumulativeStartLength + seg.length ||
        &seg == &m_segments.back()) {
      float segLocalS = s - seg.cumulativeStartLength;
      float t = (seg.length > 1e-6f) ? (segLocalS / seg.length) : 0.0f;
      return seg.evaluate(t);
    }
  }
  return m_segments.back().p1;
}

Vec2 VectorContour::sampleNormalAtLength(float s) const noexcept {
  if (m_segments.empty())
    return {0.0f, 1.0f};

  if (m_isClosed && m_totalLength > 1e-6f) {
    s = std::fmod(s, m_totalLength);
    if (s < 0.0f)
      s += m_totalLength;
  } else {
    s = std::clamp(s, 0.0f, m_totalLength);
  }

  for (const auto &seg : m_segments) {
    if (s <= seg.cumulativeStartLength + seg.length ||
        &seg == &m_segments.back()) {
      float segLocalS = s - seg.cumulativeStartLength;
      float t = (seg.length > 1e-6f) ? (segLocalS / seg.length) : 0.0f;
      return seg.evaluateNormal(t);
    }
  }
  return m_segments.back().evaluateNormal(1.0f);
}

} // namespace xyla::vector
