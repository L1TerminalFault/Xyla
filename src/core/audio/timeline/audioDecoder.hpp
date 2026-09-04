#pragma once

#include "audioClipBuffer.hpp"
#include <memory>
#include <string>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
}

namespace xyla::audio {

class AudioDecoder {
public:
  AudioDecoder() = default;
  ~AudioDecoder();

  AudioDecoder(const AudioDecoder &) = delete;
  AudioDecoder &operator=(const AudioDecoder &) = delete;

  /**
   * @brief Decode the entire audio stream of an asset into a normalized 48kHz
   * AudioClipBuffer.
   */
  std::shared_ptr<AudioClipBuffer>
  decodeEntireFile(const std::string &filePath,
                   uint32_t targetSampleRate = 48000,
                   uint32_t targetChannels = 2);

private:
  void cleanup();

  AVFormatContext *m_formatCtx{nullptr};
  AVCodecContext *m_codecCtx{nullptr};
  SwrContext *m_swrCtx{nullptr};
  int m_audioStreamIndex{-1};
};

} // namespace xyla::audio
