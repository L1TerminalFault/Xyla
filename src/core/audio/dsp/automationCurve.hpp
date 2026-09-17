#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace xyla::audio {

enum class CurveType : uint8_t {
    Linear = 0,
    Hold = 1,        // Step change at end
    Exponential = 2, // Tension controls convexity/concavity
    SCurve = 3,      // Smoothstep 3t^2 - 2t^3
    Bezier = 4       // Smooth cubic S-curve with tension
};

struct AutomationPoint {
    int64_t sampleOffset{0};
    float value{0.0f};
    CurveType type{CurveType::Linear};
    float tension{0.0f}; // -1.0 to 1.0

    bool operator==(const AutomationPoint &other) const noexcept {
        return sampleOffset == other.sampleOffset &&
               value == other.value &&
               type == other.type &&
               tension == other.tension;
    }
};

namespace dsp {

/**
 * @brief Evaluates normalized interpolation between two values given curve type and tension.
 * @param t Normalized progress in [0.0, 1.0]
 * @param v1 Starting value at t=0
 * @param v2 Ending value at t=1
 * @param type Interpolation algorithm
 * @param tension Shape parameter (-1.0 to 1.0)
 */
inline float interpolateCurve(float t, float v1, float v2, CurveType type, float tension = 0.0f) noexcept {
    t = std::clamp(t, 0.0f, 1.0f);

    switch (type) {
    case CurveType::Hold:
        return (t >= 1.0f) ? v2 : v1;

    case CurveType::Linear:
        return v1 + t * (v2 - v1);

    case CurveType::Exponential: {
        // tension in [-1.0, 1.0]: positive bends downward, negative bends upward
        const float clampedTension = std::clamp(tension, -0.99f, 0.99f);
        const float factor = (clampedTension >= 0.0f)
            ? (1.0f + clampedTension * 4.0f)
            : (1.0f / (1.0f - clampedTension * 4.0f));
        const float expT = std::pow(t, factor);
        return v1 + expT * (v2 - v1);
    }

    case CurveType::SCurve: {
        // Standard Smoothstep: 3t^2 - 2t^3
        const float smoothT = t * t * (3.0f - 2.0f * t);
        return v1 + smoothT * (v2 - v1);
    }

    case CurveType::Bezier: {
        // Tension-biased cubic spline
        // As tension shifts, inflection point moves toward start or end
        float s = t * t * (3.0f - 2.0f * t); // base smoothstep
        if (tension != 0.0f) {
            const float clampedTension = std::clamp(tension, -1.0f, 1.0f);
            if (clampedTension > 0.0f) {
                s = std::pow(s, 1.0f + clampedTension * 2.0f);
            } else {
                s = 1.0f - std::pow(1.0f - s, 1.0f - clampedTension * 2.0f);
            }
        }
        return v1 + s * (v2 - v1);
    }
    }

    return v1;
}

} // namespace dsp

class AutomationCurve {
public:
    AutomationCurve() = default;

    void addPoint(int64_t sampleOffset, float value,
                  CurveType type = CurveType::Linear, float tension = 0.0f) {
        m_points.push_back({sampleOffset, value, type, std::clamp(tension, -1.0f, 1.0f)});
        std::sort(m_points.begin(), m_points.end(),
                  [](const AutomationPoint &a, const AutomationPoint &b) {
                      return a.sampleOffset < b.sampleOffset;
                  });
    }

    void clear() noexcept { m_points.clear(); }

    [[nodiscard]] const std::vector<AutomationPoint> &points() const noexcept {
        return m_points;
    }

    [[nodiscard]] bool empty() const noexcept { return m_points.empty(); }
    [[nodiscard]] size_t size() const noexcept { return m_points.size(); }

    /**
     * @brief Sample-accurate scalar evaluation at sample position.
     */
    [[nodiscard]] float evaluateAtSample(int64_t sample) const noexcept {
        if (m_points.empty()) return 0.0f;
        if (sample <= m_points.front().sampleOffset) return m_points.front().value;
        if (sample >= m_points.back().sampleOffset) return m_points.back().value;

        // Binary search for surrounding segment
        auto it = std::upper_bound(m_points.begin(), m_points.end(), sample,
                                   [](int64_t s, const AutomationPoint &pt) {
                                       return s < pt.sampleOffset;
                                   });

        const auto &p1 = *(it - 1);
        const auto &p2 = *it;

        const int64_t segLength = p2.sampleOffset - p1.sampleOffset;
        if (segLength <= 0) return p1.value;

        const float t = static_cast<float>(sample - p1.sampleOffset) /
                        static_cast<float>(segLength);

        return dsp::interpolateCurve(t, p1.value, p2.value, p1.type, p1.tension);
    }

    /**
     * @brief Populates an entire audio block of sample values for sample-accurate modulation.
     */
    void evaluateBlock(float *destination, size_t frameCount, int64_t startSample) const noexcept {
        if (!destination || frameCount == 0) return;
        for (size_t i = 0; i < frameCount; ++i) {
            destination[i] = evaluateAtSample(startSample + static_cast<int64_t>(i));
        }
    }

private:
    std::vector<AutomationPoint> m_points;
};

} // namespace xyla::audio
