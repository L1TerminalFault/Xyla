#pragma once

#include "audioPin.hpp"
#include "core/audio/types/audioBuffer.hpp"
#include "core/audio/types/audioBufferPool.hpp"
#include "core/audio/types/audioClock.hpp"
#include <atomic>
#include <cassert>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace xyla::audio {

/**
 * @brief Context passed to AudioNode::process on every render cycle.
 */
struct ProcessContext {
  const AudioClockInfo &clock;
  AudioBufferPool &bufferPool;
  size_t frameCount{256};
};

/**
 * @brief Realtime-safe DSP Node Interface.
 *
 * Rules inside process():
 * - NO allocations (use bufferPool for intermediate scratchbuffers).
 * - NO locks or mutexes.
 * - NO blocking system calls.
 */
class AudioNode {
public:
  explicit AudioNode(std::string nodeId, std::string name)
      : m_nodeId(std::move(nodeId)), m_name(std::move(name)) {}

  virtual ~AudioNode() = default;

  [[nodiscard]] const std::string &nodeId() const noexcept { return m_nodeId; }
  [[nodiscard]] const std::string &name() const noexcept { return m_name; }

  [[nodiscard]] const std::vector<AudioPinDescriptor> &pins() const noexcept {
    return m_pins;
  }

  // --- Offline / Graph Construction Lifecycle ---
  virtual void prepare(const AudioFormat &format, size_t maxBlockSize) {
    m_sampleRate = format.sampleRate;
    m_maxBlockSize = maxBlockSize;
  }

  virtual void reset() noexcept {}

  /**
   * @brief Resolve a parameter name to an integer index (call ONCE during
   * setup).
   */
  [[nodiscard]] int
  resolveParameterIndex(const std::string &paramId) const noexcept {
    auto it = m_paramNameToIndex.find(paramId);
    if (it != m_paramNameToIndex.end()) {
      return it->second;
    }
    return -1;
  }

  /**
   * @brief String-based parameter setter (used by UI / scripting).
   */
  void setParameter(const std::string &paramId, float value) noexcept {
    int idx = resolveParameterIndex(paramId);
    if (idx >= 0) {
      setParameterByIndex(static_cast<size_t>(idx), value);
    }
  }

  /**
   * @brief Fast indexed parameter setter (ZERO string operations, used by
   * Automation Clips).
   */
  void setParameterByIndex(size_t index, float value) noexcept {
    if (index < m_parameterValues.size() && m_parameterValues[index]) {
      m_parameterValues[index]->store(value, std::memory_order_relaxed);
    }
  }

  /**
   * @brief Fast indexed parameter getter for audio thread (ZERO string
   * operations).
   */
  [[nodiscard]] float getParameterByIndex(size_t index) const noexcept {
    if (index < m_parameterValues.size() && m_parameterValues[index]) {
      return m_parameterValues[index]->load(std::memory_order_relaxed);
    }
    return 0.0f;
  }

  /**
   * @brief Core Realtime DSP Callback.
   */
  virtual void process(const AudioBuffer *const *inputs, size_t inputCount,
                       AudioBuffer **outputs, size_t outputCount,
                       const ProcessContext &ctx) noexcept = 0;

  [[nodiscard]] bool isBypassed() const noexcept {
    return m_bypassed.load(std::memory_order_relaxed);
  }

  void setBypassed(bool bypass) noexcept {
    m_bypassed.store(bypass, std::memory_order_relaxed);
  }

protected:
  /**
   * @brief Register a pin. If it's a ControlValue, allocates a fast index.
   */
  void registerPin(AudioPinDescriptor pin) {
    if (pin.dataType == PinDataType::ControlValue) {
      size_t index = m_parameterValues.size();
      m_paramNameToIndex[pin.pinId] = static_cast<int>(index);
      m_parameterValues.push_back(
          std::make_unique<std::atomic<float>>(pin.defaultValue));
    }
    m_pins.push_back(std::move(pin));
  }

  std::string m_nodeId;
  std::string m_name;
  uint32_t m_sampleRate{48000};
  size_t m_maxBlockSize{256};
  std::atomic<bool> m_bypassed{false};

  std::vector<AudioPinDescriptor> m_pins;

  // Offline string mapping (used only when setting up connections or resolving
  // indices)
  std::unordered_map<std::string, int> m_paramNameToIndex;

  // Safe vector of unique_ptr atomics (movable, realloc-safe)
  std::vector<std::unique_ptr<std::atomic<float>>> m_parameterValues;
};

} // namespace xyla::audio
