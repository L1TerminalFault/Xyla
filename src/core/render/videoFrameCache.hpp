#pragma once

#include <QMap>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <deque>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <utility>
#include <vulkan/vulkan.h>

namespace xyla {
class VulkanVideoDecoder;
}

namespace xyla::render {

struct CachedFrame {
  QString assetId;
  int64_t frameIndex = -1;

  VkImage yImage = VK_NULL_HANDLE;
  VkDeviceMemory yMemory = VK_NULL_HANDLE;
  VkImageView yView = VK_NULL_HANDLE;

  VkImage uvImage = VK_NULL_HANDLE;
  VkDeviceMemory uvMemory = VK_NULL_HANDLE;
  VkImageView uvView = VK_NULL_HANDLE;

  // Compatibility aliases
  VkImageView imageView = VK_NULL_HANDLE;
  VkImage image = VK_NULL_HANDLE;
  VkDeviceMemory memory = VK_NULL_HANDLE;

  size_t sizeBytes = 0;
  bool isGPUReady = false;
};

class VideoFrameCache : public QObject {
  Q_OBJECT

public:
  static VideoFrameCache &instance() {
    static VideoFrameCache instance;
    return instance;
  }

  [[nodiscard]] bool hasFrame(const QString &assetId, int64_t frameIndex) const;

  std::shared_ptr<CachedFrame>
  getFrame(const QString &assetId, int64_t frameIndex,
           xyla::VulkanVideoDecoder *decoder = nullptr, bool isPlaying = false,
           bool isScrubbing = false, bool isPrefetch = false);

  std::pair<VkImageView, VkImageView>
  getFramePlanes(const QString &assetId, int64_t frameIndex,
                 xyla::VulkanVideoDecoder *decoder, bool isPlaying = false,
                 bool isScrubbing = false, bool isPrefetch = false);

  void setMaxVramMB(size_t maxMegabytes);
  void clearAsset(const QString &assetId);
  void clear();

  int64_t cachedStartFrame() const { return m_cachedStartFrame; }
  int64_t cachedEndFrame() const { return m_cachedEndFrame; }

  QVariantList getCacheRangesForAsset(const QString &assetId) const;

signals:
  void frameReady(const QString &assetId, qint64 frameIndex);
  void cacheRangeChanged(qint64 startFrame, qint64 endFrame);
  void cacheRangesUpdated();

private:
  VideoFrameCache();
  ~VideoFrameCache() override;

  VideoFrameCache(const VideoFrameCache &) = delete;
  VideoFrameCache &operator=(const VideoFrameCache &) = delete;

  void evictIfNeeded();
  void updateCacheRanges();

  mutable std::mutex m_cacheMutex;
  std::unordered_map<QString, std::shared_ptr<CachedFrame>> m_frameMap;
  std::deque<QString> m_lruQueue;

  size_t m_maxVramBytes = 2048ULL * 1024ULL * 1024ULL; // 2GB default
  size_t m_currentVramBytes = 0;

  int64_t m_cachedStartFrame = -1;
  int64_t m_cachedEndFrame = -1;
  QMap<QString, QVariantList> m_cachedRangesPerAsset;
};

} // namespace xyla::render
