#include "groupNode.hpp"
#include <QJsonArray>

namespace xyla::render {

GroupNode::GroupNode(QString id, QString name) : Node(std::move(id)) {
  setName(name.isEmpty() ? StaticDefaultName : std::move(name));
}

void GroupNode::addMemberNode(const QString &id) {
  if (!m_memberNodeIds.contains(id)) {
    m_memberNodeIds.append(id);
  }
}

void GroupNode::removeMemberNode(const QString &id) {
  m_memberNodeIds.removeAll(id);
}

void GroupNode::addInterfaceInput(QString id, QString name, SocketDataType type,
                                  SocketValue defaultVal) {
  addInput(std::move(id), std::move(name), type, std::move(defaultVal));
}

void GroupNode::removeInterfaceInput(const QString &socketId) {
  std::erase_if(m_inputs,
                [&](const NodeSocket &s) { return s.id == socketId; });
}

void GroupNode::addInterfaceOutput(QString id, QString name,
                                   SocketDataType type) {
  addOutput(std::move(id), std::move(name), type);
}

void GroupNode::removeInterfaceOutput(const QString &socketId) {
  std::erase_if(m_outputs,
                [&](const NodeSocket &s) { return s.id == socketId; });
}

QVariantMap
GroupNode::toVariantMap(FrameIndex currentFrame,
                        const anim::AnimationManager *animMgr) const {
  auto map = Node::toVariantMap(currentFrame, animMgr);
  map[QStringLiteral("isCollapsed")] = m_collapsed;
  map[QStringLiteral("memberNodeIds")] = m_memberNodeIds;
  return map;
}

QJsonObject GroupNode::serialize() const {
  auto json = Node::serialize();
  json[QStringLiteral("isCollapsed")] = m_collapsed;

  QJsonArray members;
  for (const auto &id : m_memberNodeIds) {
    members.append(id);
  }
  json[QStringLiteral("memberNodeIds")] = members;
  return json;
}

bool GroupNode::deserialize(const QJsonObject &json) {
  if (!Node::deserialize(json))
    return false;
  m_collapsed = json[QStringLiteral("isCollapsed")].toBool(false);

  m_memberNodeIds.clear();
  const QJsonArray members = json[QStringLiteral("memberNodeIds")].toArray();
  for (const auto &val : members) {
    m_memberNodeIds.append(val.toString());
  }
  return true;
}

} // namespace xyla::render
