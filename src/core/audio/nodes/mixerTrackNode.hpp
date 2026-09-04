#pragma once

#include "core/audio/graph/audioNode.hpp"
#include <atomic>

namespace xyla::audio {

class MixerTrackNode : public AudioNode {
public:
  explicit MixerTrackNode(std::string nodeId, std::string name);
  ~MixerTrackNode() override = default;

  void process(const AudioBuffer *const *inputs, size_t inputCount,
               AudioBuffer **outputs, size_t outputCount,
               const ProcessContext &ctx) noexcept override;

  // Metering readouts (Lock-free polled by QML / UI)
  [[nodiscard]] float peakL() const noexcept {
    return m_peakL.load(std::memory_order_relaxed);
  }
  [[nodiscard]] float peakR() const noexcept {
    return m_peakR.load(std::memory_order_relaxed);
  }
  [[nodiscard]] float rmsL() const noexcept {
    return m_rmsL.load(std::memory_order_relaxed);
  }
  [[nodiscard]] float rmsR() const noexcept {
    return m_rmsR.load(std::memory_order_relaxed);
  }

  // Fast direct atomic controls
  void setVolume(float linearVol) noexcept {
    setParameter("volume", linearVol);
  }
  void setPan(float pan) noexcept {
    setParameter("pan", pan);
  } // -1.0 (Left) to +1.0 (Right)
  void setMuted(bool mute) noexcept {
    setParameter("mute", mute ? 1.0f : 0.0f);
  }
  void setSolo(bool solo) noexcept { setParameter("solo", solo ? 1.0f : 0.0f); }
  void setStereoWidth(float width) noexcept {
    setParameter("width", width);
  } // 0.0 = Mono, 1.0 = Normal, 2.0 = Extra Wide
  void setPhaseInvert(bool invert) noexcept {
    setParameter("phase_invert", invert ? 1.0f : 0.0f);
  }
  void setChannelSwap(bool swap) noexcept {
    setParameter("channel_swap", swap ? 1.0f : 0.0f);
  }

private:
  // Smoothing history for click-free de-zippering
  float m_lastGainL{1.0f};
  float m_lastGainR{1.0f};

  // Atomic Metering registers
  std::atomic<float> m_peakL{0.0f};
  std::atomic<float> m_peakR{0.0f};
  std::atomic<float> m_rmsL{0.0f};
  std::atomic<float> m_rmsR{0.0f};
};

} // namespace xyla::audio
