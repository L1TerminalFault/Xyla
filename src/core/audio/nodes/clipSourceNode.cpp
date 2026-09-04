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
  out->clear(); // ENSURE ZERO-FILL FIRST

  if (isBypassed() || !m_pcmReader)
    return;

  int64_t timelinePos = ctx.clock.timelineSamplePosition;
  size_t framesToRead = ctx.frameCount;

  size_t framesRead = m_pcmReader(timelinePos, framesToRead, out->allChannels(),
                                  out->channelCount());

  // If the timeline reader didn't fill the entire buffer (e.g. past the end of
  // a clip or in a gap), explicitly zero out the remaining frames to prevent
  // repeating stale audio garbage!
  if (framesRead < framesToRead) {
    for (size_t c = 0; c < out->channelCount(); ++c) {
      float *chData = out->channelData(c);
      std::fill(chData + framesRead, chData + framesToRead, 0.0f);
    }
  }
}

} // namespace xyla::audio
