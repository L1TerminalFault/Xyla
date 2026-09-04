#pragma once

#include "core/audio/dsp/automationCurve.hpp"
#include "core/audio/graph/audioNode.hpp"
#include <string>

namespace xyla::audio {

/**
 * @brief First-Class Timeline Automation Clip.
 *
 * Lives on the NLE timeline across [startSample, startSample +
 * durationSamples]. Binds directly to targetNodeId + targetParamIndex.
 */
class AutomationClip {
public:
  AutomationClip(std::string clipId, std::string targetNodeId,
                 int targetParamIndex, int64_t startSample,
                 int64_t durationSamples)
      : m_clipId(std::move(clipId)), m_targetNodeId(std::move(targetNodeId)),
        m_targetParamIndex(targetParamIndex), m_startSample(startSample),
        m_durationSamples(durationSamples) {}

  [[nodiscard]] const std::string &clipId() const noexcept { return m_clipId; }
  [[nodiscard]] const std::string &targetNodeId() const noexcept {
    return m_targetNodeId;
  }
  [[nodiscard]] int targetParamIndex() const noexcept {
    return m_targetParamIndex;
  }
  [[nodiscard]] int64_t startSample() const noexcept { return m_startSample; }
  [[nodiscard]] int64_t durationSamples() const noexcept {
    return m_durationSamples;
  }
  [[nodiscard]] int64_t endSample() const noexcept {
    return m_startSample + m_durationSamples;
  }

  void setTimelineBounds(int64_t startSample,
                         int64_t durationSamples) noexcept {
    m_startSample = startSample;
    m_durationSamples = durationSamples;
  }

  AutomationCurve &curve() noexcept { return m_curve; }
  [[nodiscard]] const AutomationCurve &curve() const noexcept {
    return m_curve;
  }

  /**
   * @brief Evaluates and applies automation to the target node for a given
   * render block.
   */
  void applyBlock(AudioNode *targetNode, int64_t blockStartSample,
                  size_t blockFrames) const noexcept {
    if (!targetNode || m_targetParamIndex < 0)
      return;

    int64_t blockEndSample =
        blockStartSample + static_cast<int64_t>(blockFrames);

    // Overlap check
    if (blockEndSample <= m_startSample || blockStartSample >= endSample())
      return;

    // Evaluate sample at the midpoint or start of the block
    int64_t clampedSample =
        std::clamp(blockStartSample, m_startSample, endSample() - 1);
    int64_t offsetInClip = clampedSample - m_startSample;

    float val = m_curve.evaluateAtSample(offsetInClip);
    targetNode->setParameterByIndex(static_cast<size_t>(m_targetParamIndex),
                                    val);
  }

private:
  std::string m_clipId;
  std::string m_targetNodeId;
  int m_targetParamIndex{-1};

  int64_t m_startSample{0};
  int64_t m_durationSamples{0};
  AutomationCurve m_curve;
};

} // namespace xyla::audio
