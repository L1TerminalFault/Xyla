#pragma once

#include "core/concurrency/xylaWorkQueue.hpp"

#include <QString>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <mutex>
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
  double scrubVelocity{0.0};
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

  // some notes :)
  // Temporarily prevent new prefetch operations from starting and wait
  // until the currently active operation has completely finished.
  // This is used when Vulkan resources are about to be destroyed or
  // replaced. It does not stop the work queue permanently.
  void pauseAndWaitIdle();

  // Release a temporary pause created by pauseAndWaitIdle().
  void resume();

  void updatePlayhead(const QString &assetId, int64_t currentMediaFrame,
                      MediaPool *mediaPool, int direction, bool isPlaying,
                      bool isScrubbing, double scrubVelocity = 0.0);

  [[nodiscard]] bool isRunning() const noexcept {
    return m_running.load(std::memory_order_acquire);
  }

private:
  void workerLoop();

  // Attempts to claim ownership of one actual prefetch operation.
  // Returns false when the worker should skip the popped request. In
  // particular, this happens when the prefetcher is temporarily paused.
  bool beginWork();

  // Releases ownership of the active prefetch operation.
  void endWork();

  std::thread m_workerThread;

  std::atomic<bool> m_running{false};
  std::atomic<uint64_t> m_stateVersion{0};

  mutable std::mutex m_stateMutex;
  std::condition_variable m_stateCv;

  bool m_paused{false};

  size_t m_activeWork{0};

  std::chrono::steady_clock::time_point m_lastScrubPushTime;

  concurrency::XylaWorkQueue<PrefetchRequest> m_workQueue{
      16, concurrency::QueueMode::FIFO};
};

} // namespace xyla::render
