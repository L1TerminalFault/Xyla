#pragma once

#include <QDateTime>
#include <QFileInfo>
#include <QString>
#include <cmath>

namespace xyla {

struct ProjectInfo {
  QString name;
  QString filePath;
  QDateTime lastModified;
  int fpsNumerator{30};
  int fpsDenominator{1};
  int width{1920};
  int height{1080};
  int videoTrackCount{2};
  int audioTrackCount{2};

  [[nodiscard]] double fps() const noexcept {
    return (fpsDenominator > 0)
               ? static_cast<double>(fpsNumerator) / fpsDenominator
               : 30.0;
  }

  [[nodiscard]] int64_t secondsToFrames(double seconds) const noexcept {
    if (fpsDenominator <= 0)
      return 0;
    return static_cast<int64_t>(
        std::round(seconds * fpsNumerator / fpsDenominator));
  }

  [[nodiscard]] double framesToSeconds(int64_t frames) const noexcept {
    if (fpsNumerator <= 0 || fpsDenominator <= 0)
      return 0.0;
    return static_cast<double>(frames * fpsDenominator) /
           static_cast<double>(fpsNumerator);
  }

  [[nodiscard]] bool isValid() const {
    return !name.trimmed().isEmpty() && !filePath.trimmed().isEmpty() &&
           QFileInfo::exists(filePath);
  }
};

} // namespace xyla
