#include "audioEngine.hpp"
#include <algorithm>

namespace xyla::audio {

AudioEngine &AudioEngine::instance() {
  static AudioEngine engine;
  return engine;
}

AudioEngine::AudioEngine() {
  // Create and bind permanent Master Output Node
  m_masterNode = m_graph.addNode<MasterOutputNode>("master_out");
  m_graph.setMasterNode(m_masterNode);
}

AudioEngine::~AudioEngine() { shutdown(); }

bool AudioEngine::initialize(std::unique_ptr<IAudioDeviceBackend> backend,
                             const AudioDeviceConfig &config) {
  shutdown();

  if (!backend)
    return false;

  m_backend = std::move(backend);
  m_config = config;
  m_format = config.format;
  m_bufferSize = config.bufferSizeFrames;

  // Initialize scratchpad buffer pool: 32 buffers, channelCount, maxFrames
  m_bufferPool.initialize(32, m_format.channelCount, m_bufferSize);

  // Compile initial graph state
  m_graph.compile(m_format.sampleRate, m_bufferSize);

  if (!m_backend->initialize(m_config, this)) {
    return false;
  }

  m_isInitialized.store(true, std::memory_order_release);
  return true;
}

bool AudioEngine::start() {
  if (!m_isInitialized.load(std::memory_order_acquire) || !m_backend)
    return false;
  return m_backend->start();
}

bool AudioEngine::stop() {
  if (!m_backend)
    return false;
  return m_backend->stop();
}

void AudioEngine::shutdown() {
  stop();
  if (m_backend) {
    m_backend->shutdown();
    m_backend.reset();
  }
  m_isInitialized.store(false, std::memory_order_release);
}

bool AudioEngine::isRunning() const noexcept {
  return m_backend && m_backend->isRunning();
}

MixerTrackNode *AudioEngine::addTrack(const std::string &trackId,
                                      const std::string &name) {
  auto *track = dynamic_cast<MixerTrackNode *>(m_graph.findNode(trackId));
  if (!track) {
    track = m_graph.addNode<MixerTrackNode>(trackId, name);
    m_tracks.push_back(track);
    m_graph.connect(trackId, "audio_out", "master_out", "master_in");
    m_graph.compile(m_format.sampleRate, m_bufferSize);
  }
  return track;
}

bool AudioEngine::removeTrack(const std::string &trackId) {
  m_tracks.erase(
      std::remove_if(m_tracks.begin(), m_tracks.end(),
                     [&](MixerTrackNode *n) { return n->nodeId() == trackId; }),
      m_tracks.end());

  const std::string sourceId =
      "source_" + trackId.substr(trackId.find("track_") == 0 ? 6 : 0);
  m_graph.disconnectAll(trackId);
  m_graph.removeNode(trackId);

  std::string sourceNodeId = "source_" + trackId;
  if (trackId.rfind("track_", 0) == 0) {
    sourceNodeId = "source_" + trackId.substr(6);
  }
  m_graph.disconnectAll(sourceNodeId);
  m_graph.removeNode(sourceNodeId);

  m_graph.compile(m_format.sampleRate, m_bufferSize);
  return true;
}

void AudioEngine::setPlaying(bool playing) noexcept {
  AudioMasterClock::instance().setPlaying(playing);
}

void AudioEngine::seekTimelineSample(int64_t samplePosition) noexcept {
  AudioMasterClock::instance().setTimelinePosition(samplePosition);
}

int64_t AudioEngine::currentTimelineSample() const noexcept {
  return AudioMasterClock::instance().timelineSamples();
}

double AudioEngine::currentTimelineSeconds() const noexcept {
  return AudioMasterClock::instance().timelineSeconds();
}

void AudioEngine::addAutomationClip(std::shared_ptr<AutomationClip> clip) {
  std::lock_guard<std::mutex> lock(m_automationMutex);
  m_automationClips.push_back(std::move(clip));
}

void AudioEngine::removeAutomationClip(const std::string &clipId) {
  std::lock_guard<std::mutex> lock(m_automationMutex);
  m_automationClips.erase(
      std::remove_if(m_automationClips.begin(), m_automationClips.end(),
                     [&](const auto &c) { return c->clipId() == clipId; }),
      m_automationClips.end());
}

void AudioEngine::clearAutomationClips() {
  std::lock_guard<std::mutex> lock(m_automationMutex);
  m_automationClips.clear();
}

void AudioEngine::renderAudio(AudioBuffer &outputBuffer,
                              const AudioClockInfo &clock) noexcept {
  outputBuffer.clear();

  bool isScrubbingActive = AudioMasterClock::instance().isScrubbing();

  if (!clock.isPlaying && !isScrubbingActive) {
    return;
  }

  if (m_automationMutex.try_lock()) {
    for (const auto &clip : m_automationClips) {
      AudioNode *target = m_graph.findNode(clip->targetNodeId());
      if (target) {
        clip->applyBlock(target, clock.timelineSamplePosition,
                         clock.bufferSizeFrames);
      }
    }
    m_automationMutex.unlock();
  }

  m_graph.process(outputBuffer, clock, m_bufferPool);

  m_bufferPool.reset();
}

} // namespace xyla::audio
