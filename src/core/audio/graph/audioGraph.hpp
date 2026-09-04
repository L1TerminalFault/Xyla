#pragma once

#include "audioNode.hpp"
#include "compiledAudioGraph.hpp"
#include "core/audio/types/audioBufferPool.hpp"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <deque>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace xyla::audio {

struct GraphConnection {
  std::string srcNodeId;
  std::string srcPinId;
  std::string dstNodeId;
  std::string dstPinId;

  bool operator==(const GraphConnection &other) const noexcept {
    return srcNodeId == other.srcNodeId && srcPinId == other.srcPinId &&
           dstNodeId == other.dstNodeId && dstPinId == other.dstPinId;
  }
};

class AudioGraph {
public:
  AudioGraph() { m_activeSchedule.store(nullptr, std::memory_order_relaxed); }

  ~AudioGraph() {
    auto *old = m_activeSchedule.exchange(nullptr);
    delete old;
  }

  template <typename T, typename... Args>
  T *addNode(const std::string &nodeId, Args &&...args) {
    // Prevent duplicate IDs
    if (findNode(nodeId))
      return dynamic_cast<T *>(findNode(nodeId));

    auto node = std::make_unique<T>(nodeId, std::forward<Args>(args)...);
    T *ptr = node.get();
    m_nodes.push_back(std::move(node));
    return ptr;
  }

  AudioNode *findNode(const std::string &nodeId) const {
    for (const auto &n : m_nodes) {
      if (n->nodeId() == nodeId)
        return n.get();
    }
    return nullptr;
  }

  bool connect(const std::string &srcNodeId, const std::string &srcPinId,
               const std::string &dstNodeId, const std::string &dstPinId) {
    GraphConnection conn{srcNodeId, srcPinId, dstNodeId, dstPinId};
    if (std::find(m_connections.begin(), m_connections.end(), conn) ==
        m_connections.end()) {
      m_connections.push_back(conn);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------
  // NEW: remove a single connection
  // ------------------------------------------------------------------
  bool disconnect(const std::string &srcNodeId, const std::string &srcPinId,
                  const std::string &dstNodeId, const std::string &dstPinId) {
    GraphConnection target{srcNodeId, srcPinId, dstNodeId, dstPinId};
    auto it = std::remove(m_connections.begin(), m_connections.end(), target);
    if (it == m_connections.end())
      return false;
    m_connections.erase(it, m_connections.end());
    return true;
  }

  // ------------------------------------------------------------------
  // NEW: remove EVERY connection that touches this node (in or out)
  // ------------------------------------------------------------------
  void disconnectAll(const std::string &nodeId) {
    m_connections.erase(
        std::remove_if(m_connections.begin(), m_connections.end(),
                       [&](const GraphConnection &c) {
                         return c.srcNodeId == nodeId || c.dstNodeId == nodeId;
                       }),
        m_connections.end());
  }

  // ------------------------------------------------------------------
  // NEW: fully remove a node + all its connections
  // ------------------------------------------------------------------
  bool removeNode(const std::string &nodeId) {
    // Never allow removing the master
    if (m_masterNode && m_masterNode->nodeId() == nodeId)
      return false;

    auto it = std::find_if(m_nodes.begin(), m_nodes.end(),
                           [&](const std::unique_ptr<AudioNode> &n) {
                             return n->nodeId() == nodeId;
                           });
    if (it == m_nodes.end())
      return false;

    // Drop every connection that referenced this node
    disconnectAll(nodeId);

    // Destroy the node
    m_nodes.erase(it);
    return true;
  }

  void setMasterNode(AudioNode *master) { m_masterNode = master; }

  // ... compile() and process() stay exactly as you had them ...

  bool compile(uint32_t sampleRate, size_t blockSize) {
    // (unchanged)
    auto newSchedule = std::make_unique<CompiledAudioGraph>();
    newSchedule->sampleRate = sampleRate;
    newSchedule->blockSize = blockSize;
    newSchedule->masterNode = m_masterNode;

    std::map<AudioNode *, std::vector<AudioNode *>> adjList;
    std::map<AudioNode *, int> inDegree;
    for (const auto &n : m_nodes) {
      inDegree[n.get()] = 0;
    }
    for (const auto &c : m_connections) {
      AudioNode *src = findNode(c.srcNodeId);
      AudioNode *dst = findNode(c.dstNodeId);
      if (src && dst) {
        adjList[src].push_back(dst);
        inDegree[dst]++;
      }
    }

    std::deque<AudioNode *> queue;
    for (const auto &[node, deg] : inDegree) {
      if (deg == 0)
        queue.push_back(node);
    }

    std::vector<AudioNode *> sortedNodes;
    while (!queue.empty()) {
      AudioNode *u = queue.front();
      queue.pop_front();
      sortedNodes.push_back(u);
      for (AudioNode *v : adjList[u]) {
        if (--inDegree[v] == 0) {
          queue.push_back(v);
        }
      }
    }

    for (const auto &n : m_nodes) {
      if (std::find(sortedNodes.begin(), sortedNodes.end(), n.get()) ==
          sortedNodes.end()) {
        sortedNodes.push_back(n.get());
      }
    }

    for (AudioNode *node : sortedNodes) {
      ExecutionStep step;
      step.node = node;
      newSchedule->steps.push_back(step);
    }

    CompiledAudioGraph *compiledPtr = newSchedule.release();
    CompiledAudioGraph *oldPtr =
        m_activeSchedule.exchange(compiledPtr, std::memory_order_acq_rel);
    delete oldPtr;
    return true;
  }

  void process(AudioBuffer &hardwareOutput, const AudioClockInfo &clock,
               AudioBufferPool &pool) noexcept {
    // (unchanged – keep your existing implementation)
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
        float mixGain =
            incomingConnections > 1
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

private:
  std::vector<std::unique_ptr<AudioNode>> m_nodes;
  std::vector<GraphConnection> m_connections;
  AudioNode *m_masterNode{nullptr};
  std::atomic<CompiledAudioGraph *> m_activeSchedule{nullptr};
};
;

} // namespace xyla::audio
