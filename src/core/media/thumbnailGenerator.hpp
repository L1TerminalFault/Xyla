#pragma once

#include "mediaData.hpp"
#include <QImage>
#include <QString>
#include <future>

namespace xyla {

class ThumbnailGenerator {
public:
  static QImage extractThumbnail(const QString &filePath, int targetWidth = 320,
                                 double timePositionSec = -1.0);
};

} // namespace xyla
