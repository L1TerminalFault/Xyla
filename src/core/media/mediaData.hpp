#pragma once

#include <QString>
#include <QVariantMap>
#include <vector>
#include <cstdint>

namespace xyla {

enum class MediaType { Unknown, Video, Audio, Image, ImageSequence };

struct VideoStreamInfo {
  int streamIndex{0};
  int width{0};
  int height{0};
  double frameRate{0.0};
  int64_t totalFrames{0};

  QString codecName;
  QString codecLongName;
  QString pixelFormat;
  QString colorSpace;
  QString colorPrimaries;
  QString colorTransfer;
  int bitDepth{8};
  double durationSeconds{0.0};

  [[nodiscard]] bool isValid() const noexcept {
    return width > 0 && width <= 32768 && height > 0 && height <= 32768 &&
           frameRate > 0.0 && frameRate <= 1000.0 && totalFrames >= 0 &&
           !codecName.isEmpty() && codecName != "unknown";
  }

  QVariantMap toVariantMap() const {
    QVariantMap map;
    map["streamIndex"] = streamIndex;
    map["codecName"] = codecName;
    map["codecLongName"] = codecLongName;
    map["width"] = width;
    map["height"] = height;
    map["frameRate"] = frameRate;
    map["pixelFormat"] = pixelFormat;
    map["colorSpace"] = colorSpace;
    map["colorPrimaries"] = colorPrimaries;
    map["colorTransfer"] = colorTransfer;
    map["bitDepth"] = bitDepth;
    map["totalFrames"] = static_cast<qint64>(totalFrames);
    map["duration"] = durationSeconds;
    return map;
  }

  static VideoStreamInfo fromVariantMap(const QVariantMap &map) {
    VideoStreamInfo info;
    info.streamIndex = map.value("streamIndex").toInt();
    info.width = map.value("width").toInt();
    info.height = map.value("height").toInt();
    info.frameRate = map.value("frameRate").toDouble();
    info.totalFrames = map.value("totalFrames").toLongLong();
    info.codecName = map.value("codecName").toString();
    info.codecLongName = map.value("codecLongName").toString();
    info.pixelFormat = map.value("pixelFormat").toString();
    info.colorSpace = map.value("colorSpace").toString();
    info.colorPrimaries = map.value("colorPrimaries").toString();
    info.colorTransfer = map.value("colorTransfer").toString();
    info.bitDepth = map.value("bitDepth", 8).toInt();
    info.durationSeconds = map.value("duration").toDouble();
    return info;
  }
};

struct AudioStreamInfo {
  int streamIndex{0};
  QString codecName;
  int sampleRate{0};
  int channels{0};
  QString channelLayout;
  QString sampleFormat;
  int64_t bitrate{0};
  int64_t totalSamples{0};
  double durationSeconds{0.0};

  [[nodiscard]] bool isValid() const noexcept {
    return sampleRate >= 8000 && sampleRate <= 384000 && channels > 0 &&
           channels <= 128 && totalSamples >= 0 && !codecName.isEmpty() &&
           codecName != "unknown";
  }

  QVariantMap toVariantMap() const {
    QVariantMap map;
    map["streamIndex"] = streamIndex;
    map["codecName"] = codecName;
    map["sampleRate"] = sampleRate;
    map["channels"] = channels;
    map["channelLayout"] = channelLayout;
    map["sampleFormat"] = sampleFormat;
    map["bitrate"] = static_cast<qint64>(bitrate);
    map["totalSamples"] = static_cast<qint64>(totalSamples);
    map["duration"] = durationSeconds;
    return map;
  }

  static AudioStreamInfo fromVariantMap(const QVariantMap &map) {
    AudioStreamInfo info;
    info.streamIndex = map.value("streamIndex").toInt();
    info.sampleRate = map.value("sampleRate").toInt();
    info.channels = map.value("channels").toInt();
    info.channelLayout = map.value("channelLayout").toString();
    info.sampleFormat = map.value("sampleFormat").toString();
    info.totalSamples = map.value("totalSamples").toLongLong();
    info.codecName = map.value("codecName").toString();
    info.bitrate = map.value("bitrate").toLongLong();
    info.durationSeconds = map.value("duration").toDouble();
    return info;
  }
};

struct MediaMetadata {
  QString filePath;
  int64_t fileSizeBytes{0};
  double durationSeconds{0.0};
  MediaType type{MediaType::Unknown};

  QString formatName;
  QString formatLongName;
  int64_t bitrate{0};
  QString creationTime;

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
      return false;
    }

    return true;
  }

  QVariantMap toVariantMap() const {
    QVariantMap map;

    // 1. Core container & file properties
    map["filePath"] = filePath;
    map["fileSize"] = static_cast<qint64>(fileSizeBytes);
    map["duration"] = durationSeconds;
    map["durationSeconds"] = durationSeconds;
    map["type"] = static_cast<int>(type);
    map["isValid"] = isValid();
    map["hasVideo"] = !videoStreams.empty();
    map["hasAudio"] = !audioStreams.empty();

    // Container probe metadata
    map["formatName"] = formatName;
    map["formatLongName"] = formatLongName;
    map["bitrate"] = static_cast<qint64>(bitrate);
    map["creationTime"] = creationTime;

    // 2. Serialize full video streams list
    QVariantList videoList;
    videoList.reserve(static_cast<qsizetype>(videoStreams.size()));
    for (const auto &vs : videoStreams) {
      videoList.append(vs.toVariantMap());
    }
    map["videoStreams"] = videoList;

    // 3. Serialize full audio streams list
    QVariantList audioList;
    audioList.reserve(static_cast<qsizetype>(audioStreams.size()));
    for (const auto &as : audioStreams) {
      audioList.append(as.toVariantMap());
    }
    map["audioStreams"] = audioList;

    // 4. Flatten Primary Video Stream for direct QML access
    if (!videoStreams.empty()) {
      const auto &vs = videoStreams[0];
      map["videoCodec"] = vs.codecName;
      map["videoCodecLong"] = vs.codecLongName;
      map["width"] = vs.width;
      map["height"] = vs.height;
      map["resolution"] = QString("%1x%2").arg(vs.width).arg(vs.height);
      map["fps"] = vs.frameRate;
      map["pixelFormat"] = vs.pixelFormat;
      map["colorSpace"] = vs.colorSpace;
      map["colorPrimaries"] = vs.colorPrimaries;
      map["colorTransfer"] = vs.colorTransfer;
      map["bitDepth"] = vs.bitDepth;
      map["totalFrames"] = static_cast<qint64>(vs.totalFrames);
    }

    // 5. Flatten Primary Audio Stream for direct QML access
    if (!audioStreams.empty()) {
      const auto &as = audioStreams[0];
      map["audioCodec"] = as.codecName;
      map["sampleRate"] = as.sampleRate;
      map["channels"] = as.channels;
      map["channelLayout"] = as.channelLayout;
      map["audioBitrate"] = static_cast<qint64>(as.bitrate);
    }

    return map;
  }
// };

  // QVariantMap toVariantMap() const {
  //   QVariantMap map;
  //   map["filePath"] = filePath;
  //   map["fileSize"] = static_cast<qint64>(fileSizeBytes);
  //   map["duration"] = durationSeconds;
  //   map["type"] = static_cast<int>(type);
  //   map["isValid"] = isValid();
  //   map["hasVideo"] = !videoStreams.empty();
  //   map["hasAudio"] = !audioStreams.empty();
  //
  //   // Serialize video streams vector
  //   QVariantList videoList;
  //   videoList.reserve(static_cast<qsizetype>(videoStreams.size()));
  //   for (const auto &vs : videoStreams) {
  //     videoList.append(vs.toVariantMap());
  //   }
  //   map["videoStreams"] = videoList;
  //
  //   // Serialize audio streams vector
  //   QVariantList audioList;
  //   audioList.reserve(static_cast<qsizetype>(audioStreams.size()));
  //   for (const auto &as : audioStreams) {
  //     audioList.append(as.toVariantMap());
  //   }
  //   map["audioStreams"] = audioList;
  //
  //   return map;
  // }

  static MediaMetadata fromVariantMap(const QVariantMap &map) {
    MediaMetadata meta;
    meta.filePath = map.value("filePath").toString();
    meta.fileSizeBytes = map.value("fileSize").toLongLong();
    meta.durationSeconds = map.value("duration").toDouble();
    meta.type = static_cast<MediaType>(map.value("type").toInt());

    // Restore container probe metadata
    meta.formatName = map.value("formatName").toString();
    meta.formatLongName = map.value("formatLongName").toString();
    meta.bitrate = map.value("bitrate").toLongLong();
    meta.creationTime = map.value("creationTime").toString();

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
