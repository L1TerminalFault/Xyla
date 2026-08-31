#pragma once

#include "core/concurrency/xylaWorkQueue.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/memory/xylaArena.hpp"

#include <QString>
#include <atomic>
#include <chrono>
#include <memory>
#include <thread>

namespace xyla {
class MediaPool;
}

namespace xyla::render {

struct PrefetchRequest {
  QString assetId;
  int64_t targetFrameIndex{0};
  int64_t currentPlayheadIndex{0};
  MediaPool *mediaPool{nullptr};
  double velocity{0.0};
  int direction{1};
  bool isPlaying{false};
  bool isScrubbing{false};
  double scrubVelocity = 0.0;
};

class FramePrefetcher {
public:
  static FramePrefetcher &instance() {
    static FramePrefetcher prefetcher;
    return prefetcher;
  }

  FramePrefetcher();
  ~FramePrefetcher();

  FramePrefetcher(const FramePrefetcher &) = delete;
  FramePrefetcher &operator=(const FramePrefetcher &) = delete;

  void start();
  void stop();

  void updatePlayhead(const QString &assetId, int64_t currentMediaFrame,
                      MediaPool *mediaPool, int direction, bool isPlaying,
                      bool isScrubbing, double scrubVelocity = 0.0);

  [[nodiscard]] bool isRunning() const noexcept { return m_running.load(); }

private:
  void workerLoop();

  std::thread m_workerThread;
  std::atomic<bool> m_running{false};
  std::atomic<uint64_t> m_stateVersion{0};

  // Throttling state for scrubbing requests
  std::chrono::steady_clock::time_point m_lastScrubPushTime;

  // High-performance concurrent work queue for prefetch scheduling
  concurrency::XylaWorkQueue<PrefetchRequest> m_workQueue{
      16, concurrency::QueueMode::FIFO};
};

} // namespace xyla::render
