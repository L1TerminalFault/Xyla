#pragma once

#include "node.hpp"
#include <memory>
#include <vector>

namespace xyla::render {
// core node graph connections are written here reader :)

// link connecting an Output socket to an Input socket
struct NodeLink {
  QString fromNodeId;
  QString fromSocketId;
  QString toNodeId;
  QString toSocketId;

  [[nodiscard]] bool operator==(const NodeLink &other) const noexcept {
    return fromNodeId == other.fromNodeId &&
           fromSocketId == other.fromSocketId && toNodeId == other.toNodeId &&
           toSocketId == other.toSocketId;
  }
};

// Memory layout metadata for Vulkan Push Constants
struct PushConstantMember {
  QString nodeId;
  QString propertyKey;
  uint32_t offsetBytes{0};
  uint32_t sizeBytes{0};
  SocketDataType dataType;
};

struct PushConstantLayout {
  uint32_t totalSizeBytes{0};
  std::vector<PushConstantMember> members;
};

// Compiled result ready for background SPIR-V compilation
struct CompiledGraphShader {
  QString glslSource;
  PushConstantLayout pushConstants;
  bool hasTemporalOffset{false};
};

class NodeGraph {
public:
  NodeGraph() = default;
  ~NodeGraph() = default;

  void addNode(std::shared_ptr<Node> node);
  bool removeNode(const QString &nodeId);
  [[nodiscard]] std::shared_ptr<Node> findNode(const QString &nodeId) const;

  // Connection Management
  bool connectSockets(const QString &fromNode, const QString &fromSocket,
                      const QString &toNode, const QString &toSocket);
  bool disconnectSockets(const QString &fromNode, const QString &fromSocket,
                         const QString &toNode, const QString &toSocket);

  [[nodiscard]] const std::vector<std::shared_ptr<Node>> &
  nodes() const noexcept {
    return m_nodes;
  }
  [[nodiscard]] const std::vector<NodeLink> &links() const noexcept {
    return m_links;
  }

  // Kahns Topological Sort Algorithm
  [[nodiscard]] std::vector<std::shared_ptr<Node>>
  compileExecutionSequence() const;

  [[nodiscard]] CompiledGraphShader compileFusedShader() const;

  static std::shared_ptr<NodeGraph>
  createDefaultClipGraph(const QString &assetId);

private:
  std::vector<std::shared_ptr<Node>> m_nodes;
  std::vector<NodeLink> m_links;
};
} // namespace xyla::render
