#include "nodeGraph.hpp"
#include "nodeGraphManager.hpp"

#include <QJsonArray>
#include <QRegularExpression>
#include <QUuid>
#include <queue>
#include <unordered_map>
#include <unordered_set>

namespace xyla::render {

namespace {

inline uint32_t alignTo(uint32_t offset, uint32_t alignment) noexcept {
  return (offset + alignment - 1) & ~(alignment - 1);
}

QString sanitizeGlslId(const QString &raw) {
  QString clean = raw;
  clean.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9]")),
                QStringLiteral("_"));
  clean.replace(QRegularExpression(QStringLiteral("_+")), QStringLiteral("_"));
  if (clean.startsWith(QLatin1Char('_')))
    clean.remove(0, 1);
  if (!clean.isEmpty() && clean.at(0).isDigit())
    clean.prepend(QStringLiteral("n_"));
  return clean;
}

} // namespace

NodeGraph::NodeGraph()
    : m_graphId(QUuid::createUuid().toString(QUuid::WithoutBraces)),
      m_name(QStringLiteral("Node Graph")) {}

NodeGraph::NodeGraph(QString graphId, QString name)
    : m_graphId(std::move(graphId)), m_name(std::move(name)) {}

void NodeGraph::addNode(std::shared_ptr<Node> node) {
  if (!node)
    return;
  m_nodes.push_back(std::move(node));
  markDirty();
}

bool NodeGraph::removeNode(const QString &nodeId) {
  const auto it =
      std::remove_if(m_nodes.begin(), m_nodes.end(),
                     [&](const auto &n) { return n && n->id() == nodeId; });
  if (it == m_nodes.end())
    return false;

  m_nodes.erase(it, m_nodes.end());
  std::erase_if(m_links, [&](const NodeLink &l) {
    return l.fromNodeId == nodeId || l.toNodeId == nodeId;
  });
  markDirty();
  return true;
}

std::shared_ptr<Node> NodeGraph::findNode(const QString &nodeId) const {
  for (const auto &node : m_nodes) {
    if (node && node->id() == nodeId)
      return node;
  }
  return nullptr;
}

bool NodeGraph::wouldIntroduceCycle(const QString &fromNode,
                                    const QString &toNode) const {
  if (fromNode == toNode)
    return true;

  std::unordered_map<QString, std::vector<QString>> adj;
  for (const auto &link : m_links) {
    adj[link.fromNodeId].push_back(link.toNodeId);
  }
  adj[fromNode].push_back(toNode);

  std::unordered_set<QString> visited;
  std::unordered_set<QString> inStack;

  const auto hasCycle = [&](auto self, const QString &curr) -> bool {
    visited.insert(curr);
    inStack.insert(curr);

    for (const auto &neighbor : adj[curr]) {
      if (inStack.contains(neighbor))
        return true;
      if (!visited.contains(neighbor) && self(self, neighbor))
        return true;
    }
    inStack.erase(curr);
    return false;
  };

  for (const auto &n : m_nodes) {
    if (!visited.contains(n->id()) && hasCycle(hasCycle, n->id())) {
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

  const auto src = findNode(fromNode);
  const auto dst = findNode(toNode);
  if (!src || !dst)
    return false;

  const auto *srcSock = src->findOutput(fromSocket);
  const auto *dstSock = dst->findInput(toSocket);
  if (!srcSock || !dstSock ||
      !NodeSocket::areCompatible(srcSock->dataType, dstSock->dataType)) {
    return false;
  }

  if (wouldIntroduceCycle(fromNode, toNode))
    return false;

  std::erase_if(m_links, [&](const NodeLink &l) {
    return l.toNodeId == toNode && l.toSocketId == toSocket;
  });

  m_links.push_back({fromNode, fromSocket, toNode, toSocket});
  markDirty();
  return true;
}

bool NodeGraph::disconnectSockets(const QString &fromNode,
                                  const QString &fromSocket,
                                  const QString &toNode,
                                  const QString &toSocket) {
  const auto count = std::erase_if(m_links, [&](const NodeLink &l) {
    return l.fromNodeId == fromNode && l.fromSocketId == fromSocket &&
           l.toNodeId == toNode && l.toSocketId == toSocket;
  });
  if (count > 0) {
    markDirty();
    return true;
  }
  return false;
}

void NodeGraph::bindAnimationManager(anim::AnimationManager &animMgr) {
  for (const auto &node : m_nodes) {
    if (node)
      node->bindAnimationManager(m_graphId, animMgr);
  }
}

void NodeGraph::setPreviewTargetNode(const QString &nodeId) {
  for (const auto &n : m_nodes) {
    if (n)
      n->setPreviewTarget(n->id() == nodeId);
  }
}

std::vector<std::shared_ptr<Node>> NodeGraph::compileExecutionSequence() const {
  std::shared_ptr<Node> targetNode = nullptr;
  for (const auto &n : m_nodes) {
    if (n && (n->isPreviewTarget() ||
              (!targetNode && n->typeName() == QStringLiteral("OutputNode")))) {
      targetNode = n;
      if (n->isPreviewTarget())
        break;
    }
  }
  if (!targetNode)
    return {};

  std::unordered_set<QString> reachable;
  std::unordered_map<QString, std::vector<QString>> reverseAdj;
  for (const auto &l : m_links) {
    reverseAdj[l.toNodeId].push_back(l.fromNodeId);
  }

  std::queue<QString> queue;
  queue.push(targetNode->id());
  reachable.insert(targetNode->id());

  while (!queue.empty()) {
    const QString curr = queue.front();
    queue.pop();
    for (const auto &prev : reverseAdj[curr]) {
      if (!reachable.contains(prev)) {
        reachable.insert(prev);
        queue.push(prev);
      }
    }
  }

  std::unordered_map<QString, int> inDegree;
  std::unordered_map<QString, std::shared_ptr<Node>> nodeMap;
  std::unordered_map<QString, std::vector<QString>> forwardAdj;

  for (const auto &n : m_nodes) {
    if (reachable.contains(n->id())) {
      nodeMap[n->id()] = n;
      inDegree[n->id()] = 0;
    }
  }

  for (const auto &l : m_links) {
    if (reachable.contains(l.fromNodeId) && reachable.contains(l.toNodeId)) {
      forwardAdj[l.fromNodeId].push_back(l.toNodeId);
      inDegree[l.toNodeId]++;
    }
  }

  std::queue<QString> kahnQueue;
  for (const auto &[id, deg] : inDegree) {
    if (deg == 0)
      kahnQueue.push(id);
  }

  std::vector<std::shared_ptr<Node>> sequence;
  sequence.reserve(nodeMap.size());
  while (!kahnQueue.empty()) {
    const QString curr = kahnQueue.front();
    kahnQueue.pop();

    if (auto it = nodeMap.find(curr); it != nodeMap.end()) {
      sequence.push_back(it->second);
    }

    for (const auto &next : forwardAdj[curr]) {
      if (--inDegree[next] == 0) {
        kahnQueue.push(next);
      }
    }
  }

  return sequence;
}

RenderContext
NodeGraph::resolvePipelineContext(const RenderContext &outputCtx) const {
  const auto sequence = compileExecutionSequence();
  if (sequence.empty())
    return outputCtx;

  RenderContext ctx = outputCtx;
  std::unordered_map<QString, PixelRect> nodeRodMap;

  for (const auto &node : sequence) {
    std::unordered_map<QString, PixelRect> inputRods;
    for (const auto &link : m_links) {
      if (link.toNodeId == node->id()) {
        inputRods[link.toSocketId] = nodeRodMap[link.fromNodeId];
      }
    }
    nodeRodMap[node->id()] = node->computeRegionOfDefinition(inputRods, ctx);
  }

  PixelRect activeRoi = outputCtx.roi;
  for (auto it = sequence.rbegin(); it != sequence.rend(); ++it) {
    const auto &node = *it;
    for (const auto &input : node->inputs()) {
      if (input.dataType == SocketDataType::Image) {
        activeRoi = node->queryInputRegionOfInterest(input.id, activeRoi, ctx);
      }
    }
  }

  ctx.roi = activeRoi;
  ctx.rod = nodeRodMap[sequence.back()->id()];
  return ctx;
}

CompiledGraphShader NodeGraph::compileFusedShader() const {
  if (!m_shaderDirty && m_cachedShader.isValid) {
    return m_cachedShader;
  }

  const auto sequence = compileExecutionSequence();
  if (sequence.empty())
    return {};

  CompiledGraphShader result;

  uint32_t currentBindingIndex = 0;
  QString header = QStringLiteral("#version 450\n");
  header += QStringLiteral(
      "layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;\n");

  // Note: Read-write image2D (without writeonly) so imageLoad + imageStore are
  // both valid
  header += QStringLiteral(
                "layout(binding = %1, rgba8) uniform image2D u_outputFrame;\n")
                .arg(currentBindingIndex++);

  for (const auto &node : sequence) {
    for (const auto &samplerName : node->declaredSamplerNames()) {
      TextureBindingDescriptor bindingDesc;
      bindingDesc.bindingIndex = currentBindingIndex++;
      bindingDesc.uniformName = samplerName;
      bindingDesc.nodeId = node->id();
      result.textureBindings.push_back(bindingDesc);

      header += QStringLiteral("layout(binding = %1) uniform sampler2D %2;\n")
                    .arg(bindingDesc.bindingIndex)
                    .arg(bindingDesc.uniformName);
    }
  }

  result.ssboBindingIndex = currentBindingIndex++;
  uint32_t currentOffset = 0;
  QString ssboDecl =
      QStringLiteral(
          "\nlayout(std430, binding = %1) readonly buffer ParameterBuffer {\n")
          .arg(result.ssboBindingIndex);

  for (const auto &node : sequence) {
    const QString cleanNodeId = sanitizeGlslId(node->id());
    for (const auto &inSocket : node->inputs()) {
      if (inSocket.dataType == SocketDataType::Image)
        continue;

      const uint32_t size = inSocket.byteSize();
      const uint32_t align = inSocket.byteAlignment();
      currentOffset = alignTo(currentOffset, align);

      const QString cleanSocketId = sanitizeGlslId(inSocket.id);
      ShaderProperty prop;
      prop.nodeId = node->id();
      prop.socketId = inSocket.id;
      prop.fullKey = QStringLiteral("%1_%2").arg(cleanNodeId, cleanSocketId);
      prop.offsetBytes = currentOffset;
      prop.sizeBytes = size;
      prop.dataType = inSocket.dataType;
      prop.handle = node->propertyHandle(inSocket.id);

      result.ssboLayout.members.push_back(prop);
      ssboDecl += QStringLiteral("  %1 %2;\n")
                      .arg(inSocket.glslTypeName(), prop.fullKey);
      currentOffset += size;
    }
  }
  result.ssboLayout.totalSizeBytes = alignTo(currentOffset, 16);
  ssboDecl += QStringLiteral("} u_params;\n\n");

  QString uniforms;
  for (const auto &node : sequence) {
    const QString u = node->generateGlslUniforms();
    if (!u.isEmpty() && !uniforms.contains(u)) {
      uniforms += u + QLatin1Char('\n');
    }
  }

  QString body = QStringLiteral("void main() {\n");
  body +=
      QStringLiteral("  ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);\n");
  body += QStringLiteral("  ivec2 imgSize = imageSize(u_outputFrame);\n");
  body += QStringLiteral("  if (pixelCoord.x >= imgSize.x || pixelCoord.y >= "
                         "imgSize.y) return;\n");
  body += QStringLiteral(
      "  vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(imgSize);\n\n");

  std::unordered_map<QString, QString> variableMap;

  for (const auto &node : sequence) {
    const QString cleanNodeId = sanitizeGlslId(node->id());
    const QString outVar = QStringLiteral("v_%1_out").arg(cleanNodeId);

    std::unordered_map<QString, QString> inputVars;
    for (const auto &inSocket : node->inputs()) {
      bool found = false;
      for (const auto &link : m_links) {
        if (link.toNodeId == node->id() && link.toSocketId == inSocket.id) {
          const QString srcKey =
              QStringLiteral("%1_%2").arg(link.fromNodeId, link.fromSocketId);
          if (auto it = variableMap.find(srcKey); it != variableMap.end()) {
            inputVars[inSocket.id] = it->second;
            found = true;
            break;
          }
        }
      }
      if (!found) {
        if (inSocket.dataType == SocketDataType::Image) {
          inputVars[inSocket.id] = QStringLiteral("vec4(0.0)");
        } else {
          inputVars[inSocket.id] =
              QStringLiteral("u_params.%1_%2")
                  .arg(cleanNodeId, sanitizeGlslId(inSocket.id));
        }
      }
    }

    body += node->generateGlslCode(inputVars, outVar);
    for (const auto &outSock : node->outputs()) {
      variableMap[QStringLiteral("%1_%2").arg(node->id(), outSock.id)] = outVar;
    }
  }

  const QString terminalKey =
      QStringLiteral("%1_video_out").arg(sequence.back()->id());
  auto terminalIt = variableMap.find(terminalKey);
  const QString terminalVar =
      (terminalIt != variableMap.end())
          ? terminalIt->second
          : QStringLiteral("v_%1_out")
                .arg(sanitizeGlslId(sequence.back()->id()));

  body += QStringLiteral("  imageStore(u_outputFrame, pixelCoord, %1);\n}\n")
              .arg(terminalVar);

  result.glslSource = header + ssboDecl + uniforms + body;
  result.isValid = true;

  m_cachedShader = result;
  m_shaderDirty = false;
  return result;
}

QString NodeGraph::generateUniqueNodeId(const QString &prefix) const {
  return QStringLiteral("%1_%2").arg(prefix,
                                     QString::number(m_nodes.size() + 1));
}

QJsonObject NodeGraph::serialize() const {
  QJsonObject root;
  root[QStringLiteral("graphId")] = m_graphId;
  root[QStringLiteral("name")] = m_name;
  root[QStringLiteral("readOnly")] = m_readOnly;

  QJsonArray nodesArr;
  for (const auto &n : m_nodes) {
    if (n)
      nodesArr.append(n->serialize());
  }
  root[QStringLiteral("nodes")] = nodesArr;

  QJsonArray linksArr;
  for (const auto &l : m_links) {
    QJsonObject lObj;
    lObj[QStringLiteral("fromNodeId")] = l.fromNodeId;
    lObj[QStringLiteral("fromSocketId")] = l.fromSocketId;
    lObj[QStringLiteral("toNodeId")] = l.toNodeId;
    lObj[QStringLiteral("toSocketId")] = l.toSocketId;
    linksArr.append(lObj);
  }
  root[QStringLiteral("links")] = linksArr;

  return root;
}

bool NodeGraph::deserialize(const QJsonObject &json,
                            NodeGraphManager &manager) {
  if (!json.contains(QStringLiteral("graphId")))
    return false;

  m_graphId = json[QStringLiteral("graphId")].toString();
  m_name = json[QStringLiteral("name")].toString(QStringLiteral("Graph"));
  m_readOnly = json[QStringLiteral("readOnly")].toBool(false);

  m_nodes.clear();
  m_links.clear();

  const QJsonArray nodesArr = json[QStringLiteral("nodes")].toArray();
  for (const auto &val : nodesArr) {
    const QJsonObject nObj = val.toObject();
    const QString typeName = nObj[QStringLiteral("typeName")].toString();
    const QString id = nObj[QStringLiteral("id")].toString();
    const QString name = nObj[QStringLiteral("name")].toString();

    auto node = manager.createNodeByType(typeName, id, name);
    if (node && node->deserialize(nObj)) {
      m_nodes.push_back(std::move(node));
    }
  }

  const QJsonArray linksArr = json[QStringLiteral("links")].toArray();
  for (const auto &val : linksArr) {
    const QJsonObject lObj = val.toObject();
    connectSockets(lObj[QStringLiteral("fromNodeId")].toString(),
                   lObj[QStringLiteral("fromSocketId")].toString(),
                   lObj[QStringLiteral("toNodeId")].toString(),
                   lObj[QStringLiteral("toSocketId")].toString());
  }

  markDirty();
  return true;
}

QVariantList
NodeGraph::toVariantList(FrameIndex frame,
                         const anim::AnimationManager *animMgr) const {
  QVariantList list;
  list.reserve(static_cast<qsizetype>(m_nodes.size()));
  for (const auto &n : m_nodes) {
    if (n)
      list.append(n->toVariantMap(frame, animMgr));
  }
  return list;
}

QVariantList NodeGraph::linksToVariantList() const {
  QVariantList list;
  list.reserve(static_cast<qsizetype>(m_links.size()));
  for (const auto &link : m_links) {
    QVariantMap map;
    map[QStringLiteral("fromNodeId")] = link.fromNodeId;
    map[QStringLiteral("fromSocketId")] = link.fromSocketId;
    map[QStringLiteral("toNodeId")] = link.toNodeId;
    map[QStringLiteral("toSocketId")] = link.toSocketId;
    list.append(map);
  }
  return list;
}

QVariantList NodeGraph::listEditorNodes() const {
  QVariantList list;
  for (const auto &n : m_nodes) {
    if (n && n->hasCustomEditor()) {
      QVariantMap m;
      m[QStringLiteral("id")] = n->id();
      m[QStringLiteral("name")] = n->name();
      m[QStringLiteral("category")] = n->editorCategory();
      m[QStringLiteral("icon")] = n->editorIcon();
      m[QStringLiteral("qmlUrl")] = n->customEditorQmlUrl();
      list.append(m);
    }
  }
  return list;
}

QString NodeGraph::defaultEditorNodeId() const {
  for (const auto &n : m_nodes) {
    if (n && n->hasCustomEditor())
      return n->id();
  }
  return {};
}

} // namespace xyla::render
