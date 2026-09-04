#include "audioDecoder.hpp"
#include <iostream>

namespace xyla::audio {

AudioDecoder::~AudioDecoder() { cleanup(); }

void AudioDecoder::cleanup() {
  if (m_swrCtx) {
    swr_free(&m_swrCtx);
    m_swrCtx = nullptr;
  }
  if (m_codecCtx) {
    avcodec_free_context(&m_codecCtx);
    m_codecCtx = nullptr;
  }
  if (m_formatCtx) {
    avformat_close_input(&m_formatCtx);
    m_formatCtx = nullptr;
  }
  m_audioStreamIndex = -1;
}

std::shared_ptr<AudioClipBuffer>
AudioDecoder::decodeEntireFile(const std::string &filePath,
                               uint32_t targetSampleRate,
                               uint32_t targetChannels) {
  cleanup();

  if (filePath.empty()) {
    return nullptr;
  }

  // Thread-isolated demuxer open
  if (avformat_open_input(&m_formatCtx, filePath.c_str(), nullptr, nullptr) <
      0) {
    return nullptr;
  }

  if (avformat_find_stream_info(m_formatCtx, nullptr) < 0) {
    cleanup();
    return nullptr;
  }

  // Find the first audio stream strictly
  const AVCodec *codec = nullptr;
  m_audioStreamIndex = -1;
  for (unsigned int i = 0; i < m_formatCtx->nb_streams; ++i) {
    if (m_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      codec = avcodec_find_decoder(m_formatCtx->streams[i]->codecpar->codec_id);
      if (codec) {
        m_audioStreamIndex = static_cast<int>(i);
        break;
      }
    }
  }

  if (m_audioStreamIndex == -1 || !codec) {
    cleanup();
    return nullptr;
  }

  m_codecCtx = avcodec_alloc_context3(codec);
  if (!m_codecCtx) {
    cleanup();
    return nullptr;
  }

  if (avcodec_parameters_to_context(
          m_codecCtx, m_formatCtx->streams[m_audioStreamIndex]->codecpar) < 0) {
    cleanup();
    return nullptr;
  }

  if (avcodec_open2(m_codecCtx, codec, nullptr) < 0) {
    cleanup();
    return nullptr;
  }

  // Setup target channel layout (Stereo default)
  AVChannelLayout targetLayout;
  av_channel_layout_default(&targetLayout, targetChannels);

  // Setup Resampler
  int swrRet = swr_alloc_set_opts2(&m_swrCtx, &targetLayout, AV_SAMPLE_FMT_FLTP,
                                   targetSampleRate, &m_codecCtx->ch_layout,
                                   m_codecCtx->sample_fmt,
                                   m_codecCtx->sample_rate, 0, nullptr);

  if (swrRet < 0 || !m_swrCtx || swr_init(m_swrCtx) < 0) {
    cleanup();
    return nullptr;
  }

  auto clipBuffer =
      std::make_shared<AudioClipBuffer>(targetChannels, targetSampleRate);

  AVPacket *packet = av_packet_alloc();
  AVFrame *frame = av_frame_alloc();

  const int maxDstSamples = 8192;
  std::vector<std::vector<float>> scratchPlanes(
      targetChannels, std::vector<float>(maxDstSamples));
  std::vector<float *> dstPointers(targetChannels);
  for (size_t c = 0; c < targetChannels; ++c) {
    dstPointers[c] = scratchPlanes[c].data();
  }

  while (av_read_frame(m_formatCtx, packet) >= 0) {
    // CRITICAL: ONLY pass audio stream packets to avcodec_send_packet!
    if (packet->stream_index == m_audioStreamIndex) {
      if (avcodec_send_packet(m_codecCtx, packet) >= 0) {
        while (avcodec_receive_frame(m_codecCtx, frame) >= 0) {
          int convertedSamples = swr_convert(
              m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
              maxDstSamples, const_cast<const uint8_t **>(frame->data),
              frame->nb_samples);

          if (convertedSamples > 0) {
            clipBuffer->appendFrames(dstPointers.data(), convertedSamples);
          }
        }
      }
    }
    av_packet_unref(packet);
  }

  // Flush remaining delayed frames from codec
  if (avcodec_send_packet(m_codecCtx, nullptr) >= 0) {
    while (avcodec_receive_frame(m_codecCtx, frame) >= 0) {
      int convertedSamples = swr_convert(
          m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
          maxDstSamples, const_cast<const uint8_t **>(frame->data),
          frame->nb_samples);

      if (convertedSamples > 0) {
        clipBuffer->appendFrames(dstPointers.data(), convertedSamples);
      }
    }
  }

  // Flush resampler buffers
  int flushSamples = 0;
  do {
    flushSamples =
        swr_convert(m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
                    maxDstSamples, nullptr, 0);
    if (flushSamples > 0) {
      clipBuffer->appendFrames(dstPointers.data(), flushSamples);
    }
  } while (flushSamples > 0);

  av_frame_free(&frame);
  av_packet_free(&packet);
  cleanup();

  return clipBuffer;
}

} // namespace xyla::audio
