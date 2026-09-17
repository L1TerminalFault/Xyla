#include <gtest/gtest.h>
#include "core/audio/dsp/automationCurve.hpp"
#include "core/audio/timeline/automationClip.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"
#include <vector>

using namespace xyla::audio;

TEST(AutomationCurveTest, EvaluatesLinearInterpolation) {
    AutomationCurve curve;
    curve.addPoint(0, 0.0f, CurveType::Linear);
    curve.addPoint(100, 1.0f, CurveType::Linear);

    EXPECT_FLOAT_EQ(curve.evaluateAtSample(0), 0.0f);
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(50), 0.5f);
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(100), 1.0f);
    // Clamping outside bounds
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(-10), 0.0f);
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(200), 1.0f);
}

TEST(AutomationCurveTest, EvaluatesHoldStepCurve) {
    AutomationCurve curve;
    curve.addPoint(0, 0.2f, CurveType::Hold);
    curve.addPoint(100, 0.8f, CurveType::Hold);

    // Value stays at 0.2f until exactly hitting the next point
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(0), 0.2f);
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(99), 0.2f);
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(100), 0.8f);
}

TEST(AutomationCurveTest, EvaluatesSCurveSmoothstep) {
    AutomationCurve curve;
    curve.addPoint(0, 0.0f, CurveType::SCurve);
    curve.addPoint(100, 1.0f, CurveType::SCurve);

    // Midpoint of smoothstep 3(0.5)^2 - 2(0.5)^3 = 0.5
    EXPECT_FLOAT_EQ(curve.evaluateAtSample(50), 0.5f);
    // Early inflection should be flatter than linear
    EXPECT_LT(curve.evaluateAtSample(20), 0.2f);
}

TEST(AutomationCurveTest, PopulatesBlockValuesSampleAccurately) {
    AutomationCurve curve;
    curve.addPoint(0, 0.0f, CurveType::Linear);
    curve.addPoint(4, 1.0f, CurveType::Linear);

    float block[5] = {0};
    curve.evaluateBlock(block, 5, 0);

    EXPECT_FLOAT_EQ(block[0], 0.0f);
    EXPECT_FLOAT_EQ(block[1], 0.25f);
    EXPECT_FLOAT_EQ(block[2], 0.50f);
    EXPECT_FLOAT_EQ(block[3], 0.75f);
    EXPECT_FLOAT_EQ(block[4], 1.0f);
}

TEST(AutomationClipTest, AppliesParameterToNodeWhenBlockOverlaps) {
    MixerTrackNode track("track_1", "Track 1");
    // Volume is index 0
    AutomationClip clip("clip_vol", "track_1", 0, 1000, 500);
    clip.curve().addPoint(0, 0.2f);
    clip.curve().addPoint(500, 0.8f);

    // Block before clip: should not alter parameter
    track.setParameterByIndex(0, 1.0f);
    clip.applyBlock(&track, 0, 256);
    EXPECT_FLOAT_EQ(track.getParameterByIndex(0), 1.0f);

    // Block overlapping clip start (sample 1000)
    clip.applyBlock(&track, 1000, 256);
    EXPECT_FLOAT_EQ(track.getParameterByIndex(0), 0.2f);
}
