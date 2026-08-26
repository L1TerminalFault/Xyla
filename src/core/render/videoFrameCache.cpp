#include "videoFrameCache.hpp"
#include "xylaRenderer.hpp"

namespace xyla::render {

// Retrieves cached GPU texture view or decodes frame on demand with slot
// eviction sync
VkImageView VideoFrameCache::getFrame(const QString &assetId,
                                      int64_t frameIndex,
                                      VulkanVideoDecoder *decoder,
                                      bool isPlaying) {
  Q_UNUSED(isPlaying);
  std::lock_guard<std::mutex> lock(m_cacheMutex);

  QString key = QString("%1_%2").arg(assetId).arg(frameIndex);
  auto it = m_frameMap.find(key);

  if (it != m_frameMap.end() && it->second->isGPUReady) {
    return it->second->imageView;
  }

  if (decoder) {
    bool seekOk = decoder->seekToFrame(frameIndex);
    if (!seekOk) {
      return VK_NULL_HANDLE;
    }

    QImage decodedImg = decoder->getDecodedQImage();
    if (decodedImg.isNull()) {
      return VK_NULL_HANDLE;
    }

    size_t slotIndex = static_cast<size_t>(frameIndex % kRingSlots);
    QString previousOwner = m_slotOwners[slotIndex];

    if (!previousOwner.isEmpty() && previousOwner != key) {
      m_frameMap.erase(previousOwner);
    }

    VkImageView view = XylaRenderer::instance().uploadTexture(
        decodedImg, static_cast<uint64_t>(frameIndex));

    if (view != VK_NULL_HANDLE) {
      auto cached = std::make_shared<CachedFrame>();
      cached->assetId = assetId;
      cached->frameIndex = frameIndex;
      cached->image = VK_NULL_HANDLE;
      cached->imageView = view;
      cached->isGPUReady = true;

      m_slotOwners[slotIndex] = key;
      m_frameMap[key] = cached;

      return cached->imageView;
    }
  }

  return VK_NULL_HANDLE;
}

// Evicts oldest cached GPU textures when exceeding memory budget
void VideoFrameCache::evictIfNeeded() {
  if (m_frameMap.size() > kRingSlots) {
    m_frameMap.clear();
  }
}

// Adjusts dynamic VRAM allocation ceiling in MB
void VideoFrameCache::setMaxVramMB(size_t maxMegabytes) {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  m_maxVramBytes = maxMegabytes * 1024ULL * 1024ULL;
  evictIfNeeded();
}

// Destroys all cached Vulkan image views and clears VRAM map
void VideoFrameCache::clear() {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  m_frameMap.clear();
  m_slotOwners.fill({});
  m_currentVramBytes = 0;
}

} // namespace xyla::render
