#include "framePrefetcher.hpp"

#include "core/media/mediaPool.hpp"
#include "core/memory/xylaArena.hpp"
#include "videoFrameCache.hpp"

#include <chrono>

namespace xyla::render {

FramePrefetcher::FramePrefetcher() = default;

FramePrefetcher::~FramePrefetcher() { stop(); }

void FramePrefetcher::start() {
  if (m_running.load(std::memory_order_acquire)) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(m_stateMutex);

    if (m_paused) {
      m_paused = false;
    }
  }

  m_running.store(true, std::memory_order_release);

  m_workerThread = std::thread(&FramePrefetcher::workerLoop, this);

  // XYLA_LOG_INFO(
  //     "FramePrefetcher",
  //     "[ENGINE] Async lookahead prefetch engine STARTED.");
}

void FramePrefetcher::stop() {
  if (!m_running.load(std::memory_order_acquire)) {
    return;
  }

  // Prevent the worker from starting another operation.
  m_running.store(false, std::memory_order_release);

  m_workQueue.stop();

  // Wake anything waiting on the state condition variable.
  m_stateCv.notify_all();

  if (m_workerThread.joinable()) {
    m_workerThread.join();
  }

  {
    std::lock_guard<std::mutex> lock(m_stateMutex);
    m_paused = false;
  }

  // XYLA_LOG_INFO(
  //     "FramePrefetcher",
  //     "[ENGINE] Async lookahead prefetch engine STOPPED.");
}

void FramePrefetcher::pauseAndWaitIdle() {
  std::unique_lock<std::mutex> lock(m_stateMutex);

  m_paused = true;

  m_stateCv.wait(lock, [this] { return m_activeWork == 0; });
}

void FramePrefetcher::resume() {
  {
    std::lock_guard<std::mutex> lock(m_stateMutex);

    m_paused = false;
  }

  m_stateCv.notify_all();
}

bool FramePrefetcher::beginWork() {
  std::lock_guard<std::mutex> lock(m_stateMutex);

  if (!m_running.load(std::memory_order_acquire) || m_paused) {
    return false;
  }

  ++m_activeWork;
  return true;
}

void FramePrefetcher::endWork() {
  {
    std::lock_guard<std::mutex> lock(m_stateMutex);

    if (m_activeWork > 0) {
      --m_activeWork;
    }
  }

  m_stateCv.notify_all();
}

void FramePrefetcher::updatePlayhead(const QString &assetId,
                                     int64_t currentMediaFrame,
                                     MediaPool *mediaPool, int direction,
                                     bool isPlaying, bool isScrubbing,
                                     double scrubVelocity) {
  if (assetId.isEmpty() || !mediaPool || currentMediaFrame < 0) {
    return;
  }

  if (!m_running.load(std::memory_order_acquire)) {
    start();
  }

  // Scrubbing demands latest-wins behavior so obsolete intermediate
  // requests are discarded.
  if (isScrubbing) {
    m_workQueue.setMode(concurrency::QueueMode::LatestWins);
  } else {
    m_workQueue.setMode(concurrency::QueueMode::FIFO);
  }

  PrefetchRequest req;
  req.assetId = assetId;
  req.targetFrameIndex = currentMediaFrame;
  req.currentPlayheadIndex = currentMediaFrame;
  req.mediaPool = mediaPool;
  req.direction = (direction >= 0) ? 1 : -1;
  req.isPlaying = isPlaying;
  req.isScrubbing = isScrubbing;
  req.scrubVelocity = scrubVelocity;

  // Non-blocking deduplicated push.
  //
  // During a temporary Vulkan pause this may still enqueue a request.
  // That is harmless: the worker will not begin Vulkan/cache work while
  // paused. A request popped during the pause is discarded by
  // beginWork().
  m_workQueue.pushDeduplicated(
      std::move(req), [](const PrefetchRequest &r) { return r.assetId; });
}

void FramePrefetcher::workerLoop() {
  // XYLA_LOG_INFO(
  //     "FramePrefetcher",
  //     "[WORKER] Background prefetch loop entered.");

  while (m_running.load(std::memory_order_acquire)) {
    PrefetchRequest req;

    if (!m_workQueue.popWait(req, std::chrono::milliseconds(20))) {
      continue;
    }

    if (!m_running.load(std::memory_order_acquire) || !req.mediaPool ||
        req.assetId.isEmpty()) {
      continue;
    }

    // Claim the request as active work before touching the decoder or
    // Vulkan-backed VideoFrameCache.
    //
    // If the prefetcher was paused between popWait() and this call,
    // beginWork() returns false and the request is discarded.
    if (!beginWork()) {
      continue;
    }

    // Every path after beginWork() is protected by this guard. This is
    // particularly important because decoder acquisition and the
    // different prefetch modes have several early exits.
    struct WorkGuard {
      FramePrefetcher *owner{nullptr};

      ~WorkGuard() {
        if (owner) {
          owner->endWork();
        }
      }
    } workGuard{this};

    auto *decoder = req.mediaPool->getPrefetchDecoder(req.assetId);
    if (!decoder) {
      continue;
    }

    auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
    auto marker = scratchpad.getMarker();

    if (req.isScrubbing) {
      // Scrubbing: decode the exact requested frame.
      const int64_t target = req.currentPlayheadIndex;

      if (!VideoFrameCache::instance().hasFrame(req.assetId, target)) {
        if (decoder->seekToFrameSmart(target, req.scrubVelocity)) {
          AVFrame *f = decoder->currentFrame();

          if (f) {
            VideoFrameCache::instance().uploadAndCacheFrame(
                req.assetId, decoder->currentFrameIndex(), f);
          }
        }
      }
    } else if (req.isPlaying) {
      // Playback lookahead: decode four frames ahead sequentially.
      for (int i = 0; i <= 4; ++i) {
        if (!m_running.load(std::memory_order_acquire)) {
          break;
        }

        const int64_t target = req.currentPlayheadIndex + (i * req.direction);

        if (target >= 0 &&
            !VideoFrameCache::instance().hasFrame(req.assetId, target)) {
          if (decoder->seekToFrameSmart(target, 0.0)) {
            AVFrame *f = decoder->currentFrame();

            if (f) {
              VideoFrameCache::instance().uploadAndCacheFrame(
                  req.assetId, decoder->currentFrameIndex(), f);
            }
          }
        }
      }
    } else {
      // Idle / pause: decode the exact target followed by two lookahead
      // frames.
      for (int i = 0; i <= 2; ++i) {
        if (!m_running.load(std::memory_order_acquire)) {
          break;
        }

        const int64_t target = req.currentPlayheadIndex + (i * req.direction);

        if (target >= 0 &&
            !VideoFrameCache::instance().hasFrame(req.assetId, target)) {
          if (decoder->seekToFrameSmart(target, 0.0)) {
            AVFrame *f = decoder->currentFrame();

            if (f) {
              VideoFrameCache::instance().uploadAndCacheFrame(
                  req.assetId, decoder->currentFrameIndex(), f);
            }
          }
        }
      }
    }

    scratchpad.resetToMarker(marker);
  }

  // XYLA_LOG_INFO(
  //     "FramePrefetcher",
  //     "[WORKER] Background prefetch loop exited.");
}

} // namespace xyla::render
