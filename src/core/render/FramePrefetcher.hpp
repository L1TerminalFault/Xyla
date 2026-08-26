#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include <QObject>
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

  void start();
  void stop();

  void updatePlayhead(const QString &assetId, int64_t currentMediaFrame,
                      VulkanVideoDecoder *decoder, int direction = 1,
                      bool isPlaying = false);

private:
  FramePrefetcher();
  ~FramePrefetcher();

  void workerLoop();

  std::thread m_workerThread;
  std::atomic<bool> m_running{false};

  std::mutex m_queueMutex;
  std::condition_variable m_cv;

  QString m_activeAssetId;
  int64_t m_currentPlayhead{-1};
  int m_direction{1};
  VulkanVideoDecoder *m_decoder{nullptr};
  bool m_hasWork{false};
};

} // namespace xyla::render
