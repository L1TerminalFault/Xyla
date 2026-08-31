#include "framePrefetcher.hpp"
#include "core/log/logger.hpp"
#include "core/media/mediaPool.hpp"
#include "core/memory/xylaArena.hpp"
#include "videoFrameCache.hpp"

#include <chrono>

namespace xyla::render {

FramePrefetcher::FramePrefetcher() = default;

FramePrefetcher::~FramePrefetcher() { stop(); }

void FramePrefetcher::start() {
  if (m_running.load())
    return;

  m_running.store(true);
  m_workerThread = std::thread(&FramePrefetcher::workerLoop, this);
  XYLA_LOG_INFO("FramePrefetcher",
                "[ENGINE] Async lookahead prefetch engine STARTED.");
}

void FramePrefetcher::stop() {
  if (!m_running.load())
    return;

  m_running.store(false);
  m_workQueue.stop();

  if (m_workerThread.joinable()) {
    m_workerThread.join();
  }

  XYLA_LOG_INFO("FramePrefetcher",
                "[ENGINE] Async lookahead prefetch engine STOPPED.");
}

void FramePrefetcher::updatePlayhead(const QString &assetId,
                                     int64_t currentMediaFrame,
                                     MediaPool *mediaPool, int direction,
                                     bool isPlaying, bool isScrubbing,
                                     double scrubVelocity) {
  if (assetId.isEmpty() || !mediaPool || currentMediaFrame < 0)
    return;

  if (!m_running.load()) {
    start();
  }

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

  m_workQueue.pushDeduplicated(
      std::move(req), [](const PrefetchRequest &r) { return r.assetId; });
}

void FramePrefetcher::workerLoop() {
  XYLA_LOG_INFO("FramePrefetcher",
                "[WORKER] Background prefetch loop entered.");

  while (m_running.load()) {
    PrefetchRequest req;

    if (!m_workQueue.popWait(req, std::chrono::milliseconds(25))) {
      continue;
    }

    if (!m_running.load() || !req.mediaPool || req.assetId.isEmpty()) {
      continue;
    }

    auto *decoder = req.mediaPool->getPrefetchDecoder(req.assetId);
    if (!decoder) {
      continue;
    }

    auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
    auto marker = scratchpad.getMarker();

    if (req.isScrubbing) {
      // Background prefetch around current playhead during scrub
      int64_t target = req.currentPlayheadIndex;
      if (!VideoFrameCache::instance().hasFrame(req.assetId, target)) {
        if (decoder->seekToFrameSmart(target, 0.0)) {
          AVFrame *f = decoder->currentFrame();
          if (f) {
            VideoFrameCache::instance().uploadAndCacheFrame(
                req.assetId, decoder->currentFrameIndex(), f);
          }
        }
      }
    } else if (req.isPlaying) {
      // Playback lookahead: decode 4 frames ahead sequentially
      for (int i = 0; i <= 4; ++i) {
        if (!m_running.load())
          break;
        int64_t target = req.currentPlayheadIndex + (i * req.direction);
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
      // Idle / Pause: Decode exact target first, then lookahead 3 frames
      for (int i = 0; i <= 3; ++i) {
        if (!m_running.load())
          break;
        int64_t target = req.currentPlayheadIndex + (i * req.direction);
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
}

} // namespace xyla::render
