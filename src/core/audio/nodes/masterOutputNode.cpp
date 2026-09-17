#include "masterOutputNode.hpp"
#include "core/audio/dsp/masterLimiterDsp.hpp"

namespace xyla::audio {

MasterOutputNode::MasterOutputNode(std::string nodeId)
    : AudioNode(std::move(nodeId), "Master Output") {
  registerPin(AudioPinDescriptor::makeAudioInput("master_in", "In"));
  registerPin(AudioPinDescriptor::makeAudioOutput("hardware_out", "Out"));
  registerPin(AudioPinDescriptor::makeControlInput("master_volume", "Volume",
                                                   0.0f, 1.0f, 0.8f));

  m_masterVolIndex = resolveParameterIndex("master_volume");
  m_lastGain = 0.8f;
}

void MasterOutputNode::process(const AudioBuffer *const *inputs,
                               size_t inputCount, AudioBuffer **outputs,
                               size_t outputCount,
                               const ProcessContext &ctx) noexcept {
  if (outputCount == 0 || !outputs[0])
    return;
  AudioBuffer *out = outputs[0];
  out->clear();

  if (inputCount == 0 || !inputs[0]) {
    m_peakL.store(0.0f, std::memory_order_relaxed);
    m_peakR.store(0.0f, std::memory_order_relaxed);
    return;
  }

  if (AudioMasterClock::instance().consumeJumpFlag()) {
    m_fadeFramesRemaining = 144; // 3ms @ 48kHz
  }

  const AudioBuffer *in = inputs[0];
  const size_t frames = ctx.frameCount;
  const float targetGain =
      (m_masterVolIndex >= 0)
          ? getParameterByIndex(static_cast<size_t>(m_masterVolIndex))
          : 0.8f;

  size_t channels = std::min(in->channelCount(), out->channelCount());
  const float *inChannels[2] = {in->channelData(0), channels > 1
                                                        ? in->channelData(1)
                                                        : in->channelData(0)};
  float *outChannels[2] = {out->channelData(0), channels > 1
                                                    ? out->channelData(1)
                                                    : out->channelData(0)};

  auto result =
      dsp::processMasterBlock(inChannels, outChannels, channels, frames,
                              m_lastGain, targetGain, m_fadeFramesRemaining);

  m_lastGain = result.finalGain;
  m_fadeFramesRemaining = result.remainingFadeFrames;
  m_peakL.store(result.peakL, std::memory_order_relaxed);
  m_peakR.store(result.peakR, std::memory_order_relaxed);
  if (result.clipped) {
    m_clipped.store(true, std::memory_order_relaxed);
  }
}

} // namespace xyla::audio
