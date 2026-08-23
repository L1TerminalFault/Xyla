#pragma once

#include <QDateTime>
#include <QFileInfo>
#include <QString>

namespace xyla {

struct ProjectInfo {
  QString name;
  QString filePath;
  QDateTime lastModified;
  int fpsNumerator{30};
  int fpsDenominator{1};
  int width{1920};
  int height{1080};

  // TODO
  [[nodiscard]] bool isValid() const {
    return !name.trimmed().isEmpty() && !filePath.trimmed().isEmpty() &&
           QFileInfo::exists(filePath);
  }
};

} // namespace xyla
