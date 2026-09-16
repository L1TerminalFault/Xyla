#include "snapEngine.hpp"
#include <algorithm>
#include <cmath>
#include <limits>

namespace xyla {

// serialization

QVariantMap SnapResult1D::toVariantMap() const {
  QVariantMap map;
  map["snappedStart"] = snappedPosition;
  map["isSnapped"] = isSnapped;
  map["tag"] = matchedTag;
  map["guidePosition"] = guidePosition;
  map["isSpacingSnap"] = isSpacingSnap;
  map["spacingGap"] = spacingGap;
  map["allMatchingGaps"] = allMatchingGaps;
  return map;
}

QVariantMap SnapResult2D::toVariantMap() const {
  QVariantMap map;
  map["snappedX"] = snappedX;
  map["snappedY"] = snappedY;
  map["isSnappedX"] = isSnappedX;
  map["isSnappedY"] = isSnappedY;
  map["matchedTagX"] = matchedTagX;
  map["matchedTagY"] = matchedTagY;
  map["guideX"] = guideX;
  map["guideY"] = guideY;
  return map;
}

// registry management

void SnapEngine::addPoint(double x, double y, const QString &tag,
                          int priority) {
  m_points.push_back(
      SnapPoint{.x = x, .y = y, .tag = tag, .priority = priority});
}

void SnapEngine::addIntervalX(double start, double end, const QString &tag) {
  m_intervalsX.push_back(SnapInterval{.start = start, .end = end, .tag = tag});
}

void SnapEngine::addIntervalY(double start, double end, const QString &tag) {
  m_intervalsY.push_back(SnapInterval{.start = start, .end = end, .tag = tag});
}

void SnapEngine::clearByTag(const QString &tag) {
  if (tag.isEmpty())
    return;

  std::erase_if(m_points, [&](const SnapPoint &p) { return p.tag == tag; });
  std::erase_if(m_intervalsX,
                [&](const SnapInterval &i) { return i.tag == tag; });
  std::erase_if(m_intervalsY,
                [&](const SnapInterval &i) { return i.tag == tag; });
}

void SnapEngine::clearAll() noexcept {
  m_points.clear();
  m_intervalsX.clear();
  m_intervalsY.clear();
}

// queries

SnapResult1D SnapEngine::snap1D(double candidateStart, double candidateDuration,
                                double threshold) const {
  SnapResult1D result;
  result.snappedPosition = candidateStart;

  if (threshold <= 0.0) {
    return result;
  }

  const double candidateEnd = candidateStart + candidateDuration;

  // 1. Point and Edge Snapping
  double bestDelta = std::numeric_limits<double>::max();
  double bestSnappedPos = candidateStart;
  QString bestTag;
  double bestGuide = -1.0;
  int bestPriority = std::numeric_limits<int>::min();
  bool foundSnap = false;

  auto testPoint = [&](double targetX, const QString &tag, int priority) {
    // Leading edge
    double distLeft = std::abs(candidateStart - targetX);
    if (distLeft <= threshold) {
      bool isBetter = (distLeft < std::abs(bestDelta)) ||
                      (std::abs(distLeft - std::abs(bestDelta)) < 1e-6 &&
                       priority > bestPriority);
      if (isBetter) {
        bestDelta = targetX - candidateStart;
        bestSnappedPos = targetX;
        bestTag = tag;
        bestGuide = targetX;
        bestPriority = priority;
        foundSnap = true;
      }
    }

    // Trailing edge
    double distRight = std::abs(candidateEnd - targetX);
    if (distRight <= threshold) {
      double targetStart = targetX - candidateDuration;
      double delta = targetStart - candidateStart;
      bool isBetter = (distRight < std::abs(bestDelta)) ||
                      (std::abs(distRight - std::abs(bestDelta)) < 1e-6 &&
                       priority > bestPriority);
      if (isBetter) {
        bestDelta = delta;
        bestSnappedPos = targetStart;
        bestTag = tag;
        bestGuide = targetX;
        bestPriority = priority;
        foundSnap = true;
      }
    }
  };

  // Test registered points
  for (const auto &p : m_points) {
    testPoint(p.x, p.tag, p.priority);
  }

  // Test interval edges
  for (const auto &interval : m_intervalsX) {
    testPoint(interval.start, interval.tag, 0);
    testPoint(interval.end, interval.tag, 0);
  }

  if (foundSnap) {
    result.snappedPosition = bestSnappedPos;
    result.isSnapped = true;
    result.matchedTag = bestTag;
    result.guidePosition = bestGuide;
    return result;
  }

  // 2. Equal Spacing Gap Snapping
  if (m_intervalsX.size() < 2) {
    return result;
  }

  std::vector<SnapInterval> sorted = m_intervalsX;
  std::sort(sorted.begin(), sorted.end(),
            [](const SnapInterval &a, const SnapInterval &b) {
              return a.start < b.start;
            });

  struct Gap {
    double start;
    double end;
    double duration;
  };

  std::vector<Gap> existingGaps;
  for (size_t i = 0; i < sorted.size() - 1; ++i) {
    double gapDur = sorted[i + 1].start - sorted[i].end;
    if (gapDur > 0.0) {
      existingGaps.push_back({sorted[i].end, sorted[i + 1].start, gapDur});
    }
  }

  double bestGapDelta = std::numeric_limits<double>::max();
  double bestGapSnappedStart = candidateStart;
  double matchedGapDuration = 0.0;
  double matchedActiveStart = -1.0;
  double matchedActiveEnd = -1.0;

  for (const auto &interval : sorted) {
    for (const auto &eg : existingGaps) {
      double refGap = eg.duration;

      // Candidate placed AFTER interval
      double candAfter = interval.end + refGap;
      double deltaAfter = std::abs(candidateStart - candAfter);
      if (deltaAfter <= threshold && deltaAfter < std::abs(bestGapDelta)) {
        bestGapDelta = deltaAfter;
        bestGapSnappedStart = candAfter;
        matchedGapDuration = refGap;
        matchedActiveStart = interval.end;
        matchedActiveEnd = candAfter;
      }

      // Candidate placed BEFORE interval
      double candBefore = interval.start - refGap - candidateDuration;
      if (candBefore >= 0.0) {
        double deltaBefore = std::abs(candidateStart - candBefore);
        if (deltaBefore <= threshold && deltaBefore < std::abs(bestGapDelta)) {
          bestGapDelta = deltaBefore;
          bestGapSnappedStart = candBefore;
          matchedGapDuration = refGap;
          matchedActiveStart = candBefore + candidateDuration;
          matchedActiveEnd = interval.start;
        }
      }
    }
  }

  if (std::abs(bestGapDelta) <= threshold && matchedActiveStart >= 0.0) {
    result.snappedPosition = bestGapSnappedStart;
    result.isSnapped = true;
    result.isSpacingSnap = true;
    result.matchedTag = "spacing_gap";
    result.spacingGap = matchedGapDuration;

    QVariantList allGaps;
    for (const auto &eg : existingGaps) {
      if (std::abs(eg.duration - matchedGapDuration) < 1e-4) {
        QVariantMap gapMap;
        gapMap["start"] = eg.start;
        gapMap["end"] = eg.end;
        gapMap["gapDuration"] = eg.duration;
        gapMap["isActive"] = false;
        allGaps.push_back(gapMap);
      }
    }

    QVariantMap activeGapMap;
    activeGapMap["start"] = matchedActiveStart;
    activeGapMap["end"] = matchedActiveEnd;
    activeGapMap["gapDuration"] = matchedGapDuration;
    activeGapMap["isActive"] = true;
    allGaps.push_back(activeGapMap);

    result.allMatchingGaps = allGaps;
    return result;
  }

  return result;
}

SnapResult2D SnapEngine::snap2D(double candidateX, double candidateY,
                                double candidateWidth, double candidateHeight,
                                double thresholdX, double thresholdY) const {
  SnapResult2D result;
  result.snappedX = candidateX;
  result.snappedY = candidateY;

  // Snap X axis
  SnapResult1D resX = snap1D(candidateX, candidateWidth, thresholdX);
  result.snappedX = resX.snappedPosition;
  result.isSnappedX = resX.isSnapped;
  result.matchedTagX = resX.matchedTag;
  result.guideX = resX.guidePosition;

  // Snap Y axis against Y points and Y intervals
  if (thresholdY > 0.0) {
    double bestDeltaY = std::numeric_limits<double>::max();
    double bestSnappedY = candidateY;
    QString bestTagY;
    double bestGuideY = -1.0;
    bool foundY = false;

    auto testPointY = [&](double targetY, const QString &tag) {
      double distTop = std::abs(candidateY - targetY);
      if (distTop <= thresholdY && distTop < std::abs(bestDeltaY)) {
        bestDeltaY = targetY - candidateY;
        bestSnappedY = targetY;
        bestTagY = tag;
        bestGuideY = targetY;
        foundY = true;
      }
      double distBottom = std::abs((candidateY + candidateHeight) - targetY);
      if (distBottom <= thresholdY && distBottom < std::abs(bestDeltaY)) {
        bestDeltaY = (targetY - candidateHeight) - candidateY;
        bestSnappedY = targetY - candidateHeight;
        bestTagY = tag;
        bestGuideY = targetY;
        foundY = true;
      }
    };

    for (const auto &p : m_points) {
      testPointY(p.y, p.tag);
    }
    for (const auto &i : m_intervalsY) {
      testPointY(i.start, i.tag);
      testPointY(i.end, i.tag);
    }

    if (foundY) {
      result.snappedY = bestSnappedY;
      result.isSnappedY = true;
      result.matchedTagY = bestTagY;
      result.guideY = bestGuideY;
    }
  }

  return result;
}

} // namespace xyla
