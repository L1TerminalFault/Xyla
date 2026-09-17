#include <gtest/gtest.h>
#include "core/audio/dsp/masterLimiterDsp.hpp"
#include "graph/audioGraphTopology.hpp"
#include <vector>
#include <cmath>

using namespace xyla::audio;

// ==============================================================================
// Master Limiter & DSP Tests
// ==============================================================================
TEST(MasterLimiterDspTest, SoftClipSaturatesGracefullyAboveThreshold) {
    // Signals under 0.90 remain perfectly linear
    EXPECT_FLOAT_EQ(dsp::softClip(0.5f, 0.90f), 0.5f);
    EXPECT_FLOAT_EQ(dsp::softClip(-0.5f, 0.90f), -0.5f);

    // Signals over threshold are compressed toward ceiling (1.0f)
    float clipped1 = dsp::softClip(1.1f, 0.90f);
    float clipped2 = dsp::softClip(1.5f, 0.90f);
    float clippedExtreme = dsp::softClip(5.0f, 0.90f);

    // Guaranteed never to exceed ceiling 1.0f
    EXPECT_LE(clipped1, 1.0f);
    EXPECT_LE(clipped2, 1.0f);
    EXPECT_LE(clippedExtreme, 1.0f);

    // Strictly monotonic progression under saturation
    EXPECT_GT(clipped2, clipped1);
    EXPECT_GE(clippedExtreme, clipped2);
}

TEST(MasterLimiterDspTest, MicroFadeStartsAtZeroAndRampsSmoothly) {
    // Frame remaining = 144 (start of fade) -> Factor should be 0.0
    float startFactor = dsp::computeMicroFadeFactor(144, 144);
    EXPECT_NEAR(startFactor, 0.0f, 1e-4f);

    // Frame remaining = 0 (end of fade) -> Factor should be 1.0
    float endFactor = dsp::computeMicroFadeFactor(0, 144);
    EXPECT_FLOAT_EQ(endFactor, 1.0f);

    // Midpoint should follow equal-power sine curve
    float midFactor = dsp::computeMicroFadeFactor(72, 144);
    EXPECT_NEAR(midFactor, std::sin(0.5f * 1.57079632679f), 1e-3f);
}

// ==============================================================================
// Audio Graph Topology & Sorting Tests
// ==============================================================================
TEST(AudioGraphTopologyTest, DisconnectAllRemovesAllCascadingPins) {
    std::vector<GraphConnection> conns = {
        {"clip_1", "out", "track_1", "in"},
        {"track_1", "out", "master", "in"},
        {"clip_2", "out", "track_2", "in"}
    };

    AudioGraphTopology::disconnectAllNodePins(conns, "track_1");

    // Both {"clip_1" -> "track_1"} and {"track_1" -> "master"} must be purged
    EXPECT_EQ(conns.size(), 1u);
    EXPECT_EQ(conns[0].srcNodeId, "clip_2");
    EXPECT_EQ(conns[0].dstNodeId, "track_2");
}

TEST(AudioGraphTopologyTest, ComputesCorrectTopologicalExecutionOrder) {
    std::vector<std::string> nodeIds = {"master", "synth", "reverb"};
    std::vector<GraphConnection> conns = {
        {"synth", "out", "reverb", "in"},
        {"reverb", "out", "master", "in"}
    };

    auto order = AudioGraphTopology::computeTopologicalOrder(nodeIds, conns);

    // Synth must process before Reverb, and Reverb before Master
    ASSERT_EQ(order.size(), 3u);
    EXPECT_EQ(order[0], "synth");
    EXPECT_EQ(order[1], "reverb");
    EXPECT_EQ(order[2], "master");
}
