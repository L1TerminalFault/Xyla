#pragma once

#include "audioNode.hpp"
#include "core/audio/types/audioBuffer.hpp"
#include <vector>

namespace xyla::audio {

/**
 * @brief Raw buffer transfer instruction between nodes.
 * Uses pre-resolved raw pointers so the audio thread does zero lookups.
 */
struct BufferTransfer {
  const AudioBuffer *srcBuffer{nullptr};
  AudioBuffer *dstBuffer{nullptr};
  float gain{1.0f};
};

/**
 * @brief Represents one node execution step in the topologically sorted
 * schedule.
 */
struct ExecutionStep {
  AudioNode *node{nullptr};

  // Pre-resolved pointers for node inputs and outputs
  std::vector<const AudioBuffer *> inputs;
  std::vector<AudioBuffer *> outputs;

  // Transfers to sum into downstream nodes after this step completes
  std::vector<BufferTransfer> outgoingTransfers;
};

/**
 * @brief Immutable, cache-contiguous execution schedule for the real-time audio
 * thread.
 */
class CompiledAudioGraph {
public:
  CompiledAudioGraph() = default;
  ~CompiledAudioGraph() = default;

  CompiledAudioGraph(const CompiledAudioGraph &) = delete;
  CompiledAudioGraph &operator=(const CompiledAudioGraph &) = delete;

  std::vector<ExecutionStep> steps;
  AudioNode *masterNode{nullptr};
  AudioBuffer *masterOutputBuffer{nullptr};
  size_t blockSize{256};
  uint32_t sampleRate{48000};
};

} // namespace xyla::audio
