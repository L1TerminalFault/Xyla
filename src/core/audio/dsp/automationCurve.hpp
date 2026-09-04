#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace xyla::audio {

enum class CurveType : uint8_t {
  Linear = 0,
  Hold = 1, // Immediate step
  Exponential = 2,
  SCurve = 3,
  Bezier = 4
};

struct AutomationPoint {
  int64_t sampleOffset{0};
  float value{0.0f};
  CurveType type{CurveType::Linear};
  float tension{0.0f};
};

class AutomationCurve {
public:
  AutomationCurve() = default;

  void addPoint(int64_t sampleOffset, float value,
                CurveType type = CurveType::Linear, float tension = 0.0f) {
    m_points.push_back({sampleOffset, value, type, tension});
    std::sort(m_points.begin(), m_points.end(),
              [](const AutomationPoint &a, const AutomationPoint &b) {
                return a.sampleOffset < b.sampleOffset;
              });
  }

  void clear() noexcept { m_points.clear(); }

  [[nodiscard]] const std::vector<AutomationPoint> &points() const noexcept {
    return m_points;
  }

  /**
   * @brief Sample-accurate curve evaluation at a given sample position.
   */
  [[nodiscard]] float evaluateAtSample(int64_t sample) const noexcept {
    if (m_points.empty())
      return 0.0f;
    if (sample <= m_points.front().sampleOffset)
      return m_points.front().value;
    if (sample >= m_points.back().sampleOffset)
      return m_points.back().value;

    // Binary search for surrounding segment
    auto it = std::upper_bound(m_points.begin(), m_points.end(), sample,
                               [](int64_t s, const AutomationPoint &pt) {
                                 return s < pt.sampleOffset;
                               });

    const auto &p1 = *(it - 1);
    const auto &p2 = *it;

    int64_t segLength = p2.sampleOffset - p1.sampleOffset;
    if (segLength <= 0)
      return p1.value;

    float t = static_cast<float>(sample - p1.sampleOffset) /
              static_cast<float>(segLength);

    switch (p1.type) {
    case CurveType::Hold:
      return p1.value;

    case CurveType::Linear:
      return p1.value + t * (p2.value - p1.value);

    case CurveType::Exponential: {
      float factor = (p1.tension >= 0.0f) ? (1.0f + p1.tension * 4.0f)
                                          : (1.0f / (1.0f - p1.tension * 4.0f));
      float expT = std::pow(t, factor);
      return p1.value + expT * (p2.value - p1.value);
    }

    case CurveType::SCurve: {
      // Smoothstep 3t^2 - 2t^3
      float smoothT = t * t * (3.0f - 2.0f * t);
      return p1.value + smoothT * (p2.value - p1.value);
    }

    case CurveType::Bezier: {
      // Cubic Hermite easing with tension
      float t2 = t * t;
      float t3 = t2 * t;
      float h1 = 2.0f * t3 - 3.0f * t2 + 1.0f;
      float h2 = -2.0f * t3 + 3.0f * t2;
      return h1 * p1.value + h2 * p2.value;
    }
    }

    return p1.value;
  }

private:
  std::vector<AutomationPoint> m_points;
};

} // namespace xyla::audio
