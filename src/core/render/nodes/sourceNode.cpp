#include "sourceNode.hpp"
#include <QRegularExpression>

namespace xyla::render {

namespace {

// Sanitizes node IDs into clean GLSL identifier names
QString sanitizeGlslId(const QString &raw) {
  QString clean = raw;
  clean.replace(QRegularExpression("[^a-zA-Z0-9]"), "_");
  clean.replace(QRegularExpression("_+"), "_");
  if (clean.startsWith('_'))
    clean.remove(0, 1);
  if (!clean.isEmpty() && clean[0].isDigit())
    clean.prepend("n_");
  return clean;
}

} // namespace

// Node constructor
SourceNode::SourceNode(QString id, QString name, QString assetId)
    : Node(std::move(id), std::move(name), "SourceNode") {
  setPropertyValue("assetId", std::move(assetId));
  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

// Generates uniform code
QString SourceNode::generateGlslUniforms() const { return ""; }

// Samples global bound Vulkan video input texture as clean RGBA
QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  return QString("  vec4 %1 = texture(u_inputFrame, uv);\n").arg(outputVar);
}

} // namespace xyla::render
