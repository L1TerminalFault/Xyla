#pragma once

#include "node.hpp"
#include "nodeSocket.hpp"
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <vector>

namespace xyla::render {

struct PushConstantMember {
  QString nodeId;
  QString propertyKey;
  QString fullKey;
  uint32_t offsetBytes{0};
  uint32_t sizeBytes{0};
  SocketDataType dataType{SocketDataType::Float};
  SocketValue defaultValue;
};

struct PushConstantLayout {
  uint32_t totalSizeBytes{0};
  std::vector<PushConstantMember> members;
};

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
  [[nodiscard]] const std::vector<std::shared_ptr<Node>> &
  nodes() const noexcept {
    return m_nodes;
  }
  [[nodiscard]] const std::vector<NodeLink> &links() const noexcept {
    return m_links;
  }

  bool connectSockets(const QString &fromNode, const QString &fromSocket,
                      const QString &toNode, const QString &toSocket);
  bool disconnectSockets(const QString &fromNode, const QString &fromSocket,
                         const QString &toNode, const QString &toSocket);

  [[nodiscard]] std::vector<std::shared_ptr<Node>>
  compileExecutionSequence() const;
  [[nodiscard]] CompiledGraphShader compileFusedShader() const;
  void markDirty() noexcept { m_shaderDirty = true; }

  [[nodiscard]] QVariantMap extractDefaultProperties() const;
  [[nodiscard]] QVariantList listEditorNodes() const;
  [[nodiscard]] QString defaultEditorNodeId() const;

  [[nodiscard]] QVariantList toVariantList() const;
  [[nodiscard]] QVariantList linksToVariantList() const;

  static std::shared_ptr<NodeGraph>
  createDefaultClipGraph(const QString &assetId);

private:
  [[nodiscard]] bool wouldIntroduceCycle(const QString &fromNode,
                                         const QString &toNode) const;

  std::vector<std::shared_ptr<Node>> m_nodes;
  std::vector<NodeLink> m_links;
  mutable bool m_shaderDirty{true};
  mutable CompiledGraphShader m_cachedCompiledShader;
};

} // namespace xyla::render
