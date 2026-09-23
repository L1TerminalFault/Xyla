#pragma once

#include "core/render/node.hpp"
#include <QStringList>

namespace xyla::render {

class GroupNode : public Node {
public:
  inline static const QString StaticTypeName = QStringLiteral("GroupNode");
  inline static const QString StaticDefaultName = QStringLiteral("Group");

  explicit GroupNode(QString id, QString name = StaticDefaultName);

  [[nodiscard]] bool isCollapsed() const noexcept { return m_collapsed; }
  void setCollapsed(bool collapsed) noexcept { m_collapsed = collapsed; }

  [[nodiscard]] const QStringList &memberNodeIds() const noexcept {
    return m_memberNodeIds;
  }
  void setMemberNodeIds(QStringList ids) noexcept {
    m_memberNodeIds = std::move(ids);
  }
  void addMemberNode(const QString &id);
  void removeMemberNode(const QString &id);

  void addInterfaceInput(QString id, QString name, SocketDataType type,
                         SocketValue defaultVal = {});
  void removeInterfaceInput(const QString &socketId);

  void addInterfaceOutput(QString id, QString name, SocketDataType type);
  void removeInterfaceOutput(const QString &socketId);

  [[nodiscard]] QString defaultName() const noexcept override {
    return StaticDefaultName;
  }
  [[nodiscard]] QString typeName() const noexcept override {
    return StaticTypeName;
  }
  [[nodiscard]] QString editorCategory() const override {
    return QStringLiteral("Utility");
  }
  [[nodiscard]] QString editorIcon() const override {
    return QStringLiteral("folder");
  }

  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &,
                   const QString &) const override {
    return {};
  }

  [[nodiscard]] QVariantMap
  toVariantMap(FrameIndex currentFrame,
               const anim::AnimationManager *animMgr) const override;

  [[nodiscard]] QJsonObject serialize() const override;
  bool deserialize(const QJsonObject &json) override;

private:
  bool m_collapsed{false};
  QStringList m_memberNodeIds;
};

} // namespace xyla::render
