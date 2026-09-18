#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace xyla::audio {

struct AudioPeak {
  float min{0.0f};
  float max{0.0f};

  bool operator==(const AudioPeak &other) const noexcept {
    return min == other.min && max == other.max;
  }
};

namespace dsp {

/**
 * @brief Computes min/max peak bins from raw PCM samples (Level 0).
 */
inline std::vector<AudioPeak>
buildPeakBinsFromPcm(const float *pcm, size_t totalSamples, size_t binSize) {
  if (!pcm || totalSamples == 0 || binSize == 0) {
    return {};
  }

  const size_t numBins = (totalSamples + binSize - 1) / binSize;
  std::vector<AudioPeak> bins(numBins);

  for (size_t b = 0; b < numBins; ++b) {
    const size_t start = b * binSize;
    const size_t end = std::min(start + binSize, totalSamples);

    float minVal = pcm[start];
    float maxVal = pcm[start];
    for (size_t i = start + 1; i < end; ++i) {
      const float s = pcm[i];
      minVal = std::min(minVal, s);
      maxVal = std::max(maxVal, s);
    }
    bins[b] = {minVal, maxVal};
  }
  return bins;
}

/**
 * @brief Downsamples an existing peak pyramid level by factor of 4 (Level 0 ->
 * Level 1 -> Level 2).
 */
inline std::vector<AudioPeak>
reducePeakBins(const std::vector<AudioPeak> &sourceBins,
               size_t reductionFactor = 4) {
  if (sourceBins.empty() || reductionFactor == 0) {
    return {};
  }

  const size_t srcSize = sourceBins.size();
  const size_t numBins = (srcSize + reductionFactor - 1) / reductionFactor;
  std::vector<AudioPeak> result(numBins);

  for (size_t b = 0; b < numBins; ++b) {
    const size_t start = b * reductionFactor;
    const size_t end = std::min(start + reductionFactor, srcSize);

    float minVal = sourceBins[start].min;
    float maxVal = sourceBins[start].max;
    for (size_t i = start + 1; i < end; ++i) {
      minVal = std::min(minVal, sourceBins[i].min);
      maxVal = std::max(maxVal, sourceBins[i].max);
    }
    result[b] = {minVal, maxVal};
  }
  return result;
}

/**
 * @brief Slices peak bins for [startSample, startSample + sampleCount) onto a
 * target pixel count.
 */
inline std::vector<AudioPeak>
slicePeaksForPixels(const std::vector<AudioPeak> &levelPeaks, size_t binSize,
                    int64_t startSample, size_t sampleCount,
                    size_t targetPixels) {
  if (levelPeaks.empty() || sampleCount == 0 || binSize == 0) {
    return {};
  }

  targetPixels = std::clamp(targetPixels, size_t{1}, size_t{8192});
  const double samplesPerPixel =
      static_cast<double>(sampleCount) / static_cast<double>(targetPixels);

  std::vector<AudioPeak> result(targetPixels);

  for (size_t px = 0; px < targetPixels; ++px) {
    const int64_t segStart =
        startSample + static_cast<int64_t>(px * samplesPerPixel);
    const int64_t segEnd =
        startSample + static_cast<int64_t>((px + 1) * samplesPerPixel);

    size_t bin0 = static_cast<size_t>(
        std::max<int64_t>(0, segStart / static_cast<int64_t>(binSize)));
    size_t bin1 = static_cast<size_t>(
        (std::max<int64_t>(segEnd - 1, 0) + static_cast<int64_t>(binSize) - 1) /
        static_cast<int64_t>(binSize));

    bin1 = std::min(bin1, levelPeaks.size());
    bin0 = std::min(bin0, levelPeaks.size());

    if (bin0 >= bin1) {
      result[px] = {0.0f, 0.0f};
      continue;
    }

    float mn = levelPeaks[bin0].min;
    float mx = levelPeaks[bin0].max;
    for (size_t b = bin0 + 1; b < bin1; ++b) {
      mn = std::min(mn, levelPeaks[b].min);
      mx = std::max(mx, levelPeaks[b].max);
    }
    result[px] = {mn, mx};
  }
  return result;
}

} // namespace dsp
} // namespace xyla::audio
