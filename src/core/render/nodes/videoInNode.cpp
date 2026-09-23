#include "videoInNode.hpp"
#include <QRegularExpression>

namespace xyla::render {

namespace {

QString sanitizeGlslIdentifier(const QString &raw) {
  QString clean = raw;
  clean.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9]")),
                QStringLiteral("_"));
  clean.replace(QRegularExpression(QStringLiteral("_+")), QStringLiteral("_"));
  if (clean.startsWith(QLatin1Char('_')))
    clean.remove(0, 1);
  if (!clean.isEmpty() && clean.at(0).isDigit())
    clean.prepend(QStringLiteral("n_"));
  return clean;
}

} // namespace

VideoInNode::VideoInNode(QString id, QString name, QString assetId)
    : Node(std::move(id)), m_assetId(std::move(assetId)) {
  setName(name.isEmpty() ? StaticDefaultName : std::move(name));
  addOutput(QStringLiteral("video_out"), QStringLiteral("Video Out"),
            SocketDataType::Image);
}

std::vector<QString> VideoInNode::declaredSamplerNames() const {
  const QString cleanId = sanitizeGlslIdentifier(m_id);
  return {QStringLiteral("u_planeY_%1").arg(cleanId),
          QStringLiteral("u_planeUV_%1").arg(cleanId)};
}

PixelRect VideoInNode::computeRegionOfDefinition(
    const std::unordered_map<QString, PixelRect> &,
    const RenderContext &ctx) const {
  if (m_nativeWidth > 0 && m_nativeHeight > 0) {
    return PixelRect{0, 0, m_nativeWidth, m_nativeHeight};
  }
  return PixelRect{0, 0, static_cast<int32_t>(ctx.formatWidth),
                   static_cast<int32_t>(ctx.formatHeight)};
}

QString VideoInNode::generateGlslUniforms() const {
  return QStringLiteral(R"(
vec4 yuvToRgbaBt709(vec2 uv, sampler2D planeY, sampler2D planeUV) {
  // Studio / Limited Range BT.709 Decode
  float y = (texture(planeY, uv).r - (16.0 / 255.0)) * (255.0 / (235.0 - 16.0));
  vec2 uvChroma = texture(planeUV, uv).rg - vec2(0.5, 0.5);

  float r = y + 1.5748 * uvChroma.y;
  float g = y - 0.1873 * uvChroma.x - 0.4681 * uvChroma.y;
  float b = y + 1.8556 * uvChroma.x;

  return vec4(clamp(vec3(r, g, b), 0.0, 1.0), 1.0);
}

vec4 decodeSourceColor(vec4 col, int alphaMode, int colorSpace) {
  if (alphaMode == 2) {
    col.a = 1.0;
  } else if (alphaMode == 1) {
    col.rgb *= col.a;
  }

  // Linearize only if specifically requested (Linear Working Space)
  if (colorSpace == 0) {
    col.rgb = mix(col.rgb / 12.92, pow((col.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, col.rgb));
  }

  return col;
}
)");
}

QString
VideoInNode::generateGlslCode(const std::unordered_map<QString, QString> &,
                              const QString &outputVar) const {
  const QString cleanId = sanitizeGlslIdentifier(m_id);

  return QStringLiteral(
             "  vec4 raw_%1 = yuvToRgbaBt709(uv, u_planeY_%1, u_planeUV_%1);\n"
             "  vec4 %2 = decodeSourceColor(raw_%1, %3, %4);\n")
      .arg(cleanId, outputVar, QString::number(static_cast<int>(m_alphaMode)),
           QString::number(static_cast<int>(m_colorSpace)));
}

QVariantMap
VideoInNode::toVariantMap(FrameIndex currentFrame,
                          const anim::AnimationManager *animMgr) const {
  auto map = Node::toVariantMap(currentFrame, animMgr);
  map[QStringLiteral("assetId")] = m_assetId;
  map[QStringLiteral("alphaMode")] = static_cast<int>(m_alphaMode);
  map[QStringLiteral("colorSpace")] = static_cast<int>(m_colorSpace);
  map[QStringLiteral("outOfRangeMode")] = static_cast<int>(m_outOfRangeMode);
  map[QStringLiteral("timeOffset")] = static_cast<qlonglong>(m_timeOffset);
  map[QStringLiteral("playbackSpeed")] = m_playbackSpeed;
  map[QStringLiteral("nativeWidth")] = m_nativeWidth;
  map[QStringLiteral("nativeHeight")] = m_nativeHeight;
  return map;
}

QJsonObject VideoInNode::serialize() const {
  auto json = Node::serialize();
  json[QStringLiteral("assetId")] = m_assetId;
  json[QStringLiteral("alphaMode")] = static_cast<int>(m_alphaMode);
  json[QStringLiteral("colorSpace")] = static_cast<int>(m_colorSpace);
  json[QStringLiteral("outOfRangeMode")] = static_cast<int>(m_outOfRangeMode);
  json[QStringLiteral("timeOffset")] = static_cast<qint64>(m_timeOffset);
  json[QStringLiteral("playbackSpeed")] = m_playbackSpeed;
  json[QStringLiteral("nativeWidth")] = m_nativeWidth;
  json[QStringLiteral("nativeHeight")] = m_nativeHeight;
  return json;
}

bool VideoInNode::deserialize(const QJsonObject &json) {
  if (!Node::deserialize(json))
    return false;
  m_assetId = json[QStringLiteral("assetId")].toString();
  m_alphaMode =
      static_cast<AlphaMode>(json[QStringLiteral("alphaMode")].toInt(0));
  m_colorSpace =
      static_cast<ColorSpace>(json[QStringLiteral("colorSpace")].toInt(2));
  m_outOfRangeMode = static_cast<OutOfRangeMode>(
      json[QStringLiteral("outOfRangeMode")].toInt(0));
  m_timeOffset = json[QStringLiteral("timeOffset")].toInteger(0);
  m_playbackSpeed =
      static_cast<float>(json[QStringLiteral("playbackSpeed")].toDouble(1.0));
  m_nativeWidth = json[QStringLiteral("nativeWidth")].toInt(1920);
  m_nativeHeight = json[QStringLiteral("nativeHeight")].toInt(1080);
  return true;
}

} // namespace xyla::render
