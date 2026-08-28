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
  addInput("blendMode", "Blend Mode", SocketDataType::Int, 0);

  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

// Generates uniform code
QString TransformNode::generateGlslUniforms() const { return ""; }

// Applies Aspect-Corrected 2D Affine Matrix Transformation (Position, Scale, 2D
// Rotation, Opacity)
QString TransformNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  QString cleanId = sanitizeGlslId(id());

  auto posIt = inputVars.find("position");
  QString posVar = (posIt != inputVars.end())
                       ? posIt->second
                       : QString("u_push.pc_%1_position").arg(cleanId);

  auto scaleIt = inputVars.find("scale");
  QString scaleVar = (scaleIt != inputVars.end())
                         ? scaleIt->second
                         : QString("u_push.pc_%1_scale").arg(cleanId);

  auto rotIt = inputVars.find("rotation");
  QString rotVar = (rotIt != inputVars.end())
                       ? rotIt->second
                       : QString("u_push.pc_%1_rotation").arg(cleanId);

  auto opacityIt = inputVars.find("opacity");
  QString opacityVar = (opacityIt != inputVars.end())
                           ? opacityIt->second
                           : QString("u_push.pc_%1_opacity").arg(cleanId);

  QString code;
  // 1. Aspect ratio compensation for 16:9 viewport
  code += QString("  float aspect_%1 = float(imgSize.x) / "
                  "max(float(imgSize.y), 1.0);\n")
              .arg(cleanId);
  code += QString("  vec2 centeredUv_%1 = uv - vec2(0.5);\n").arg(cleanId);
  code += QString("  centeredUv_%1.x *= aspect_%1;\n").arg(cleanId);

  // 2. 2D Rotation Matrix & Position Translation in Aspect-Corrected Euclidean
  // space
  code += QString("  float rad_%1 = radians(%2);\n").arg(cleanId).arg(rotVar);
  code += QString("  mat2 rotMat_%1 = mat2(cos(rad_%1), -sin(rad_%1), "
                  "sin(rad_%1), cos(rad_%1));\n")
              .arg(cleanId);
  code += QString("  vec2 posAspect_%1 = vec2(%2.x * aspect_%1, -%2.y);\n")
              .arg(cleanId)
              .arg(posVar);
  code +=
      QString(
          "  vec2 rotatedUv_%1 = rotMat_%1 * (centeredUv_%1 - posAspect_%1);\n")
          .arg(cleanId);

  // 3. Scale and Aspect Un-Stretching
  code +=
      QString("  vec2 scaledUv_%1 = rotatedUv_%1 / max(%2, vec2(0.0001));\n")
          .arg(cleanId)
          .arg(scaleVar);
  code += QString("  scaledUv_%1.x /= aspect_%1;\n").arg(cleanId);
  code += QString("  vec2 uv_%1 = scaledUv_%1 + vec2(0.5);\n").arg(cleanId);

  // 4. Sample source at transformed UVs and apply opacity
  QString srcNodeCleanId = cleanId;
  srcNodeCleanId.replace("_xform", "_src");

  code += QString("  vec4 %1 = sample_%2(uv_%3) * %4;\n")
              .arg(outputVar)
              .arg(srcNodeCleanId)
              .arg(cleanId)
              .arg(opacityVar);

  return code;
}

} // namespace xyla::render
