#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/memory/xylaArena.hpp"

#include <QMap>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <cstdint>
#include <list>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>
#include <vulkan/vulkan.h>

extern "C" {
#include <libavutil/frame.h>
}

namespace xyla::render {

struct CachedFrame {
  QString assetId;
  int64_t frameIndex{0};
  uint32_t width{0};
  uint32_t height{0};

  VkImage yImage{VK_NULL_HANDLE};
  VkDeviceMemory yMemory{VK_NULL_HANDLE};
  VkImageView yView{VK_NULL_HANDLE};
  uint8_t *yMappedPtr{nullptr};

  VkImage uvImage{VK_NULL_HANDLE};
  VkDeviceMemory uvMemory{VK_NULL_HANDLE};
  VkImageView uvView{VK_NULL_HANDLE};
  uint8_t *uvMappedPtr{nullptr};

  // Legacy handle aliases for backward compatibility
  VkImageView imageView{VK_NULL_HANDLE};
  VkImage image{VK_NULL_HANDLE};
  VkDeviceMemory memory{VK_NULL_HANDLE};

  size_t sizeBytes{0};
  bool isGPUReady{false};

  std::list<struct FrameKey>::iterator lruIt;
};

struct FrameKey {
  QString assetId;
  int64_t frameIndex{0};

  bool operator==(const FrameKey &other) const {
    return frameIndex == other.frameIndex && assetId == other.assetId;
  }
};

} // namespace xyla::render

namespace std {
template <> struct hash<xyla::render::FrameKey> {
  size_t operator()(const xyla::render::FrameKey &k) const noexcept {
    size_t h1 = std::hash<std::string>{}(k.assetId.toStdString());
    size_t h2 = std::hash<int64_t>{}(k.frameIndex);
    return h1 ^ (h2 << 1);
  }
};
} // namespace std

namespace xyla::render {

struct PooledTexture {
  uint32_t width{0};
  uint32_t height{0};

  VkImage yImage{VK_NULL_HANDLE};
  VkDeviceMemory yMemory{VK_NULL_HANDLE};
  VkImageView yView{VK_NULL_HANDLE};
  uint8_t *yMappedPtr{nullptr};

  VkImage uvImage{VK_NULL_HANDLE};
  VkDeviceMemory uvMemory{VK_NULL_HANDLE};
  VkImageView uvView{VK_NULL_HANDLE};
  uint8_t *uvMappedPtr{nullptr};

  size_t sizeBytes{0};
};

class VideoFrameCache : public QObject {
  Q_OBJECT

public:
  static constexpr size_t kMaxPooledTextures = 32;

  static VideoFrameCache &instance();

  VideoFrameCache();
  ~VideoFrameCache() override;

  VideoFrameCache(const VideoFrameCache &) = delete;
  VideoFrameCache &operator=(const VideoFrameCache &) = delete;
  void ensureCapacityForBytes(size_t requiredBytes);

  [[nodiscard]] bool hasFrame(const QString &assetId, int64_t frameIndex) const;

  bool uploadAndCacheFrame(const QString &assetId, int64_t frameIndex,
                           AVFrame *frame);

  std::pair<VkImageView, VkImageView>
  getFramePlanes(const QString &assetId, int64_t frameIndex,
                 xyla::VulkanVideoDecoder *decoder, bool isPlaying,
                 bool isScrubbing, bool isPrefetch = false,
                 double scrubVelocity = 0.0);

  std::shared_ptr<CachedFrame>
  getFrame(const QString &assetId, int64_t frameIndex,
           xyla::VulkanVideoDecoder *decoder, bool isPlaying, bool isScrubbing,
           bool isPrefetch = false, double scrubVelocity = 0.0);

  void setMaxVramMB(size_t maxMegabytes);
  void clearAsset(const QString &assetId);
  void clear();

  QVariantList getCacheRangesForAsset(const QString &assetId) const;

signals:
  void frameReady(const QString &assetId, int64_t frameIndex);
  void cacheRangeChanged(int64_t startFrame, int64_t endFrame);
  void cacheRangesUpdated();

private:
  void evictIfNeeded();
  void updateCacheRanges();
  void destroyTextureHandle(std::shared_ptr<CachedFrame> frame);

  mutable std::mutex m_cacheMutex;

  std::unordered_map<FrameKey, std::shared_ptr<CachedFrame>> m_frameMap;
  std::list<FrameKey> m_lruList;
  std::unordered_map<QString, std::map<int64_t, std::shared_ptr<CachedFrame>>>
      m_assetFrameMap;
  std::vector<PooledTexture> m_texturePool;

  size_t m_currentVramBytes{0};
  size_t m_maxVramBytes{4096ULL * 1024ULL * 1024ULL}; // Default 4GB

  QMap<QString, QVariantList> m_cachedRangesPerAsset;
  int64_t m_cachedStartFrame{-1};
  int64_t m_cachedEndFrame{-1};
};

} // namespace xyla::render
