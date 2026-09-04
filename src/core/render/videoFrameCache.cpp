#include "videoFrameCache.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/memory/xylaArena.hpp"
#include "xylaRenderer.hpp"
#include <algorithm>
#include <vector>

namespace xyla::render {

static constexpr size_t kMaxCachedFramesTotal = 40;
static constexpr size_t kMaxPoolTexturesMax = 8;

VideoFrameCache &VideoFrameCache::instance() {
  static VideoFrameCache cache;
  return cache;
}

VideoFrameCache::VideoFrameCache() {
  m_maxVramBytes = 2000ULL * 1024ULL * 1024ULL;
}

VideoFrameCache::~VideoFrameCache() { clear(); }

bool VideoFrameCache::hasFrame(const QString &assetId,
                               int64_t frameIndex) const {
  if (assetId.isEmpty() || frameIndex < 0)
    return false;

  FrameKey key{assetId, frameIndex};
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  auto it = m_frameMap.find(key);
  return (it != m_frameMap.end() && it->second && it->second->isGPUReady);
}

void VideoFrameCache::destroyTextureHandle(std::shared_ptr<CachedFrame> frame) {
  if (!frame)
    return;
  VkDevice device = XylaRenderer::instance().device();
  if (device != VK_NULL_HANDLE) {
    if (frame->yView != VK_NULL_HANDLE) {
      vkDestroyImageView(device, frame->yView, nullptr);
      frame->yView = VK_NULL_HANDLE;
    }
    if (frame->yMappedPtr && frame->yMemory != VK_NULL_HANDLE) {
      vkUnmapMemory(device, frame->yMemory);
      frame->yMappedPtr = nullptr;
    }
    if (frame->yImage != VK_NULL_HANDLE) {
      vkDestroyImage(device, frame->yImage, nullptr);
      frame->yImage = VK_NULL_HANDLE;
    }
    if (frame->yMemory != VK_NULL_HANDLE) {
      vkFreeMemory(device, frame->yMemory, nullptr);
      frame->yMemory = VK_NULL_HANDLE;
    }

    if (frame->uvView != VK_NULL_HANDLE) {
      vkDestroyImageView(device, frame->uvView, nullptr);
      frame->uvView = VK_NULL_HANDLE;
    }
    if (frame->uvMappedPtr && frame->uvMemory != VK_NULL_HANDLE) {
      vkUnmapMemory(device, frame->uvMemory);
      frame->uvMappedPtr = nullptr;
    }
    if (frame->uvImage != VK_NULL_HANDLE) {
      vkDestroyImage(device, frame->uvImage, nullptr);
      frame->uvImage = VK_NULL_HANDLE;
    }
    if (frame->uvMemory != VK_NULL_HANDLE) {
      vkFreeMemory(device, frame->uvMemory, nullptr);
      frame->uvMemory = VK_NULL_HANDLE;
    }
  }
}

void VideoFrameCache::ensureCapacityForBytes(size_t requiredBytes) {
  std::vector<std::shared_ptr<CachedFrame>> framesToDestroy;

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);

    while ((m_currentVramBytes + requiredBytes > m_maxVramBytes ||
            m_frameMap.size() >= kMaxCachedFramesTotal) &&
           !m_texturePool.empty()) {
      auto pooled = m_texturePool.back();
      m_texturePool.pop_back();

      auto dummy = std::make_shared<CachedFrame>();
      dummy->yImage = pooled.yImage;
      dummy->yMemory = pooled.yMemory;
      dummy->yView = pooled.yView;
      dummy->uvImage = pooled.uvImage;
      dummy->uvMemory = pooled.uvMemory;
      dummy->uvView = pooled.uvView;
      framesToDestroy.push_back(dummy);
    }

    while ((m_currentVramBytes + requiredBytes > m_maxVramBytes ||
            m_frameMap.size() >= kMaxCachedFramesTotal) &&
           !m_lruList.empty()) {
      FrameKey keyToEvict = m_lruList.front();
      m_lruList.pop_front();

      auto it = m_frameMap.find(keyToEvict);
      if (it != m_frameMap.end()) {
        m_currentVramBytes -=
            std::min(m_currentVramBytes, it->second->sizeBytes);
        m_assetFrameMap[it->second->assetId].erase(it->second->frameIndex);

        if (m_texturePool.size() < kMaxPoolTexturesMax &&
            it->second->isGPUReady) {
          PooledTexture item;
          item.width = it->second->width;
          item.height = it->second->height;
          item.yImage = it->second->yImage;
          item.yMemory = it->second->yMemory;
          item.yView = it->second->yView;
          item.uvImage = it->second->uvImage;
          item.uvMemory = it->second->uvMemory;
          item.uvView = it->second->uvView;
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

bool VideoFrameCache::uploadAndCacheFrame(const QString &assetId,
                                          int64_t frameIndex, AVFrame *frame) {
  if (assetId.isEmpty() || frameIndex < 0 || !frame || !frame->data[0] ||
      frame->width <= 0 || frame->height <= 0) {
    return false;
  }

  FrameKey key{assetId, frameIndex};

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
      return true;
    }
  }

  AVFrame *safeFrame = av_frame_clone(frame);
  if (!safeFrame) {
    return false;
  }

  uint32_t w = static_cast<uint32_t>(safeFrame->width);
  uint32_t h = static_cast<uint32_t>(safeFrame->height);

  const uint8_t *yData = safeFrame->data[0];
  int yPitch = safeFrame->linesize[0];
  const uint8_t *uvData = safeFrame->data[1];
  int uvPitch = safeFrame->linesize[1];

  std::vector<uint8_t> interleavedUV;

  bool isPlanar420 = (safeFrame->format == AV_PIX_FMT_YUV420P ||
                      safeFrame->format == AV_PIX_FMT_YUVJ420P);

  if (isPlanar420 && safeFrame->data[1] && safeFrame->data[2]) {
    uint32_t uvWidth = w / 2;
    uint32_t uvHeight = h / 2;
    size_t requiredBytes = static_cast<size_t>(uvWidth) * uvHeight * 2;

    if (requiredBytes > 0) {
      interleavedUV.resize(requiredBytes);

      const uint8_t *uPlane = safeFrame->data[1];
      const uint8_t *vPlane = safeFrame->data[2];
      int uPitch = safeFrame->linesize[1];
      int vPitch = safeFrame->linesize[2];

      uint8_t *dstUV = interleavedUV.data();

      for (uint32_t row = 0; row < uvHeight; ++row) {
        const uint8_t *uRow = uPlane + row * uPitch;
        const uint8_t *vRow = vPlane + row * vPitch;
        uint8_t *dstRow = dstUV + row * (uvWidth * 2);

        for (uint32_t col = 0; col < uvWidth; ++col) {
          dstRow[col * 2 + 0] = uRow[col];
          dstRow[col * 2 + 1] = vRow[col];
        }
      }

      uvData = interleavedUV.data();
      uvPitch = static_cast<int>(uvWidth * 2);
    }
  }

  if (!yData || !uvData) {
    av_frame_free(&safeFrame);
    return false;
  }

  size_t estimatedSizeBytes = static_cast<size_t>(w * h * 1.5);

  ensureCapacityForBytes(estimatedSizeBytes);

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

  bool uploadSuccess = false;

  if (reusedFromPool) {
    uploadSuccess = XylaRenderer::instance().uploadToExistingYuvTextures(
        yData, yPitch, uvData, uvPitch, w, h, pooledItem.yImage,
        pooledItem.uvImage);

    if (uploadSuccess) {
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
        m_lruList.push_back(key);
        cached->lruIt = std::prev(m_lruList.end());
        m_frameMap[key] = cached;
        m_assetFrameMap[assetId][frameIndex] = cached;
        m_currentVramBytes += cached->sizeBytes;
      }

      updateCacheRanges();
      emit frameReady(assetId, frameIndex);
      av_frame_free(&safeFrame);
      return true;
    }
  }

  VkImage yImg = VK_NULL_HANDLE, uvImg = VK_NULL_HANDLE;
  VkDeviceMemory yMem = VK_NULL_HANDLE, uvMem = VK_NULL_HANDLE;
  VkImageView yView = VK_NULL_HANDLE, uvView = VK_NULL_HANDLE;

  uploadSuccess = XylaRenderer::instance().allocateAndUploadYuvTextures(
      yData, yPitch, uvData, uvPitch, w, h, &yImg, &yMem, &yView, &uvImg,
      &uvMem, &uvView);

  av_frame_free(&safeFrame);

  if (uploadSuccess && yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
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

    cached->sizeBytes = estimatedSizeBytes;
    cached->isGPUReady = true;

    {
      std::lock_guard<std::mutex> lock(m_cacheMutex);
      m_lruList.push_back(key);
      cached->lruIt = std::prev(m_lruList.end());
      m_frameMap[key] = cached;
      m_assetFrameMap[assetId][frameIndex] = cached;
      m_currentVramBytes += cached->sizeBytes;
    }

    updateCacheRanges();
    emit frameReady(assetId, frameIndex);
    return true;
  }

  return false;
}

std::shared_ptr<CachedFrame>
VideoFrameCache::getFrame(const QString &assetId, int64_t frameIndex,
                          xyla::VulkanVideoDecoder *decoder, bool isPlaying,
                          bool isScrubbing, bool isPrefetch,
                          double scrubVelocity) {
  if (assetId.isEmpty() || frameIndex < 0) {
    return nullptr;
  }

  FrameKey key{assetId, frameIndex};

  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_frameMap.find(key);
    if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
      m_lruList.splice(m_lruList.end(), m_lruList, it->second->lruIt);
      return it->second;
    }
  }

  auto [yView, uvView] = getFramePlanes(assetId, frameIndex, decoder, isPlaying,
                                        isScrubbing, isPrefetch, scrubVelocity);
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

void VideoFrameCache::evictIfNeeded() { ensureCapacityForBytes(0); }

void VideoFrameCache::updateCacheRanges() {
  auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
  auto marker = scratchpad.getMarker();

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

  scratchpad.resetToMarker(marker);

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
                                bool isPrefetch, double scrubVelocity) {
  Q_UNUSED(decoder);
  Q_UNUSED(isPlaying);
  Q_UNUSED(isScrubbing);
  Q_UNUSED(isPrefetch);
  Q_UNUSED(scrubVelocity);

  if (assetId.isEmpty() || frameIndex < 0) {
    return {VK_NULL_HANDLE, VK_NULL_HANDLE};
  }

  FrameKey key{assetId, frameIndex};

  std::lock_guard<std::mutex> lock(m_cacheMutex);

  // 1. Direct hit on exact frame
  auto it = m_frameMap.find(key);
  if (it != m_frameMap.end() && it->second && it->second->isGPUReady) {
    m_lruList.splice(m_lruList.end(), m_lruList, it->second->lruIt);
    return {it->second->yView, it->second->uvView};
  }

  // 2. Return nearby neighbor frame of this asset so screen never flashes black
  auto assetIt = m_assetFrameMap.find(assetId);
  if (assetIt != m_assetFrameMap.end() && !assetIt->second.empty()) {
    // Find closest frame <= frameIndex
    auto lb = assetIt->second.lower_bound(frameIndex);
    if (lb != assetIt->second.end() && lb->second && lb->second->isGPUReady) {
      return {lb->second->yView, lb->second->uvView};
    } else if (!assetIt->second.empty()) {
      auto lastIt = std::prev(assetIt->second.end());
      if (lastIt->second && lastIt->second->isGPUReady) {
        return {lastIt->second->yView, lastIt->second->uvView};
      }
    }
  }

  // Pure cache miss - return null. Decoder background worker will decode
  // asynchronously.
  return {VK_NULL_HANDLE, VK_NULL_HANDLE};
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

        m_lruList.erase(it->second->lruIt);
        m_assetFrameMap[assetId].erase(it->second->frameIndex);

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
    m_lruList.clear();
    m_assetFrameMap.clear();

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

      framesToDestroy.push_back(dummy);
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
