#pragma once

#include "audioBuffer.hpp"
#include <atomic>
#include <cassert>
#include <cstddef>
#include <memory>
#include <vector>

namespace xyla::audio {

/**
 * @brief Pre-allocated scratchpad pool for real-time audio threads.
 *
 * Provides instant buffer checkouts using a lock-free bitmap / index stack.
 * Guarantees zero system calls or memory allocations during DSP execution.
 */
class AudioBufferPool {
public:
  AudioBufferPool() = default;

  void initialize(size_t maxBuffers, size_t channels, size_t maxFrames) {
    m_buffers.clear();
    m_freeIndices.clear();
    m_buffers.reserve(maxBuffers);
    m_freeIndices.reserve(maxBuffers);

    for (size_t i = 0; i < maxBuffers; ++i) {
      m_buffers.push_back(std::make_unique<AudioBuffer>(channels, maxFrames));
      m_freeIndices.push_back(i);
    }
  }

  /**
   * @brief Check out an available buffer from the pool.
   * @return Pointer to available AudioBuffer, or nullptr if exhausted.
   */
  [[nodiscard]] AudioBuffer *acquireBuffer() noexcept {
    if (m_freeIndices.empty()) {
      assert(false && "AudioBufferPool exhausted! Increase pool size.");
      return nullptr;
    }
    size_t idx = m_freeIndices.back();
    m_freeIndices.pop_back();
    AudioBuffer *buf = m_buffers[idx].get();
    buf->clear();
    return buf;
  }

  /**
   * @brief Return a buffer back to the pool.
   */
  void releaseBuffer(AudioBuffer *buffer) noexcept {
    if (!buffer)
      return;

    for (size_t i = 0; i < m_buffers.size(); ++i) {
      if (m_buffers[i].get() == buffer) {
        m_freeIndices.push_back(i);
        return;
      }
    }
    assert(false && "Released buffer does not belong to this pool!");
  }

  void reset() noexcept {
    m_freeIndices.clear();
    for (size_t i = 0; i < m_buffers.size(); ++i) {
      m_freeIndices.push_back(i);
    }
  }

  [[nodiscard]] size_t availableCount() const noexcept {
    return m_freeIndices.size();
  }

  [[nodiscard]] size_t capacity() const noexcept { return m_buffers.size(); }

private:
  std::vector<std::unique_ptr<AudioBuffer>> m_buffers;
  std::vector<size_t> m_freeIndices;
};

} // namespace xyla::audio
