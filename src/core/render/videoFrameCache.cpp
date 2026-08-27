#include "videoFrameCache.hpp"
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

void VideoFrameCache::destroyTextureHandle(std::shared_ptr<CachedFrame> frame) {
  if (!frame)
    return;
  VkDevice device = XylaRenderer::instance().device();
  if (device != VK_NULL_HANDLE) {
    if (frame->yView != VK_NULL_HANDLE)
      vkDestroyImageView(device, frame->yView, nullptr);
    if (frame->yMappedPtr && frame->yMemory != VK_NULL_HANDLE)
      vkUnmapMemory(device, frame->yMemory);
    if (frame->yImage != VK_NULL_HANDLE)
      vkDestroyImage(device, frame->yImage, nullptr);
    if (frame->yMemory != VK_NULL_HANDLE)
      vkFreeMemory(device, frame->yMemory, nullptr);

    if (frame->uvView != VK_NULL_HANDLE)
      vkDestroyImageView(device, frame->uvView, nullptr);
    if (frame->uvMappedPtr && frame->uvMemory != VK_NULL_HANDLE)
      vkUnmapMemory(device, frame->uvMemory);
    if (frame->uvImage != VK_NULL_HANDLE)
      vkDestroyImage(device, frame->uvImage, nullptr);
    if (frame->uvMemory != VK_NULL_HANDLE)
      vkFreeMemory(device, frame->uvMemory, nullptr);
  }
}

bool VideoFrameCache::uploadAndCacheFrame(const QString &assetId,
                                          int64_t frameIndex, AVFrame *frame) {
  if (assetId.isEmpty() || frameIndex < 0 || !frame) {
    return false;
  }

  const QString key = QString("%1_%2").arg(assetId).arg(frameIndex);

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
      return true; // Already cached
    }
  }

  uint32_t w = static_cast<uint32_t>(frame->width);
  uint32_t h = static_cast<uint32_t>(frame->height);

  // ZERO-COPY VULKAN IMPORT PATH (AV_PIX_FMT_VULKAN)
  if (frame->format == AV_PIX_FMT_VULKAN && frame->data[0] != nullptr) {
    auto *vkf = reinterpret_cast<AVVkFrame *>(frame->data[0]);
    if (vkf && vkf->img[0] != VK_NULL_HANDLE) {
      VkImage yImg = vkf->img[0];
      VkImage uvImg =
          (vkf->img[1] != VK_NULL_HANDLE) ? vkf->img[1] : vkf->img[0];

      VkImageView yView = XylaRenderer::instance().createImageViewForImage(
          yImg, VK_FORMAT_R8_UNORM);
      VkImageView uvView = XylaRenderer::instance().createImageViewForImage(
          uvImg, VK_FORMAT_R8G8_UNORM);

      if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
        auto cached = std::make_shared<CachedFrame>();
        cached->assetId = assetId;
        cached->frameIndex = frameIndex;
        cached->width = w;
        cached->height = h;

        cached->yImage = yImg;
        cached->yMemory = VK_NULL_HANDLE;
        cached->yView = yView;

        cached->uvImage = uvImg;
        cached->uvMemory = VK_NULL_HANDLE;
        cached->uvView = uvView;

        cached->imageView = yView;
        cached->image = yImg;

        cached->sizeBytes = static_cast<size_t>(w * h * 1.5);
        cached->isGPUReady = true;

        {
          std::lock_guard<std::mutex> lock(m_cacheMutex);
          m_frameMap[key] = cached;
          m_lruQueue.push_back(key);
          m_currentVramBytes += cached->sizeBytes;
        }

        evictIfNeeded();
        updateCacheRanges();
        emit frameReady(assetId, frameIndex);
        return true;
      }
    }
  }

  if (!frame->data[0] || !frame->data[1]) {
    return false;
  }

  // RECYCLED VULKAN HANDLE POOL PATH (0.2ms staging copy)
  PooledTexture pooledItem;
  bool reusedFromPool = false;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    for (auto it = m_texturePool.begin(); it != m_texturePool.end(); ++it) {
      if (it->width == w && it->height == h) {
        pooledItem = *it;
        m_texturePool.erase(it);
        reusedFromPool = true;
        break;
      }
    }
  }

  if (reusedFromPool) {
    bool ok = XylaRenderer::instance().uploadToExistingYuvTextures(
        frame->data[0], frame->linesize[0], frame->data[1], frame->linesize[1],
        w, h, pooledItem.yImage, pooledItem.uvImage);

    if (ok) {
      auto cached = std::make_shared<CachedFrame>();
      cached->assetId = assetId;
      cached->frameIndex = frameIndex;
      cached->width = w;
      cached->height = h;

      cached->yImage = pooledItem.yImage;
      cached->yMemory = pooledItem.yMemory;
      cached->yView = pooledItem.yView;

      cached->uvImage = pooledItem.uvImage;
      cached->uvMemory = pooledItem.uvMemory;
      cached->uvView = pooledItem.uvView;

      cached->imageView = pooledItem.yView;
      cached->image = pooledItem.yImage;
      cached->memory = pooledItem.yMemory;

      cached->sizeBytes = pooledItem.sizeBytes;
      cached->isGPUReady = true;

      {
        std::lock_guard<std::mutex> lock(m_cacheMutex);
        m_frameMap[key] = cached;
        m_lruQueue.push_back(key);
        m_currentVramBytes += cached->sizeBytes;
      }

      evictIfNeeded();
      updateCacheRanges();
      emit frameReady(assetId, frameIndex);
      return true;
    }
  }

  // COLD START FALLBACK PATH
  VkImage yImg = VK_NULL_HANDLE, uvImg = VK_NULL_HANDLE;
  VkDeviceMemory yMem = VK_NULL_HANDLE, uvMem = VK_NULL_HANDLE;
  VkImageView yView = VK_NULL_HANDLE, uvView = VK_NULL_HANDLE;

  bool ok = XylaRenderer::instance().allocateAndUploadYuvTextures(
      frame->data[0], frame->linesize[0], frame->data[1], frame->linesize[1], w,
      h, &yImg, &yMem, &yView, &uvImg, &uvMem, &uvView);

  if (ok && yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
    auto cached = std::make_shared<CachedFrame>();
    cached->assetId = assetId;
    cached->frameIndex = frameIndex;
    cached->width = w;
    cached->height = h;

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

    {
      std::lock_guard<std::mutex> lock(m_cacheMutex);
      m_frameMap[key] = cached;
      m_lruQueue.push_back(key);
      m_currentVramBytes += cached->sizeBytes;
    }

    evictIfNeeded();
    updateCacheRanges();
    emit frameReady(assetId, frameIndex);
    return true;
  }

  return false;
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

        if (m_texturePool.size() < kMaxPooledTextures &&
            it->second->isGPUReady) {
          PooledTexture item;
          item.width = it->second->width;
          item.height = it->second->height;
          item.yImage = it->second->yImage;
          item.yMemory = it->second->yMemory;
          item.yView = it->second->yView;
          item.yMappedPtr = it->second->yMappedPtr;

          item.uvImage = it->second->uvImage;
          item.uvMemory = it->second->uvMemory;
          item.uvView = it->second->uvView;
          item.uvMappedPtr = it->second->uvMappedPtr;

          item.sizeBytes = it->second->sizeBytes;
          m_texturePool.push_back(item);
        } else {
          framesToDestroy.push_back(it->second);
        }

        m_frameMap.erase(it);
      }
    }
  }

  for (auto &frame : framesToDestroy) {
    destroyTextureHandle(frame);
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

  bool changed = false;
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    if (m_cachedRangesPerAsset != newRangesPerAsset) {
      m_cachedRangesPerAsset = newRangesPerAsset;
      m_cachedStartFrame = globalMin;
      m_cachedEndFrame = globalMax;
      changed = true;
    }
  }

  if (changed) {
    emit cacheRangeChanged(globalMin, globalMax);
    emit cacheRangesUpdated();
  }
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

  // 2. Reject background prefetch calls during active playback or scrubbing
  if (isPrefetch && (isPlaying || isScrubbing)) {
    return {VK_NULL_HANDLE, VK_NULL_HANDLE};
  }

  // 3. Fast Scrubbing Fallback View (Instant non-blocking preview)
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

    if (isPlaying) {
      // PLAYBACK MODE: If UI ticks dropped 1-5 frames, catch up sequentially
      if (frameIndex > currentIdx && frameIndex <= currentIdx + 5) {
        while (decoder->currentFrameIndex() < frameIndex) {
          int64_t nextIdx = decoder->currentFrameIndex() + 1;
          if (!decoder->decodeNextFrame())
            break;
          uploadAndCacheFrame(assetId, nextIdx, decoder->currentFrame());
        }
      } else if (currentIdx == frameIndex) {
        uploadAndCacheFrame(assetId, frameIndex, decoder->currentFrame());
      } else {
        if (!isPrefetch && decoder->seekToFrame(frameIndex, true)) {
          uploadAndCacheFrame(assetId, decoder->currentFrameIndex(),
                              decoder->currentFrame());
        }
      }
    } else if (isScrubbing) {
      // FAST SCRUBBING MODE: Capped forward catchup (max 10 frames)
      if (frameIndex > currentIdx && frameIndex <= currentIdx + 10) {
        while (decoder->currentFrameIndex() < frameIndex) {
          if (!decoder->decodeNextFrame())
            break;
        }
        uploadAndCacheFrame(assetId, decoder->currentFrameIndex(),
                            decoder->currentFrame());
      } else if (currentIdx == frameIndex) {
        uploadAndCacheFrame(assetId, frameIndex, decoder->currentFrame());
      } else {
        if (!isPrefetch) {
          // Fast Keyframe Seek (precise = false) for jumps > 10 frames
          if (decoder->seekToFrame(frameIndex, /*precise=*/false)) {
            uploadAndCacheFrame(assetId, decoder->currentFrameIndex(),
                                decoder->currentFrame());
          }
        }
      }
    } else {
      // PAUSED MODE: Precise seek to target frame
      if (currentIdx == frameIndex) {
        uploadAndCacheFrame(assetId, frameIndex, decoder->currentFrame());
      } else {
        if (!isPrefetch && decoder->seekToFrame(frameIndex, /*precise=*/true)) {
          uploadAndCacheFrame(assetId, decoder->currentFrameIndex(),
                              decoder->currentFrame());
        }
      }
    }

    // --- FIX: CHECK BOTH REQUESTED FRAME AND ACTUAL DECODED KEYFRAME ---
    int64_t actualDecodedIndex = decoder->currentFrameIndex();
    const QString actualKey =
        QString("%1_%2").arg(assetId).arg(actualDecodedIndex);

    {
      std::lock_guard<std::mutex> lock(m_cacheMutex);

      // 1. Exact requested frame key
      auto it = m_frameMap.find(key);
      if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
        return {it->second->yView, it->second->uvView};
      }

      // 2. Actual decoded keyframe key (so XylaRenderer::renderFrame is ALWAYS
      // called)
      auto actualIt = m_frameMap.find(actualKey);
      if (actualIt != m_frameMap.end() && actualIt->second &&
          actualIt->second->isGPUReady) {
        return {actualIt->second->yView, actualIt->second->uvView};
      }
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

  for (auto &frame : framesToDestroy) {
    destroyTextureHandle(frame);
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

    for (auto &pooled : m_texturePool) {
      auto dummy = std::make_shared<CachedFrame>();
      dummy->yImage = pooled.yImage;
      dummy->yMemory = pooled.yMemory;
      dummy->yView = pooled.yView;
      dummy->yMappedPtr = pooled.yMappedPtr;

      dummy->uvImage = pooled.uvImage;
      dummy->uvMemory = pooled.uvMemory;
      dummy->uvView = pooled.uvView;
      dummy->uvMappedPtr = pooled.uvMappedPtr;

      destroyTextureHandle(dummy);
    }
    m_texturePool.clear();

    m_currentVramBytes = 0;
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRangesPerAsset.clear();
  }

  for (auto &frame : framesToDestroy) {
    destroyTextureHandle(frame);
  }

  emit cacheRangeChanged(-1, -1);
  emit cacheRangesUpdated();
}

} // namespace xyla::render
