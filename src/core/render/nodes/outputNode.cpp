#include "outputNode.hpp"
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

OutputNode::OutputNode(QString id, QString name)
    : Node(std::move(id), std::move(name), "OutputNode") {
  addInput("video_in", "Video In", SocketDataType::Image);
  addInput("opacity", "Opacity", SocketDataType::Float, 1.0f);
  addInput("blendMode", "Blend Mode", SocketDataType::Int, int32_t(0));

  addOutput("video_out", "Video Out", SocketDataType::Image);
}

QString OutputNode::generateGlslUniforms() const {
  return QString(R"(
vec3 applyBlendMode(int mode, vec3 base, vec3 blend) {
  switch (mode) {
    case 1:  return base * blend;
    case 2:  return 1.0 - (1.0 - base) * (1.0 - blend);
    case 3:  return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5, base));
    case 4:  return min(base, blend);
    case 5:  return max(base, blend);
    case 6:  return clamp(base / max(1.0 - blend, 0.0001), 0.0, 1.0);
    case 7:  return 1.0 - clamp((1.0 - base) / max(blend, 0.0001), 0.0, 1.0);
    case 8:  return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5, blend));
    case 9:  return (1.0 - 2.0 * blend) * base * base + 2.0 * blend * base;
    case 10: return abs(base - blend);
    case 11: return base + blend - 2.0 * base * blend;
    case 12: return min(base + blend, vec3(1.0));
    default: return blend;
  }
}
)");
}

QString OutputNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  QString cleanId = sanitizeGlslId(id());

  auto inTexIt = inputVars.find("video_in");
  QString inTex = (inTexIt != inputVars.end()) ? inTexIt->second : "vec4(0.0)";

  auto opacityIt = inputVars.find("opacity");
  QString opacityVar = (opacityIt != inputVars.end())
                           ? opacityIt->second
                           : QString("u_params.pc_%1_opacity").arg(cleanId);

  return QString(R"(
  vec4 %1 = vec4(%2.rgb, %2.a * clamp(%3, 0.0, 1.0));
)")
      .arg(outputVar, inTex, opacityVar);
}

} // namespace xyla::render
