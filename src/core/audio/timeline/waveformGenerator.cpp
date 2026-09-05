#include "waveformGenerator.hpp"

#include <algorithm>

namespace xyla::audio {

WaveformGenerator &WaveformGenerator::instance() {
  static WaveformGenerator gen;
  return gen;
}

void WaveformPyramid::generateFromPcm(const AudioClipBuffer &buffer) {
  m_channelCount = buffer.channels();
  m_level0.assign(m_channelCount, {});
  m_level1.assign(m_channelCount, {});
  m_level2.assign(m_channelCount, {});

  for (size_t c = 0; c < m_channelCount; ++c) {
    const auto &pcm = buffer.channel(c);
    const size_t totalSamples = pcm.size();
    if (totalSamples == 0)
      continue;

    // Level 0 — 64 samples per bin
    const size_t numBins0 =
        (totalSamples + kLevel0BinSize - 1) / kLevel0BinSize;
    m_level0[c].resize(numBins0);
    for (size_t b = 0; b < numBins0; ++b) {
      const size_t start = b * kLevel0BinSize;
      const size_t end = std::min(start + kLevel0BinSize, totalSamples);
      float minVal = pcm[start];
      float maxVal = pcm[start];
      for (size_t i = start + 1; i < end; ++i) {
        const float s = pcm[i];
        minVal = std::min(minVal, s);
        maxVal = std::max(maxVal, s);
      }
      m_level0[c][b] = {minVal, maxVal};
    }

    // Level 1 — 4× L0 bins → 256 samples per bin
    const size_t numBins1 =
        (totalSamples + kLevel1BinSize - 1) / kLevel1BinSize;
    m_level1[c].resize(numBins1);
    for (size_t b = 0; b < numBins1; ++b) {
      const size_t l0Start = b * 4;
      const size_t l0End = std::min(l0Start + 4, numBins0);
      float minVal = m_level0[c][l0Start].min;
      float maxVal = m_level0[c][l0Start].max;
      for (size_t i = l0Start + 1; i < l0End; ++i) {
        minVal = std::min(minVal, m_level0[c][i].min);
        maxVal = std::max(maxVal, m_level0[c][i].max);
      }
      m_level1[c][b] = {minVal, maxVal};
    }

    // Level 2 — 4× L1 bins → 1024 samples per bin
    const size_t numBins2 =
        (totalSamples + kLevel2BinSize - 1) / kLevel2BinSize;
    m_level2[c].resize(numBins2);
    for (size_t b = 0; b < numBins2; ++b) {
      const size_t l1Start = b * 4;
      const size_t l1End = std::min(l1Start + 4, numBins1);
      float minVal = m_level1[c][l1Start].min;
      float maxVal = m_level1[c][l1Start].max;
      for (size_t i = l1Start + 1; i < l1End; ++i) {
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
                                                 size_t targetPixels) const {
  if (!m_isGenerated || channel >= m_channelCount || sampleCount == 0)
    return {};

  // At least 1 column; cap to avoid insane lists on huge clips
  targetPixels = std::clamp(targetPixels, size_t{1}, size_t{8192});

  const double samplesPerPixel =
      static_cast<double>(sampleCount) / static_cast<double>(targetPixels);

  // Pick MIP: prefer finer data when each pixel covers few samples
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

  std::vector<AudioPeak> result;
  result.resize(targetPixels);

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
      result[px] = {0.f, 0.f};
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

std::shared_ptr<WaveformPyramid>
WaveformGenerator::getOrGenerate(const std::string &assetId,
                                 std::shared_ptr<AudioClipBuffer> buffer) {
  if (assetId.empty() || !buffer)
    return nullptr;

  {
    std::lock_guard<std::mutex> lock(m_mutex);
    auto it = m_cache.find(assetId);
    if (it != m_cache.end() && it->second && it->second->isGenerated())
      return it->second;
  }

  auto pyramid = std::make_shared<WaveformPyramid>();
  pyramid->generateFromPcm(*buffer);

  {
    std::lock_guard<std::mutex> lock(m_mutex);
    // Another thread may have won the race — prefer existing
    auto it = m_cache.find(assetId);
    if (it != m_cache.end() && it->second && it->second->isGenerated())
      return it->second;
    m_cache[assetId] = pyramid;
  }
  return pyramid;
}

std::shared_ptr<WaveformPyramid>
WaveformGenerator::generateAsync(std::shared_ptr<AudioClipBuffer> buffer) {
  if (!buffer)
    return nullptr;
  auto pyramid = std::make_shared<WaveformPyramid>();
  pyramid->generateFromPcm(*buffer);
  return pyramid;
}

void WaveformGenerator::invalidate(const std::string &assetId) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_cache.erase(assetId);
}

void WaveformGenerator::clear() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_cache.clear();
}

} // namespace xyla::audio
