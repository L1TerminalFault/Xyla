#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <vector>

namespace xyla {

// 2d point target
struct SnapPoint {
  double x{0.0};
  double y{0.0};
  QString tag;
  int priority{0};
};

// 1d interval block for spacing
struct SnapInterval {
  double start{0.0};
  double end{0.0};
  QString tag;

  [[nodiscard]] double getDuration() const noexcept { return end - start; }
};

// 1d snap evaluation result
struct SnapResult1D {
  double snappedPosition{0.0};
  bool isSnapped{false};
  QString matchedTag;
  double guidePosition{-1.0};
  bool isSpacingSnap{false};
  double spacingGap{0.0};
  QVariantList allMatchingGaps;

  [[nodiscard]] QVariantMap toVariantMap() const;
};

// 2d snap evaluation result
struct SnapResult2D {
  double snappedX{0.0};
  double snappedY{0.0};
  bool isSnappedX{false};
  bool isSnappedY{false};
  QString matchedTagX;
  QString matchedTagY;
  double guideX{-1.0};
  double guideY{-1.0};

  [[nodiscard]] QVariantMap toVariantMap() const;
};

// stateful tag-based snap registry
class SnapEngine {
public:
  // registry management
  void addPoint(double x, double y = 0.0, const QString &tag = "",
                int priority = 0);
  void addIntervalX(double start, double end, const QString &tag = "");
  void addIntervalY(double start, double end, const QString &tag = "");

  void clearByTag(const QString &tag);
  void clearAll() noexcept;

  // queries
  [[nodiscard]] SnapResult1D snap1D(double candidateStart,
                                    double candidateDuration,
                                    double threshold) const;

  [[nodiscard]] SnapResult2D snap2D(double candidateX, double candidateY,
                                    double candidateWidth,
                                    double candidateHeight, double thresholdX,
                                    double thresholdY) const;

private:
  std::vector<SnapPoint> m_points;
  std::vector<SnapInterval> m_intervalsX;
  std::vector<SnapInterval> m_intervalsY;
};

} // namespace xyla
