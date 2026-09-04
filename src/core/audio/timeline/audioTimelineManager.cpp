#include "audioTimelineManager.hpp"
#include "core/audio/audioEngine.hpp"
#include "core/log/logger.hpp"
#include "ui/models/timelineModel.hpp"
#include <algorithm>
#include <cmath>

namespace xyla::audio {

AudioTimelineManager &AudioTimelineManager::instance() {
  static AudioTimelineManager manager;
  return manager;
}

AudioTimelineManager::AudioTimelineManager(QObject *parent) : QObject(parent) {}

void AudioTimelineManager::bindTimelineModel(TimelineModel *model,
                                             MediaPool *mediaPool) {
  m_timelineModel = model;
  m_mediaPool = mediaPool;

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

  XYLA_LOG_INFO("AudioTimelineManager",
                "[INIT] Bound to TimelineModel and MediaPool successfully.");
  syncTracksFromModel();
}

std::shared_ptr<AudioClipBuffer>
AudioTimelineManager::loadAssetAudio(const std::string &assetId,
                                     const std::string &filePath) {
  {
    std::lock_guard<std::mutex> lock(m_cacheMutex);
    auto it = m_assetCache.find(assetId);
    if (it != m_assetCache.end()) {
      XYLA_LOG_INFO("AudioTimelineManager",
                    "[CACHE HIT] Audio already loaded for asset: " + assetId);
      return it->second;
    }
  }

  XYLA_LOG_INFO("AudioTimelineManager",
                "[DECODE START] Loading audio stream from file: " + filePath);
  AudioDecoder localDecoder;
  auto buffer = localDecoder.decodeEntireFile(filePath, m_sampleRate, 2);

  if (buffer && buffer->totalFrames() > 0) {
    XYLA_LOG_INFO("AudioTimelineManager",
                  "[DECODE SUCCESS] Asset [" + assetId + "] decoded " +
                      std::to_string(buffer->totalFrames()) +
                      " frames across " + std::to_string(buffer->channels()) +
                      " channels @ " + std::to_string(buffer->sampleRate()) +
                      " Hz.");

    std::lock_guard<std::mutex> lock(m_cacheMutex);
    m_assetCache[assetId] = buffer;
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

void AudioTimelineManager::syncTracksFromModel() {
  if (!m_timelineModel) {
    XYLA_LOG_WARN("AudioTimelineManager", "[SYNC SKIP] TimelineModel is null.");
    return;
  }

  auto &engine = AudioEngine::instance();
  const int totalTracks = m_timelineModel->rowCount();

  XYLA_LOG_INFO("AudioTimelineManager", "[SYNC START] Inspecting " +
                                            std::to_string(totalTracks) +
                                            " tracks from model.");

  // ------------------------------------------------------------------
  // 1. Collect every audio track that should exist right now
  // ------------------------------------------------------------------
  struct DesiredTrack {
    int index = -1;
    std::string trackId;
    std::string name;
  };
  std::vector<DesiredTrack> desired;
  std::unordered_set<std::string> liveTrackIds;  // "track_<id>"
  std::unordered_set<std::string> liveSourceIds; // "source_<id>"

  for (int t = 0; t < totalTracks; ++t) {
    auto *track = m_timelineModel->getTrack(t);
    if (!track || track->kind() != TrackKind::Audio)
      continue;

    DesiredTrack d;
    d.index = t;
    d.trackId = track->trackId().toStdString();
    d.name = track->name().toStdString();
    desired.push_back(d);

    liveTrackIds.insert("track_" + d.trackId);
    liveSourceIds.insert("source_" + d.trackId);
  }

  // ------------------------------------------------------------------
  // 2. Remove nodes that are no longer in the timeline
  // ------------------------------------------------------------------
  // Snapshot current track nodes owned by the engine
  std::vector<std::string> existingTrackIds;
  for (auto *n : engine.tracks()) {
    if (n)
      existingTrackIds.push_back(n->nodeId());
  }

  for (const std::string &nodeId : existingTrackIds) {
    if (liveTrackIds.count(nodeId) == 0) {
      XYLA_LOG_INFO("AudioTimelineManager",
                    "[GRAPH CLEANUP] Removing stale track node: " + nodeId);
      engine.removeTrack(nodeId); // also removes matching source_ node
    }
  }

  // Extra safety: remove any orphan source_ nodes that might have been left
  // behind (requires a way to iterate all nodes; if you don't have one, the
  // removeTrack path above is usually enough) Example if you add
  // AudioGraph::allNodeIds(): for (const std::string &id :
  // engine.graph().allNodeIds()) {
  //   if (id.rfind("source_", 0) == 0 && liveSourceIds.count(id) == 0) {
  //     engine.graph().disconnectAll(id);
  //     engine.graph().removeNode(id);
  //   }
  // }

  // ------------------------------------------------------------------
  // 3. Create / update bindings for every live audio track
  // ------------------------------------------------------------------
  std::vector<AudioTrackBinding> newBindings;

  for (const DesiredTrack &d : desired) {
    AudioTrackBinding binding;
    binding.trackIndex = d.index;
    binding.trackId = d.trackId;

    const std::string mixerNodeId = "track_" + d.trackId;
    const std::string sourceNodeId = "source_" + d.trackId;

    // ---- MixerTrackNode ----
    auto *mixerNode =
        dynamic_cast<MixerTrackNode *>(engine.graph().findNode(mixerNodeId));
    if (!mixerNode) {
      mixerNode = engine.addTrack(mixerNodeId, d.name);
      XYLA_LOG_INFO("AudioTimelineManager",
                    "[GRAPH BUILD] Created MixerTrackNode [" + mixerNodeId +
                        "] for track: " + d.name);
    }
    binding.mixerNode = mixerNode;

    // ---- ClipSourceNode ----
    auto *sourceNode =
        dynamic_cast<ClipSourceNode *>(engine.graph().findNode(sourceNodeId));
    if (!sourceNode) {
      sourceNode = engine.graph().addNode<ClipSourceNode>(sourceNodeId,
                                                          d.name + " Source");
      engine.graph().connect(sourceNodeId, "audio_out", mixerNodeId,
                             "audio_in");
      XYLA_LOG_INFO("AudioTimelineManager", "[GRAPH ROUTE] Connected " +
                                                sourceNodeId + " -> " +
                                                mixerNodeId);
    }

    // Always (re)bind the PCM reader using the stable trackId.
    // This avoids the stale-index problem when tracks are reordered.
    const std::string capturedTrackId = d.trackId;
    sourceNode->setPcmReader(
        [this, capturedTrackId](int64_t timelineSample, size_t numFrames,
                                float **outBuffers, size_t outChannels) {
          return this->readTrackAudioById(capturedTrackId, timelineSample,
                                          numFrames, outBuffers, outChannels);
        });

    binding.sourceNode = sourceNode;

    // ---- Map clips ----
    auto *track = m_timelineModel->getTrack(d.index);
    if (track) {
      const double samplePerFrame =
          static_cast<double>(m_sampleRate) / m_projectFps;

      for (const auto &clip : track->clips()) {
        AudioTimelineClipRef ref;
        ref.clipId = clip.clipId().toStdString();
        ref.assetId = clip.assetId().toStdString();
        ref.startSample =
            static_cast<int64_t>(clip.startFrame() * samplePerFrame);
        ref.durationSamples =
            static_cast<int64_t>(clip.durationFrames() * samplePerFrame);
        ref.sourceInSample =
            static_cast<int64_t>(clip.sourceInFrame() * samplePerFrame);
        binding.clips.push_back(ref);

        XYLA_LOG_INFO(
            "AudioTimelineManager",
            "[CLIP MAPPED] Track " + std::to_string(d.index) + " (" + d.name +
                ") Clip: " + ref.clipId + " Asset: " + ref.assetId +
                " Range: [" + std::to_string(ref.startSample) + " - " +
                std::to_string(ref.startSample + ref.durationSamples) +
                "] samples.");
      }
    }

    newBindings.push_back(std::move(binding));
  }

  // ------------------------------------------------------------------
  // 4. Publish new bindings + recompile
  // ------------------------------------------------------------------
  {
    std::lock_guard<std::mutex> lock(m_tracksMutex);
    m_trackBindings = std::move(newBindings);
  }

  engine.graph().compile(m_sampleRate, engine.bufferSize());

  XYLA_LOG_INFO("AudioTimelineManager",
                "[SYNC DONE] Audio graph recompiled with " +
                    std::to_string(m_trackBindings.size()) + " audio tracks.");
}

size_t AudioTimelineManager::readTrackAudio(int trackIndex,
                                            int64_t timelineSample,
                                            size_t numFrames,
                                            float **outputChannels,
                                            size_t channelCount) noexcept {
  if (!m_tracksMutex.try_lock()) {
    return 0;
  }

  const AudioTrackBinding *targetTrack = nullptr;
  for (const auto &tb : m_trackBindings) {
    if (tb.trackIndex == trackIndex) {
      targetTrack = &tb;
      break;
    }
  }

  if (!targetTrack || targetTrack->clips.empty()) {
    m_tracksMutex.unlock();
    return 0;
  }

  int64_t blockStart = timelineSample;
  int64_t blockEnd = timelineSample + static_cast<int64_t>(numFrames);

  size_t totalRead = 0;

  for (const auto &clip : targetTrack->clips) {
    int64_t clipEnd = clip.startSample + clip.durationSamples;

    // Check if clip intersects current render block
    if (blockEnd <= clip.startSample || blockStart >= clipEnd) {
      continue;
    }

    std::shared_ptr<AudioClipBuffer> buffer = nullptr;
    {
      if (m_cacheMutex.try_lock()) {
        auto it = m_assetCache.find(clip.assetId);
        if (it != m_assetCache.end()) {
          buffer = it->second;
        }
        m_cacheMutex.unlock();
      }
    }

    if (!buffer) {
      continue;
    }

    int64_t overlapStart = std::max(blockStart, clip.startSample);
    int64_t overlapEnd = std::min(blockEnd, clipEnd);
    size_t overlapFrames = static_cast<size_t>(overlapEnd - overlapStart);

    int64_t bufferOffset =
        (overlapStart - clip.startSample) + clip.sourceInSample;
    size_t destOffset = static_cast<size_t>(overlapStart - blockStart);

    float *sliceOutputs[16];
    for (size_t c = 0; c < channelCount; ++c) {
      sliceOutputs[c] = outputChannels[c] + destOffset;
    }

    buffer->readFrames(bufferOffset, overlapFrames, sliceOutputs, channelCount);
    totalRead += overlapFrames;
  }

  m_tracksMutex.unlock();
  return totalRead;
}

size_t AudioTimelineManager::readTrackAudioById(const std::string &trackId,
                                                int64_t timelineSample,
                                                size_t numFrames,
                                                float **outputChannels,
                                                size_t channelCount) noexcept {
  if (!m_tracksMutex.try_lock())
    return 0;

  const AudioTrackBinding *targetTrack = nullptr;
  for (const auto &tb : m_trackBindings) {
    if (tb.trackId == trackId) {
      targetTrack = &tb;
      break;
    }
  }

  if (!targetTrack || targetTrack->clips.empty()) {
    m_tracksMutex.unlock();
    return 0;
  }

  const int64_t blockStart = timelineSample;
  const int64_t blockEnd = timelineSample + static_cast<int64_t>(numFrames);
  size_t totalRead = 0;

  for (const auto &clip : targetTrack->clips) {
    const int64_t clipEnd = clip.startSample + clip.durationSamples;
    if (blockEnd <= clip.startSample || blockStart >= clipEnd)
      continue;

    std::shared_ptr<AudioClipBuffer> buffer;
    if (m_cacheMutex.try_lock()) {
      auto it = m_assetCache.find(clip.assetId);
      if (it != m_assetCache.end())
        buffer = it->second;
      m_cacheMutex.unlock();
    }
    if (!buffer)
      continue;

    const int64_t overlapStart = std::max(blockStart, clip.startSample);
    const int64_t overlapEnd = std::min(blockEnd, clipEnd);
    const size_t overlapFrames = static_cast<size_t>(overlapEnd - overlapStart);
    const int64_t bufferOffset =
        (overlapStart - clip.startSample) + clip.sourceInSample;
    const size_t destOffset = static_cast<size_t>(overlapStart - blockStart);

    float *sliceOutputs[16];
    for (size_t c = 0; c < channelCount && c < 16; ++c)
      sliceOutputs[c] = outputChannels[c] + destOffset;

    buffer->readFrames(bufferOffset, overlapFrames, sliceOutputs, channelCount);
    totalRead += overlapFrames;
  }

  m_tracksMutex.unlock();
  return totalRead;
}
} // namespace xyla::audio
