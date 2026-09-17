#include "waveformGenerator.hpp"
#include <algorithm>

namespace xyla::audio {

WaveformGenerator &WaveformGenerator::instance() {
  static WaveformGenerator gen;
  return gen;
}

void WaveformPyramid::generateFromRawPcm(const float *const *channels,
                                         size_t channelCount,
                                         size_t totalFrames) {
  m_channelCount = channelCount;
  m_level0.assign(m_channelCount, {});
  m_level1.assign(m_channelCount, {});
  m_level2.assign(m_channelCount, {});

  for (size_t c = 0; c < m_channelCount; ++c) {
    if (!channels || !channels[c] || totalFrames == 0) {
      continue;
    }

    // Level 0 — 64 samples per bin
    m_level0[c] =
        dsp::buildPeakBinsFromPcm(channels[c], totalFrames, kLevel0BinSize);

    // Level 1 — 4× L0 bins → 256 samples per bin
    m_level1[c] = dsp::reducePeakBins(m_level0[c], 4);

    // Level 2 — 4× L1 bins → 1024 samples per bin
    m_level2[c] = dsp::reducePeakBins(m_level1[c], 4);
  }

  m_isGenerated = true;
}

void WaveformPyramid::generateFromPcm(const AudioClipBuffer &buffer) {
  m_channelCount = buffer.channels();
  std::vector<const float *> channelPointers(m_channelCount);
  size_t totalFrames = 0;

  for (size_t c = 0; c < m_channelCount; ++c) {
    const auto &pcm = buffer.channel(c);
    channelPointers[c] = pcm.data();
    totalFrames = std::max(totalFrames, pcm.size());
  }

  generateFromRawPcm(channelPointers.data(), m_channelCount, totalFrames);
}

std::vector<AudioPeak> WaveformPyramid::getPeaks(size_t channel,
                                                 int64_t startSample,
                                                 size_t sampleCount,
                                                 size_t targetPixels) const {
  if (!m_isGenerated || channel >= m_channelCount || sampleCount == 0) {
    return {};
  }

  targetPixels = std::clamp(targetPixels, size_t{1}, size_t{8192});
  const double samplesPerPixel =
      static_cast<double>(sampleCount) / static_cast<double>(targetPixels);

  // Pick MIP level based on zoom
  const std::vector<AudioPeak> *sourceLevel = &m_level1[channel];
  size_t binSize = kLevel1BinSize;

  if (samplesPerPixel < 128.0) {
    sourceLevel = &m_level0[channel];
    binSize = kLevel0BinSize;
  } else if (samplesPerPixel > 512.0) {
    sourceLevel = &m_level2[channel];
    binSize = kLevel2BinSize;
  }

  return dsp::slicePeaksForPixels(*sourceLevel, binSize, startSample,
                                  sampleCount, targetPixels);
}

std::shared_ptr<WaveformPyramid>
WaveformGenerator::getOrGenerate(const std::string &assetId,
                                 std::shared_ptr<AudioClipBuffer> buffer) {
  if (assetId.empty() || !buffer) {
    return nullptr;
  }

  {
    std::lock_guard<std::mutex> lock(m_mutex);
    auto it = m_cache.find(assetId);
    if (it != m_cache.end() && it->second && it->second->isGenerated()) {
      return it->second;
    }
  }

  auto pyramid = std::make_shared<WaveformPyramid>();
  pyramid->generateFromPcm(*buffer);

  {
    std::lock_guard<std::mutex> lock(m_mutex);
    // Another thread may have won the race — prefer existing if generated
    auto it = m_cache.find(assetId);
    if (it != m_cache.end() && it->second && it->second->isGenerated()) {
      return it->second;
    }
    m_cache[assetId] = pyramid;
  }
  return pyramid;
}

std::shared_ptr<WaveformPyramid>
WaveformGenerator::generateAsync(std::shared_ptr<AudioClipBuffer> buffer) {
  if (!buffer) {
    return nullptr;
  }
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

size_t WaveformGenerator::cachedCount() const {
  std::lock_guard<std::mutex> lock(m_mutex);
  return m_cache.size();
}

} // namespace xyla::audio
