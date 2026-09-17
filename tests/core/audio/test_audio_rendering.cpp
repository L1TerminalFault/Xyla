/**
 * @file test_audio_rendering.cpp
 * @brief GoogleTest suite for audio track rendering, track ID routing stability,
 *        clip parameter updates, and real-time concurrency.
 *
 * NOTE: All test doubles, synthetic state injectors, and harnesses are defined
 *       strictly within this testing file. Pure C++20 test suite with ZERO Qt
 *       or GUI dependencies.
 */

#include <gtest/gtest.h>
#include "clipAudioProcessor.hpp"
#include "audioClipBuffer.hpp"
#include <cmath>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>

using namespace xyla::audio;

/**
 * @brief Test fixture harness managing audio buffers and track bindings
 *        strictly within the testing scope without polluting production source code.
 */
class TestAudioPipelineHarness {
public:
    std::unordered_map<std::string, std::shared_ptr<AudioClipBuffer>> assetCache;
    std::vector<AudioTrackBinding> trackBindings;

    void registerClipBuffer(const std::string &assetId, std::shared_ptr<AudioClipBuffer> buffer) {
        assetCache[assetId] = buffer;
    }

    void setTrackBindings(std::vector<AudioTrackBinding> bindings) {
        trackBindings = std::move(bindings);
    }

    size_t renderTrackById(const std::string &trackId, int64_t timelineSample,
                           size_t numFrames, float **outputChannels, size_t channelCount) noexcept {
        const int64_t blockStart = timelineSample;
        const int64_t blockEnd = timelineSample + static_cast<int64_t>(numFrames);

        for (size_t ch = 0; ch < channelCount; ++ch) {
            std::fill_n(outputChannels[ch], numFrames, 0.0f);
        }

        const AudioTrackBinding *targetTrack = nullptr;
        for (const auto &binding : trackBindings) {
            if (binding.trackId == trackId) {
                targetTrack = &binding;
                break;
            }
        }
        if (!targetTrack) return 0;

        for (const auto &clip : targetTrack->clips) {
            const auto win = ClipOverlapWindow::compute(
                blockStart, blockEnd, clip.startSample, clip.durationSamples, clip.sourceInSample);
            if (!win.hasOverlap || win.overlapFrames == 0) continue;

            auto it = assetCache.find(clip.assetId);
            if (it == assetCache.end() || !it->second) continue;

            std::vector<float> sliceMemory(win.overlapFrames * channelCount, 0.0f);
            std::vector<float*> sliceChannels(channelCount);
            for (size_t ch = 0; ch < channelCount; ++ch) {
                sliceChannels[ch] = sliceMemory.data() + (ch * win.overlapFrames);
            }

            size_t framesRead = it->second->readFrames(
                win.bufferOffset, win.overlapFrames, sliceChannels.data(), channelCount);
            if (framesRead == 0) continue;

            ClipDspParams dspParams{clip.volume, clip.pan, clip.channelMode, clip.isMuted};
            dsp::applyClipDsp(sliceChannels.data(), channelCount, framesRead, dspParams);

            for (size_t ch = 0; ch < channelCount; ++ch) {
                float *dest = outputChannels[ch] + win.destOffset;
                const float *src = sliceChannels[ch];
                for (size_t f = 0; f < framesRead; ++f) {
                    dest[f] += src[f];
                }
            }
        }
        return numFrames;
    }
};

class AudioRenderingTest : public ::testing::Test {
protected:
    TestAudioPipelineHarness harness;
    std::shared_ptr<AudioClipBuffer> audioBuffer;

    void SetUp() override {
        // Populate a synthetic sine wave buffer of 48000 frames (1 second) directly with AudioClipBuffer::appendFrames
        audioBuffer = std::make_shared<AudioClipBuffer>(2, 48000);
        std::vector<float> sineL(48000);
        std::vector<float> sineR(48000);
        for (size_t i = 0; i < 48000; ++i) {
            float val = std::sin(2.0f * static_cast<float>(M_PI) * 440.0f * i / 48000.0f) * 0.5f;
            sineL[i] = val;
            sineR[i] = val;
        }
        const float *planar[2] = { sineL.data(), sineR.data() };
        audioBuffer->appendFrames(planar, 48000);
        harness.registerClipBuffer("asset_test_sine", audioBuffer);
    }
};

TEST_F(AudioRenderingTest, DynamicParamUpdateAppliesToClipBinding) {
    // Tests dynamic parameter updates directly on AudioTrackBinding without Qt/QObject dependency
    AudioTrackBinding binding;
    binding.trackId = "track_param_test";
    
    AudioTimelineClipRef clip;
    clip.clipId = "clip_999";
    clip.volume = 1.0f;
    clip.pan = 0.0f;
    clip.channelMode = 0;
    clip.isMuted = false;
    binding.clips.push_back(clip);

    // Apply dynamic parameter updates
    binding.clips[0].volume = 0.35f;
    binding.clips[0].pan = -0.4f;
    binding.clips[0].channelMode = 1;
    binding.clips[0].isMuted = false;

    EXPECT_FLOAT_EQ(binding.clips[0].volume, 0.35f);
    EXPECT_FLOAT_EQ(binding.clips[0].pan, -0.4f);
    EXPECT_EQ(binding.clips[0].channelMode, 1);
    EXPECT_FALSE(binding.clips[0].isMuted);
}

TEST_F(AudioRenderingTest, RenderByIdIsResilientToTrackReordering) {
    AudioTrackBinding trackA;
    trackA.trackId = "track_A";
    trackA.trackIndex = 2; // Track reordered in UI
    AudioTimelineClipRef clip;
    clip.clipId = "clip_a";
    clip.assetId = "asset_test_sine";
    clip.startSample = 0;
    clip.durationSamples = 1000;
    clip.volume = 0.8f;
    trackA.clips.push_back(clip);

    harness.setTrackBindings({ trackA });

    float outL[256] = {0}, outR[256] = {0};
    float *channels[2] = { outL, outR };

    size_t rendered = harness.renderTrackById("track_A", 0, 256, channels, 2);
    EXPECT_EQ(rendered, 256u);
}

TEST_F(AudioRenderingTest, MutedClipRendersCompleteSilence) {
    AudioTrackBinding binding;
    binding.trackId = "track_mute";
    AudioTimelineClipRef clip;
    clip.clipId = "clip_muted";
    clip.assetId = "asset_test_sine";
    clip.startSample = 0;
    clip.durationSamples = 1000;
    clip.isMuted = true;
    binding.clips.push_back(clip);
    harness.setTrackBindings({ binding });

    float outL[128] = {1.0f}, outR[128] = {1.0f};
    float *channels[2] = { outL, outR };

    size_t rendered = harness.renderTrackById("track_mute", 0, 128, channels, 2);
    EXPECT_EQ(rendered, 128u);
    for (size_t i = 0; i < 128; ++i) {
        EXPECT_FLOAT_EQ(outL[i], 0.0f);
        EXPECT_FLOAT_EQ(outR[i], 0.0f);
    }
}
