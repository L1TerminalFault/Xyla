#include "vulkanDecoderFactory.hpp"
#include "core/log/logger.hpp"

namespace xyla {

VulkanVideoDecoder::~VulkanVideoDecoder() { close(); }

bool VulkanVideoDecoder::initVulkanHWContext() {
  int err = av_hwdevice_ctx_create(&m_hwDeviceCtx, AV_HWDEVICE_TYPE_VULKAN,
                                   nullptr, nullptr, 0);
  if (err < 0) {
    char errBuf[AV_ERROR_MAX_STRING_SIZE] = {0};
    av_strerror(err, errBuf, sizeof(errBuf));
    XYLA_LOG_WARN("VulkanDecoder",
                  "Failed to create Vulkan HW Device Context (" +
                      std::string(errBuf) + ")");
    return false;
  }
  return true;
}

bool VulkanVideoDecoder::open(const QString &filePath) {
  std::lock_guard<std::mutex> lock(m_decoderMutex);

  if (m_isOpen) {
    close();
  }

  const std::string nativePath = filePath.toStdString();

  if (avformat_open_input(&m_fmtCtx, nativePath.c_str(), nullptr, nullptr) <
      0) {
    XYLA_LOG_ERROR("VulkanDecoder", "Failed to open video file: " + nativePath);
    return false;
  }

  if (avformat_find_stream_info(m_fmtCtx, nullptr) < 0) {
    XYLA_LOG_ERROR("VulkanDecoder",
                   "Failed to find stream info: " + nativePath);
    close();
    return false;
  }

  // Locate primary video stream
  const AVCodec *decoder = nullptr;
  m_videoStreamIndex =
      av_find_best_stream(m_fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);

  if (m_videoStreamIndex < 0 || !decoder) {
    XYLA_LOG_ERROR("VulkanDecoder",
                   "No valid video stream found in: " + nativePath);
    close();
    return false;
  }

  m_codecCtx = avcodec_alloc_context3(decoder);
  if (!m_codecCtx) {
    close();
    return false;
  }

  AVStream *videoStream = m_fmtCtx->streams[m_videoStreamIndex];
  if (avcodec_parameters_to_context(m_codecCtx, videoStream->codecpar) < 0) {
    close();
    return false;
  }

  if (initVulkanHWContext()) {
    m_codecCtx->hw_device_ctx = av_buffer_ref(m_hwDeviceCtx);
  } else {
    XYLA_LOG_WARN("VulkanDecoder",
                  "Falling back to software decoding pipeline for: " +
                      nativePath);
  }

  if (avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
    XYLA_LOG_ERROR("VulkanDecoder",
                   "Failed to open codec context for: " + nativePath);
    close();
    return false;
  }

  // Allocate frame structures
  m_hwFrame = av_frame_alloc();
  m_swFrame = av_frame_alloc();
  m_packet = av_packet_alloc();

  m_isOpen = true;
  XYLA_LOG_INFO("VulkanDecoder",
                "Successfully initialized Vulkan decoder pipeline: " +
                    nativePath);
  return true;
}

bool VulkanVideoDecoder::decodeNextFrame() {
  std::lock_guard<std::mutex> lock(m_decoderMutex);
  if (!m_isOpen)
    return false;

  while (av_read_frame(m_fmtCtx, m_packet) >= 0) {
    if (m_packet->stream_index == m_videoStreamIndex) {
      int ret = avcodec_send_packet(m_codecCtx, m_packet);
      av_packet_unref(m_packet);

      if (ret < 0)
        return false;

      ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
      if (ret == 0) {
        // Check if frame is hardware accelerated (Vulkan VK_FORMAT_*)
        if (m_hwFrame->format == AV_PIX_FMT_VULKAN) {
          // Frame resides inside GPU memory (VkImage)
          // Transfer or alias directly into engine graphics queue
        } else {
          // Software frame fallback
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

void VulkanVideoDecoder::close() {
  std::lock_guard<std::mutex> lock(m_decoderMutex);

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
  m_isOpen = false;
}

// Factory Implementations
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

} // namespace xyla
