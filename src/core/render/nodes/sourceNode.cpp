#include "sourceNode.hpp"

namespace xyla::render {

// Node constructor
SourceNode::SourceNode(QString id, QString name, QString assetId)
    : Node(std::move(id), std::move(name), "SourceNode") {
  setPropertyValue("assetId", std::move(assetId));
  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

// Generates uniform code
QString SourceNode::generateGlslUniforms() const { return ""; }

// Samples global bound Vulkan video input texture
QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  return QString("  vec4 %1 = texture(u_inputFrame, uv);\n").arg(outputVar);
}

} // namespace xyla::render
