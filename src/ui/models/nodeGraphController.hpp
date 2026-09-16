#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

namespace xyla {

class TimelineModel;

class NodeGraphController : public QObject {
  Q_OBJECT

  // properties
  Q_PROPERTY(QString standaloneActiveGraphId READ getStandaloneActiveGraphId
                 WRITE setStandaloneActiveGraphId NOTIFY activeGraphChanged)

public:
  // construction and lifecycle
  explicit NodeGraphController(TimelineModel *timelineModel = nullptr,
                               QObject *parent = nullptr);
  ~NodeGraphController() override = default;

  // standalone graph management
  [[nodiscard]] QString getStandaloneActiveGraphId() const noexcept;
  void setStandaloneActiveGraphId(const QString &graphId);

  // clip graph bindings
  Q_INVOKABLE QVariantList getClipAttachedGraphs(const QString &clipId) const;
  Q_INVOKABLE bool attachGraphToClip(const QString &clipId,
                                     const QString &graphId);
  Q_INVOKABLE bool detachGraphFromClip(const QString &clipId,
                                       const QString &graphId);
  Q_INVOKABLE QString getClipActiveGraphId(const QString &clipId) const;
  Q_INVOKABLE bool setClipActiveGraphId(const QString &clipId,
                                        const QString &graphId);
  Q_INVOKABLE bool reorderClipGraphs(const QString &clipId,
                                     const QVariantList &orderedGraphIds);

  // graph structure and mutations
  Q_INVOKABLE QVariantList listEditorNodes(const QString &graphId = "");
  Q_INVOKABLE QString defaultEditorNodeId(const QString &graphId = "");
  Q_INVOKABLE QString addNode(const QString &graphId, const QString &typeName,
                              double x = 0.0, double y = 0.0);
  Q_INVOKABLE QString addNodeToGraph(const QString &graphId,
                                     const QString &typeName, double x = 0.0,
                                     double y = 0.0);
  Q_INVOKABLE bool removeNode(const QString &graphId, const QString &nodeId);
  Q_INVOKABLE bool removeNodeFromGraph(const QString &graphId,
                                       const QString &nodeId);

  Q_INVOKABLE bool connectSockets(const QString &graphId,
                                  const QString &fromNodeId,
                                  const QString &fromSocketId,
                                  const QString &toNodeId,
                                  const QString &toSocketId);
  Q_INVOKABLE bool disconnectSockets(const QString &graphId,
                                     const QString &fromNodeId,
                                     const QString &fromSocketId,
                                     const QString &toNodeId,
                                     const QString &toSocketId);

  Q_INVOKABLE void setNodePosition(const QString &graphId,
                                   const QString &nodeId, double x, double y);
  Q_INVOKABLE void updateSocketValue(const QString &graphId,
                                     const QString &nodeId,
                                     const QString &socketId,
                                     const QVariant &value);

  // group nodes
  Q_INVOKABLE bool addGroupInterfaceSocket(const QString &graphId,
                                           const QString &groupNodeId,
                                           bool isInput, const QString &name,
                                           int dataType);
  Q_INVOKABLE bool removeGroupInterfaceSocket(const QString &graphId,
                                              const QString &groupNodeId,
                                              bool isInput,
                                              const QString &socketId);
  Q_INVOKABLE QStringList getGroupMemberNodeIds(const QString &graphId,
                                                const QString &groupId);
  Q_INVOKABLE bool setGroupMemberNodeIds(const QString &graphId,
                                         const QString &groupId,
                                         const QStringList &memberIds);

signals:
  void activeGraphChanged();
  void projectGraphsChanged();
  void visualFrameInvalidated();

private:
  TimelineModel *m_timelineModel{nullptr};
  QString m_standaloneActiveGraphId{"default_io_graph"};
};

} // namespace xyla
