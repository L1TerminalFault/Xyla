#pragma once
#include "core/render/node.hpp"
#include <QStringList>

namespace xyla::render {

class GroupNode : public Node {
public:
  GroupNode(const QString &id, const QString &name = "Group")
      : Node(id, name, "GroupNode") {}

  [[nodiscard]] bool isCollapsed() const { return m_isCollapsed; }
  void setCollapsed(bool c) { m_isCollapsed = c; }

  [[nodiscard]] QStringList memberNodeIds() const { return m_memberNodeIds; }
  void setMemberNodeIds(const QStringList &ids) { m_memberNodeIds = ids; }

private:
  bool m_isCollapsed{false};
  QStringList m_memberNodeIds;
};

} // namespace xyla::render
