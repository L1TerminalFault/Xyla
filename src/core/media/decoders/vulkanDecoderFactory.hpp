#pragma once

#include "core/media/decoderRegistry.hpp"
#include <QImage>
#include <QString>
#include <atomic>
#include <memory>
#include <mutex>
#include <vulkan/vulkan.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_vulkan.h>
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
    m_requestedFrame.store(targetFrame, std::memory_order_relaxed);
  }

  [[nodiscard]] double nativeFps() const noexcept override {
    return m_nativeFps.load(std::memory_order_relaxed);
  }

  [[nodiscard]] int64_t currentFrameIndex() const noexcept override {
    return m_currentFrameIndex.load(std::memory_order_relaxed);
  }

  // Raw NV12 Frame for SourceNode Shader Bindings (Y Plane = data[0], UV Plane
  // = data[1])
  [[nodiscard]] AVFrame *currentFrame() const noexcept;
  [[nodiscard]] VkImage getDecodedVkImage() const noexcept;

private:
  bool initHWContext(AVCodecID codecId);
  bool decodeNextFrameInternal();

  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};

  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  AVPacket *m_packet{nullptr};

  int m_videoStreamIndex{-1};
  std::atomic<int64_t> m_currentFrameIndex{-1};
  std::atomic<double> m_nativeFps{30.0};
  std::atomic<bool> m_isOpen{false};
  std::atomic<int64_t> m_requestedFrame{-1};

  mutable std::recursive_mutex m_decoderMutex;
  bool m_isHwAccelerated{false};
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  VulkanDecoderFactory() = default;
  ~VulkanDecoderFactory() override = default;

  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
