#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

enum class OutputBlendMode : uint8_t {
  Normal = 0,
  PremultipliedOver,
  Additive,
  Multiply,
  Screen
};

class OutputNode : public Node {
public:
  inline static const QString StaticTypeName = QStringLiteral("OutputNode");
  inline static const QString StaticDefaultName = QStringLiteral("Video Out");

  explicit OutputNode(QString id, QString name = StaticDefaultName);

  [[nodiscard]] QString defaultName() const noexcept override {
    return StaticDefaultName;
  }
  [[nodiscard]] QString typeName() const noexcept override {
    return StaticTypeName;
  }
  [[nodiscard]] QString editorCategory() const override {
    return QStringLiteral("Output");
  }
  [[nodiscard]] QString editorIcon() const override {
    return QStringLiteral("output");
  }

  [[nodiscard]] OutputBlendMode blendMode() const noexcept {
    return m_blendMode;
  }
  void setBlendMode(OutputBlendMode mode) noexcept { m_blendMode = mode; }

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;

  [[nodiscard]] QVariantMap
  toVariantMap(FrameIndex currentFrame,
               const anim::AnimationManager *animMgr) const override;

  [[nodiscard]] QJsonObject serialize() const override;
  bool deserialize(const QJsonObject &json) override;

private:
  OutputBlendMode m_blendMode{OutputBlendMode::Normal};
};

} // namespace xyla::render
