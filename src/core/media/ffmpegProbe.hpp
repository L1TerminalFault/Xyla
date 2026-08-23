#pragma once

#include "mediaProbe.hpp"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/pixdesc.h>
}

namespace xyla {
class FFmpegProbe : public MediaProbe {
public:
  FFmpegProbe() = default;
  ~FFmpegProbe() override = default;

  // Fast, thread-safe, non-blocking header extraction engine
  bool probe(const QString &filePath, MediaMetadata &outMetadata) override;

private:
  static QString parseColorTransfer(AVColorTransferCharacteristic transfer);
  static QString parseColorSpace(AVColorSpace space);
};
} // namespace xyla
