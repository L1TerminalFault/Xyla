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
  addInput("posX", "Position X", SocketDataType::Float, 0.0f);
  addInput("posY", "Position Y", SocketDataType::Float, 0.0f);
  addInput("scaleX", "Scale X", SocketDataType::Float, 1.0f);
  addInput("scaleY", "Scale Y", SocketDataType::Float, 1.0f);
  addInput("rotation", "Rotation", SocketDataType::Float, 0.0f);
  addInput("anchorX", "Anchor X", SocketDataType::Float, 0.5f);
  addInput("anchorY", "Anchor Y", SocketDataType::Float, 0.5f);

  addOutput("video_out", "Video Out", SocketDataType::Image);
}

void TransformNode::bindAnimationManager(const QString &clipId,
                                         anim::AnimationManager &animMgr) {
  const QString prefix = clipId + ".transform.";
  setPropertyHandle("posX", animMgr.findHandle(prefix + "posX"));
  setPropertyHandle("posY", animMgr.findHandle(prefix + "posY"));
  setPropertyHandle("scaleX", animMgr.findHandle(prefix + "scaleX"));
  setPropertyHandle("scaleY", animMgr.findHandle(prefix + "scaleY"));
  setPropertyHandle("rotation", animMgr.findHandle(prefix + "rotation"));
}

QString TransformNode::generateGlslUniforms() const { return ""; }

QString TransformNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  QString cleanId = sanitizeGlslId(id());

  auto getVar = [&](const QString &sockId, float defVal) {
    auto it = inputVars.find(sockId);
    return (it != inputVars.end()) ? it->second
                                   : QString("u_params.pc_%1_%2")
                                         .arg(cleanId, sanitizeGlslId(sockId));
  };

  QString posX = getVar("posX", 0.0f);
  QString posY = getVar("posY", 0.0f);
  QString scaleX = getVar("scaleX", 1.0f);
  QString scaleY = getVar("scaleY", 1.0f);
  QString rot = getVar("rotation", 0.0f);
  QString anchorX = getVar("anchorX", 0.5f);
  QString anchorY = getVar("anchorY", 0.5f);

  auto funcIt = inputVars.find("video_in_func");
  if (funcIt == inputVars.end() || funcIt->second.isEmpty()) {
    auto inTexIt = inputVars.find("video_in");
    if (inTexIt != inputVars.end() && inTexIt->second != "vec4(0.0)") {
      return QString("  vec4 %1 = %2;\n").arg(outputVar, inTexIt->second);
    }
    return QString("  vec4 %1 = vec4(0.0);\n").arg(outputVar);
  }

  QString upstreamSampleFunc = funcIt->second;

  return QString(R"(
  float aspect_%1 = float(imgSize.x) / max(float(imgSize.y), 1.0);
  vec2 anchor_%1 = vec2(%7, %8);
  vec2 centeredUv_%1 = sampleUv - anchor_%1;
  centeredUv_%1.x *= aspect_%1;

  float rad_%1 = radians(%6);
  mat2 rotMat_%1 = mat2(cos(rad_%1), -sin(rad_%1), sin(rad_%1), cos(rad_%1));
  vec2 posAspect_%1 = vec2(%2 * aspect_%1, -%3);
  vec2 rotatedUv_%1 = rotMat_%1 * (centeredUv_%1 - posAspect_%1);

  vec2 safeScale_%1 = sign(vec2(%4, %5)) * max(abs(vec2(%4, %5)), vec2(0.0001));
  vec2 scaledUv_%1 = rotatedUv_%1 / safeScale_%1;
  scaledUv_%1.x /= aspect_%1;
  vec2 uv_%1 = scaledUv_%1 + anchor_%1;

  vec4 %9 = %10(uv_%1);
)")
      .arg(cleanId, posX, posY, scaleX, scaleY, rot, anchorX, anchorY,
           outputVar, upstreamSampleFunc);
}

} // namespace xyla::render
