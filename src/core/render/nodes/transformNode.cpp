#include "transformNode.hpp"
#include <QRegularExpression>

namespace xyla::render {

namespace {

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

TransformNode::TransformNode(QString id, QString name)
    : Node(std::move(id), std::move(name), "TransformNode") {
  addInput("video_in", "Video In", SocketDataType::Image);
  addInput("position", "Position", SocketDataType::Vec2, Vec2Val{0.0f, 0.0f});
  addInput("scale", "Scale", SocketDataType::Vec2, Vec2Val{1.0f, 1.0f});
  addInput("rotation", "Rotation", SocketDataType::Float, 0.0f);
  addInput("anchor", "Anchor Point", SocketDataType::Vec2, Vec2Val{0.5f, 0.5f});

  addOutput("video_out", "Video Out", SocketDataType::Image);
}

QString TransformNode::generateGlslUniforms() const { return ""; }

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

  auto anchorIt = inputVars.find("anchor");
  QString anchorVar = (anchorIt != inputVars.end())
                          ? anchorIt->second
                          : QString("u_push.pc_%1_anchor").arg(cleanId);

  auto inTexIt = inputVars.find("video_in");
  bool isConnected =
      (inTexIt != inputVars.end() && inTexIt->second != "vec4(0.0)");

  if (!isConnected) {
    return QString("  vec4 %1 = vec4(0.0);\n").arg(outputVar);
  }

  // Derive source node function name dynamically
  QString srcNodeCleanId = cleanId;
  srcNodeCleanId.replace("_xform", "_src");

  return QString(R"(
  float aspect_%1 = float(imgSize.x) / max(float(imgSize.y), 1.0);
  vec2 anchor_%1 = %5;
  vec2 centeredUv_%1 = uv - anchor_%1;
  centeredUv_%1.x *= aspect_%1;

  float rad_%1 = radians(%4);
  mat2 rotMat_%1 = mat2(cos(rad_%1), -sin(rad_%1), sin(rad_%1), cos(rad_%1));
  vec2 posAspect_%1 = vec2(%2.x * aspect_%1, -%2.y);
  vec2 rotatedUv_%1 = rotMat_%1 * (centeredUv_%1 - posAspect_%1);

  vec2 safeScale_%1 = sign(%3) * max(abs(%3), vec2(0.0001));
  vec2 scaledUv_%1 = rotatedUv_%1 / safeScale_%1;
  scaledUv_%1.x /= aspect_%1;
  vec2 uv_%1 = scaledUv_%1 + anchor_%1;

  vec4 %6 = sample_%7(uv_%1);
)")
      .arg(cleanId, posVar, scaleVar, rotVar, anchorVar, outputVar,
           srcNodeCleanId);
}

} // namespace xyla::render
