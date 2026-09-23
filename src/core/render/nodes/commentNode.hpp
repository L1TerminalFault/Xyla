#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

class CommentNode : public Node {
public:
  inline static const QString StaticTypeName = QStringLiteral("CommentNode");
  inline static const QString StaticDefaultName = QStringLiteral("Backdrop");

  explicit CommentNode(QString id, QString name = StaticDefaultName,
                       QString text = QStringLiteral("Notes"),
                       double width = 400.0, double height = 250.0);

  [[nodiscard]] const QString &text() const noexcept { return m_text; }
  void setText(QString text) noexcept { m_text = std::move(text); }

  [[nodiscard]] double width() const noexcept { return m_width; }
  [[nodiscard]] double height() const noexcept { return m_height; }
  void setDimensions(double w, double h) noexcept {
    m_width = w;
    m_height = h;
  }

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
    return QStringLiteral("sticky_note_2");
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
  QString m_text;
  double m_width{400.0};
  double m_height{250.0};
};

} // namespace xyla::render
