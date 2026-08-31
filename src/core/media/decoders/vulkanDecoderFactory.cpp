#include "vulkanDecoderFactory.hpp"
#include "core/memory/xylaArena.hpp"
#include <QtConcurrent/QtConcurrent>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <qdir.h>
#include <qurl.h>
#include <vector>

namespace xyla {

namespace {

static enum AVPixelFormat get_hw_format(AVCodecContext *ctx,
                                        const enum AVPixelFormat *pix_fmts) {
  AVHWDeviceType targetHWType = AV_HWDEVICE_TYPE_NONE;
  if (ctx && ctx->hw_device_ctx && ctx->hw_device_ctx->data) {
    auto *hwctx =
        reinterpret_cast<AVHWDeviceContext *>(ctx->hw_device_ctx->data);
    targetHWType = hwctx->type;
  }

  AVPixelFormat expectedFormat = AV_PIX_FMT_NONE;
  if (targetHWType == AV_HWDEVICE_TYPE_VULKAN)
    expectedFormat = AV_PIX_FMT_VULKAN;
  else if (targetHWType == AV_HWDEVICE_TYPE_CUDA)
    expectedFormat = AV_PIX_FMT_CUDA;
  else if (targetHWType == AV_HWDEVICE_TYPE_VAAPI)
    expectedFormat = AV_PIX_FMT_VAAPI;
  else if (targetHWType == AV_HWDEVICE_TYPE_D3D11VA)
    expectedFormat = AV_PIX_FMT_D3D11;

  for (const enum AVPixelFormat *p = pix_fmts; *p != -1; p++) {
    if (expectedFormat != AV_PIX_FMT_NONE && *p == expectedFormat) {
      return *p;
    }
  }

  return pix_fmts[0];
}

} // namespace

VulkanVideoDecoder::VulkanVideoDecoder() {
  m_lastRequestTime = std::chrono::steady_clock::now();
}

VulkanVideoDecoder::~VulkanVideoDecoder() { close(); }

void VulkanVideoDecoder::closeInternal() {
  m_isOpen.store(false, std::memory_order_relaxed);

  if (m_packet)
    av_packet_free(&m_packet);
  if (m_hwFrame)
    av_frame_free(&m_hwFrame);
  if (m_swFrame)
    av_frame_free(&m_swFrame);
  if (m_codecCtx)
    avcodec_free_context(&m_codecCtx);
  if (m_hwDeviceCtx)
    av_buffer_unref(&m_hwDeviceCtx);

  if (m_packetB)
    av_packet_free(&m_packetB);
  if (m_hwFrameB)
    av_frame_free(&m_hwFrameB);
  if (m_swFrameB)
    av_frame_free(&m_swFrameB);
  if (m_codecCtxB)
    avcodec_free_context(&m_codecCtxB);
  if (m_fmtCtxB)
    avformat_close_input(&m_fmtCtxB);

  m_isHwAccelerated = false;
  m_activeHwType = AV_HWDEVICE_TYPE_NONE;
  m_keyframeIndex.clear();
}

void VulkanVideoDecoder::close() {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  closeInternal();

  if (m_fmtCtx)
    avformat_close_input(&m_fmtCtx);

  m_videoStreamIndex = -1;
  m_currentFrameIndex.store(-1, std::memory_order_relaxed);
}

QFuture<bool> VulkanVideoDecoder::openAsync(const QString &filePath) {
  return QtConcurrent::run([this, filePath]() { return open(filePath); });
}

bool VulkanVideoDecoder::open(const QString &filePath) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
  auto marker = scratchpad.getMarker();

  if (m_isOpen.load(std::memory_order_relaxed)) {
    close();
  }

  QString cleanPath =
      QUrl(filePath).isLocalFile() ? QUrl(filePath).toLocalFile() : filePath;
  const std::string nativePath =
      QDir::toNativeSeparators(cleanPath).toStdString();

  int err =
      avformat_open_input(&m_fmtCtx, nativePath.c_str(), nullptr, nullptr);
  if (err < 0) {
    scratchpad.resetToMarker(marker);
    return false;
  }

  if (avformat_find_stream_info(m_fmtCtx, nullptr) < 0) {
    close();
    scratchpad.resetToMarker(marker);
    return false;
  }

  const AVCodec *decoder = nullptr;
  m_videoStreamIndex =
      av_find_best_stream(m_fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);

  if (m_videoStreamIndex < 0 || !decoder) {
    close();
    scratchpad.resetToMarker(marker);
    return false;
  }

  AVStream *videoStream = m_fmtCtx->streams[m_videoStreamIndex];
  AVRational rate = videoStream->avg_frame_rate;
  if (rate.num == 0 || rate.den == 0) {
    rate = videoStream->r_frame_rate;
  }
  m_nativeFps.store((rate.num > 0 && rate.den > 0) ? av_q2d(rate) : 30.0,
                    std::memory_order_relaxed);

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

  bool decodeSuccess = false;

  for (auto backend : preferredBackends) {
    if (m_videoStreamIndex >= 0 && m_fmtCtx) {
      av_seek_frame(m_fmtCtx, m_videoStreamIndex, 0, AVSEEK_FLAG_BACKWARD);
    }

    bool codecSupportsBackend = false;
    for (int i = 0;; i++) {
      const AVCodecHWConfig *config = avcodec_get_hw_config(decoder, i);
      if (!config)
        break;
      if ((config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) &&
          config->device_type == backend) {
        codecSupportsBackend = true;
        break;
      }
    }

    if (!codecSupportsBackend) {
      continue;
    }

    AVBufferRef *hwCtx = nullptr;
    if (backend == AV_HWDEVICE_TYPE_VULKAN) {
      if (av_hwdevice_ctx_create(&hwCtx, backend, nullptr, nullptr, 0) < 0) {
        av_hwdevice_ctx_create(&hwCtx, backend, "0", nullptr, 0);
      }
    } else {
      av_hwdevice_ctx_create(&hwCtx, backend, nullptr, nullptr, 0);
    }

    if (!hwCtx) {
      continue;
    }

    AVCodecContext *codecCtx = avcodec_alloc_context3(decoder);
    if (!codecCtx ||
        avcodec_parameters_to_context(codecCtx, videoStream->codecpar) < 0) {
      if (codecCtx)
        avcodec_free_context(&codecCtx);
      av_buffer_unref(&hwCtx);
      continue;
    }

    codecCtx->thread_count =
        std::min(8, static_cast<int>(std::thread::hardware_concurrency()));
    codecCtx->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
    codecCtx->get_format = get_hw_format;
    codecCtx->hw_device_ctx = av_buffer_ref(hwCtx);

    if (avcodec_open2(codecCtx, decoder, nullptr) < 0) {
      avcodec_free_context(&codecCtx);
      av_buffer_unref(&hwCtx);
      continue;
    }

    m_codecCtx = codecCtx;
    m_hwDeviceCtx = hwCtx;
    m_hwFrame = av_frame_alloc();
    m_swFrame = av_frame_alloc();
    m_packet = av_packet_alloc();
    m_isOpen.store(true, std::memory_order_relaxed);

    if (decodeNextFrameInternal()) {
      m_isHwAccelerated = true;
      m_activeHwType = backend;
      m_currentFrameIndex.store(0, std::memory_order_relaxed);
      decodeSuccess = true;
      break;
    }

    closeInternal();
  }

  if (!decodeSuccess) {
    if (m_videoStreamIndex >= 0 && m_fmtCtx) {
      av_seek_frame(m_fmtCtx, m_videoStreamIndex, 0, AVSEEK_FLAG_BACKWARD);
    }

    m_codecCtx = avcodec_alloc_context3(decoder);
    if (!m_codecCtx ||
        avcodec_parameters_to_context(m_codecCtx, videoStream->codecpar) < 0 ||
        avcodec_open2(m_codecCtx, decoder, nullptr) < 0) {
      close();
      scratchpad.resetToMarker(marker);
      return false;
    }

    m_hwFrame = av_frame_alloc();
    m_swFrame = av_frame_alloc();
    m_packet = av_packet_alloc();
    m_isOpen.store(true, std::memory_order_relaxed);
    m_isHwAccelerated = false;

    if (decodeNextFrameInternal()) {
      m_currentFrameIndex.store(0, std::memory_order_relaxed);
    }
  }

  indexKeyframes();
  scratchpad.resetToMarker(marker);

  return m_isOpen.load(std::memory_order_relaxed);
}

void VulkanVideoDecoder::indexKeyframes() {
  m_keyframeIndex.clear();
  if (m_videoStreamIndex < 0 || !m_fmtCtx) {
    return;
  }

  int seekRes =
      av_seek_frame(m_fmtCtx, m_videoStreamIndex, 0, AVSEEK_FLAG_BACKWARD);
  if (seekRes < 0) {
    return;
  }

  AVPacket *pkt = av_packet_alloc();
  double fps = m_nativeFps.load(std::memory_order_relaxed);
  if (fps <= 0.0)
    fps = 30.0;
  AVStream *st = m_fmtCtx->streams[m_videoStreamIndex];
  int64_t startTime = (st->start_time != AV_NOPTS_VALUE) ? st->start_time : 0;

  while (av_read_frame(m_fmtCtx, pkt) >= 0) {
    if (pkt->stream_index == m_videoStreamIndex &&
        (pkt->flags & AV_PKT_FLAG_KEY)) {
      int64_t pts = (pkt->pts != AV_NOPTS_VALUE) ? pkt->pts : pkt->dts;
      if (pts != AV_NOPTS_VALUE) {
        double sec = (pts - startTime) * av_q2d(st->time_base);
        int64_t frameIdx = static_cast<int64_t>(std::round(sec * fps));
        m_keyframeIndex.push_back({frameIdx, pts, 0});
      }
    }
    av_packet_unref(pkt);
  }
  av_packet_free(&pkt);

  av_seek_frame(m_fmtCtx, m_videoStreamIndex, 0, AVSEEK_FLAG_BACKWARD);
  if (m_codecCtx) {
    avcodec_flush_buffers(m_codecCtx);
  }
}

int64_t VulkanVideoDecoder::findNearestIFrameIndex(
    int64_t targetFrameIndex) const noexcept {
  if (targetFrameIndex <= 0) {
    return 0;
  }

  if (m_keyframeIndex.size() > 1) {
    auto it = std::upper_bound(
        m_keyframeIndex.begin(), m_keyframeIndex.end(), targetFrameIndex,
        [](int64_t val, const KeyframeEntry &e) { return val < e.frameIndex; });

    if (it != m_keyframeIndex.begin()) {
      --it;
      return it->frameIndex;
    }
  }

  return 0;
}

bool VulkanVideoDecoder::isIFrame(int64_t frameIndex) const noexcept {
  if (m_keyframeIndex.empty())
    return false;

  auto it = std::lower_bound(
      m_keyframeIndex.begin(), m_keyframeIndex.end(), frameIndex,
      [](const KeyframeEntry &e, int64_t val) { return e.frameIndex < val; });

  return (it != m_keyframeIndex.end() && it->frameIndex == frameIndex);
}

bool VulkanVideoDecoder::decodeNextFrameInternal() {
  if (!m_isOpen.load(std::memory_order_relaxed)) {
    return false;
  }

  if (m_hwFrame)
    av_frame_unref(m_hwFrame);
  if (m_swFrame)
    av_frame_unref(m_swFrame);

  int ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
  if (ret == 0) {
    if (m_hwFrame->hw_frames_ctx != nullptr ||
        m_hwFrame->format == AV_PIX_FMT_CUDA ||
        m_hwFrame->format == AV_PIX_FMT_VULKAN ||
        m_hwFrame->format == AV_PIX_FMT_VAAPI ||
        m_hwFrame->format == AV_PIX_FMT_D3D11) {
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
        if (m_hwFrame->hw_frames_ctx != nullptr ||
            m_hwFrame->format == AV_PIX_FMT_CUDA ||
            m_hwFrame->format == AV_PIX_FMT_VULKAN ||
            m_hwFrame->format == AV_PIX_FMT_VAAPI ||
            m_hwFrame->format == AV_PIX_FMT_D3D11) {
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

  ret = avcodec_send_packet(m_codecCtx, nullptr);
  if (ret >= 0) {
    ret = avcodec_receive_frame(m_codecCtx, m_hwFrame);
    if (ret == 0) {
      if (m_hwFrame->hw_frames_ctx != nullptr ||
          m_hwFrame->format == AV_PIX_FMT_CUDA ||
          m_hwFrame->format == AV_PIX_FMT_VULKAN ||
          m_hwFrame->format == AV_PIX_FMT_VAAPI ||
          m_hwFrame->format == AV_PIX_FMT_D3D11) {
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

bool VulkanVideoDecoder::seekToFrameSmart(int64_t frameIndex,
                                          double playheadVelocity, double fps) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);

  if (playheadVelocity >= 0.0) {
    m_currentVelocity = playheadVelocity;
  } else {
    auto now = std::chrono::steady_clock::now();
    double elapsedSec =
        std::chrono::duration<double>(now - m_lastRequestTime).count();
    if (elapsedSec > 0.001 && m_lastRequestedFrame >= 0) {
      m_currentVelocity =
          std::abs(static_cast<double>(frameIndex - m_lastRequestedFrame)) /
          elapsedSec;
    } else {
      m_currentVelocity = 0.0;
    }
    m_lastRequestTime = now;
    m_lastRequestedFrame = frameIndex;
  }

  if (m_currentVelocity > 15.0) {
    int64_t iFrameIdx = findNearestIFrameIndex(frameIndex);
    return seekToFrameInternalPrecise(iFrameIdx, false, fps);
  }

  return seekToFrameInternalPrecise(frameIndex, true, fps);
}

bool VulkanVideoDecoder::seekToFrame(int64_t frameIndex, double fps) {
  return seekToFrameInternalPrecise(frameIndex, true, fps);
}

bool VulkanVideoDecoder::seekToFrameInternalPrecise(int64_t frameIndex,
                                                    bool precise, double fps) {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed) || m_videoStreamIndex < 0 ||
      !m_fmtCtx || !m_codecCtx) {
    return false;
  }

  uint64_t capturedGen = m_currentGeneration.load(std::memory_order_relaxed);
  int64_t current = m_currentFrameIndex.load(std::memory_order_relaxed);

  if (frameIndex == current && m_swFrame && m_swFrame->data[0]) {
    return true;
  }

  if (frameIndex > current && frameIndex <= current + 350) {
    while (m_currentFrameIndex.load(std::memory_order_relaxed) < frameIndex) {
      if (precise &&
          capturedGen != m_currentGeneration.load(std::memory_order_relaxed)) {
        return false;
      }
      if (!decodeNextFrameInternal())
        break;
      m_currentFrameIndex.fetch_add(1, std::memory_order_relaxed);
    }
    return (m_currentFrameIndex.load(std::memory_order_relaxed) == frameIndex);
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

  if (st && st->start_time != AV_NOPTS_VALUE) {
    targetPts += st->start_time;
  }

  if (m_fmtCtx->pb) {
    m_fmtCtx->pb->eof_reached = 0;
    m_fmtCtx->pb->error = 0;
  }

  int seekRes = av_seek_frame(m_fmtCtx, m_videoStreamIndex, targetPts,
                              AVSEEK_FLAG_BACKWARD);
  if (seekRes < 0) {
    seekRes = av_seek_frame(m_fmtCtx, m_videoStreamIndex, targetPts, 0);
  }
  if (seekRes < 0) {
    int64_t globalTargetUs = static_cast<int64_t>(timeSeconds * AV_TIME_BASE);
    seekRes = av_seek_frame(m_fmtCtx, -1, globalTargetUs, AVSEEK_FLAG_BACKWARD);
  }

  avcodec_flush_buffers(m_codecCtx);

  if (seekRes < 0) {
    return false;
  }

  if (!precise) {
    if (decodeNextFrameInternal()) {
      int64_t rawPts =
          (m_swFrame && m_swFrame->pts != AV_NOPTS_VALUE)
              ? m_swFrame->pts
              : (m_swFrame ? m_swFrame->best_effort_timestamp : AV_NOPTS_VALUE);
      int64_t actualIndex = frameIndex;
      if (rawPts != AV_NOPTS_VALUE && st && st->time_base.den > 0) {
        int64_t adjustedPts =
            rawPts - (st->start_time != AV_NOPTS_VALUE ? st->start_time : 0);
        actualIndex = static_cast<int64_t>(
            std::round(av_q2d(st->time_base) * adjustedPts * streamFps));
      }
      m_currentFrameIndex.store(actualIndex, std::memory_order_relaxed);
      return true;
    }
    return false;
  }

  bool frameDecoded = false;
  int maxDecodePasses = 800;

  while (maxDecodePasses-- > 0 && decodeNextFrameInternal()) {
    if (capturedGen != m_currentGeneration.load(std::memory_order_relaxed)) {
      return false;
    }

    frameDecoded = true;

    int64_t rawPts =
        (m_swFrame && m_swFrame->pts != AV_NOPTS_VALUE)
            ? m_swFrame->pts
            : (m_swFrame ? m_swFrame->best_effort_timestamp : AV_NOPTS_VALUE);

    int64_t currentIdx = frameIndex;
    if (rawPts != AV_NOPTS_VALUE && st && st->time_base.den > 0) {
      int64_t adjustedPts =
          rawPts - (st->start_time != AV_NOPTS_VALUE ? st->start_time : 0);
      currentIdx = static_cast<int64_t>(
          std::round(av_q2d(st->time_base) * adjustedPts * streamFps));
    }

    m_currentFrameIndex.store(currentIdx, std::memory_order_relaxed);

    if (currentIdx >= frameIndex) {
      return true;
    }
  }

  if (frameDecoded) {
    m_currentFrameIndex.store(frameIndex, std::memory_order_relaxed);
    return true;
  }

  return false;
}

VkImage VulkanVideoDecoder::getDecodedVkImage() const noexcept {
  return VK_NULL_HANDLE;
}

AVFrame *VulkanVideoDecoder::currentFrame() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed)) {
    return nullptr;
  }
  return (m_swFrame && m_swFrame->data[0]) ? m_swFrame : nullptr;
}

AVFrame *VulkanVideoDecoder::cloneCurrentFrame() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_decoderMutex);
  if (!m_isOpen.load(std::memory_order_relaxed) || !m_swFrame ||
      !m_swFrame->data[0]) {
    return nullptr;
  }
  return av_frame_clone(m_swFrame);
}

DecoderScore VulkanDecoderFactory::evaluate(const MediaMetadata &meta) {
  if (!meta.isValid())
    return DecoderScore::invalid();
  if (meta.type == MediaType::Video && !meta.videoStreams.empty()) {
    return DecoderScore{100, true, true, "Vulkan Hardware Decoder"};
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
