#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace xyla::audio::dsp {

/**
 * @brief Broadcast-grade smooth soft-knee saturation ceiling.
 * Formula: threshold + (1 - threshold) * tanh((s - threshold) / (1 -
 * threshold))
 */
inline float softClip(float s, float threshold = 0.90f) noexcept {
  if (s > threshold) {
    const float margin = 1.0f - threshold;
    return threshold + margin * std::tanh((s - threshold) / margin);
  } else if (s < -threshold) {
    const float margin = 1.0f - threshold;
    return -threshold + margin * std::tanh((s + threshold) / margin);
  }
  return s;
}

/**
 * @brief Equal-power cosine crossfade curve for seek/scrub click suppression.
 * @param remainingFrames Frames left in fade
 * @param totalFadeFrames Total window length (e.g. 144 samples @ 48kHz for 3ms)
 */
inline float computeMicroFadeFactor(int remainingFrames,
                                    int totalFadeFrames) noexcept {
  if (totalFadeFrames <= 0 || remainingFrames <= 0)
    return 1.0f;
  float progress = 1.0f - (static_cast<float>(remainingFrames) /
                           static_cast<float>(totalFadeFrames));
  progress = std::clamp(progress, 0.0f, 1.0f);
  return std::sin(progress * 1.5707963267948966f); // sin(t * pi/2)
}

struct MasterDspBlockResult {
  float peakL{0.0f};
  float peakR{0.0f};
  bool clipped{false};
  float finalGain{1.0f};
  int remainingFadeFrames{0};
};

/**
 * @brief Real-time safe block processor for master gain, micro-fade, and
 * saturation. Pure C++20: Zero allocations, zero external dependencies.
 */
inline MasterDspBlockResult
processMasterBlock(const float *const *inputs, float *const *outputs,
                   size_t channelCount, size_t frameCount, float startGain,
                   float targetGain, int initialFadeFrames,
                   int totalFadeWindow = 144, float ceiling = 0.95f) noexcept {
  MasterDspBlockResult result;
  result.remainingFadeFrames = initialFadeFrames;
  if (channelCount == 0 || frameCount == 0 || !inputs || !outputs) {
    result.finalGain = targetGain;
    return result;
  }

  const float stepGain = (frameCount > 0) ? (targetGain - startGain) /
                                                static_cast<float>(frameCount)
                                          : 0.0f;
  const int fadeStart = initialFadeFrames;
  float maxPeakL = 0.0f;
  float maxPeakR = 0.0f;
  bool anyClipped = false;

  for (size_t c = 0; c < channelCount; ++c) {
    const float *src = inputs[c];
    float *dst = outputs[c];
    if (!src || !dst)
      continue;

    float g = startGain;
    int fadeRemaining = fadeStart;

    for (size_t i = 0; i < frameCount; ++i) {
      float s = src[i] * g;

      // Apply symmetric micro-fade envelope if scrub/seek occurred
      if (fadeRemaining > 0) {
        s *= computeMicroFadeFactor(fadeRemaining, totalFadeWindow);
        --fadeRemaining;
      }

      // Soft-knee ceiling
      if (s > ceiling) {
        anyClipped = true;
        const float margin = 1.0f - ceiling;
        s = ceiling + margin * std::tanh((s - ceiling) / margin);
      } else if (s < -ceiling) {
        anyClipped = true;
        const float margin = 1.0f - ceiling;
        s = -ceiling + margin * std::tanh((s + ceiling) / margin);
      }

      dst[i] = s;
      g += stepGain;

      const float absVal = std::abs(s);
      if (c == 0 && absVal > maxPeakL)
        maxPeakL = absVal;
      if (c == 1 && absVal > maxPeakR)
        maxPeakR = absVal;
    }
  }

  if (fadeStart > 0) {
    result.remainingFadeFrames =
        std::max(0, fadeStart - static_cast<int>(frameCount));
  }
  result.finalGain = targetGain;
  result.peakL = maxPeakL;
  result.peakR = maxPeakR;
  result.clipped = anyClipped;
  return result;
}

} // namespace xyla::audio::dsp
