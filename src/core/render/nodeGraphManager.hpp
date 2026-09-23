#pragma once

#include "nodeGraph.hpp"
#include <functional>
#include <memory>
#include <unordered_map>

namespace xyla::render {

constexpr inline const char *DEFAULT_IO_GRAPH_ID = "default_io_graph";
using NodeFactory =
    std::function<std::shared_ptr<Node>(QString id, QString name)>;

class NodeGraphManager {
public:
  static NodeGraphManager &instance();

  template <typename TNode> void registerNodeType() {
    m_typeRegistry[TNode::StaticTypeName] = [](QString id, QString name) {
      return std::make_shared<TNode>(std::move(id), std::move(name));
    };
  }

  [[nodiscard]] std::shared_ptr<Node>
  createNodeByType(const QString &typeName, QString id, QString name) const;

  std::shared_ptr<NodeGraph>
  createGraph(const QString &name = QStringLiteral("New Graph"),
              const QString &preferredId = {});
  bool removeGraph(const QString &graphId);

  [[nodiscard]] std::shared_ptr<NodeGraph>
  getGraph(const QString &graphId) const;
  [[nodiscard]] std::shared_ptr<NodeGraph> defaultIOGraph() const;
  [[nodiscard]] bool hasGraph(const QString &graphId) const;

  [[nodiscard]] QStringList allGraphIds() const;
  [[nodiscard]] QVariantList listAllGraphsSummary() const;

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &root);
  void clearUserGraphs();

private:
  NodeGraphManager();
  void ensureDefaultGraphExists();

  std::unordered_map<QString, NodeFactory> m_typeRegistry;
  std::unordered_map<QString, std::shared_ptr<NodeGraph>> m_graphs;
};

} // namespace xyla::render
