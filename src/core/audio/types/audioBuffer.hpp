#pragma once

#include <algorithm>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

namespace xyla::audio {

/**
 * @brief High-performance Planar (Non-Interleaved) 32-bit Floating Point Audio
 * Buffer.
 *
 * Designed for strict real-time audio threads:
 * - Can own its contiguous aligned memory, OR wrap external device/scratchpad
 * memory without malloc.
 * - Memory is laid out as channels of discrete float arrays:
 * channelData[ch][sampleIdx].
 */
class AudioBuffer {
public:
  AudioBuffer() = default;

  /**
   * @brief Allocate a buffer with capacity. (Call this during preparation /
   * offline, NEVER inside render callback).
   */
  AudioBuffer(size_t channels, size_t maxFrames) {
    allocate(channels, maxFrames);
  }

  ~AudioBuffer() = default;

  AudioBuffer(const AudioBuffer &) = delete;
  AudioBuffer &operator=(const AudioBuffer &) = delete;

  AudioBuffer(AudioBuffer &&other) noexcept
      : m_channels(other.m_channels), m_frames(other.m_frames),
        m_capacityFrames(other.m_capacityFrames),
        m_ownsMemory(other.m_ownsMemory),
        m_channelPointers(std::move(other.m_channelPointers)),
        m_storage(std::move(other.m_storage)) {
    other.m_channels = 0;
    other.m_frames = 0;
    other.m_capacityFrames = 0;
    other.m_ownsMemory = false;
  }

  AudioBuffer &operator=(AudioBuffer &&other) noexcept {
    if (this != &other) {
      m_channels = other.m_channels;
      m_frames = other.m_frames;
      m_capacityFrames = other.m_capacityFrames;
      m_ownsMemory = other.m_ownsMemory;
      m_channelPointers = std::move(other.m_channelPointers);
      m_storage = std::move(other.m_storage);

      other.m_channels = 0;
      other.m_frames = 0;
      other.m_capacityFrames = 0;
      other.m_ownsMemory = false;
    }
    return *this;
  }

  void allocate(size_t channels, size_t maxFrames) {
    m_channels = channels;
    m_frames = maxFrames;
    m_capacityFrames = maxFrames;
    m_ownsMemory = true;

    m_storage.resize(channels * maxFrames, 0.0f);
    m_channelPointers.resize(channels);

    for (size_t c = 0; c < channels; ++c) {
      m_channelPointers[c] = m_storage.data() + (c * maxFrames);
    }
  }

  /**
   * @brief Re-wrap external pointers without allocating memory (Zero
   * Allocations). Used when receiving buffers from ALSA / PipeWire / Hardware
   * callbacks.
   */
  void wrapPointers(float *const *externalPointers, size_t channels,
                    size_t frames) noexcept {
    m_channels = channels;
    m_frames = frames;
    m_capacityFrames = frames;
    m_ownsMemory = false;

    if (m_channelPointers.size() < channels) {
      m_channelPointers.resize(channels);
    }

    for (size_t c = 0; c < channels; ++c) {
      m_channelPointers[c] = externalPointers[c];
    }
  }

  [[nodiscard]] size_t channelCount() const noexcept { return m_channels; }
  [[nodiscard]] size_t frameCount() const noexcept { return m_frames; }
  void setFrameCount(size_t frames) noexcept {
    assert(frames <= m_capacityFrames);
    m_frames = frames;
  }

  [[nodiscard]] float *channelData(size_t ch) noexcept {
    assert(ch < m_channels);
    return m_channelPointers[ch];
  }

  [[nodiscard]] const float *channelData(size_t ch) const noexcept {
    assert(ch < m_channels);
    return m_channelPointers[ch];
  }

  [[nodiscard]] float **allChannels() noexcept {
    return m_channelPointers.data();
  }

  [[nodiscard]] const float *const *allChannels() const noexcept {
    return m_channelPointers.data();
  }

  void clear() noexcept {
    for (size_t c = 0; c < m_channels; ++c) {
      if (m_channelPointers[c]) {
        std::memset(m_channelPointers[c], 0, m_frames * sizeof(float));
      }
    }
  }

  void clearChannel(size_t ch) noexcept {
    assert(ch < m_channels);
    if (m_channelPointers[ch]) {
      std::memset(m_channelPointers[ch], 0, m_frames * sizeof(float));
    }
  }

  /**
   * @brief Multiply channel contents by a constant linear scalar.
   */
  void applyGain(float gain) noexcept {
    if (gain == 1.0f)
      return;
    if (gain == 0.0f) {
      clear();
      return;
    }

    for (size_t c = 0; c < m_channels; ++c) {
      float *ptr = m_channelPointers[c];
      for (size_t i = 0; i < m_frames; ++i) {
        ptr[i] *= gain;
      }
    }
  }

  /**
   * @brief Multiply channel by ramped gain (sample-accurate de-zippering).
   */
  void applyRamp(float startGain, float endGain) noexcept {
    if (m_frames == 0)
      return;

    float step = (endGain - startGain) / static_cast<float>(m_frames);
    for (size_t c = 0; c < m_channels; ++c) {
      float *ptr = m_channelPointers[c];
      float currentGain = startGain;
      for (size_t i = 0; i < m_frames; ++i) {
        ptr[i] *= currentGain;
        currentGain += step;
      }
    }
  }

  /**
   * @brief Accumulate (sum) another buffer's contents into this buffer: this +=
   * src * gain
   */
  void accumulate(const AudioBuffer &src, float gain = 1.0f) noexcept {
    size_t channelsToMix = std::min(m_channels, src.m_channels);
    size_t framesToMix = std::min(m_frames, src.m_frames);

    if (gain == 1.0f) {
      for (size_t c = 0; c < channelsToMix; ++c) {
        float *dstPtr = m_channelPointers[c];
        const float *srcPtr = src.m_channelPointers[c];
        for (size_t i = 0; i < framesToMix; ++i) {
          dstPtr[i] += srcPtr[i];
        }
      }
    } else if (gain != 0.0f) {
      for (size_t c = 0; c < channelsToMix; ++c) {
        float *dstPtr = m_channelPointers[c];
        const float *srcPtr = src.m_channelPointers[c];
        for (size_t i = 0; i < framesToMix; ++i) {
          dstPtr[i] += srcPtr[i] * gain;
        }
      }
    }
  }

  /**
   * @brief Direct copy from source buffer.
   */
  void copyFrom(const AudioBuffer &src) noexcept {
    size_t channelsToCopy = std::min(m_channels, src.m_channels);
    size_t framesToCopy = std::min(m_frames, src.m_frames);

    for (size_t c = 0; c < channelsToCopy; ++c) {
      std::memcpy(m_channelPointers[c], src.m_channelPointers[c],
                  framesToCopy * sizeof(float));
    }
  }

private:
  size_t m_channels{0};
  size_t m_frames{0};
  size_t m_capacityFrames{0};
  bool m_ownsMemory{false};

  std::vector<float *> m_channelPointers;
  std::vector<float> m_storage;
};

} // namespace xyla::audio
