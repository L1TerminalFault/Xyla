#include "nodeGraph.hpp"
#include "nodes/outputNode.hpp"
#include "nodes/sourceNode.hpp"
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
    if (link.toNodeId != toNode) {
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

  if (!outputNode) {
    return {};
  }

  QString glslHeader = "#version 450\n";
  glslHeader +=
      "layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;\n";
  glslHeader += "layout(binding = 0, rgba8) uniform image2D u_outputFrame;\n";
  glslHeader += "layout(binding = 1) uniform sampler2D u_planeY;\n";
  glslHeader += "layout(binding = 2) uniform sampler2D u_planeUV;\n\n";

  QString pushConstantGLSL = "layout(push_constant) uniform PushConstants {\n";
  pushConstantGLSL += "  vec4 lift;\n";
  pushConstantGLSL += "  vec4 gamma;\n";
  pushConstantGLSL += "  vec4 gain;\n";
  pushConstantGLSL += "  vec4 offset;\n";
  pushConstantGLSL += "  vec2 position;\n";
  pushConstantGLSL += "  vec2 scale;\n";
  pushConstantGLSL += "  vec2 anchor;\n";
  pushConstantGLSL += "  float rotation;\n";
  pushConstantGLSL += "  float opacity;\n";
  pushConstantGLSL += "  float temperature;\n";
  pushConstantGLSL += "  float tint;\n";
  pushConstantGLSL += "  float contrast;\n";
  pushConstantGLSL += "  float pivot;\n";
  pushConstantGLSL += "  float midDetail;\n";
  pushConstantGLSL += "  float colorBoost;\n";
  pushConstantGLSL += "  float shadows;\n";
  pushConstantGLSL += "  float highlights;\n";
  pushConstantGLSL += "  float saturation;\n";
  pushConstantGLSL += "  float hue;\n";
  pushConstantGLSL += "  float lumMix;\n";
  pushConstantGLSL += "  int blendMode;\n";

  auto registerIntrinsicMember = [&](const QString &key, SocketDataType type,
                                     uint32_t size, uint32_t align,
                                     uint32_t &offset) {
    offset = alignTo(offset, align);
    PushConstantMember m;
    m.nodeId = "intrinsic";
    m.propertyKey = key;
    m.fullKey = key;
    m.offsetBytes = offset;
    m.sizeBytes = size;
    m.dataType = type;
    result.pushConstants.members.push_back(m);
    offset += size;
  };

  uint32_t currentByteOffset = 0;
  registerIntrinsicMember("lift", SocketDataType::Color, 16, 16,
                          currentByteOffset);
  registerIntrinsicMember("gamma", SocketDataType::Color, 16, 16,
                          currentByteOffset);
  registerIntrinsicMember("gain", SocketDataType::Color, 16, 16,
                          currentByteOffset);
  registerIntrinsicMember("offset", SocketDataType::Color, 16, 16,
                          currentByteOffset);

  registerIntrinsicMember("position", SocketDataType::Vec2, 8, 8,
                          currentByteOffset);
  registerIntrinsicMember("scale", SocketDataType::Vec2, 8, 8,
                          currentByteOffset);
  registerIntrinsicMember("anchor", SocketDataType::Vec2, 8, 8,
                          currentByteOffset);

  registerIntrinsicMember("rotation", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("opacity", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("temperature", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("tint", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("contrast", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("pivot", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("midDetail", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("colorBoost", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("shadows", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("highlights", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("saturation", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("hue", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("lumMix", SocketDataType::Float, 4, 4,
                          currentByteOffset);
  registerIntrinsicMember("blendMode", SocketDataType::Int, 4, 4,
                          currentByteOffset);

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

  QString helperFunctions = R"(
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

vec3 applyIntrinsicColorGrade(vec3 rgb, vec2 uv, ivec2 imgSize) {
    rgb.r += u_push.temperature * 0.08;
    rgb.b -= u_push.temperature * 0.08;
    rgb.g += u_push.tint * 0.08;

    vec3 liftVal = u_push.lift.rgb;
    vec3 gammaVal = max(u_push.gamma.rgb, vec3(0.01));
    vec3 gainVal = u_push.gain.rgb;
    vec3 offsetVal = u_push.offset.rgb;

    rgb = gainVal * (rgb + liftVal * (vec3(1.0) - rgb));
    rgb = max(rgb, vec3(0.0));
    rgb = pow(rgb, vec3(1.0) / gammaVal) + offsetVal;

    float origLuma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb += (1.0 - smoothstep(0.0, 0.5, origLuma)) * u_push.shadows * 0.35;
    rgb += smoothstep(0.5, 1.0, origLuma) * u_push.highlights * 0.35;

    vec2 texel = 1.0 / vec2(imgSize);
    float lumaN = texture(u_planeY, uv + vec2(0.0, texel.y)).r;
    float lumaS = texture(u_planeY, uv - vec2(0.0, texel.y)).r;
    float lumaE = texture(u_planeY, uv + vec2(texel.x, 0.0)).r;
    float lumaW = texture(u_planeY, uv - vec2(texel.x, 0.0)).r;
    float lumaCenter = texture(u_planeY, uv).r;
    float highPassLaplacian = (lumaCenter * 4.0) - (lumaN + lumaS + lumaE + lumaW);
    float midWeight = smoothstep(0.1, 0.4, origLuma) * (1.0 - smoothstep(0.6, 0.9, origLuma));
    rgb += vec3(highPassLaplacian) * midWeight * u_push.midDetail * 3.5;

    rgb = (rgb - vec3(u_push.pivot)) * u_push.contrast + vec3(u_push.pivot);

    float maxC = max(rgb.r, max(rgb.g, rgb.b));
    float minC = min(rgb.r, min(rgb.g, rgb.b));
    float currentSat = (maxC - minC) / max(maxC, 0.001);
    float boostFactor = (1.0 - currentSat) * u_push.colorBoost * 0.02;
    float satMultiplier = max(0.0, (u_push.saturation / 50.0) + boostFactor);

    float finalLuma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 satRgb = mix(vec3(finalLuma), rgb, satMultiplier);

    return mix(vec3(finalLuma), satRgb, u_push.lumMix * 0.01);
}
)";

  QString customUniforms;
  for (const auto &node : m_nodes) {
    QString uniforms = node->generateGlslUniforms();
    if (!uniforms.isEmpty() && !customUniforms.contains(uniforms)) {
      customUniforms += uniforms + "\n";
    }
  }

  QString glslBody = "void main() {\n";
  glslBody += "  ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);\n";
  glslBody += "  ivec2 imgSize = imageSize(u_outputFrame);\n";
  glslBody += "  if (pixelCoord.x >= imgSize.x || pixelCoord.y >= imgSize.y) "
              "return;\n\n";

  glslBody += R"(
  vec2 uv = (vec2(pixelCoord) + vec2(0.5)) / vec2(imgSize);
  vec2 p = uv - vec2(0.5) - vec2(u_push.position.x, -u_push.position.y);

  ivec2 vidSize = textureSize(u_planeY, 0);
  float canvasAspect = float(imgSize.x) / float(imgSize.y);
  float videoAspect = (vidSize.y > 0) ? float(vidSize.x) / float(vidSize.y) : canvasAspect;
  p.x *= canvasAspect;

  float rad = radians(-u_push.rotation);
  float cosR = cos(rad);
  float sinR = sin(rad);
  vec2 rotated = vec2(cosR * p.x - sinR * p.y, sinR * p.x + cosR * p.y);

  rotated.x /= videoAspect;

  vec2 scaled = rotated / max(u_push.scale, vec2(0.0001));
  vec2 sampleUv = scaled + vec2(0.5) - u_push.anchor;
)";

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

    if (node->typeName() == "SourceNode") {
      glslBody += QString("  vec4 %1 = (sampleUv.x >= 0.0 && sampleUv.x <= 1.0 "
                          "&& sampleUv.y >= 0.0 && sampleUv.y <= 1.0) ? "
                          "sample_%2(sampleUv) : vec4(0.0);\n")
                      .arg(outputVar, cleanNodeId);
    } else {
      glslBody += node->generateGlslCode(inputVars, outputVar);
    }

    for (const auto &outSocket : node->outputs()) {
      variableMap[node->id() + "_" + outSocket.id] = outputVar;
    }
  }

  QString outVarKey = outputNode->id() + "_video_out";
  QString finalSrcColor =
      variableMap.count(outVarKey) ? variableMap[outVarKey] : "vec4(0.0)";

  glslBody += QString("  vec4 srcColor = %1;\n").arg(finalSrcColor);
  glslBody += "  srcColor.rgb = applyIntrinsicColorGrade(srcColor.rgb, "
              "sampleUv, imgSize);\n";
  glslBody += "  srcColor.a *= u_push.opacity;\n\n";

  glslBody += "  vec4 dstColor = imageLoad(u_outputFrame, pixelCoord);\n";
  glslBody += "  int bMode = u_push.blendMode;\n";

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

  glslBody += "}\n";

  result.glslSource = glslHeader + pushConstantGLSL + helperFunctions +
                      customUniforms + glslBody;
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
  srcNode->setPosition(-150.0, 0.0);

  auto outNode = std::make_shared<OutputNode>(prefix + "_out", "Video Out");
  outNode->setPosition(150.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(outNode);

  graph->connectSockets(srcNode->id(), "video_out", outNode->id(), "video_in");

  return graph;
}

} // namespace xyla::render



// WARNING:
#include "nodes/utilityNodes.hpp"
#include <QJsonArray>
#include <QJsonObject>
#include <QUuid>

namespace xyla::render {

// --- Constructors ---
NodeGraph::NodeGraph()
    : m_graphId(QUuid::createUuid().toString(QUuid::WithoutBraces)),
      m_name("Node Graph"), m_isReadOnly(false) {}

NodeGraph::NodeGraph(QString graphId, QString name)
    : m_graphId(std::move(graphId)), m_name(std::move(name)), m_isReadOnly(false) {}

// --- Node Factory Helper for Deserialization ---
static std::shared_ptr<Node> createNodeByType(const QString &typeName, const QString &id, const QString &name) {
  if (typeName == "SourceNode") return std::make_shared<SourceNode>(id, name, "");
  if (typeName == "OutputNode") return std::make_shared<OutputNode>(id, name);
  if (typeName == "Reroute") return std::make_shared<RerouteNode>(id, name);
  if (typeName == "CommentNode") return std::make_shared<CommentNode>(id, name);
  if (typeName == "GroupNode") return std::make_shared<GroupNode>(id, name);
  return nullptr;
}

// =============================================================================
// Helper: Convert std::variant SocketValue to QJsonValue
// =============================================================================
static QJsonValue socketValueToJson(const SocketValue &val) {
  return std::visit(
      [](auto &&arg) -> QJsonValue {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, std::monostate>) {
          return QJsonValue(QJsonValue::Null);
        } else if constexpr (std::is_same_v<T, float> || std::is_same_v<T, double>) {
          return QJsonValue(static_cast<double>(arg));
        } else if constexpr (std::is_same_v<T, int>) {
          return QJsonValue(arg);
        } else if constexpr (std::is_same_v<T, bool>) {
          return QJsonValue(arg);
        } else if constexpr (std::is_same_v<T, QString>) {
          return QJsonValue(arg);
        } else if constexpr (std::is_same_v<T, std::array<float, 2>>) {
          QJsonArray arr;
          arr.append(static_cast<double>(arg[0]));
          arr.append(static_cast<double>(arg[1]));
          return arr;
        } else if constexpr (std::is_same_v<T, std::array<float, 4>>) {
          QJsonArray arr;
          arr.append(static_cast<double>(arg[0]));
          arr.append(static_cast<double>(arg[1]));
          arr.append(static_cast<double>(arg[2]));
          arr.append(static_cast<double>(arg[3]));
          return arr;
        } else {
          return QJsonValue();
        }
      },
      val);
}

// =============================================================================
// Helper: Convert QJsonValue to std::variant SocketValue
// =============================================================================
static SocketValue jsonToSocketValue(const QJsonValue &json) {
  if (json.isNull() || json.isUndefined()) {
    return std::monostate{};
  }
  if (json.isBool()) {
    return json.toBool();
  }
  if (json.isDouble()) {
    return json.toDouble();
  }
  if (json.isString()) {
    return json.toString();
  }
  if (json.isArray()) {
    QJsonArray arr = json.toArray();
    if (arr.size() == 2) {
      return std::array<float, 2>{static_cast<float>(arr[0].toDouble()),
                                   static_cast<float>(arr[1].toDouble())};
    }
    if (arr.size() == 4) {
      return std::array<float, 4>{static_cast<float>(arr[0].toDouble()),
                                   static_cast<float>(arr[1].toDouble()),
                                   static_cast<float>(arr[2].toDouble()),
                                   static_cast<float>(arr[3].toDouble())};
    }
  }
  return std::monostate{};
}

// --- Serialization ---
QJsonObject NodeGraph::serialize() const {
  QJsonObject root;
  root["graphId"] = m_graphId;
  root["name"] = m_name;
  root["isReadOnly"] = m_isReadOnly;

  // Nodes array
  QJsonArray nodesArr;
  for (const auto &node : m_nodes) {
    if (!node) continue;
    QJsonObject nObj;
    nObj["id"] = node->id();
    nObj["name"] = node->name();
    nObj["typeName"] = node->typeName();
    nObj["posX"] = node->positionX();
    nObj["posY"] = node->positionY();

    if (auto c = std::dynamic_pointer_cast<CommentNode>(node)) {
      nObj["commentText"] = c->text();
      nObj["boxWidth"] = c->width();
      nObj["boxHeight"] = c->height();
    } else if (auto g = std::dynamic_pointer_cast<GroupNode>(node)) {
      nObj["isCollapsed"] = g->isCollapsed();
      QJsonArray membersArr;
      for (const auto &mId : g->memberNodeIds()) membersArr.append(mId);
      nObj["memberNodeIds"] = membersArr;
    }

    QJsonObject propsObj;
    for (const auto &[k, val] : node->properties()) {
      propsObj[k] = socketValueToJson(val);
    }
    nObj["properties"] = propsObj;

    nodesArr.append(nObj);
  }
  root["nodes"] = nodesArr;

  // Links array
  QJsonArray linksArr;
  for (const auto &link : m_links) {
    QJsonObject lObj;
    lObj["fromNodeId"] = link.fromNodeId;
    lObj["fromSocketId"] = link.fromSocketId;
    lObj["toNodeId"] = link.toNodeId;
    lObj["toSocketId"] = link.toSocketId;
    linksArr.append(lObj);
  }
  root["links"] = linksArr;

  return root;
}

// --- Deserialization ---
bool NodeGraph::deserialize(const QJsonObject &root) {
  if (!root.contains("graphId") || !root.contains("nodes")) {
    return false;
  }

  m_nodes.clear();
  m_links.clear();

  m_graphId = root["graphId"].toString();
  m_name = root.value("name").toString("Imported Graph");
  m_isReadOnly = root.value("isReadOnly").toBool(false);

  QJsonArray nodesArr = root["nodes"].toArray();
  for (const auto &val : nodesArr) {
    QJsonObject nObj = val.toObject();
    QString id = nObj["id"].toString();
    QString name = nObj["name"].toString();
    QString type = nObj["typeName"].toString();
    double px = nObj["posX"].toDouble(0.0);
    double py = nObj["posY"].toDouble(0.0);

    auto node = createNodeByType(type, id, name);
    if (!node) continue;

    node->setPosition(px, py);

    if (auto c = std::dynamic_pointer_cast<CommentNode>(node)) {
      c->setText(nObj.value("commentText").toString("Notes"));
      c->setDimensions(nObj.value("boxWidth").toDouble(300.0), nObj.value("boxHeight").toDouble(200.0));
    } else if (auto g = std::dynamic_pointer_cast<GroupNode>(node)) {
      g->setCollapsed(nObj.value("isCollapsed").toBool(false));
      QStringList members;
      QJsonArray mArr = nObj.value("memberNodeIds").toArray();
      for (const auto &mv : mArr) members.append(mv.toString());
      g->setMemberNodeIds(members);
    }

    if (nObj.contains("properties")) {
      QJsonObject pObj = nObj["properties"].toObject();
      for (auto it = pObj.begin(); it != pObj.end(); ++it) {
        node->setProperty(it.key(), jsonToSocketValue(it.value()));
      }
    }

    m_nodes.push_back(node);
  }

  QJsonArray linksArr = root["links"].toArray();
  for (const auto &val : linksArr) {
    QJsonObject lObj = val.toObject();
    connectSockets(lObj["fromNodeId"].toString(), lObj["fromSocketId"].toString(),
                   lObj["toNodeId"].toString(), lObj["toSocketId"].toString());
  }

  markDirty();
  return true;
}

} // namespace xyla::render
