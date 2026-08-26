#include "FramePrefetcher.hpp"
#include "core/log/logger.hpp"
#include "videoFrameCache.hpp"

namespace xyla::render {

FramePrefetcher::FramePrefetcher() { start(); }

FramePrefetcher::~FramePrefetcher() { stop(); }

void FramePrefetcher::start() {
  if (m_running.load())
    return;
  m_running.store(true);
  m_workerThread = std::thread(&FramePrefetcher::workerLoop, this);
  XYLA_LOG_INFO("FramePrefetcher", "Async prefetch engine started.");
}

void FramePrefetcher::stop() {
  if (!m_running.load())
    return;
  m_running.store(false);
  m_cv.notify_all();
  if (m_workerThread.joinable()) {
    m_workerThread.join();
  }
}

void FramePrefetcher::updatePlayhead(const QString &assetId,
                                     int64_t currentMediaFrame,
                                     VulkanVideoDecoder *decoder, int direction,
                                     bool isPlaying) {
  // FIX: If actively playing back, SUSPEND prefetching immediately!
  // This prevents the prefetcher from competing with the main decoder stream.
  if (assetId.isEmpty() || !decoder || isPlaying)
    return;

  decoder->requestFrame(currentMediaFrame);

  std::lock_guard<std::mutex> lock(m_queueMutex);
  m_activeAssetId = assetId;
  m_currentPlayhead = currentMediaFrame;
  m_decoder = decoder;
  m_direction = direction;
  m_hasWork = true;
  m_cv.notify_one();
}

void FramePrefetcher::workerLoop() {
  while (m_running.load()) {
    QString assetId;
    int64_t playhead = -1;
    int direction = 1;
    VulkanVideoDecoder *decoder = nullptr;

    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_cv.wait(lock, [this] { return m_hasWork || !m_running.load(); });

      if (!m_running.load())
        break;

      assetId = m_activeAssetId;
      playhead = m_currentPlayhead;
      direction = m_direction;
      decoder = m_decoder;
      m_hasWork = false;
    }

    if (!decoder || assetId.isEmpty() || playhead < 0)
      continue;

    // Decode target frame
    VideoFrameCache::instance().getFramePlanes(assetId, playhead, decoder,
                                               false, true);

    int aheadCount = (direction >= 0) ? 180 : 30;
    int behindCount = (direction >= 0) ? 30 : 180;
    int step = (direction >= 0) ? 1 : -1;
    int maxOffset = std::max(aheadCount, behindCount);

    for (int offset = 1; offset <= maxOffset; ++offset) {
      if (!m_running.load())
        break;

      {
        std::lock_guard<std::mutex> lock(m_queueMutex);
        if (m_hasWork)
          break;
      }

      int64_t targetFwd = playhead + (offset * step);
      if (targetFwd >= 0 && offset <= aheadCount) {
        VideoFrameCache::instance().getFramePlanes(assetId, targetFwd, decoder,
                                                   false, true);
      }

      int64_t targetBwd = playhead - (offset * step);
      if (targetBwd >= 0 && offset <= behindCount) {
        VideoFrameCache::instance().getFramePlanes(assetId, targetBwd, decoder,
                                                   false, true);
      }
    }
  }
}

} // namespace xyla::render
