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

  disconnectAll(nodeId);
  m_nodes.erase(it);
  return true;
}

bool AudioGraph::compile(uint32_t sampleRate, size_t blockSize) {
  auto newSchedule = std::make_unique<CompiledAudioGraph>();
  newSchedule->sampleRate = sampleRate;
  newSchedule->blockSize = blockSize;
  newSchedule->masterNode = m_masterNode;

  std::vector<std::string> nodeIds;
  nodeIds.reserve(m_nodes.size());
  for (const auto &n : m_nodes) {
    if (n)
      nodeIds.push_back(n->nodeId());
  }

  const auto sortedOrder =
      AudioGraphTopology::computeTopologicalOrder(nodeIds, m_connections);

  for (const auto &id : sortedOrder) {
    AudioNode *node = findNode(id);
    if (!node)
      continue;

    ExecutionStep step;
    step.node = node;

    std::vector<AudioNode *> sources;
    for (const auto &conn : m_connections) {
      if (conn.dstNodeId == id) {
        if (AudioNode *src = findNode(conn.srcNodeId)) {
          sources.push_back(src);
        }
      }
    }

    const float mixGain =
        (sources.size() > 1)
            ? (1.0f / std::sqrt(static_cast<float>(sources.size())))
            : 1.0f;

    for (AudioNode *src : sources) {
      step.inputSources.push_back(NodeInputSource{src, mixGain});
    }

    newSchedule->steps.push_back(std::move(step));
  }

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

    AudioBuffer *inBuf = nullptr;
    if (!step.inputSources.empty()) {
      inBuf = pool.acquireBuffer();
      if (inBuf) {
        for (const auto &source : step.inputSources) {
          if (auto it = nodeOutputBuffers.find(source.sourceNode);
              it != nodeOutputBuffers.end()) {
            inBuf->accumulate(*it->second, source.gain);
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

  if (schedule->masterNode &&
      nodeOutputBuffers.contains(schedule->masterNode)) {
    hardwareOutput.copyFrom(*nodeOutputBuffers[schedule->masterNode]);
  } else {
    hardwareOutput.clear();
  }

  for (auto &[_, buf] : nodeOutputBuffers) {
    pool.releaseBuffer(buf);
  }
}

} // namespace xyla::audio
