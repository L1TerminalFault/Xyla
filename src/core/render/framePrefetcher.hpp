#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include <QString>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <thread>

namespace xyla::render {

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
                      VulkanVideoDecoder *decoder, int direction = 1,
                      bool isPlaying = false, bool isScrubbing = false);

private:
  void workerLoop();

  std::thread m_workerThread;
  std::mutex m_queueMutex;
  std::condition_variable m_cv;

  std::atomic<bool> m_running{false};
  std::atomic<uint64_t> m_stateVersion{0}; // Track updates for cancellation

  bool m_hasWork{false};
  QString m_activeAssetId;
  int64_t m_currentPlayhead{-1};
  VulkanVideoDecoder *m_decoder{nullptr};
  int m_direction{1};
  bool m_isPlaying{false};
  bool m_isScrubbing{false};
};

} // namespace xyla::render
