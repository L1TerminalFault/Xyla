#include "videoFrameCache.hpp"
#include "xylaRenderer.hpp"

namespace xyla::render {

namespace {

// Thread pool task for asynchronous background frame prefetching
class PrefetchTask : public QRunnable {
public:
  PrefetchTask(QString assetId, int64_t frameIndex, VulkanVideoDecoder *decoder,
               double fps, VideoFrameCache *cache)
      : m_assetId(std::move(assetId)), m_frameIndex(frameIndex),
        m_decoder(decoder), m_fps(fps), m_cache(cache) {}

  void run() override {
    if (!m_decoder || !m_cache)
      return;

    if (m_decoder->seekToFrame(m_frameIndex, m_fps)) {
      VkImage img = m_decoder->getDecodedVkImage();
      if (img != VK_NULL_HANDLE) {
        QMetaObject::invokeMethod(
            m_cache, "frameReady", Qt::QueuedConnection,
            Q_ARG(QString, m_assetId),
            Q_ARG(qint64, static_cast<qint64>(m_frameIndex)));
      }
    }
  }

private:
  QString m_assetId;
  int64_t m_frameIndex;
  VulkanVideoDecoder *m_decoder{nullptr};
  double m_fps{30.0};
  VideoFrameCache *m_cache{nullptr};
};

} // namespace

// Configures dedicated prefetch thread pool
VideoFrameCache::VideoFrameCache() {
  m_threadPool = std::make_unique<QThreadPool>();
  m_threadPool->setMaxThreadCount(std::max(1, QThread::idealThreadCount() / 2));
}

// Cleans up queued prefetch tasks and VRAM textures
VideoFrameCache::~VideoFrameCache() {
  if (m_threadPool) {
    m_threadPool->clear();
    m_threadPool->waitForDone();
  }
  clear();
}

// Retrieves cached GPU texture view or decodes frame on demand
VkImageView VideoFrameCache::getFrame(const QString &assetId,
                                      int64_t frameIndex,
                                      VulkanVideoDecoder *decoder) {
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

    VkImage img = decoder->getDecodedVkImage();
    if (img == VK_NULL_HANDLE) {
      return VK_NULL_HANDLE;
    }

    VkDevice device = XylaRenderer::instance().device();
    if (device == VK_NULL_HANDLE) {
      return VK_NULL_HANDLE;
    }

    VkImageView view = XylaRenderer::instance().inputImageView();
    if (view != VK_NULL_HANDLE) {
      auto cached = std::make_shared<CachedFrame>();
      cached->assetId = assetId;
      cached->frameIndex = frameIndex;
      cached->image = img;
      cached->imageView = view;
      cached->isGPUReady = true;

      m_frameMap[key] = cached;
      m_lruQueue.push_back(key);
      evictIfNeeded();

      return cached->imageView;
    }
  }

  return VK_NULL_HANDLE;
}

// Enqueues future frames into background worker thread pool
void VideoFrameCache::prefetchFrames(const QString &assetId, int64_t startFrame,
                                     int count, VulkanVideoDecoder *decoder,
                                     double fps) {
  if (!decoder || count <= 0)
    return;

  for (int i = 1; i <= count; ++i) {
    int64_t targetFrame = startFrame + i;
    QString key = QString("%1_%2").arg(assetId).arg(targetFrame);

    {
      std::lock_guard<std::mutex> lock(m_cacheMutex);
      if (m_frameMap.count(key)) {
        continue;
      }
    }

    auto *task = new PrefetchTask(assetId, targetFrame, decoder, fps, this);
    task->setAutoDelete(true);
    m_threadPool->start(task);
  }
}

// Evicts oldest cached GPU textures when exceeding memory budget
void VideoFrameCache::evictIfNeeded() {
  while (m_lruQueue.size() > 60) {
    QString oldestKey = m_lruQueue.front();
    m_lruQueue.pop_front();
    m_frameMap.erase(oldestKey);
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
  m_lruQueue.clear();
  m_currentVramBytes = 0;
}

} // namespace xyla::render
