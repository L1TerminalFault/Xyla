#pragma once

#include <cstdint>
#include <vector>

namespace xyla::audio {

/**
 * @brief Normalized 48kHz 32-bit Float PCM storage for a media asset's audio
 * stream.
 */
class AudioClipBuffer {
public:
  AudioClipBuffer(uint32_t channels, uint32_t sampleRate = 48000)
      : m_channels(channels), m_sampleRate(sampleRate) {
    m_channelData.resize(channels);
  }

  void appendFrames(const float *const *planarData, size_t frameCount) {
    for (size_t c = 0; c < m_channels; ++c) {
      if (planarData[c]) {
        m_channelData[c].insert(m_channelData[c].end(), planarData[c],
                                planarData[c] + frameCount);
      }
    }
    m_totalFrames += frameCount;
  }

  /**
   * @brief Read a slice of frames matching the timeline playhead.
   * Zero allocation, bounds-safe.
   */
  size_t readFrames(int64_t startFrame, size_t requestedFrames,
                    float **outputBuffers, size_t outChannels) const noexcept {
    if (startFrame < 0 || static_cast<size_t>(startFrame) >= m_totalFrames) {
      return 0;
    }

    size_t available = m_totalFrames - static_cast<size_t>(startFrame);
    size_t framesToCopy = std::min(requestedFrames, available);
    size_t channelsToCopy =
        std::min(static_cast<size_t>(m_channels), outChannels);

    for (size_t c = 0; c < channelsToCopy; ++c) {
      if (outputBuffers[c]) {
        const float *src = m_channelData[c].data() + startFrame;
        std::copy(src, src + framesToCopy, outputBuffers[c]);
      }
    }

    return framesToCopy;
  }

  [[nodiscard]] size_t totalFrames() const noexcept { return m_totalFrames; }
  [[nodiscard]] uint32_t channels() const noexcept { return m_channels; }
  [[nodiscard]] uint32_t sampleRate() const noexcept { return m_sampleRate; }

  [[nodiscard]] const std::vector<float> &channel(size_t ch) const {
    return m_channelData[ch];
  }

private:
  uint32_t m_channels{2};
  uint32_t m_sampleRate{48000};
  size_t m_totalFrames{0};
  std::vector<std::vector<float>> m_channelData;
};

} // namespace xyla::audio
