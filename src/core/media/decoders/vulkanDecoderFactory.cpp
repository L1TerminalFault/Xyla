#include "vulkanDecoderFactory.hpp"
#include "core/log/logger.hpp"
#include <QImage>
#include <cmath>
#include <vector>

namespace xyla {

namespace {

static enum AVPixelFormat get_hw_format(AVCodecContext *ctx,
                                        const enum AVPixelFormat *pix_fmts) {
  Q_UNUSED(ctx);
  const enum AVPixelFormat *p;
  for (p = pix_fmts; *p != -1; p++) {
    if (*p == AV_PIX_FMT_CUDA || *p == AV_PIX_FMT_VAAPI ||
        *p == AV_PIX_FMT_D3D11 || *p == AV_PIX_FMT_VIDEOTOOLBOX ||
        *p == AV_PIX_FMT_VULKAN) {
      return *p;
    }
  }
  return pix_fmts[0];
}

} // namespace

VulkanVideoDecoder::~VulkanVideoDecoder() { close(); }

bool VulkanVideoDecoder::initVulkanHWContext() {
  av_log_set_level(AV_LOG_QUIET);

  std::vector<AVHWDeviceType> targetBackends = {
      AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_VAAPI, AV_HWDEVICE_TYPE_D3D11VA,
      AV_HWDEVICE_TYPE_VIDEOTOOLBOX, AV_HWDEVICE_TYPE_VULKAN};

  for (auto backend : targetBackends) {
    int err =
        av_hwdevice_ctx_create(&m_hwDeviceCtx, backend, nullptr, nullptr, 0);
    if (err >= 0) {
      const char *name = av_hwdevice_get_type_name(backend);
      XYLA_LOG_INFO("VulkanDecoder",
                    std::string("Initialized GPU hardware decode engine: ") +
                        name);
      return true;
    }
  }

  XYLA_LOG_WARN(
      "VulkanDecoder",
      "No hardware decode backend available. Using software fallback.");
  return false;
}

bool VulkanVideoDecoder::open(const QString &filePath) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  if (m_isOpen) {
    close();
  }

  const std::string nativePath = filePath.toStdString();

  if (avformat_open_input(&m_fmtCtx, nativePath.c_str(), nullptr, nullptr) < 0)
    return false;

  if (avformat_find_stream_info(m_fmtCtx, nullptr) < 0) {
    close();
    return false;
  }

  const AVCodec *decoder = nullptr;
  m_videoStreamIndex =
      av_find_best_stream(m_fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);

  if (m_videoStreamIndex < 0 || !decoder) {
    close();
    return false;
  }

  AVStream *videoStream = m_fmtCtx->streams[m_videoStreamIndex];

  const AVCodec *hwCodec = nullptr;
  if (videoStream->codecpar->codec_id == AV_CODEC_ID_H264) {
    hwCodec = avcodec_find_decoder_by_name("h264_cuvid");
  } else if (videoStream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
    hwCodec = avcodec_find_decoder_by_name("hevc_cuvid");
  } else if (videoStream->codecpar->codec_id == AV_CODEC_ID_AV1) {
    hwCodec = avcodec_find_decoder_by_name("av1_cuvid");
  }

  if (hwCodec) {
    decoder = hwCodec;
    XYLA_LOG_INFO("VulkanDecoder",
                  std::string("Using direct NVIDIA NVDEC decoder: ") +
                      decoder->name);
  }

  AVRational rate = videoStream->avg_frame_rate;
  if (rate.num == 0 || rate.den == 0) {
    rate = videoStream->r_frame_rate;
  }
  m_nativeFps.store((rate.num > 0 && rate.den > 0) ? av_q2d(rate) : 30.0);

  m_codecCtx = avcodec_alloc_context3(decoder);
  if (!m_codecCtx) {
    close();
    return false;
  }

  if (avcodec_parameters_to_context(m_codecCtx, videoStream->codecpar) < 0) {
    close();
    return false;
  }

  m_codecCtx->thread_count = 0;
  m_codecCtx->get_format = get_hw_format;

  if (initVulkanHWContext() && m_hwDeviceCtx) {
    m_codecCtx->hw_device_ctx = av_buffer_ref(m_hwDeviceCtx);
  }

  if (avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
    if (m_codecCtx->hw_device_ctx) {
      av_buffer_unref(&m_codecCtx->hw_device_ctx);
    }
    const AVCodec *swFallback =
        avcodec_find_decoder(videoStream->codecpar->codec_id);
    if (avcodec_open2(m_codecCtx, swFallback, nullptr) < 0) {
      XYLA_LOG_ERROR("VulkanDecoder",
                     "Failed to open codec context for: " + nativePath);
      close();
      return false;
    }
  }

  m_hwFrame = av_frame_alloc();
  m_swFrame = av_frame_alloc();
  m_nv12Frame = av_frame_alloc();
  m_packet = av_packet_alloc();

  m_isOpen = true;
  m_currentFrameIndex.store(-1);
  m_gopStartFrame = -1;
  m_gopEndFrame = -1;
  return true;
}

void VulkanVideoDecoder::evictGopCache(int64_t targetFrame,
                                       size_t maxCapacity) {
  while (m_gopCache.size() > maxCapacity) {
    int64_t farthestKey = -1;
    int64_t maxDist = -1;

    for (const auto &[frameIdx, img] : m_gopCache) {
      int64_t dist = std::abs(frameIdx - targetFrame);
      if (dist > maxDist) {
        maxDist = dist;
        farthestKey = frameIdx;
      }
    }

    if (farthestKey != -1) {
      m_gopCache.erase(farthestKey);
    } else {
      break;
    }
  }
}

bool VulkanVideoDecoder::decodeNextFrameInternal() {
  if (!m_isOpen)
    return false;

  int ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
  if (ret == 0) {
    av_frame_unref(m_swFrame);
    if (m_hwFrame->hw_frames_ctx != nullptr ||
        m_hwFrame->format == AV_PIX_FMT_CUDA) {
      av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0);
      m_swFrame->pts = m_hwFrame->pts;
      m_swFrame->pkt_dts = m_hwFrame->pkt_dts;
    } else {
      av_frame_move_ref(m_swFrame, m_hwFrame);
    }
    return true;
  }

  while (av_read_frame(m_fmtCtx, m_packet) >= 0) {
    if (m_packet->stream_index == m_videoStreamIndex) {
      ret = avcodec_send_packet(m_codecCtx, m_packet);
      av_packet_unref(m_packet);

      if (ret < 0 && ret != AVERROR(EAGAIN)) {
        av_frame_unref(m_hwFrame);
        av_frame_unref(m_swFrame);
        avcodec_flush_buffers(m_codecCtx);
        return false;
      }

      ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
      if (ret == 0) {
        av_frame_unref(m_swFrame);
        if (m_hwFrame->hw_frames_ctx != nullptr ||
            m_hwFrame->format == AV_PIX_FMT_CUDA) {
          av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0);
          m_swFrame->pts = m_hwFrame->pts;
          m_swFrame->pkt_dts = m_hwFrame->pkt_dts;
        } else {
          av_frame_move_ref(m_swFrame, m_hwFrame);
        }
        return true;
      }
    } else {
      av_packet_unref(m_packet);
    }
  }

  avcodec_send_packet(m_codecCtx, nullptr);
  if (avcodec_receive_frame(m_codecCtx, m_hwFrame) == 0) {
    av_frame_unref(m_swFrame);
    if (m_hwFrame->hw_frames_ctx != nullptr ||
        m_hwFrame->format == AV_PIX_FMT_CUDA) {
      av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0);
      m_swFrame->pts = m_hwFrame->pts;
      m_swFrame->pkt_dts = m_hwFrame->pkt_dts;
    } else {
      av_frame_move_ref(m_swFrame, m_hwFrame);
    }
    return true;
  }

  return false;
}

bool VulkanVideoDecoder::decodeNextFrame() {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  bool ok = decodeNextFrameInternal();
  if (ok) {
    m_currentFrameIndex.fetch_add(1);
  }
  return ok;
}

void VulkanVideoDecoder::close() {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  m_gopCache.clear();

  if (m_swsCtx) {
    sws_freeContext(m_swsCtx);
    m_swsCtx = nullptr;
  }

  if (m_nv12SwsCtx) {
    sws_freeContext(m_nv12SwsCtx);
    m_nv12SwsCtx = nullptr;
  }

  if (m_packet)
    av_packet_free(&m_packet);
  if (m_hwFrame)
    av_frame_free(&m_hwFrame);
  if (m_swFrame)
    av_frame_free(&m_swFrame);
  if (m_nv12Frame)
    av_frame_free(&m_nv12Frame);
  if (m_codecCtx)
    avcodec_free_context(&m_codecCtx);
  if (m_fmtCtx)
    avformat_close_input(&m_fmtCtx);
  if (m_hwDeviceCtx)
    av_buffer_unref(&m_hwDeviceCtx);

  m_videoStreamIndex = -1;
  m_currentFrameIndex.store(-1);
  m_isOpen = false;
}

DecoderScore VulkanDecoderFactory::evaluate(const MediaMetadata &meta) {
  if (!meta.isValid()) {
    return DecoderScore::invalid();
  }

  if (meta.type == MediaType::Video && !meta.videoStreams.empty()) {
    return DecoderScore{
        95, true, true,
        "Vulkan Zero-Copy Hardware Decoder (VK_KHR_video_decode)"};
  }

  return DecoderScore::invalid();
}

std::unique_ptr<IDecoder>
VulkanDecoderFactory::createDecoder(const MediaMetadata &meta) {
  if (!meta.isValid())
    return nullptr;
  return std::make_unique<VulkanVideoDecoder>();
}

bool VulkanVideoDecoder::seekToFrame(int64_t frameIndex, double fps) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen || m_videoStreamIndex < 0) {
    return false;
  }

  m_requestedFrame.store(frameIndex);

  if (m_gopCache.count(frameIndex)) {
    m_currentFrameIndex.store(frameIndex);
    return true;
  }

  if (frameIndex == m_currentFrameIndex.load() && m_swFrame &&
      m_swFrame->data[0]) {
    return true;
  }

  if (frameIndex > m_currentFrameIndex.load() &&
      frameIndex <= m_currentFrameIndex.load() + 15) {
    while (m_currentFrameIndex.load() < frameIndex) {
      if (m_requestedFrame.load() != frameIndex) {
        return false;
      }
      if (!decodeNextFrameInternal()) {
        break;
      }
      m_currentFrameIndex.fetch_add(1);
    }
    return (m_currentFrameIndex.load() == frameIndex);
  }

  AVStream *st = m_fmtCtx->streams[m_videoStreamIndex];
  double streamFps = (m_nativeFps.load() > 0.0) ? m_nativeFps.load()
                                                : (fps > 0.0 ? fps : 30.0);

  int64_t seekTargetFrame = (frameIndex < m_currentFrameIndex.load())
                                ? std::max<int64_t>(0, frameIndex - 15)
                                : frameIndex;

  double timeSeconds = static_cast<double>(seekTargetFrame) / streamFps;

  int64_t targetPts = AV_NOPTS_VALUE;
  if (st && st->time_base.den > 0) {
    targetPts = static_cast<int64_t>(timeSeconds / av_q2d(st->time_base));
  } else {
    targetPts = static_cast<int64_t>(timeSeconds * AV_TIME_BASE);
  }

  if (m_hwFrame)
    av_frame_unref(m_hwFrame);
  if (m_swFrame)
    av_frame_unref(m_swFrame);
  if (m_packet)
    av_packet_unref(m_packet);

  av_seek_frame(m_fmtCtx, m_videoStreamIndex, targetPts, AVSEEK_FLAG_BACKWARD);
  avcodec_flush_buffers(m_codecCtx);

  int maxDecodeAttempts = 120;
  bool targetReached = false;

  while (maxDecodeAttempts-- > 0 && decodeNextFrameInternal()) {
    if (m_requestedFrame.load() != frameIndex) {
      return false;
    }

    int64_t rawPts = m_hwFrame->pts != AV_NOPTS_VALUE
                         ? m_hwFrame->pts
                         : (m_swFrame->pts != AV_NOPTS_VALUE
                                ? m_swFrame->pts
                                : m_swFrame->best_effort_timestamp);

    int64_t actualDecodedIndex = seekTargetFrame;
    if (rawPts != AV_NOPTS_VALUE && st && st->time_base.den > 0) {
      double frameSec = av_q2d(st->time_base) * rawPts;
      actualDecodedIndex =
          static_cast<int64_t>(std::round(frameSec * streamFps));
    }

    if (actualDecodedIndex >= frameIndex) {
      m_currentFrameIndex.store(frameIndex);
      targetReached = true;
      break;
    }
  }

  m_currentFrameIndex.store(frameIndex);
  return targetReached || (m_swFrame && m_swFrame->data[0]);
}

QImage VulkanVideoDecoder::getDecodedQImage() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return QImage();

  int64_t curIdx = m_currentFrameIndex.load();
  if (m_gopCache.count(curIdx)) {
    return m_gopCache[curIdx];
  }

  if (!m_swFrame || !m_swFrame->data[0] || m_swFrame->width <= 0 ||
      m_swFrame->height <= 0) {
    return QImage();
  }

  int w = m_swFrame->width;
  int h = m_swFrame->height;

  AVPixelFormat swFormat = static_cast<AVPixelFormat>(m_swFrame->format);
  if (swFormat == AV_PIX_FMT_NONE || swFormat == AV_PIX_FMT_CUDA) {
    swFormat = (m_codecCtx && m_codecCtx->pix_fmt != AV_PIX_FMT_NONE)
                   ? m_codecCtx->pix_fmt
                   : AV_PIX_FMT_NV12;
  }

  m_swsCtx =
      sws_getCachedContext(m_swsCtx, w, h, swFormat, w, h, AV_PIX_FMT_RGBA,
                           SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);

  if (!m_swsCtx)
    return QImage();

  QImage rgbaImg(w, h, QImage::Format_RGBA8888);
  uint8_t *dest[4] = {rgbaImg.bits(), nullptr, nullptr, nullptr};
  int destLinesize[4] = {static_cast<int>(rgbaImg.bytesPerLine()), 0, 0, 0};

  int res = sws_scale(m_swsCtx, m_swFrame->data, m_swFrame->linesize, 0, h,
                      dest, destLinesize);
  if (res <= 0)
    return QImage();

  return rgbaImg;
}

VkImage VulkanVideoDecoder::getDecodedVkImage() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return VK_NULL_HANDLE;

  if (m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN &&
      m_hwFrame->data[0]) {
    auto *vkFrame = reinterpret_cast<AVVkFrame *>(m_hwFrame->data[0]);
    return vkFrame ? vkFrame->img[0] : VK_NULL_HANDLE;
  }

  return VK_NULL_HANDLE;
}

AVFrame *VulkanVideoDecoder::currentFrame() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen || !m_swFrame || !m_swFrame->data[0])
    return nullptr;

  if (m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN)
    return m_hwFrame;

  if (m_swFrame->format == AV_PIX_FMT_NV12) {
    return m_swFrame;
  }

  int w = m_swFrame->width;
  int h = m_swFrame->height;
  AVPixelFormat srcFmt = static_cast<AVPixelFormat>(m_swFrame->format);

  if (!m_nv12Frame) {
    m_nv12Frame = av_frame_alloc();
  }

  if (m_nv12Frame->width != w || m_nv12Frame->height != h ||
      m_nv12Frame->format != AV_PIX_FMT_NV12) {
    av_frame_unref(m_nv12Frame);
    m_nv12Frame->width = w;
    m_nv12Frame->height = h;
    m_nv12Frame->format = AV_PIX_FMT_NV12;
    av_frame_get_buffer(m_nv12Frame, 32);
  }

  m_nv12SwsCtx =
      sws_getCachedContext(m_nv12SwsCtx, w, h, srcFmt, w, h, AV_PIX_FMT_NV12,
                           SWS_POINT, nullptr, nullptr, nullptr);

  if (m_nv12SwsCtx) {
    sws_scale(m_nv12SwsCtx, m_swFrame->data, m_swFrame->linesize, 0, h,
              m_nv12Frame->data, m_nv12Frame->linesize);
    m_nv12Frame->pts = m_swFrame->pts;
    return m_nv12Frame;
  }

  return m_swFrame;
}

} // namespace xyla
