#include "commentNode.hpp"

namespace xyla::render {

CommentNode::CommentNode(QString id, QString name, QString text, double width,
                         double height)
    : Node(std::move(id)), m_text(std::move(text)), m_width(width),
      m_height(height) {
  setName(name.isEmpty() ? StaticDefaultName : std::move(name));
}

QVariantMap
CommentNode::toVariantMap(FrameIndex currentFrame,
                          const anim::AnimationManager *animMgr) const {
  auto map = Node::toVariantMap(currentFrame, animMgr);
  map[QStringLiteral("commentText")] = m_text;
  map[QStringLiteral("boxWidth")] = m_width;
  map[QStringLiteral("boxHeight")] = m_height;
  return map;
}

QJsonObject CommentNode::serialize() const {
  auto json = Node::serialize();
  json[QStringLiteral("commentText")] = m_text;
  json[QStringLiteral("boxWidth")] = m_width;
  json[QStringLiteral("boxHeight")] = m_height;
  return json;
}

bool CommentNode::deserialize(const QJsonObject &json) {
  if (!Node::deserialize(json))
    return false;
  m_text =
      json[QStringLiteral("commentText")].toString(QStringLiteral("Notes"));
  m_width = json[QStringLiteral("boxWidth")].toDouble(400.0);
  m_height = json[QStringLiteral("boxHeight")].toDouble(250.0);
  return true;
}

} // namespace xyla::render
