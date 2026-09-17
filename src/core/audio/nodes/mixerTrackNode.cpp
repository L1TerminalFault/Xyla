#include "mixerTrackNode.hpp"
#include "dsp/mixerTrackDsp.hpp"

namespace xyla::audio {

MixerTrackNode::MixerTrackNode(std::string nodeId, std::string name)
    : AudioNode(std::move(nodeId), std::move(name)) {
  // 1 Audio In, 1 Audio Out
  registerPin(AudioPinDescriptor::makeAudioInput("audio_in", "In"));
  registerPin(AudioPinDescriptor::makeAudioOutput("audio_out", "Out"));

  // Automation / Control pins
  registerPin(AudioPinDescriptor::makeControlInput("volume", "Volume", 0.0f,
                                                   2.0f, 1.0f));
  registerPin(
      AudioPinDescriptor::makeControlInput("pan", "Pan", -1.0f, 1.0f, 0.0f));
  registerPin(
      AudioPinDescriptor::makeControlInput("mute", "Mute", 0.0f, 1.0f, 0.0f));
  registerPin(
      AudioPinDescriptor::makeControlInput("solo", "Solo", 0.0f, 1.0f, 0.0f));
  registerPin(AudioPinDescriptor::makeControlInput("width", "Stereo Width",
                                                   0.0f, 2.0f, 1.0f));
  registerPin(AudioPinDescriptor::makeControlInput(
      "phase_invert", "Phase Invert", 0.0f, 1.0f, 0.0f));
  registerPin(AudioPinDescriptor::makeControlInput(
      "channel_swap", "Channel Swap", 0.0f, 1.0f, 0.0f));
}

void MixerTrackNode::process(const AudioBuffer *const *inputs,
                             size_t inputCount, AudioBuffer **outputs,
                             size_t outputCount,
                             const ProcessContext &ctx) noexcept {
  if (outputCount == 0 || !outputs[0])
    return;

  AudioBuffer *out = outputs[0];
  out->clear();

  if (inputCount == 0 || !inputs[0] || isBypassed()) {
    if (inputCount > 0 && inputs[0] && isBypassed()) {
      out->copyFrom(*inputs[0]);
    }
    m_peakL.store(0.0f, std::memory_order_relaxed);
    m_peakR.store(0.0f, std::memory_order_relaxed);
    m_rmsL.store(0.0f, std::memory_order_relaxed);
    m_rmsR.store(0.0f, std::memory_order_relaxed);
    return;
  }

  const AudioBuffer *in = inputs[0];
  const size_t frames = ctx.frameCount;
  if (frames == 0)
    return;

  dsp::MixerTrackParams params;
  params.isMuted = getParameterByIndex(2) >= 0.5f;
  params.volume = params.isMuted ? 0.0f : getParameterByIndex(0);
  params.pan = getParameterByIndex(1);
  params.width = getParameterByIndex(4);
  params.phaseInvert = getParameterByIndex(5) >= 0.5f;
  params.swapChannels = getParameterByIndex(6) >= 0.5f;

  const float *inPlanes[2] = {in->channelData(0), (in->channelCount() > 1)
                                                      ? in->channelData(1)
                                                      : in->channelData(0)};

  float *outPlanes[2] = {out->channelData(0), (out->channelCount() > 1)
                                                  ? out->channelData(1)
                                                  : out->channelData(0)};

  auto meter = dsp::processMixerTrackBlock(
      inPlanes, outPlanes, in->channelCount(), out->channelCount(), frames,
      params, m_lastGainL, m_lastGainR);

  m_lastGainL = meter.finalGainL;
  m_lastGainR = meter.finalGainR;

  m_peakL.store(meter.peakL, std::memory_order_relaxed);
  m_peakR.store(meter.peakR, std::memory_order_relaxed);
  m_rmsL.store(meter.rmsL, std::memory_order_relaxed);
  m_rmsR.store(meter.rmsR, std::memory_order_relaxed);
}

} // namespace xyla::audio
