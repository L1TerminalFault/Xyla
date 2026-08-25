#include "videoFrameCache.hpp"
#include "core/log/logger.hpp"

namespace xyla::render {

VideoFrameCache::~VideoFrameCache() { clear(); }

VkImageView VideoFrameCache::getFrame(const QString &assetId,
                                      int64_t frameIndex,
                                      VulkanVideoDecoder *decoder) {
  std::lock_guard<std::mutex> lock(m_cacheMutex);

  QString key = QString("%1_%2").arg(assetId).arg(frameIndex);
  auto it = m_frameMap.find(key);

  if (it != m_frameMap.end() && it->second->isGPUReady) {
    return it->second->imageView; // vram cache hit happy :)
  }

  // cache miss :<
  if (decoder) {
    // In production: Queue background decode task and return previous frame or
    // placeholder
  }

  return VK_NULL_HANDLE;
}

void VideoFrameCache::prefetchFrames(const QString &assetId, int64_t startFrame,
                                     int count, VulkanVideoDecoder *decoder) {
  if (!decoder)
    return;
  // Dispatches pre-fetch work to worker thread for upcoming frames (T+1 to
  // T+count)
}

void VideoFrameCache::setMaxVramMB(size_t maxMegabytes) {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  m_maxVramBytes = maxMegabytes * 1024 * 1024;
}

void VideoFrameCache::clear() {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  m_frameMap.clear();
  m_lruQueue.clear();
  m_currentVramBytes = 0;
}

} // namespace xyla::render
