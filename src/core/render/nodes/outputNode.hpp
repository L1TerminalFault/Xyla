#pragma once

#include "../node.hpp"

namespace xyla::render {

class OutputNode : public Node {
public:
  OutputNode(QString id, QString name = "Video Out");

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
