#include "nodeGraphController.hpp"
#include "core/log/logger.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodes/commentNode.hpp"
#include "core/render/nodes/groupNode.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/rerouteNode.hpp"
#include "core/render/nodes/videoInNode.hpp"
#include "timelineModel.hpp"

#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>

namespace xyla {

namespace {

QString normalizeNodeType(const QString &typeName) {
  if (typeName.compare(QStringLiteral("VideoIn"), Qt::CaseInsensitive) == 0 ||
      typeName.compare(QStringLiteral("VideoInNode"), Qt::CaseInsensitive) ==
          0 ||
      typeName.compare(QStringLiteral("SourceNode"), Qt::CaseInsensitive) ==
          0) {
    return xyla::render::VideoInNode::StaticTypeName;
  }
  if (typeName.compare(QStringLiteral("VideoOut"), Qt::CaseInsensitive) == 0 ||
      typeName.compare(QStringLiteral("VideoOutNode"), Qt::CaseInsensitive) ==
          0 ||
      typeName.compare(QStringLiteral("OutputNode"), Qt::CaseInsensitive) ==
          0) {
    return render::OutputNode::StaticTypeName;
  }
  if (typeName.compare(QStringLiteral("Reroute"), Qt::CaseInsensitive) == 0 ||
      typeName.compare(QStringLiteral("Dot"), Qt::CaseInsensitive) == 0) {
    return render::RerouteNode::StaticTypeName;
  }
  if (typeName.compare(QStringLiteral("Comment"), Qt::CaseInsensitive) == 0 ||
      typeName.compare(QStringLiteral("Backdrop"), Qt::CaseInsensitive) == 0) {
    return render::CommentNode::StaticTypeName;
  }
  if (typeName.compare(QStringLiteral("Group"), Qt::CaseInsensitive) == 0) {
    return render::GroupNode::StaticTypeName;
  }
  return typeName;
}

} // namespace

NodeGraphController::NodeGraphController(TimelineModel *timelineModel,
                                         QObject *parent)
    : QObject(parent), m_timelineModel(timelineModel) {
  auto &mgr = render::NodeGraphManager::instance();
  if (auto def = mgr.getGraph(render::DEFAULT_IO_GRAPH_ID)) {
    m_standaloneActiveGraphId = render::DEFAULT_IO_GRAPH_ID;
  } else {
    const auto all = mgr.listAllGraphsSummary();
    if (!all.isEmpty()) {
      m_standaloneActiveGraphId =
          all.first().toMap().value(QStringLiteral("id")).toString();
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
      if (const auto *clip = m_timelineModel->findClip(selectedClipId)) {
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
  if (!g || g->isReadOnly())
    return false;

  g->setName(name);
  g->markDirty();

  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit projectGraphsChanged();
  return true;
}

bool NodeGraphController::deleteProjectGraph(const QString &graphId) {
  if (graphId == render::DEFAULT_IO_GRAPH_ID)
    return false;

  if (m_timelineModel) {
    const QVariantList allClips = m_timelineModel->getAllClips();
    for (const auto &clipVar : allClips) {
      const QString clipId =
          clipVar.toMap().value(QStringLiteral("id")).toString();
      if (!clipId.isEmpty()) {
        detachGraphFromClip(clipId, graphId);
      }
    }
  }

  const bool ok = render::NodeGraphManager::instance().removeGraph(graphId);
  if (ok) {
    if (m_standaloneActiveGraphId == graphId) {
      m_standaloneActiveGraphId.clear();
      if (auto fallback = resolveGraph({})) {
        m_standaloneActiveGraphId = fallback->id();
      }
    }
    if (m_timelineModel)
      m_timelineModel->markDirty();
    emit projectGraphsChanged();
    emit activeGraphChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

QVariantList
NodeGraphController::getClipAttachedGraphs(const QString &clipId) const {
  if (!m_timelineModel)
    return {};

  const auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return {};

  auto &mgr = render::NodeGraphManager::instance();
  QVariantList list;

  for (const auto &graphId : clip->getNodeGraphIds()) {
    auto g = mgr.getGraph(graphId);
    QVariantMap map;
    map[QStringLiteral("id")] = graphId;
    map[QStringLiteral("name")] = g ? g->name() : graphId;
    map[QStringLiteral("isReadOnly")] = g ? g->isReadOnly() : false;
    map[QStringLiteral("isDefault")] =
        (graphId == render::DEFAULT_IO_GRAPH_ID) || (g && g->isReadOnly());
    list.append(map);
  }
  return list;
}

bool NodeGraphController::attachGraphToClip(const QString &clipId,
                                            const QString &graphId) {
  if (!m_timelineModel)
    return false;
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return false;

  clip->attachNodeGraphId(graphId);
  return true;
}

bool NodeGraphController::detachGraphFromClip(const QString &clipId,
                                              const QString &graphId) {
  if (!m_timelineModel)
    return false;
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return false;

  return clip->detachNodeGraphId(graphId);
}

QString NodeGraphController::getClipActiveGraphId(const QString &clipId) const {
  if (!m_timelineModel)
    return render::DEFAULT_IO_GRAPH_ID;
  const auto *clip = m_timelineModel->findClip(clipId);
  return clip ? clip->getActiveGraphId() : render::DEFAULT_IO_GRAPH_ID;
}

bool NodeGraphController::setClipActiveGraphId(const QString &clipId,
                                               const QString &graphId) {
  if (!m_timelineModel)
    return false;
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return false;

  clip->setActiveGraphId(graphId);
  emit activeGraphChanged();
  return true;
}

bool NodeGraphController::reorderClipGraphs(
    const QString &clipId, const QVariantList &orderedGraphIds) {
  if (!m_timelineModel)
    return false;
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return false;

  QStringList list;
  for (const auto &v : orderedGraphIds) {
    list.append(v.toString());
  }
  clip->setAttachedNodeGraphIds(list);
  return true;
}

QVariantList NodeGraphController::listEditorNodes(const QString &graphId) {
  if (auto g = resolveGraph(graphId)) {
    return g->listEditorNodes();
  }
  return {};
}

QString NodeGraphController::defaultEditorNodeId(const QString &graphId) {
  if (auto g = resolveGraph(graphId)) {
    return g->defaultEditorNodeId();
  }
  return {};
}

QVariantList NodeGraphController::getGraphNodes(const QString &graphId) {
  if (auto g = resolveGraph(graphId)) {
    const FrameIndex frame = 0;
    const anim::AnimationManager *animMgr =
        m_timelineModel ? m_timelineModel->animationManager() : nullptr;
    return g->toVariantList(frame, animMgr);
  }
  return {};
}

QVariantList NodeGraphController::getGraphLinks(const QString &graphId) {
  if (auto g = resolveGraph(graphId)) {
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
  if (!g)
    return {};

  // If the user tries to edit the read-only default graph, fork it into a
  // unique custom graph for this clip!
  if (g->isReadOnly()) {
    if (m_timelineModel) {
      const QString clipId = m_timelineModel->getSelectedClipId();
      if (auto *clip = m_timelineModel->findClip(clipId)) {
        const QString newGraphId =
            QStringLiteral("graph_%1")
                .arg(
                    QUuid::createUuid().toString(QUuid::WithoutBraces).left(8));
        const QString graphName =
            QStringLiteral("%1 Graph").arg(clip->getName());

        auto customGraph = render::NodeGraphManager::instance().createGraph(
            graphName, newGraphId);
        clip->attachNodeGraphId(customGraph->id());
        clip->setActiveGraphId(customGraph->id());
        g = customGraph;

        emit activeGraphChanged();
        emit projectGraphsChanged();
      }
    }
  }

  // Now add the requested node to the editable graph...
  const QString canonicalType = normalizeNodeType(typeName);
  const QString prefix =
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  const QString newId =
      QStringLiteral("%1_%2").arg(prefix, canonicalType.toLower());

  auto newNode = render::NodeGraphManager::instance().createNodeByType(
      canonicalType, newId, canonicalType);
  if (!newNode)
    return {};

  newNode->setPosition(x, y);
  g->addNode(newNode);
  g->markDirty();

  if (m_timelineModel)
    m_timelineModel->markDirty();
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
  if (!g || g->isReadOnly())
    return false;

  const bool ok = g->removeNode(nodeId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel)
      m_timelineModel->markDirty();
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
  if (!g || g->isReadOnly())
    return false;

  const bool ok =
      g->connectSockets(fromNodeId, fromSocketId, toNodeId, toSocketId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel)
      m_timelineModel->markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

bool NodeGraphController::disconnectSockets(const QString &graphId,
                                            const QString &fromNodeId,
                                            const QString &fromSocketId,
                                            const QString &toNodeId,
                                            const QString &toSocketId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly())
    return false;

  const bool ok =
      g->disconnectSockets(fromNodeId, fromSocketId, toNodeId, toSocketId);
  if (ok) {
    g->markDirty();
    if (m_timelineModel)
      m_timelineModel->markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

void NodeGraphController::setNodePosition(const QString &graphId,
                                          const QString &nodeId, double x,
                                          double y) {
  auto g = resolveGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

  node->setPosition(x, y);
  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
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
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

  auto *input = node->findInput(socketId);
  if (!input)
    return;

  auto *animMgr =
      m_timelineModel ? m_timelineModel->animationManager() : nullptr;
  const FrameIndex frame = 0;

  if (animMgr) {
    const auto handle = node->propertyHandle(socketId);
    if (handle.isValid()) {
      animMgr->setProperty(handle, unpacked, frame);
    }
  }

  if (unpacked.typeId() == QMetaType::QVariantList) {
    const QVariantList list = unpacked.toList();
    if (list.size() >= 4) {
      input->defaultValue =
          render::ColorVal{static_cast<float>(list[0].toDouble()),
                           static_cast<float>(list[1].toDouble()),
                           static_cast<float>(list[2].toDouble()),
                           static_cast<float>(list[3].toDouble())};
    } else if (list.size() >= 2) {
      input->defaultValue =
          render::Vec2Val{static_cast<float>(list[0].toDouble()),
                          static_cast<float>(list[1].toDouble())};
    } else if (!list.empty()) {
      input->defaultValue = static_cast<float>(list[0].toDouble());
    }
  } else if (unpacked.typeId() == QMetaType::Int ||
             unpacked.typeId() == QMetaType::LongLong) {
    input->defaultValue = unpacked.toInt();
  } else if (unpacked.typeId() == QMetaType::Bool) {
    input->defaultValue = unpacked.toBool();
  } else if (unpacked.canConvert<double>()) {
    input->defaultValue = static_cast<float>(unpacked.toDouble());
  }

  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit visualFrameInvalidated();
}

void NodeGraphController::setPreviewTarget(const QString &graphId,
                                           const QString &nodeId) {
  auto g = resolveGraph(graphId);
  if (!g)
    return;

  g->setPreviewTargetNode(nodeId);
  g->markDirty();

  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit visualFrameInvalidated();
}

void NodeGraphController::clearPreviewTarget(const QString &graphId) {
  setPreviewTarget(graphId, {});
}

void NodeGraphController::setNodeBypassed(const QString &graphId,
                                          const QString &nodeId,
                                          bool bypassed) {
  auto g = resolveGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

  node->setBypassed(bypassed);
  g->markDirty();

  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit visualFrameInvalidated();
}

void NodeGraphController::toggleNodeBypass(const QString &graphId,
                                           const QString &nodeId) {
  auto g = resolveGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

  setNodeBypassed(graphId, nodeId, !node->bypassed());
}

QVariantList NodeGraphController::getAvailableNodeTypes() const {
  QVariantList list;

  auto appendType = [&list](const QString &displayName, const QString &typeName,
                            const QString &category,
                            const QString &iconSource) {
    QVariantMap m;
    m[QStringLiteral("displayName")] = displayName;
    m[QStringLiteral("name")] = displayName;
    m[QStringLiteral("typeName")] = typeName;
    m[QStringLiteral("category")] = category;
    m[QStringLiteral("iconSource")] = iconSource;
    list.append(m);
  };

  appendType(QStringLiteral("Video In"), render::VideoInNode::StaticTypeName,
             QStringLiteral("Source"),
             QStringLiteral("qrc:/assets/icons/video.svg"));
  appendType(QStringLiteral("Video Out"), render::OutputNode::StaticTypeName,
             QStringLiteral("Output"),
             QStringLiteral("qrc:/assets/icons/layout-grid.svg"));
  appendType(QStringLiteral("Reroute"), render::RerouteNode::StaticTypeName,
             QStringLiteral("Utility"),
             QStringLiteral("qrc:/assets/icons/corner-down-right.svg"));
  appendType(QStringLiteral("Comment"), render::CommentNode::StaticTypeName,
             QStringLiteral("Utility"),
             QStringLiteral("qrc:/assets/icons/message-square.svg"));
  appendType(QStringLiteral("Group"), render::GroupNode::StaticTypeName,
             QStringLiteral("Utility"),
             QStringLiteral("qrc:/assets/icons/folder.svg"));

  return list;
}

QString NodeGraphController::addRerouteToGraph(const QString &graphId, double x,
                                               double y) {
  return addNodeToGraph(graphId, render ::RerouteNode::StaticTypeName, x, y);
}

QString NodeGraphController::addCommentToGraph(const QString &graphId,
                                               const QString &text, double x,
                                               double y, double w, double h) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly())
    return {};

  const QString prefix =
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  const QString newId = QStringLiteral("%1_comment").arg(prefix);

  auto commentNode = std::make_shared<render::CommentNode>(
      newId, text.isEmpty() ? QStringLiteral("Notes") : text, text, w, h);
  commentNode->setPosition(x, y);

  g->addNode(commentNode);
  g->markDirty();

  if (m_timelineModel)
    m_timelineModel->markDirty();
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
  if (!g || g->isReadOnly())
    return false;
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group)
    return false;

  const QString sockId = QStringLiteral("sock_%1").arg(
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(6));
  const auto dType = static_cast<render::SocketDataType>(dataType);

  if (isInput) {
    group->addInterfaceInput(sockId, name, dType, 0.0f);
  } else {
    group->addInterfaceOutput(sockId, name, dType);
  }

  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

bool NodeGraphController::removeGroupInterfaceSocket(const QString &graphId,
                                                     const QString &groupNodeId,
                                                     bool isInput,
                                                     const QString &socketId) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly())
    return false;
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group)
    return false;

  if (isInput) {
    group->removeInterfaceInput(socketId);
  } else {
    group->removeInterfaceOutput(socketId);
  }

  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

QStringList NodeGraphController::getGroupMemberNodeIds(const QString &graphId,
                                                       const QString &groupId) {
  auto g = resolveGraph(graphId);
  if (!g)
    return {};
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  return group ? group->memberNodeIds() : QStringList{};
}

bool NodeGraphController::setGroupMemberNodeIds(const QString &graphId,
                                                const QString &groupId,
                                                const QStringList &memberIds) {
  auto g = resolveGraph(graphId);
  if (!g || g->isReadOnly())
    return false;
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  if (!group)
    return false;

  group->setMemberNodeIds(memberIds);
  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
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

  const QString preferredId =
      QStringLiteral("graph_%1")
          .arg(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8));
  const QString graphName =
      name.isEmpty() ? QStringLiteral("Graph %1").arg(preferredId.right(4))
                     : name;

  auto g = mgr.createGraph(graphName, preferredId);
  if (!g) {
    XYLA_LOG_WARN("NodeGraphController", "Failed to create graph.");
    return {};
  }

  g->setReadOnly(false);

  if (m_timelineModel) {
    if (const auto *clip =
            m_timelineModel->findClip(m_timelineModel->getSelectedClipId())) {
      if (!clip->getAssetId().isEmpty()) {
        for (const auto &node : g->nodes()) {
          if (auto src = std::dynamic_pointer_cast<render::VideoInNode>(node)) {
            src->setAssetId(clip->getAssetId());
            break;
          }
        }
      }
    }
  }

  g->markDirty();
  if (m_timelineModel)
    m_timelineModel->markDirty();
  setStandaloneActiveGraphId(g->id());

  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return g->id();
}

} // namespace xyla
