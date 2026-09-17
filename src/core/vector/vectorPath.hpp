#pragma once

#include "vectorContour.hpp"
#include <QPainterPath>
#include <array>
#include <vector>

namespace xyla::vector {

enum class FillRule : uint8_t { EvenOdd = 0, Winding };

enum class LineCap : uint8_t { Butt = 0, Square, Round };

enum class LineJoin : uint8_t { Miter = 0, Bevel, Round };

struct StrokeStyle {
  float width{2.0f};
  LineCap cap{LineCap::Butt};
  LineJoin join{LineJoin::Miter};
  float miterLimit{4.0f};
  std::array<float, 4> color{1.0f, 1.0f, 1.0f, 1.0f};

  float trimStart{0.0f};
  float trimEnd{1.0f};
  float trimOffset{0.0f};
};

class VectorPath {
public:
  VectorPath() = default;

  static VectorPath fromPainterPath(const QPainterPath &path);

  void addContour(VectorContour contour);
  [[nodiscard]] const std::vector<VectorContour> &contours() const noexcept {
    return m_contours;
  }
  [[nodiscard]] std::vector<VectorContour> &contours() noexcept {
    return m_contours;
  }

  void computeArcLengths() noexcept;
  [[nodiscard]] float totalLength() const noexcept { return m_totalLength; }

  [[nodiscard]] FillRule fillRule() const noexcept { return m_fillRule; }
  void setFillRule(FillRule rule) noexcept { m_fillRule = rule; }

  [[nodiscard]] const std::array<float, 4> &fillColor() const noexcept {
    return m_fillColor;
  }
  void setFillColor(std::array<float, 4> col) noexcept { m_fillColor = col; }

  [[nodiscard]] const StrokeStyle &stroke() const noexcept { return m_stroke; }
  [[nodiscard]] StrokeStyle &stroke() noexcept { return m_stroke; }
  void setStroke(const StrokeStyle &st) noexcept { m_stroke = st; }

  [[nodiscard]] bool hasFill() const noexcept {
    return m_fillColor[3] > 0.0001f;
  }
  [[nodiscard]] bool hasStroke() const noexcept {
    return m_stroke.width > 0.0001f && m_stroke.color[3] > 0.0001f;
  }

private:
  std::vector<VectorContour> m_contours;
  FillRule m_fillRule{FillRule::Winding};
  std::array<float, 4> m_fillColor{1.0f, 1.0f, 1.0f, 1.0f};
  StrokeStyle m_stroke;
  float m_totalLength{0.0f};
};

} // namespace xyla::vector
