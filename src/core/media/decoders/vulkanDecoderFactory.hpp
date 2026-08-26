#pragma once

#include "core/media/decoderRegistry.hpp"
#include <QImage>
#include <QString>
#include <atomic>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vulkan/vulkan.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_vulkan.h>
#include <libswscale/swscale.h>
}

namespace xyla {

class VulkanVideoDecoder : public IDecoder {
public:
  VulkanVideoDecoder() = default;
  ~VulkanVideoDecoder() override;

  bool open(const QString &filePath) override;
  bool decodeNextFrame() override;
  bool seekToFrame(int64_t frameIndex, double fps = 30.0) override;
  void close() override;

  void requestFrame(int64_t targetFrame) noexcept {
    m_requestedFrame.store(targetFrame);
  }

  // FIX: Lock-free atomic getters (0.000000ms execution time, NEVER blocks on
  // FFmpeg!)
  double nativeFps() const noexcept override { return m_nativeFps.load(); }
  int64_t currentFrameIndex() const noexcept override {
    return m_currentFrameIndex.load();
  }

  [[nodiscard]] QImage getDecodedQImage() const noexcept;
  [[nodiscard]] VkImage getDecodedVkImage() const noexcept;
  [[nodiscard]] AVFrame *currentFrame() const noexcept;

private:
  bool initVulkanHWContext();
  bool decodeNextFrameInternal();
  void evictGopCache(int64_t targetFrame, size_t maxCapacity = 120);

  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};

  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  mutable AVFrame *m_nv12Frame{nullptr};
  AVPacket *m_packet{nullptr};

  mutable SwsContext *m_swsCtx{nullptr};
  mutable SwsContext *m_nv12SwsCtx{nullptr};

  int m_videoStreamIndex{-1};
  std::atomic<int64_t> m_currentFrameIndex{-1};
  int64_t m_gopStartFrame{-1};
  int64_t m_gopEndFrame{-1};
  std::atomic<double> m_nativeFps{30.0};
  bool m_isOpen{false};

  std::atomic<int64_t> m_requestedFrame{-1};

  mutable std::unordered_map<int64_t, QImage> m_gopCache;
  mutable std::recursive_mutex m_decoderMutex;
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  VulkanDecoderFactory() = default;
  ~VulkanDecoderFactory() override = default;

  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
