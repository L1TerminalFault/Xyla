#include "nodeGraph.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/sourceNode.hpp"
#include "nodes/transformNode.hpp"
#include <QRegularExpression>
#include <QUuid>
#include <algorithm>
#include <queue>
#include <unordered_map>

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

uint32_t getDataTypeSizeBytes(SocketDataType type) noexcept {
  switch (type) {
  case SocketDataType::Float:
    return 4;
  case SocketDataType::Vec2:
    return 8;
  case SocketDataType::Color:
    return 16;
  case SocketDataType::Mat4:
    return 64;
  case SocketDataType::Int:
    return 4;
  case SocketDataType::Bool:
    return 4;
  case SocketDataType::Image:
    return 0;
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

QString socketDataTypeToString(SocketDataType type) {
  switch (type) {
  case SocketDataType::Image:
    return "Image";
  case SocketDataType::Float:
    return "Float";
  case SocketDataType::Vec2:
    return "Vec2";
  case SocketDataType::Color:
    return "Color";
  case SocketDataType::Mat4:
    return "Mat4";
  case SocketDataType::Int:
    return "Int";
  case SocketDataType::Bool:
    return "Bool";
  }
  return "Float";
}

QVariant socketValueToVariant(const SocketValue &val) {
  return std::visit(
      [](auto &&arg) -> QVariant {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, std::monostate>) {
          return QVariant();
        } else if constexpr (std::is_same_v<T, float>) {
          return QVariant::fromValue(arg);
        } else if constexpr (std::is_same_v<T, Vec2Val>) {
          QVariantList list;
          list.append(arg[0]);
          list.append(arg[1]);
          return list;
        } else if constexpr (std::is_same_v<T, ColorVal>) {
          QVariantList list;
          list.append(arg[0]);
          list.append(arg[1]);
          list.append(arg[2]);
          list.append(arg[3]);
          return list;
        } else if constexpr (std::is_same_v<T, int32_t>) {
          return QVariant::fromValue(arg);
        } else if constexpr (std::is_same_v<T, bool>) {
          return QVariant::fromValue(arg);
        } else if constexpr (std::is_same_v<T, QString>) {
          return QVariant::fromValue(arg);
        }
        return QVariant();
      },
      val);
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

QVariantList NodeGraph::toVariantList() const {
  QVariantList list;
  for (const auto &node : m_nodes) {
    if (!node)
      continue;

    QVariantMap nodeMap;
    nodeMap["id"] = node->id();
    nodeMap["name"] = node->name();
    nodeMap["typeName"] = node->typeName();
    nodeMap["x"] = node->positionX();
    nodeMap["y"] = node->positionY();

    QVariantList inputsList;
    for (const auto &inSocket : node->inputs()) {
      QVariantMap sMap;
      sMap["id"] = inSocket.id;
      sMap["name"] = inSocket.name;
      sMap["dataTypeName"] = socketDataTypeToString(inSocket.dataType);
      sMap["defaultValue"] = socketValueToVariant(inSocket.defaultValue);
      inputsList.append(sMap);
    }
    nodeMap["inputs"] = inputsList;

    QVariantList outputsList;
    for (const auto &outSocket : node->outputs()) {
      QVariantMap sMap;
      sMap["id"] = outSocket.id;
      sMap["name"] = outSocket.name;
      sMap["dataTypeName"] = socketDataTypeToString(outSocket.dataType);
      sMap["defaultValue"] = socketValueToVariant(outSocket.defaultValue);
      outputsList.append(sMap);
    }
    nodeMap["outputs"] = outputsList;

    list.append(nodeMap);
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

  return sequence;
}

CompiledGraphShader NodeGraph::compileFusedShader() const {
  if (!m_shaderDirty && !m_cachedCompiledShader.glslSource.isEmpty()) {
    return m_cachedCompiledShader;
  }

  CompiledGraphShader result;
  auto sequence = compileExecutionSequence();

  if (sequence.empty()) {
    return result;
  }

  QString glslHeader = "#version 450\n";
  glslHeader +=
      "layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;\n";
  glslHeader += "layout(binding = 0, rgba8) uniform image2D u_outputFrame;\n";

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
  for (const auto &node : sequence) {
    QString uniforms = node->generateGlslUniforms();
    if (!uniforms.isEmpty()) {
      if (!customUniforms.contains(uniforms)) {
        customUniforms += uniforms + "\n";
      }
    }
  }

  if (customUniforms.isEmpty()) {
    glslHeader += "layout(binding = 1) uniform sampler2D u_inputFrame;\n\n";
  } else {
    glslHeader += customUniforms + "\n";
  }

  QString pushConstantGLSL = "layout(push_constant) uniform PushConstants {\n";
  uint32_t currentByteOffset = 0;
  QString transformNodeCleanId = "";

  for (const auto &node : sequence) {
    QString cleanNodeId = sanitizeGlslId(node->id());
    if (node->typeName() == "TransformNode") {
      transformNodeCleanId = cleanNodeId;
    }

    for (const auto &inputSocket : node->inputs()) {
      if (inputSocket.frameOffset < 0) {
        result.hasTemporalOffset = true;
      }

      if (inputSocket.dataType != SocketDataType::Image) {
        uint32_t size = getDataTypeSizeBytes(inputSocket.dataType);
        uint32_t align = getDataTypeAlignment(inputSocket.dataType);
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

        pushConstantGLSL += QString("  %1 pc_%2_%3;\n")
                                .arg(inputSocket.glslTypeName())
                                .arg(cleanNodeId)
                                .arg(cleanSocketId);

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

      if (!foundLink && inSocket.dataType != SocketDataType::Image) {
        QString cleanSocketId = sanitizeGlslId(inSocket.id);
        inputVars[inSocket.id] =
            QString("u_push.pc_%1_%2").arg(cleanNodeId).arg(cleanSocketId);
      }
    }

    glslBody +=
        QString("  // Node: %1 (%2)\n").arg(node->name()).arg(cleanNodeId);
    glslBody += node->generateGlslCode(inputVars, outputVar);

    for (const auto &outSocket : node->outputs()) {
      variableMap[node->id() + "_" + outSocket.id] = outputVar;
    }
  }

  QString lastOutputVar = sequence.back()->id() + "_tex_out";
  if (variableMap.count(lastOutputVar)) {
    glslBody +=
        QString("  vec4 srcColor = %1;\n").arg(variableMap[lastOutputVar]);
    glslBody += "  vec4 dstColor = imageLoad(u_outputFrame, pixelCoord);\n";

    if (!transformNodeCleanId.isEmpty()) {
      glslBody += QString("  int bMode = u_push.pc_%1_blendMode;\n")
                      .arg(transformNodeCleanId);
    } else {
      glslBody += "  int bMode = 0;\n";
    }

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

std::shared_ptr<NodeGraph>
NodeGraph::createDefaultClipGraph(const QString &assetId) {
  auto graph = std::make_shared<NodeGraph>();
  QString uniquePrefix =
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

  auto srcNode = std::make_shared<SourceNode>(uniquePrefix + "_src",
                                              "Media Source", assetId);
  srcNode->setPosition(-220.0, 0.0);

  auto xformNode = std::make_shared<TransformNode>(uniquePrefix + "_xform",
                                                   "Transform / Opacity");
  xformNode->setPosition(0.0, 0.0);

  auto outNode =
      std::make_shared<OutputNode>(uniquePrefix + "_out", "Clip Output");
  outNode->setPosition(220.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(xformNode);
  graph->addNode(outNode);

  graph->connectSockets(srcNode->id(), "tex_out", xformNode->id(), "tex_in");
  graph->connectSockets(xformNode->id(), "tex_out", outNode->id(), "tex_in");

  return graph;
}

} // namespace xyla::render
