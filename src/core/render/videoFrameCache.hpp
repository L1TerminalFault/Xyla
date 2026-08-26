#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include <QObject>
#include <array>
#include <deque>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <utility>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct CachedFrame {
  QString assetId;
  int64_t frameIndex{0};

  // Y Plane (R8_UNORM)
  VkImage yImage{VK_NULL_HANDLE};
  VkDeviceMemory yMemory{VK_NULL_HANDLE};
  VkImageView yView{VK_NULL_HANDLE};

  // UV Plane (RG8_UNORM)
  VkImage uvImage{VK_NULL_HANDLE};
  VkDeviceMemory uvMemory{VK_NULL_HANDLE};
  VkImageView uvView{VK_NULL_HANDLE};

  // Backward-compatibility aliases
  VkImageView imageView{VK_NULL_HANDLE};
  VkImage image{VK_NULL_HANDLE};
  VkDeviceMemory memory{VK_NULL_HANDLE};

  size_t sizeBytes{0};
  bool isGPUReady{false};
};

class VideoFrameCache : public QObject {
  Q_OBJECT

public:
  static VideoFrameCache &instance() {
    static VideoFrameCache cache;
    return cache;
  }

  // Non-blocking VRAM texture lookup
  std::pair<VkImageView, VkImageView>
  getFramePlanes(const QString &assetId, int64_t frameIndex,
                 VulkanVideoDecoder *decoder, bool isPlaying = false,
                 bool allowBlockingDecode = false);

  VkImageView getFrame(const QString &assetId, int64_t frameIndex,
                       VulkanVideoDecoder *decoder, bool isPlaying = false,
                       bool allowBlockingDecode = false) {
    auto [yView, uvView] = getFramePlanes(assetId, frameIndex, decoder,
                                          isPlaying, allowBlockingDecode);
    return yView;
  }

  void setMaxVramMB(size_t maxMegabytes);
  void clear();
  void clearAsset(const QString &assetId);

  [[nodiscard]] int64_t cachedStartFrame() const noexcept {
    return m_cachedStartFrame;
  }
  [[nodiscard]] int64_t cachedEndFrame() const noexcept {
    return m_cachedEndFrame;
  }

signals:
  void frameReady(const QString &assetId, qint64 frameIndex);
  void cacheRangeChanged(qint64 startFrame, qint64 endFrame);

private:
  VideoFrameCache();
  ~VideoFrameCache() override;

  void evictIfNeeded();
  void updateCacheRange();

  std::mutex m_cacheMutex;
  std::unordered_map<QString, std::shared_ptr<CachedFrame>> m_frameMap;
  std::deque<QString> m_lruQueue;

  static constexpr size_t kRingSlots = 32;
  std::array<QString, kRingSlots> m_slotOwners;

  int64_t m_cachedStartFrame{-1};
  int64_t m_cachedEndFrame{-1};

  size_t m_currentVramBytes{0};
  size_t m_maxVramBytes{4500ULL * 1024ULL * 1024ULL};
};

} // namespace xyla::render
