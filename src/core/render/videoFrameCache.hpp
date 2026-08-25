#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include <QString>
#include <deque>
#include <memory>
#include <mutex>
#include <unordered_map>
// TODO replace with volk
#include <vulkan/vulkan.h>

namespace xyla::render {

struct CachedFrame {
  QString assetId;
  int64_t frameIndex{0};
  VkImage image{VK_NULL_HANDLE};
  VkImageView imageView{VK_NULL_HANDLE};
  bool isGPUReady{false};
};

class VideoFrameCache {
public:
  static VideoFrameCache &instance() {
    static VideoFrameCache cache;
    return cache;
  }

  // Fetches a GPU texture for a specific asset and frame index
  // Returns VkImageView if cached in VRAM; otherwise returns nullptr and
  // requests async decode
  VkImageView getFrame(const QString &assetId, int64_t frameIndex,
                       VulkanVideoDecoder *decoder);

  // Prefetchs upcoming frames in background thread for smooth playback
  void prefetchFrames(const QString &assetId, int64_t startFrame, int count,
                      VulkanVideoDecoder *decoder);

  // Evicts old GPU frames to keep VRAM usage strictly bounded
  void setMaxVramMB(size_t maxMegabytes);
  void clear();

private:
  VideoFrameCache() = default;
  ~VideoFrameCache();

  std::mutex m_cacheMutex;
  size_t m_maxVramBytes{1024 * 1024 * 1024};
  size_t m_currentVramBytes{0};

  std::unordered_map<QString, std::shared_ptr<CachedFrame>> m_frameMap;
  std::deque<QString> m_lruQueue; // LRU Eviction Queue
};

} // namespace xyla::render
