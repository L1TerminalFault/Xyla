#include "transcodeEngine.hpp"
#include "core/log/logger.hpp"
#include <QDateTime>
#include <QFileInfo>
#include <QStandardPaths>
#include <algorithm>

namespace xyla {

TranscodeEngine::TranscodeEngine(QObject *parent) : QObject(parent) {
  m_running = true;
  m_workerThread = std::thread(&TranscodeEngine::workerLoop, this);
}

TranscodeEngine::~TranscodeEngine() {
  cancelAll();

  if (m_hwDeviceCtx) {
    av_buffer_unref(&m_hwDeviceCtx);
    m_hwDeviceCtx = nullptr;
  }
}

bool TranscodeEngine::initHardwareDevice() {
  if (m_hwDeviceCtx) {
    return m_hwSupported;
  }

#if defined(_WIN32)
  std::vector<AVHWDeviceType> preferredTypes = {
      AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_D3D11VA, AV_HWDEVICE_TYPE_VULKAN};
#elif defined(__APPLE__)
  std::vector<AVHWDeviceType> preferredTypes = {AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
                                                AV_HWDEVICE_TYPE_VULKAN};
#else
  // On Linux, prioritize CUDA on NVIDIA systems to avoid VAAPI timeout
  std::vector<AVHWDeviceType> preferredTypes = {
      AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_VAAPI, AV_HWDEVICE_TYPE_VULKAN};
#endif

  for (auto type : preferredTypes) {
    if (av_hwdevice_ctx_create(&m_hwDeviceCtx, type, nullptr, nullptr, 0) >=
        0) {
      m_hwSupported = true;
      m_hwType = type;
      const char *name = av_hwdevice_get_type_name(type);
      XYLA_LOG_INFO(
          "TranscodeEngine",
          std::string("Hardware accelerated transcode device initialized: ") +
              (name ? name : "UNKNOWN"));
      return true;
    }
  }

  m_hwSupported = false;
  XYLA_LOG_WARN("TranscodeEngine",
                "No supported HW device found. Falling back to CPU transcode.");
  return false;
}

void TranscodeEngine::queueTranscode(const QString &assetId,
                                     const QString &inputPath,
                                     double durationSeconds) {
  QString cacheDir =
      QStandardPaths::writableLocation(QStandardPaths::CacheLocation) +
      "/proxies";
  QDir().mkpath(cacheDir);

  QFileInfo fileInfo(inputPath);
  QString outputPath = cacheDir + "/" + assetId + "_proxy_" +
                       QString::number(QDateTime::currentMSecsSinceEpoch()) +
                       ".mp4";

  TranscodeJob job{assetId, inputPath, outputPath, durationSeconds};

  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    m_jobQueue.enqueue(job);
  }
  m_cv.notify_one();
}

void TranscodeEngine::cancelAll() {
  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    m_jobQueue.clear();
    m_running = false;
  }
  m_cv.notify_all();

  if (m_workerThread.joinable()) {
    m_workerThread.join();
  }
}

void TranscodeEngine::workerLoop() {
  // Asynchronous background hardware device initialization
  initHardwareDevice();

  while (m_running) {
    TranscodeJob job;
    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_cv.wait(lock, [this] { return !m_jobQueue.isEmpty() || !m_running; });

      if (!m_running)
        break;

      job = m_jobQueue.dequeue();
    }

    emit transcodeStarted(job.assetId);

    if (processJob(job)) {
      emit transcodeCompleted(job.assetId, job.outputPath);
    } else {
      emit transcodeFailed(job.assetId, "In-process transcode failed.");
    }
  }
}

bool TranscodeEngine::setupVaapiFramesContext(AVCodecContext *encCtx,
                                              AVBufferRef *hwDeviceCtx,
                                              int width, int height) {
  if (!hwDeviceCtx)
    return false;

  AVBufferRef *hwFramesRef = av_hwframe_ctx_alloc(hwDeviceCtx);
  if (!hwFramesRef) {
    XYLA_LOG_ERROR("TranscodeEngine", "Failed to allocate HW frames context.");
    return false;
  }

  auto *framesCtx = reinterpret_cast<AVHWFramesContext *>(hwFramesRef->data);
  framesCtx->format = AV_PIX_FMT_VAAPI;
  framesCtx->sw_format = AV_PIX_FMT_NV12;
  framesCtx->width = width;
  framesCtx->height = height;
  framesCtx->initial_pool_size = 20;

  int ret = av_hwframe_ctx_init(hwFramesRef);
  if (ret < 0) {
    char errBuf[256];
    av_strerror(ret, errBuf, sizeof(errBuf));
    XYLA_LOG_ERROR("TranscodeEngine",
                   std::string("Failed to initialize HW frames context: ") +
                       errBuf);
    av_buffer_unref(&hwFramesRef);
    return false;
  }

  encCtx->hw_frames_ctx = av_buffer_ref(hwFramesRef);
  av_buffer_unref(&hwFramesRef);
  return true;
}

bool TranscodeEngine::processJob(const TranscodeJob &job) {
  AVFormatContext *inFmtCtx = nullptr;
  if (avformat_open_input(&inFmtCtx, job.inputPath.toUtf8().constData(),
                          nullptr, nullptr) < 0) {
    return false;
  }

  if (avformat_find_stream_info(inFmtCtx, nullptr) < 0) {
    avformat_close_input(&inFmtCtx);
    return false;
  }

  int videoStreamIdx = -1;
  for (unsigned int i = 0; i < inFmtCtx->nb_streams; ++i) {
    if (inFmtCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      videoStreamIdx = static_cast<int>(i);
      break;
    }
  }

  if (videoStreamIdx == -1) {
    avformat_close_input(&inFmtCtx);
    return false;
  }

  AVCodecParameters *inCodecPar = inFmtCtx->streams[videoStreamIdx]->codecpar;
  const AVCodec *decCodec = avcodec_find_decoder(inCodecPar->codec_id);
  if (!decCodec) {
    avformat_close_input(&inFmtCtx);
    return false;
  }

  AVCodecContext *decCtx = avcodec_alloc_context3(decCodec);
  avcodec_parameters_to_context(decCtx, inCodecPar);
  if (avcodec_open2(decCtx, decCodec, nullptr) < 0) {
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmtCtx);
    return false;
  }

  AVFormatContext *outFmtCtx = nullptr;
  avformat_alloc_output_context2(&outFmtCtx, nullptr, nullptr,
                                 job.outputPath.toUtf8().constData());
  if (!outFmtCtx) {
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmtCtx);
    return false;
  }

  const AVCodec *encCodec = nullptr;
  bool useHwEncoder = false;

  if (m_hwSupported && m_hwType == AV_HWDEVICE_TYPE_VAAPI) {
    encCodec = avcodec_find_encoder_by_name("h264_vaapi");
    if (encCodec)
      useHwEncoder = true;
  } else if (m_hwSupported && m_hwType == AV_HWDEVICE_TYPE_CUDA) {
    encCodec = avcodec_find_encoder_by_name("h264_nvenc");
    if (encCodec)
      useHwEncoder = true;
  }

  if (!encCodec) {
    encCodec = avcodec_find_encoder_by_name("libx264");
  }

  if (!encCodec) {
    avformat_free_context(outFmtCtx);
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmtCtx);
    return false;
  }

  AVStream *outStream = avformat_new_stream(outFmtCtx, nullptr);
  AVCodecContext *encCtx = avcodec_alloc_context3(encCodec);

  encCtx->width = decCtx->width;
  encCtx->height = decCtx->height;
  encCtx->time_base = inFmtCtx->streams[videoStreamIdx]->time_base;
  encCtx->framerate =
      av_guess_frame_rate(inFmtCtx, inFmtCtx->streams[videoStreamIdx], nullptr);
  encCtx->gop_size = 1; // Force GOP=1 for frame-accurate timeline scrubbing
  encCtx->max_b_frames = 0;

  if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
    encCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  bool encoderInitialized = false;

  if (useHwEncoder && m_hwType == AV_HWDEVICE_TYPE_VAAPI) {
    encCtx->pix_fmt = AV_PIX_FMT_VAAPI;
    if (setupVaapiFramesContext(encCtx, m_hwDeviceCtx, encCtx->width,
                                encCtx->height)) {
      if (avcodec_open2(encCtx, encCodec, nullptr) >= 0) {
        encoderInitialized = true;
        XYLA_LOG_INFO("TranscodeEngine",
                      "Using VAAPI hardware acceleration for proxy transcode.");
      }
    }
  }

  // Fallback to CPU libx264 if hardware context allocation or open fails
  if (!encoderInitialized) {
    if (encCtx->hw_frames_ctx) {
      av_buffer_unref(&encCtx->hw_frames_ctx);
      encCtx->hw_frames_ctx = nullptr;
    }
    avcodec_free_context(&encCtx);

    encCodec = avcodec_find_encoder_by_name("libx264");
    if (!encCodec) {
      avformat_free_context(outFmtCtx);
      avcodec_free_context(&decCtx);
      avformat_close_input(&inFmtCtx);
      return false;
    }

    encCtx = avcodec_alloc_context3(encCodec);
    encCtx->width = decCtx->width;
    encCtx->height = decCtx->height;
    encCtx->time_base = inFmtCtx->streams[videoStreamIdx]->time_base;
    encCtx->framerate = av_guess_frame_rate(
        inFmtCtx, inFmtCtx->streams[videoStreamIdx], nullptr);
    encCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    encCtx->gop_size = 1;
    encCtx->max_b_frames = 0;

    if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
      encCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    av_opt_set(encCtx->priv_data, "preset", "ultrafast", 0);
    av_opt_set(encCtx->priv_data, "tune", "zerolatency", 0);

    if (avcodec_open2(encCtx, encCodec, nullptr) < 0) {
      avcodec_free_context(&encCtx);
      avformat_free_context(outFmtCtx);
      avcodec_free_context(&decCtx);
      avformat_close_input(&inFmtCtx);
      return false;
    }
  }

  avcodec_parameters_from_context(outStream->codecpar, encCtx);
  outStream->time_base = encCtx->time_base;

  if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE)) {
    if (avio_open(&outFmtCtx->pb, job.outputPath.toUtf8().constData(),
                  AVIO_FLAG_WRITE) < 0) {
      avcodec_free_context(&encCtx);
      avformat_free_context(outFmtCtx);
      avcodec_free_context(&decCtx);
      avformat_close_input(&inFmtCtx);
      return false;
    }
  }

  if (avformat_write_header(outFmtCtx, nullptr) < 0) {
    if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE))
      avio_closep(&outFmtCtx->pb);
    avcodec_free_context(&encCtx);
    avformat_free_context(outFmtCtx);
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmtCtx);
    return false;
  }

  AVPacket *inPacket = av_packet_alloc();
  AVFrame *decodedFrame = av_frame_alloc();
  AVFrame *hwFrame = nullptr;

  if (useHwEncoder && encoderInitialized) {
    hwFrame = av_frame_alloc();
  }

  int64_t totalDurationPts = inFmtCtx->streams[videoStreamIdx]->duration;

  while (av_read_frame(inFmtCtx, inPacket) >= 0) {
    if (inPacket->stream_index == videoStreamIdx) {
      if (avcodec_send_packet(decCtx, inPacket) >= 0) {
        while (avcodec_receive_frame(decCtx, decodedFrame) >= 0) {
          decodedFrame->pict_type = AV_PICTURE_TYPE_NONE;
          decodedFrame->flags &= ~AV_FRAME_FLAG_KEY;

          AVFrame *frameToSend = decodedFrame;

          if (useHwEncoder && encoderInitialized && encCtx->hw_frames_ctx) {
            if (av_hwframe_get_buffer(encCtx->hw_frames_ctx, hwFrame, 0) >= 0) {
              if (av_hwframe_transfer_data(hwFrame, decodedFrame, 0) >= 0) {
                hwFrame->pts = decodedFrame->pts;
                hwFrame->pict_type = AV_PICTURE_TYPE_NONE;
                hwFrame->flags &= ~AV_FRAME_FLAG_KEY;
                frameToSend = hwFrame;
              }
            }
          }

          if (avcodec_send_frame(encCtx, frameToSend) >= 0) {
            AVPacket *outPacket = av_packet_alloc();
            while (avcodec_receive_packet(encCtx, outPacket) >= 0) {
              av_packet_rescale_ts(outPacket, encCtx->time_base,
                                   outStream->time_base);
              outPacket->stream_index = outStream->index;
              av_interleaved_write_frame(outFmtCtx, outPacket);
              av_packet_unref(outPacket);
            }
            av_packet_free(&outPacket);
          }

          if (totalDurationPts > 0) {
            double progress = static_cast<double>(decodedFrame->pts) /
                              static_cast<double>(totalDurationPts);
            emit transcodeProgress(job.assetId, std::clamp(progress, 0.0, 1.0));
          }
        }
      }
    }
    av_packet_unref(inPacket);
  }

  // Flush encoder
  avcodec_send_frame(encCtx, nullptr);
  AVPacket *outPacket = av_packet_alloc();
  while (avcodec_receive_packet(encCtx, outPacket) >= 0) {
    av_packet_rescale_ts(outPacket, encCtx->time_base, outStream->time_base);
    outPacket->stream_index = outStream->index;
    av_interleaved_write_frame(outFmtCtx, outPacket);
    av_packet_unref(outPacket);
  }
  av_packet_free(&outPacket);

  av_write_trailer(outFmtCtx);

  if (hwFrame)
    av_frame_free(&hwFrame);
  av_frame_free(&decodedFrame);
  av_packet_free(&inPacket);

  if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE)) {
    avio_closep(&outFmtCtx->pb);
  }

  avcodec_free_context(&encCtx);
  avformat_free_context(outFmtCtx);
  avcodec_free_context(&decCtx);
  avformat_close_input(&inFmtCtx);

  return true;
}

} // namespace xyla
