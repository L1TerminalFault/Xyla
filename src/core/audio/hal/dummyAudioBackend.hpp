#pragma once

#include "audioDeviceBackend.hpp"
#include <atomic>

namespace xyla::audio {

class DummyAudioBackend final : public IAudioDeviceBackend {
public:
  DummyAudioBackend() = default;
  ~DummyAudioBackend() override { shutdown(); }

  [[nodiscard]] const char *backendName() const noexcept override {
    return "DummyMock";
  }

  bool initialize(const AudioDeviceConfig &config,
                  IAudioRenderCallback *callback) override {
    m_config = config;
    m_callback = callback;
    m_buffer.allocate(config.format.channelCount, config.bufferSizeFrames);
    return true;
  }

  bool start() override {
    m_running.store(true, std::memory_order_release);
    return true;
  }

  bool stop() override {
    m_running.store(false, std::memory_order_release);
    return true;
  }

  void shutdown() override { stop(); }

  [[nodiscard]] bool isRunning() const noexcept override {
    return m_running.load(std::memory_order_acquire);
  }

  [[nodiscard]] AudioDeviceConfig currentConfig() const noexcept override {
    return m_config;
  }

  /**
   * @brief Manually triggers a synthetic audio hardware tick.
   */
  void stepTick() {
    if (!m_callback || !isRunning())
      return;
    AudioClockInfo clock;
    clock.bufferSizeFrames = m_config.bufferSizeFrames;
    clock.sampleRate = m_config.format.sampleRate;
    clock.isPlaying = true;
    m_buffer.clear();
    m_callback->renderAudio(m_buffer, clock);
  }

private:
  AudioDeviceConfig m_config;
  IAudioRenderCallback *m_callback{nullptr};
  std::atomic<bool> m_running{false};
  AudioBuffer m_buffer;
};

} // namespace xyla::audio
