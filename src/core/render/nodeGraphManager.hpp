// #pragma once
//
// #include "nodeGraph.hpp"
// #include <QJsonArray>
// #include <QJsonDocument>
// #include <QJsonObject>
// #include <QString>
// #include <functional>
// #include <memory>
// #include <unordered_map>
// #include <vector>
//
// namespace xyla::render {
//
// class NodeGraphRepository {
// public:
//     using GraphModifiedCallback = std::function<void(const QString
//     &graphId)>;
//
//     NodeGraphRepository() = default;
//     ~NodeGraphRepository() = default;
//
//     // --- Startup Initialization ---
//     /**
//      * @brief Instantiates and registers the default baseline node graph.
//      * @return The unique ID of the default master graph.
//      */
//     QString initializeDefaultGraph() {
//         m_defaultGraphId = QStringLiteral("graph_default_base");
//
//         if (m_graphs.find(m_defaultGraphId) == m_graphs.end()) {
//             auto defaultGraph =
//             NodeGraph::createDefaultClipGraph(QStringLiteral("default_asset"));
//             m_graphs[m_defaultGraphId] = defaultGraph;
//         }
//
//         return m_defaultGraphId;
//     }
//
//     [[nodiscard]] const QString &defaultGraphId() const noexcept {
//         return m_defaultGraphId;
//     }
//
//     // --- Query & Lifecycle ---
//     [[nodiscard]] std::shared_ptr<NodeGraph> getGraph(const QString &graphId)
//     const {
//         auto it = m_graphs.find(graphId);
//         if (it != m_graphs.end()) {
//             return it->second;
//         }
//         return nullptr;
//     }
//
//     void registerGraph(const QString &graphId, std::shared_ptr<NodeGraph>
//     graph) {
//         if (!graphId.isEmpty() && graph) {
//             m_graphs[graphId] = std::move(graph);
//             notifyGraphModified(graphId);
//         }
//     }
//
//     std::shared_ptr<NodeGraph> createGraph(const QString &customId =
//     QString()) {
//         QString id = customId.isEmpty() ? generateGraphId() : customId;
//         auto graph = std::make_shared<NodeGraph>();
//         m_graphs[id] = graph;
//         notifyGraphModified(id);
//         return graph;
//     }
//
//     /**
//      * @brief Duplicates an existing graph ("Make Single-User" / Unlink from
//      shared).
//      */
//     QString duplicateGraph(const QString &sourceGraphId) {
//         auto source = getGraph(sourceGraphId);
//         if (!source) return QString();
//
//         QString newId = generateGraphId();
//         // Serialize source and deserialize into new instance for a true
//         deep-copy QJsonObject sourceJson = source->serialize(); auto
//         clonedGraph = NodeGraph::deserialize(sourceJson); m_graphs[newId] =
//         clonedGraph; notifyGraphModified(newId); return newId;
//     }
//
//     bool removeGraph(const QString &graphId) {
//         if (graphId == m_defaultGraphId) return false; // Protected default
//         auto it = m_graphs.find(graphId);
//         if (it != m_graphs.end()) {
//             m_graphs.erase(it);
//             notifyGraphModified(graphId);
//             return true;
//         }
//         return false;
//     }
//
//     [[nodiscard]] bool hasGraph(const QString &graphId) const noexcept {
//         return m_graphs.find(graphId) != m_graphs.end();
//     }
//
//     [[nodiscard]] std::vector<QString> allGraphIds() const {
//         std::vector<QString> ids;
//         ids.reserve(m_graphs.size());
//         for (const auto &[id, _] : m_graphs) {
//             ids.push_back(id);
//         }
//         return ids;
//     }
//
//     // --- Reactive Many-to-Many Notification ---
//     /**
//      * @brief When a node graph is edited, calling this notifies all
//      listening clips & viewport.
//      */
//     void notifyGraphModified(const QString &graphId) {
//         auto graph = getGraph(graphId);
//         if (graph) {
//             graph->markDirty();
//         }
//         for (const auto &cb : m_listeners) {
//             if (cb) cb(graphId);
//         }
//     }
//
//     void addModifiedListener(GraphModifiedCallback cb) {
//         m_listeners.push_back(std::move(cb));
//     }
//
//     // --- Full Disk & Project Serialization ---
//     [[nodiscard]] QJsonObject serialize() const {
//         QJsonObject root;
//         root["version"] = 1;
//         root["defaultGraphId"] = m_defaultGraphId;
//         root["idCounter"] = static_cast<qint64>(m_idCounter);
//
//         QJsonObject graphsObj;
//         for (const auto &[id, graph] : m_graphs) {
//             if (graph) {
//                 graphsObj[id] = graph->serialize();
//             }
//         }
//         root["graphs"] = graphsObj;
//         return root;
//     }
//
//     static std::shared_ptr<NodeGraphRepository> deserialize(const QJsonObject
//     &obj) {
//         auto repo = std::make_shared<NodeGraphRepository>();
//         repo->m_defaultGraphId = obj["defaultGraphId"].toString();
//         repo->m_idCounter =
//         static_cast<uint64_t>(obj["idCounter"].toInteger(1000));
//
//         QJsonObject graphsObj = obj["graphs"].toObject();
//         for (auto it = graphsObj.begin(); it != graphsObj.end(); ++it) {
//             QString graphId = it.key();
//             QJsonObject graphData = it.value().toObject();
//             auto graph = NodeGraph::deserialize(graphData);
//             if (graph) {
//                 repo->m_graphs[graphId] = graph;
//             }
//         }
//
//         // Guarantee a valid default graph always exists
//         if (repo->m_defaultGraphId.isEmpty() ||
//         !repo->hasGraph(repo->m_defaultGraphId)) {
//             repo->initializeDefaultGraph();
//         }
//
//         return repo;
//     }
//
//     /**
//      * @brief Exports the entire repository to a JSON string or file.
//      */
//     [[nodiscard]] QByteArray exportToJson(QJsonDocument::JsonFormat format =
//     QJsonDocument::Indented) const {
//         QJsonDocument doc(serialize());
//         return doc.toJson(format);
//     }
//
//     /**
//      * @brief Imports repository from JSON data.
//      */
//     static std::shared_ptr<NodeGraphRepository> importFromJson(const
//     QByteArray &jsonData) {
//         QJsonDocument doc = QJsonDocument::fromJson(jsonData);
//         if (doc.isNull() || !doc.isObject()) {
//             return nullptr;
//         }
//         return deserialize(doc.object());
//     }
//
// private:
//     QString generateGraphId() {
//         return QStringLiteral("graph_%1").arg(++m_idCounter);
//     }
//
//     QString m_defaultGraphId;
//     uint64_t m_idCounter{1000};
//     std::unordered_map<QString, std::shared_ptr<NodeGraph>> m_graphs;
//     std::vector<GraphModifiedCallback> m_listeners;
// };
//
// } // namespace xyla::render

#pragma once

/* =============================================================================
 * XYLA NODE GRAPH MANAGER (HEADER)
 * -----------------------------------------------------------------------------
 * WHAT THIS FILE DOES:
 * 1. Provides a central repository holding all NodeGraphs in the project.
 * 2. Manages the singleton immutable default In/Out graph ("default_io_graph").
 * 3. Declares lifecycle, lookup, and serialization methods.
 * =============================================================================
 */

#include "nodeGraph.hpp"
#include <QJsonObject>
#include <QStringList>
#include <QVariantList>
#include <memory>
#include <unordered_map>

namespace xyla::render {

constexpr const char *DEFAULT_IO_GRAPH_ID = "default_io_graph";

class NodeGraphManager {
public:
  static NodeGraphManager &instance();

  [[nodiscard]] std::shared_ptr<NodeGraph>
  getGraph(const QString &graphId) const;
  [[nodiscard]] std::shared_ptr<NodeGraph> defaultIOGraph() const;

  std::shared_ptr<NodeGraph> createGraph(const QString &name = "New Graph",
                                         const QString &preferredId = "");
  bool removeGraph(const QString &graphId);

  [[nodiscard]] bool hasGraph(const QString &graphId) const;
  [[nodiscard]] QStringList allGraphIds() const;
  [[nodiscard]] QVariantList listAllGraphsSummary() const;

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &root);
  void clearUserGraphs();

private:
  NodeGraphManager();
  void ensureDefaultGraphExists();

  std::unordered_map<QString, std::shared_ptr<NodeGraph>> m_graphs;
};

} // namespace xyla::render
