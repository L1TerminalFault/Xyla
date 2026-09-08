#include "timelineClip.hpp"
#include <QJsonArray>
#include <QJsonObject>

namespace xyla {

namespace {

QJsonObject serializeAnimProperty(const anim::AnimProperty &prop) {
  QJsonObject obj;
  obj["value"] = static_cast<double>(prop.staticValue());
  obj["isAnimated"] = prop.isAnimated();
  if (prop.isAnimated()) {
    QJsonArray kfArray;
    for (const auto &kf : prop.keyframes()) {
      QJsonObject kfObj;
      kfObj["frame"] = static_cast<qint64>(kf.frame);
      kfObj["value"] = static_cast<double>(kf.value);
      kfObj["interp"] = static_cast<int>(kf.interpolation);
      kfArray.append(kfObj);
    }
    obj["keyframes"] = kfArray;
  }
  return obj;
}

void deserializeAnimProperty(const QJsonObject &obj, anim::AnimProperty &prop,
                             float defaultVal) {
  float val = static_cast<float>(obj.value("value").toDouble(defaultVal));
  prop.setStaticValue(val);
  if (obj.value("isAnimated").toBool(false)) {
    QJsonArray kfArray = obj.value("keyframes").toArray();
    for (const auto &item : kfArray) {
      QJsonObject kfObj = item.toObject();
      auto frame =
          static_cast<anim::FrameIndex>(kfObj.value("frame").toInteger());
      auto kfVal = static_cast<float>(kfObj.value("value").toDouble());
      auto interp =
          static_cast<anim::Interpolation>(kfObj.value("interp").toInt(1));
      prop.setKeyframe(frame, kfVal, interp);
    }
  }
}

} // namespace

QJsonObject TimelineClip::serialize() const {
  QJsonObject obj;
  obj["clipId"] = m_clipId;
  obj["assetId"] = m_assetId;
  obj["name"] = m_name;
  obj["startFrame"] = static_cast<qint64>(m_startFrame);
  obj["durationFrames"] = static_cast<qint64>(m_durationFrames);
  obj["sourceInFrame"] = static_cast<qint64>(m_sourceInFrame);
  obj["trackIndex"] = m_trackIndex;
  obj["speed"] = m_speed;
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;
  obj["linkGroupId"] = m_linkGroupId;
  obj["blendMode"] = m_blendMode;

  QJsonObject xformObj;
  xformObj["posX"] = serializeAnimProperty(m_transform.posX);
  xformObj["posY"] = serializeAnimProperty(m_transform.posY);
  xformObj["scaleX"] = serializeAnimProperty(m_transform.scaleX);
  xformObj["scaleY"] = serializeAnimProperty(m_transform.scaleY);
  xformObj["rotation"] = serializeAnimProperty(m_transform.rotation);
  xformObj["opacity"] = serializeAnimProperty(m_transform.opacity);
  obj["transform"] = xformObj;

  QJsonObject colorObj;
  colorObj["liftR"] = serializeAnimProperty(m_color.liftR);
  colorObj["liftG"] = serializeAnimProperty(m_color.liftG);
  colorObj["liftB"] = serializeAnimProperty(m_color.liftB);
  colorObj["gammaR"] = serializeAnimProperty(m_color.gammaR);
  colorObj["gammaG"] = serializeAnimProperty(m_color.gammaG);
  colorObj["gammaB"] = serializeAnimProperty(m_color.gammaB);
  colorObj["gainR"] = serializeAnimProperty(m_color.gainR);
  colorObj["gainG"] = serializeAnimProperty(m_color.gainG);
  colorObj["gainB"] = serializeAnimProperty(m_color.gainB);
  colorObj["offsetR"] = serializeAnimProperty(m_color.offsetR);
  colorObj["offsetG"] = serializeAnimProperty(m_color.offsetG);
  colorObj["offsetB"] = serializeAnimProperty(m_color.offsetB);

  colorObj["temperature"] = serializeAnimProperty(m_color.temperature);
  colorObj["tint"] = serializeAnimProperty(m_color.tint);
  colorObj["contrast"] = serializeAnimProperty(m_color.contrast);
  colorObj["pivot"] = serializeAnimProperty(m_color.pivot);
  colorObj["midDetail"] = serializeAnimProperty(m_color.midDetail);
  colorObj["colorBoost"] = serializeAnimProperty(m_color.colorBoost);
  colorObj["shadows"] = serializeAnimProperty(m_color.shadows);
  colorObj["highlights"] = serializeAnimProperty(m_color.highlights);
  colorObj["saturation"] = serializeAnimProperty(m_color.saturation);
  colorObj["hue"] = serializeAnimProperty(m_color.hue);
  colorObj["lumMix"] = serializeAnimProperty(m_color.lumMix);
  colorObj["bypass"] = m_color.bypass;
  obj["color"] = colorObj;

  QJsonObject audioObj;
  audioObj["volume"] = serializeAnimProperty(m_audio.volume);
  audioObj["pan"] = serializeAnimProperty(m_audio.pan);
  audioObj["channelMode"] = m_audio.channelMode;
  obj["audio"] = audioObj;

  obj["positionX"] = static_cast<double>(m_transform.posX.staticValue());
  obj["positionY"] = static_cast<double>(m_transform.posY.staticValue());
  obj["scaleX"] = static_cast<double>(m_transform.scaleX.staticValue());
  obj["scaleY"] = static_cast<double>(m_transform.scaleY.staticValue());
  obj["opacity"] = static_cast<double>(m_transform.opacity.staticValue());

  return obj;
}

TimelineClip TimelineClip::deserialize(const QJsonObject &obj) {
  QString clipId = obj.value("clipId").toString();
  QString assetId = obj.value("assetId").toString();
  QString name = obj.value("name").toString("Clip");
  FrameIndex startFrame =
      static_cast<FrameIndex>(obj.value("startFrame").toInteger(0));
  FrameIndex durationFrames =
      static_cast<FrameIndex>(obj.value("durationFrames").toInteger(30));
  FrameIndex sourceInFrame =
      static_cast<FrameIndex>(obj.value("sourceInFrame").toInteger(0));
  int trackIndex = obj.value("trackIndex").toInt(0);

  TimelineClip clip(clipId, assetId, name, startFrame, durationFrames,
                    sourceInFrame, trackIndex);

  clip.setSpeed(obj.value("speed").toDouble(1.0));
  clip.setMuted(obj.value("isMuted").toBool(false));
  clip.setLocked(obj.value("isLocked").toBool(false));
  clip.setLinkGroupId(obj.value("linkGroupId").toString());
  clip.setBlendMode(obj.value("blendMode").toInt(0));

  if (obj.contains("transform") && obj["transform"].isObject()) {
    QJsonObject xformObj = obj["transform"].toObject();
    deserializeAnimProperty(xformObj["posX"].toObject(), clip.transform().posX,
                            0.0f);
    deserializeAnimProperty(xformObj["posY"].toObject(), clip.transform().posY,
                            0.0f);
    deserializeAnimProperty(xformObj["scaleX"].toObject(),
                            clip.transform().scaleX, 1.0f);
    deserializeAnimProperty(xformObj["scaleY"].toObject(),
                            clip.transform().scaleY, 1.0f);
    deserializeAnimProperty(xformObj["rotation"].toObject(),
                            clip.transform().rotation, 0.0f);
    deserializeAnimProperty(xformObj["opacity"].toObject(),
                            clip.transform().opacity, 1.0f);
  } else {
    clip.transform().posX.setStaticValue(
        static_cast<float>(obj.value("positionX").toDouble(0.0)));
    clip.transform().posY.setStaticValue(
        static_cast<float>(obj.value("positionY").toDouble(0.0)));
    clip.transform().scaleX.setStaticValue(
        static_cast<float>(obj.value("scaleX").toDouble(1.0)));
    clip.transform().scaleY.setStaticValue(
        static_cast<float>(obj.value("scaleY").toDouble(1.0)));
    clip.transform().opacity.setStaticValue(
        static_cast<float>(obj.value("opacity").toDouble(1.0)));
  }

  if (obj.contains("color") && obj["color"].isObject()) {
    QJsonObject colorObj = obj["color"].toObject();
    deserializeAnimProperty(colorObj["liftR"].toObject(), clip.color().liftR,
                            0.0f);
    deserializeAnimProperty(colorObj["liftG"].toObject(), clip.color().liftG,
                            0.0f);
    deserializeAnimProperty(colorObj["liftB"].toObject(), clip.color().liftB,
                            0.0f);
    deserializeAnimProperty(colorObj["gammaR"].toObject(), clip.color().gammaR,
                            1.0f);
    deserializeAnimProperty(colorObj["gammaG"].toObject(), clip.color().gammaG,
                            1.0f);
    deserializeAnimProperty(colorObj["gammaB"].toObject(), clip.color().gammaB,
                            1.0f);
    deserializeAnimProperty(colorObj["gainR"].toObject(), clip.color().gainR,
                            1.0f);
    deserializeAnimProperty(colorObj["gainG"].toObject(), clip.color().gainG,
                            1.0f);
    deserializeAnimProperty(colorObj["gainB"].toObject(), clip.color().gainB,
                            1.0f);
    deserializeAnimProperty(colorObj["offsetR"].toObject(),
                            clip.color().offsetR, 0.0f);
    deserializeAnimProperty(colorObj["offsetG"].toObject(),
                            clip.color().offsetG, 0.0f);
    deserializeAnimProperty(colorObj["offsetB"].toObject(),
                            clip.color().offsetB, 0.0f);

    deserializeAnimProperty(colorObj["temperature"].toObject(),
                            clip.color().temperature, 0.0f);
    deserializeAnimProperty(colorObj["tint"].toObject(), clip.color().tint,
                            0.0f);
    deserializeAnimProperty(colorObj["contrast"].toObject(),
                            clip.color().contrast, 1.0f);
    deserializeAnimProperty(colorObj["pivot"].toObject(), clip.color().pivot,
                            0.435f);
    deserializeAnimProperty(colorObj["midDetail"].toObject(),
                            clip.color().midDetail, 0.0f);
    deserializeAnimProperty(colorObj["colorBoost"].toObject(),
                            clip.color().colorBoost, 0.0f);
    deserializeAnimProperty(colorObj["shadows"].toObject(),
                            clip.color().shadows, 0.0f);
    deserializeAnimProperty(colorObj["highlights"].toObject(),
                            clip.color().highlights, 0.0f);
    deserializeAnimProperty(colorObj["saturation"].toObject(),
                            clip.color().saturation, 50.0f);
    deserializeAnimProperty(colorObj["hue"].toObject(), clip.color().hue,
                            50.0f);
    deserializeAnimProperty(colorObj["lumMix"].toObject(), clip.color().lumMix,
                            100.0f);

    clip.color().bypass = colorObj.value("bypass").toBool(false);
  }

  if (obj.contains("audio") && obj["audio"].isObject()) {
    QJsonObject audioObj = obj["audio"].toObject();
    deserializeAnimProperty(audioObj["volume"].toObject(), clip.audio().volume,
                            1.0f);
    deserializeAnimProperty(audioObj["pan"].toObject(), clip.audio().pan, 0.0f);
    clip.audio().channelMode = audioObj.value("channelMode").toInt(0);
  }

  return clip;
}

QVariantMap TimelineClip::toVariantMap() const {
  QVariantMap map;
  map["clipId"] = m_clipId;
  map["assetId"] = m_assetId;
  map["name"] = m_name;
  map["startFrame"] = static_cast<double>(m_startFrame);
  map["durationFrames"] = static_cast<double>(m_durationFrames);
  map["sourceInFrame"] = static_cast<double>(m_sourceInFrame);
  map["trackIndex"] = m_trackIndex;
  map["speed"] = m_speed;
  map["isMuted"] = m_isMuted;
  map["isLocked"] = m_isLocked;
  map["linkGroupId"] = m_linkGroupId;
  map["blendMode"] = m_blendMode;

  QVariantMap xform;
  xform["positionX"] = static_cast<double>(m_transform.posX.staticValue());
  xform["positionY"] = static_cast<double>(m_transform.posY.staticValue());
  xform["scaleX"] = static_cast<double>(m_transform.scaleX.staticValue());
  xform["scaleY"] = static_cast<double>(m_transform.scaleY.staticValue());
  xform["rotation"] = static_cast<double>(m_transform.rotation.staticValue());
  xform["opacity"] = static_cast<double>(m_transform.opacity.staticValue());
  map["transform"] = xform;

  QVariantMap col;
  col["lift"] =
      QVariantList{static_cast<double>(m_color.liftR.staticValue()),
                   static_cast<double>(m_color.liftG.staticValue()),
                   static_cast<double>(m_color.liftB.staticValue()), 0.0};
  col["gamma"] =
      QVariantList{static_cast<double>(m_color.gammaR.staticValue()),
                   static_cast<double>(m_color.gammaG.staticValue()),
                   static_cast<double>(m_color.gammaB.staticValue()), 0.0};
  col["gain"] =
      QVariantList{static_cast<double>(m_color.gainR.staticValue()),
                   static_cast<double>(m_color.gainG.staticValue()),
                   static_cast<double>(m_color.gainB.staticValue()), 0.0};
  col["offset"] =
      QVariantList{static_cast<double>(m_color.offsetR.staticValue()),
                   static_cast<double>(m_color.offsetG.staticValue()),
                   static_cast<double>(m_color.offsetB.staticValue()), 0.0};

  col["temperature"] = m_color.temperature.staticValue();
  col["tint"] = m_color.tint.staticValue();
  col["contrast"] = m_color.contrast.staticValue();
  col["pivot"] = m_color.pivot.staticValue();
  col["midDetail"] = m_color.midDetail.staticValue();
  col["colorBoost"] = m_color.colorBoost.staticValue();
  col["shadows"] = m_color.shadows.staticValue();
  col["highlights"] = m_color.highlights.staticValue();
  col["saturation"] = m_color.saturation.staticValue();
  col["hue"] = m_color.hue.staticValue();
  col["lumMix"] = m_color.lumMix.staticValue();
  col["bypass"] = m_color.bypass;
  map["color"] = col;

  QVariantMap aud;
  aud["volume"] = m_audio.volume.staticValue();
  aud["pan"] = m_audio.pan.staticValue();
  aud["channelMode"] = m_audio.channelMode;
  map["audio"] = aud;

  map["positionX"] = static_cast<double>(m_transform.posX.staticValue());
  map["positionY"] = static_cast<double>(m_transform.posY.staticValue());
  map["scaleX"] = static_cast<double>(m_transform.scaleX.staticValue());
  map["scaleY"] = static_cast<double>(m_transform.scaleY.staticValue());
  map["opacity"] = static_cast<double>(m_transform.opacity.staticValue());

  map["nodes"] = nodeGraphNodes();
  map["links"] = nodeGraphLinks();

  return map;
}

QVariantMap TimelineClip::pushConstantValues(FrameIndex relativeFrame) const {
  QVariantMap map;

  map["position"] = QVariantList{
      static_cast<double>(m_transform.posX.evaluate(relativeFrame)),
      static_cast<double>(m_transform.posY.evaluate(relativeFrame))};
  map["scale"] = QVariantList{
      static_cast<double>(m_transform.scaleX.evaluate(relativeFrame)),
      static_cast<double>(m_transform.scaleY.evaluate(relativeFrame))};
  map["anchor"] = QVariantList{0.0, 0.0};
  map["rotation"] = m_transform.rotation.evaluate(relativeFrame);
  map["opacity"] = m_transform.opacity.evaluate(relativeFrame);
  map["blendMode"] = m_blendMode;

  map["lift"] = QVariantList{
      static_cast<double>(m_color.liftR.evaluate(relativeFrame)),
      static_cast<double>(m_color.liftG.evaluate(relativeFrame)),
      static_cast<double>(m_color.liftB.evaluate(relativeFrame)), 0.0};
  map["gamma"] = QVariantList{
      static_cast<double>(m_color.gammaR.evaluate(relativeFrame)),
      static_cast<double>(m_color.gammaG.evaluate(relativeFrame)),
      static_cast<double>(m_color.gammaB.evaluate(relativeFrame)), 0.0};
  map["gain"] = QVariantList{
      static_cast<double>(m_color.gainR.evaluate(relativeFrame)),
      static_cast<double>(m_color.gainG.evaluate(relativeFrame)),
      static_cast<double>(m_color.gainB.evaluate(relativeFrame)), 0.0};
  map["offset"] = QVariantList{
      static_cast<double>(m_color.offsetR.evaluate(relativeFrame)),
      static_cast<double>(m_color.offsetG.evaluate(relativeFrame)),
      static_cast<double>(m_color.offsetB.evaluate(relativeFrame)), 0.0};

  map["temperature"] = m_color.temperature.evaluate(relativeFrame);
  map["tint"] = m_color.tint.evaluate(relativeFrame);
  map["contrast"] = m_color.contrast.evaluate(relativeFrame);
  map["pivot"] = m_color.pivot.evaluate(relativeFrame);
  map["midDetail"] = m_color.midDetail.evaluate(relativeFrame);
  map["colorBoost"] = m_color.colorBoost.evaluate(relativeFrame);
  map["shadows"] = m_color.shadows.evaluate(relativeFrame);
  map["highlights"] = m_color.highlights.evaluate(relativeFrame);
  map["saturation"] = m_color.saturation.evaluate(relativeFrame);
  map["hue"] = m_color.hue.evaluate(relativeFrame);
  map["lumMix"] = m_color.lumMix.evaluate(relativeFrame);

  return map;
}

anim::AnimProperty *TimelineClip::findAnimProperty(const QString &key) {
  const anim::PropertyDescriptor *desc = anim::findPropertyDescriptor(key);
  if (!desc || !desc->accessor)
    return nullptr;
  return desc->accessor(*this);
}

const anim::AnimProperty *
TimelineClip::findAnimProperty(const QString &key) const {
  return const_cast<TimelineClip *>(this)->findAnimProperty(key);
}

std::vector<const anim::PropertyDescriptor *>
TimelineClip::animatableProperties() const {
  std::vector<const anim::PropertyDescriptor *> result;
  for (const auto &desc : anim::propertyRegistry())
    result.push_back(&desc);
  return result;
}

} // namespace xyla
