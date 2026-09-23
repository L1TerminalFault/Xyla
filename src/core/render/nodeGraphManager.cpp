#include "nodeGraphManager.hpp"
#include "nodes/commentNode.hpp"
#include "nodes/groupNode.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/rerouteNode.hpp"
#include "nodes/videoInNode.hpp"

#include <QJsonArray>
#include <QUuid>

namespace xyla::render {

NodeGraphManager &NodeGraphManager::instance() {
  static NodeGraphManager s_mgr;
  return s_mgr;
}

NodeGraphManager::NodeGraphManager() {
  registerNodeType<VideoInNode>();
  registerNodeType<OutputNode>();
  registerNodeType<RerouteNode>();
  registerNodeType<CommentNode>();
  registerNodeType<GroupNode>();

  ensureDefaultGraphExists();
}

void NodeGraphManager::ensureDefaultGraphExists() {
  auto defGraph = std::make_shared<NodeGraph>(DEFAULT_IO_GRAPH_ID,
                                              QStringLiteral("Default"));

  auto srcNode = std::make_shared<VideoInNode>(QStringLiteral("default_src"),
                                               QStringLiteral("Video In"),
                                               QStringLiteral(""));
  srcNode->setPosition(-150.0, 0.0);

  auto outNode = std::make_shared<OutputNode>(QStringLiteral("default_out"),
                                              QStringLiteral("Video Out"));
  outNode->setPosition(150.0, 0.0);

  defGraph->addNode(srcNode);
  defGraph->addNode(outNode);
  defGraph->connectSockets(srcNode->id(), QStringLiteral("video_out"),
                           outNode->id(), QStringLiteral("video_in"));

  defGraph->setReadOnly(true);
  defGraph->markDirty();

  m_graphs[DEFAULT_IO_GRAPH_ID] = std::move(defGraph);
}

std::shared_ptr<Node>
NodeGraphManager::createNodeByType(const QString &typeName, QString id,
                                   QString name) const {
  const auto it = m_typeRegistry.find(typeName);
  if (it != m_typeRegistry.end()) {
    return it->second(std::move(id), std::move(name));
  }
  return nullptr;
}

std::shared_ptr<NodeGraph>
NodeGraphManager::createGraph(const QString &name, const QString &preferredId) {
  const QString id =
      preferredId.isEmpty()
          ? QStringLiteral("graph_%1")
                .arg(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8))
          : preferredId;

  auto graph = std::make_shared<NodeGraph>(
      id, name.isEmpty() ? QStringLiteral("New Graph") : name);

  const QString prefix = id;
  auto srcNode = std::make_shared<VideoInNode>(
      QStringLiteral("%1_src").arg(prefix), QStringLiteral("Video In"),
      QStringLiteral(""));
  srcNode->setPosition(-160.0, 0.0);

  auto outNode = std::make_shared<OutputNode>(
      QStringLiteral("%1_out").arg(prefix), QStringLiteral("Video Out"));
  outNode->setPosition(160.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(outNode);
  graph->connectSockets(srcNode->id(), QStringLiteral("video_out"),
                        outNode->id(), QStringLiteral("video_in"));

  m_graphs[id] = graph;
  return graph;
}

bool NodeGraphManager::removeGraph(const QString &graphId) {
  if (graphId == DEFAULT_IO_GRAPH_ID)
    return false;
  return m_graphs.erase(graphId) > 0;
}

std::shared_ptr<NodeGraph>
NodeGraphManager::getGraph(const QString &graphId) const {
  if (auto it = m_graphs.find(graphId); it != m_graphs.end()) {
    return it->second;
  }
  return defaultIOGraph();
}

std::shared_ptr<NodeGraph> NodeGraphManager::defaultIOGraph() const {
  if (auto it = m_graphs.find(DEFAULT_IO_GRAPH_ID); it != m_graphs.end()) {
    return it->second;
  }
  return nullptr;
}

bool NodeGraphManager::hasGraph(const QString &graphId) const {
  return m_graphs.contains(graphId);
}

QStringList NodeGraphManager::allGraphIds() const {
  QStringList list;
  list.reserve(static_cast<qsizetype>(m_graphs.size()));
  for (const auto &[id, _] : m_graphs) {
    list.append(id);
  }
  return list;
}

QVariantList NodeGraphManager::listAllGraphsSummary() const {
  QVariantList list;
  list.reserve(static_cast<qsizetype>(m_graphs.size()));
  for (const auto &[id, g] : m_graphs) {
    QVariantMap m;
    m[QStringLiteral("id")] = g->id();
    m[QStringLiteral("name")] = g->name();
    m[QStringLiteral("isDefault")] = (id == DEFAULT_IO_GRAPH_ID);
    m[QStringLiteral("isReadOnly")] = g->isReadOnly();
    list.append(m);
  }
  return list;
}

QJsonObject NodeGraphManager::serialize() const {
  QJsonObject root;
  QJsonArray arr;
  for (const auto &[_, graph] : m_graphs) {
    arr.append(graph->serialize());
  }
  root[QStringLiteral("graphs")] = arr;
  return root;
}

void NodeGraphManager::deserialize(const QJsonObject &root) {
  if (!root.contains(QStringLiteral("graphs")))
    return;

  m_graphs.clear();
  ensureDefaultGraphExists();

  const QJsonArray arr = root[QStringLiteral("graphs")].toArray();
  for (const auto &val : arr) {
    const QJsonObject obj = val.toObject();
    const QString id = obj[QStringLiteral("graphId")].toString();

    if (id.isEmpty() || id == DEFAULT_IO_GRAPH_ID)
      continue;

    auto graph =
        std::make_shared<NodeGraph>(id, obj[QStringLiteral("name")].toString());
    if (graph->deserialize(obj, *this)) {
      m_graphs[id] = std::move(graph);
    }
  }
}

void NodeGraphManager::clearUserGraphs() {
  m_graphs.clear();
  ensureDefaultGraphExists();
}

} // namespace xyla::render
