#include "colorGradeNode.hpp"
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

ColorGradeNode::ColorGradeNode(QString id, QString name)
    : Node(std::move(id), std::move(name), "ColorGradeNode") {
  addInput("video_in", "Video In", SocketDataType::Image);

  // 4 Primary Color Wheels (Lift, Gamma, Gain, Offset)
  addInput("lift", "Lift", SocketDataType::Color,
           ColorVal{0.0f, 0.0f, 0.0f, 0.0f});
  addInput("gamma", "Gamma", SocketDataType::Color,
           ColorVal{1.0f, 1.0f, 1.0f, 0.0f});
  addInput("gain", "Gain", SocketDataType::Color,
           ColorVal{1.0f, 1.0f, 1.0f, 0.0f});
  addInput("offset", "Offset", SocketDataType::Color,
           ColorVal{0.0f, 0.0f, 0.0f, 0.0f});

  // Top Header Parameters
  addInput("temperature", "Temperature", SocketDataType::Float, 0.0f);
  addInput("tint", "Tint", SocketDataType::Float, 0.0f);
  addInput("contrast", "Contrast", SocketDataType::Float, 1.0f);
  addInput("pivot", "Pivot", SocketDataType::Float, 0.435f);
  addInput("midDetail", "Mid Detail", SocketDataType::Float, 0.0f);

  // Bottom Footer Parameters
  addInput("colorBoost", "Color Boost", SocketDataType::Float, 0.0f);
  addInput("shadows", "Shadows", SocketDataType::Float, 0.0f);
  addInput("highlights", "Highlights", SocketDataType::Float, 0.0f);
  addInput("saturation", "Saturation", SocketDataType::Float, 50.0f);
  addInput("hue", "Hue", SocketDataType::Float, 50.0f);
  addInput("lumMix", "Lum Mix", SocketDataType::Float, 100.0f);

  addOutput("video_out", "Video Out", SocketDataType::Image);
}

QString ColorGradeNode::generateGlslUniforms() const { return ""; }

QString ColorGradeNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  QString cleanId = sanitizeGlslId(id());

  auto inTexIt = inputVars.find("video_in");
  QString inTex = (inTexIt != inputVars.end()) ? inTexIt->second : "vec4(0.0)";

  QString liftVar = inputVars.count("lift")
                        ? inputVars.at("lift")
                        : QString("u_push.pc_%1_lift").arg(cleanId);
  QString gammaVar = inputVars.count("gamma")
                         ? inputVars.at("gamma")
                         : QString("u_push.pc_%1_gamma").arg(cleanId);
  QString gainVar = inputVars.count("gain")
                        ? inputVars.at("gain")
                        : QString("u_push.pc_%1_gain").arg(cleanId);
  QString offsetVar = inputVars.count("offset")
                          ? inputVars.at("offset")
                          : QString("u_push.pc_%1_offset").arg(cleanId);

  QString tempVar = inputVars.count("temperature")
                        ? inputVars.at("temperature")
                        : QString("u_push.pc_%1_temperature").arg(cleanId);
  QString tintVar = inputVars.count("tint")
                        ? inputVars.at("tint")
                        : QString("u_push.pc_%1_tint").arg(cleanId);
  QString conVar = inputVars.count("contrast")
                       ? inputVars.at("contrast")
                       : QString("u_push.pc_%1_contrast").arg(cleanId);
  QString pivVar = inputVars.count("pivot")
                       ? inputVars.at("pivot")
                       : QString("u_push.pc_%1_pivot").arg(cleanId);
  QString midVar = inputVars.count("midDetail")
                       ? inputVars.at("midDetail")
                       : QString("u_push.pc_%1_midDetail").arg(cleanId);

  QString cBoostVar = inputVars.count("colorBoost")
                          ? inputVars.at("colorBoost")
                          : QString("u_push.pc_%1_colorBoost").arg(cleanId);
  QString shadVar = inputVars.count("shadows")
                        ? inputVars.at("shadows")
                        : QString("u_push.pc_%1_shadows").arg(cleanId);
  QString highVar = inputVars.count("highlights")
                        ? inputVars.at("highlights")
                        : QString("u_push.pc_%1_highlights").arg(cleanId);
  QString satVar = inputVars.count("saturation")
                       ? inputVars.at("saturation")
                       : QString("u_push.pc_%1_saturation").arg(cleanId);
  QString lumMixVar = inputVars.count("lumMix")
                          ? inputVars.at("lumMix")
                          : QString("u_push.pc_%1_lumMix").arg(cleanId);

  QString code;
  code += QString("  vec4 srcColor_%1 = %2;\n").arg(cleanId, inTex);
  code += QString("  vec3 rgb_%1 = srcColor_%1.rgb;\n").arg(cleanId);

  // 1. Temperature & Tint
  code += QString("  rgb_%1.r += %2 * 0.08;\n").arg(cleanId, tempVar);
  code += QString("  rgb_%1.b -= %2 * 0.08;\n").arg(cleanId, tempVar);
  code += QString("  rgb_%1.g += %2 * 0.08;\n").arg(cleanId, tintVar);

  // 2. Lift / Gamma / Gain / Offset (DaVinci Primaries Math)
  code += QString("  vec3 liftVal_%1 = %2.rgb;\n").arg(cleanId, liftVar);
  code += QString("  vec3 gammaVal_%1 = max(%2.rgb, vec3(0.01));\n")
              .arg(cleanId, gammaVar);
  code += QString("  vec3 gainVal_%1 = %2.rgb;\n").arg(cleanId, gainVar);
  code += QString("  vec3 offsetVal_%1 = %2.rgb;\n").arg(cleanId, offsetVar);

  code += QString("  rgb_%1 = gainVal_%1 * (rgb_%1 + liftVal_%1 * (vec3(1.0) - "
                  "rgb_%1));\n")
              .arg(cleanId);
  code += QString("  rgb_%1 = max(rgb_%1, vec3(0.0));\n").arg(cleanId);
  code +=
      QString(
          "  rgb_%1 = pow(rgb_%1, vec3(1.0) / gammaVal_%1) + offsetVal_%1;\n")
          .arg(cleanId);

  // 3. Shadows & Highlights Recovery
  code +=
      QString(
          "  float origLuma_%1 = dot(rgb_%1, vec3(0.2126, 0.7152, 0.0722));\n")
          .arg(cleanId);
  code += QString("  rgb_%1 += (1.0 - smoothstep(0.0, 0.5, origLuma_%1)) * %2 "
                  "* 0.35;\n")
              .arg(cleanId, shadVar);
  code +=
      QString("  rgb_%1 += smoothstep(0.5, 1.0, origLuma_%1) * %2 * 0.35;\n")
          .arg(cleanId, highVar);

  // 4. DaVinci Midtone Detail (Portable High-Pass Kernel via u_planeY texel
  // offsets)
  code += QString("  vec2 texel_%1 = 1.0 / vec2(imgSize);\n").arg(cleanId);
  code += QString("  float lumaN_%1 = texture(u_planeY, uv + vec2(0.0, "
                  "texel_%1.y)).r;\n")
              .arg(cleanId);
  code += QString("  float lumaS_%1 = texture(u_planeY, uv - vec2(0.0, "
                  "texel_%1.y)).r;\n")
              .arg(cleanId);
  code += QString("  float lumaE_%1 = texture(u_planeY, uv + vec2(texel_%1.x, "
                  "0.0)).r;\n")
              .arg(cleanId);
  code += QString("  float lumaW_%1 = texture(u_planeY, uv - vec2(texel_%1.x, "
                  "0.0)).r;\n")
              .arg(cleanId);
  code += QString("  float lumaCenter_%1 = texture(u_planeY, uv).r;\n")
              .arg(cleanId);
  code += QString("  float highPassLaplacian_%1 = (lumaCenter_%1 * 4.0) - "
                  "(lumaN_%1 + lumaS_%1 + lumaE_%1 + lumaW_%1);\n")
              .arg(cleanId);
  code += QString("  float midWeight_%1 = smoothstep(0.1, 0.4, origLuma_%1) * "
                  "(1.0 - smoothstep(0.6, 0.9, origLuma_%1));\n")
              .arg(cleanId);
  code +=
      QString(
          "  rgb_%1 += vec3(highPassLaplacian_%1) * midWeight_%1 * %2 * 3.5;\n")
          .arg(cleanId, midVar);

  // 5. Contrast & Pivot S-Curve
  code += QString("  rgb_%1 = (rgb_%1 - vec3(%2)) * %3 + vec3(%2);\n")
              .arg(cleanId, pivVar, conVar);

  // 6. Smart Color Boost & Saturation
  code += QString("  float maxC_%1 = max(rgb_%1.r, max(rgb_%1.g, rgb_%1.b));\n")
              .arg(cleanId);
  code += QString("  float minC_%1 = min(rgb_%1.r, min(rgb_%1.g, rgb_%1.b));\n")
              .arg(cleanId);
  code += QString("  float currentSat_%1 = (maxC_%1 - minC_%1) / max(maxC_%1, "
                  "0.001);\n")
              .arg(cleanId);
  code +=
      QString("  float boostFactor_%1 = (1.0 - currentSat_%1) * %2 * 0.02;\n")
          .arg(cleanId, cBoostVar);
  code += QString("  float satMultiplier_%1 = max(0.0, (%2 / 50.0) + "
                  "boostFactor_%1);\n")
              .arg(cleanId, satVar);

  code +=
      QString(
          "  float finalLuma_%1 = dot(rgb_%1, vec3(0.2126, 0.7152, 0.0722));\n")
          .arg(cleanId);
  code += QString("  vec3 satRgb_%1 = mix(vec3(finalLuma_%1), rgb_%1, "
                  "satMultiplier_%1);\n")
              .arg(cleanId);

  // 7. Lum Mix (Luminance preservation)
  code += QString("  vec3 mixedRgb_%1 = mix(vec3(finalLuma_%1), satRgb_%1, %2 "
                  "* 0.01);\n")
              .arg(cleanId, lumMixVar);

  code +=
      QString(
          "  vec4 %1 = vec4(clamp(mixedRgb_%2, 0.0, 1.0), srcColor_%2.a);\n")
          .arg(outputVar, cleanId);

  return code;
}

} // namespace xyla::render
