#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <utility>

namespace xyla::audio::dsp {

struct MixerTrackParams {
  float volume{1.0f}; // 0.0 to 2.0
  float pan{0.0f};    // -1.0 (Left) to +1.0 (Right)
  float width{1.0f};  // 0.0 (Mono) to 2.0 (Extra Wide)
  bool isMuted{false};
  bool phaseInvert{false};
  bool swapChannels{false};
};

struct MixerMeterResult {
  float peakL{0.0f};
  float peakR{0.0f};
  float rmsL{0.0f};
  float rmsR{0.0f};
  float finalGainL{0.0f};
  float finalGainR{0.0f};
};

/**
 * @brief Computes target channel gains from pan, volume, and phase inversion.
 */
inline std::pair<float, float>
computeTargetGains(const MixerTrackParams &params) noexcept {
  if (params.isMuted) {
    return {0.0f, 0.0f};
  }

  const float clampedPan = std::clamp(params.pan, -1.0f, 1.0f);
  const float phaseMod = params.phaseInvert ? -1.0f : 1.0f;

  // Linear Pan Law
  const float targetPanL = (clampedPan <= 0.0f) ? 1.0f : (1.0f - clampedPan);
  const float targetPanR = (clampedPan >= 0.0f) ? 1.0f : (1.0f + clampedPan);

  return {targetPanL * params.volume * phaseMod,
          targetPanR * params.volume * phaseMod};
}

/**
 * @brief Real-time planar DSP loop for channel swap, M/S width, ramped gain,
 * and metering. Pure C++20: Zero heap allocations, SIMD-friendly loop.
 */
inline MixerMeterResult
processMixerTrackBlock(const float *const *inputs, float *const *outputs,
                       size_t inChannels, size_t outChannels, size_t frameCount,
                       const MixerTrackParams &params, float lastGainL,
                       float lastGainR) noexcept {
  MixerMeterResult result;
  if (frameCount == 0 || !inputs || !outputs || !inputs[0] || !outputs[0]) {
    result.finalGainL = lastGainL;
    result.finalGainR = lastGainR;
    return result;
  }

  const auto [targetGainL, targetGainR] = computeTargetGains(params);
  const float width = std::clamp(params.width, 0.0f, 2.0f);
  const bool swap = params.swapChannels;

  const float stepGainL =
      (targetGainL - lastGainL) / static_cast<float>(frameCount);
  const float stepGainR =
      (targetGainR - lastGainR) / static_cast<float>(frameCount);

  float currentGainL = lastGainL;
  float currentGainR = lastGainR;

  const float *inL = inputs[0];
  const float *inR = (inChannels > 1 && inputs[1]) ? inputs[1] : inL;

  float *outL = outputs[0];
  float *outR = (outChannels > 1 && outputs[1]) ? outputs[1] : outL;

  float maxPeakL = 0.0f;
  float maxPeakR = 0.0f;
  float sumSqL = 0.0f;
  float sumSqR = 0.0f;

  for (size_t i = 0; i < frameCount; ++i) {
    float l = inL[i];
    float r = inR[i];

    // 1. Channel Swap
    if (swap) {
      std::swap(l, r);
    }

    // 2. Mid/Side Stereo Width
    if (width != 1.0f) {
      const float mid = (l + r) * 0.5f;
      const float side = (l - r) * 0.5f * width;
      l = mid + side;
      r = mid - side;
    }

    // 3. Smooth Ramped Gain & Pan
    const float finalL = l * currentGainL;
    const float finalR = r * currentGainR;

    currentGainL += stepGainL;
    currentGainR += stepGainR;

    outL[i] = finalL;
    if (outChannels > 1 && outputs[1]) {
      outR[i] = finalR;
    }

    // 4. Metering Accumulation
    const float absL = std::abs(finalL);
    const float absR = std::abs(finalR);
    if (absL > maxPeakL)
      maxPeakL = absL;
    if (absR > maxPeakR)
      maxPeakR = absR;
    sumSqL += finalL * finalL;
    sumSqR += finalR * finalR;
  }

  result.finalGainL = targetGainL;
  result.finalGainR = targetGainR;
  result.peakL = maxPeakL;
  result.peakR = maxPeakR;
  result.rmsL = std::sqrt(sumSqL / static_cast<float>(frameCount));
  result.rmsR = std::sqrt(sumSqR / static_cast<float>(frameCount));
  return result;
}

} // namespace xyla::audio::dsp
