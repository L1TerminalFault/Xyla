#include "nodeGraph.hpp"
#include "nodes/colorGradeNode.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/sourceNode.hpp"
#include "nodes/transformNode.hpp"
#include <QRegularExpression>
#include <QUuid>
#include <algorithm>
#include <queue>
#include <unordered_map>
#include <unordered_set>

namespace xyla::render {

namespace {

QString sanitizeGlslId(const QString &raw) {
  QString clean = raw;
  clean.replace(QRegularExpression("[^a-zA-Z0-9]"), "_");
  clean.replace(QRegularExpression("_+"), "_");
  if (clean.startsWith('_'))
    clean.remove(0, 1);
  if (!clean.isEmpty() && clean[0].isDigit())
    clean.prepend("n_");
  return clean;
}

uint32_t alignTo(uint32_t currentOffset, uint32_t alignment) noexcept {
  return (currentOffset + alignment - 1) & ~(alignment - 1);
}

} // namespace

void NodeGraph::addNode(std::shared_ptr<Node> node) {
  if (!node)
    return;
  m_nodes.push_back(std::move(node));
  markDirty();
}

bool NodeGraph::removeNode(const QString &nodeId) {
  auto it = std::remove_if(
      m_nodes.begin(), m_nodes.end(),
      [&nodeId](const std::shared_ptr<Node> &n) { return n->id() == nodeId; });
  if (it != m_nodes.end()) {
    m_nodes.erase(it, m_nodes.end());

    auto lIt = std::remove_if(
        m_links.begin(), m_links.end(), [&nodeId](const NodeLink &l) {
          return l.fromNodeId == nodeId || l.toNodeId == nodeId;
        });
    m_links.erase(lIt, m_links.end());
    markDirty();
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

bool NodeGraph::wouldIntroduceCycle(const QString &fromNode,
                                    const QString &toNode) const {
  if (fromNode == toNode)
    return true;

  std::unordered_map<QString, std::vector<QString>> adj;
  for (const auto &link : m_links) {
    if (link.toNodeId != toNode) { // Test with prospective link only
      adj[link.fromNodeId].push_back(link.toNodeId);
    }
  }
  adj[fromNode].push_back(toNode);

  std::unordered_set<QString> visited;
  std::unordered_set<QString> recStack;

  std::function<bool(const QString &)> isCyclic =
      [&](const QString &curr) -> bool {
    visited.insert(curr);
    recStack.insert(curr);

    for (const auto &neighbor : adj[curr]) {
      if (recStack.count(neighbor))
        return true;
      if (!visited.count(neighbor) && isCyclic(neighbor))
        return true;
    }
    recStack.erase(curr);
    return false;
  };

  for (const auto &node : m_nodes) {
    if (!visited.count(node->id())) {
      if (isCyclic(node->id()))
        return true;
    }
  }

  return false;
}

bool NodeGraph::connectSockets(const QString &fromNode,
                               const QString &fromSocket, const QString &toNode,
                               const QString &toSocket) {
  if (fromNode == toNode)
    return false;

  auto srcNode = findNode(fromNode);
  auto dstNode = findNode(toNode);
  if (!srcNode || !dstNode)
    return false;

  const NodeSocket *srcSock = nullptr;
  for (const auto &s : srcNode->outputs()) {
    if (s.id == fromSocket) {
      srcSock = &s;
      break;
    }
  }

  const NodeSocket *dstSock = nullptr;
  for (const auto &s : dstNode->inputs()) {
    if (s.id == toSocket) {
      dstSock = &s;
      break;
    }
  }

  if (!srcSock || !dstSock)
    return false;
  if (!NodeSocket::areCompatible(srcSock->dataType, dstSock->dataType))
    return false;

  if (wouldIntroduceCycle(fromNode, toNode))
    return false;

  // Single connection per input socket
  auto lIt =
      std::remove_if(m_links.begin(), m_links.end(), [&](const NodeLink &l) {
        return l.toNodeId == toNode && l.toSocketId == toSocket;
      });
  m_links.erase(lIt, m_links.end());

  m_links.push_back({fromNode, fromSocket, toNode, toSocket});
  markDirty();
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
    markDirty();
    return true;
  }
  return false;
}

std::vector<std::shared_ptr<Node>> NodeGraph::compileExecutionSequence() const {
  std::shared_ptr<Node> outputNode = nullptr;
  for (const auto &n : m_nodes) {
    if (n && n->typeName() == "OutputNode") {
      outputNode = n;
      break;
    }
  }

  if (!outputNode)
    return {};

  // 1. Backward reachability from OutputNode
  std::unordered_set<QString> reachable;
  std::unordered_map<QString, std::vector<QString>> reverseAdj;
  for (const auto &link : m_links) {
    reverseAdj[link.toNodeId].push_back(link.fromNodeId);
  }

  std::queue<QString> reachQueue;
  reachQueue.push(outputNode->id());
  reachable.insert(outputNode->id());

  while (!reachQueue.empty()) {
    QString curr = reachQueue.front();
    reachQueue.pop();

    for (const auto &prev : reverseAdj[curr]) {
      if (!reachable.count(prev)) {
        reachable.insert(prev);
        reachQueue.push(prev);
      }
    }
  }

  // 2. Forward topological sort on reachable nodes only
  std::unordered_map<QString, int> inDegree;
  std::unordered_map<QString, std::shared_ptr<Node>> nodeMap;
  std::unordered_map<QString, std::vector<QString>> adjList;

  for (const auto &n : m_nodes) {
    if (reachable.count(n->id())) {
      nodeMap[n->id()] = n;
      inDegree[n->id()] = 0;
    }
  }

  for (const auto &l : m_links) {
    if (reachable.count(l.fromNodeId) && reachable.count(l.toNodeId)) {
      adjList[l.fromNodeId].push_back(l.toNodeId);
      inDegree[l.toNodeId]++;
    }
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

  return sequence;
}

CompiledGraphShader NodeGraph::compileFusedShader() const {
  if (!m_shaderDirty && !m_cachedCompiledShader.glslSource.isEmpty()) {
    return m_cachedCompiledShader;
  }

  CompiledGraphShader result;
  auto sequence = compileExecutionSequence();

  std::shared_ptr<Node> outputNode = nullptr;
  for (const auto &n : m_nodes) {
    if (n && n->typeName() == "OutputNode") {
      outputNode = n;
      break;
    }
  }

  QString glslHeader = "#version 450\n";
  glslHeader +=
      "layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;\n";
  glslHeader += "layout(binding = 0, rgba8) uniform image2D u_outputFrame;\n";
  glslHeader += "layout(binding = 1) uniform sampler2D u_planeY;\n";
  glslHeader += "layout(binding = 2) uniform sampler2D u_planeUV;\n\n";

  glslHeader += R"(
vec3 applyBlendMode(vec3 src, vec3 dst, int mode) {
    if (mode == 1) return src * dst;
    if (mode == 2) return vec3(1.0) - (vec3(1.0) - src) * (vec3(1.0) - dst);
    if (mode == 3) {
        return vec3(
            (dst.r < 0.5) ? (2.0 * src.r * dst.r) : (1.0 - 2.0 * (1.0 - src.r) * (1.0 - dst.r)),
            (dst.g < 0.5) ? (2.0 * src.g * dst.g) : (1.0 - 2.0 * (1.0 - src.g) * (1.0 - dst.g)),
            (dst.b < 0.5) ? (2.0 * src.b * dst.b) : (1.0 - 2.0 * (1.0 - src.b) * (1.0 - dst.b))
        );
    }
    if (mode == 4) return min(src, dst);
    if (mode == 5) return max(src, dst);
    if (mode == 6) return min(src + dst, vec3(1.0));
    if (mode == 7) return abs(dst - src);
    return src;
}
)";

  QString customUniforms;
  for (const auto &node : m_nodes) {
    QString uniforms = node->generateGlslUniforms();
    if (!uniforms.isEmpty() && !customUniforms.contains(uniforms)) {
      customUniforms += uniforms + "\n";
    }
  }

  glslHeader += customUniforms + "\n";

  QString pushConstantGLSL = "layout(push_constant) uniform PushConstants {\n";
  uint32_t currentByteOffset = 0;

  for (const auto &node : m_nodes) {
    QString cleanNodeId = sanitizeGlslId(node->id());

    for (const auto &inputSocket : node->inputs()) {
      if (inputSocket.dataType != SocketDataType::Image) {
        uint32_t size = inputSocket.byteSize();
        uint32_t align = inputSocket.byteAlignment();
        currentByteOffset = alignTo(currentByteOffset, align);

        QString cleanSocketId = sanitizeGlslId(inputSocket.id);

        PushConstantMember member;
        member.nodeId = node->id();
        member.propertyKey = inputSocket.id;
        member.fullKey = node->id() + "_" + inputSocket.id;
        member.offsetBytes = currentByteOffset;
        member.sizeBytes = size;
        member.dataType = inputSocket.dataType;
        member.defaultValue = inputSocket.defaultValue;

        result.pushConstants.members.push_back(member);

        pushConstantGLSL +=
            QString("  %1 pc_%2_%3;\n")
                .arg(inputSocket.glslTypeName(), cleanNodeId, cleanSocketId);

        currentByteOffset += size;
      }
    }
  }

  result.pushConstants.totalSizeBytes = alignTo(currentByteOffset, 16);
  pushConstantGLSL += "} u_push;\n\n";

  QString glslBody = "void main() {\n";
  glslBody += "  ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);\n";
  glslBody += "  ivec2 imgSize = imageSize(u_outputFrame);\n";
  glslBody +=
      "  if (pixelCoord.x >= imgSize.x || pixelCoord.y >= imgSize.y) return;\n";
  glslBody += "  vec2 uv = (vec2(pixelCoord) + vec2(0.5)) / vec2(imgSize);\n\n";

  std::unordered_map<QString, QString> variableMap;

  for (size_t i = 0; i < sequence.size(); ++i) {
    const auto &node = sequence[i];
    QString cleanNodeId = sanitizeGlslId(node->id());
    QString outputVar = QString("v_%1_out").arg(cleanNodeId);

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

      if (!foundLink) {
        if (inSocket.dataType == SocketDataType::Image) {
          inputVars[inSocket.id] = "vec4(0.0)";
        } else {
          QString cleanSocketId = sanitizeGlslId(inSocket.id);
          inputVars[inSocket.id] =
              QString("u_push.pc_%1_%2").arg(cleanNodeId, cleanSocketId);
        }
      }
    }

    glslBody += QString("  // Node: %1 (%2)\n").arg(node->name(), cleanNodeId);
    glslBody += node->generateGlslCode(inputVars, outputVar);

    for (const auto &outSocket : node->outputs()) {
      variableMap[node->id() + "_" + outSocket.id] = outputVar;
    }
  }

  // Anchor compositing strictly to OutputNode
  if (outputNode) {
    QString outCleanId = sanitizeGlslId(outputNode->id());
    QString outVarKey = outputNode->id() + "_video_out";
    QString finalSrcColor =
        variableMap.count(outVarKey) ? variableMap[outVarKey] : "vec4(0.0)";

    glslBody += QString("  vec4 srcColor = %1;\n").arg(finalSrcColor);
    glslBody += "  vec4 dstColor = imageLoad(u_outputFrame, pixelCoord);\n";
    glslBody +=
        QString("  int bMode = u_push.pc_%1_blendMode;\n").arg(outCleanId);

    glslBody += R"(
  if (srcColor.a > 0.0001) {
    vec3 blendedRgb = applyBlendMode(srcColor.rgb, dstColor.rgb, bMode);
    float outAlpha = srcColor.a + dstColor.a * (1.0 - srcColor.a);
    vec3 outRgb = (outAlpha > 0.0001) 
        ? (blendedRgb * srcColor.a + dstColor.rgb * dstColor.a * (1.0 - srcColor.a)) / outAlpha 
        : vec3(0.0);
    imageStore(u_outputFrame, pixelCoord, vec4(outRgb, outAlpha));
  }
)";
  }

  glslBody += "}\n";

  result.glslSource =
      glslHeader +
      (result.pushConstants.members.empty() ? "" : pushConstantGLSL) + glslBody;

  m_cachedCompiledShader = result;
  m_shaderDirty = false;
  return result;
}

QVariantMap NodeGraph::extractDefaultProperties() const {
  QVariantMap defaults;
  for (const auto &node : m_nodes) {
    if (!node)
      continue;
    for (const auto &input : node->inputs()) {
      if (input.dataType == SocketDataType::Image)
        continue;

      QVariant v = node->toVariantMap()["properties"].toMap().value(input.id);
      if (v.isValid()) {
        defaults[node->id() + "_" + input.id] = v;
        if (!defaults.contains(input.id)) {
          defaults[input.id] = v;
        }
      }
    }
  }
  return defaults;
}

QVariantList NodeGraph::listEditorNodes() const {
  QVariantList list;
  for (const auto &n : m_nodes) {
    if (n && n->hasCustomEditor()) {
      QVariantMap m;
      m["id"] = n->id();
      m["name"] = n->name();
      m["typeName"] = n->typeName();
      m["category"] = n->editorCategory();
      m["icon"] = n->editorIcon();
      m["qmlUrl"] = n->customEditorQmlUrl();
      list.append(m);
    }
  }
  return list;
}

QString NodeGraph::defaultEditorNodeId() const {
  for (const auto &n : m_nodes) {
    if (n && n->hasCustomEditor()) {
      return n->id();
    }
  }
  return "";
}

QVariantList NodeGraph::toVariantList() const {
  QVariantList list;
  for (const auto &node : m_nodes) {
    if (node) {
      list.append(node->toVariantMap());
    }
  }
  return list;
}

QVariantList NodeGraph::linksToVariantList() const {
  QVariantList list;
  for (const auto &link : m_links) {
    QVariantMap linkMap;
    linkMap["fromNodeId"] = link.fromNodeId;
    linkMap["fromSocketId"] = link.fromSocketId;
    linkMap["toNodeId"] = link.toNodeId;
    linkMap["toSocketId"] = link.toSocketId;
    list.append(linkMap);
  }
  return list;
}

std::shared_ptr<NodeGraph>
NodeGraph::createDefaultClipGraph(const QString &assetId) {
  auto graph = std::make_shared<NodeGraph>();
  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

  auto srcNode =
      std::make_shared<SourceNode>(prefix + "_src", "Video In", assetId);
  srcNode->setPosition(-300.0, 0.0);

  auto xformNode =
      std::make_shared<TransformNode>(prefix + "_xform", "Transform");
  xformNode->setPosition(-100.0, 0.0);

  auto gradeNode =
      std::make_shared<ColorGradeNode>(prefix + "_grade", "Color Grade");
  gradeNode->setPosition(100.0, 0.0);

  auto outNode = std::make_shared<OutputNode>(prefix + "_out", "Video Out");
  outNode->setPosition(300.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(xformNode);
  graph->addNode(gradeNode);
  graph->addNode(outNode);

  graph->connectSockets(srcNode->id(), "video_out", xformNode->id(),
                        "video_in");
  graph->connectSockets(xformNode->id(), "video_out", gradeNode->id(),
                        "video_in");
  graph->connectSockets(gradeNode->id(), "video_out", outNode->id(),
                        "video_in");

  return graph;
}

} // namespace xyla::render
