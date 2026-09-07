#pragma once

#include "core/animation/animatableProperty.hpp"
#include <QJsonArray>
#include <QJsonObject>
#include <array>

namespace xyla {

struct ClipTransformData {
  anim::AnimatableProperty<std::array<float, 2>> position{{0.0f, 0.0f}};
  anim::AnimatableProperty<std::array<float, 2>> scale{{1.0f, 1.0f}};
  anim::AnimatableProperty<float> rotation{0.0f};
  anim::AnimatableProperty<std::array<float, 2>> anchorPoint{{0.0f, 0.0f}};
  anim::AnimatableProperty<float> opacity{1.0f};
};

struct ClipColorData {
  anim::AnimatableProperty<std::array<float, 4>> lift{{0.0f, 0.0f, 0.0f, 0.0f}};
  anim::AnimatableProperty<std::array<float, 4>> gamma{
      {1.0f, 1.0f, 1.0f, 0.0f}};
  anim::AnimatableProperty<std::array<float, 4>> gain{{1.0f, 1.0f, 1.0f, 0.0f}};
  anim::AnimatableProperty<std::array<float, 4>> offset{
      {0.0f, 0.0f, 0.0f, 0.0f}};

  anim::AnimatableProperty<float> temperature{0.0f};
  anim::AnimatableProperty<float> tint{0.0f};
  anim::AnimatableProperty<float> contrast{1.0f};
  anim::AnimatableProperty<float> pivot{0.435f};
  anim::AnimatableProperty<float> midDetail{0.0f};

  anim::AnimatableProperty<float> colorBoost{0.0f};
  anim::AnimatableProperty<float> shadows{0.0f};
  anim::AnimatableProperty<float> highlights{0.0f};
  anim::AnimatableProperty<float> saturation{50.0f};
  anim::AnimatableProperty<float> hue{50.0f};
  anim::AnimatableProperty<float> lumMix{100.0f};

  bool bypass{false};
};

struct ClipAudioData {
  anim::AnimatableProperty<float> volume{1.0f}; // Linear gain (1.0 = 0dB)
  anim::AnimatableProperty<float> pan{0.0f};    // -1.0 (Left) to +1.0 (Right)
  int channelMode{0}; // 0 = Stereo, 1 = Mono, 2 = 5.1 Surround
};

} // namespace xyla
