#pragma once

#include "core/animation/animProperty.hpp"

namespace xyla {

struct ClipTransformData {
  anim::AnimProperty posX{0.0f};
  anim::AnimProperty posY{0.0f};
  anim::AnimProperty scaleX{1.0f};
  anim::AnimProperty scaleY{1.0f};
  anim::AnimProperty rotation{0.0f};
  anim::AnimProperty opacity{1.0f};
};

struct ClipColorData {
  // Lift
  anim::AnimProperty liftR{0.0f};
  anim::AnimProperty liftG{0.0f};
  anim::AnimProperty liftB{0.0f};

  // Gamma
  anim::AnimProperty gammaR{1.0f};
  anim::AnimProperty gammaG{1.0f};
  anim::AnimProperty gammaB{1.0f};

  // Gain
  anim::AnimProperty gainR{1.0f};
  anim::AnimProperty gainG{1.0f};
  anim::AnimProperty gainB{1.0f};

  // Offset
  anim::AnimProperty offsetR{0.0f};
  anim::AnimProperty offsetG{0.0f};
  anim::AnimProperty offsetB{0.0f};

  // Primary controls
  anim::AnimProperty temperature{0.0f};
  anim::AnimProperty tint{0.0f};
  anim::AnimProperty contrast{1.0f};
  anim::AnimProperty pivot{0.435f};
  anim::AnimProperty midDetail{0.0f};
  anim::AnimProperty colorBoost{0.0f};
  anim::AnimProperty shadows{0.0f};
  anim::AnimProperty highlights{0.0f};
  anim::AnimProperty saturation{50.0f};
  anim::AnimProperty hue{50.0f};
  anim::AnimProperty lumMix{100.0f};

  bool bypass{false};
};

struct ClipAudioData {
  anim::AnimProperty volume{1.0f};
  anim::AnimProperty pan{0.0f};
  int channelMode{0};
};

} // namespace xyla
