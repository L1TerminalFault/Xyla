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
#include <string_view>
#include <vector>

namespace xyla::audio {

/**
 * @brief Pure helper for track/source node naming resolution.
 */
struct AudioEngineNaming {
  static std::string deriveSourceNodeId(std::string_view trackId) noexcept {
    constexpr std::string_view prefix = "track_";
    if (trackId.rfind(prefix, 0) == 0) {
      return "source_" + std::string(trackId.substr(prefix.size()));
    }
    return "source_" + std::string(trackId);
  }
};

/**
 * @brief Master Audio Engine Facade.
 *
 * Coordinates:
 * - Hardware Device HAL (ALSA, PipeWire, Dummy)
 * - Graph compilation & Lock-Free Execution
 * - Timeline Automation Clip Evaluation
 * - Master Metering & Clock Synchronization
 */
class AudioEngine : public IAudioRenderCallback {
public:
  static AudioEngine &instance();

  AudioEngine();
  ~AudioEngine() override;

  AudioEngine(const AudioEngine &) = delete;
  AudioEngine &operator=(const AudioEngine &) = delete;
  AudioEngine(AudioEngine &&) = delete;
  AudioEngine &operator=(AudioEngine &&) = delete;

  // --- Hardware & Offline Lifecycle ---
  bool initialize(std::unique_ptr<IAudioDeviceBackend> backend,
                  const AudioDeviceConfig &config);

  /**
   * @brief Initializes the engine for headless unit tests or offline rendering
   *        without requiring an ALSA/PipeWire hardware backend.
   */
  bool initializeOffline(
      const AudioFormat &format = AudioFormat::standardStereo(48000),
      uint32_t bufferSize = 256);

  bool start();
  bool stop();
  void shutdown();

  [[nodiscard]] bool isRunning() const noexcept;
  [[nodiscard]] AudioFormat format() const noexcept { return m_format; }
  [[nodiscard]] uint32_t bufferSize() const noexcept { return m_bufferSize; }

  // --- Graph & Mixer Access ---
  AudioGraph &graph() noexcept { return m_graph; }
  [[nodiscard]] const AudioGraph &graph() const noexcept { return m_graph; }
  [[nodiscard]] MasterOutputNode *masterNode() const noexcept {
    return m_masterNode;
  }

  MixerTrackNode *addTrack(const std::string &trackId, const std::string &name);
  bool removeTrack(const std::string &trackId);
  const std::vector<MixerTrackNode *> &tracks() const noexcept {
    return m_tracks;
  }

  // --- Timeline Synchronization ---
  void setPlaying(bool playing) noexcept;
  void seekTimelineSample(int64_t samplePosition) noexcept;
  [[nodiscard]] int64_t currentTimelineSample() const noexcept;
  [[nodiscard]] double currentTimelineSeconds() const noexcept;

  // --- Automation Clips Registry ---
  void addAutomationClip(std::shared_ptr<AutomationClip> clip);
  void removeAutomationClip(const std::string &clipId);
  void clearAutomationClips();

  // --- Audio Rendering Pipeline (Strict Real-Time Callback) ---
  void renderAudio(AudioBuffer &outputBuffer,
                   const AudioClockInfo &clock) noexcept override;

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
  std::atomic<bool> m_isOffline{false};
};

} // namespace xyla::audio
