#pragma once

#include "core/media/iDecoder.hpp"
#include <QFuture>
#include <QObject>
#include <QString>
#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <vector>
#include <vulkan/vulkan.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/imgutils.h>
}

namespace xyla {

enum class ScrubMode {
  Precise, // Full GOP decode to exact target frame (Slow scrub / Playhead stop)
  FastIFrameOnly, // Instantly decode nearest keyframe (<1ms execution on fast
                  // scrub)
  DualSession     // Dual-session: Show I-Frame instantly, decode exact frame in
                  // background
};

struct KeyframeEntry {
  int64_t frameIndex{0};
  int64_t pts{0};
  int64_t filePos{0};
};

class VulkanVideoDecoder : public IDecoder {
public:
  VulkanVideoDecoder();
  ~VulkanVideoDecoder() override;
  AVFrame *cloneCurrentFrame() const noexcept;
  // Non-copyable, non-movable
  VulkanVideoDecoder(const VulkanVideoDecoder &) = delete;
  VulkanVideoDecoder &operator=(const VulkanVideoDecoder &) = delete;
  VulkanVideoDecoder(VulkanVideoDecoder &&) = delete;
  VulkanVideoDecoder &operator=(VulkanVideoDecoder &&) = delete;

  // Asynchronous Non-Blocking Open Sequence
  QFuture<bool> openAsync(const QString &filePath);
  bool open(const QString &filePath) override;
  void close() override;

  bool decodeNextFrame() override;
  bool seekToFrame(int64_t frameIndex, double fps = 0.0) override;
  bool seekToFrameInternalPrecise(int64_t frameIndex, bool precise,
                                  double fps = 0.0);

  // Velocity-Aware Smart Scrubbing Seek
  bool seekToFrameSmart(int64_t frameIndex, double playheadVelocity,
                        double fps = 0.0);

  // Cooperative Cancellation: Bails out of in-flight decode loops immediately
  // (<0.1ms)
  void cancelInFlightSeeks() noexcept {
    m_currentGeneration.fetch_add(1, std::memory_order_relaxed);
  }

  // Keyframe / I-Frame Helpers
  [[nodiscard]] int64_t
  findNearestIFrameIndex(int64_t targetFrameIndex) const noexcept;
  [[nodiscard]] bool isIFrame(int64_t frameIndex) const noexcept;

  // Frame Getters
  AVFrame *currentFrame() const noexcept override;
  VkImage getDecodedVkImage() const noexcept;

  // Status Accessors
  [[nodiscard]] bool isOpen() const noexcept override {
    return m_isOpen.load();
  }
  [[nodiscard]] int64_t currentFrameIndex() const noexcept override {
    return m_currentFrameIndex.load();
  }
  [[nodiscard]] double nativeFps() const noexcept override {
    return m_nativeFps.load();
  }
  [[nodiscard]] bool isHwAccelerated() const noexcept {
    return m_isHwAccelerated;
  }

private:
  void closeInternal();
  bool decodeNextFrameInternal();
  void indexKeyframes();

  mutable std::recursive_mutex m_decoderMutex;

  // FFmpeg Demuxing & Decoding Contexts (Session A - Primary)
  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};
  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  AVPacket *m_packet{nullptr};

  // FFmpeg Session B (Background Asynchronous Precise Catch-Up Decoder)
  AVFormatContext *m_fmtCtxB{nullptr};
  AVCodecContext *m_codecCtxB{nullptr};
  AVFrame *m_hwFrameB{nullptr};
  AVFrame *m_swFrameB{nullptr};
  AVPacket *m_packetB{nullptr};

  int m_videoStreamIndex{-1};
  std::atomic<bool> m_isOpen{false};
  std::atomic<int64_t> m_currentFrameIndex{-1};
  std::atomic<double> m_nativeFps{30.0};
  bool m_isHwAccelerated{false};
  AVHWDeviceType m_activeHwType{AV_HWDEVICE_TYPE_NONE};

  // Atomic Generation Counter for Preemption
  std::atomic<uint64_t> m_currentGeneration{0};

  // Keyframe Index Table
  std::vector<KeyframeEntry> m_keyframeIndex;

  // Playhead Velocity Tracking State
  int64_t m_lastRequestedFrame{-1};
  std::chrono::steady_clock::time_point m_lastRequestTime;
  double m_currentVelocity{0.0};
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  VulkanDecoderFactory() = default;
  ~VulkanDecoderFactory() override = default;

  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
