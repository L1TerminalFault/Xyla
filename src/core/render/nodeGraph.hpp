#pragma once

/* =============================================================================
 * XYLA NODE GRAPH INTERFACE
 * -----------------------------------------------------------------------------
 * WHAT THIS FILE DOES:
 * 1. Declares NodeGraph as an independent, identifiable entity with:
 *    - `id()` (QString) and `name()` (QString)
 *    - `isReadOnly()` flag (to protect the immutable default In/Out graph)
 * 2. Provides `serialize()` and `deserialize()` to/from QJsonObject.
 * 3. Manages nodes, links, cycle detection, execution ordering, and shader compilation.
 * ============================================================================= */

#include "node.hpp"
#include "nodeSocket.hpp"
#include <QJsonObject>
#include <QJsonArray>
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
  NodeGraph();
  explicit NodeGraph(QString graphId, QString name = "Default Graph");
  ~NodeGraph() = default;

  // --- Graph Identity ---
  [[nodiscard]] const QString &id() const noexcept { return m_graphId; }
  void setId(const QString &id) { m_graphId = id; }

  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  void setName(const QString &name) { m_name = name; }

  [[nodiscard]] bool isReadOnly() const noexcept { return m_isReadOnly; }
  void setReadOnly(bool ro) noexcept { m_isReadOnly = ro; }

  // --- Node & Link Operations ---
  void addNode(std::shared_ptr<Node> node);
  bool removeNode(const QString &nodeId);
  [[nodiscard]] std::shared_ptr<Node> findNode(const QString &nodeId) const;
  [[nodiscard]] const std::vector<std::shared_ptr<Node>> &nodes() const noexcept {
    return m_nodes;
  }
  [[nodiscard]] const std::vector<NodeLink> &links() const noexcept {
    return m_links;
  }

  bool connectSockets(const QString &fromNode, const QString &fromSocket,
                      const QString &toNode, const QString &toSocket);
  bool disconnectSockets(const QString &fromNode, const QString &fromSocket,
                         const QString &toNode, const QString &toSocket);

  // --- Compilation ---
  [[nodiscard]] std::vector<std::shared_ptr<Node>> compileExecutionSequence() const;
  [[nodiscard]] CompiledGraphShader compileFusedShader() const;
  void markDirty() noexcept { m_shaderDirty = true; }

  // --- Serialization & Deserialization ---
  [[nodiscard]] QJsonObject serialize() const;
  bool deserialize(const QJsonObject &json);

  // --- UI / QML Inspection ---
  [[nodiscard]] QVariantMap extractDefaultProperties() const;
  [[nodiscard]] QVariantList listEditorNodes() const;
  [[nodiscard]] QString defaultEditorNodeId() const;
  [[nodiscard]] QVariantList toVariantList() const;
  [[nodiscard]] QVariantList linksToVariantList() const;

  // --- Default Factory ---
  static std::shared_ptr<NodeGraph> createDefaultClipGraph(const QString &assetId);

private:
  [[nodiscard]] bool wouldIntroduceCycle(const QString &fromNode,
                                         const QString &toNode) const;

  QString m_graphId;
  QString m_name;
  bool m_isReadOnly{false};

  std::vector<std::shared_ptr<Node>> m_nodes;
  std::vector<NodeLink> m_links;
  mutable bool m_shaderDirty{true};
  mutable CompiledGraphShader m_cachedCompiledShader;
};

} // namespace xyla::render
