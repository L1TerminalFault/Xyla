#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

class SourceNode : public Node {
public:
  explicit SourceNode(QString id, QString name = "Media Source",
                      QString assetId = "");
  ~SourceNode() override = default;

  [[nodiscard]] QString generateGlslUniforms() const override;

  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
