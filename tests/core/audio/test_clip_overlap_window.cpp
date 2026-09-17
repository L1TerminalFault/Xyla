/**
 * @file test_clip_overlap_window.cpp
 * @brief Comprehensive GoogleTest suite for ClipOverlapWindow geometry & window arithmetic.
 *
 * Tests all boundary conditions, containment scenarios, trimming offsets, and fast-rejections.
 */

#include <gtest/gtest.h>
#include "core/audio/dsp/clipAudioProcessor.hpp"

using namespace xyla::audio;

class ClipOverlapWindowTest : public ::testing::Test {
protected:
    void SetUp() override {}
    void TearDown() override {}
};

// ============================================================================
// 1. Rejection & Disjoint Cases
// ============================================================================

TEST_F(ClipOverlapWindowTest, RejectsBlockCompletelyBeforeClip) {
    // Render block [0, 512) is completely before clip starting at 1000 with duration 2000
    const auto win = ClipOverlapWindow::compute(0, 512, 1000, 2000, 0);
    EXPECT_FALSE(win.hasOverlap);
    EXPECT_EQ(win.overlapFrames, 0u);
}

TEST_F(ClipOverlapWindowTest, RejectsBlockCompletelyAfterClip) {
    // Clip [1000, 1500), render block [1500, 2012)
    const auto win = ClipOverlapWindow::compute(1500, 2012, 1000, 500, 0);
    EXPECT_FALSE(win.hasOverlap);
    EXPECT_EQ(win.overlapFrames, 0u);
}

TEST_F(ClipOverlapWindowTest, AbuttingBoundariesProduceNoOverlap) {
    // Block ends exactly where clip begins [0, 1000) vs clip [1000, 2000)
    const auto winBefore = ClipOverlapWindow::compute(0, 1000, 1000, 1000, 0);
    EXPECT_FALSE(winBefore.hasOverlap);

    // Block begins exactly where clip ends [2000, 3000) vs clip [1000, 2000)
    const auto winAfter = ClipOverlapWindow::compute(2000, 3000, 1000, 1000, 0);
    EXPECT_FALSE(winAfter.hasOverlap);
}

// ============================================================================
// 2. Overlap Intersections
// ============================================================================

TEST_F(ClipOverlapWindowTest, BlockStartsBeforeAndOverlapsClipStart) {
    // Block [800, 1312), Clip [1000, 3000)
    // Overlap: [1000, 1312) -> 312 frames.
    // Destination offset inside buffer: 1000 - 800 = 200.
    // Source offset inside asset: 0 + sourceIn (150) = 150.
    const auto win = ClipOverlapWindow::compute(800, 1312, 1000, 2000, 150);
    EXPECT_TRUE(win.hasOverlap);
    EXPECT_EQ(win.overlapStart, 1000);
    EXPECT_EQ(win.overlapEnd, 1312);
    EXPECT_EQ(win.overlapFrames, 312u);
    EXPECT_EQ(win.destOffset, 200u);
    EXPECT_EQ(win.bufferOffset, 150);
}

TEST_F(ClipOverlapWindowTest, BlockContainedEntirelyInsideClip) {
    // Block [2000, 2512), Clip [1000, 5000), sourceIn = 480
    // destOffset should be 0 because audio starts at frame 0 of the callback block
    // bufferOffset should be (2000 - 1000) + 480 = 1480
    const auto win = ClipOverlapWindow::compute(2000, 2512, 1000, 4000, 480);
    EXPECT_TRUE(win.hasOverlap);
    EXPECT_EQ(win.overlapStart, 2000);
    EXPECT_EQ(win.overlapEnd, 2512);
    EXPECT_EQ(win.overlapFrames, 512u);
    EXPECT_EQ(win.destOffset, 0u);
    EXPECT_EQ(win.bufferOffset, 1480);
}

TEST_F(ClipOverlapWindowTest, ShortClipContainedEntirelyInsideBlock) {
    // Block [0, 1024), Clip [200, 450) with duration 250, sourceIn = 50
    const auto win = ClipOverlapWindow::compute(0, 1024, 200, 250, 50);
    EXPECT_TRUE(win.hasOverlap);
    EXPECT_EQ(win.overlapStart, 200);
    EXPECT_EQ(win.overlapEnd, 450);
    EXPECT_EQ(win.overlapFrames, 250u);
    EXPECT_EQ(win.destOffset, 200u);
    EXPECT_EQ(win.bufferOffset, 50);
}

TEST_F(ClipOverlapWindowTest, BlockOverlapsClipEnd) {
    // Clip [1000, 2000), Block [1800, 2312)
    // Overlap: [1800, 2000) -> 200 frames.
    // destOffset: 0 (starts at sample 0 of block)
    // bufferOffset: (1800 - 1000) + 0 = 800
    const auto win = ClipOverlapWindow::compute(1800, 2312, 1000, 1000, 0);
    EXPECT_TRUE(win.hasOverlap);
    EXPECT_EQ(win.overlapStart, 1800);
    EXPECT_EQ(win.overlapEnd, 2000);
    EXPECT_EQ(win.overlapFrames, 200u);
    EXPECT_EQ(win.destOffset, 0u);
    EXPECT_EQ(win.bufferOffset, 800);
}

TEST_F(ClipOverlapWindowTest, NegativeTimelineStartHandledSafely) {
    // In video editors, user can drag audio clip partially into negative timeline space
    // Clip [-500, 1500) duration 2000, Block [0, 512)
    const auto win = ClipOverlapWindow::compute(0, 512, -500, 2000, 0);
    EXPECT_TRUE(win.hasOverlap);
    EXPECT_EQ(win.overlapStart, 0);
    EXPECT_EQ(win.overlapEnd, 512);
    EXPECT_EQ(win.overlapFrames, 512u);
    EXPECT_EQ(win.destOffset, 0u);
    EXPECT_EQ(win.bufferOffset, 500); // (0 - (-500)) = 500
}

