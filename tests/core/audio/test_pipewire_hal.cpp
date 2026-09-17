#include <gtest/gtest.h>
#include "core/audio/hal/pipewireUtils.hpp"
#include "core/audio/hal/dummyAudioBackend.hpp"
#include <vector>

using namespace xyla::audio;

TEST(PipeWireUtilsTest, FormatsLatencyStringAccurately) {
    EXPECT_EQ(hal::PipeWireUtils::formatLatencyString(256, 48000), "256/48000");
    EXPECT_EQ(hal::PipeWireUtils::formatLatencyString(512, 96000), "512/96000");
    EXPECT_EQ(hal::PipeWireUtils::formatLatencyString(128, 44100), "128/44100");
}

TEST(PipeWireUtilsTest, InterleavesStereoPlanarChannelsAccurately) {
    const float planarL[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
    const float planarR[4] = { 10.0f, 20.0f, 30.0f, 40.0f };
    const float *channels[2] = { planarL, planarR };

    float interleaved[8] = {0};

    hal::PipeWireUtils::interleavePlanarToPacked(channels, 2, interleaved, 4);

    // Verify L, R, L, R, L, R, L, R
    EXPECT_FLOAT_EQ(interleaved[0], 1.0f);
    EXPECT_FLOAT_EQ(interleaved[1], 10.0f);
    EXPECT_FLOAT_EQ(interleaved[2], 2.0f);
    EXPECT_FLOAT_EQ(interleaved[3], 20.0f);
    EXPECT_FLOAT_EQ(interleaved[4], 3.0f);
    EXPECT_FLOAT_EQ(interleaved[5], 30.0f);
    EXPECT_FLOAT_EQ(interleaved[6], 4.0f);
    EXPECT_FLOAT_EQ(interleaved[7], 40.0f);
}

TEST(DummyAudioBackendTest, MockLifecycleAndTickExecution) {
    DummyAudioBackend backend;
    AudioDeviceConfig config;
    config.bufferSizeFrames = 256;
    config.format = AudioFormat::standardStereo(48000);

    struct MockCallback : public IAudioRenderCallback {
        int renderCount{0};
        void renderAudio(AudioBuffer &, const AudioClockInfo &) noexcept override {
            renderCount++;
        }
    } callback;

    ASSERT_TRUE(backend.initialize(config, &callback));
    EXPECT_FALSE(backend.isRunning());

    ASSERT_TRUE(backend.start());
    EXPECT_TRUE(backend.isRunning());

    // Step 5 simulated hardware periods
    for (int i = 0; i < 5; ++i) {
        backend.stepTick();
    }
    EXPECT_EQ(callback.renderCount, 5);

    ASSERT_TRUE(backend.stop());
    EXPECT_FALSE(backend.isRunning());
}
