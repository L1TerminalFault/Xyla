#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

namespace xyla {

class TimelineModel;

namespace render {
class NodeGraph;
}

class NodeGraphController : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString standaloneActiveGraphId READ getStandaloneActiveGraphId
                 WRITE setStandaloneActiveGraphId NOTIFY activeGraphChanged)

public:
  explicit NodeGraphController(TimelineModel *timelineModel = nullptr,
                               QObject *parent = nullptr);
  ~NodeGraphController() override = default;

  QString getStandaloneActiveGraphId() const noexcept;
  void setStandaloneActiveGraphId(const QString &graphId);

  bool setGraphName(const QString &graphId, const QString &name);
  bool deleteProjectGraph(const QString &graphId);

  QVariantList getClipAttachedGraphs(const QString &clipId) const;
  bool attachGraphToClip(const QString &clipId, const QString &graphId);
  bool detachGraphFromClip(const QString &clipId, const QString &graphId);
  QString getClipActiveGraphId(const QString &clipId) const;
  bool setClipActiveGraphId(const QString &clipId, const QString &graphId);
  bool reorderClipGraphs(const QString &clipId,
                         const QVariantList &orderedGraphIds);

  Q_INVOKABLE QVariantList listEditorNodes(const QString &graphId = QString());
  Q_INVOKABLE QString defaultEditorNodeId(const QString &graphId = QString());
  Q_INVOKABLE QVariantList getGraphNodes(const QString &graphId = QString());
  Q_INVOKABLE QVariantList getGraphLinks(const QString &graphId = QString());

  Q_INVOKABLE QString addNode(const QString &graphId, const QString &typeName,
                              double x, double y);
  Q_INVOKABLE QString addNodeToGraph(const QString &graphId,
                                     const QString &typeName, double x,
                                     double y);
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

  Q_INVOKABLE QVariantList getAllProjectGraphs() const;
  Q_INVOKABLE bool isGraphReadOnly(const QString &graphId) const;
  Q_INVOKABLE QString createNewProjectGraph(const QString &name = QString());

signals:
  void activeGraphChanged();
  void projectGraphsChanged();
  void visualFrameInvalidated();

private:
  std::shared_ptr<render::NodeGraph> resolveGraph(const QString &graphId) const;

  TimelineModel *m_timelineModel{nullptr};
  QString m_standaloneActiveGraphId;
};

} // namespace xyla
