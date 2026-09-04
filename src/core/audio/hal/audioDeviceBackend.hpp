#pragma once

#include "core/audio/types/audioBuffer.hpp"
#include "core/audio/types/audioClock.hpp"
#include "core/audio/types/audioFormat.hpp"
#include <string>

namespace xyla::audio {

struct AudioDeviceConfig {
  std::string deviceName{"default"};
  AudioFormat format{AudioFormat::standardStereo(48000)};
  uint32_t bufferSizeFrames{256}; // 256 @ 48kHz = 5.33ms hardware block latency
  uint32_t numBuffers{2};
};

/**
 * @brief High-frequency audio callback invoked directly by the OS driver
 * thread.
 *
 * RULES: ZERO heap allocation, ZERO mutex locks, ZERO file/network I/O.
 */
class IAudioRenderCallback {
public:
  virtual ~IAudioRenderCallback() = default;

  /**
   * @brief Called by driver when it needs audio.
   * @param outputBuffer Pre-allocated planar buffer to be filled by the graph.
   * @param clock Timebase metadata.
   */
  virtual void renderAudio(AudioBuffer &outputBuffer,
                           const AudioClockInfo &clock) noexcept = 0;
};

/**
 * @brief Platform-agnostic Audio Driver Interface (HAL).
 */
class IAudioDeviceBackend {
public:
  virtual ~IAudioDeviceBackend() = default;

  [[nodiscard]] virtual const char *backendName() const noexcept = 0;
  virtual bool initialize(const AudioDeviceConfig &config,
                          IAudioRenderCallback *callback) = 0;
  virtual bool start() = 0;
  virtual bool stop() = 0;
  virtual void shutdown() = 0;

  [[nodiscard]] virtual bool isRunning() const noexcept = 0;
  [[nodiscard]] virtual AudioDeviceConfig currentConfig() const noexcept = 0;
};

} // namespace xyla::audio
