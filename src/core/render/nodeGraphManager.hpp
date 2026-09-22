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
