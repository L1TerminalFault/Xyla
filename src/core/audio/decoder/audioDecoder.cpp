// #include "audioDecoder.hpp"
// #include <iostream>
//
// namespace xyla::audio {
//
// AudioDecoder::~AudioDecoder() { cleanup(); }
//
// void AudioDecoder::cleanup() {
//   if (m_swrCtx) {
//     swr_free(&m_swrCtx);
//     m_swrCtx = nullptr;
//   }
//   if (m_codecCtx) {
//     avcodec_free_context(&m_codecCtx);
//     m_codecCtx = nullptr;
//   }
//   if (m_formatCtx) {
//     avformat_close_input(&m_formatCtx);
//     m_formatCtx = nullptr;
//   }
//   m_audioStreamIndex = -1;
// }
//
// std::shared_ptr<AudioClipBuffer>
// AudioDecoder::decodeEntireFile(const std::string &filePath,
//                                uint32_t targetSampleRate,
//                                uint32_t targetChannels) {
//   cleanup();
//
//   if (filePath.empty()) {
//     return nullptr;
//   }
//
//   // Thread-isolated demuxer open
//   if (avformat_open_input(&m_formatCtx, filePath.c_str(), nullptr, nullptr) <
//       0) {
//     return nullptr;
//   }
//
//   if (avformat_find_stream_info(m_formatCtx, nullptr) < 0) {
//     cleanup();
//     return nullptr;
//   }
//
//   // Find the first audio stream strictly
//   const AVCodec *codec = nullptr;
//   m_audioStreamIndex = -1;
//   for (unsigned int i = 0; i < m_formatCtx->nb_streams; ++i) {
//     if (m_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
//       codec = avcodec_find_decoder(m_formatCtx->streams[i]->codecpar->codec_id);
//       if (codec) {
//         m_audioStreamIndex = static_cast<int>(i);
//         break;
//       }
//     }
//   }
//
//   if (m_audioStreamIndex == -1 || !codec) {
//     cleanup();
//     return nullptr;
//   }
//
//   m_codecCtx = avcodec_alloc_context3(codec);
//   if (!m_codecCtx) {
//     cleanup();
//     return nullptr;
//   }
//
//   if (avcodec_parameters_to_context(
//           m_codecCtx, m_formatCtx->streams[m_audioStreamIndex]->codecpar) < 0) {
//     cleanup();
//     return nullptr;
//   }
//
//   if (avcodec_open2(m_codecCtx, codec, nullptr) < 0) {
//     cleanup();
//     return nullptr;
//   }
//
//   // Setup target channel layout (Stereo default)
//   AVChannelLayout targetLayout;
//   av_channel_layout_default(&targetLayout, targetChannels);
//
//   // Setup Resampler
//   int swrRet = swr_alloc_set_opts2(&m_swrCtx, &targetLayout, AV_SAMPLE_FMT_FLTP,
//                                    targetSampleRate, &m_codecCtx->ch_layout,
//                                    m_codecCtx->sample_fmt,
//                                    m_codecCtx->sample_rate, 0, nullptr);
//
//   if (swrRet < 0 || !m_swrCtx || swr_init(m_swrCtx) < 0) {
//     cleanup();
//     return nullptr;
//   }
//
//   auto clipBuffer =
//       std::make_shared<AudioClipBuffer>(targetChannels, targetSampleRate);
//
//   AVPacket *packet = av_packet_alloc();
//   AVFrame *frame = av_frame_alloc();
//
//   const int maxDstSamples = 8192;
//   std::vector<std::vector<float>> scratchPlanes(
//       targetChannels, std::vector<float>(maxDstSamples));
//   std::vector<float *> dstPointers(targetChannels);
//   for (size_t c = 0; c < targetChannels; ++c) {
//     dstPointers[c] = scratchPlanes[c].data();
//   }
//
//   while (av_read_frame(m_formatCtx, packet) >= 0) {
//     // CRITICAL: ONLY pass audio stream packets to avcodec_send_packet!
//     if (packet->stream_index == m_audioStreamIndex) {
//       if (avcodec_send_packet(m_codecCtx, packet) >= 0) {
//         while (avcodec_receive_frame(m_codecCtx, frame) >= 0) {
//           int convertedSamples = swr_convert(
//               m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
//               maxDstSamples, const_cast<const uint8_t **>(frame->data),
//               frame->nb_samples);
//
//           if (convertedSamples > 0) {
//             clipBuffer->appendFrames(dstPointers.data(), convertedSamples);
//           }
//         }
//       }
//     }
//     av_packet_unref(packet);
//   }
//
//   // Flush remaining delayed frames from codec
//   if (avcodec_send_packet(m_codecCtx, nullptr) >= 0) {
//     while (avcodec_receive_frame(m_codecCtx, frame) >= 0) {
//       int convertedSamples = swr_convert(
//           m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
//           maxDstSamples, const_cast<const uint8_t **>(frame->data),
//           frame->nb_samples);
//
//       if (convertedSamples > 0) {
//         clipBuffer->appendFrames(dstPointers.data(), convertedSamples);
//       }
//     }
//   }
//
//   // Flush resampler buffers
//   int flushSamples = 0;
//   do {
//     flushSamples =
//         swr_convert(m_swrCtx, reinterpret_cast<uint8_t **>(dstPointers.data()),
//                     maxDstSamples, nullptr, 0);
//     if (flushSamples > 0) {
//       clipBuffer->appendFrames(dstPointers.data(), flushSamples);
//     }
//   } while (flushSamples > 0);
//
//   av_frame_free(&frame);
//   av_packet_free(&packet);
//   cleanup();
//
//   return clipBuffer;
// }
//
// } // namespace xyla::audio
//
//
//
//
#include "audioDecoder.hpp"
#include <algorithm>
#include <vector>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
}

namespace xyla::audio {

namespace {

// RAII Deleters for transient packet/frame objects
struct AVPacketDeleter {
    void operator()(AVPacket *pkt) const noexcept {
        if (pkt) av_packet_free(&pkt);
    }
};

struct AVFrameDeleter {
    void operator()(AVFrame *frame) const noexcept {
        if (frame) av_frame_free(&frame);
    }
};

using ScopedAVPacket = std::unique_ptr<AVPacket, AVPacketDeleter>;
using ScopedAVFrame = std::unique_ptr<AVFrame, AVFrameDeleter>;

// Internal helper to convert and push resampled planar audio frames
inline void convertAndAppend(
    SwrContext *swrCtx,
    AudioClipBuffer &clipBuffer,
    float *const *dstPointers,
    int maxDstSamples,
    const uint8_t *const *srcData,
    int srcSamples) 
{
    int converted = swr_convert(
        swrCtx,
        reinterpret_cast<uint8_t **>(const_cast<float **>(dstPointers)),
        maxDstSamples,
        const_cast<const uint8_t**>(srcData),
        srcSamples
    );

    if (converted > 0) {
        clipBuffer.appendFrames(dstPointers, static_cast<size_t>(converted));
    }
}

} // anonymous namespace

AudioDecoder::AudioDecoder() = default;

AudioDecoder::~AudioDecoder() {
    cleanup();
}

AudioDecoder::AudioDecoder(AudioDecoder &&other) noexcept
    : m_formatCtx(other.m_formatCtx)
    , m_codecCtx(other.m_codecCtx)
    , m_swrCtx(other.m_swrCtx)
    , m_audioStreamIndex(other.m_audioStreamIndex)
{
    other.m_formatCtx = nullptr;
    other.m_codecCtx = nullptr;
    other.m_swrCtx = nullptr;
    other.m_audioStreamIndex = -1;
}

AudioDecoder &AudioDecoder::operator=(AudioDecoder &&other) noexcept {
    if (this != &other) {
        cleanup();
        m_formatCtx = other.m_formatCtx;
        m_codecCtx = other.m_codecCtx;
        m_swrCtx = other.m_swrCtx;
        m_audioStreamIndex = other.m_audioStreamIndex;

        other.m_formatCtx = nullptr;
        other.m_codecCtx = nullptr;
        other.m_swrCtx = nullptr;
        other.m_audioStreamIndex = -1;
    }
    return *this;
}

void AudioDecoder::cleanup() noexcept {
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

AudioFileInfo AudioDecoder::probeFile(const std::string &filePath) {
    AudioFileInfo info;
    if (filePath.empty()) return info;

    AVFormatContext *fmtCtx = nullptr;
    if (avformat_open_input(&fmtCtx, filePath.c_str(), nullptr, nullptr) < 0) {
        return info;
    }

    if (avformat_find_stream_info(fmtCtx, nullptr) >= 0) {
        for (unsigned int i = 0; i < fmtCtx->nb_streams; ++i) {
            const auto *par = fmtCtx->streams[i]->codecpar;
            if (par->codec_type == AVMEDIA_TYPE_AUDIO) {
                info.channels = static_cast<uint32_t>(par->ch_layout.nb_channels);
                info.sampleRate = static_cast<uint32_t>(par->sample_rate);
                info.isValid = true;

                if (fmtCtx->streams[i]->duration > 0 && fmtCtx->streams[i]->time_base.den > 0) {
                    info.durationSeconds = static_cast<double>(fmtCtx->streams[i]->duration) *
                                           av_q2d(fmtCtx->streams[i]->time_base);
                    info.durationFrames = static_cast<int64_t>(info.durationSeconds * info.sampleRate);
                } else if (fmtCtx->duration > 0) {
                    info.durationSeconds = static_cast<double>(fmtCtx->duration) / AV_TIME_BASE;
                    info.durationFrames = static_cast<int64_t>(info.durationSeconds * info.sampleRate);
                }

                const AVCodec *codec = avcodec_find_decoder(par->codec_id);
                if (codec && codec->name) {
                    info.codecName = codec->name;
                }
                break;
            }
        }
    }

    avformat_close_input(&fmtCtx);
    return info;
}

std::shared_ptr<AudioClipBuffer> AudioDecoder::decodeEntireFile(
    const std::string &filePath,
    uint32_t targetSampleRate,
    uint32_t targetChannels) 
{
    cleanup();

    if (filePath.empty() || targetChannels == 0 || targetSampleRate == 0) {
        return nullptr;
    }

    // 1. Thread-isolated demuxer open
    if (avformat_open_input(&m_formatCtx, filePath.c_str(), nullptr, nullptr) < 0) {
        return nullptr;
    }

    if (avformat_find_stream_info(m_formatCtx, nullptr) < 0) {
        cleanup();
        return nullptr;
    }

    // 2. Find the first audio stream
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

    // 3. Allocate and initialize decoder context
    m_codecCtx = avcodec_alloc_context3(codec);
    if (!m_codecCtx) {
        cleanup();
        return nullptr;
    }

    if (avcodec_parameters_to_context(m_codecCtx, m_formatCtx->streams[m_audioStreamIndex]->codecpar) < 0) {
        cleanup();
        return nullptr;
    }

    if (avcodec_open2(m_codecCtx, codec, nullptr) < 0) {
        cleanup();
        return nullptr;
    }

    // 4. Set up target channel layout (e.g. standard stereo)
    AVChannelLayout targetLayout;
    av_channel_layout_default(&targetLayout, static_cast<int>(targetChannels));

    // 5. Initialize Resampler to planar 32-bit float (AV_SAMPLE_FMT_FLTP)
    int swrRet = swr_alloc_set_opts2(
        &m_swrCtx,
        &targetLayout,
        AV_SAMPLE_FMT_FLTP,
        static_cast<int>(targetSampleRate),
        &m_codecCtx->ch_layout,
        m_codecCtx->sample_fmt,
        m_codecCtx->sample_rate,
        0,
        nullptr
    );

    if (swrRet < 0 || !m_swrCtx || swr_init(m_swrCtx) < 0) {
        cleanup();
        return nullptr;
    }

    auto clipBuffer = std::make_shared<AudioClipBuffer>(targetChannels, targetSampleRate);

    ScopedAVPacket packet(av_packet_alloc());
    ScopedAVFrame frame(av_frame_alloc());
    if (!packet || !frame) {
        cleanup();
        return nullptr;
    }

    constexpr int maxDstSamples = 8192;
    std::vector<std::vector<float>> scratchPlanes(targetChannels, std::vector<float>(maxDstSamples));
    std::vector<float *> dstPointers(targetChannels);
    for (size_t c = 0; c < targetChannels; ++c) {
        dstPointers[c] = scratchPlanes[c].data();
    }

    // 6. Packet Read & Decode Loop
    while (av_read_frame(m_formatCtx, packet.get()) >= 0) {
        if (packet->stream_index == m_audioStreamIndex) {
            if (avcodec_send_packet(m_codecCtx, packet.get()) >= 0) {
                while (avcodec_receive_frame(m_codecCtx, frame.get()) >= 0) {
                    convertAndAppend(
                        m_swrCtx,
                        *clipBuffer,
                        dstPointers.data(),
                        maxDstSamples,
                        const_cast<const uint8_t **>(frame->data),
                        frame->nb_samples
                    );
                }
            }
        }
        av_packet_unref(packet.get());
    }

    // 7. Flush delayed frames from codec
    if (avcodec_send_packet(m_codecCtx, nullptr) >= 0) {
        while (avcodec_receive_frame(m_codecCtx, frame.get()) >= 0) {
            convertAndAppend(
                m_swrCtx,
                *clipBuffer,
                dstPointers.data(),
                maxDstSamples,
                const_cast<const uint8_t **>(frame->data),
                frame->nb_samples
            );
        }
    }

    // 8. Drain residual resampler buffer
    int flushSamples = 0;
    do {
        flushSamples = swr_convert(
            m_swrCtx,
            reinterpret_cast<uint8_t **>(dstPointers.data()),
            maxDstSamples,
            nullptr,
            0
        );
        if (flushSamples > 0) {
            clipBuffer->appendFrames(dstPointers.data(), static_cast<size_t>(flushSamples));
        }
    } while (flushSamples > 0);

    cleanup();
    return clipBuffer;
}

} // namespace xyla::audio
