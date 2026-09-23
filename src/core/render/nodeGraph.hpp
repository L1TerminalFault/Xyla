#pragma once

#include "core/animation/AnimationManager.hpp"
#include "node.hpp"
#include "nodeSocket.hpp"
#include "renderTypes.hpp"

#include <QJsonObject>
#include <QVariantList>
#include <atomic>
#include <memory>
#include <vector>

namespace xyla::render {

class NodeGraphManager;
struct TextureBindingDescriptor {
  uint32_t bindingIndex{0};
  QString uniformName;
  QString nodeId;
};

struct ShaderProperty {
  QString nodeId;
  QString socketId;
  QString fullKey;
  uint32_t offsetBytes{0};
  uint32_t sizeBytes{0};
  SocketDataType dataType{SocketDataType::Float};
  anim::PropertyHandle handle;
};

struct ShaderBufferLayout {
  uint32_t totalSizeBytes{0};
  std::vector<ShaderProperty> members;
};

struct CompiledGraphShader {
  QString glslSource;
  ShaderBufferLayout ssboLayout;
  std::vector<TextureBindingDescriptor> textureBindings;
  uint32_t ssboBindingIndex{0};
  bool isValid{false};
};

class NodeGraph {
public:
  NodeGraph();
  explicit NodeGraph(QString graphId, QString name);

  [[nodiscard]] const QString &id() const noexcept { return m_graphId; }
  void setId(QString id) noexcept { m_graphId = std::move(id); }

  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  void setName(QString name) noexcept { m_name = std::move(name); }

  [[nodiscard]] bool isReadOnly() const noexcept { return m_readOnly; }
  void setReadOnly(bool readOnly) noexcept { m_readOnly = readOnly; }

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

  void bindAnimationManager(anim::AnimationManager &animMgr);

  [[nodiscard]] std::vector<std::shared_ptr<Node>>
  compileExecutionSequence() const;
  [[nodiscard]] RenderContext
  resolvePipelineContext(const RenderContext &outputCtx) const;
  [[nodiscard]] CompiledGraphShader compileFusedShader() const;

  void markDirty() noexcept { m_shaderDirty = true; }
  void setPreviewTargetNode(const QString &nodeId);

  [[nodiscard]] QJsonObject serialize() const;
  bool deserialize(const QJsonObject &json, NodeGraphManager &graphManager);

  [[nodiscard]] QVariantList
  toVariantList(FrameIndex frame, const anim::AnimationManager *animMgr) const;
  [[nodiscard]] QVariantList linksToVariantList() const;
  [[nodiscard]] QVariantList listEditorNodes() const;
  [[nodiscard]] QString defaultEditorNodeId() const;
  [[nodiscard]] QString generateUniqueNodeId(const QString &prefix) const;

private:
  [[nodiscard]] bool wouldIntroduceCycle(const QString &fromNode,
                                         const QString &toNode) const;

  QString m_graphId;
  QString m_name;
  bool m_readOnly{false};

  std::vector<std::shared_ptr<Node>> m_nodes;
  std::vector<NodeLink> m_links;

  mutable std::atomic<bool> m_shaderDirty{true};
  mutable CompiledGraphShader m_cachedShader;
};

} // namespace xyla::render
