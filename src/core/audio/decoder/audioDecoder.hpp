#pragma once

#include "core/audio/timeline/audioClipBuffer.hpp"
#include <cstdint>
#include <memory>
#include <string>

extern "C" {
struct AVFormatContext;
struct AVCodecContext;
struct SwrContext;
struct AVPacket;
struct AVFrame;
}

namespace xyla::audio {

struct AudioFileInfo {
  uint32_t sampleRate{0};
  uint32_t channels{0};
  int64_t durationFrames{0};
  double durationSeconds{0.0};
  std::string codecName;
  bool isValid{false};
};

/**
 * @brief Thread-safe, RAII-governed audio demuxer and decoder based on
 * FFmpeg/libswresample. Converts any audio container/codec (AAC, MP3, FLAC,
 * WAV, Opus, Vorbis) into a 32-bit float planar AudioClipBuffer.
 */
class AudioDecoder {
public:
  AudioDecoder();
  ~AudioDecoder();

  AudioDecoder(const AudioDecoder &) = delete;
  AudioDecoder &operator=(const AudioDecoder &) = delete;
  AudioDecoder(AudioDecoder &&) noexcept;
  AudioDecoder &operator=(AudioDecoder &&) noexcept;

  /**
   * @brief Quickly inspects audio file metadata without decoding all audio
   * samples.
   */
  static AudioFileInfo probeFile(const std::string &filePath);

  /**
   * @brief Decodes the entire audio stream of a file into a planar 32-bit float
   * AudioClipBuffer.
   * @param filePath Absolute or relative path to media file
   * @param targetSampleRate Destination sample rate (default: 48000 Hz)
   * @param targetChannels Destination channel count (default: 2 / Stereo)
   * @return std::shared_ptr<AudioClipBuffer> on success, nullptr on
   * invalid/missing file
   */
  std::shared_ptr<AudioClipBuffer>
  decodeEntireFile(const std::string &filePath,
                   uint32_t targetSampleRate = 48000,
                   uint32_t targetChannels = 2);

  void cleanup() noexcept;

private:
  AVFormatContext *m_formatCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  SwrContext *m_swrCtx{nullptr};
  int m_audioStreamIndex{-1};
};

} // namespace xyla::audio
