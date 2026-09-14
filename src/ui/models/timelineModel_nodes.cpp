// #include "core/audio/timeline/audioTimelineManager.hpp"
// #include "core/audio/timeline/waveformGenerator.hpp"
// #include "core/render/nodes/colorGradeNode.hpp"
// #include "core/render/nodes/outputNode.hpp"
// #include "core/render/nodes/sourceNode.hpp"
// #include "core/render/nodes/transformNode.hpp"
// #include "project/projectManager.hpp"
// #include "timelineModel.hpp"
//
// #include <QJSValue>
// #include <QPointF>
// #include <QUuid>
// #include <QVector2D>
// #include <algorithm>
//
// namespace xyla {
//
// QVariantList TimelineModel::getClipWaveformPeaks(const QString &assetId,
//                                                  int64_t startFrame,
//                                                  int64_t durationFrames,
//                                                  int targetPixels) const {
//   QVariantList peaksList;
//   if (assetId.isEmpty() || durationFrames <= 0 || targetPixels <= 0)
//     return peaksList;
//
//   const std::string assetKey = assetId.toStdString();
//   auto clipBuffer =
//       audio::AudioTimelineManager::instance().getClipBuffer(assetKey);
//   if (!clipBuffer)
//     return peaksList;
//
//   auto pyramid =
//       audio::WaveformGenerator::instance().getOrGenerate(assetKey,
//       clipBuffer);
//   if (!pyramid || !pyramid->isGenerated())
//     return peaksList;
//
//   double fps = 30.0;
//   if (m_projectManager && m_projectManager->hasActiveProject()) {
//     if (const auto *proj = m_projectManager->activeProject()) {
//       if (proj->fps() > 0.0)
//         fps = proj->fps();
//     }
//   }
//
//   double sampleRate = 48000.0;
//   // Prefer clipBuffer->sampleRate() if you have it
//
//   const int64_t startSample = static_cast<int64_t>(
//       (static_cast<double>(startFrame) / fps) * sampleRate);
//   const size_t sampleCount = static_cast<size_t>(
//       std::max(0.0, (static_cast<double>(durationFrames) / fps) *
//       sampleRate));
//   if (sampleCount == 0)
//     return peaksList;
//
//   const size_t pixels = static_cast<size_t>(std::clamp(targetPixels, 1,
//   8192));
//
//   auto peaks = pyramid->getPeaks(0, startSample, sampleCount, pixels);
//
//   peaksList.reserve(static_cast<int>(peaks.size()));
//   for (const auto &p : peaks) {
//     QVariantMap map;
//     map.insert(QStringLiteral("min"), p.min);
//     map.insert(QStringLiteral("max"), p.max);
//     peaksList.append(std::move(map));
//   }
//   return peaksList;
// }
//
// QVariantList TimelineModel::listEditorNodes(const QString &clipId) {
//   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
//   if (clip && clip->nodeGraph()) {
//     return clip->nodeGraph()->listEditorNodes();
//   }
//   return {};
// }
//
// QString TimelineModel::defaultEditorNodeId(const QString &clipId) {
//   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
//   if (clip && clip->nodeGraph()) {
//     return clip->nodeGraph()->defaultEditorNodeId();
//   }
//   return "";
// }
//
// QString TimelineModel::addNode(const QString &clipId, const QString
// &typeName,
//                                double x, double y) {
//   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
//   if (!clip || !clip->nodeGraph())
//     return "";
//
//   if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
//       typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
//     for (const auto &n : clip->nodeGraph()->nodes()) {
//       if (n && n->typeName() == "OutputNode") {
//         return "";
//       }
//     }
//   } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
//     for (const auto &n : clip->nodeGraph()->nodes()) {
//       if (n && n->typeName() == "SourceNode") {
//         return "";
//       }
//     }
//   }
//
//   QString prefix =
//   QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
//   std::shared_ptr<render::Node> newNode;
//
//   if (typeName.compare("Transform", Qt::CaseInsensitive) == 0 ||
//       typeName.compare("TransformNode", Qt::CaseInsensitive) == 0) {
//     newNode =
//         std::make_shared<render::TransformNode>(prefix + "_xform",
//         "Transform");
//   } else if (typeName.compare("ColorGrade", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("Color Grade", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("ColorGradeNode", Qt::CaseInsensitive) == 0) {
//     newNode = std::make_shared<render::ColorGradeNode>(prefix + "_grade",
//                                                        "Color Grade");
//   } else if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
//     newNode =
//         std::make_shared<render::OutputNode>(prefix + "_out", "Video Out");
//   } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
//     newNode = std::make_shared<render::SourceNode>(prefix + "_src", "Video
//     In",
//                                                    clip->assetId());
//   }
//
//   if (newNode) {
//     newNode->setPosition(x, y);
//     clip->nodeGraph()->addNode(newNode);
//
//     emit selectedClipDataChanged();
//     emit clipPropertiesChanged(clip->clipId());
//     emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
//     return newNode->id();
//   }
//   return "";
// }
//
// bool TimelineModel::removeNode(const QString &clipId, const QString &nodeId)
// {
//   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
//   if (clip && clip->nodeGraph()) {
//     bool ok = clip->nodeGraph()->removeNode(nodeId);
//     if (ok) {
//       emit selectedClipDataChanged();
//       emit clipPropertiesChanged(clip->clipId());
//       emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
//     }
//     return ok;
//   }
//   return false;
// }
//
// // bool TimelineModel::connectSockets(const QString &clipId,
// //                                    const QString &fromNodeId,
// //                                    const QString &fromSocketId,
// //                                    const QString &toNodeId,
// //                                    const QString &toSocketId) {
// //   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
// //   if (clip && clip->nodeGraph()) {
// //     bool ok = clip->nodeGraph()->connectSockets(fromNodeId, fromSocketId,
// //                                                 toNodeId, toSocketId);
// //     if (ok) {
// //       emit selectedClipDataChanged();
// //       emit clipPropertiesChanged(clip->clipId());
// //       emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
// //     }
// //     return ok;
// //   }
// //   return false;
// // }
//
// bool TimelineModel::disconnectSockets(const QString &clipId,
//                                       const QString &fromNodeId,
//                                       const QString &fromSocketId,
//                                       const QString &toNodeId,
//                                       const QString &toSocketId) {
//   auto *clip = findClip(clipId.isEmpty() ? m_selectedClipId : clipId);
//   if (clip && clip->nodeGraph()) {
//     bool ok = clip->nodeGraph()->disconnectSockets(fromNodeId, fromSocketId,
//                                                    toNodeId, toSocketId);
//     if (ok) {
//       emit selectedClipDataChanged();
//       emit clipPropertiesChanged(clip->clipId());
//       emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
//     }
//     return ok;
//   }
//   return false;
// }
//
// void TimelineModel::setNodePosition(const QString &graphId,
//                                     const QString &nodeId, double x, double
//                                     y) {
//   auto g = render::NodeGraphManager::instance().getGraph(graphId);
//   if (!g) return;
//   auto node = g->findNode(nodeId);
//   if (!node) return;
//
//   node->setPosition(x, y);
//   g->markDirty();
//   markDirty();
// }
//
// void TimelineModel::updateSocketValue(const QString &graphId,
//                                       const QString &nodeId,
//                                       const QString &socketId,
//                                       const QVariant &value) {
//   QVariant unpacked = value;
//   if (unpacked.canConvert<QJSValue>()) {
//     QJSValue jsVal = unpacked.value<QJSValue>();
//     if (jsVal.isArray() || jsVal.isObject()) unpacked = jsVal.toVariant();
//     else if (jsVal.isNumber()) unpacked = jsVal.toNumber();
//     else if (jsVal.isBool()) unpacked = jsVal.toBool();
//     else if (jsVal.isString()) unpacked = jsVal.toString();
//   }
//
//   auto g = render::NodeGraphManager::instance().getGraph(graphId);
//   if (!g) return;
//   auto node = g->findNode(nodeId);
//   if (!node) return;
//
//   render::SocketValue val;
//   bool assigned = false;
//
//   if (unpacked.typeId() == QMetaType::QVariantList || unpacked.typeId() ==
//   QMetaType::QStringList) {
//     QVariantList list = unpacked.toList();
//     if (list.size() >= 4) {
//       val = render::ColorVal{static_cast<float>(list[0].toDouble()),
//       static_cast<float>(list[1].toDouble()),
//                              static_cast<float>(list[2].toDouble()),
//                              static_cast<float>(list[3].toDouble())};
//       assigned = true;
//     } else if (list.size() >= 2) {
//       val = render::Vec2Val{static_cast<float>(list[0].toDouble()),
//       static_cast<float>(list[1].toDouble())}; assigned = true;
//     } else if (list.size() == 1) {
//       val = static_cast<float>(list[0].toDouble());
//       assigned = true;
//     }
//   } else if (unpacked.typeId() == QMetaType::QVariantMap) {
//     QVariantMap map = unpacked.toMap();
//     if (map.contains("x") && map.contains("y")) {
//       val = render::Vec2Val{static_cast<float>(map["x"].toDouble()),
//       static_cast<float>(map["y"].toDouble())}; assigned = true;
//     }
//   } else if (unpacked.canConvert<QVector2D>()) {
//     QVector2D v = unpacked.value<QVector2D>();
//     val = render::Vec2Val{v.x(), v.y()};
//     assigned = true;
//   } else if (unpacked.canConvert<QPointF>()) {
//     QPointF pt = unpacked.toPointF();
//     val = render::Vec2Val{static_cast<float>(pt.x()),
//     static_cast<float>(pt.y())}; assigned = true;
//   } else if (unpacked.typeId() == QMetaType::Int || unpacked.typeId() ==
//   QMetaType::LongLong) {
//     val = unpacked.toInt();
//     assigned = true;
//   } else if (unpacked.canConvert<double>()) {
//     val = static_cast<float>(unpacked.toDouble());
//     assigned = true;
//   } else if (unpacked.typeId() == QMetaType::Bool) {
//     val = unpacked.toBool();
//     assigned = true;
//   }
//
//   if (assigned) {
//     node->setInputSocketValue(socketId, val);
//     g->markDirty();
//     markDirty();
//     emit projectGraphsChanged();       // matches the refresh pattern of
//     every other mutator emit visualFrameInvalidated();
//   }
// }
//
// } // namespace xyla

#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/render/nodes/colorGradeNode.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/sourceNode.hpp"
#include "core/render/nodes/transformNode.hpp"
#include "core/render/nodes/utilityNodes.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodeGraph.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QDebug>
#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>
#include <algorithm>

namespace xyla {

// =============================================================================
// WAVEFORM PEAKS
// =============================================================================

QVariantList TimelineModel::getClipWaveformPeaks(const QString &assetId,
                                                 int64_t startFrame,
                                                 int64_t durationFrames,
                                                 int targetPixels) const {
  QVariantList peaksList;
  if (assetId.isEmpty() || durationFrames <= 0 || targetPixels <= 0)
    return peaksList;

  const std::string assetKey = assetId.toStdString();
  auto clipBuffer =
      audio::AudioTimelineManager::instance().getClipBuffer(assetKey);
  if (!clipBuffer)
    return peaksList;

  auto pyramid =
      audio::WaveformGenerator::instance().getOrGenerate(assetKey, clipBuffer);
  if (!pyramid || !pyramid->isGenerated())
    return peaksList;

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  double sampleRate = 48000.0;
  const int64_t startSample = static_cast<int64_t>(
      (static_cast<double>(startFrame) / fps) * sampleRate);
  const size_t sampleCount = static_cast<size_t>(
      std::max(0.0, (static_cast<double>(durationFrames) / fps) * sampleRate));
  if (sampleCount == 0)
    return peaksList;

  const size_t pixels = static_cast<size_t>(std::clamp(targetPixels, 1, 8192));
  auto peaks = pyramid->getPeaks(0, startSample, sampleCount, pixels);

  peaksList.reserve(static_cast<int>(peaks.size()));
  for (const auto &p : peaks) {
    QVariantMap map;
    map.insert(QStringLiteral("min"), p.min);
    map.insert(QStringLiteral("max"), p.max);
    peaksList.append(std::move(map));
  }
  return peaksList;
}

// =============================================================================
// NODE GRAPH MANAGER ENGINE INTEGRATION (MIGRATED TO graphId)
// =============================================================================

QVariantList TimelineModel::listEditorNodes(const QString &graphId) {
  QString targetId = graphId.isEmpty() ? m_selectedClipId : graphId;
  auto g = render::NodeGraphManager::instance().getGraph(targetId);
  if (g) {
    return g->listEditorNodes();
  }
  return {};
}

QString TimelineModel::defaultEditorNodeId(const QString &graphId) {
  QString targetId = graphId.isEmpty() ? m_selectedClipId : graphId;
  auto g = render::NodeGraphManager::instance().getGraph(targetId);
  if (g) {
    return g->defaultEditorNodeId();
  }
  return "";
}

QString TimelineModel::addNode(const QString &graphId, const QString &typeName,
                               double x, double y) {
  return addNodeToGraph(graphId, typeName, x, y);
}

QString TimelineModel::addNodeToGraph(const QString &graphId,
                                      const QString &typeName, double x,
                                      double y) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return "";

  // Singleton enforcement for VideoOut / VideoIn if needed
  if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
      typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "OutputNode") return "";
    }
  } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
             typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
    for (const auto &n : g->nodes()) {
      if (n && n->typeName() == "SourceNode") return "";
    }
  }

  QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
  QString newId = prefix + "_" + typeName.toLower();

  auto newNode = g->createNodeByType(typeName, newId, typeName);
  if (!newNode) {
    qWarning() << "[TimelineModel] Unknown node type requested:" << typeName;
    return "";
  }

  // If it's a SourceNode, attach the selected asset if applicable
  if (auto src = std::dynamic_pointer_cast<render::SourceNode>(newNode)) {
    auto *clip = findClip(m_selectedClipId);
    if (clip && !clip->assetId().isEmpty()) {
      src->setAssetId(clip->assetId());
    }
  }

  newNode->setPosition(x, y);
  g->addNode(newNode);
  g->markDirty();
  markDirty();

  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return newNode->id();
}
// QString TimelineModel::addNodeToGraph(const QString &graphId,
//                                       const QString &typeName, double x,
//                                       double y) {
//   auto g = render::NodeGraphManager::instance().getGraph(graphId);
//   if (!g || g->isReadOnly())
//     return "";
//
//   // Prevent duplicate Output or Source nodes if the graph enforces singletons
//   if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
//       typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
//     for (const auto &n : g->nodes()) {
//       if (n && n->typeName() == "OutputNode") {
//         return "";
//       }
//     }
//   } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
//              typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
//     for (const auto &n : g->nodes()) {
//       if (n && n->typeName() == "SourceNode") {
//         return "";
//       }
//     }
//   }
//
//   // Use NodeFactory or node creation
//   std::shared_ptr<render::Node> newNode =
//       render::NodeFactory::instance().createNode(typeName);
//
//   // Fallback direct creation if factory doesn't know the alias
//   if (!newNode) {
//     QString prefix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
//     if (typeName.compare("Transform", Qt::CaseInsensitive) == 0 ||
//         typeName.compare("TransformNode", Qt::CaseInsensitive) == 0) {
//       newNode = std::make_shared<render::TransformNode>(prefix + "_xform",
//                                                         "Transform");
//     } else if (typeName.compare("ColorGrade", Qt::CaseInsensitive) == 0 ||
//                typeName.compare("Color Grade", Qt::CaseInsensitive) == 0 ||
//                typeName.compare("ColorGradeNode", Qt::CaseInsensitive) == 0) {
//       newNode = std::make_shared<render::ColorGradeNode>(prefix + "_grade",
//                                                          "Color Grade");
//     } else if (typeName.compare("VideoOut", Qt::CaseInsensitive) == 0 ||
//                typeName.compare("OutputNode", Qt::CaseInsensitive) == 0) {
//       newNode =
//           std::make_shared<render::OutputNode>(prefix + "_out", "Video Out");
//     } else if (typeName.compare("VideoIn", Qt::CaseInsensitive) == 0 ||
//                typeName.compare("SourceNode", Qt::CaseInsensitive) == 0) {
//       auto *clip = findClip(m_selectedClipId);
//       QString assetId = clip ? clip->assetId() : "";
//       newNode = std::make_shared<render::SourceNode>(prefix + "_src",
//                                                      "Video In", assetId);
//     }
//   }
//
//   if (newNode) {
//     newNode->setPosition(x, y);
//     g->addNode(newNode);
//     g->markDirty();
//     markDirty();
//
//     emit projectGraphsChanged();
//     emit visualFrameInvalidated();
//     return newNode->id();
//   }
//   return "";
// }

bool TimelineModel::removeNode(const QString &graphId, const QString &nodeId) {
  return removeNodeFromGraph(graphId, nodeId);
}

bool TimelineModel::removeNodeFromGraph(const QString &graphId,
                                        const QString &nodeId) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly())
    return false;

  bool ok = g->removeNode(nodeId);
  if (ok) {
    g->markDirty();
    markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

bool TimelineModel::connectSockets(const QString &graphId,
                                   const QString &fromNodeId,
                                   const QString &fromSocketId,
                                   const QString &toNodeId,
                                   const QString &toSocketId) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) {
    qWarning() << "[TimelineModel] connectSockets failed: graph not found or "
                  "read-only:"
               << graphId;
    return false;
  }

  bool ok = g->connectSockets(fromNodeId, fromSocketId, toNodeId, toSocketId);
  if (ok) {
    g->markDirty();
    markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  } else {
    qWarning() << "[TimelineModel] connectSockets rejected:" << fromNodeId
               << fromSocketId << "->" << toNodeId << toSocketId;
  }
  return ok;
}

bool TimelineModel::disconnectSockets(const QString &graphId,
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
    markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
  return ok;
}

void TimelineModel::setNodePosition(const QString &graphId,
                                    const QString &nodeId, double x, double y) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g)
    return;
  auto node = g->findNode(nodeId);
  if (!node)
    return;

  node->setPosition(x, y);
  g->markDirty();
  markDirty();
}

void TimelineModel::updateSocketValue(const QString &graphId,
                                      const QString &nodeId,
                                      const QString &socketId,
                                      const QVariant &value) {
  QVariant unpacked = value;
  if (unpacked.canConvert<QJSValue>()) {
    QJSValue jsVal = unpacked.value<QJSValue>();
    if (jsVal.isArray() || jsVal.isObject())
      unpacked = jsVal.toVariant();
    else if (jsVal.isNumber())
      unpacked = jsVal.toNumber();
    else if (jsVal.isBool())
      unpacked = jsVal.toBool();
    else if (jsVal.isString())
      unpacked = jsVal.toString();
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
    markDirty();
    emit projectGraphsChanged();
    emit visualFrameInvalidated();
  }
}

// QString TimelineModel::getGroupSubGraphId(const QString &graphId, const QString &groupNodeId) {
//   auto g = render::NodeGraphManager::instance().getGraph(graphId);
//   if (!g) return "";
//   auto node = std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
//   if (node && node->subGraph()) {
//     // Register subgraph in NodeGraphManager so the editor can load it directly by ID!
//     render::NodeGraphManager::instance().registerGraph(node->subGraph());
//     return node->subGraph()->id();
//   }
//   return "";
// }

bool TimelineModel::addGroupInterfaceSocket(const QString &graphId, const QString &groupNodeId,
                                            bool isInput, const QString &name, int dataType) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) return false;
  auto group = std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group) return false;

  QString sockId = "sock_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(6);
  auto dType = static_cast<render::SocketDataType>(dataType);

  if (isInput) {
    group->addInterfaceInput(sockId, name, dType, 0.0f);
  } else {
    group->addInterfaceOutput(sockId, name, dType);
  }

  g->markDirty();
  markDirty();
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

bool TimelineModel::removeGroupInterfaceSocket(const QString &graphId, const QString &groupNodeId,
                                               bool isInput, const QString &socketId) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) return false;
  auto group = std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupNodeId));
  if (!group) return false;

  if (isInput) {
    group->removeInterfaceInput(socketId);
  } else {
    group->removeInterfaceOutput(socketId);
  }

  g->markDirty();
  markDirty();
  emit projectGraphsChanged();
  emit visualFrameInvalidated();
  return true;
}

Q_INVOKABLE QStringList TimelineModel::getGroupMemberNodeIds(const QString &graphId, const QString &groupId) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g) return {};
  auto group = std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  return group ? group->memberNodeIds() : QStringList{};
}

Q_INVOKABLE bool TimelineModel::setGroupMemberNodeIds(const QString &graphId, const QString &groupId, const QStringList &memberIds) {
  auto g = render::NodeGraphManager::instance().getGraph(graphId);
  if (!g || g->isReadOnly()) return false;
  auto group = std::dynamic_pointer_cast<render::GroupNode>(g->findNode(groupId));
  if (!group) return false;

  group->setMemberNodeIds(memberIds);
  g->markDirty();
  markDirty();
  emit projectGraphsChanged();
  return true;
}

} // namespace xyla
