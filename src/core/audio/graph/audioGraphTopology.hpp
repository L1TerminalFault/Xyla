#pragma once

#include <algorithm>
#include <deque>
#include <map>
#include <string>
#include <vector>

namespace xyla::audio {

struct GraphConnection {
  std::string srcNodeId;
  std::string srcPinId;
  std::string dstNodeId;
  std::string dstPinId;

  bool operator==(const GraphConnection &other) const noexcept {
    return srcNodeId == other.srcNodeId && srcPinId == other.srcPinId &&
           dstNodeId == other.dstNodeId && dstPinId == other.dstPinId;
  }
};

/**
 * @brief Pure topological sort and validation engine for AudioGraph DAGs.
 * Completely testable with synthetic node ID strings.
 */
class AudioGraphTopology {
public:
  static bool addConnection(std::vector<GraphConnection> &connections,
                            GraphConnection conn) {
    if (std::find(connections.begin(), connections.end(), conn) ==
        connections.end()) {
      connections.push_back(std::move(conn));
      return true;
    }
    return false;
  }

  static bool removeConnection(std::vector<GraphConnection> &connections,
                               const GraphConnection &target) {
    auto it = std::remove(connections.begin(), connections.end(), target);
    if (it == connections.end())
      return false;
    connections.erase(it, connections.end());
    return true;
  }

  static void disconnectAllNodePins(std::vector<GraphConnection> &connections,
                                    const std::string &nodeId) {
    connections.erase(std::remove_if(connections.begin(), connections.end(),
                                     [&](const GraphConnection &c) {
                                       return c.srcNodeId == nodeId ||
                                              c.dstNodeId == nodeId;
                                     }),
                      connections.end());
  }

  /**
   * @brief Computes topological execution order using Kahn's Algorithm.
   * @return Ordered list of node IDs. Returns empty if a cycle/deadlock is
   * detected.
   */
  static std::vector<std::string>
  computeTopologicalOrder(const std::vector<std::string> &nodeIds,
                          const std::vector<GraphConnection> &connections) {
    std::map<std::string, std::vector<std::string>> adjList;
    std::map<std::string, int> inDegree;

    for (const auto &id : nodeIds) {
      inDegree[id] = 0;
    }

    for (const auto &c : connections) {
      if (inDegree.count(c.srcNodeId) && inDegree.count(c.dstNodeId)) {
        adjList[c.srcNodeId].push_back(c.dstNodeId);
        inDegree[c.dstNodeId]++;
      }
    }

    std::deque<std::string> queue;
    for (const auto &[id, deg] : inDegree) {
      if (deg == 0)
        queue.push_back(id);
    }

    std::vector<std::string> sorted;
    sorted.reserve(nodeIds.size());

    while (!queue.empty()) {
      std::string u = queue.front();
      queue.pop_front();
      sorted.push_back(u);

      for (const auto &v : adjList[u]) {
        if (--inDegree[v] == 0) {
          queue.push_back(v);
        }
      }
    }

    // Add any remaining unlinked/isolated nodes
    for (const auto &id : nodeIds) {
      if (std::find(sorted.begin(), sorted.end(), id) == sorted.end()) {
        sorted.push_back(id);
      }
    }

    return sorted;
  }
};

} // namespace xyla::audio
