/* =============================================================================
 * XYLA NODE GRAPH MANAGER (IMPLEMENTATION)
 * -----------------------------------------------------------------------------
 * WHAT THIS FILE DOES:
 * 1. Implements singleton lifecycle for NodeGraphManager.
 * 2. Includes the concrete SourceNode and OutputNode headers safely.
 * 3. Constructs the immutable "default_io_graph" with Video In and Video Out.
 * 4. Handles serialization and deserialization of the central graphs
 * repository.
 * =============================================================================
 */

#include "nodeGraphManager.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/sourceNode.hpp"
#include <QJsonArray>
#include <QUuid>

namespace xyla::render {

NodeGraphManager &NodeGraphManager::instance() {
  static NodeGraphManager s_mgr;
  return s_mgr;
}

NodeGraphManager::NodeGraphManager() { ensureDefaultGraphExists(); }

void NodeGraphManager::ensureDefaultGraphExists() {
  if (m_graphs.find(DEFAULT_IO_GRAPH_ID) == m_graphs.end()) {
    auto defGraph =
        std::make_shared<NodeGraph>(DEFAULT_IO_GRAPH_ID, "Default In/Out");
    defGraph->setReadOnly(true);

    auto srcNode = std::make_shared<SourceNode>("default_src", "Video In", "");
    srcNode->setPosition(-150.0, 0.0);
    auto outNode = std::make_shared<OutputNode>("default_out", "Video Out");
    outNode->setPosition(150.0, 0.0);

    defGraph->addNode(srcNode);
    defGraph->addNode(outNode);
    defGraph->connectSockets("default_src", "video_out", "default_out",
                             "video_in");

    m_graphs[DEFAULT_IO_GRAPH_ID] = defGraph;
  }
}

std::shared_ptr<NodeGraph>
NodeGraphManager::getGraph(const QString &graphId) const {
  auto it = m_graphs.find(graphId);
  if (it != m_graphs.end()) {
    return it->second;
  }
  auto defIt = m_graphs.find(DEFAULT_IO_GRAPH_ID);
  return (defIt != m_graphs.end()) ? defIt->second : nullptr;
}

std::shared_ptr<NodeGraph> NodeGraphManager::defaultIOGraph() const {
  return getGraph(DEFAULT_IO_GRAPH_ID);
}

// In core/render/nodeGraphManager.cpp:
std::shared_ptr<NodeGraph> NodeGraphManager::createGraph(const QString &name, const QString &preferredId) {
  QString id = preferredId.isEmpty()
      ? ("graph_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8))
      : preferredId;

  auto graph = std::make_shared<NodeGraph>(id, name.isEmpty() ? "New Graph" : name);

  // Pre-seed user graph with connected In & Out nodes
  auto srcNode = std::make_shared<SourceNode>("src_in", "Video In", "");
  srcNode->setPosition(-160.0, 0.0);
  auto outNode = std::make_shared<OutputNode>("src_out", "Video Out");
  outNode->setPosition(160.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(outNode);
  graph->connectSockets("src_in", "video_out", "src_out", "video_in");

  m_graphs[id] = graph;
  return graph;
}

bool NodeGraphManager::removeGraph(const QString &graphId) {
  if (graphId == DEFAULT_IO_GRAPH_ID) {
    return false; // Immutable default graph can never be deleted
  }
  return m_graphs.erase(graphId) > 0;
}

bool NodeGraphManager::hasGraph(const QString &graphId) const {
  return m_graphs.find(graphId) != m_graphs.end();
}

QStringList NodeGraphManager::allGraphIds() const {
  QStringList list;
  for (const auto &[id, g] : m_graphs) {
    list.append(id);
  }
  return list;
}

QVariantList NodeGraphManager::listAllGraphsSummary() const {
  QVariantList list;
  for (const auto &[id, g] : m_graphs) {
    QVariantMap m;
    m["id"] = g->id();
    m["name"] = g->name();
    m["isDefault"] = (id == DEFAULT_IO_GRAPH_ID);
    m["isReadOnly"] = g->isReadOnly();
    list.append(m);
  }
  return list;
}

QJsonObject NodeGraphManager::serialize() const {
  QJsonObject root;
  QJsonArray graphsArr;
  for (const auto &[id, graph] : m_graphs) {
    graphsArr.append(graph->serialize());
  }
  root["graphs"] = graphsArr;
  return root;
}

void NodeGraphManager::deserialize(const QJsonObject &root) {
  if (!root.contains("graphs"))
    return;

  m_graphs.clear();
  ensureDefaultGraphExists();

  QJsonArray graphsArr = root["graphs"].toArray();
  for (const auto &gVal : graphsArr) {
    QJsonObject gObj = gVal.toObject();
    QString id = gObj["graphId"].toString();
    if (id.isEmpty())
      continue;

    auto graph = std::make_shared<NodeGraph>(id, gObj.value("name").toString());
    if (graph->deserialize(gObj)) {
      m_graphs[id] = graph;
    }
  }
  ensureDefaultGraphExists();
}

void NodeGraphManager::clearUserGraphs() {
  m_graphs.clear();
  ensureDefaultGraphExists();
}

} // namespace xyla::render
