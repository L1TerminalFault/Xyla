#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace xyla::audio {

enum class ChannelLayout : uint32_t {
  Mono = 1,
  Stereo = 2,
  Surround_5_1 = 6,
  Surround_7_1 = 8,
  Atmos_7_1_4 = 12,
  Ambisonics_1stOrder = 4,
  Ambisonics_2ndOrder = 9,
  Ambisonics_3rdOrder = 16
};

enum class ChannelRole : uint8_t {
  Left = 0,
  Right = 1,
  Center = 2,
  LFE = 3, // Low Frequency Effects
  SurroundLeft = 4,
  SurroundRight = 5,
  SideLeft = 6,
  SideRight = 7,
  TopFrontLeft = 8,
  TopFrontRight = 9,
  TopBackLeft = 10,
  TopBackRight = 11,
  Ambisonic_W = 12,
  Ambisonic_X = 13,
  Ambisonic_Y = 14,
  Ambisonic_Z = 15,
  Unknown = 255
};

struct AudioFormat {
  uint32_t sampleRate{48000};
  uint32_t channelCount{2};
  ChannelLayout layout{ChannelLayout::Stereo};

  static AudioFormat standardStereo(uint32_t sampleRate = 48000) {
    return AudioFormat{sampleRate, 2, ChannelLayout::Stereo};
  }

  static AudioFormat standardSurround51(uint32_t sampleRate = 48000) {
    return AudioFormat{sampleRate, 6, ChannelLayout::Surround_5_1};
  }

  static AudioFormat standardAtmos714(uint32_t sampleRate = 48000) {
    return AudioFormat{sampleRate, 12, ChannelLayout::Atmos_7_1_4};
  }

  bool operator==(const AudioFormat &other) const noexcept {
    return sampleRate == other.sampleRate &&
           channelCount == other.channelCount && layout == other.layout;
  }

  bool operator!=(const AudioFormat &other) const noexcept {
    return !(*this == other);
  }

  [[nodiscard]] std::vector<ChannelRole> channelRoles() const {
    switch (layout) {
    case ChannelLayout::Mono:
      return {ChannelRole::Center};
    case ChannelLayout::Stereo:
      return {ChannelRole::Left, ChannelRole::Right};
    case ChannelLayout::Surround_5_1:
      return {ChannelRole::Left,         ChannelRole::Right,
              ChannelRole::Center,       ChannelRole::LFE,
              ChannelRole::SurroundLeft, ChannelRole::SurroundRight};
    case ChannelLayout::Surround_7_1:
      return {ChannelRole::Left,         ChannelRole::Right,
              ChannelRole::Center,       ChannelRole::LFE,
              ChannelRole::SideLeft,     ChannelRole::SideRight,
              ChannelRole::SurroundLeft, ChannelRole::SurroundRight};
    case ChannelLayout::Atmos_7_1_4:
      return {ChannelRole::Left,         ChannelRole::Right,
              ChannelRole::Center,       ChannelRole::LFE,
              ChannelRole::SideLeft,     ChannelRole::SideRight,
              ChannelRole::SurroundLeft, ChannelRole::SurroundRight,
              ChannelRole::TopFrontLeft, ChannelRole::TopFrontRight,
              ChannelRole::TopBackLeft,  ChannelRole::TopBackRight};
    default:
      std::vector<ChannelRole> roles(channelCount, ChannelRole::Unknown);
      return roles;
    }
  }
};

} // namespace xyla::audio
