#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

class TransformNode : public Node {
public:
  explicit TransformNode(QString id, QString name = "Transform / Opacity");
  ~TransformNode() override = default;

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
