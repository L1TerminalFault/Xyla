#include "nodeGraph.hpp"
#include "core/render/nodes/colorGradeNode.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/sourceNode.hpp"
#include "core/render/nodes/transformNode.hpp"
#include "nodes/utilityNodes.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUuid>
#include <algorithm>
#include <queue>
#include <unordered_map>
#include <unordered_set>

namespace xyla::render {

std::unordered_map<QString, NodeGraph::NodeFactory> NodeGraph::s_nodeRegistry;

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

QJsonValue socketValueToJson(const SocketValue &val) {
  return std::visit(
      [](auto &&arg) -> QJsonValue {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, std::monostate>) {
          return QJsonValue(QJsonValue::Null);
        } else if constexpr (std::is_same_v<T, float> ||
                             std::is_same_v<T, double>) {
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

SocketValue jsonToSocketValue(const QJsonValue &json) {
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

} // namespace

NodeGraph::NodeGraph()
    : m_graphId(QUuid::createUuid().toString(QUuid::WithoutBraces)),
      m_name("Node Graph"), m_isReadOnly(false) {}

NodeGraph::NodeGraph(QString graphId, QString name)
    : m_graphId(std::move(graphId)), m_name(std::move(name)),
      m_isReadOnly(false) {}

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
    if (n && n->id() == nodeId)
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

void NodeGraph::bindAnimationManager(const QString &clipId,
                                     anim::AnimationManager &animMgr) {
  for (const auto &node : m_nodes) {
    if (node) {
      node->bindAnimationManager(clipId, animMgr);
    }
  }
}

RenderContext
NodeGraph::resolveDemandContext(const RenderContext &outputCtx) const {
  auto sequence = compileExecutionSequence();
  RenderContext current = outputCtx;

  for (auto it = sequence.rbegin(); it != sequence.rend(); ++it) {
    if (*it) {
      for (const auto &inSocket : (*it)->inputs()) {
        current = (*it)->queryInputContext(inSocket.id, current);
      }
    }
  }

  return current;
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
  glslHeader += "layout(binding = 0, rgba16f) uniform image2D u_outputFrame;\n";
  glslHeader += "layout(binding = 1) uniform sampler2D u_planeY;\n";
  glslHeader += "layout(binding = 2) uniform sampler2D u_planeUV;\n";
  glslHeader += "layout(binding = 3) uniform sampler2D u_sourceRgba;\n\n";

  QString paramBufferGLSL =
      "layout(binding = 4, std430) readonly buffer GraphParameters {\n";

  uint32_t currentByteOffset = 0;

  for (const auto &node : sequence) {
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
        member.handle = node->propertyHandle(inputSocket.id);

        result.pushConstants.members.push_back(member);

        paramBufferGLSL +=
            QString("  %1 pc_%2_%3;\n")
                .arg(inputSocket.glslTypeName(), cleanNodeId, cleanSocketId);
        currentByteOffset += size;
      }
    }
  }

  result.pushConstants.totalSizeBytes = alignTo(currentByteOffset, 16);
  paramBufferGLSL += "} u_params;\n\n";

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
  glslBody +=
      "  vec2 sampleUv = (vec2(pixelCoord) + vec2(0.5)) / vec2(imgSize);\n";

  std::unordered_map<QString, QString> variableMap;
  std::unordered_map<QString, QString> samplingFuncMap;

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
          if (samplingFuncMap.count(srcVarKey)) {
            inputVars[inSocket.id + "_func"] = samplingFuncMap[srcVarKey];
          }
          break;
        }
      }

      if (!foundLink) {
        if (inSocket.dataType == SocketDataType::Image) {
          inputVars[inSocket.id] = "vec4(0.0)";
          inputVars[inSocket.id + "_func"] = "";
        } else {
          QString cleanSocketId = sanitizeGlslId(inSocket.id);
          inputVars[inSocket.id] =
              QString("u_params.pc_%1_%2").arg(cleanNodeId, cleanSocketId);
        }
      }
    }

    glslBody += QString("  // Node: %1 (%2)\n").arg(node->name(), cleanNodeId);

    if (node->typeName() == "SourceNode") {
      samplingFuncMap[node->id() + "_video_out"] =
          QString("sample_%1").arg(cleanNodeId);
      glslBody += QString("  vec4 %1 = (sampleUv.x >= 0.0 && sampleUv.x <= 1.0 "
                          "&& sampleUv.y >= 0.0 && sampleUv.y <= 1.0) ? "
                          "sample_%2(sampleUv) : vec4(0.0);\n")
                      .arg(outputVar, cleanNodeId);
    } else if (node->typeName() == "OutputNode") {
      // OutputNode is the sink terminal node; it doesn't generate intermediate
      // code
    } else {
      glslBody += node->generateGlslCode(inputVars, outputVar);
    }

    for (const auto &outSocket : node->outputs()) {
      variableMap[node->id() + "_" + outSocket.id] = outputVar;
    }
  }

  QString finalSrcColor = "vec4(0.0)";
  for (const auto &link : m_links) {
    if (link.toNodeId == outputNode->id() && link.toSocketId == "video_in") {
      QString srcVarKey = link.fromNodeId + "_" + link.fromSocketId;
      if (variableMap.count(srcVarKey)) {
        finalSrcColor = variableMap[srcVarKey];
      }
      break;
    }
  }

  glslBody += QString("  vec4 srcColor = %1;\n").arg(finalSrcColor);
  glslBody += "  vec4 dstColor = imageLoad(u_outputFrame, pixelCoord);\n";
  glslBody +=
      "  float outAlpha = srcColor.a + dstColor.a * (1.0 - srcColor.a);\n";
  glslBody += "  vec3 outRgb = (outAlpha > 0.0001) "
              "? (srcColor.rgb * srcColor.a + dstColor.rgb * dstColor.a * (1.0 "
              "- srcColor.a)) / outAlpha "
              ": vec3(0.0);\n";
  glslBody += "  imageStore(u_outputFrame, pixelCoord, vec4(outRgb, "
              "max(outAlpha, 1.0)));\n";
  glslBody += "}\n";

  result.glslSource = glslHeader + paramBufferGLSL + customUniforms + glslBody;
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

void NodeGraph::registerNodeType(const QString &typeName, NodeFactory factory) {
  s_nodeRegistry[typeName] = std::move(factory);
}

std::shared_ptr<Node> NodeGraph::createNodeByType(const QString &typeName,
                                                  const QString &id,
                                                  const QString &name) {
  auto it = s_nodeRegistry.find(typeName);
  if (it != s_nodeRegistry.end()) {
    return it->second(id, name);
  }

  if (typeName == "SourceNode" ||
      typeName.compare("VideoIn", Qt::CaseInsensitive) == 0)
    return std::make_shared<SourceNode>(id, name, "");

  if (typeName == "OutputNode" ||
      typeName.compare("VideoOut", Qt::CaseInsensitive) == 0)
    return std::make_shared<OutputNode>(id, name);

  if (typeName == "Transform" || typeName == "TransformNode")
    return std::make_shared<TransformNode>(id,
                                           name.isEmpty() ? "Transform" : name);

  if (typeName == "ColorGrade" || typeName == "ColorGradeNode" ||
      typeName == "Color Grade")
    return std::make_shared<ColorGradeNode>(id, name.isEmpty() ? "Color Grade"
                                                               : name);

  if (typeName == "Reroute")
    return std::make_shared<RerouteNode>(id, name.isEmpty() ? "Reroute" : name);

  if (typeName == "CommentNode" || typeName == "Comment")
    return std::make_shared<CommentNode>(id, name.isEmpty() ? "Notes" : name);

  return nullptr;
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

QJsonObject NodeGraph::serialize() const {
  QJsonObject root;
  root["graphId"] = m_graphId;
  root["name"] = m_name;
  root["isReadOnly"] = m_isReadOnly;

  QJsonArray nodesArr;
  for (const auto &node : m_nodes) {
    if (!node)
      continue;
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
      for (const auto &mId : g->memberNodeIds())
        membersArr.append(mId);
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
    if (!node)
      continue;

    node->setPosition(px, py);

    if (auto c = std::dynamic_pointer_cast<CommentNode>(node)) {
      c->setText(nObj.value("commentText").toString("Notes"));
      c->setDimensions(nObj.value("boxWidth").toDouble(300.0),
                       nObj.value("boxHeight").toDouble(200.0));
    } else if (auto g = std::dynamic_pointer_cast<GroupNode>(node)) {
      g->setCollapsed(nObj.value("isCollapsed").toBool(false));
      QStringList members;
      QJsonArray mArr = nObj.value("memberNodeIds").toArray();
      for (const auto &mv : mArr)
        members.append(mv.toString());
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
    connectSockets(lObj["fromNodeId"].toString(),
                   lObj["fromSocketId"].toString(), lObj["toNodeId"].toString(),
                   lObj["toSocketId"].toString());
  }

  markDirty();
  return true;
}

} // namespace xyla::render
