#include <gtest/gtest.h>
#include "core/audio/decoder/audioDecoder.hpp"

using namespace xyla::audio;

TEST(AudioDecoderTest, GracefullyHandlesEmptyFilePath) {
    AudioDecoder decoder;
    auto buffer = decoder.decodeEntireFile("");
    EXPECT_EQ(buffer, nullptr);

    auto info = AudioDecoder::probeFile("");
    EXPECT_FALSE(info.isValid);
}

TEST(AudioDecoderTest, GracefullyHandlesNonExistentFile) {
    AudioDecoder decoder;
    auto buffer = decoder.decodeEntireFile("/tmp/path_that_does_not_exist_98234712.wav");
    EXPECT_EQ(buffer, nullptr);

    auto info = AudioDecoder::probeFile("/tmp/path_that_does_not_exist_98234712.wav");
    EXPECT_FALSE(info.isValid);
    EXPECT_EQ(info.sampleRate, 0u);
    EXPECT_EQ(info.channels, 0u);
}

TEST(AudioDecoderTest, ReentrantCleanupSafety) {
    AudioDecoder decoder;
    // Calling cleanup multiple times on an uninitialized decoder must be safe
    EXPECT_NO_THROW(decoder.cleanup());
    EXPECT_NO_THROW(decoder.cleanup());
}

TEST(AudioDecoderTest, MoveSemanticsTransferHandlesCleanly) {
    AudioDecoder d1;
    AudioDecoder d2 = std::move(d1);
    EXPECT_NO_THROW(d2.cleanup());
}
