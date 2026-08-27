#include "videoFrameCache.hpp"
#include "core/log/logger.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "xylaRenderer.hpp"
#include <algorithm>
#include <cmath>
#include <vector>

namespace xyla::render {

VideoFrameCache::VideoFrameCache() = default;
VideoFrameCache::~VideoFrameCache() = default;

bool VideoFrameCache::hasFrame(const QString &assetId,
                               int64_t frameIndex) const {
  if (assetId.isEmpty() || frameIndex < 0)
    return false;

  const QString key = QString("%1_%2").arg(assetId).arg(frameIndex);
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  auto it = m_frameMap.find(key);
  return (it != m_frameMap.end() && it->second && it->second->isGPUReady);
}

std::shared_ptr<CachedFrame>
VideoFrameCache::getFrame(const QString &assetId, int64_t frameIndex,
                          xyla::VulkanVideoDecoder *decoder, bool isPlaying,
                          bool isScrubbing, bool isPrefetch) {
  if (assetId.isEmpty() || frameIndex < 0) {
    return nullptr;
  }

  const QString key = QString("%1_%2").arg(assetId).arg(frameIndex);

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
      return it->second;
    }
  }

  auto [yView, uvView] = getFramePlanes(assetId, frameIndex, decoder, isPlaying,
                                        isScrubbing, isPrefetch);
  if (yView == VK_NULL_HANDLE) {
    return nullptr;
  }

  std::lock_guard<std::mutex> lock(m_cacheMutex);
  auto it = m_frameMap.find(key);
  if (it != m_frameMap.end()) {
    return it->second;
  }
  return nullptr;
}

void VideoFrameCache::evictIfNeeded() {
  std::vector<std::shared_ptr<CachedFrame>> framesToDestroy;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    if (m_currentVramBytes <= m_maxVramBytes)
      return;

    while (m_currentVramBytes > m_maxVramBytes && !m_lruQueue.empty()) {
      QString keyToEvict = m_lruQueue.front();
      m_lruQueue.pop_front();

      auto it = m_frameMap.find(keyToEvict);
      if (it != m_frameMap.end()) {
        m_currentVramBytes -=
            std::min(m_currentVramBytes, it->second->sizeBytes);
        framesToDestroy.push_back(it->second);
        m_frameMap.erase(it);
      }
    }
  }

  // Destroy Vulkan resources OUTSIDE the mutex lock
  VkDevice device = XylaRenderer::instance().device();
  if (device != VK_NULL_HANDLE) {
    for (auto &frame : framesToDestroy) {
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

  if (!framesToDestroy.empty()) {
    updateCacheRanges();
  }
}

void VideoFrameCache::updateCacheRanges() {
  std::unordered_map<QString, std::vector<int64_t>> assetFrames;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    for (const auto &[key, cachedFrame] : m_frameMap) {
      if (cachedFrame && cachedFrame->isGPUReady) {
        assetFrames[cachedFrame->assetId].push_back(cachedFrame->frameIndex);
      }
    }
  }

  QMap<QString, QVariantList> newRangesPerAsset;
  int64_t globalMin = -1;
  int64_t globalMax = -1;

  for (auto &[assetId, frames] : assetFrames) {
    if (frames.empty())
      continue;
    std::sort(frames.begin(), frames.end());

    QVariantList rangeList;
    int64_t segStart = frames[0];
    int64_t segEnd = frames[0];

    if (globalMin == -1 || frames.front() < globalMin)
      globalMin = frames.front();
    if (globalMax == -1 || frames.back() > globalMax)
      globalMax = frames.back();

    for (size_t i = 1; i < frames.size(); ++i) {
      if (frames[i] == segEnd + 1) {
        segEnd = frames[i];
      } else {
        QVariantMap seg;
        seg["start"] = static_cast<qlonglong>(segStart);
        seg["end"] = static_cast<qlonglong>(segEnd);
        rangeList.append(seg);

        segStart = frames[i];
        segEnd = frames[i];
      }
    }
    QVariantMap seg;
    seg["start"] = static_cast<qlonglong>(segStart);
    seg["end"] = static_cast<qlonglong>(segEnd);
    rangeList.append(seg);

    newRangesPerAsset[assetId] = rangeList;
  }

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    m_cachedRangesPerAsset = newRangesPerAsset;
    m_cachedStartFrame = globalMin;
    m_cachedEndFrame = globalMax;
  }

  emit cacheRangeChanged(globalMin, globalMax);
  emit cacheRangesUpdated();
}

QVariantList
VideoFrameCache::getCacheRangesForAsset(const QString &assetId) const {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  return m_cachedRangesPerAsset.value(assetId, QVariantList());
}

std::pair<VkImageView, VkImageView>
VideoFrameCache::getFramePlanes(const QString &assetId, int64_t frameIndex,
                                xyla::VulkanVideoDecoder *decoder,
                                bool isPlaying, bool isScrubbing,
                                bool isPrefetch) {
  if (assetId.isEmpty() || frameIndex < 0) {
    return {VK_NULL_HANDLE, VK_NULL_HANDLE};
  }

  const QString key = QString("%1_%2").arg(assetId).arg(frameIndex);

  // 1. Instant VRAM Cache Hit (<0.01ms)
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
      auto lruIt = std::find(m_lruQueue.begin(), m_lruQueue.end(), key);
      if (lruIt != m_lruQueue.end()) {
        m_lruQueue.erase(lruIt);
      }
      m_lruQueue.push_back(key);

      return {it->second->yView, it->second->uvView};
    }
  }

  // 2. Reject background prefetch calls during active playback
  if (isPrefetch && isPlaying) {
    return {VK_NULL_HANDLE, VK_NULL_HANDLE};
  }

  // 3. Fast Scrubbing Fallback View (Non-blocking preview)
  std::pair<VkImageView, VkImageView> scrubFallbackViews = {VK_NULL_HANDLE,
                                                            VK_NULL_HANDLE};
  if (isScrubbing) {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    int64_t minDistance = 999999;

    for (const auto &[k, frame] : m_frameMap) {
      if (frame && frame->assetId == assetId && frame->isGPUReady) {
        int64_t dist = std::abs(frame->frameIndex - frameIndex);
        if (dist < minDistance) {
          minDistance = dist;
          scrubFallbackViews = {frame->yView, frame->uvView};
        }
      }
    }
  }

  // 4. Synchronous Decode & Cache Path
  if (decoder) {
    int64_t currentIdx = decoder->currentFrameIndex();

    if (currentIdx == frameIndex) {
      // Decoder sits on target frame
    } else if (currentIdx + 1 == frameIndex) {
      if (!decoder->decodeNextFrame()) {
        return scrubFallbackViews;
      }
    } else {
      if (isPrefetch) {
        return {VK_NULL_HANDLE, VK_NULL_HANDLE};
      }
      if (!decoder->seekToFrame(frameIndex)) {
        return scrubFallbackViews;
      }
    }

    AVFrame *frame = decoder->currentFrame();
    if (!frame || !frame->data[0] || !frame->data[1]) {
      return scrubFallbackViews;
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
      VkImageView resultYView = yView;
      VkImageView resultUVView = uvView;

      {
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
      }

      evictIfNeeded();
      updateCacheRanges();
      emit frameReady(assetId, frameIndex);

      return {resultYView, resultUVView};
    }
  }

  return scrubFallbackViews;
}

void VideoFrameCache::setMaxVramMB(size_t maxMegabytes) {
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    m_maxVramBytes = maxMegabytes * 1024ULL * 1024ULL;
  }
  evictIfNeeded();
}

void VideoFrameCache::clearAsset(const QString &assetId) {
  std::vector<std::shared_ptr<CachedFrame>> framesToDestroy;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    for (auto it = m_frameMap.begin(); it != m_frameMap.end();) {
      if (it->second->assetId == assetId) {
        m_currentVramBytes -=
            std::min(m_currentVramBytes, it->second->sizeBytes);

        auto lruIt = std::find(m_lruQueue.begin(), m_lruQueue.end(), it->first);
        if (lruIt != m_lruQueue.end()) {
          m_lruQueue.erase(lruIt);
        }

        framesToDestroy.push_back(it->second);
        it = m_frameMap.erase(it);
      } else {
        ++it;
      }
    }
  }

  VkDevice device = XylaRenderer::instance().device();
  if (device != VK_NULL_HANDLE) {
    for (auto &frame : framesToDestroy) {
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

  updateCacheRanges();
}

void VideoFrameCache::clear() {
  std::vector<std::shared_ptr<CachedFrame>> framesToDestroy;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    for (auto &[key, frame] : m_frameMap) {
      framesToDestroy.push_back(frame);
    }
    m_frameMap.clear();
    m_lruQueue.clear();
    m_currentVramBytes = 0;
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRangesPerAsset.clear();
  }

  VkDevice device = XylaRenderer::instance().device();
  if (device != VK_NULL_HANDLE) {
    for (auto &frame : framesToDestroy) {
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

  emit cacheRangeChanged(-1, -1);
  emit cacheRangesUpdated();
}

} // namespace xyla::render
