#pragma once

#include "audioDeviceBackend.hpp"
#include <atomic>
#include <thread>

namespace xyla::audio {

class DummyAudioBackend final : public IAudioDeviceBackend {
public:
  DummyAudioBackend();
  ~DummyAudioBackend() override;

  [[nodiscard]] const char *backendName() const noexcept override {
    return "Dummy/Clock";
  }

  bool initialize(const AudioDeviceConfig &config,
                  IAudioRenderCallback *callback) override;
  bool start() override;
  bool stop() override;
  void shutdown() override;

  [[nodiscard]] bool isRunning() const noexcept override {
    return m_running.load(std::memory_order_acquire);
  }

  [[nodiscard]] AudioDeviceConfig currentConfig() const noexcept override {
    return m_config;
  }

private:
  void audioThreadLoop();

  AudioDeviceConfig m_config;
  IAudioRenderCallback *m_callback{nullptr};

  std::thread m_thread;
  std::atomic<bool> m_running{false};
  std::atomic<bool> m_stopRequested{false};

  AudioBuffer m_scratchBuffer;
};

} // namespace xyla::audio
