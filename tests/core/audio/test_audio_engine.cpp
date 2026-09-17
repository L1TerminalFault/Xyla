#include <gtest/gtest.h>
#include "core/audio/engine/audioEngine.hpp"
#include "core/audio/types/audioBuffer.hpp"
#include <memory>

using namespace xyla::audio;

class AudioEngineTest : public ::testing::Test {
protected:
    AudioEngine engine;

    void SetUp() override {
        // Initialize engine in headless/offline mode (48kHz, 256 frame buffer)
        // Zero soundcard/PipeWire dependency!
        ASSERT_TRUE(engine.initializeOffline(AudioFormat::standardStereo(48000), 256));
    }

    void TearDown() override {
        engine.shutdown();
    }
};

TEST_F(AudioEngineTest, MasterNodeIsCreatedByDefault) {
    EXPECT_NE(engine.masterNode(), nullptr);
    EXPECT_EQ(engine.masterNode()->nodeId(), "master_out");
    EXPECT_NE(engine.graph().findNode("master_out"), nullptr);
}

TEST_F(AudioEngineTest, SourceNodeIdNamingResolution) {
    // "track_dialogue" -> "source_dialogue"
    EXPECT_EQ(AudioEngineNaming::deriveSourceNodeId("track_dialogue"), "source_dialogue");
    // "track_0" -> "source_0"
    EXPECT_EQ(AudioEngineNaming::deriveSourceNodeId("track_0"), "source_0");
    // "custom" -> "source_custom"
    EXPECT_EQ(AudioEngineNaming::deriveSourceNodeId("custom"), "source_custom");
}

TEST_F(AudioEngineTest, AddTrackConnectsToMasterAndCompiles) {
    auto *track = engine.addTrack("track_1", "Dialogue Track");
    ASSERT_NE(track, nullptr);
    EXPECT_EQ(track->nodeId(), "track_1");
    EXPECT_EQ(engine.tracks().size(), 1u);

    // Verify track is in the graph and connected to master_out
    EXPECT_NE(engine.graph().findNode("track_1"), nullptr);

    // Adding duplicate ID returns existing track without creating extra strips
    auto *trackDup = engine.addTrack("track_1", "Duplicate");
    EXPECT_EQ(track, trackDup);
    EXPECT_EQ(engine.tracks().size(), 1u);
}

TEST_F(AudioEngineTest, RemoveTrackCleansUpTrackAndAssociatedSourceNode) {
    engine.addTrack("track_music", "Music");
    EXPECT_EQ(engine.tracks().size(), 1u);

    // Add a corresponding source node for this track
    engine.graph().addNode<MixerTrackNode>("source_music", "Source Music");
    EXPECT_NE(engine.graph().findNode("source_music"), nullptr);

    // Remove track: both track_music and source_music should be purged
    bool removed = engine.removeTrack("track_music");
    EXPECT_TRUE(removed);
    EXPECT_EQ(engine.tracks().size(), 0u);
    EXPECT_EQ(engine.graph().findNode("track_music"), nullptr);
    EXPECT_EQ(engine.graph().findNode("source_music"), nullptr);
}

TEST_F(AudioEngineTest, RenderAudioProducesSilenceWhenStopped) {
    AudioBuffer buffer(2, 256);
    
    // Pre-fill channels with non-zero values using channelData()
    for (size_t c = 0; c < buffer.channelCount(); ++c) {
        float *data = buffer.channelData(c);
        std::fill_n(data, 256, 1.0f);
    }

    AudioClockInfo clock;
    clock.isPlaying = false;
    clock.bufferSizeFrames = 256;
    clock.timelineSamplePosition = 0;

    engine.renderAudio(buffer, clock);

    // Output must be cleared to complete silence when stopped and not scrubbing
    for (size_t c = 0; c < buffer.channelCount(); ++c) {
        const float *data = buffer.channelData(c);
        for (size_t f = 0; f < 256; ++f) {
            EXPECT_FLOAT_EQ(data[f], 0.0f);
        }
    }
}
