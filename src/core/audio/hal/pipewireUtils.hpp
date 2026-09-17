#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <string>

namespace xyla::audio::hal {

/**
 * @brief Pure helper functions for PipeWire audio stream formatting and buffer
 * conversion.
 */
struct PipeWireUtils {
  /**
   * @brief Generates standard PipeWire node latency string (e.g. "256/48000")
   * to lock hardware quantum.
   */
  static std::string formatLatencyString(uint32_t bufferSizeFrames,
                                         uint32_t sampleRate) {
    if (sampleRate == 0)
      sampleRate = 48000;
    return std::to_string(bufferSizeFrames) + "/" + std::to_string(sampleRate);
  }

  /**
   * @brief Interleaves planar float channels into a packed stereo/multi-channel
   * destination buffer. Guaranteed zero allocations, real-time safe.
   */
  static void interleavePlanarToPacked(const float *const *sourceChannels,
                                       size_t channelCount,
                                       float *dstInterleaved,
                                       size_t frameCount) noexcept {
    if (!dstInterleaved || !sourceChannels || frameCount == 0 ||
        channelCount == 0) {
      return;
    }

    const float *srcL = sourceChannels[0];
    const float *srcR =
        (channelCount > 1 && sourceChannels[1]) ? sourceChannels[1] : srcL;

    if (channelCount == 2) {
      for (size_t i = 0; i < frameCount; ++i) {
        dstInterleaved[i * 2 + 0] = srcL[i];
        dstInterleaved[i * 2 + 1] = srcR[i];
      }
    } else if (channelCount == 1) {
      std::copy_n(srcL, frameCount, dstInterleaved);
    } else {
      // General N-channel interleaving
      for (size_t i = 0; i < frameCount; ++i) {
        for (size_t c = 0; c < channelCount; ++c) {
          dstInterleaved[i * channelCount + c] =
              sourceChannels[c] ? sourceChannels[c][i] : 0.0f;
        }
      }
    }
  }
};

} // namespace xyla::audio::hal
