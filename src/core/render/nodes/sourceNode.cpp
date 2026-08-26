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

// Declares raw NV12 Y and UV plane samplers at bindings 1 and 2
QString SourceNode::generateGlslUniforms() const {
  return "layout(binding = 1) uniform sampler2D u_planeY;\n"
         "layout(binding = 2) uniform sampler2D u_planeUV;\n";
}

// BT.709 YUV -> RGBA Conversion directly in GLSL Compute Shader
QString SourceNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {
  Q_UNUSED(inputVars);

  return QString(R"(
  float y_val = texture(u_planeY, uv).r;
  vec2 uv_val = texture(u_planeUV, uv).rg - vec2(0.5, 0.5);

  // BT.709 Color Matrix Transform
  float r_col = y_val + 1.5748 * uv_val.y;
  float g_col = y_val - 0.1873 * uv_val.x - 0.4681 * uv_val.y;
  float b_col = y_val + 1.8556 * uv_val.x;

  vec4 %1 = vec4(clamp(r_col, 0.0, 1.0), clamp(g_col, 0.0, 1.0), clamp(b_col, 0.0, 1.0), 1.0);
)")
      .arg(outputVar);
}

} // namespace xyla::render
