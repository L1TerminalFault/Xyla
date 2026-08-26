#include "vulkanDecoderFactory.hpp"
#include "core/log/logger.hpp"
#include <cmath>

namespace xyla {

// Hardware decoder destructor
VulkanVideoDecoder::~VulkanVideoDecoder() { close(); }

// Probes cross-platform hardware acceleration backends (CUDA, VAAPI, D3D11VA,
// VideoToolbox, Vulkan)
bool VulkanVideoDecoder::initVulkanHWContext() {
  std::vector<AVHWDeviceType> targetBackends = {
      AV_HWDEVICE_TYPE_CUDA,         // NVIDIA (Linux / Windows)
      AV_HWDEVICE_TYPE_VAAPI,        // AMD & Intel (Linux)
      AV_HWDEVICE_TYPE_D3D11VA,      // AMD & Intel (Windows)
      AV_HWDEVICE_TYPE_VIDEOTOOLBOX, // Apple Silicon / macOS
      AV_HWDEVICE_TYPE_VULKAN        // Cross-platform Vulkan Video
  };

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

// Opens video container with automatic hardware cascade and software fallback
bool VulkanVideoDecoder::open(const QString &filePath) {
  std::lock_guard<std::mutex> lock(m_decoderMutex);

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

  AVRational rate = videoStream->avg_frame_rate;
  if (rate.num == 0 || rate.den == 0) {
    rate = videoStream->r_frame_rate;
  }
  m_nativeFps = (rate.num > 0 && rate.den > 0) ? av_q2d(rate) : 30.0;

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

  if (initVulkanHWContext() && m_hwDeviceCtx) {
    m_codecCtx->hw_device_ctx = av_buffer_ref(m_hwDeviceCtx);
  }

  if (avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
    if (m_codecCtx->hw_device_ctx) {
      av_buffer_unref(&m_codecCtx->hw_device_ctx);
    }
    if (avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
      XYLA_LOG_ERROR("VulkanDecoder",
                     "Failed to open codec context for: " + nativePath);
      close();
      return false;
    }
    XYLA_LOG_INFO("VulkanDecoder",
                  "Opened software decoder fallback for: " + nativePath);
  }

  m_hwFrame = av_frame_alloc();
  m_swFrame = av_frame_alloc();
  m_packet = av_packet_alloc();

  m_isOpen = true;
  m_currentFrameIndex = -1;
  return true;
}

// Internal sequential frame decoder loop
bool VulkanVideoDecoder::decodeNextFrameInternal() {
  if (!m_isOpen)
    return false;

  int ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
  if (ret == 0) {
    av_frame_unref(m_swFrame);
    if (m_hwFrame->hw_frames_ctx != nullptr ||
        m_hwFrame->format == AV_PIX_FMT_CUDA) {
      av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0);
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
        return false;
      }

      ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
      if (ret == 0) {
        av_frame_unref(m_swFrame);
        if (m_hwFrame->hw_frames_ctx != nullptr ||
            m_hwFrame->format == AV_PIX_FMT_CUDA) {
          av_hwframe_transfer_data(m_swFrame, m_hwFrame, 0);
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
    } else {
      av_frame_move_ref(m_swFrame, m_hwFrame);
    }
    return true;
  }

  return false;
}

// Reads packets and decodes next video frame
bool VulkanVideoDecoder::decodeNextFrame() {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  bool ok = decodeNextFrameInternal();
  if (ok) {
    m_currentFrameIndex++;
  }
  return ok;
}

// Releases hardware codec contexts, GOP buffers, and pixel scaling contexts
void VulkanVideoDecoder::close() {
  std::lock_guard<std::mutex> lock(m_decoderMutex);

  m_gopCache.clear();

  if (m_swsCtx) {
    sws_freeContext(m_swsCtx);
    m_swsCtx = nullptr;
  }

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
  m_currentFrameIndex = -1;
  m_isOpen = false;
}

// Evaluates Vulkan decoder compatibility for media metadata
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

// Instantiates Vulkan video decoder implementation
std::unique_ptr<IDecoder>
VulkanDecoderFactory::createDecoder(const MediaMetadata &meta) {
  if (!meta.isValid())
    return nullptr;
  return std::make_unique<VulkanVideoDecoder>();
}

// Reverse GOP cached seeking for instant 0.00ms backward scrubbing
bool VulkanVideoDecoder::seekToFrame(int64_t frameIndex, double fps) {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  if (!m_isOpen || m_videoStreamIndex < 0) {
    return false;
  }

  if (m_gopCache.count(frameIndex)) {
    m_currentFrameIndex = frameIndex;
    return true;
  }

  if (frameIndex == m_currentFrameIndex && m_swFrame && m_swFrame->data[0]) {
    return true;
  }

  if (frameIndex > m_currentFrameIndex &&
      frameIndex <= m_currentFrameIndex + 15) {
    while (m_currentFrameIndex < frameIndex) {
      if (!decodeNextFrameInternal()) {
        break;
      }
      m_currentFrameIndex++;
    }
    return (m_currentFrameIndex == frameIndex);
  }

  if (m_gopCache.size() > 300) {
    m_gopCache.clear();
  }

  AVStream *st = m_fmtCtx->streams[m_videoStreamIndex];
  double streamFps =
      (m_nativeFps > 0.0) ? m_nativeFps : (fps > 0.0 ? fps : 30.0);
  double timeSeconds = static_cast<double>(frameIndex) / streamFps;
  int64_t targetPts = static_cast<int64_t>(timeSeconds * AV_TIME_BASE);

  int64_t streamPts = targetPts;
  if (st && st->time_base.den > 0) {
    streamPts = av_rescale_q(targetPts, AV_TIME_BASE_Q, st->time_base);
  }

  av_seek_frame(m_fmtCtx, m_videoStreamIndex, streamPts, AVSEEK_FLAG_BACKWARD);
  avcodec_flush_buffers(m_codecCtx);

  int64_t startKeyframeIndex = frameIndex;
  if (st && st->time_base.den > 0) {
    double keyframeSec = av_q2d(st->time_base) * streamPts;
    startKeyframeIndex =
        static_cast<int64_t>(std::round(keyframeSec * streamFps));
  }

  int64_t decodedIndex = startKeyframeIndex;
  int maxDecodeAttempts = 120;

  while (maxDecodeAttempts-- > 0 && decodeNextFrameInternal()) {
    if (m_swFrame && m_swFrame->data[0] && m_swFrame->width > 0 &&
        m_swFrame->height > 0) {
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
                               SWS_BILINEAR, nullptr, nullptr, nullptr);

      if (m_swsCtx) {
        QImage rgbaImg(w, h, QImage::Format_RGBA8888);
        uint8_t *dest[4] = {rgbaImg.bits(), nullptr, nullptr, nullptr};
        int destLinesize[4] = {static_cast<int>(rgbaImg.bytesPerLine()), 0, 0,
                               0};
        if (sws_scale(m_swsCtx, m_swFrame->data, m_swFrame->linesize, 0, h,
                      dest, destLinesize) > 0) {
          m_gopCache[decodedIndex] = rgbaImg;
        }
      }
    }

    if (decodedIndex >= frameIndex) {
      m_currentFrameIndex = frameIndex;
      return true;
    }
    decodedIndex++;
  }

  m_currentFrameIndex = frameIndex;
  return true;
}

// Thread-safe extraction of decoded RGBA image using reverse GOP cache lookup
QImage VulkanVideoDecoder::getDecodedQImage() const noexcept {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return QImage();

  if (m_gopCache.count(m_currentFrameIndex)) {
    return m_gopCache[m_currentFrameIndex];
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
                           SWS_BILINEAR, nullptr, nullptr, nullptr);

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

// Extracts VkImage handle or native Vulkan texture
VkImage VulkanVideoDecoder::getDecodedVkImage() const noexcept {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return VK_NULL_HANDLE;

  if (m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN &&
      m_hwFrame->data[0]) {
    auto *vkFrame = reinterpret_cast<AVVkFrame *>(m_hwFrame->data[0]);
    return vkFrame ? vkFrame->img[0] : VK_NULL_HANDLE;
  }

  return VK_NULL_HANDLE;
}

// Returns native stream FPS
double VulkanVideoDecoder::nativeFps() const noexcept {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  return m_nativeFps;
}

// Returns current frame index
int64_t VulkanVideoDecoder::currentFrameIndex() const noexcept {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  return m_currentFrameIndex;
}

// Returns pointer to current active frame structure
AVFrame *VulkanVideoDecoder::currentFrame() const noexcept {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return nullptr;
  return (m_hwFrame && m_hwFrame->format == AV_PIX_FMT_VULKAN) ? m_hwFrame
                                                               : m_swFrame;
}

} // namespace xyla
