#include "vectorPath.hpp"

namespace xyla::vector {

VectorPath VectorPath::fromPainterPath(const QPainterPath &path) {
  VectorPath result;
  result.setFillRule(path.fillRule() == Qt::OddEvenFill ? FillRule::EvenOdd
                                                        : FillRule::Winding);

  VectorContour currentContour(false);
  Vec2 lastPoint{0.0f, 0.0f};
  Vec2 subpathStart{0.0f, 0.0f};

  for (int i = 0; i < path.elementCount(); ++i) {
    const auto elem = path.elementAt(i);
    Vec2 pt{static_cast<float>(elem.x), static_cast<float>(elem.y)};

    switch (elem.type) {
    case QPainterPath::MoveToElement:
      if (!currentContour.segments().empty()) {
        result.addContour(std::move(currentContour));
        currentContour = VectorContour(false);
      }
      lastPoint = pt;
      subpathStart = pt;
      break;

    case QPainterPath::LineToElement:
      currentContour.addLine(lastPoint, pt);
      lastPoint = pt;
      break;

    case QPainterPath::CurveToElement: {
      if (i + 2 < path.elementCount()) {
        const auto c2 = path.elementAt(i + 1);
        const auto endPt = path.elementAt(i + 2);
        Vec2 cp1 = pt;
        Vec2 cp2{static_cast<float>(c2.x), static_cast<float>(c2.y)};
        Vec2 target{static_cast<float>(endPt.x), static_cast<float>(endPt.y)};

        currentContour.addCubic(lastPoint, cp1, cp2, target);
        lastPoint = target;
        i += 2;
      }
      break;
    }
    case QPainterPath::CurveToDataElement:
      break;
    }
  }

  if (!currentContour.segments().empty()) {
    if ((lastPoint - subpathStart).lengthSquared() < 1e-6f) {
      currentContour.close();
    }
    result.addContour(std::move(currentContour));
  }

  result.computeArcLengths();
  return result;
}

void VectorPath::addContour(VectorContour contour) {
  m_contours.push_back(std::move(contour));
}

void VectorPath::computeArcLengths() noexcept {
  m_totalLength = 0.0f;
  for (auto &contour : m_contours) {
    contour.computeArcLengths();
    m_totalLength += contour.totalLength();
  }
}

} // namespace xyla::vector
