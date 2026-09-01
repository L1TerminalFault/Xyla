#include "sourceNode.hpp"
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

SourceNode::SourceNode(QString id, QString name, QString assetId)
    : Node(std::move(id), std::move(name), "SourceNode"),
      m_assetId(std::move(assetId)) {
  addOutput("video_out", "Video Out", SocketDataType::Image);
}

// Helper sampler function generated in GLOBAL scope (above main())
QString SourceNode::generateGlslUniforms() const {
  QString cleanId = sanitizeGlslId(id());

  return QString(R"(
vec4 sample_%1(vec2 st) {
  if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
    return vec4(0.0);
  }
  float yVal = texture(u_planeY, st).r;
  vec2 uvVal = texture(u_planeUV, st).rg;

  // BT.709 Standard YUV to Linear RGB
  float c = yVal - 0.0627451;
  float d = uvVal.r - 0.5;
  float e = uvVal.g - 0.5;

  float r = clamp(1.164383 * c + 1.792741 * e, 0.0, 1.0);
  float g = clamp(1.164383 * c - 0.213249 * d - 0.532909 * e, 0.0, 1.0);
  float b = clamp(1.164383 * c + 2.112402 * d, 0.0, 1.0);

  return vec4(r, g, b, 1.0);
}
)")
      .arg(cleanId);
}

// Executed INSIDE main()
QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  QString cleanId = sanitizeGlslId(id());
  return QString("  vec4 %1 = sample_%2(uv);\n").arg(outputVar, cleanId);
}

QVariantMap SourceNode::toVariantMap() const {
  auto map = Node::toVariantMap();
  map["assetId"] = m_assetId;
  return map;
}

} // namespace xyla::render
