#pragma once

#include "core/audio/types/audioFormat.hpp"
#include <cstdint>
#include <string>

namespace xyla::audio {

enum class PinDirection : uint8_t { Input = 0, Output = 1 };

enum class PinDataType : uint8_t {
  AudioStream = 0, // Carries planar float buffers
  ControlValue = 1 // Carries single float or automation modulation
};

struct AudioPinDescriptor {
  std::string pinId;
  std::string name;
  PinDirection direction{PinDirection::Input};
  PinDataType dataType{PinDataType::AudioStream};
  AudioFormat audioFormat{AudioFormat::standardStereo()};

  // Parameter limits (used if dataType == ControlValue)
  float minValue{0.0f};
  float maxValue{1.0f};
  float defaultValue{0.0f};

  static AudioPinDescriptor
  makeAudioInput(const std::string &id, const std::string &name,
                 const AudioFormat &format = AudioFormat::standardStereo()) {
    return AudioPinDescriptor{
        id,   name, PinDirection::Input, PinDataType::AudioStream, format, 0.0f,
        0.0f, 0.0f};
  }

  static AudioPinDescriptor
  makeAudioOutput(const std::string &id, const std::string &name,
                  const AudioFormat &format = AudioFormat::standardStereo()) {
    return AudioPinDescriptor{id,
                              name,
                              PinDirection::Output,
                              PinDataType::AudioStream,
                              format,
                              0.0f,
                              0.0f,
                              0.0f};
  }

  static AudioPinDescriptor makeControlInput(const std::string &id,
                                             const std::string &name,
                                             float minVal, float maxVal,
                                             float defVal) {
    return AudioPinDescriptor{id,
                              name,
                              PinDirection::Input,
                              PinDataType::ControlValue,
                              {},
                              minVal,
                              maxVal,
                              defVal};
  }
};

} // namespace xyla::audio
