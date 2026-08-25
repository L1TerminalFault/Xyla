#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

class OutputNode : public Node {
public:
  explicit OutputNode(QString id, QString name = "Clip Output");
  ~OutputNode() override = default;

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
