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

QString OutputNode::generateGlslUniforms() const { return ""; }

QString OutputNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  QString cleanId = sanitizeGlslId(id());

  auto inTexIt = inputVars.find("video_in");
  QString inTex = (inTexIt != inputVars.end()) ? inTexIt->second : "vec4(0.0)";

  auto opacityIt = inputVars.find("opacity");
  QString opacityVar = (opacityIt != inputVars.end())
                           ? opacityIt->second
                           : QString("u_push.pc_%1_opacity").arg(cleanId);

  return QString(R"(
  vec4 %1 = %2 * %3;
)")
      .arg(outputVar, inTex, opacityVar);
}

} // namespace xyla::render
