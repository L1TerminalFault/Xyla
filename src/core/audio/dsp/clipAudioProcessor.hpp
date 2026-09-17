/**
 * @file clipAudioProcessor.hpp
 * @brief Standalone, real-time safe audio DSP calculations and window helpers for timeline clips.
 * 
 * Separating this module eliminates massive code duplication between readTrackAudio()
 * and readTrackAudioById(), isolates pure math/DSP from Qt/graph logic, and allows
 * deterministic unit testing of volume, pan law, channel remapping, and overlap math.
 */

#pragma once

#include "core/audio/nodes/mixerTrackNode.hpp"
#include "core/audio/nodes/clipSourceNode.hpp"
#include <algorithm>
#include <cstddef>
#include <cstdint>

namespace xyla::audio {

/**
 * @brief Channel routing modes for timeline clips.
 */
enum class ChannelMode : int {
    Stereo    = 0,  ///< Standard 2-channel stereo pass-through
    MonoLeft  = 1,  ///< Duplicate Left channel onto Right (Left channel as dual-mono)
    MonoRight = 2,  ///< Duplicate Right channel onto Left (Right channel as dual-mono)
    Mute      = 3   ///< Silence/Muted
};

/**
 * @brief Lightweight audio parameter snapshot for real-time DSP execution.
 */
struct ClipDspParams {
    float volume = 1.0f;        ///< Linear gain multiplier [0.0, ...]
    float pan = 0.0f;           ///< Stereo pan from -1.0 (hard left) to +1.0 (hard right)
    int channelMode = 0;        ///< Corresponds to ChannelMode enum
    bool isMuted = false;       ///< Explicit mute toggle
};

/**
 * @brief Reference to an audio clip positioned on the timeline in sample units.
 *
 * Translates UI/TimelineModel frame coordinates (FPS-based) into absolute PCM sample
 * positions (sampleRate-based) for sample-accurate scheduling on the audio render thread.
 */
struct AudioTimelineClipRef {
  std::string clipId;            ///< Unique identifier of the timeline clip item
  std::string assetId;           ///< Key referencing the decoded PCM buffer in m_assetCache
  int64_t startSample{0};        ///< Timeline position where clip playback starts (in samples)
  int64_t durationSamples{0};    ///< Active playback duration on timeline (in samples)
  int64_t sourceInSample{0};     ///< Start trim offset within source media asset (in samples)

  float volume{1.0f};            ///< Static gain multiplier [0.0, ...]
  float pan{0.0f};               ///< Stereo pan position [-1.0 = hard Left, 0.0 = Center, +1.0 = hard Right]
  int channelMode{0};            ///< Routing: 0 = Stereo, 1 = Mono Left, 2 = Mono Right, 3 = Mute
  bool isMuted{false};           ///< Explicit clip mute flag
};

/**
 * @brief Represents an active audio track binding connecting the UI model to the AudioEngine graph.
 *
 * Each binding pairs a TimelineModel track with a MixerTrackNode (gain/pan/summing bus)
 * and a ClipSourceNode (PCM reader provider callback) in the real-time audio graph.
 */
struct AudioTrackBinding {
  int trackIndex{0};                         ///< Current UI visual index (may shift on reorder)
  std::string trackId;                       ///< Persistent, immutable track identifier
  MixerTrackNode *mixerNode{nullptr};        ///< Target mixer node in the audio graph
  ClipSourceNode *sourceNode{nullptr};       ///< Source generator node invoking PCM read callbacks
  std::vector<AudioTimelineClipRef> clips;   ///< Snapshot of clips placed on this track
};

/**
 * @brief Calculates sample-accurate intersection windows between an audio engine render block
 *        and an individual timeline clip.
 */
struct ClipOverlapWindow {
    bool hasOverlap = false;    ///< True if block and clip intersect
    int64_t overlapStart = 0;   ///< Absolute timeline sample where rendering begins
    int64_t overlapEnd = 0;     ///< Absolute timeline sample where rendering ends
    size_t overlapFrames = 0;   ///< Total frame count to decode/render
    int64_t bufferOffset = 0;   ///< Start sample offset inside the source AudioClipBuffer
    size_t destOffset = 0;      ///< Frame offset inside the engine render block's output array

    /**
     * @brief Computes window overlap coordinates.
     * 
     * @param blockStart Start timeline sample of audio buffer callback
     * @param blockEnd End timeline sample of audio buffer callback (exclusive)
     * @param clipStart Timeline start sample of the clip
     * @param clipDuration Total length of the clip in samples
     * @param clipSourceIn Sample offset in the source asset where playback starts (trim in-point)
     * @return ClipOverlapWindow Computed coordinates and offsets
     */
    static inline ClipOverlapWindow compute(int64_t blockStart, int64_t blockEnd,
                                            int64_t clipStart, int64_t clipDuration,
                                            int64_t clipSourceIn) noexcept {
        ClipOverlapWindow window;
        const int64_t clipEnd = clipStart + clipDuration;

        // Fast rejection check: render block is completely outside clip range
        if (blockEnd <= clipStart || blockStart >= clipEnd) {
            window.hasOverlap = false;
            return window;
        }

        window.hasOverlap = true;
        window.overlapStart = std::max(blockStart, clipStart);
        window.overlapEnd = std::min(blockEnd, clipEnd);
        window.overlapFrames = static_cast<size_t>(window.overlapEnd - window.overlapStart);

        // Account for timeline position relative to clip start, plus the user's source trim in-point
        window.bufferOffset = (window.overlapStart - clipStart) + clipSourceIn;

        // Destination offset inside the caller's output channel buffer
        window.destOffset = static_cast<size_t>(window.overlapStart - blockStart);

        return window;
    }
};

namespace dsp {

    /**
     * @brief Applies channel mode remapping, volume gain, and linear stereo pan law in-place.
     * 
     * @note Designed for the real-time audio thread:
     *       - strictly noexcept
     *       - 0 dynamic allocations
     *       - bounds checked against max 16 audio channels
     * 
     * @param sliceOutputs Array of float pointers pointing to destination channel buffers
     * @param channelCount Number of audio channels in the buffer
     * @param framesRead Number of audio frames read from the clip buffer
     * @param params Audio volume, pan, channel mode, and mute settings
     */
    inline void applyClipDsp(float **sliceOutputs, size_t channelCount, size_t framesRead,
                             const ClipDspParams &params) noexcept {
        if (framesRead == 0 || sliceOutputs == nullptr || channelCount == 0) {
            return;
        }

        // ------------------------------------------------------------------
        // 1. Check Mute / Silence conditions
        // If muted or volume is essentially zero, zero-fill all valid channels
        // ------------------------------------------------------------------
        if (params.isMuted || 
            params.channelMode == static_cast<int>(ChannelMode::Mute) || 
            params.volume <= 0.0001f) {
            
            for (size_t c = 0; c < channelCount && c < 16; ++c) {
                if (sliceOutputs[c]) {
                    std::fill(sliceOutputs[c], sliceOutputs[c] + framesRead, 0.0f);
                }
            }
            return;
        }

        // ------------------------------------------------------------------
        // 2. Channel Mode Remapping & Pan Law
        // ------------------------------------------------------------------
        if (channelCount >= 2 && sliceOutputs[0] && sliceOutputs[1]) {
            float *left = sliceOutputs[0];
            float *right = sliceOutputs[1];

            // Channel remapping
            if (params.channelMode == static_cast<int>(ChannelMode::MonoLeft)) {
                // Mono Left: Copy left channel to right
                std::copy(left, left + framesRead, right);
            } else if (params.channelMode == static_cast<int>(ChannelMode::MonoRight)) {
                // Mono Right: Copy right channel to left
                std::copy(right, right + framesRead, left);
            }

            // 3. Apply Volume & Stereo Pan Law (-1.0 to +1.0)
            // Linear pan law:
            // Pan = -1.0 (Left):  gainL = vol * 1.0, gainR = vol * 0.0
            // Pan =  0.0 (Center):gainL = vol * 1.0, gainR = vol * 1.0
            // Pan = +1.0 (Right): gainL = vol * 0.0, gainR = vol * 1.0
            const float vol = params.volume;
            const float gainL = vol * (params.pan <= 0.0f ? 1.0f : (1.0f - params.pan));
            const float gainR = vol * (params.pan >= 0.0f ? 1.0f : (1.0f + params.pan));

            for (size_t i = 0; i < framesRead; ++i) {
                left[i] *= gainL;
                right[i] *= gainR;
            }

            // Scale any additional surround or auxiliary channels (ch 2..15) by master volume
            for (size_t c = 2; c < channelCount && c < 16; ++c) {
                if (float *ch = sliceOutputs[c]) {
                    for (size_t i = 0; i < framesRead; ++i) {
                        ch[i] *= vol;
                    }
                }
            }
        } else if (channelCount == 1 && sliceOutputs[0]) {
            // Single mono output channel
            float *mono = sliceOutputs[0];
            const float vol = params.volume;
            for (size_t i = 0; i < framesRead; ++i) {
                mono[i] *= vol;
            }
        }
    }

    /**
     * @brief Computes stereo left and right gains based on master volume and linear pan [-1.0, +1.0].
     */
    inline void computePanGains(float volume, float pan, float &outGainL, float &outGainR) noexcept {
        outGainL = volume * (pan <= 0.0f ? 1.0f : (1.0f - pan));
        outGainR = volume * (pan >= 0.0f ? 1.0f : (1.0f + pan));
    }

} // namespace dsp

/**
 * @brief Converts video timeline frame count to audio sample count.
 */
inline int64_t framesToSamples(int64_t frames, double fps, uint32_t sampleRate) noexcept {
    if (fps <= 0.0) return 0;
    return static_cast<int64_t>(static_cast<double>(frames) * (static_cast<double>(sampleRate) / fps));
}

/**
 * @brief Converts audio sample count to video timeline frame count.
 */
inline int64_t samplesToFrames(int64_t samples, double fps, uint32_t sampleRate) noexcept {
    if (sampleRate == 0) return 0;
    return static_cast<int64_t>(static_cast<double>(samples) * (fps / static_cast<double>(sampleRate)));
}

} // namespace xyla::audio
