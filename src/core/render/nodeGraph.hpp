#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/propertyHandle.hpp"
#include "node.hpp"
#include "nodeSocket.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>
#include <memory>
#include <unordered_map>
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
  anim::PropertyHandle handle;
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
  using NodeFactory = std::function<std::shared_ptr<Node>(const QString &id,
                                                          const QString &name)>;

  NodeGraph();
  explicit NodeGraph(QString graphId, QString name = "Default Graph");
  ~NodeGraph() = default;

  [[nodiscard]] const QString &id() const noexcept { return m_graphId; }
  void setId(const QString &id) { m_graphId = id; }

  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  void setName(const QString &name) { m_name = name; }

  [[nodiscard]] bool isReadOnly() const noexcept { return m_isReadOnly; }
  void setReadOnly(bool ro) noexcept { m_isReadOnly = ro; }

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

  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr);

  [[nodiscard]] RenderContext
  resolveDemandContext(const RenderContext &outputCtx) const;

  [[nodiscard]] std::vector<std::shared_ptr<Node>>
  compileExecutionSequence() const;
  [[nodiscard]] CompiledGraphShader compileFusedShader() const;
  void markDirty() noexcept { m_shaderDirty = true; }

  [[nodiscard]] QJsonObject serialize() const;
  bool deserialize(const QJsonObject &json);

  [[nodiscard]] QVariantMap extractDefaultProperties() const;
  [[nodiscard]] QVariantList listEditorNodes() const;
  [[nodiscard]] QString defaultEditorNodeId() const;
  [[nodiscard]] QVariantList toVariantList() const;
  [[nodiscard]] QVariantList linksToVariantList() const;

  static void registerNodeType(const QString &typeName, NodeFactory factory);
  static std::shared_ptr<Node> createNodeByType(const QString &typeName,
                                                const QString &id,
                                                const QString &name = "");

  static std::shared_ptr<NodeGraph>
  createDefaultClipGraph(const QString &assetId);

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

  static std::unordered_map<QString, NodeFactory> s_nodeRegistry;
};

} // namespace xyla::render
