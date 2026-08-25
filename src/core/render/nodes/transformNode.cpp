#include "transformNode.hpp"
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
TransformNode::TransformNode(QString id, QString name)
    : Node(std::move(id), std::move(name), "TransformNode") {
  addInput("tex_in", "Texture In", SocketDataType::Image);
  addInput("position", "Position", SocketDataType::Vec2, Vec2Val{0.0f, 0.0f});
  addInput("scale", "Scale", SocketDataType::Vec2, Vec2Val{1.0f, 1.0f});
  addInput("rotation", "Rotation", SocketDataType::Float, 0.0f);
  addInput("opacity", "Opacity", SocketDataType::Float, 1.0f);

  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

// Generates uniform code
QString TransformNode::generateGlslUniforms() const { return ""; }

// Applies UV transform, scale, position, and opacity blending
QString TransformNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  QString cleanId = sanitizeGlslId(id());

  auto texIt = inputVars.find("tex_in");
  QString texVar = (texIt != inputVars.end()) ? texIt->second : "vec4(0.0)";

  auto posIt = inputVars.find("position");
  QString posVar = (posIt != inputVars.end())
                       ? posIt->second
                       : QString("u_push.pc_%1_position").arg(cleanId);

  auto scaleIt = inputVars.find("scale");
  QString scaleVar = (scaleIt != inputVars.end())
                         ? scaleIt->second
                         : QString("u_push.pc_%1_scale").arg(cleanId);

  auto opacityIt = inputVars.find("opacity");
  QString opacityVar = (opacityIt != inputVars.end())
                           ? opacityIt->second
                           : QString("u_push.pc_%1_opacity").arg(cleanId);

  QString code;
  code += QString("  vec2 uv_%1 = (uv - vec2(0.5) - %2) / max(%3, "
                  "vec2(0.0001)) + vec2(0.5);\n")
              .arg(cleanId)
              .arg(posVar)
              .arg(scaleVar);

  code += QString("  vec4 %1 = (uv_%2.x >= 0.0 && uv_%2.x <= 1.0 && uv_%2.y >= "
                  "0.0 && uv_%2.y <= 1.0) ? (%3 * %4) : vec4(0.0);\n")
              .arg(outputVar)
              .arg(cleanId)
              .arg(texVar)
              .arg(opacityVar);

  return code;
}

} // namespace xyla::render
