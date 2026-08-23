#pragma once

#include "mediaData.hpp"
#include <QString>

namespace xyla {

class MediaProbe {
public:
  virtual ~MediaProbe() = default;

  virtual bool probe(const QString &filePath, MediaMetadata &outMetadata) = 0;
};

} // namespace xyla
