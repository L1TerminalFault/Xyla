#include "audioGraph.hpp"
#include <algorithm>
#include <cmath>
#include <unordered_map>

namespace xyla::audio {

AudioGraph::AudioGraph() {
  m_activeSchedule.store(nullptr, std::memory_order_relaxed);
}

AudioGraph::~AudioGraph() {
  auto *old = m_activeSchedule.exchange(nullptr, std::memory_order_acq_rel);
  delete old;
}

AudioNode *AudioGraph::findNode(const std::string &nodeId) const {
  for (const auto &n : m_nodes) {
    if (n && n->nodeId() == nodeId) {
      return n.get();
    }
  }
  return nullptr;
}

bool AudioGraph::connect(const std::string &srcNodeId,
                         const std::string &srcPinId,
                         const std::string &dstNodeId,
                         const std::string &dstPinId) {
  return AudioGraphTopology::addConnection(
      m_connections, GraphConnection{srcNodeId, srcPinId, dstNodeId, dstPinId});
}

bool AudioGraph::disconnect(const std::string &srcNodeId,
                            const std::string &srcPinId,
                            const std::string &dstNodeId,
                            const std::string &dstPinId) {
  return AudioGraphTopology::removeConnection(
      m_connections, GraphConnection{srcNodeId, srcPinId, dstNodeId, dstPinId});
}

void AudioGraph::disconnectAll(const std::string &nodeId) {
  AudioGraphTopology::disconnectAllNodePins(m_connections, nodeId);
}

bool AudioGraph::removeNode(const std::string &nodeId) {
  // Protected Master Node check
  if (m_masterNode && m_masterNode->nodeId() == nodeId) {
    return false;
  }

  auto it = std::find_if(m_nodes.begin(), m_nodes.end(),
                         [&](const std::unique_ptr<AudioNode> &n) {
                           return n && n->nodeId() == nodeId;
                         });
  if (it == m_nodes.end()) {
    return false;
  }

  // Cascade remove all incoming & outgoing pin connections
  disconnectAll(nodeId);

  // Destroy node instance
  m_nodes.erase(it);
  return true;
}

bool AudioGraph::compile(uint32_t sampleRate, size_t blockSize) {
  auto newSchedule = std::make_unique<CompiledAudioGraph>();
  newSchedule->sampleRate = sampleRate;
  newSchedule->blockSize = blockSize;
  newSchedule->masterNode = m_masterNode;

  // Collect all valid node IDs
  std::vector<std::string> nodeIds;
  nodeIds.reserve(m_nodes.size());
  for (const auto &n : m_nodes) {
    if (n)
      nodeIds.push_back(n->nodeId());
  }

  // Use our decoupled topological sorting engine
  const auto sortedOrder =
      AudioGraphTopology::computeTopologicalOrder(nodeIds, m_connections);

  for (const auto &id : sortedOrder) {
    AudioNode *node = findNode(id);
    if (node) {
      ExecutionStep step;
      step.node = node;
      newSchedule->steps.push_back(step);
    }
  }

  // Atomic pointer exchange: real-time safe schedule swap
  CompiledAudioGraph *compiledPtr = newSchedule.release();
  CompiledAudioGraph *oldPtr =
      m_activeSchedule.exchange(compiledPtr, std::memory_order_acq_rel);
  delete oldPtr;

  return true;
}

void AudioGraph::process(AudioBuffer &hardwareOutput,
                         const AudioClockInfo &clock,
                         AudioBufferPool &pool) noexcept {
  CompiledAudioGraph *schedule =
      m_activeSchedule.load(std::memory_order_acquire);
  if (!schedule || schedule->steps.empty()) {
    hardwareOutput.clear();
    return;
  }

  ProcessContext ctx{clock, pool, clock.bufferSizeFrames};
  std::unordered_map<AudioNode *, AudioBuffer *> nodeOutputBuffers;

  for (auto &step : schedule->steps) {
    if (!step.node)
      continue;

    AudioBuffer *outBuf = pool.acquireBuffer();
    if (!outBuf)
      break;
    nodeOutputBuffers[step.node] = outBuf;

    AudioBuffer *inBuf = pool.acquireBuffer();
    if (inBuf) {
      size_t incomingConnections = 0;
      for (const auto &conn : m_connections) {
        if (conn.dstNodeId == step.node->nodeId()) {
          incomingConnections++;
        }
      }

      // Equal-power 1/sqrt(N) fan-in mix gain
      const float mixGain =
          (incomingConnections > 1)
              ? (1.0f / std::sqrt(static_cast<float>(incomingConnections)))
              : 1.0f;

      for (const auto &conn : m_connections) {
        if (conn.dstNodeId == step.node->nodeId()) {
          AudioNode *srcNode = findNode(conn.srcNodeId);
          if (srcNode && nodeOutputBuffers.count(srcNode)) {
            inBuf->accumulate(*nodeOutputBuffers[srcNode], mixGain);
          }
        }
      }
    }

    const AudioBuffer *inputList[1] = {inBuf};
    AudioBuffer *outputList[1] = {outBuf};
    step.node->process(inBuf ? inputList : nullptr, inBuf ? 1 : 0, outputList,
                       1, ctx);

    if (inBuf) {
      pool.releaseBuffer(inBuf);
    }
  }

  if (m_masterNode && nodeOutputBuffers.count(m_masterNode)) {
    hardwareOutput.copyFrom(*nodeOutputBuffers[m_masterNode]);
  } else {
    hardwareOutput.clear();
  }

  for (auto &[node, buf] : nodeOutputBuffers) {
    pool.releaseBuffer(buf);
  }
}

} // namespace xyla::audio
