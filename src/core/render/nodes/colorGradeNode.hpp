#pragma once

#include "../node.hpp"

namespace xyla::render {

class ColorGradeNode : public Node {
public:
  ColorGradeNode(QString id, QString name = "Color Grade");

  [[nodiscard]] bool hasCustomEditor() const override { return true; }
  [[nodiscard]] QString customEditorQmlUrl() const override {
    return "qrc:/Xyla/src/qml/editors/ColorGradeCEView.qml";
  }
  [[nodiscard]] QString editorCategory() const override { return "Color"; }
  [[nodiscard]] QString editorIcon() const override { return "palette"; }

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
