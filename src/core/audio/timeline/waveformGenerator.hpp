#pragma once

#include "audioClipBuffer.hpp"
#include "dsp/waveformDsp.hpp"

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace xyla::audio {

/**
 * Multi-resolution peak pyramid for fast timeline waveform rendering.
 * Built once per asset; queries only slice an existing MIP level.
 */
class WaveformPyramid {
public:
  static constexpr size_t kLevel0BinSize = 64;   // fine
  static constexpr size_t kLevel1BinSize = 256;  // medium
  static constexpr size_t kLevel2BinSize = 1024; // coarse

  WaveformPyramid() = default;

  void generateFromPcm(const AudioClipBuffer &buffer);
  void generateFromRawPcm(const float *const *channels, size_t channelCount,
                          size_t totalFrames);

  /**
   * Slice peaks for [startSample, startSample + sampleCount) at a zoom-driven
   * MIP level. Does not allocate from PCM — only copies from the prebuilt
   * level.
   */
  [[nodiscard]] std::vector<AudioPeak> getPeaks(size_t channel,
                                                int64_t startSample,
                                                size_t sampleCount,
                                                size_t targetPixels) const;

  [[nodiscard]] bool isGenerated() const noexcept { return m_isGenerated; }
  [[nodiscard]] size_t channelCount() const noexcept { return m_channelCount; }

  // Direct level inspectors for unit testing
  [[nodiscard]] const std::vector<AudioPeak> &level0(size_t channel) const {
    return m_level0.at(channel);
  }
  [[nodiscard]] const std::vector<AudioPeak> &level1(size_t channel) const {
    return m_level1.at(channel);
  }
  [[nodiscard]] const std::vector<AudioPeak> &level2(size_t channel) const {
    return m_level2.at(channel);
  }

private:
  bool m_isGenerated{false};
  size_t m_channelCount{0};

  std::vector<std::vector<AudioPeak>> m_level0;
  std::vector<std::vector<AudioPeak>> m_level1;
  std::vector<std::vector<AudioPeak>> m_level2;
};

/**
 * Process-wide cache of pyramids keyed by asset id.
 * generateFromPcm runs at most once per asset (until invalidate/clear).
 */
class WaveformGenerator {
public:
  static WaveformGenerator &instance();

  WaveformGenerator() = default;
  ~WaveformGenerator() = default;

  WaveformGenerator(const WaveformGenerator &) = delete;
  WaveformGenerator &operator=(const WaveformGenerator &) = delete;

  /**
   * Return cached pyramid for assetId, or build once from buffer and cache it.
   * Thread-safe. Safe to call from UI / worker threads.
   */
  std::shared_ptr<WaveformPyramid>
  getOrGenerate(const std::string &assetId,
                std::shared_ptr<AudioClipBuffer> buffer);

  /**
   * Legacy entry: builds a pyramid without caching.
   */
  std::shared_ptr<WaveformPyramid>
  generateAsync(std::shared_ptr<AudioClipBuffer> buffer);

  void invalidate(const std::string &assetId);
  void clear();

  [[nodiscard]] size_t cachedCount() const;

private:
  mutable std::mutex m_mutex;
  std::unordered_map<std::string, std::shared_ptr<WaveformPyramid>> m_cache;
};

} // namespace xyla::audio
