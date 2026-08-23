#pragma once

#include <QString>
#include <QVariant>
#include <QVariantMap>
#include <cstdint>
#include <vector>

namespace xyla {

enum class MediaType { Unknown, Video, Audio, Image, ImageSequence };

struct VideoStreamInfo {
  int width{0};
  int height{0};
  double frameRate{0.0};
  int64_t totalFrames{0};
  QString codecName;
  QString pixelFormat;

  [[nodiscard]] bool isValid() const noexcept {
    return width > 0 && width <= 32768 && height > 0 && height <= 32768 &&
           frameRate > 0.0 && frameRate <= 1000.0 && totalFrames >= 0 &&
           !codecName.isEmpty() && codecName != "unknown";
  }
};

struct AudioStreamInfo {
  int sampleRate{0};
  int channels{0};
  int64_t totalSamples{0};
  QString codecName;
  QString sampleFormat;

  [[nodiscard]] bool isValid() const noexcept {
    return sampleRate >= 8000 && sampleRate <= 384000 && channels > 0 &&
           channels <= 128 && totalSamples >= 0 && !codecName.isEmpty() &&
           codecName != "unknown";
  }
};

struct MediaMetadata {
  QString filePath;
  int64_t fileSizeBytes{0};
  double durationSeconds{0.0};
  MediaType type{MediaType::Unknown};

  std::vector<VideoStreamInfo> videoStreams;
  std::vector<AudioStreamInfo> audioStreams;

  [[nodiscard]] bool isValid() const noexcept {
    if (filePath.isEmpty() || fileSizeBytes <= 0 || durationSeconds <= 0.001) {
      return false;
    }

    if (type == MediaType::Video) {
      if (videoStreams.empty())
        return false;
      for (const auto &vs : videoStreams) {
        if (!vs.isValid())
          return false;
      }
    } else if (type == MediaType::Audio) {
      if (audioStreams.empty())
        return false;
      for (const auto &as : audioStreams) {
        if (!as.isValid())
          return false;
      }
    } else {
      return false; // Unknown or unclassified media type
    }

    return true;
  }
  QVariantMap toVariantMap() const {
    QVariantMap map;
    map["filePath"] = filePath;
    map["fileSize"] = static_cast<qint64>(fileSizeBytes);
    map["duration"] = durationSeconds;
    map["type"] = static_cast<int>(type);
    map["isValid"] = isValid();
    map["hasVideo"] = !videoStreams.empty();
    map["hasAudio"] = !audioStreams.empty();
    return map;
  }
};

} // namespace xyla
