#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

class RerouteNode : public Node {
public:
  inline static const QString StaticTypeName = QStringLiteral("RerouteNode");
  inline static const QString StaticDefaultName = QStringLiteral("Dot");

  explicit RerouteNode(QString id, QString name = StaticDefaultName);

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
    return QStringLiteral("grain");
  }

  [[nodiscard]] PixelRect computeRegionOfDefinition(
      const std::unordered_map<QString, PixelRect> &inputRods,
      const RenderContext &ctx) const override;

  [[nodiscard]] PixelRect
  queryInputRegionOfInterest(const QString &inputSocketId,
                             const PixelRect &downstreamRoi,
                             const RenderContext &ctx) const override;

  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;
};

} // namespace xyla::render
