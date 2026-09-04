#pragma once

#include "audioDeviceBackend.hpp"
#include <atomic>
#include <memory>
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <thread>

namespace xyla::audio {

class PipeWireAudioBackend final : public IAudioDeviceBackend {
public:
  PipeWireAudioBackend();
  ~PipeWireAudioBackend() override;

  [[nodiscard]] const char *backendName() const noexcept override {
    return "PipeWire";
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

  void onProcess();

private:
  AudioDeviceConfig m_config;
  IAudioRenderCallback *m_callback{nullptr};

  struct pw_main_loop *m_loop{nullptr};
  struct pw_stream *m_stream{nullptr};
  struct spa_hook m_streamListener{};

  std::thread m_loopThread;
  std::atomic<bool> m_running{false};
  AudioBuffer m_pipewireBuffer;

  int64_t m_hardwareSampleCounter{0};
};

} // namespace xyla::audio
