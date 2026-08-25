#include "nodeGraph.hpp"
#include "core/log/logger.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/sourceNode.hpp"
#include "nodes/transformNode.hpp"
#include <algorithm>
#include <queue>
#include <unordered_map>

namespace xyla::render {

namespace {

uint32_t alignTo(uint32_t currentOffset, uint32_t alignment) noexcept {
  return (currentOffset + alignment - 1) & ~(alignment - 1);
}

uint32_t getDataTypeSizeBytes(SocketDataType type) noexcept {
  switch (type) {
  case SocketDataType::Float:
    return 4;
  case SocketDataType::Vec2:
    return 8; // 2 x 4 bytes (aligned to 8)
  case SocketDataType::Color:
    return 16; // 4 x 4 bytes (aligned to 16)
  case SocketDataType::Mat4:
    return 64; // 16 x 4 bytes (aligned to 16)
  case SocketDataType::Int:
    return 4;
  case SocketDataType::Bool:
    return 4; // Vulkan bool push constant is 4 bytes
  case SocketDataType::Image:
    return 0; // Textures use descriptor bindings, not push constants
  }
  return 4;
}

uint32_t getDataTypeAlignment(SocketDataType type) noexcept {
  switch (type) {
  case SocketDataType::Float:
    return 4;
  case SocketDataType::Vec2:
    return 8;
  case SocketDataType::Color:
    return 16;
  case SocketDataType::Mat4:
    return 16;
  case SocketDataType::Int:
    return 4;
  case SocketDataType::Bool:
    return 4;
  case SocketDataType::Image:
    return 1;
  }
  return 4;
}

} // namespace

void NodeGraph::addNode(std::shared_ptr<Node> node) {
  if (!node)
    return;
  m_nodes.push_back(std::move(node));
}

bool NodeGraph::removeNode(const QString &nodeId) {
  auto it = std::remove_if(
      m_nodes.begin(), m_nodes.end(),
      [&nodeId](const std::shared_ptr<Node> &n) { return n->id() == nodeId; });
  if (it != m_nodes.end()) {
    m_nodes.erase(it, m_nodes.end());

    // clean up links connected to removed node
    auto lIt = std::remove_if(
        m_links.begin(), m_links.end(), [&nodeId](const NodeLink &l) {
          return l.fromNodeId == nodeId || l.toNodeId == nodeId;
        });
    m_links.erase(lIt, m_links.end());
    return true;
  }
  return false;
}

std::shared_ptr<Node> NodeGraph::findNode(const QString &nodeId) const {
  for (const auto &n : m_nodes) {
    if (n->id() == nodeId)
      return n;
  }
  return nullptr;
}

bool NodeGraph::connectSockets(const QString &fromNode,
                               const QString &fromSocket, const QString &toNode,
                               const QString &toSocket) {
  if (fromNode == toNode)
    return false;

  for (const auto &l : m_links) {
    if (l.fromNodeId == fromNode && l.fromSocketId == fromSocket &&
        l.toNodeId == toNode && l.toSocketId == toSocket) {
      return false;
    }
  }

  m_links.push_back({fromNode, fromSocket, toNode, toSocket});
  return true;
}

bool NodeGraph::disconnectSockets(const QString &fromNode,
                                  const QString &fromSocket,
                                  const QString &toNode,
                                  const QString &toSocket) {
  auto it =
      std::remove_if(m_links.begin(), m_links.end(), [&](const NodeLink &l) {
        return l.fromNodeId == fromNode && l.fromSocketId == fromSocket &&
               l.toNodeId == toNode && l.toSocketId == toSocket;
      });
  if (it != m_links.end()) {
    m_links.erase(it, m_links.end());
    return true;
  }
  return false;
}

// Kahn
std::vector<std::shared_ptr<Node>> NodeGraph::compileExecutionSequence() const {
  std::unordered_map<QString, int> inDegree;
  std::unordered_map<QString, std::shared_ptr<Node>> nodeMap;
  std::unordered_map<QString, std::vector<QString>> adjList;

  for (const auto &n : m_nodes) {
    nodeMap[n->id()] = n;
    inDegree[n->id()] = 0;
  }

  for (const auto &l : m_links) {
    adjList[l.fromNodeId].push_back(l.toNodeId);
    inDegree[l.toNodeId]++;
  }

  std::queue<QString> q;
  for (const auto &[id, deg] : inDegree) {
    if (deg == 0)
      q.push(id);
  }

  std::vector<std::shared_ptr<Node>> sequence;
  while (!q.empty()) {
    QString curr = q.front();
    q.pop();

    if (nodeMap.count(curr)) {
      sequence.push_back(nodeMap[curr]);
    }

    for (const auto &neighbor : adjList[curr]) {
      inDegree[neighbor]--;
      if (inDegree[neighbor] == 0) {
        q.push(neighbor);
      }
    }
  }

  if (sequence.size() != m_nodes.size()) {
    XYLA_LOG_WARN(
        "NodeGraph",
        "Cycle detected in NodeGraph! Fallback to partial execution sequence.");
  }

  return sequence;
}

CompiledGraphShader NodeGraph::compileFusedShader() const {
  CompiledGraphShader result;
  auto sequence = compileExecutionSequence();

  if (sequence.empty()) {
    return result;
  }

  QString glslHeader = "#version 450\n";
  glslHeader +=
      "layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;\n";
  glslHeader +=
      "layout(binding = 0, rgba8) uniform writeonly image2D u_outputFrame;\n\n";

  QString pushConstantGLSL = "layout(push_constant) uniform PushConstants {\n";
  uint32_t currentByteOffset = 0;

  for (const auto &node : sequence) {
    for (const auto &inputSocket : node->inputs()) {
      if (inputSocket.frameOffset < 0) {
        result.hasTemporalOffset = true;
      }

      if (inputSocket.dataType != SocketDataType::Image) {
        uint32_t size = getDataTypeSizeBytes(inputSocket.dataType);
        uint32_t align = getDataTypeAlignment(inputSocket.dataType);
        currentByteOffset = alignTo(currentByteOffset, align);

        PushConstantMember member;
        member.nodeId = node->id();
        member.propertyKey = inputSocket.id;
        member.offsetBytes = currentByteOffset;
        member.sizeBytes = size;
        member.dataType = inputSocket.dataType;

        result.pushConstants.members.push_back(member);

        pushConstantGLSL += QString("  %1 pc_%2_%3;\n")
                                .arg(inputSocket.glslTypeName())
                                .arg(node->id())
                                .arg(inputSocket.id);

        currentByteOffset += size;
      }
    }

    glslHeader += node->generateGlslUniforms();
  }

  result.pushConstants.totalSizeBytes = alignTo(currentByteOffset, 16);
  pushConstantGLSL += "} u_push;\n\n";

  if (result.hasTemporalOffset) {
    glslHeader += "layout(binding = 1) uniform sampler2D u_prevFrame;\n";
  }

  QString glslBody = "void main() {\n";
  glslBody += "  ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);\n";
  glslBody += "  ivec2 imgSize = imageSize(u_outputFrame);\n";
  glslBody +=
      "  if (pixelCoord.x >= imgSize.x || pixelCoord.y >= imgSize.y) return;\n";
  glslBody += "  vec2 uv = (vec2(pixelCoord) + vec2(0.5)) / vec2(imgSize);\n\n";

  std::unordered_map<QString, QString> variableMap;

  // Fuse each node's math directly into the compute shader body
  for (size_t i = 0; i < sequence.size(); ++i) {
    const auto &node = sequence[i];
    QString outputVar = QString("v_%1_out").arg(node->id());

    std::unordered_map<QString, QString> inputVars;
    for (const auto &inSocket : node->inputs()) {
      bool foundLink = false;
      for (const auto &link : m_links) {
        if (link.toNodeId == node->id() && link.toSocketId == inSocket.id) {
          QString srcVarKey = link.fromNodeId + "_" + link.fromSocketId;
          if (variableMap.count(srcVarKey)) {
            inputVars[inSocket.id] = variableMap[srcVarKey];
            foundLink = true;
          }
          break;
        }
      }

      // If unconnected, use Push Constant value
      if (!foundLink && inSocket.dataType != SocketDataType::Image) {
        inputVars[inSocket.id] =
            QString("u_push.pc_%1_%2").arg(node->id()).arg(inSocket.id);
      }
    }

    glslBody +=
        QString("  // Node: %1 (%2)\n").arg(node->name()).arg(node->id());
    glslBody += node->generateGlslCode(inputVars, outputVar);

    // Register node's output socket variables
    for (const auto &outSocket : node->outputs()) {
      variableMap[node->id() + "_" + outSocket.id] = outputVar;
    }
  }

  // Store final composite frame to Vulkan output texture
  QString lastOutputVar = sequence.back()->id() + "_tex_out";
  if (variableMap.count(lastOutputVar)) {
    glslBody += QString("  imageStore(u_outputFrame, pixelCoord, %1);\n")
                    .arg(variableMap[lastOutputVar]);
  }
  glslBody += "}\n";

  result.glslSource =
      glslHeader +
      (result.pushConstants.members.empty() ? "" : pushConstantGLSL) + glslBody;
  return result;
}

std::shared_ptr<NodeGraph>
NodeGraph::createDefaultClipGraph(const QString &assetId) {
  auto graph = std::make_shared<NodeGraph>();

  // source
  auto srcNode =
      std::make_shared<SourceNode>(assetId + "_src", "Media Source", assetId);

  // transform
  auto xformNode = std::make_shared<TransformNode>(assetId + "_xform",
                                                   "Transform / Opacity");

  // output
  auto outNode = std::make_shared<OutputNode>(assetId + "_out", "Clip Output");

  graph->addNode(srcNode);
  graph->addNode(xformNode);
  graph->addNode(outNode);

  graph->connectSockets(srcNode->id(), "tex_out", xformNode->id(), "tex_in");
  graph->connectSockets(xformNode->id(), "tex_out", outNode->id(), "tex_in");

  return graph;
}

} // namespace xyla::render
