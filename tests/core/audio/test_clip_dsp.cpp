/**
 * @file test_clip_dsp.cpp
 * @brief GoogleTest suite for dsp::applyClipDsp, stereo pan law, channel remapping, and mute.
 */

#include <gtest/gtest.h>
#include "core/audio/dsp/clipAudioProcessor.hpp"
#include <vector>
#include <cmath>

using namespace xyla::audio;

class ClipDspTest : public ::testing::Test {
protected:
    static constexpr size_t kFrameCount = 64;
    float m_left[kFrameCount];
    float m_right[kFrameCount];
    float *m_channels[2];

    void SetUp() override {
        std::fill_n(m_left, kFrameCount, 1.0f);
        std::fill_n(m_right, kFrameCount, 1.0f);
        m_channels[0] = m_left;
        m_channels[1] = m_right;
    }
};

// ============================================================================
// 1. Identity & Volume Scaling
// ============================================================================

TEST_F(ClipDspTest, UnityGainCenterPanMaintainsSignal) {
    ClipDspParams params{1.0f, 0.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    for (size_t i = 0; i < kFrameCount; ++i) {
        EXPECT_FLOAT_EQ(m_left[i], 1.0f);
        EXPECT_FLOAT_EQ(m_right[i], 1.0f);
    }
}

TEST_F(ClipDspTest, VolumeAttenuationAndBoost) {
    // 50% attenuation
    ClipDspParams attenParams{0.5f, 0.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, attenParams);
    EXPECT_FLOAT_EQ(m_left[0], 0.5f);
    EXPECT_FLOAT_EQ(m_right[0], 0.5f);

    // Boost 2.0x
    ClipDspParams boostParams{2.0f, 0.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, boostParams);
    EXPECT_FLOAT_EQ(m_left[0], 1.0f); // 0.5 * 2.0 = 1.0
    EXPECT_FLOAT_EQ(m_right[0], 1.0f);
}

// ============================================================================
// 2. Mute & Zero-Gain Guards
// ============================================================================

TEST_F(ClipDspTest, ExplicitMuteZeroesAllChannels) {
    ClipDspParams params{1.0f, 0.0f, 0, true /* isMuted */};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    for (size_t i = 0; i < kFrameCount; ++i) {
        EXPECT_FLOAT_EQ(m_left[i], 0.0f);
        EXPECT_FLOAT_EQ(m_right[i], 0.0f);
    }
}

TEST_F(ClipDspTest, EpsilonVolumeThresholdTreatedAsMute) {
    ClipDspParams params{0.00005f /* <= 0.0001f */, 0.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 0.0f);
    EXPECT_FLOAT_EQ(m_right[0], 0.0f);
}

TEST_F(ClipDspTest, ChannelModeMuteZeroesAllChannels) {
    ClipDspParams params{1.0f, 0.0f, static_cast<int>(ChannelMode::Mute), false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 0.0f);
    EXPECT_FLOAT_EQ(m_right[0], 0.0f);
}

// ============================================================================
// 3. Stereo Pan Law (-1.0 to +1.0)
// ============================================================================

TEST_F(ClipDspTest, HardLeftPanMutesRightChannel) {
    ClipDspParams params{1.0f, -1.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 1.0f);
    EXPECT_FLOAT_EQ(m_right[0], 0.0f);
}

TEST_F(ClipDspTest, HardRightPanMutesLeftChannel) {
    ClipDspParams params{1.0f, 1.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 0.0f);
    EXPECT_FLOAT_EQ(m_right[0], 1.0f);
}

TEST_F(ClipDspTest, HalfPanGainsCalculatedAccurately) {
    // Pan = -0.5: gainL = 1.0, gainR = 1.0 + (-0.5) = 0.5
    ClipDspParams panLeftHalf{1.0f, -0.5f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, panLeftHalf);
    EXPECT_FLOAT_EQ(m_left[0], 1.0f);
    EXPECT_FLOAT_EQ(m_right[0], 0.5f);

    // Reset and test Pan = +0.5: gainL = 1.0 - 0.5 = 0.5, gainR = 1.0
    std::fill_n(m_left, kFrameCount, 1.0f);
    std::fill_n(m_right, kFrameCount, 1.0f);
    ClipDspParams panRightHalf{1.0f, 0.5f, 0, false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, panRightHalf);
    EXPECT_FLOAT_EQ(m_left[0], 0.5f);
    EXPECT_FLOAT_EQ(m_right[0], 1.0f);
}

// ============================================================================
// 4. Channel Remapping Modes
// ============================================================================

TEST_F(ClipDspTest, ChannelModeMonoLeftDuplicatesLeftChannel) {
    std::fill_n(m_left, kFrameCount, 0.35f);
    std::fill_n(m_right, kFrameCount, 0.95f); // Overwritten

    ClipDspParams params{1.0f, 0.0f, static_cast<int>(ChannelMode::MonoLeft), false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 0.35f);
    EXPECT_FLOAT_EQ(m_right[0], 0.35f);
}

TEST_F(ClipDspTest, ChannelModeMonoRightDuplicatesRightChannel) {
    std::fill_n(m_left, kFrameCount, 0.12f); // Overwritten
    std::fill_n(m_right, kFrameCount, 0.88f);

    ClipDspParams params{1.0f, 0.0f, static_cast<int>(ChannelMode::MonoRight), false};
    dsp::applyClipDsp(m_channels, 2, kFrameCount, params);

    EXPECT_FLOAT_EQ(m_left[0], 0.88f);
    EXPECT_FLOAT_EQ(m_right[0], 0.88f);
}

// ============================================================================
// 5. Robustness & Null Safety
// ============================================================================

TEST_F(ClipDspTest, ZeroFramesReadReturnsImmediatelyWithoutError) {
    ClipDspParams params{1.0f, 0.0f, 0, false};
    dsp::applyClipDsp(m_channels, 2, 0, params);
    EXPECT_FLOAT_EQ(m_left[0], 1.0f);
}

TEST_F(ClipDspTest, NullPointerOrZeroChannelsHandledGracefully) {
    ClipDspParams params{1.0f, 0.0f, 0, false};
    dsp::applyClipDsp(nullptr, 0, kFrameCount, params);
    SUCCEED();
}

