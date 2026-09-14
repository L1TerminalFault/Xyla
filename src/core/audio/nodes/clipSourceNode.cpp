#include "clipSourceNode.hpp"
#include <cstring>

namespace xyla::audio {

ClipSourceNode::ClipSourceNode(std::string nodeId, std::string name)
    : AudioNode(std::move(nodeId), std::move(name)) {
  registerPin(AudioPinDescriptor::makeAudioOutput("audio_out", "Out"));
}

void ClipSourceNode::process(const AudioBuffer *const *inputs,
                             size_t inputCount, AudioBuffer **outputs,
                             size_t outputCount,
                             const ProcessContext &ctx) noexcept {
  (void)inputs;
  (void)inputCount;

  if (outputCount == 0 || !outputs[0])
    return;

  AudioBuffer *out = outputs[0];
  out->clear();

  if (isBypassed() || !m_pcmReader)
    return;

  int64_t timelinePos = ctx.clock.timelineSamplePosition;
  size_t framesToRead = ctx.frameCount;

  m_pcmReader(timelinePos, framesToRead, out->allChannels(),
              out->channelCount());
}

} // namespace xyla::audio
