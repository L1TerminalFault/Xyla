#pragma once

#include "../node.hpp"

namespace xyla::render {

class TransformNode : public Node {
public:
  TransformNode(QString id, QString name = "Transform");

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override;
};

} // namespace xyla::render
