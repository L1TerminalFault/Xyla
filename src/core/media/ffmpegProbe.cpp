#include "ffmpegProbe.hpp"
#include "core/log/logger.hpp"
#include <QFileInfo>
#include <memory>

namespace xyla {

namespace {

struct FormatContextDeleter {
  void operator()(AVFormatContext *ctx) const {
    if (ctx) {
      avformat_close_input(&ctx);
    }
  }
};

using ScopedAVFormatContext =
    std::unique_ptr<AVFormatContext, FormatContextDeleter>;

} // namespace

bool FFmpegProbe::probe(const QString &filePath, MediaMetadata &outMetadata) {
  outMetadata = MediaMetadata();
  outMetadata.filePath = filePath;

  QFileInfo fileInfo(filePath);
  if (!fileInfo.exists() || !fileInfo.isFile()) {
    XYLA_LOG_ERROR("FFmpegProbe",
                   "Target file does not exist or is unreadable: " +
                       filePath.toStdString());
    return false;
  }
  outMetadata.fileSizeBytes = fileInfo.size();

  AVFormatContext *rawCtx = nullptr;
  const std::string nativePath = filePath.toStdString();

  AVDictionary *options = nullptr;
  av_dict_set(&options, "probesize", "5000000", 0); // 5MB analysis buffer limit
  av_dict_set(&options, "analyzeduration", "5000000",
              0); // 5 sec max analysis time
  av_dict_set(&options, "formatprobesize", "1048576",
              0); // 1MB format probe max

  int err = avformat_open_input(&rawCtx, nativePath.c_str(), nullptr, &options);
  av_dict_free(&options); // clean up dictionary options

  if (err < 0) {
    char errBuf[AV_ERROR_MAX_STRING_SIZE] = {0};
    av_strerror(err, errBuf, sizeof(errBuf));
    XYLA_LOG_ERROR("FFmpegProbe", "avformat_open_input failed (" +
                                      std::string(errBuf) + "): " + nativePath);
    return false;
  }

  ScopedAVFormatContext fmtCtx(rawCtx);

  // Read media stream information
  if (avformat_find_stream_info(fmtCtx.get(), nullptr) < 0) {
    XYLA_LOG_ERROR("FFmpegProbe",
                   "Failed to resolve stream metadata: " + nativePath);
    return false;
  }

  if (fmtCtx->duration != AV_NOPTS_VALUE) {
    outMetadata.durationSeconds =
        static_cast<double>(fmtCtx->duration) / AV_TIME_BASE;
  }

  for (unsigned int i = 0; i < fmtCtx->nb_streams; ++i) {
    const AVStream *stream = fmtCtx->streams[i];
    const AVCodecParameters *codecPar = stream->codecpar;

    if (codecPar->codec_type == AVMEDIA_TYPE_VIDEO) {
      // Ignore embedded album art / cover thumbnails on audio files
      if (stream->disposition & AV_DISPOSITION_ATTACHED_PIC) {
        continue;
      }

      VideoStreamInfo vInfo;
      vInfo.width = codecPar->width;
      vInfo.height = codecPar->height;

      // Frame rate extraction (prefer avg_frame_rate, fall back to
      // r_frame_rate)
      AVRational fps = stream->avg_frame_rate.num > 0 ? stream->avg_frame_rate
                                                      : stream->r_frame_rate;
      if (fps.den > 0 && fps.num > 0) {
        vInfo.frameRate = av_q2d(fps);
      } else {
        vInfo.frameRate =
            30.0; // Standard nominal fallback if completely unstated
      }

      // Total frame count calculation
      if (stream->nb_frames > 0) {
        vInfo.totalFrames = stream->nb_frames;
      } else if (vInfo.frameRate > 0.0 && outMetadata.durationSeconds > 0.0) {
        vInfo.totalFrames =
            static_cast<int64_t>(outMetadata.durationSeconds * vInfo.frameRate);
      }

      // Codec Name & Pixel Format
      const char *cName = avcodec_get_name(codecPar->codec_id);
      vInfo.codecName = cName ? QString(cName) : "unknown";

      const char *pFmt =
          av_get_pix_fmt_name(static_cast<AVPixelFormat>(codecPar->format));
      vInfo.pixelFormat = pFmt ? QString(pFmt) : "unknown";

      outMetadata.videoStreams.push_back(vInfo);

    } else if (codecPar->codec_type == AVMEDIA_TYPE_AUDIO) {
      AudioStreamInfo aInfo;
      aInfo.sampleRate = codecPar->sample_rate;
      int channels = 0;
#if LIBAVCODEC_VERSION_INT >= AV_VERSION_INT(59, 24, 100)
      channels = codecPar->ch_layout.nb_channels;
#else
      // older ffmpeg versions
      channels = codecPar->channels;
#endif
      // Defensive fallback if header reports 0 channels
      if (channels <= 0 &&
          codecPar->ch_layout.order != AV_CHANNEL_ORDER_UNSPEC) {
        channels = codecPar->ch_layout.nb_channels;
      }
      aInfo.channels = std::max(1, channels);

      // Total samples calculation
      if (stream->duration != AV_NOPTS_VALUE) {
        aInfo.totalSamples = av_rescale_q(stream->duration, stream->time_base,
                                          AVRational{1, aInfo.sampleRate});
      } else if (outMetadata.durationSeconds > 0.0) {
        aInfo.totalSamples = static_cast<int64_t>(outMetadata.durationSeconds *
                                                  aInfo.sampleRate);
      }

      const char *cName = avcodec_get_name(codecPar->codec_id);
      aInfo.codecName = cName ? QString(cName) : "unknown";

      const char *sFmt =
          av_get_sample_fmt_name(static_cast<AVSampleFormat>(codecPar->format));
      aInfo.sampleFormat = sFmt ? QString(sFmt) : "unknown";

      outMetadata.audioStreams.push_back(aInfo);
    }
  }

  if (!outMetadata.videoStreams.empty()) {
    outMetadata.type = MediaType::Video;
  } else if (!outMetadata.audioStreams.empty()) {
    outMetadata.type = MediaType::Audio;
  }

  return outMetadata.isValid();
}

} // namespace xyla
