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

// Declares raw NV12 Y and UV plane samplers & ITU-R BT.709 colorspace matrix
// conversion
QString SourceNode::generateGlslUniforms() const {
  QString cleanId = sanitizeGlslId(id());
  return QString(R"(
layout(binding = 1) uniform sampler2D u_planeY;
layout(binding = 2) uniform sampler2D u_planeUV;

vec4 sample_%1(vec2 sampleUv) {
    if (sampleUv.x < 0.0 || sampleUv.x > 1.0 || sampleUv.y < 0.0 || sampleUv.y > 1.0) {
        return vec4(0.0);
    }
    
    // Sample Y channel and interleaved UV channel
    float y_raw = texture(u_planeY, sampleUv).r;
    vec2 uv_raw = texture(u_planeUV, sampleUv).rg;

    // ITU-R BT.709 Studio Range [16, 235] -> Full Range [0, 1] Matrix
    float c = y_raw - 0.0627451; // (Y - 16 / 255)
    float d = uv_raw.r - 0.5;    // (U - 128 / 255)
    float e = uv_raw.g - 0.5;    // (V - 128 / 255)

    float r = clamp(1.164383 * c + 1.596027 * e, 0.0, 1.0);
    float g = clamp(1.164383 * c - 0.391762 * d - 0.812968 * e, 0.0, 1.0);
    float b = clamp(1.164383 * c + 2.017232 * d, 0.0, 1.0);

    return vec4(r, g, b, 1.0);
}
)")
      .arg(cleanId);
}

QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);
  QString cleanId = sanitizeGlslId(id());

  return QString("  vec4 %1 = sample_%2(uv);\n").arg(outputVar).arg(cleanId);
}

} // namespace xyla::render
