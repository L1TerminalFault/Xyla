/**
 * @file audioTimelineManager.cpp
 * @brief Refactored AudioTimelineManager implementation with modular helpers,
 *        enhanced thread safety, and unified audio DSP processing.
 */

#include "audioTimelineManager.hpp"
#include "clipAudioProcessor.hpp"
#include "core/audio/decoder/audioDecoder.hpp"
#include "core/audio/engine/audioEngine.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/log/logger.hpp"
#include "ui/models/timelineModel.hpp"

namespace xyla::audio {

// ============================================================================
// 1. Singleton & Lifecycle
// ============================================================================

AudioTimelineManager &AudioTimelineManager::instance() {
  static AudioTimelineManager manager;
  return manager;
}

AudioTimelineManager::AudioTimelineManager(QObject *parent) : QObject(parent) {}

void AudioTimelineManager::bindTimelineModel(TimelineModel *model,
                                             MediaPool *mediaPool) {
  m_timelineModel = model;
  m_mediaPool = mediaPool;

  // Listen to TimelineModel modifications to keep audio playback graph
  // synchronized
  if (m_timelineModel) {
    connect(m_timelineModel, &QAbstractItemModel::dataChanged, this,
            &AudioTimelineManager::syncTracksFromModel);
    connect(m_timelineModel, &QAbstractItemModel::rowsInserted, this,
            &AudioTimelineManager::syncTracksFromModel);
    connect(m_timelineModel, &QAbstractItemModel::rowsRemoved, this,
            &AudioTimelineManager::syncTracksFromModel);
    connect(m_timelineModel, &QAbstractItemModel::modelReset, this,
            &AudioTimelineManager::syncTracksFromModel);
  }

  // XYLA_LOG_INFO("AudioTimelineManager",
  //               "[INIT] Bound to TimelineModel and MediaPool successfully.");
  syncTracksFromModel();
}

// ============================================================================
// 2. Asset Audio Loading & Cache
// ============================================================================

std::shared_ptr<AudioClipBuffer>
AudioTimelineManager::loadAssetAudio(const std::string &assetId,
                                     const std::string &filePath) {
  // Check memory cache first
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_assetCache.find(assetId);
    if (it != m_assetCache.end()) {
      // XYLA_LOG_INFO("AudioTimelineManager",
      //               "[CACHE HIT] Audio already loaded for asset: " +
      //               assetId);
      return it->second;
    }
  }

  // XYLA_LOG_INFO("AudioTimelineManager",
  //               "[DECODE START] Loading audio stream from file: " +
  //               filePath);
  AudioDecoder localDecoder;
  auto buffer = localDecoder.decodeEntireFile(filePath, m_sampleRate, 2);

  if (buffer && buffer->totalFrames() > 0) {
    // XYLA_LOG_INFO("AudioTimelineManager",
    //               "[DECODE SUCCESS] Asset [" + assetId + "] decoded " +
    //                   std::to_string(buffer->totalFrames()) +
    //                   " frames across " + std::to_string(buffer->channels())
    //                   + " channels @ " + std::to_string(buffer->sampleRate())
    //                   + " Hz.");
    {
      std::lock_guard<std::mutex> lock(m_cacheMutex);
      m_assetCache[assetId] = buffer;
    }
    // Asynchronously or synchronously populate waveform cache for the UI
    // timeline
    audio::WaveformGenerator::instance().getOrGenerate(assetId, buffer);
  } else {
    XYLA_LOG_ERROR(
        "AudioTimelineManager",
        "[DECODE FAILED] AudioDecoder returned empty buffer for file: " +
            filePath);
  }

  return buffer;
}

std::shared_ptr<AudioClipBuffer>
AudioTimelineManager::getClipBuffer(const std::string &assetId) const {
  std::lock_guard<std::mutex> lock(m_cacheMutex);
  auto it = m_assetCache.find(assetId);
  if (it != m_assetCache.end()) {
    return it->second;
  }
  return nullptr;
}

// ============================================================================
// 3. Timeline Model Synchronization Helpers
// ============================================================================

void AudioTimelineManager::updateProjectFpsFromModel() {
  if (m_timelineModel && m_timelineModel->projectManager() &&
      m_timelineModel->projectManager()->hasActiveProject()) {
    if (const auto *proj = m_timelineModel->projectManager()->activeProject()) {
      if (proj->fps() > 0.0) {
        m_projectFps = proj->fps();
      }
    }
  }
}

std::vector<AudioTimelineManager::DesiredTrack>
AudioTimelineManager::collectDesiredAudioTracks(
    std::unordered_set<std::string> &outLiveTrackIds,
    std::unordered_set<std::string> &outLiveSourceIds) const {

  std::vector<DesiredTrack> desired;
  if (!m_timelineModel)
    return desired;

  const int totalTracks = m_timelineModel->rowCount();
  for (int t = 0; t < totalTracks; ++t) {
    auto *track = m_timelineModel->getTrack(t);
    // Ignore non-audio tracks (e.g. video, subtitles, markers)
    if (!track || track->getKind() != TrackKind::Audio) {
      continue;
    }

    DesiredTrack d;
    d.index = t;
    d.trackId = track->getTrackId().toStdString();
    d.name = track->getName().toStdString();
    desired.push_back(d);

    // Track node identifiers in AudioEngine graph
    outLiveTrackIds.insert("track_" + d.trackId);
    outLiveSourceIds.insert("source_" + d.trackId);
  }

  return desired;
}

void AudioTimelineManager::pruneObsoleteEngineTracks(
    const std::unordered_set<std::string> &liveTrackIds) {

  auto &engine = AudioEngine::instance();
  std::vector<std::string> existingTrackIds;

  for (auto *n : engine.tracks()) {
    if (n) {
      existingTrackIds.push_back(n->nodeId());
    }
  }

  // Remove nodes from audio graph if their corresponding track was deleted in
  // Qt model
  for (const std::string &nodeId : existingTrackIds) {
    if (liveTrackIds.count(nodeId) == 0) {
      engine.removeTrack(nodeId);
    }
  }
}

void AudioTimelineManager::setupTrackAudioNodes(
    const DesiredTrack &desiredTrack, AudioTrackBinding &binding) {
  auto &engine = AudioEngine::instance();
  binding.trackIndex = desiredTrack.index;
  binding.trackId = desiredTrack.trackId;

  const std::string mixerNodeId = "track_" + desiredTrack.trackId;
  const std::string sourceNodeId = "source_" + desiredTrack.trackId;

  // 1. Ensure MixerTrackNode exists in AudioEngine
  auto *mixerNode =
      dynamic_cast<MixerTrackNode *>(engine.graph().findNode(mixerNodeId));
  if (!mixerNode) {
    mixerNode = engine.addTrack(mixerNodeId, desiredTrack.name);
  }
  binding.mixerNode = mixerNode;

  // 2. Ensure ClipSourceNode exists and routes audio into MixerTrackNode
  auto *sourceNode =
      dynamic_cast<ClipSourceNode *>(engine.graph().findNode(sourceNodeId));
  if (!sourceNode) {
    sourceNode = engine.graph().addNode<ClipSourceNode>(
        sourceNodeId, desiredTrack.name + " Source");
    engine.graph().connect(sourceNodeId, "audio_out", mixerNodeId, "audio_in");
    // XYLA_LOG_INFO("AudioTimelineManager", "[GRAPH ROUTE] Connected " +
    //                                           sourceNodeId + " -> " +
    //                                           mixerNodeId);
  }

  // 3. Bind PCM reader lambda using stable trackId (resilient against track
  // reordering)
  const std::string capturedTrackId = desiredTrack.trackId;
  sourceNode->setPcmReader(
      [this, capturedTrackId](int64_t timelineSample, size_t numFrames,
                              float **outBuffers, size_t outChannels) {
        return this->readTrackAudioById(capturedTrackId, timelineSample,
                                        numFrames, outBuffers, outChannels);
      });

  binding.sourceNode = sourceNode;
}

std::vector<AudioTimelineClipRef>
AudioTimelineManager::buildClipRefsForTrack(int trackIndex) const {
  std::vector<AudioTimelineClipRef> clipRefs;
  if (!m_timelineModel)
    return clipRefs;

  auto *track = m_timelineModel->getTrack(trackIndex);
  if (!track)
    return clipRefs;

  // Conversion factor from timeline video frames to audio samples:
  // samples = frames * (sampleRate / fps)
  const double samplePerFrame =
      static_cast<double>(m_sampleRate) / m_projectFps;

  for (const auto &clip : track->getClips()) {
    AudioTimelineClipRef ref;
    ref.clipId = clip.getClipId().toStdString();
    ref.assetId = clip.getAssetId().toStdString();
    ref.startSample =
        static_cast<int64_t>(clip.getTiming().startFrame * samplePerFrame);
    ref.durationSamples =
        static_cast<int64_t>(clip.getTiming().durationFrames * samplePerFrame);
    ref.sourceInSample =
        static_cast<int64_t>(clip.getTiming().sourceInFrame * samplePerFrame);
    ref.volume = clip.getAudio().volume.getStaticValue();
    ref.pan = clip.getAudio().pan.getStaticValue();
    ref.isMuted = clip.getIsMuted();
    clipRefs.push_back(ref);
  }

  return clipRefs;
}

// ============================================================================
// 4. Primary Sync Orchestration
// ============================================================================

void AudioTimelineManager::syncTracksFromModel() {
  if (!m_timelineModel) {
    XYLA_LOG_WARN("AudioTimelineManager", "[SYNC SKIP] TimelineModel is null.");
    return;
  }

  // 1. Update project frame rate
  updateProjectFpsFromModel();

  // 2. Discover all audio tracks present in TimelineModel
  std::unordered_set<std::string> liveTrackIds;  // "track_<id>"
  std::unordered_set<std::string> liveSourceIds; // "source_<id>"
  const std::vector<DesiredTrack> desiredTracks =
      collectDesiredAudioTracks(liveTrackIds, liveSourceIds);

  // 3. Remove obsolete nodes from audio engine graph
  pruneObsoleteEngineTracks(liveTrackIds);

  // 4. Build bindings for all desired audio tracks
  std::vector<AudioTrackBinding> newBindings;
  newBindings.reserve(desiredTracks.size());

  for (const auto &d : desiredTracks) {
    AudioTrackBinding binding;
    setupTrackAudioNodes(d, binding);
    binding.clips = buildClipRefsForTrack(d.index);
    newBindings.push_back(std::move(binding));
  }

  // ------------------------------------------------------------------
  // 5. Publish new bindings under lock and recompile the AudioEngine graph
  // ------------------------------------------------------------------
  {
    std::lock_guard<std::mutex> lock(m_tracksMutex);
    m_trackBindings = std::move(newBindings);
  }

  auto &engine = AudioEngine::instance();
  engine.graph().compile(m_sampleRate, engine.bufferSize());

  // XYLA_LOG_INFO("AudioTimelineManager",
  //               "[SYNC DONE] Audio graph recompiled with " +
  //                   std::to_string(m_trackBindings.size()) + " audio
  //                   tracks.");
}

// ============================================================================
// 5. Real-Time Audio Rendering Helpers
// ============================================================================

const AudioTrackBinding *AudioTimelineManager::findBindingById(
    const std::string &trackId) const noexcept {
  for (const auto &tb : m_trackBindings) {
    if (tb.trackId == trackId) {
      return &tb;
    }
  }
  return nullptr;
}

const AudioTrackBinding *
AudioTimelineManager::findBindingByIndex(int trackIndex) const noexcept {
  for (const auto &tb : m_trackBindings) {
    if (tb.trackIndex == trackIndex) {
      return &tb;
    }
  }
  return nullptr;
}

std::shared_ptr<AudioClipBuffer>
AudioTimelineManager::tryGetCachedBuffer(const std::string &assetId) noexcept {
  // In the real-time audio thread, try_lock prevents priority inversion /
  // thread blocking
  if (!m_cacheMutex.try_lock()) {
    return nullptr;
  }

  std::shared_ptr<AudioClipBuffer> buffer = nullptr;
  auto it = m_assetCache.find(assetId);
  if (it != m_assetCache.end()) {
    buffer = it->second;
  }
  m_cacheMutex.unlock();
  return buffer;
}

size_t AudioTimelineManager::renderSingleClip(const AudioTimelineClipRef &clip,
                                              int64_t blockStart,
                                              int64_t blockEnd,
                                              float **outputChannels,
                                              size_t channelCount) noexcept {
  // Calculate sample-accurate overlap window
  const ClipOverlapWindow window =
      ClipOverlapWindow::compute(blockStart, blockEnd, clip.startSample,
                                 clip.durationSamples, clip.sourceInSample);

  if (!window.hasOverlap || window.overlapFrames == 0) {
    return 0;
  }

  // Acquire asset audio buffer without blocking
  std::shared_ptr<AudioClipBuffer> buffer = tryGetCachedBuffer(clip.assetId);
  if (!buffer) {
    return 0;
  }

  // Prepare channel output pointer slices offset to the destination sample
  float *sliceOutputs[16];
  for (size_t c = 0; c < channelCount && c < 16; ++c) {
    sliceOutputs[c] =
        outputChannels[c] ? (outputChannels[c] + window.destOffset) : nullptr;
  }

  // Read PCM frames from audio asset
  const size_t framesRead = buffer->readFrames(
      window.bufferOffset, window.overlapFrames, sliceOutputs, channelCount);

  if (framesRead > 0) {
    // Apply channel mode remapping, mute, volume, and stereo pan law
    const ClipDspParams dspParams{clip.volume, clip.pan, clip.channelMode,
                                  clip.isMuted};
    dsp::applyClipDsp(sliceOutputs, channelCount, framesRead, dspParams);
  }

  return framesRead;
}

size_t AudioTimelineManager::renderTrackAudioInternal(
    const AudioTrackBinding &track, int64_t timelineSample, size_t numFrames,
    float **outputChannels, size_t channelCount) noexcept {
  if (track.clips.empty() || outputChannels == nullptr || channelCount == 0) {
    return 0;
  }

  const int64_t blockStart = timelineSample;
  const int64_t blockEnd = timelineSample + static_cast<int64_t>(numFrames);
  size_t totalRendered = 0;

  for (const auto &clip : track.clips) {
    totalRendered += renderSingleClip(clip, blockStart, blockEnd,
                                      outputChannels, channelCount);
  }

  return totalRendered;
}

// ============================================================================
// 6. Public Real-Time Audio Interfaces
// ============================================================================

size_t AudioTimelineManager::readTrackAudio(int trackIndex,
                                            int64_t timelineSample,
                                            size_t numFrames,
                                            float **outputChannels,
                                            size_t channelCount) noexcept {
  // Audio thread must never block on m_tracksMutex: use try_lock to avoid audio
  // dropouts
  if (!m_tracksMutex.try_lock()) {
    return 0;
  }

  const AudioTrackBinding *targetTrack = findBindingByIndex(trackIndex);
  size_t framesRead = 0;

  if (targetTrack) {
    // Delegates to unified render function with full DSP (fixing previous
    // missing DSP in this overload)
    framesRead = renderTrackAudioInternal(
        *targetTrack, timelineSample, numFrames, outputChannels, channelCount);
  }

  m_tracksMutex.unlock();
  return framesRead;
}

size_t AudioTimelineManager::readTrackAudioById(const std::string &trackId,
                                                int64_t timelineSample,
                                                size_t numFrames,
                                                float **outputChannels,
                                                size_t channelCount) noexcept {
  if (!m_tracksMutex.try_lock()) {
    return 0;
  }

  const AudioTrackBinding *targetTrack = findBindingById(trackId);
  size_t framesRead = 0;

  if (targetTrack) {
    framesRead = renderTrackAudioInternal(
        *targetTrack, timelineSample, numFrames, outputChannels, channelCount);
  }

  m_tracksMutex.unlock();
  return framesRead;
}

// ============================================================================
// 7. Dynamic Clip Parameter Updates
// ============================================================================

void AudioTimelineManager::updateClipAudioParams(const std::string &clipId,
                                                 float volume, float pan,
                                                 int channelMode,
                                                 bool isMuted) {
  std::lock_guard<std::mutex> lock(m_tracksMutex);
  for (auto &trackBinding : m_trackBindings) {
    for (auto &clip : trackBinding.clips) {
      if (clip.clipId == clipId) {
        clip.volume = volume;
        clip.pan = pan;
        clip.channelMode = channelMode;
        clip.isMuted = isMuted;
        return;
      }
    }
  }
}

} // namespace xyla::audio
