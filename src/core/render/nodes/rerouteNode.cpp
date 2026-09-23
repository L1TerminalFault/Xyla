#include "rerouteNode.hpp"

namespace xyla::render {

RerouteNode::RerouteNode(QString id, QString name) : Node(std::move(id)) {
  setName(name.isEmpty() ? StaticDefaultName : std::move(name));
  addInput(QStringLiteral("in"), QStringLiteral("In"), SocketDataType::Image);
  addOutput(QStringLiteral("out"), QStringLiteral("Out"),
            SocketDataType::Image);
}

PixelRect RerouteNode::computeRegionOfDefinition(
    const std::unordered_map<QString, PixelRect> &inputRods,
    const RenderContext &ctx) const {
  const auto it = inputRods.find(QStringLiteral("in"));
  return (it != inputRods.end()) ? it->second : ctx.rod;
}

PixelRect
RerouteNode::queryInputRegionOfInterest(const QString &,
                                        const PixelRect &downstreamRoi,
                                        const RenderContext &) const {
  return downstreamRoi;
}

QString RerouteNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  const auto it = inputVars.find(QStringLiteral("in"));
  const QString inVar =
      (it != inputVars.end()) ? it->second : QStringLiteral("vec4(0.0)");
  return QStringLiteral("  vec4 %1 = %2;\n").arg(outputVar, inVar);
}

} // namespace xyla::render
