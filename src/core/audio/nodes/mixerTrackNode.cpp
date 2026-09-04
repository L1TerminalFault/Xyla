#include "mixerTrackNode.hpp"
#include <algorithm>
#include <cmath>

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

  // If no input or bypassed, exit cleanly
  if (inputCount == 0 || !inputs[0] || isBypassed()) {
    if (inputCount > 0 && inputs[0] && isBypassed()) {
      out->copyFrom(*inputs[0]);
    }
    m_peakL.store(0.0f, std::memory_order_relaxed);
    m_peakR.store(0.0f, std::memory_order_relaxed);
    return;
  }

  const AudioBuffer *in = inputs[0];
  size_t frames = ctx.frameCount;
  if (frames == 0)
    return;

  // Retrieve Control Parameters by Index (Zero String Lookups)
  // Pin registration order: volume(0), pan(1), mute(2), solo(3), width(4),
  // phase_invert(5), channel_swap(6)
  const bool isMuted = getParameterByIndex(2) >= 0.5f;
  const float vol = isMuted ? 0.0f : getParameterByIndex(0);
  const float pan = std::clamp(getParameterByIndex(1), -1.0f, 1.0f);
  const float width = std::clamp(getParameterByIndex(4), 0.0f, 2.0f);
  const bool phaseInvert = getParameterByIndex(5) >= 0.5f;
  const bool swapChannels = getParameterByIndex(6) >= 0.5f;

  const float phaseMod = phaseInvert ? -1.0f : 1.0f;

  // Linear Pan Law
  float targetPanL = (pan <= 0.0f) ? 1.0f : (1.0f - pan);
  float targetPanR = (pan >= 0.0f) ? 1.0f : (1.0f + pan);

  float targetGainL = targetPanL * vol * phaseMod;
  float targetGainR = targetPanR * vol * phaseMod;

  // Sample-accurate micro-ramp steps to prevent clicks/pops
  float stepGainL = (targetGainL - m_lastGainL) / static_cast<float>(frames);
  float stepGainR = (targetGainR - m_lastGainR) / static_cast<float>(frames);

  float currentGainL = m_lastGainL;
  float currentGainR = m_lastGainR;

  // Source Planar Pointers
  const float *inL = in->channelData(0);
  const float *inR = (in->channelCount() > 1) ? in->channelData(1) : inL;

  // Destination Planar Pointers
  float *outL = out->channelData(0);
  float *outR = (out->channelCount() > 1) ? out->channelData(1) : outL;

  float maxPeakL = 0.0f;
  float maxPeakR = 0.0f;
  float sumSqL = 0.0f;
  float sumSqR = 0.0f;

  // Real-time Planar DSP Loop
  for (size_t i = 0; i < frames; ++i) {
    float l = inL[i];
    float r = inR[i];

    // 1. Channel Swap
    if (swapChannels) {
      std::swap(l, r);
    }

    // 2. Mid/Side Stereo Width
    if (width != 1.0f) {
      float mid = (l + r) * 0.5f;
      float side = (l - r) * 0.5f * width;
      l = mid + side;
      r = mid - side;
    }

    // 3. Apply Smooth Ramped Gain & Pan
    float finalL = l * currentGainL;
    float finalR = r * currentGainR;

    currentGainL += stepGainL;
    currentGainR += stepGainR;

    outL[i] = finalL;
    if (out->channelCount() > 1) {
      outR[i] = finalR;
    }

    // Metering Accumulation
    float absL = std::abs(finalL);
    float absR = std::abs(finalR);
    if (absL > maxPeakL)
      maxPeakL = absL;
    if (absR > maxPeakR)
      maxPeakR = absR;
    sumSqL += finalL * finalL;
    sumSqR += finalR * finalR;
  }

  m_lastGainL = targetGainL;
  m_lastGainR = targetGainR;

  // Store metering atomics
  m_peakL.store(maxPeakL, std::memory_order_relaxed);
  m_peakR.store(maxPeakR, std::memory_order_relaxed);
  m_rmsL.store(std::sqrt(sumSqL / static_cast<float>(frames)),
               std::memory_order_relaxed);
  m_rmsR.store(std::sqrt(sumSqR / static_cast<float>(frames)),
               std::memory_order_relaxed);
}

} // namespace xyla::audio
