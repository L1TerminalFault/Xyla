#include "framePrefetcher.hpp"
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
                                     bool isPlaying, bool isScrubbing) {
  if (assetId.isEmpty() || !decoder)
    return;

  std::lock_guard<std::mutex> lock(m_queueMutex);
  m_activeAssetId = assetId;
  m_currentPlayhead = currentMediaFrame;
  m_decoder = decoder;
  m_direction = (direction >= 0) ? 1 : -1;
  m_isPlaying = isPlaying;
  m_isScrubbing = isScrubbing;
  m_hasWork = true;
  m_stateVersion.fetch_add(1, std::memory_order_relaxed);
  m_cv.notify_one();
}

void FramePrefetcher::workerLoop() {
  while (m_running.load()) {
    QString assetId;
    int64_t playhead = -1;
    int direction = 1;
    bool isPlaying = false;
    bool isScrubbing = false;
    VulkanVideoDecoder *decoder = nullptr;
    uint64_t currentVersion = 0;

    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_cv.wait(lock, [this] { return m_hasWork || !m_running.load(); });

      if (!m_running.load())
        break;

      assetId = m_activeAssetId;
      playhead = m_currentPlayhead;
      direction = m_direction;
      decoder = m_decoder;
      isPlaying = m_isPlaying;
      isScrubbing = m_isScrubbing;
      currentVersion = m_stateVersion.load(std::memory_order_relaxed);
      m_hasWork = false;
    }

    if (!decoder || assetId.isEmpty() || playhead < 0)
      continue;

    // Yield control during active playback or scrubbing to prevent background
    // thread contention
    if (isPlaying || isScrubbing) {
      continue;
    }

    // Prefetch lookahead window only when paused/idle
    int aheadCount = 4;
    for (int offset = 1; offset <= aheadCount; ++offset) {
      if (!m_running.load() ||
          m_stateVersion.load(std::memory_order_relaxed) != currentVersion) {
        break;
      }

      int64_t targetFrame = playhead + (offset * direction);
      if (targetFrame >= 0) {
        if (!VideoFrameCache::instance().hasFrame(assetId, targetFrame)) {
          // Pass isPlaying=false, isScrubbing=false, isPrefetch=true
          VideoFrameCache::instance().getFramePlanes(
              assetId, targetFrame, decoder, false, false, true);
        }
      }
    }
  }
}

} // namespace xyla::render
