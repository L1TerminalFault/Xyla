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
    : Node(std::move(id), std::move(name), "SourceNode") {
  setPropertyValue("assetId", std::move(assetId));
  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

// Declares raw NV12 Y and UV plane samplers & a GLSL sampling helper function
QString SourceNode::generateGlslUniforms() const {
  QString cleanId = sanitizeGlslId(id());
  return QString(R"(
layout(binding = 1) uniform sampler2D u_planeY;
layout(binding = 2) uniform sampler2D u_planeUV;

vec4 sample_%1(vec2 sampleUv) {
    if (sampleUv.x < 0.0 || sampleUv.x > 1.0 || sampleUv.y < 0.0 || sampleUv.y > 1.0) {
        return vec4(0.0);
    }
    float y_val = texture(u_planeY, sampleUv).r;
    vec2 uv_val = texture(u_planeUV, sampleUv).rg - vec2(0.5, 0.5);

    float r_col = y_val + 1.5748 * uv_val.y;
    float g_col = y_val - 0.1873 * uv_val.x - 0.4681 * uv_val.y;
    float b_col = y_val + 1.8556 * uv_val.x;

    return vec4(clamp(r_col, 0.0, 1.0), clamp(g_col, 0.0, 1.0), clamp(b_col, 0.0, 1.0), 1.0);
}
)")
      .arg(cleanId);
}

// Samples texture at default un-transformed UV
QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  QString cleanId = sanitizeGlslId(id());

  return QString("  vec4 %1 = sample_%2(uv);\n").arg(outputVar).arg(cleanId);
}

} // namespace xyla::render
