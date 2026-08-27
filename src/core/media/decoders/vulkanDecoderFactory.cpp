#include "vulkanDecoderFactory.hpp"
#include "core/log/logger.hpp"
#include <algorithm>
#include <cmath>
#include <vector>

namespace xyla {

namespace {

// Dynamically matches pixel format to the active AVHWDeviceContext
static enum AVPixelFormat get_hw_format(AVCodecContext *ctx,
                                        const enum AVPixelFormat *pix_fmts) {
  AVHWDeviceType targetHWType = AV_HWDEVICE_TYPE_NONE;
  if (ctx && ctx->hw_device_ctx && ctx->hw_device_ctx->data) {
    auto *hwctx =
        reinterpret_cast<AVHWDeviceContext *>(ctx->hw_device_ctx->data);
    targetHWType = hwctx->type;
  }

  AVPixelFormat expectedFormat = AV_PIX_FMT_NONE;
  if (targetHWType == AV_HWDEVICE_TYPE_CUDA)
    expectedFormat = AV_PIX_FMT_CUDA;
  else if (targetHWType == AV_HWDEVICE_TYPE_VULKAN)
    expectedFormat = AV_PIX_FMT_VULKAN;
  else if (targetHWType == AV_HWDEVICE_TYPE_VAAPI)
    expectedFormat = AV_PIX_FMT_VAAPI;
  else if (targetHWType == AV_HWDEVICE_TYPE_D3D11VA)
    expectedFormat = AV_PIX_FMT_D3D11;

  for (const enum AVPixelFormat *p = pix_fmts; *p != -1; p++) {
    if (expectedFormat != AV_PIX_FMT_NONE && *p == expectedFormat) {
      return *p;
    }
  }

  return pix_fmts[0]; // Default fallback
}

} // namespace

VulkanVideoDecoder::~VulkanVideoDecoder() { close(); }

bool VulkanVideoDecoder::initHWContext(AVCodecID codecId) {
  Q_UNUSED(codecId);

#if defined(_WIN32)
  std::vector<AVHWDeviceType> preferredBackends = {
      AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_D3D11VA, AV_HWDEVICE_TYPE_VULKAN};
#elif defined(__APPLE__)
  std::vector<AVHWDeviceType> preferredBackends = {
      AV_HWDEVICE_TYPE_VIDEOTOOLBOX, AV_HWDEVICE_TYPE_VULKAN};
#else
  std::vector<AVHWDeviceType> preferredBackends = {
      AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_VAAPI, AV_HWDEVICE_TYPE_VULKAN};
#endif

  for (auto backend : preferredBackends) {
    if (av_hwdevice_ctx_create(&m_hwDeviceCtx, backend, nullptr, nullptr, 0) >=
        0) {
      XYLA_LOG_INFO("VulkanDecoder",
                    std::string("Initialized HW decode backend: ") +
                        av_hwdevice_get_type_name(backend));
      m_isHwAccelerated = true;
      return true;
    }
  }

  m_isHwAccelerated = false;
  return false;
}

bool VulkanVideoDecoder::open(const QString &filePath) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  if (m_isOpen.load(std::memory_order_relaxed)) {
    close();
  }

  const std::string nativePath = filePath.toStdString();
  if (avformat_open_input(&m_fmtCtx, nativePath.c_str(), nullptr, nullptr) <
      0) {
    return false;
  }

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

  m_codecCtx = avcodec_alloc_context3(decoder);
  if (!m_codecCtx) {
    close();
    return false;
  }

  if (avcodec_parameters_to_context(m_codecCtx, videoStream->codecpar) < 0) {
    close();
    return false;
  }

  m_codecCtx->thread_count =
      std::min(8, static_cast<int>(std::thread::hardware_concurrency()));
  m_codecCtx->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
  m_codecCtx->get_format = get_hw_format;

  if (initHWContext(videoStream->codecpar->codec_id) && m_hwDeviceCtx) {
    m_codecCtx->hw_device_ctx = av_buffer_ref(m_hwDeviceCtx);
  }

  if (avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
    if (m_codecCtx->hw_device_ctx) {
      av_buffer_unref(&m_codecCtx->hw_device_ctx);
    }
    const AVCodec *swFallback =
        avcodec_find_decoder(videoStream->codecpar->codec_id);
    if (!swFallback || avcodec_open2(m_codecCtx, swFallback, nullptr) < 0) {
      close();
      return false;
    }
  }

  AVRational rate = videoStream->avg_frame_rate;
  if (rate.num == 0 || rate.den == 0) {
    rate = videoStream->r_frame_rate;
  }
  m_nativeFps.store((rate.num > 0 && rate.den > 0) ? av_q2d(rate) : 30.0,
                    std::memory_order_relaxed);

  m_hwFrame = av_frame_alloc();
  m_swFrame = av_frame_alloc();
  m_packet = av_packet_alloc();

  m_isOpen.store(true, std::memory_order_relaxed);

  // Prime frame 0
  if (decodeNextFrameInternal()) {
    m_currentFrameIndex.store(0, std::memory_order_relaxed);
  } else {
    m_currentFrameIndex.store(-1, std::memory_order_relaxed);
  }

  return true;
}

bool VulkanVideoDecoder::decodeNextFrameInternal() {
  if (!m_isOpen.load(std::memory_order_relaxed))
    return false;

  int ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
  if (ret == 0) {
    if (m_hwFrame->format == AV_PIX_FMT_VULKAN) {
      return true;
    }

    av_frame_unref(m_swFrame);
    if (m_hwFrame->hw_frames_ctx != nullptr ||
        m_hwFrame->format == AV_PIX_FMT_CUDA) {
      if (av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0) < 0) {
        return false;
      }
      m_swFrame->pts = m_hwFrame->pts;
      m_swFrame->best_effort_timestamp = m_hwFrame->best_effort_timestamp;
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
        if (m_hwFrame->format == AV_PIX_FMT_VULKAN) {
          return true;
        }

        av_frame_unref(m_swFrame);
        if (m_hwFrame->hw_frames_ctx != nullptr ||
            m_hwFrame->format == AV_PIX_FMT_CUDA) {
          if (av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0) < 0) {
            return false;
          }
          m_swFrame->pts = m_hwFrame->pts;
          m_swFrame->best_effort_timestamp = m_hwFrame->best_effort_timestamp;
        } else {
          av_frame_move_ref(m_swFrame, m_hwFrame);
        }
        return true;
      }
    } else {
      av_packet_unref(m_packet);
    }
  }

  return false;
}

bool VulkanVideoDecoder::decodeNextFrame() {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  bool ok = decodeNextFrameInternal();
  if (ok) {
    m_currentFrameIndex.fetch_add(1, std::memory_order_relaxed);
  }
  return ok;
}

bool VulkanVideoDecoder::seekToFrame(int64_t frameIndex, double fps) {
  return seekToFrame(frameIndex, /*precise=*/true, fps);
}

bool VulkanVideoDecoder::seekToFrame(int64_t frameIndex, bool precise,
                                     double fps) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed) || m_videoStreamIndex < 0) {
    return false;
  }

  int64_t current = m_currentFrameIndex.load(std::memory_order_relaxed);

  if (frameIndex == current &&
      ((m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN) ||
       (m_swFrame && m_swFrame->data[0]))) {
    return true;
  }

  if (frameIndex > current && frameIndex <= current + 15) {
    while (m_currentFrameIndex.load(std::memory_order_relaxed) < frameIndex) {
      if (!decodeNextFrameInternal())
        break;
      m_currentFrameIndex.fetch_add(1, std::memory_order_relaxed);
    }
    return true;
  }

  if (frameIndex < current && frameIndex >= current - 5) {
    return true;
  }

  AVStream *st = m_fmtCtx->streams[m_videoStreamIndex];
  double streamFps = m_nativeFps.load(std::memory_order_relaxed);
  if (streamFps <= 0.0)
    streamFps = (fps > 0.0) ? fps : 30.0;

  double timeSeconds = static_cast<double>(frameIndex) / streamFps;
  int64_t targetPts =
      (st && st->time_base.den > 0)
          ? static_cast<int64_t>(timeSeconds / av_q2d(st->time_base))
          : static_cast<int64_t>(timeSeconds * AV_TIME_BASE);

  av_seek_frame(m_fmtCtx, m_videoStreamIndex, targetPts, AVSEEK_FLAG_BACKWARD);
  avcodec_flush_buffers(m_codecCtx);

  if (!precise) {
    if (decodeNextFrameInternal()) {
      int64_t rawPts = (m_hwFrame->pts != AV_NOPTS_VALUE)
                           ? m_hwFrame->pts
                           : m_hwFrame->best_effort_timestamp;
      int64_t decodedIdx = frameIndex;
      if (rawPts != AV_NOPTS_VALUE && st && st->time_base.den > 0) {
        decodedIdx = static_cast<int64_t>(
            std::round(av_q2d(st->time_base) * rawPts * streamFps));
      }
      m_currentFrameIndex.store(decodedIdx, std::memory_order_relaxed);
      return true;
    }
    return false;
  }

  int decodeAttempts = 60;
  while (decodeAttempts-- > 0 && decodeNextFrameInternal()) {
    int64_t rawPts = (m_swFrame->pts != AV_NOPTS_VALUE)
                         ? m_swFrame->pts
                         : m_swFrame->best_effort_timestamp;

    int64_t decodedIdx = frameIndex;
    if (rawPts != AV_NOPTS_VALUE && st && st->time_base.den > 0) {
      decodedIdx = static_cast<int64_t>(
          std::round(av_q2d(st->time_base) * rawPts * streamFps));
    }

    if (decodedIdx >= frameIndex) {
      m_currentFrameIndex.store(decodedIdx, std::memory_order_relaxed);
      return true;
    }
  }

  m_currentFrameIndex.store(frameIndex, std::memory_order_relaxed);
  return true;
}

VkImage VulkanVideoDecoder::getDecodedVkImage() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed) || !m_hwFrame)
    return VK_NULL_HANDLE;

  if (m_hwFrame->format == AV_PIX_FMT_VULKAN && m_hwFrame->data[0]) {
    auto *vkFrame = reinterpret_cast<AVVkFrame *>(m_hwFrame->data[0]);
    return vkFrame ? vkFrame->img[0] : VK_NULL_HANDLE;
  }
  return VK_NULL_HANDLE;
}

AVFrame *VulkanVideoDecoder::currentFrame() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed)) {
    return nullptr;
  }
  if (m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN) {
    return m_hwFrame;
  }
  return (m_swFrame && m_swFrame->data[0]) ? m_swFrame : nullptr;
}

void VulkanVideoDecoder::close() {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  m_isOpen.store(false, std::memory_order_relaxed);

  if (m_packet)
    av_packet_free(&m_packet);
  if (m_hwFrame)
    av_frame_free(&m_hwFrame);
  if (m_swFrame)
    av_frame_free(&m_swFrame);
  if (m_codecCtx)
    avcodec_free_context(&m_codecCtx);
  if (m_fmtCtx)
    avformat_close_input(&m_fmtCtx);
  if (m_hwDeviceCtx)
    av_buffer_unref(&m_hwDeviceCtx);

  m_videoStreamIndex = -1;
  m_currentFrameIndex.store(-1, std::memory_order_relaxed);
}

DecoderScore VulkanDecoderFactory::evaluate(const MediaMetadata &meta) {
  if (!meta.isValid())
    return DecoderScore::invalid();
  if (meta.type == MediaType::Video && !meta.videoStreams.empty()) {
    return DecoderScore{100, true, true, "Vulkan Zero-Copy Hardware Decoder"};
  }
  return DecoderScore::invalid();
}

std::unique_ptr<IDecoder>
VulkanDecoderFactory::createDecoder(const MediaMetadata &meta) {
  if (!meta.isValid())
    return nullptr;
  return std::make_unique<VulkanVideoDecoder>();
}

} // namespace xyla
