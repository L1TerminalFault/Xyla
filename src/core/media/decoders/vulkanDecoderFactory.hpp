#pragma once

#include "core/media/decoderRegistry.hpp"
#include <QMap>
#include <QString>
#include <atomic>
#include <memory>
#include <mutex>
#include <vulkan/vulkan.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_vulkan.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
}

namespace xyla {

class VulkanVideoDecoder : public IDecoder {
public:
  VulkanVideoDecoder() = default;
  ~VulkanVideoDecoder() override;

  bool open(const QString &filePath) override;
  void close() override;

  bool decodeNextFrame() override;

  // Fulfills the IDecoder pure virtual interface
  bool seekToFrame(int64_t frameIndex, double fps = 30.0) override;

  // Overload for scrubbing vs precise seeking
  bool seekToFrame(int64_t frameIndex, bool precise, double fps = 30.0);

  [[nodiscard]] double nativeFps() const noexcept override {
    return m_nativeFps.load(std::memory_order_relaxed);
  }

  [[nodiscard]] int64_t currentFrameIndex() const noexcept override {
    return m_currentFrameIndex.load(std::memory_order_relaxed);
  }

  [[nodiscard]] bool isOpen() const noexcept override {
    return m_isOpen.load(std::memory_order_relaxed);
  }

  [[nodiscard]] VkImage getDecodedVkImage() const noexcept;
  [[nodiscard]] AVFrame *currentFrame() const noexcept;

private:
  bool initHWContext(AVCodecID codecId);
  bool decodeNextFrameInternal();

  mutable std::recursive_mutex m_decoderMutex;

  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};

  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  AVPacket *m_packet{nullptr};

  int m_videoStreamIndex{-1};
  std::atomic<double> m_nativeFps{30.0};
  std::atomic<int64_t> m_currentFrameIndex{-1};
  std::atomic<bool> m_isOpen{false};
  bool m_isHwAccelerated{false};
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
