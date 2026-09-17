#pragma once

#include "../node.hpp"

namespace xyla::render {

enum class SourceFormat : uint8_t { PlanarYuv = 0, RgbaImage };

class SourceNode : public Node {
public:
  SourceNode(QString id, QString name = "Video In", QString assetId = "",
             SourceFormat format = SourceFormat::PlanarYuv);

  [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
  void setAssetId(QString assetId) { m_assetId = std::move(assetId); }

  [[nodiscard]] SourceFormat format() const noexcept { return m_format; }
  void setFormat(SourceFormat format) noexcept { m_format = format; }

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;

  [[nodiscard]] QVariantMap toVariantMap() const override;

private:
  QString m_assetId;
  SourceFormat m_format{SourceFormat::PlanarYuv};
};

} // namespace xyla::render
