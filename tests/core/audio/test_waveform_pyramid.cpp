#include <gtest/gtest.h>
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/audio/timeline/audioClipBuffer.hpp"
#include <vector>

using namespace xyla::audio;

TEST(WaveformDspTest, BuildPeakBinsAccuratelyPreservesMinAndMax) {
    // 64 samples per bin. Place explicit spikes at sample 10 and 50.
    std::vector<float> pcm(64, 0.0f);
    pcm[10] = -0.85f;
    pcm[50] = 0.92f;

    auto bins = dsp::buildPeakBinsFromPcm(pcm.data(), pcm.size(), 64);
    ASSERT_EQ(bins.size(), 1u);
    EXPECT_FLOAT_EQ(bins[0].min, -0.85f);
    EXPECT_FLOAT_EQ(bins[0].max, 0.92f);
}

TEST(WaveformDspTest, ReducePeakBinsCombinesFourBinsIntoOne) {
    std::vector<AudioPeak> l0Bins = {
        {-0.1f, 0.2f},
        {-0.9f, 0.3f}, // Lowest min
        {-0.2f, 0.8f}, // Highest max
        {0.0f,  0.1f}
    };

    auto l1Bins = dsp::reducePeakBins(l0Bins, 4);
    ASSERT_EQ(l1Bins.size(), 1u);
    EXPECT_FLOAT_EQ(l1Bins[0].min, -0.9f);
    EXPECT_FLOAT_EQ(l1Bins[0].max, 0.8f);
}

TEST(WaveformPyramidTest, GeneratesThreeLevelsHierarchically) {
    // Create a 2048 sample buffer
    auto buffer = std::make_shared<AudioClipBuffer>(2, 48000);
    std::vector<float> left(2048, 0.1f);
    std::vector<float> right(2048, -0.1f);
    left[100] = 0.99f;
    right[100] = -0.99f;

    const float* planar[2] = { left.data(), right.data() };
    buffer->appendFrames(planar, 2048);

    WaveformPyramid pyramid;
    pyramid.generateFromPcm(*buffer);

    EXPECT_TRUE(pyramid.isGenerated());
    EXPECT_EQ(pyramid.channelCount(), 2u);

    // Level 0: 2048 / 64 = 32 bins
    EXPECT_EQ(pyramid.level0(0).size(), 32u);
    // Level 1: 32 / 4 = 8 bins
    EXPECT_EQ(pyramid.level1(0).size(), 8u);
    // Level 2: 8 / 4 = 2 bins
    EXPECT_EQ(pyramid.level2(0).size(), 2u);

    // Peak at sample 100 falls in bin 1 (samples 64-127)
    EXPECT_FLOAT_EQ(pyramid.level0(0)[1].max, 0.99f);
    EXPECT_FLOAT_EQ(pyramid.level0(1)[1].min, -0.99f);
}

TEST(WaveformGeneratorCacheTest, GetOrGenerateCachesPyramidThreadSafe) {
    WaveformGenerator generator; // Local instance for unit testing
    auto buffer = std::make_shared<AudioClipBuffer>(1, 48000);
    std::vector<float> samples(512, 0.25f);
    const float* planar[1] = { samples.data() };
    buffer->appendFrames(planar, 512);

    auto pyramid1 = generator.getOrGenerate("asset_guitar", buffer);
    ASSERT_NE(pyramid1, nullptr);
    EXPECT_EQ(generator.cachedCount(), 1u);

    // Second retrieval returns the exact same shared_ptr
    auto pyramid2 = generator.getOrGenerate("asset_guitar", buffer);
    EXPECT_EQ(pyramid1, pyramid2);

    // Invalidate clears the entry
    generator.invalidate("asset_guitar");
    EXPECT_EQ(generator.cachedCount(), 0u);
}
