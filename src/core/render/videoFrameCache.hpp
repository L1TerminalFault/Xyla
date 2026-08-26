#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include <QObject>
#include <array>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct CachedFrame {
  QString assetId;
  int64_t frameIndex{0};
  VkImage image{VK_NULL_HANDLE};
  VkImageView imageView{VK_NULL_HANDLE};
  size_t sizeBytes{1920 * 1080 * 4};
  bool isGPUReady{false};
};

class VideoFrameCache : public QObject {
  Q_OBJECT

public:
  static VideoFrameCache &instance() {
    static VideoFrameCache cache;
    return cache;
  }

  VkImageView getFrame(const QString &assetId, int64_t frameIndex,
                       VulkanVideoDecoder *decoder, bool isPlaying = false);
  void setMaxVramMB(size_t maxMegabytes);
  void clear();

signals:
  void frameReady(const QString &assetId, qint64 frameIndex);

private:
  VideoFrameCache() = default;
  ~VideoFrameCache() override = default;

  void evictIfNeeded();

  std::mutex m_cacheMutex;
  std::unordered_map<QString, std::shared_ptr<CachedFrame>> m_frameMap;

  static constexpr size_t kRingSlots = 32;
  std::array<QString, kRingSlots> m_slotOwners;

  size_t m_currentVramBytes{0};
  size_t m_maxVramBytes{2048ULL * 1024ULL * 1024ULL};
};

} // namespace xyla::render
