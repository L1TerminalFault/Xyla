#pragma once

#include "core/audio/graph/audioGraph.hpp"
#include "core/audio/hal/audioDeviceBackend.hpp"
#include "core/audio/nodes/masterOutputNode.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"
#include "core/audio/timeline/automationClip.hpp"
#include "core/audio/types/audioBufferPool.hpp"
#include "core/audio/types/audioClock.hpp"
#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace xyla::audio {

/**
 * @brief Master Audio Engine Facade.
 *
 * Coordinates:
 * - Hardware Device HAL (ALSA, PipeWire, Dummy)
 * - Graph compilation & Lock-Free Execution
 * - Timeline Automation Clip Evaluation
 * - Master Metering & Clock Synchronization
 */
class AudioEngine final : public IAudioRenderCallback {
public:
  static AudioEngine &instance();

  AudioEngine();
  ~AudioEngine() override;

  AudioEngine(const AudioEngine &) = delete;
  AudioEngine &operator=(const AudioEngine &) = delete;

  // --- Hardware Lifecycle ---
  bool initialize(std::unique_ptr<IAudioDeviceBackend> backend,
                  const AudioDeviceConfig &config);
  bool start();
  bool stop();
  void shutdown();

  [[nodiscard]] bool isRunning() const noexcept;
  [[nodiscard]] AudioFormat format() const noexcept { return m_format; }
  [[nodiscard]] uint32_t bufferSize() const noexcept { return m_bufferSize; }

  // --- Graph & Mixer Access ---
  AudioGraph &graph() noexcept { return m_graph; }
  [[nodiscard]] MasterOutputNode *masterNode() const noexcept {
    return m_masterNode;
  }

  MixerTrackNode *addTrack(const std::string &trackId, const std::string &name);
  bool removeTrack(const std::string &trackId);

  // --- Timeline Synchronization ---
  void setPlaying(bool playing) noexcept;
  void seekTimelineSample(int64_t samplePosition) noexcept;
  [[nodiscard]] int64_t currentTimelineSample() const noexcept;
  [[nodiscard]] double currentTimelineSeconds() const noexcept;

  // --- Automation Clips Registry ---
  void addAutomationClip(std::shared_ptr<AutomationClip> clip);
  void removeAutomationClip(const std::string &clipId);
  void clearAutomationClips();

  // --- Hardware Audio Callback (Strict Real-Time Thread) ---
  void renderAudio(AudioBuffer &outputBuffer,
                   const AudioClockInfo &clock) noexcept override;

  const std::vector<MixerTrackNode *> &tracks() const noexcept {
    return m_tracks;
  }

private:
  std::unique_ptr<IAudioDeviceBackend> m_backend;
  AudioDeviceConfig m_config;
  AudioFormat m_format{AudioFormat::standardStereo(48000)};
  uint32_t m_bufferSize{256};

  AudioGraph m_graph;
  AudioBufferPool m_bufferPool;
  MasterOutputNode *m_masterNode{nullptr};

  // Track strips index
  std::vector<MixerTrackNode *> m_tracks;

  // Automation clips evaluated on audio tick
  std::mutex m_automationMutex;
  std::vector<std::shared_ptr<AutomationClip>> m_automationClips;

  std::atomic<bool> m_isInitialized{false};
};

} // namespace xyla::audio
