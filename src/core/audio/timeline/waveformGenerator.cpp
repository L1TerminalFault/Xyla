#include "waveformGenerator.hpp"
#include <algorithm>

namespace xyla::audio {

WaveformGenerator &WaveformGenerator::instance() {
  static WaveformGenerator gen;
  return gen;
}

void WaveformPyramid::generateFromPcm(const AudioClipBuffer &buffer) {
  m_channelCount = buffer.channels();
  m_level0.resize(m_channelCount);
  m_level1.resize(m_channelCount);
  m_level2.resize(m_channelCount);

  for (size_t c = 0; c < m_channelCount; ++c) {
    const auto &pcm = buffer.channel(c);
    size_t totalSamples = pcm.size();

    // 1. Generate Level 0 (64 samples per bin)
    size_t numBins0 = (totalSamples + kLevel0BinSize - 1) / kLevel0BinSize;
    m_level0[c].resize(numBins0);

    for (size_t b = 0; b < numBins0; ++b) {
      size_t start = b * kLevel0BinSize;
      size_t end = std::min(start + kLevel0BinSize, totalSamples);

      float minVal = 0.0f;
      float maxVal = 0.0f;
      for (size_t i = start; i < end; ++i) {
        float s = pcm[i];
        if (s < minVal)
          minVal = s;
        if (s > maxVal)
          maxVal = s;
      }
      m_level0[c][b] = {minVal, maxVal};
    }

    // 2. Generate Level 1 from Level 0 (4 bins of L0 = 1 bin of L1: 256
    // samples)
    size_t numBins1 = (totalSamples + kLevel1BinSize - 1) / kLevel1BinSize;
    m_level1[c].resize(numBins1);

    for (size_t b = 0; b < numBins1; ++b) {
      size_t l0Start = b * 4;
      size_t l0End = std::min(l0Start + 4, numBins0);

      float minVal = 0.0f;
      float maxVal = 0.0f;
      for (size_t i = l0Start; i < l0End; ++i) {
        minVal = std::min(minVal, m_level0[c][i].min);
        maxVal = std::max(maxVal, m_level0[c][i].max);
      }
      m_level1[c][b] = {minVal, maxVal};
    }

    // 3. Generate Level 2 from Level 1 (4 bins of L1 = 1 bin of L2: 1024
    // samples)
    size_t numBins2 = (totalSamples + kLevel2BinSize - 1) / kLevel2BinSize;
    m_level2[c].resize(numBins2);

    for (size_t b = 0; b < numBins2; ++b) {
      size_t l1Start = b * 4;
      size_t l1End = std::min(l1Start + 4, numBins1);

      float minVal = 0.0f;
      float maxVal = 0.0f;
      for (size_t i = l1Start; i < l1End; ++i) {
        minVal = std::min(minVal, m_level1[c][i].min);
        maxVal = std::max(maxVal, m_level1[c][i].max);
      }
      m_level2[c][b] = {minVal, maxVal};
    }
  }

  m_isGenerated = true;
}

std::vector<AudioPeak> WaveformPyramid::getPeaks(size_t channel,
                                                 int64_t startSample,
                                                 size_t sampleCount,
                                                 double samplesPerPixel) const {
  if (!m_isGenerated || channel >= m_channelCount) {
    return {};
  }

  // Choose optimal MIP level based on zoom and index the specific channel
  const std::vector<AudioPeak> *sourceLevel = &m_level1[channel];
  size_t binSize = kLevel1BinSize;

  if (samplesPerPixel < 128.0) {
    sourceLevel = &m_level0[channel];
    binSize = kLevel0BinSize;
  } else if (samplesPerPixel > 512.0) {
    sourceLevel = &m_level2[channel];
    binSize = kLevel2BinSize;
  }

  const auto &levelPeaks = *sourceLevel;
  if (levelPeaks.empty())
    return {};

  size_t startBin =
      static_cast<size_t>(std::max<int64_t>(0, startSample / binSize));
  size_t endBin =
      static_cast<size_t>((startSample + sampleCount + binSize - 1) / binSize);
  endBin = std::min(endBin, levelPeaks.size());

  if (startBin >= endBin)
    return {};

  std::vector<AudioPeak> result;
  result.reserve(endBin - startBin);
  result.insert(result.end(), levelPeaks.begin() + startBin,
                levelPeaks.begin() + endBin);
  return result;
}

std::shared_ptr<WaveformPyramid>
WaveformGenerator::generateAsync(std::shared_ptr<AudioClipBuffer> buffer) {
  if (!buffer)
    return nullptr;

  auto pyramid = std::make_shared<WaveformPyramid>();
  pyramid->generateFromPcm(*buffer);
  return pyramid;
}

} // namespace xyla::audio
