#include <gtest/gtest.h>
#include "dsp/mixerTrackDsp.hpp"
#include <vector>

using namespace xyla::audio::dsp;

TEST(MixerTrackDspTest, ChannelSwapReversesLeftAndRightPlanes) {
    const float inL[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
    const float inR[4] = { 10.0f, 20.0f, 30.0f, 40.0f };
    float outL[4] = {0};
    float outR[4] = {0};

    const float* inputs[2] = { inL, inR };
    float* outputs[2] = { outL, outR };

    MixerTrackParams params;
    params.swapChannels = true;

    processMixerTrackBlock(inputs, outputs, 2, 2, 4, params, 1.0f, 1.0f);

    for (size_t i = 0; i < 4; ++i) {
        EXPECT_FLOAT_EQ(outL[i], inR[i]);
        EXPECT_FLOAT_EQ(outR[i], inL[i]);
    }
}

TEST(MixerTrackDspTest, WidthZeroCollapsesToMonoCenter) {
    const float inL[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    const float inR[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
    float outL[4] = {0};
    float outR[4] = {0};

    const float* inputs[2] = { inL, inR };
    float* outputs[2] = { outL, outR };

    MixerTrackParams params;
    params.width = 0.0f; // Collapse to mono: (L+R)/2 = 0.5 for both channels

    processMixerTrackBlock(inputs, outputs, 2, 2, 4, params, 1.0f, 1.0f);

    for (size_t i = 0; i < 4; ++i) {
        EXPECT_FLOAT_EQ(outL[i], 0.5f);
        EXPECT_FLOAT_EQ(outR[i], 0.5f);
    }
}

TEST(MixerTrackDspTest, PhaseInvertMultipliesSignalByNegativeOne) {
    const float inL[4] = { 0.75f, 0.5f, 0.25f, 0.1f };
    float outL[4] = {0};

    const float* inputs[1] = { inL };
    float* outputs[1] = { outL };

    MixerTrackParams params;
    params.phaseInvert = true;

    processMixerTrackBlock(inputs, outputs, 1, 1, 4, params, -1.0f, -1.0f);

    for (size_t i = 0; i < 4; ++i) {
        EXPECT_FLOAT_EQ(outL[i], -inL[i]);
    }
}

TEST(MixerTrackDspTest, AccurateRMSCalculation) {
    // Constant DC of 0.5f -> RMS should be exactly 0.5f
    const float inL[4] = { 0.5f, 0.5f, 0.5f, 0.5f };
    float outL[4] = {0};
    const float* inputs[1] = { inL };
    float* outputs[1] = { outL };

    MixerTrackParams params;
    auto meter = processMixerTrackBlock(inputs, outputs, 1, 1, 4, params, 1.0f, 1.0f);

    EXPECT_FLOAT_EQ(meter.peakL, 0.5f);
    EXPECT_FLOAT_EQ(meter.rmsL, 0.5f);
}
