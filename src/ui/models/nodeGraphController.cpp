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

// construction and lifecycle

NodeGraphController::NodeGraphController(TimelineModel *timelineModel,
                                         QObject *parent)
    : QObject(parent), m_timelineModel(timelineModel) {}

// standalone graph management

QString NodeGraphController::getStandaloneActiveGraphId() const noexcept {
  return m_standaloneActiveGraphId;
}

void NodeGraphController::setStandaloneActiveGraphId(const QString &graphId) {
  if (m_standaloneActiveGraphId != graphId) {
    m_standaloneActiveGraphId = graphId;
    emit activeGraphChanged();
  }
}

// clip graph bindings

QVariantList
NodeGraphController::getClipAttachedGraphs(const QString &clipId) const {
  if (!m_timelineModel)
    return QVariantList();
  auto *clip = m_timelineModel->findClip(clipId);
  if (!clip)
    return QVariantList();

  QVariantList list;
  for (const auto &id : clip->getNodeGraphIds()) {
    list.append(id);
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
  auto *clip = m_timelineModel->findClip(clipId);
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

// graph structure and mutations

QVariantList NodeGraphController::listEditorNodes(const QString &graphId) {
  QString targetId = graphId.isEmpty() ? m_standaloneActiveGraphId : graphId;
  auto g = render::NodeGraphManager::instance().getGraph(targetId);
  if (g) {
    return g->listEditorNodes();
  }
  return {};
}

QString NodeGraphController::defaultEditorNodeId(const QString &graphId) {
  QString targetId = graphId.isEmpty() ? m_standaloneActiveGraphId : graphId;
  auto g = render::NodeGraphManager::instance().getGraph(targetId);
  if (g) {
    return g->defaultEditorNodeId();
  }
  return "";
}

QString NodeGraphController::addNode(const QString &graphId,
                                     const QString &typeName, double x,
                                     double y) {
  return addNodeToGraph(graphId, typeName, x, y);
}

QString NodeGraphController::addNodeToGraph(const QString &graphId,
                                            const QString &typeName, double x,
                                            double y) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) {
    return "";
  }

  if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
      typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "OutputNode")
        return "";
    }
  } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
             typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "SourceNode")
        return "";
    }
  }

  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  QString newId = prefix + "_" + typeName.toLower();

  auto newNode = g->createNodeByType(typeName, newId, typeName);
  if (!newNode) {
    qWarning() << "[NodeGraphController] Unknown node type requested:"
               << typeName;
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
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return false;

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
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) {
    qWarning() << "[NodeGraphController] connectSockets failed: graph not "
                  "found or read-only:"
               << graphId;
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
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return false;

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
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

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

  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

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
    g->markDirty();
    if (m_timelineModel) {
      m_timelineModel->markDirty();
    }
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
}

// group nodes

bool NodeGraphController::addGroupInterfaceSocket(const QString &graphId,
                                                  const QString &groupNodeId,
                                                  bool isInput,
                                                  const QString &name,
                                                  int dataType) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return false;
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group)
    return false;

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
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
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
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

QStringList NodeGraphController::getGroupMemberNodeIds(const QString &graphId,
                                                       const QString &groupId) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g)
    return {};
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  return group ? group->memberNodeIds() : QStringList{};
}

bool NodeGraphController::setGroupMemberNodeIds(const QString &graphId,
                                                const QString &groupId,
                                                const QStringList &memberIds) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return false;
  auto group =
      std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  if (!group)
    return false;

  group->setMemberNodeIds(memberIds);
  g->markDirty();
  if (m_timelineModel) {
    m_timelineModel->markDirty();
  }
  emit projectGraphsChanged();
  return true;
}

} // namespace xyla
