#pragma once

#include "../node.hpp"

namespace xyla::render {

class SourceNode : public Node {
public:
  SourceNode(QString id, QString name = "Video In", QString assetId = "");

  [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
  void setAssetId(QString assetId) { m_assetId = std::move(assetId); }

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;

  [[nodiscard]] QVariantMap toVariantMap() const override;

private:
  QString m_assetId;
};

} // namespace xyla::render
