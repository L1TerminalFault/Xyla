#include "sourceNode.hpp"

namespace xyla::render {

SourceNode::SourceNode(QString id, QString name, QString assetId)
    : Node(std::move(id), std::move(name), "SourceNode") {
  setPropertyValue("assetId", std::move(assetId));
  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

QString SourceNode::generateGlslUniforms() const {
  return QString("uniform sampler2D u_tex_%1;\n").arg(id());
}

QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  return QString("  vec4 %1 = texture(u_tex_%2, uv);\n")
      .arg(outputVar)
      .arg(id());
}

} // namespace xyla::render
