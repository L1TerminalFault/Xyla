// #pragma once
//
// #include "audioClipBuffer.hpp"
// #include "audioDecoder.hpp"
// #include "core/audio/nodes/clipSourceNode.hpp"
// #include "core/audio/nodes/mixerTrackNode.hpp"
// #include <QObject>
// #include <memory>
// #include <mutex>
// #include <string>
// #include <unordered_map>
// #include <vector>
//
// namespace xyla {
// class TimelineModel;
// class MediaPool;
// } // namespace xyla
//
// namespace xyla::audio {
//
// struct AudioTimelineClipRef {
//   std::string clipId;
//   std::string assetId;
//   int64_t startSample{0};
//   int64_t durationSamples{0};
//   int64_t sourceInSample{0};
//
//   float volume{1.0f};
//   float pan{0.0f};
//   int channelMode{0};
//   bool isMuted{false};
// };
//
// struct AudioTrackBinding {
//   int trackIndex{0};
//   std::string trackId;
//   MixerTrackNode *mixerNode{nullptr};
//   ClipSourceNode *sourceNode{nullptr};
//   std::vector<AudioTimelineClipRef> clips;
// };
//
// class AudioTimelineManager : public QObject {
//   Q_OBJECT
//
// public:
//   static AudioTimelineManager &instance();
//
//   void updateClipAudioParams(const std::string &clipId, float volume, float pan,
//                              int channelMode, bool isMuted);
//
//   explicit AudioTimelineManager(QObject *parent = nullptr);
//   ~AudioTimelineManager() override = default;
//   size_t readTrackAudioById(const std::string &trackId, int64_t timelineSample,
//                             size_t numFrames, float **outputChannels,
//                             size_t channelCount) noexcept;
//   void bindTimelineModel(TimelineModel *model, MediaPool *mediaPool);
//
//   // Pre-decode and cache an asset's audio stream
//   std::shared_ptr<AudioClipBuffer> loadAssetAudio(const std::string &assetId,
//                                                   const std::string &filePath);
//
//   [[nodiscard]] std::shared_ptr<AudioClipBuffer>
//   getClipBuffer(const std::string &assetId) const;
//
//   // Called when clips are added/moved/trimmed on the timeline
//   void syncTracksFromModel();
//
//   // Called by ClipSourceNode on the real-time audio thread
//   size_t readTrackAudio(int trackIndex, int64_t timelineSample,
//                         size_t numFrames, float **outputChannels,
//                         size_t channelCount) noexcept;
//
// private:
//   TimelineModel *m_timelineModel{nullptr};
//   MediaPool *m_mediaPool{nullptr};
//
//   // Decoded audio cache (AssetId -> PCM Buffer)
//   mutable std::mutex m_cacheMutex;
//   std::unordered_map<std::string, std::shared_ptr<AudioClipBuffer>>
//       m_assetCache;
//
//   // Track state accessed by audio thread (Double-buffered / Mutex protected)
//   std::mutex m_tracksMutex;
//   std::vector<AudioTrackBinding> m_trackBindings;
//
//   double m_projectFps{30.0};
//   uint32_t m_sampleRate{48000};
// };
//
// } // namespace xyla::audio


// #pragma once
//
// #include "audioClipBuffer.hpp"
// #include "audioDecoder.hpp"
// #include "core/audio/nodes/clipSourceNode.hpp"
// #include "core/audio/nodes/mixerTrackNode.hpp"
// #include "clipAudioProcessor.hpp"
// #include <QObject>
// #include <memory>
// #include <mutex>
// #include <string>
// #include <unordered_map>
// #include <unordered_set>
// #include <vector>
//
// namespace xyla {
// class TimelineModel;
// class MediaPool;
// } // namespace xyla
//
// namespace xyla::audio {
//
// struct AudioTimelineClipRef {
//   std::string clipId;
//   std::string assetId;
//   int64_t startSample{0};
//   int64_t durationSamples{0};
//   int64_t sourceInSample{0};
//
//   float volume{1.0f};
//   float pan{0.0f};
//   int channelMode{0};
//   bool isMuted{false};
// };
//
// struct AudioTrackBinding {
//   int trackIndex{0};
//   std::string trackId;
//   MixerTrackNode *mixerNode{nullptr};
//   ClipSourceNode *sourceNode{nullptr};
//   std::vector<AudioTimelineClipRef> clips;
// };
//
// class AudioTimelineManager : public QObject {
//   Q_OBJECT
//
// public:
//   static AudioTimelineManager &instance();
//
//   void updateClipAudioParams(const std::string &clipId, float volume, float pan,
//                              int channelMode, bool isMuted);
//
//   explicit AudioTimelineManager(QObject *parent = nullptr);
//   ~AudioTimelineManager() override = default;
//
//   // Prevent copy and assignment for singleton
//   AudioTimelineManager(const AudioTimelineManager &) = delete;
//   AudioTimelineManager &operator=(const AudioTimelineManager &) = delete;
//
//   size_t readTrackAudioById(const std::string &trackId, int64_t timelineSample,
//                             size_t numFrames, float **outputChannels,
//                             size_t channelCount) noexcept;
//   void bindTimelineModel(TimelineModel *model, MediaPool *mediaPool);
//
//   // Pre-decode and cache an asset's audio stream
//   std::shared_ptr<AudioClipBuffer> loadAssetAudio(const std::string &assetId,
//                                                   const std::string &filePath);
//
//   [[nodiscard]] std::shared_ptr<AudioClipBuffer>
//   getClipBuffer(const std::string &assetId) const;
//
//   // Called when clips are added/moved/trimmed on the timeline
//   void syncTracksFromModel();
//
//   // Called by ClipSourceNode on the real-time audio thread
//   size_t readTrackAudio(int trackIndex, int64_t timelineSample,
//                         size_t numFrames, float **outputChannels,
//                         size_t channelCount) noexcept;
//
// private:
//   TimelineModel *m_timelineModel{nullptr};
//   MediaPool *m_mediaPool{nullptr};
//
//   // Decoded audio cache (AssetId -> PCM Buffer)
//   mutable std::mutex m_cacheMutex;
//   std::unordered_map<std::string, std::shared_ptr<AudioClipBuffer>>
//       m_assetCache;
//
//   // Track state accessed by audio thread (Double-buffered / Mutex protected)
//   std::mutex m_tracksMutex;
//   std::vector<AudioTrackBinding> m_trackBindings;
//
//   double m_projectFps{30.0};
//   uint32_t m_sampleRate{48000};
//
//   // ------------------------------------------------------------------
//   // Modular Internal Helpers (Decomposed sync and unified audio rendering)
//   // ------------------------------------------------------------------
//   struct DesiredTrack {
//     int index = -1;
//     std::string trackId;
//     std::string name;
//   };
//
//   void updateProjectFpsFromModel();
//   std::vector<DesiredTrack> collectDesiredAudioTracks(
//       std::unordered_set<std::string> &outLiveTrackIds,
//       std::unordered_set<std::string> &outLiveSourceIds) const;
//   void pruneObsoleteEngineTracks(const std::unordered_set<std::string> &liveTrackIds);
//   void setupTrackAudioNodes(const DesiredTrack &desiredTrack, AudioTrackBinding &binding);
//   std::vector<AudioTimelineClipRef> buildClipRefsForTrack(int trackIndex) const;
//
//   size_t renderTrackAudioInternal(const AudioTrackBinding &track,
//                                   int64_t timelineSample,
//                                   size_t numFrames,
//                                   float **outputChannels,
//                                   size_t channelCount) noexcept;
//   size_t renderSingleClip(const AudioTimelineClipRef &clip,
//                           int64_t blockStart,
//                           int64_t blockEnd,
//                           float **outputChannels,
//                           size_t channelCount) noexcept;
//   std::shared_ptr<AudioClipBuffer> tryGetCachedBuffer(const std::string &assetId) noexcept;
//   const AudioTrackBinding *findBindingById(const std::string &trackId) const noexcept;
//   const AudioTrackBinding *findBindingByIndex(int trackIndex) const noexcept;
// };
//
// } // namespace xyla::audio
//
//
//




#pragma once

#include "audioClipBuffer.hpp"
#include "core/audio/decoder/audioDecoder.hpp"
#include "core/audio/nodes/clipSourceNode.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"
#include "core/audio/dsp/clipAudioProcessor.hpp"
#include <QObject>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace xyla {
class TimelineModel;
class MediaPool;
} // namespace xyla

namespace xyla::audio {

/**
 * @class AudioTimelineManager
 * @brief Coordinates synchronization between Qt UI TimelineModel and the real-time AudioEngine.
 *
 * ARCHITECTURAL ROLE:
 * - Bridges the asynchronous Qt GUI thread (user timeline manipulations, clip trims, track additions)
 *   with the high-priority real-time audio thread running inside the AudioEngine graph.
 * - Manages an in-memory cache of decoded PCM audio assets (m_assetCache).
 * - Reconciles and recompiles the AudioEngine graph when tracks or clips change.
 *
 * THREAD SAFETY & CONCURRENCY CONTRACT:
 * - GUI / Worker Thread Operations:
 *   - Methods such as bindTimelineModel(), syncTracksFromModel(), loadAssetAudio(),
 *     and updateClipAudioParams() run on the UI/worker thread and acquire m_tracksMutex
 *     or m_cacheMutex using blocking locks (std::lock_guard).
 * - Real-Time Audio Thread Operations:
 *   - Real-time render callbacks (readTrackAudio() and readTrackAudioById()) are invoked by
 *     ClipSourceNode directly on the OS audio rendering thread.
 *   - To prevent priority inversion and avoid blocking the audio callback (which causes audible
 *     glitches/buffer underruns), these functions use non-blocking try_lock(). If a lock cannot
 *     be immediately acquired, the function returns 0 frames and outputs silence instantly.
 *
 * MEMORY ALLOCATION CONSTRAINTS:
 * - All audio thread rendering paths are strictly marked noexcept and avoid dynamic heap
 *   allocations (zero new, malloc, or container resizing).
 *
 * TIMEBASE ALIGNMENT:
 * - Timeline UI coordinates operate in visual video frames at m_projectFps (e.g. 24, 29.97, 30, 60).
 * - DSP audio rendering operates in PCM samples at m_sampleRate (e.g. 48000 Hz, 44100 Hz).
 * - Time conversion formulas:
 *     samples = frames * (sampleRate / fps)
 *     frames  = samples * (fps / sampleRate)
 */
class AudioTimelineManager : public QObject {
  Q_OBJECT

public:
  /**
   * @brief Returns the global singleton instance.
   */
  static AudioTimelineManager &instance();

  /**
   * @brief Updates real-time audio parameters for a specific clip without triggering a full graph rebuild.
   *
   * Thread-safe: Acquires m_tracksMutex briefly to update parameters in place.
   *
   * @param clipId Unique timeline clip identifier.
   * @param volume Linear volume gain factor (>= 0.0f).
   * @param pan Stereo balance (-1.0f = full Left, 0.0f = Center, +1.0f = full Right).
   * @param channelMode Channel routing mode (0: Stereo, 1: Mono Left, 2: Mono Right, 3: Mute).
   * @param isMuted True if clip should be muted.
   */
  void updateClipAudioParams(const std::string &clipId, float volume, float pan,
                             int channelMode, bool isMuted);

  explicit AudioTimelineManager(QObject *parent = nullptr);
  ~AudioTimelineManager() override = default;

  // Prevent copy and assignment for singleton
  AudioTimelineManager(const AudioTimelineManager &) = delete;
  AudioTimelineManager &operator=(const AudioTimelineManager &) = delete;

  /**
   * @brief Real-time audio rendering callback resolving tracks by stable, persistent trackId.
   *
   * Invoked on the real-time audio thread by ClipSourceNode.
   * Resilient to track reordering in the UI because lookup uses the immutable trackId.
   *
   * @param trackId Unique persistent identifier of the track.
   * @param timelineSample Starting playhead position in PCM samples.
   * @param numFrames Number of audio frames requested for this buffer slice.
   * @param outputChannels De-interleaved channel buffers [channelCount][numFrames].
   * @param channelCount Number of audio channels (typically 2 for stereo).
   * @return Actual number of audio frames written to the output slice.
   */
  size_t readTrackAudioById(const std::string &trackId, int64_t timelineSample,
                            size_t numFrames, float **outputChannels,
                            size_t channelCount) noexcept;

  /**
   * @brief Binds Qt TimelineModel and MediaPool signals to automatically synchronize changes.
   *
   * Connects Qt signals (dataChanged, rowsInserted, rowsRemoved, modelReset) so any
   * edit in the timeline model triggers syncTracksFromModel().
   *
   * @param model Pointer to the active Qt TimelineModel.
   * @param mediaPool Pointer to the MediaPool containing media asset definitions.
   */
  void bindTimelineModel(TimelineModel *model, MediaPool *mediaPool);

  /**
   * @brief Pre-decodes and caches an audio file from disk into memory.
   *
   * Caches decoded PCM data in m_assetCache indexed by assetId and registers waveform peaks.
   *
   * @param assetId Unique media asset identifier.
   * @param filePath Absolute path to media file on local storage.
   * @return Shared pointer to the decoded AudioClipBuffer, or nullptr on failure.
   */
  std::shared_ptr<AudioClipBuffer> loadAssetAudio(const std::string &assetId,
                                                  const std::string &filePath);

  /**
   * @brief Retrieves a decoded audio buffer from cache if already loaded.
   *
   * Thread-safe: Protected by m_cacheMutex.
   *
   * @param assetId Unique media asset identifier.
   * @return Shared pointer to the cached AudioClipBuffer, or nullptr if not present.
   */
  [[nodiscard]] std::shared_ptr<AudioClipBuffer>
  getClipBuffer(const std::string &assetId) const;

  /**
   * @brief Reconciles AudioEngine graph nodes and active clips with the Qt TimelineModel state.
   *
   * Executes on the GUI thread when clips are added, moved, or trimmed.
   * Modularized into 5 distinct pipeline stages:
   * 1. updateProjectFpsFromModel()    - Queries project FPS and sample rate.
   * 2. collectDesiredAudioTracks()   - Scans TimelineModel for enabled audio tracks.
   * 3. pruneObsoleteEngineTracks()   - Destroys nodes for deleted tracks.
   * 4. setupTrackAudioNodes()        - Instantiates & routes MixerTrackNode/ClipSourceNode.
   * 5. buildClipRefsForTrack()       - Converts clips from frames to samples with in/out trims.
   */
  void syncTracksFromModel();

  /**
   * @brief Real-time audio callback invoked by ClipSourceNode on the audio thread by index.
   *
   * Non-blocking and noexcept. Delegates internally to renderTrackAudioInternal().
   *
   * @param trackIndex Zero-based visual index of the track.
   * @param timelineSample Starting playhead position in PCM samples.
   * @param numFrames Number of audio frames requested.
   * @param outputChannels De-interleaved channel buffers [channelCount][numFrames].
   * @param channelCount Number of audio channels.
   * @return Actual number of audio frames written.
   */
  size_t readTrackAudio(int trackIndex, int64_t timelineSample,
                        size_t numFrames, float **outputChannels,
                        size_t channelCount) noexcept;

private:
  TimelineModel *m_timelineModel{nullptr};    ///< Borrowed pointer to active UI timeline model
  MediaPool *m_mediaPool{nullptr};            ///< Borrowed pointer to active media pool

  // Decoded audio cache (AssetId -> PCM Buffer)
  mutable std::mutex m_cacheMutex;            ///< Protects m_assetCache map insertions and lookups
  std::unordered_map<std::string, std::shared_ptr<AudioClipBuffer>>
      m_assetCache;

  // Track state accessed by audio thread (Double-buffered / Mutex protected)
  std::mutex m_tracksMutex;                   ///< Protects m_trackBindings across UI updates and audio render
  std::vector<AudioTrackBinding> m_trackBindings;

  double m_projectFps{30.0};                  ///< Project frame rate for timeline frame-to-sample scaling
  uint32_t m_sampleRate{48000};               ///< Audio sampling frequency in Hz (typically 48000)

  // ------------------------------------------------------------------
  // Modular Internal Helpers (Decomposed sync and unified audio rendering)
  // ------------------------------------------------------------------
  struct DesiredTrack {
    int index = -1;
    std::string trackId;
    std::string name;
  };

  /**
   * @brief Synchronizes project FPS and audio sample rate from active project settings.
   */
  void updateProjectFpsFromModel();

  /**
   * @brief Iterates TimelineModel rows to extract valid audio tracks.
   */
  std::vector<DesiredTrack> collectDesiredAudioTracks(
      std::unordered_set<std::string> &outLiveTrackIds,
      std::unordered_set<std::string> &outLiveSourceIds) const;

  /**
   * @brief Removes audio graph nodes from AudioEngine for tracks that were deleted in UI.
   */
  void pruneObsoleteEngineTracks(const std::unordered_set<std::string> &liveTrackIds);

  /**
   * @brief Configures or creates MixerTrackNode and ClipSourceNode in AudioEngine for a track.
   */
  void setupTrackAudioNodes(const DesiredTrack &desiredTrack, AudioTrackBinding &binding);

  /**
   * @brief Converts track clip items from TimelineModel frame units into audio sample coordinates.
   */
  std::vector<AudioTimelineClipRef> buildClipRefsForTrack(int trackIndex) const;

  /**
   * @brief Core real-time rendering loop. Iterates track clips and mixes overlapping audio slices.
   */
  size_t renderTrackAudioInternal(const AudioTrackBinding &track,
                                  int64_t timelineSample,
                                  size_t numFrames,
                                  float **outputChannels,
                                  size_t channelCount) noexcept;

  /**
   * @brief Calculates overlap window, fetches decoded PCM frames, and applies stereo DSP pan/gain.
   */
  size_t renderSingleClip(const AudioTimelineClipRef &clip,
                          int64_t blockStart,
                          int64_t blockEnd,
                          float **outputChannels,
                          size_t channelCount) noexcept;

  /**
   * @brief Safely retrieves a cached audio buffer using non-blocking try_lock on audio thread.
   */
  std::shared_ptr<AudioClipBuffer> tryGetCachedBuffer(const std::string &assetId) noexcept;

  /**
   * @brief Helper to locate a track binding by persistent trackId.
   */
  const AudioTrackBinding *findBindingById(const std::string &trackId) const noexcept;

  /**
   * @brief Helper to locate a track binding by visual trackIndex.
   */
  const AudioTrackBinding *findBindingByIndex(int trackIndex) const noexcept;
};

} // namespace xyla::audio
