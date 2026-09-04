#pragma once

#include "core/audio/graph/audioNode.hpp"
#include <atomic>

namespace xyla::audio {

class MasterOutputNode : public AudioNode {
public:
  explicit MasterOutputNode(std::string nodeId = "master_out");
  ~MasterOutputNode() override = default;

  void process(const AudioBuffer *const *inputs, size_t inputCount,
               AudioBuffer **outputs, size_t outputCount,
               const ProcessContext &ctx) noexcept override;

  [[nodiscard]] float peakL() const noexcept {
    return m_peakL.load(std::memory_order_relaxed);
  }
  [[nodiscard]] float peakR() const noexcept {
    return m_peakR.load(std::memory_order_relaxed);
  }
  [[nodiscard]] bool isClipping() const noexcept {
    return m_clipped.load(std::memory_order_relaxed);
  }
  void resetClipIndicator() noexcept {
    m_clipped.store(false, std::memory_order_relaxed);
  }

  void setMasterVolume(float linearGain) noexcept {
    setParameter("master_volume", linearGain);
  }

private:
  float m_lastGain{1.0f};
  int m_masterVolIndex{-1};
  std::atomic<float> m_peakL{0.0f};
  int m_fadeFramesRemaining{0};
  std::atomic<float> m_peakR{0.0f};
  std::atomic<bool> m_clipped{false};
};

} // namespace xyla::audio
