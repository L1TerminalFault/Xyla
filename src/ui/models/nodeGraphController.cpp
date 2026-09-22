#include "nodeGraphController.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodes/sourceNode.hpp"
#include "core/render/nodes/utilityNodes.hpp"
#include "timelineModel.hpp"

#include <QDebug>
#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>

namespace xyla {

namespace {

QString normalizeNodeType(const QString &typeName) {
  if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
      typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
    return QStringLiteral("SourceNode");
  }
  if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
      typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
    return QStringLiteral("OutputNode");
  }
  return typeName;
}

} // namespace

NodeGraphController::NodeGraphController(TimelineModel *timelineModel,
                                         QObject *parent)
    : QObject(parent), m_timelineModel(timelineModel) {
  auto &mgr = render::NodeGraphManager::instance();
  auto defaultGraph = mgr.getGraph(render::DEFAULT_IO_GRAPH_ID);
  if (defaultGraph) {
    m_standaloneActiveGraphId = render::DEFAULT_IO_GRAPH_ID;
  } else {
    const auto all = mgr.listAllGraphsSummary();
    if (!all.isEmpty()) {
      m_standaloneActiveGraphId = all.first().toMap().value("id").toString();
    }
  }
}

std::shared_ptr<render::NodeGraph>
NodeGraphController::resolveGraph(const QString &graphId) const {
  auto &mgr = render::NodeGraphManager::instance();

  if (!graphId.isEmpty() && mgr.hasGraph(graphId)) {
    return mgr.getGraph(graphId);
  }

  if (m_timelineModel) {
    const QString selectedClipId = m_timelineModel->getSelectedClipId();
    if (!selectedClipId.isEmpty()) {
      auto *clip = m_timelineModel->findClip(selectedClipId);
      if (clip) {
        const QString clipGraphId = clip->getActiveGraphId();
        if (!clipGraphId.isEmpty() && mgr.hasGraph(clipGraphId)) {
          return mgr.getGraph(clipGraphId);
        }
      }
    }
  }

  if (!m_standaloneActiveGraphId.isEmpty() &&
      mgr.hasGraph(m_standaloneActiveGraphId)) {
    return mgr.getGraph(m_standaloneActiveGraphId);
  }

  return mgr.defaultIOGraph();
}

QString NodeGraphController::getStandaloneActiveGraphId() const noexcept {
  return m_standaloneActiveGraphId;
}

void NodeGraphController::setStandaloneActiveGraphId(const QString &graphId) {
  if (m_standaloneActiveGraphId != graphId) {
    m_standaloneActiveGraphId = graphId;
    emit activeGraphChanged();
  }
}

bool NodeGraphController::setGraphName(const QString &graphId,
                                       const QString &name) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }

  g->setName(name);
  g->markDirty();

  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  return true;
}

bool NodeGraphController::deleteProjectGraph(const QString &graphId) {
  if (graphId == render::DEFAULT_IO_GRAPH_ID) {
    return false;
  }

  if (m_timelineModel) {
    const QVariantList allClips = m_timelineModel->getAllClips();
    for (const auto &clipVar : allClips) {
      const QVariantMap clipMap = clipVar.toMap();
      const QString clipId = clipMap.value("id").toString();
      if (!clipId.isEmpty()) {
        detachGraphFromClip(clipId, graphId);
      }
    }
  }

  bool ok = render::NodeGraphManager::instance().removeGraph(graphId);
  if (ok) {
    if (m_standaloneActiveGraphId == graphId) {
      m_standaloneActiveGraphId.clear();
      auto fallback = resolveGraph(QString());
      if (fallback) {
        m_standaloneActiveGraphId = fallback->id();
      }
    }

    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit projectGraphsChanged();
    emit activeGraphChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

QVariantList
NodeGraphController::getClipAttachedGraphs(const QString &clipId) const {
  if (!m_timelineModel) {
    return QVariantList();
  }

  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip) {
    return QVariantList();
  }

  auto &mgr = render::NodeGraphManager::instance();
  QVariantList list;

  for (const auto &graphId : clip->getNodeGraphIds()) {
    auto g = mgr.getGraph(graphId);
    QVariantMap map;
    map["id"] = graphId;
    map["name"] = g ? g->name() : graphId;
    map["isReadOnly"] = g ? g->isReadOnly() : false;
    map["isDefault"] =
        (graphId == render::DEFAULT_IO_GRAPH_ID) || (g && g->isReadOnly());
    list.append(map);
  }

  return list;
}

bool NodeGraphController::attachGraphToClip(const QString &clipId,
                                            const QString &graphId) {
  if (!m_timelineModel) {
    return false;
  }
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip) {
    return false;
  }

  clip->attachNodeGraphId(graphId);
  return true;
}

bool NodeGraphController::detachGraphFromClip(const QString &clipId,
                                              const QString &graphId) {
  if (!m_timelineModel) {
    return false;
  }
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip) {
    return false;
  }

  return clip->detachNodeGraphId(graphId);
}

QString NodeGraphController::getClipActiveGraphId(const QString &clipId) const {
  if (!m_timelineModel) {
    return render::DEFAULT_IO_GRAPH_ID;
  }
  auto *clip = m_timelineModel->findClip(clipId);
  return clip ? clip->getActiveGraphId() : render::DEFAULT_IO_GRAPH_ID;
}

bool NodeGraphController::setClipActiveGraphId(const QString &clipId,
                                               const QString &graphId) {
  if (!m_timelineModel) {
    return false;
  }
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip) {
    return false;
  }

  clip->setActiveGraphId(graphId);
  emit activeGraphChanged();
  return true;
}

bool NodeGraphController::reorderClipGraphs(
    const QString &clipId, const QVariantList &orderedGraphIds) {
  if (!m_timelineModel) {
    return false;
  }
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip) {
    return false;
  }

  QStringList list;
  for (const auto &v : orderedGraphIds) {
    list.append(v.toString());
  }
  clip->setAttachedNodeGraphIds(list);
  return true;
}

QVariantList NodeGraphController::listEditorNodes(const QString &graphId) {
  auto g = resolveGraph(graphId);
  if (g) {
    return g->listEditorNodes();
  }
  return {};
}

QString NodeGraphController::defaultEditorNodeId(const QString &graphId) {
  auto g = resolveGraph(graphId);
  if (g) {
    return g->defaultEditorNodeId();
  }
  return "";
}

QVariantList NodeGraphController::getGraphNodes(const QString &graphId) {
  auto g = resolveGraph(graphId);
  if (g) {
    return g->toVariantList();
  }
  return {};
}

QVariantList NodeGraphController::getGraphLinks(const QString &graphId) {
  auto g = resolveGraph(graphId);
  if (g) {
    return g->linksToVariantList();
  }
  return {};
}

QString NodeGraphController::addNode(const QString &graphId,
                                     const QString &typeName, double x,
                                     double y) {
  return addNodeToGraph(graphId, typeName, x, y);
}

QString NodeGraphController::addNodeToGraph(const QString &graphId,
                                            const QString &typeName, double x,
                                            double y) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    qWarning() << "[NodeGraphController] Cannot add node: target graph "
                  "unresolved or read-only";
    return "";
  }

  const QString canonicalType = normalizeNodeType(typeName);

  if (canonicalType == "OutputNode") {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "OutputNode") {
        qWarning() << "[NodeGraphController] Graph already has an OutputNode";
        return "";
      }
    }
  } else if (canonicalType == "SourceNode") {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "SourceNode") {
        qWarning() << "[NodeGraphController] Graph already has a SourceNode";
        return "";
      }
    }
  }

  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  QString newId = prefix + "_" + canonicalType.toLower();

  auto newNode = g->createNodeByType(canonicalType, newId, canonicalType);
  if (!newNode) {
    qWarning() << "[NodeGraphController] Unknown node type requested:"
               << canonicalType;
    return "";
  }

  if (auto src = std::dynamic_pointer_cast<render::SourceNode>(newNode)) {
    if (m_timelineModel) {
      auto *clip =
          m_timelineModel->findClip(m_timelineModel->getSelectedClipId());
      if (clip && !clip->getAssetId().isEmpty()) {
        src->setAssetId(clip->getAssetId());
      }
    }
  }

  newNode->setPosition(x, y);
  g->addNode(newNode);
  g->markDirty();

  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }

  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return newNode->id();
}

bool NodeGraphController::removeNode(const QString &graphId,
                                     const QString &nodeId) {
  return removeNodeFromGraph(graphId, nodeId);
}

bool NodeGraphController::removeNodeFromGraph(const QString &graphId,
                                              const QString &nodeId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }

  bool ok = g->removeNode(nodeId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

bool NodeGraphController::connectSockets(const QString &graphId,
                                         const QString &fromNodeId,
                                         const QString &fromSocketId,
                                         const QString &toNodeId,
                                         const QString &toSocketId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    qWarning() << "[NodeGraphController] connectSockets failed: target graph "
                  "unresolved or read-only";
    return false;
  }

  bool ok = g->connectSockets(fromNodeId, fromSocketId, toNodeId, toSocketId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  } else {
    qWarning() << "[NodeGraphController] connectSockets rejected:" << fromNodeId
               << fromSocketId << "->" << toNodeId << toSocketId;
  }
  return ok;
}

bool NodeGraphController::disconnectSockets(const QString &graphId,
                                            const QString &fromNodeId,
                                            const QString &fromSocketId,
                                            const QString &toNodeId,
                                            const QString &toSocketId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }

  bool ok =
      g->disconnectSockets(fromNodeId, fromSocketId, toNodeId, toSocketId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

void NodeGraphController::setNodePosition(const QString &graphId,
                                          const QString &nodeId, double x,
                                          double y) {
  auto g = resolveGraph(graphId);
  if (!g) {
    return;
  }
  auto node = g->findNode(nodeId);
  if (!node) {
    return;
  }

  node->setPosition(x, y);
  g->markDirty();
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
}

void NodeGraphController::updateSocketValue(const QString &graphId,
                                            const QString &nodeId,
                                            const QString &socketId,
                                            const QVariant &value) {
  QVariant unpacked = value;
  if (unpacked.canConvert<QJSValue>()) {
    QJSValue jsVal = unpacked.value<QJSValue>();
    if (jsVal.isArray() || jsVal.isObject()) {
      unpacked = jsVal.toVariant();
    } else if (jsVal.isNumber()) {
      unpacked = jsVal.toNumber();
    } else if (jsVal.isBool()) {
      unpacked = jsVal.toBool();
    } else if (jsVal.isString()) {
      unpacked = jsVal.toString();
    }
  }

  auto g = resolveGraph(graphId);
  if (!g) {
    return;
  }
  auto node = g->findNode(nodeId);
  if (!node) {
    return;
  }

  render::SocketValue val;
  bool assigned = false;

  if (unpacked.typeId() == QMetaType::QVariantList ||
      unpacked.typeId() == QMetaType::QStringList) {
    QVariantList list = unpacked.toList();
    if (list.size() >= 4) {
      val = render::ColorVal{static_cast<float>(list[0].toDouble()),
                             static_cast<float>(list[1].toDouble()),
                             static_cast<float>(list[2].toDouble()),
                             static_cast<float>(list[3].toDouble())};
      assigned = true;
    } else if (list.size() >= 2) {
      val = render::Vec2Val{static_cast<float>(list[0].toDouble()),
                            static_cast<float>(list[1].toDouble())};
      assigned = true;
    } else if (list.size() == 1) {
      val = static_cast<float>(list[0].toDouble());
      assigned = true;
    }
  } else if (unpacked.typeId() == QMetaType::QVariantMap) {
    QVariantMap map = unpacked.toMap();
    if (map.contains("x") && map.contains("y")) {
      val = render::Vec2Val{static_cast<float>(map["x"].toDouble()),
                            static_cast<float>(map["y"].toDouble())};
      assigned = true;
    }
  } else if (unpacked.canConvert<QVector2D>()) {
    QVector2D v = unpacked.value<QVector2D>();
    val = render::Vec2Val{v.x(), v.y()};
    assigned = true;
  } else if (unpacked.canConvert<QPointF>()) {
    QPointF pt = unpacked.toPointF();
    val =
        render::Vec2Val{static_cast<float>(pt.x()), static_cast<float>(pt.y())};
    assigned = true;
  } else if (unpacked.typeId() == QMetaType::Int ||
             unpacked.typeId() == QMetaType::LongLong) {
    val = unpacked.toInt();
    assigned = true;
  } else if (unpacked.canConvert<double>()) {
    val = static_cast<float>(unpacked.toDouble());
    assigned = true;
  } else if (unpacked.typeId() == QMetaType::Bool) {
    val = unpacked.toBool();
    assigned = true;
  }

  if (assigned) {
    node->setInputSocketValue(socketId, val);
    node->setProperty(socketId, val);
    g->markDirty();
    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit visualFrameInvalidated();
  }
}
QVariantList NodeGraphController::getAvailableNodeTypes() const {
  QVariantList list;

  auto appendType = [&list](const QString &displayName, const QString &typeName,
                            const QString &category,
                            const QString &iconSource) {
    QVariantMap m;
    m["displayName"] = displayName;
    m["name"] = displayName;
    m["typeName"] = typeName;
    m["category"] = category;
    m["iconSource"] = iconSource;
    list.append(m);
  };

  appendType("Transform", "Transform", "Spatial",
             "qrc:/assets/icons/crop-landscape.svg");
  appendType("Color Grade", "ColorGrade", "Color",
             "qrc:/assets/icons/palette.svg");
  appendType("Blur", "Blur", "Filter", "qrc:/assets/icons/blur.svg");
  appendType("Video In", "SourceNode", "Source", "qrc:/assets/icons/video.svg");
  appendType("Video Out", "OutputNode", "Output",
             "qrc:/assets/icons/layout-grid.svg");
  appendType("Reroute", "Reroute", "Utility",
             "qrc:/assets/icons/corner-down-right.svg");
  appendType("Comment", "CommentNode", "Utility",
             "qrc:/assets/icons/message-square.svg");
  appendType("Group", "GroupNode", "Utility", "qrc:/assets/icons/folder.svg");

  return list;
}

QString NodeGraphController::addRerouteToGraph(const QString &graphId, double x,
                                               double y) {
  return addNodeToGraph(graphId, "Reroute", x, y);
}

QString NodeGraphController::addCommentToGraph(const QString &graphId,
                                               const QString &text, double x,
                                               double y, double w, double h) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return "";
  }

  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  QString newId = prefix + "_comment";

  auto commentNode =
      std::dynamic_pointer_cast<render::CommentNode>(g->createNodeByType(
          "CommentNode", newId, text.isEmpty() ? "Notes" : text));

  if (!commentNode) {
    return "";
  }

  commentNode->setPosition(x, y);
  commentNode->setText(text.isEmpty() ? "Notes" : text);
  commentNode->setDimensions(w, h);

  g->addNode(commentNode);
  g->markDirty();

  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }

  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return commentNode->id();
}
bool NodeGraphController::addGroupInterfaceSocket(const QString &graphId,
                                                  const QString &groupNodeId,
                                                  bool isInput,
                                                  const QString &name,
                                                  int dataType) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group) {
    return false;
  }

  QString sockId =
      "sock_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(6);
  auto dType = static_cast<render::SocketDataType>(dataType);

  if (isInput) {
    group->addInterfaceInput(sockId, name, dType, 0.0f);
  } else {
    group->addInterfaceOutput(sockId, name, dType);
  }

  g->markDirty();
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

bool NodeGraphController::removeGroupInterfaceSocket(const QString &graphId,
                                                     const QString &groupNodeId,
                                                     bool isInput,
                                                     const QString &socketId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group) {
    return false;
  }

  if (isInput) {
    group->removeInterfaceInput(socketId);
  } else {
    group->removeInterfaceOutput(socketId);
  }

  g->markDirty();
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

QStringList NodeGraphController::getGroupMemberNodeIds(const QString &graphId,
                                                       const QString &groupId) {
  auto g = resolveGraph(graphId);
  if (!g) {
    return {};
  }
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  return group ? group->memberNodeIds() : QStringList{};
}

bool NodeGraphController::setGroupMemberNodeIds(const QString &graphId,
                                                const QString &groupId,
                                                const QStringList &memberIds) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly()) {
    return false;
  }
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  if (!group) {
    return false;
  }

  group->setMemberNodeIds(memberIds);
  g->markDirty();
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  return true;
}

QVariantList NodeGraphController::getAllProjectGraphs() const {
  return render::NodeGraphManager::instance().listAllGraphsSummary();
}

bool NodeGraphController::isGraphReadOnly(const QString &graphId) const {
  auto g = resolveGraph(graphId);
  return g ? g->isReadOnly() : false;
}

QString NodeGraphController::createNewProjectGraph(const QString &name) {
  auto &mgr = render::NodeGraphManager::instance();

  QString preferredId =
      "graph_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  QString graphName = name.isEmpty() ? ("Graph " + preferredId.right(4)) : name;

  auto g = mgr.createGraph(graphName, preferredId);
  if (!g) {
    qWarning() << "[NodeGraphController] Failed to create graph:"
               << preferredId;
    return "";
  }

  g->setReadOnly(false);

  if (m_timelineModel) {
    auto *clip =
        m_timelineModel->findClip(m_timelineModel->getSelectedClipId());
    if (clip && !clip->getAssetId().isEmpty()) {
      for (const auto &node : g->nodes()) {
        if (auto src = std::dynamic_pointer_cast<render::SourceNode>(node)) {
          src->setAssetId(clip->getAssetId());
          break;
        }
      }
    }
  }

  g->markDirty();

  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }

  setStandaloneActiveGraphId(g->id());

  emit projectGraphsChanged();
  emit visualFrameInvalidated();

  return g->id();
}

} // namespace xyla
