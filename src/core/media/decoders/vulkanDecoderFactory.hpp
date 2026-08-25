#pragma once

#include "core/media/decoderRegistry.hpp"
#include <QMutex>
#include <QString>
#include <memory>
#include <mutex>
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

  double nativeFps() const noexcept override { return m_nativeFps; }
  int64_t currentFrameIndex() const noexcept override {
    return m_currentFrameIndex;
  }

  [[nodiscard]] VkImage getDecodedVkImage() const noexcept;
  [[nodiscard]] AVFrame *currentFrame() const noexcept;

private:
  bool initVulkanHWContext();
  bool decodeNextFrameInternal();

  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};

  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  AVPacket *m_packet{nullptr};
  mutable SwsContext *m_swsCtx{nullptr};

  int m_videoStreamIndex{-1};
  int64_t m_currentFrameIndex{-1};
  double m_nativeFps{30.0};
  bool m_isOpen{false};

  mutable std::mutex m_decoderMutex;
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  VulkanDecoderFactory() = default;
  ~VulkanDecoderFactory() override = default;

  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
