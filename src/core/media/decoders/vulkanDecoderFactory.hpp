#pragma once

#include "core/media/decoderRegistry.hpp"
#include "core/media/mediaData.hpp"
#include <memory>
#include <mutex>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_vulkan.h>
}

namespace xyla {

class VulkanVideoDecoder : public IDecoder {
public:
  VulkanVideoDecoder() = default;
  ~VulkanVideoDecoder() override;

  bool open(const QString &filePath) override;
  void close() override;

  bool decodeNextFrame();

private:
  bool initVulkanHWContext();

  AVFormatContext *m_fmtCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  AVBufferRef *m_hwDeviceCtx{nullptr};
  AVFrame *m_hwFrame{nullptr};
  AVFrame *m_swFrame{nullptr};
  AVPacket *m_packet{nullptr};

  int m_videoStreamIndex{-1};
  bool m_isOpen{false};
  std::mutex m_decoderMutex;
};

class VulkanDecoderFactory : public IDecoderFactory {
public:
  DecoderScore evaluate(const MediaMetadata &meta) override;
  std::unique_ptr<IDecoder> createDecoder(const MediaMetadata &meta) override;
};

} // namespace xyla
