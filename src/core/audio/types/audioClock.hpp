#pragma once

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>

namespace xyla::audio {

/**
 * @brief Master Audio Reference Clock.
 *
 * Driven directly by the hardware audio callback.
 * The video compositing engine and UI playhead slave to this clock.
 */
struct AudioClockInfo {
  int64_t hardwareSamplePosition{
      0}; // Monotonically increasing samples outputted
  int64_t timelineSamplePosition{
      0};                      // Current position along NLE timeline in samples
  double timelineSeconds{0.0}; // timelineSamplePosition / sampleRate
  uint32_t sampleRate{48000};
  uint32_t bufferSizeFrames{256};
  bool isPlaying{false};
};

class AudioMasterClock {
public:
  static AudioMasterClock &instance() {
    static AudioMasterClock clock;
    return clock;
  }

  AudioMasterClock() = default;

  void reset() noexcept {
    m_hardwareSamples.store(0, std::memory_order_relaxed);
    m_timelineSamples.store(0, std::memory_order_relaxed);
    m_sampleRate.store(48000, std::memory_order_relaxed);
    m_isPlaying.store(false, std::memory_order_relaxed);
    m_isScrubbing.store(false, std::memory_order_relaxed);
    m_hasJumped.store(false, std::memory_order_relaxed);
  }

  void updateFromRenderCallback(int64_t timelinePosSamples,
                                uint32_t framesRendered, uint32_t sampleRate,
                                bool isPlaying) noexcept {
    m_sampleRate.store(sampleRate, std::memory_order_relaxed);
    m_isPlaying.store(isPlaying, std::memory_order_relaxed);
    m_hardwareSamples.fetch_add(framesRendered, std::memory_order_relaxed);
    m_timelineSamples.store(timelinePosSamples + framesRendered,
                            std::memory_order_release);
  }

  void setTimelinePosition(int64_t samples) noexcept {
    int64_t current = m_timelineSamples.load(std::memory_order_relaxed);
    if (std::abs(samples - current) > 128) {
      // Mark that a discontinuous jump occurred (scrub or seek)
      m_hasJumped.store(true, std::memory_order_release);
    }
    m_timelineSamples.store(samples, std::memory_order_release);
  }

  [[nodiscard]] bool consumeJumpFlag() noexcept {
    return m_hasJumped.exchange(false, std::memory_order_acq_rel);
  }

  [[nodiscard]] int64_t timelineSamples() const noexcept {
    return m_timelineSamples.load(std::memory_order_acquire);
  }

  [[nodiscard]] double timelineSeconds() const noexcept {
    uint32_t sr = m_sampleRate.load(std::memory_order_relaxed);
    if (sr == 0)
      return 0.0;
    return static_cast<double>(timelineSamples()) / static_cast<double>(sr);
  }

  [[nodiscard]] int64_t samplesToTimelineFrame(double fps) const noexcept {
    if (fps <= 0.0)
      return 0;
    return static_cast<int64_t>(timelineSeconds() * fps);
  }

  [[nodiscard]] int64_t timelineFrameToSamples(int64_t frame,
                                               double fps) const noexcept {
    if (fps <= 0.0)
      return 0;
    uint32_t sr = m_sampleRate.load(std::memory_order_relaxed);
    return static_cast<int64_t>((static_cast<double>(frame) / fps) * sr);
  }

  [[nodiscard]] bool isPlaying() const noexcept {
    return m_isPlaying.load(std::memory_order_relaxed);
  }

  void setPlaying(bool playing) noexcept {
    m_isPlaying.store(playing, std::memory_order_relaxed);
  }

  void setScrubbing(bool scrubbing) noexcept {
    m_isScrubbing.store(scrubbing, std::memory_order_relaxed);
  }

  [[nodiscard]] bool isScrubbing() const noexcept {
    return m_isScrubbing.load(std::memory_order_relaxed);
  }

private:
  std::atomic<int64_t> m_hardwareSamples{0};
  std::atomic<int64_t> m_timelineSamples{0};
  std::atomic<uint32_t> m_sampleRate{48000};
  std::atomic<bool> m_isPlaying{false};
  std::atomic<bool> m_isScrubbing{false};
  std::atomic<bool> m_hasJumped{false};
};

} // namespace xyla::audio
