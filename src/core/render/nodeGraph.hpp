#pragma once

#include "node.hpp"
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <vector>

namespace xyla::render {

struct NodeLink {
  QString fromNodeId;
  QString fromSocketId;
  QString toNodeId;
  QString toSocketId;
};

struct PushConstantMember {
  QString nodeId;
  QString propertyKey;
  uint32_t offsetBytes{0};
  uint32_t sizeBytes{0};
  SocketDataType dataType{SocketDataType::Float};
};

struct PushConstantLayout {
  std::vector<PushConstantMember> members;
  uint32_t totalSizeBytes{0};
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

  // Exports node list array to QML
  [[nodiscard]] QVariantList toVariantList() const {
    QVariantList list;
    for (const auto &node : m_nodes) {
      if (node) {
        QVariantMap map = node->toVariantMap();
        map["x"] = node->positionX();
        map["y"] = node->positionY();
        list.append(map);
      }
    }
    return list;
  }

  // Exports graph link connections array to QML
  [[nodiscard]] QVariantList linksToVariantList() const {
    QVariantList list;
    for (const auto &link : m_links) {
      QVariantMap map;
      map["fromNodeId"] = link.fromNodeId;
      map["fromSocketId"] = link.fromSocketId;
      map["toNodeId"] = link.toNodeId;
      map["toSocketId"] = link.toSocketId;
      list.append(map);
    }
    return list;
  }

  static std::shared_ptr<NodeGraph>
  createDefaultClipGraph(const QString &assetId);

private:
  std::vector<std::shared_ptr<Node>> m_nodes;
  std::vector<NodeLink> m_links;
};

} // namespace xyla::render
