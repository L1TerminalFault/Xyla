#pragma once

#include "audioGraphTopology.hpp"
#include "compiledAudioGraph.hpp"
#include "core/audio/nodes/audioNode.hpp"
#include "core/audio/types/audioBufferPool.hpp"
#include <atomic>
#include <memory>
#include <string>
#include <vector>

namespace xyla::audio {

class AudioGraph {
public:
  AudioGraph();
  ~AudioGraph();

  AudioGraph(const AudioGraph &) = delete;
  AudioGraph &operator=(const AudioGraph &) = delete;

  template <typename T, typename... Args>
  T *addNode(const std::string &nodeId, Args &&...args) {
    if (AudioNode *existing = findNode(nodeId)) {
      return dynamic_cast<T *>(existing);
    }
    auto node = std::make_unique<T>(nodeId, std::forward<Args>(args)...);
    T *ptr = node.get();
    m_nodes.push_back(std::move(node));
    return ptr;
  }

  [[nodiscard]] AudioNode *findNode(const std::string &nodeId) const;

  bool connect(const std::string &srcNodeId, const std::string &srcPinId,
               const std::string &dstNodeId, const std::string &dstPinId);

  bool disconnect(const std::string &srcNodeId, const std::string &srcPinId,
                  const std::string &dstNodeId, const std::string &dstPinId);

  void disconnectAll(const std::string &nodeId);

  bool removeNode(const std::string &nodeId);

  void setMasterNode(AudioNode *master) noexcept { m_masterNode = master; }
  [[nodiscard]] AudioNode *masterNode() const noexcept { return m_masterNode; }

  [[nodiscard]] const std::vector<std::unique_ptr<AudioNode>> &
  nodes() const noexcept {
    return m_nodes;
  }
  [[nodiscard]] const std::vector<GraphConnection> &
  connections() const noexcept {
    return m_connections;
  }

  bool compile(uint32_t sampleRate, size_t blockSize);

  void process(AudioBuffer &hardwareOutput, const AudioClockInfo &clock,
               AudioBufferPool &pool) noexcept;

private:
  std::vector<std::unique_ptr<AudioNode>> m_nodes;
  std::vector<GraphConnection> m_connections;
  AudioNode *m_masterNode{nullptr};
  std::atomic<CompiledAudioGraph *> m_activeSchedule{nullptr};
};

} // namespace xyla::audio
