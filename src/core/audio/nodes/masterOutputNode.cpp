#include "masterOutputNode.hpp"
#include <algorithm>
#include <cmath>

namespace xyla::audio {

// Broadcast-grade smooth saturation / soft knee
inline float softClip(float s) noexcept {
  constexpr float threshold = 0.9f;
  if (s > threshold) {
    return threshold +
           (1.0f - threshold) * std::tanh((s - threshold) / (1.0f - threshold));
  } else if (s < -threshold) {
    return -threshold +
           (1.0f - threshold) * std::tanh((s + threshold) / (1.0f - threshold));
  }
  return s;
}

MasterOutputNode::MasterOutputNode(std::string nodeId)
    : AudioNode(std::move(nodeId), "Master Output") {
  registerPin(AudioPinDescriptor::makeAudioInput("master_in", "In"));
  registerPin(AudioPinDescriptor::makeAudioOutput("hardware_out", "Out"));
  registerPin(AudioPinDescriptor::makeControlInput("master_volume", "Volume",
                                                   0.0f, 1.0f, 0.8f));

  m_masterVolIndex = resolveParameterIndex("master_volume");
  m_lastGain = 0.8f;
}

void MasterOutputNode::process(const AudioBuffer *const *inputs,
                               size_t inputCount, AudioBuffer **outputs,
                               size_t outputCount,
                               const ProcessContext &ctx) noexcept {
  if (outputCount == 0 || !outputs[0])
    return;

  AudioBuffer *out = outputs[0];
  out->clear();

  if (inputCount == 0 || !inputs[0]) {
    m_peakL.store(0.0f, std::memory_order_relaxed);
    m_peakR.store(0.0f, std::memory_order_relaxed);
    return;
  }

  // Check if master clock experienced a discontinuous jump (scrub/seek)
  if (AudioMasterClock::instance().consumeJumpFlag()) {
    // Trigger a pristine 3ms crossfade (144 samples @ 48kHz)
    m_fadeFramesRemaining = 144;
  }

  const AudioBuffer *in = inputs[0];
  size_t frames = ctx.frameCount;

  float targetGain =
      (m_masterVolIndex >= 0)
          ? getParameterByIndex(static_cast<size_t>(m_masterVolIndex))
          : 0.8f;

  float stepGain = (targetGain - m_lastGain) / static_cast<float>(frames);

  size_t channels = std::min(in->channelCount(), out->channelCount());
  float maxPeakL = 0.0f;
  float maxPeakR = 0.0f;
  bool clippedThisBlock = false;

  // Snapshot fade state once for all channels to guarantee phase coherence
  int fadeStart = m_fadeFramesRemaining;

  for (size_t c = 0; c < channels; ++c) {
    const float *src = in->channelData(c);
    float *dst = out->channelData(c);
    float g = m_lastGain;
    int fadeRemaining = fadeStart;

    for (size_t i = 0; i < frames; ++i) {
      float s = src[i] * g;

      // Symmetric micro-fade envelope (prevents both pre-jump clicks and
      // post-jump pops)
      if (fadeRemaining > 0) {
        // Cosine equal-power crossfade window (0.0 -> 1.0)
        float progress = 1.0f - (static_cast<float>(fadeRemaining) / 144.0f);
        float fadeFactor = std::sin(progress * 1.57079632679f); // sin(t * pi/2)
        s *= fadeFactor;
      }

      // Smooth soft-knee saturation ceiling
      if (s > 0.95f) {
        clippedThisBlock = true;
        s = 0.95f + 0.05f * std::tanh((s - 0.95f) / 0.05f);
      } else if (s < -0.95f) {
        clippedThisBlock = true;
        s = -0.95f + 0.05f * std::tanh((s + 0.95f) / 0.05f);
      }

      dst[i] = s;
      g += stepGain;

      float absVal = std::abs(s);
      if (c == 0 && absVal > maxPeakL)
        maxPeakL = absVal;
      if (c == 1 && absVal > maxPeakR)
        maxPeakR = absVal;
    }
  }

  // Advance shared counter once per block after all channels processed
  // identically
  if (fadeStart > 0) {
    m_fadeFramesRemaining = std::max(0, fadeStart - static_cast<int>(frames));
  }

  m_lastGain = targetGain;
  m_peakL.store(maxPeakL, std::memory_order_relaxed);
  m_peakR.store(maxPeakR, std::memory_order_relaxed);

  if (clippedThisBlock) {
    m_clipped.store(true, std::memory_order_relaxed);
  }
}

} // namespace xyla::audio
