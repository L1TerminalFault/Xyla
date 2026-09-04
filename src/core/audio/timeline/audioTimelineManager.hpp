#pragma once

#include "audioClipBuffer.hpp"
#include "audioDecoder.hpp"
#include "core/audio/nodes/clipSourceNode.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"
#include <QObject>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace xyla {
class TimelineModel;
class MediaPool;
} // namespace xyla

namespace xyla::audio {

struct AudioTimelineClipRef {
  std::string clipId;
  std::string assetId;
  int64_t startSample{0};
  int64_t durationSamples{0};
  int64_t sourceInSample{0};
};

struct AudioTrackBinding {
  int trackIndex{0};
  std::string trackId;
  MixerTrackNode *mixerNode{nullptr};
  ClipSourceNode *sourceNode{nullptr};
  std::vector<AudioTimelineClipRef> clips;
};

class AudioTimelineManager : public QObject {
  Q_OBJECT

public:
  static AudioTimelineManager &instance();

  explicit AudioTimelineManager(QObject *parent = nullptr);
  ~AudioTimelineManager() override = default;
  size_t readTrackAudioById(const std::string &trackId, int64_t timelineSample,
                            size_t numFrames, float **outputChannels,
                            size_t channelCount) noexcept;
  void bindTimelineModel(TimelineModel *model, MediaPool *mediaPool);

  // Pre-decode and cache an asset's audio stream
  std::shared_ptr<AudioClipBuffer> loadAssetAudio(const std::string &assetId,
                                                  const std::string &filePath);

  [[nodiscard]] std::shared_ptr<AudioClipBuffer>
  getClipBuffer(const std::string &assetId) const;

  // Called when clips are added/moved/trimmed on the timeline
  void syncTracksFromModel();

  // Called by ClipSourceNode on the real-time audio thread
  size_t readTrackAudio(int trackIndex, int64_t timelineSample,
                        size_t numFrames, float **outputChannels,
                        size_t channelCount) noexcept;

private:
  TimelineModel *m_timelineModel{nullptr};
  MediaPool *m_mediaPool{nullptr};

  // Decoded audio cache (AssetId -> PCM Buffer)
  mutable std::mutex m_cacheMutex;
  std::unordered_map<std::string, std::shared_ptr<AudioClipBuffer>>
      m_assetCache;

  // Track state accessed by audio thread (Double-buffered / Mutex protected)
  std::mutex m_tracksMutex;
  std::vector<AudioTrackBinding> m_trackBindings;

  double m_projectFps{30.0};
  uint32_t m_sampleRate{48000};
};

} // namespace xyla::audio
