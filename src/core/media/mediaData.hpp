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

  QVariantMap toVariantMap() const {
    return {{"width", width},
            {"height", height},
            {"frameRate", frameRate},
            {"totalFrames", static_cast<qint64>(totalFrames)},
            {"codecName", codecName},
            {"pixelFormat", pixelFormat}};
  }

  static VideoStreamInfo fromVariantMap(const QVariantMap &map) {
    VideoStreamInfo info;
    info.width = map.value("width").toInt();
    info.height = map.value("height").toInt();
    info.frameRate = map.value("frameRate").toDouble();
    info.totalFrames = map.value("totalFrames").toLongLong();
    info.codecName = map.value("codecName").toString();
    info.pixelFormat = map.value("pixelFormat").toString();
    return info;
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

  QVariantMap toVariantMap() const {
    return {{"sampleRate", sampleRate},
            {"channels", channels},
            {"totalSamples", static_cast<qint64>(totalSamples)},
            {"codecName", codecName},
            {"sampleFormat", sampleFormat}};
  }

  static AudioStreamInfo fromVariantMap(const QVariantMap &map) {
    AudioStreamInfo info;
    info.sampleRate = map.value("sampleRate").toInt();
    info.channels = map.value("channels").toInt();
    info.totalSamples = map.value("totalSamples").toLongLong();
    info.codecName = map.value("codecName").toString();
    info.sampleFormat = map.value("sampleFormat").toString();
    return info;
  }
};

struct MediaMetadata {
  QString filePath;
  int64_t fileSizeBytes{0};
  double durationSeconds{0.0};
  MediaType type{MediaType::Unknown};

  std::vector<VideoStreamInfo> videoStreams;
  std::vector<AudioStreamInfo> audioStreams;

  bool hasVideo() const { return !videoStreams.empty(); }
  bool hasAudio() const { return !audioStreams.empty(); }

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

    // Serialize video streams vector
    QVariantList videoList;
    videoList.reserve(static_cast<qsizetype>(videoStreams.size()));
    for (const auto &vs : videoStreams) {
      videoList.append(vs.toVariantMap());
    }
    map["videoStreams"] = videoList;

    // Serialize audio streams vector
    QVariantList audioList;
    audioList.reserve(static_cast<qsizetype>(audioStreams.size()));
    for (const auto &as : audioStreams) {
      audioList.append(as.toVariantMap());
    }
    map["audioStreams"] = audioList;

    return map;
  }

  static MediaMetadata fromVariantMap(const QVariantMap &map) {
    MediaMetadata meta;
    meta.filePath = map.value("filePath").toString();
    meta.fileSizeBytes = map.value("fileSize").toLongLong();
    meta.durationSeconds = map.value("duration").toDouble();
    meta.type = static_cast<MediaType>(map.value("type").toInt());

    // Deserialize video streams vector
    const QVariantList videoList = map.value("videoStreams").toList();
    meta.videoStreams.reserve(static_cast<qsizetype>(videoList.size()));
    for (const auto &var : videoList) {
      meta.videoStreams.push_back(VideoStreamInfo::fromVariantMap(var.toMap()));
    }

    // Deserialize audio streams vector
    const QVariantList audioList = map.value("audioStreams").toList();
    meta.audioStreams.reserve(static_cast<qsizetype>(audioList.size()));
    for (const auto &var : audioList) {
      meta.audioStreams.push_back(AudioStreamInfo::fromVariantMap(var.toMap()));
    }

    return meta;
  }
};

} // namespace xyla
