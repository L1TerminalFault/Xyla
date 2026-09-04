#pragma once

#include "core/audio/graph/audioNode.hpp"
#include <functional>

namespace xyla::audio {

/**
 * @brief Callback signature used by ClipSourceNode to read decoded timeline
 * PCM.
 */
using AudioPcmReader =
    std::function<size_t(int64_t timelineSample, size_t numFrames,
                         float **outputChannelBuffers, size_t channelCount)>;

class ClipSourceNode : public AudioNode {
public:
  ClipSourceNode(std::string nodeId, std::string name);
  ~ClipSourceNode() override = default;

  void setPcmReader(AudioPcmReader reader) { m_pcmReader = std::move(reader); }

  void process(const AudioBuffer *const *inputs, size_t inputCount,
               AudioBuffer **outputs, size_t outputCount,
               const ProcessContext &ctx) noexcept override;

private:
  AudioPcmReader m_pcmReader{nullptr};
};

} // namespace xyla::audio
