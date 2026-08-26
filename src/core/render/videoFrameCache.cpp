#include "videoFrameCache.hpp"
#include "core/log/logger.hpp"
#include "xylaRenderer.hpp"
#include <algorithm>
#include <cmath>

namespace xyla::render {

VideoFrameCache::VideoFrameCache() = default;
VideoFrameCache::~VideoFrameCache() = default;

void VideoFrameCache::evictIfNeeded() {
  if (m_currentVramBytes <= m_maxVramBytes)
    return;

  int64_t currentPlayhead = 0;
  if (!m_lruQueue.empty()) {
    QString lastKey = m_lruQueue.back();
    int idx = lastKey.lastIndexOf('_');
    if (idx != -1) {
      currentPlayhead = lastKey.mid(idx + 1).toLongLong();
    }
  }

  VkDevice device = XylaRenderer::instance().device();

  while (m_currentVramBytes > m_maxVramBytes && !m_frameMap.empty()) {
    QString farthestKey;
    int64_t maxDist = -1;

    for (const auto &[key, frame] : m_frameMap) {
      int64_t dist = std::abs(frame->frameIndex - currentPlayhead);
      if (dist > maxDist) {
        maxDist = dist;
        farthestKey = key;
      }
    }

    if (!farthestKey.isEmpty()) {
      auto it = m_frameMap.find(farthestKey);
      if (it != m_frameMap.end()) {
        if (device != VK_NULL_HANDLE) {
          if (it->second->yView != VK_NULL_HANDLE)
            vkDestroyImageView(device, it->second->yView, nullptr);
          if (it->second->yImage != VK_NULL_HANDLE)
            vkDestroyImage(device, it->second->yImage, nullptr);
          if (it->second->yMemory != VK_NULL_HANDLE)
            vkFreeMemory(device, it->second->yMemory, nullptr);

          if (it->second->uvView != VK_NULL_HANDLE)
            vkDestroyImageView(device, it->second->uvView, nullptr);
          if (it->second->uvImage != VK_NULL_HANDLE)
            vkDestroyImage(device, it->second->uvImage, nullptr);
          if (it->second->uvMemory != VK_NULL_HANDLE)
            vkFreeMemory(device, it->second->uvMemory, nullptr);
        }
        m_currentVramBytes -=
            std::min(m_currentVramBytes, it->second->sizeBytes);
        m_frameMap.erase(it);

        auto lruIt =
            std::find(m_lruQueue.begin(), m_lruQueue.end(), farthestKey);
        if (lruIt != m_lruQueue.end()) {
          m_lruQueue.erase(lruIt);
        }
      }
    } else {
      break;
    }
  }

  updateCacheRange();
}

void VideoFrameCache::updateCacheRange() {
  int64_t minFrame = -1;
  int64_t maxFrame = -1;

  for (const auto &[key, cachedFrame] : m_frameMap) {
    if (cachedFrame && cachedFrame->isGPUReady) {
      if (minFrame == -1 || cachedFrame->frameIndex < minFrame) {
        minFrame = cachedFrame->frameIndex;
      }
      if (maxFrame == -1 || cachedFrame->frameIndex > maxFrame) {
        maxFrame = cachedFrame->frameIndex;
      }
    }
  }

  if (m_cachedStartFrame != minFrame || m_cachedEndFrame != maxFrame) {
    m_cachedStartFrame = minFrame;
    m_cachedEndFrame = maxFrame;
    emit cacheRangeChanged(m_cachedStartFrame, m_cachedEndFrame);
  }
}

std::pair<VkImageView, VkImageView>
VideoFrameCache::getFramePlanes(const QString &assetId, int64_t frameIndex,
                                VulkanVideoDecoder *decoder, bool isPlaying,
                                bool allowBlockingDecode) {
  Q_UNUSED(isPlaying);
  if (assetId.isEmpty() || frameIndex < 0)
    return {VK_NULL_HANDLE, VK_NULL_HANDLE};

  QString key = QString("%1_%2").arg(assetId).arg(frameIndex);

  // 1. Exact VRAM Cache Hit (<0.01ms)
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second->isGPUReady) {
      return {it->second->yView, it->second->uvView};
    }
  }

  // 2. Non-blocking UI Path: If exact frame isn't ready, return nearest cached
  // frame so UI never flashes black
  if (!allowBlockingDecode) {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    int64_t bestFrame = -1;
    int64_t minDistance = 999999;
    std::pair<VkImageView, VkImageView> nearestViews = {VK_NULL_HANDLE,
                                                        VK_NULL_HANDLE};

    for (const auto &[k, frame] : m_frameMap) {
      if (frame && frame->assetId == assetId && frame->isGPUReady) {
        int64_t dist = std::abs(frame->frameIndex - frameIndex);
        if (dist < minDistance) {
          minDistance = dist;
          bestFrame = frame->frameIndex;
          nearestViews = {frame->yView, frame->uvView};
        }
      }
    }

    // Return nearest cached frame if within 45 frames (~1.5 sec)
    if (bestFrame != -1 && minDistance <= 45) {
      return nearestViews;
    }

    return {VK_NULL_HANDLE, VK_NULL_HANDLE};
  }

  // 3. Background Thread Decode Path
  if (decoder) {
    if (!decoder->seekToFrame(frameIndex)) {
      return {VK_NULL_HANDLE, VK_NULL_HANDLE};
    }

    AVFrame *frame = decoder->currentFrame();
    if (!frame || !frame->data[0] || !frame->data[1]) {
      return {VK_NULL_HANDLE, VK_NULL_HANDLE};
    }

    uint32_t w = static_cast<uint32_t>(frame->width);
    uint32_t h = static_cast<uint32_t>(frame->height);

    VkImage yImg = VK_NULL_HANDLE, uvImg = VK_NULL_HANDLE;
    VkDeviceMemory yMem = VK_NULL_HANDLE, uvMem = VK_NULL_HANDLE;
    VkImageView yView = VK_NULL_HANDLE, uvView = VK_NULL_HANDLE;

    bool ok = XylaRenderer::instance().allocateAndUploadYuvTextures(
        frame->data[0], frame->linesize[0], frame->data[1], frame->linesize[1],
        w, h, &yImg, &yMem, &yView, &uvImg, &uvMem, &uvView);

    if (ok && yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
      std::lock_guard<std::mutex> lock(m_cacheMutex);

      auto existing = m_frameMap.find(key);
      if (existing != m_frameMap.end() && existing->second->isGPUReady) {
        VkDevice dev = XylaRenderer::instance().device();
        vkDestroyImageView(dev, yView, nullptr);
        vkDestroyImage(dev, yImg, nullptr);
        vkFreeMemory(dev, yMem, nullptr);
        vkDestroyImageView(dev, uvView, nullptr);
        vkDestroyImage(dev, uvImg, nullptr);
        vkFreeMemory(dev, uvMem, nullptr);
        return {existing->second->yView, existing->second->uvView};
      }

      auto cached = std::make_shared<CachedFrame>();
      cached->assetId = assetId;
      cached->frameIndex = frameIndex;

      cached->yImage = yImg;
      cached->yMemory = yMem;
      cached->yView = yView;

      cached->uvImage = uvImg;
      cached->uvMemory = uvMem;
      cached->uvView = uvView;

      cached->imageView = yView;
      cached->image = yImg;
      cached->memory = yMem;

      cached->sizeBytes = static_cast<size_t>(w * h * 1.5);
      cached->isGPUReady = true;

      m_frameMap[key] = cached;
      m_lruQueue.push_back(key);
      m_currentVramBytes += cached->sizeBytes;

      evictIfNeeded();
      updateCacheRange();
      emit frameReady(assetId, frameIndex);

      return {cached->yView, cached->uvView};
    }
  }

  return {VK_NULL_HANDLE, VK_NULL_HANDLE};
}

void VideoFrameCache::setMaxVramMB(size_t maxMegabytes) {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  m_maxVramBytes = maxMegabytes * 1024ULL * 1024ULL;
  evictIfNeeded();
}

void VideoFrameCache::clearAsset(const QString &assetId) {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  VkDevice device = XylaRenderer::instance().device();

  for (auto it = m_frameMap.begin(); it != m_frameMap.end();) {
    if (it->second->assetId == assetId) {
      if (device != VK_NULL_HANDLE) {
        if (it->second->yView != VK_NULL_HANDLE)
          vkDestroyImageView(device, it->second->yView, nullptr);
        if (it->second->yImage != VK_NULL_HANDLE)
          vkDestroyImage(device, it->second->yImage, nullptr);
        if (it->second->yMemory != VK_NULL_HANDLE)
          vkFreeMemory(device, it->second->yMemory, nullptr);

        if (it->second->uvView != VK_NULL_HANDLE)
          vkDestroyImageView(device, it->second->uvView, nullptr);
        if (it->second->uvImage != VK_NULL_HANDLE)
          vkDestroyImage(device, it->second->uvImage, nullptr);
        if (it->second->uvMemory != VK_NULL_HANDLE)
          vkFreeMemory(device, it->second->uvMemory, nullptr);
      }
      m_currentVramBytes -= std::min(m_currentVramBytes, it->second->sizeBytes);

      auto lruIt = std::find(m_lruQueue.begin(), m_lruQueue.end(), it->first);
      if (lruIt != m_lruQueue.end()) {
        m_lruQueue.erase(lruIt);
      }

      it = m_frameMap.erase(it);
    } else {
      ++it;
    }
  }
  updateCacheRange();
}

void VideoFrameCache::clear() {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  VkDevice device = XylaRenderer::instance().device();

  if (device != VK_NULL_HANDLE) {
    for (auto &[key, frame] : m_frameMap) {
      if (frame->yView != VK_NULL_HANDLE)
        vkDestroyImageView(device, frame->yView, nullptr);
      if (frame->yImage != VK_NULL_HANDLE)
        vkDestroyImage(device, frame->yImage, nullptr);
      if (frame->yMemory != VK_NULL_HANDLE)
        vkFreeMemory(device, frame->yMemory, nullptr);

      if (frame->uvView != VK_NULL_HANDLE)
        vkDestroyImageView(device, frame->uvView, nullptr);
      if (frame->uvImage != VK_NULL_HANDLE)
        vkDestroyImage(device, frame->uvImage, nullptr);
      if (frame->uvMemory != VK_NULL_HANDLE)
        vkFreeMemory(device, frame->uvMemory, nullptr);
    }
  }

  m_frameMap.clear();
  m_lruQueue.clear();
  m_currentVramBytes = 0;
  m_cachedStartFrame = -1;
  m_cachedEndFrame = -1;
  emit cacheRangeChanged(-1, -1);
}

} // namespace xyla::render
