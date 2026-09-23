#include "outputNode.hpp"

namespace xyla::render {

OutputNode::OutputNode(QString id, QString name) : Node(std::move(id)) {
  setName(name.isEmpty() ? StaticDefaultName : std::move(name));
  addInput(QStringLiteral("video_in"), QStringLiteral("Video In"),
           SocketDataType::Image);
  addInput(QStringLiteral("opacity"), QStringLiteral("Opacity"),
           SocketDataType::Float, 1.0f);
}

QString OutputNode::generateGlslUniforms() const {
  return QStringLiteral(R"(
vec4 applyOutputComposite(vec4 src, vec4 dst, int blendMode, float opacity) {
  src *= clamp(opacity, 0.0, 1.0);

  if (blendMode == 1) { // Premultiplied Over
    return src + dst * (1.0 - src.a);
  } else if (blendMode == 2) { // Additive
    return src + dst;
  } else if (blendMode == 3) { // Multiply
    return vec4(src.rgb * dst.rgb, src.a * dst.a);
  } else if (blendMode == 4) { // Screen
    return vec4(1.0 - (1.0 - src.rgb) * (1.0 - dst.rgb), max(src.a, dst.a));
  }

  // Normal Over
  float outAlpha = src.a + dst.a * (1.0 - src.a);
  vec3 outRgb = (outAlpha > 0.0001)
      ? (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / outAlpha
      : vec3(0.0);
  return vec4(outRgb, clamp(outAlpha, 0.0, 1.0));
}
)");
}

QString OutputNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  const auto srcIt = inputVars.find(QStringLiteral("video_in"));
  const QString inColor =
      (srcIt != inputVars.end()) ? srcIt->second : QStringLiteral("vec4(0.0)");

  const auto opIt = inputVars.find(QStringLiteral("opacity"));
  const QString opacityVar =
      (opIt != inputVars.end()) ? opIt->second : QStringLiteral("1.0");

  return QStringLiteral(
             "  vec4 dst_frame = imageLoad(u_outputFrame, pixelCoord);\n"
             "  vec4 %1 = applyOutputComposite(%2, dst_frame, %3, %4);\n")
      .arg(outputVar, inColor, QString::number(static_cast<int>(m_blendMode)),
           opacityVar);
}

QVariantMap
OutputNode::toVariantMap(FrameIndex currentFrame,
                         const anim::AnimationManager *animMgr) const {
  auto map = Node::toVariantMap(currentFrame, animMgr);
  map[QStringLiteral("blendMode")] = static_cast<int>(m_blendMode);
  return map;
}

QJsonObject OutputNode::serialize() const {
  auto json = Node::serialize();
  json[QStringLiteral("blendMode")] = static_cast<int>(m_blendMode);
  return json;
}

bool OutputNode::deserialize(const QJsonObject &json) {
  if (!Node::deserialize(json))
    return false;
  m_blendMode =
      static_cast<OutputBlendMode>(json[QStringLiteral("blendMode")].toInt(0));
  return true;
}

} // namespace xyla::render
