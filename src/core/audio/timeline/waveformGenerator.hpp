#pragma once

#include "audioClipBuffer.hpp"
#include <cstdint>
#include <memory>
#include <vector>

namespace xyla::audio {

struct AudioPeak {
  float min{-0.0f};
  float max{0.0f};
};

/**
 * @brief Multi-resolution Peak Pyramid for fast 60fps timeline waveform
 * rendering.
 */
class WaveformPyramid {
public:
  // 3 MIP levels: fine (64 samples/bin), medium (256 samples/bin), coarse (1024
  // samples/bin)
  static constexpr size_t kLevel0BinSize = 64;
  static constexpr size_t kLevel1BinSize = 256;
  static constexpr size_t kLevel2BinSize = 1024;

  WaveformPyramid() = default;

  void generateFromPcm(const AudioClipBuffer &buffer);

  /**
   * @brief Retrieve peaks for a specific slice of time at a chosen zoom level.
   * @param channel Index of channel (0 = Left, 1 = Right)
   * @param startSample Start sample position in the audio clip
   * @param sampleCount Number of samples to cover
   * @param samplesPerPixel Timeline zoom ratio (determines which MIP level to
   * sample)
   */
  [[nodiscard]] std::vector<AudioPeak> getPeaks(size_t channel,
                                                int64_t startSample,
                                                size_t sampleCount,
                                                double samplesPerPixel) const;

  [[nodiscard]] bool isGenerated() const noexcept { return m_isGenerated; }

private:
  bool m_isGenerated{false};
  size_t m_channelCount{0};

  // Channel -> Level -> Peaks
  std::vector<std::vector<AudioPeak>> m_level0; // 64 samples per peak
  std::vector<std::vector<AudioPeak>> m_level1; // 256 samples per peak
  std::vector<std::vector<AudioPeak>> m_level2; // 1024 samples per peak
};

class WaveformGenerator {
public:
  static WaveformGenerator &instance();

  /**
   * @brief Asynchronously generate pyramid from decoded PCM buffer.
   */
  std::shared_ptr<WaveformPyramid>
  generateAsync(std::shared_ptr<AudioClipBuffer> buffer);
};

} // namespace xyla::audio
