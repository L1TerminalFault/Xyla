#include "timelineClip.hpp"
#include <QJsonArray>
#include <QJsonObject>
#include <array>

namespace xyla {

namespace {

QJsonObject serializeFloatProp(const anim::AnimatableProperty<float> &prop) {
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

void deserializeFloatProp(const QJsonObject &obj,
                          anim::AnimatableProperty<float> &prop,
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
          static_cast<anim::InterpolationType>(kfObj.value("interp").toInt(1));
      prop.setKeyframe(frame, kfVal, interp);
    }
  }
}

QJsonObject
serializeVec2Prop(const anim::AnimatableProperty<std::array<float, 2>> &prop) {
  QJsonObject obj;
  QJsonArray valArr;
  valArr.append(static_cast<double>(prop.staticValue()[0]));
  valArr.append(static_cast<double>(prop.staticValue()[1]));
  obj["value"] = valArr;
  obj["isAnimated"] = prop.isAnimated();

  if (prop.isAnimated()) {
    QJsonArray kfArray;
    for (const auto &kf : prop.keyframes()) {
      QJsonObject kfObj;
      kfObj["frame"] = static_cast<qint64>(kf.frame);
      QJsonArray arr;
      arr.append(static_cast<double>(kf.value[0]));
      arr.append(static_cast<double>(kf.value[1]));
      kfObj["value"] = arr;
      kfObj["interp"] = static_cast<int>(kf.interpolation);
      kfArray.append(kfObj);
    }
    obj["keyframes"] = kfArray;
  }
  return obj;
}

void deserializeVec2Prop(const QJsonObject &obj,
                         anim::AnimatableProperty<std::array<float, 2>> &prop,
                         std::array<float, 2> defaultVal) {
  QJsonArray valArr = obj.value("value").toArray();
  if (valArr.size() >= 2) {
    prop.setStaticValue({static_cast<float>(valArr[0].toDouble()),
                         static_cast<float>(valArr[1].toDouble())});
  } else {
    prop.setStaticValue(defaultVal);
  }

  if (obj.value("isAnimated").toBool(false)) {
    QJsonArray kfArray = obj.value("keyframes").toArray();
    for (const auto &item : kfArray) {
      QJsonObject kfObj = item.toObject();
      auto frame =
          static_cast<anim::FrameIndex>(kfObj.value("frame").toInteger());
      QJsonArray arr = kfObj.value("value").toArray();
      if (arr.size() >= 2) {
        std::array<float, 2> kfVal = {static_cast<float>(arr[0].toDouble()),
                                      static_cast<float>(arr[1].toDouble())};
        auto interp = static_cast<anim::InterpolationType>(
            kfObj.value("interp").toInt(1));
        prop.setKeyframe(frame, kfVal, interp);
      }
    }
  }
}

QJsonObject
serializeVec4Prop(const anim::AnimatableProperty<std::array<float, 4>> &prop) {
  QJsonObject obj;
  QJsonArray valArr;
  for (int i = 0; i < 4; ++i) {
    valArr.append(static_cast<double>(prop.staticValue()[i]));
  }
  obj["value"] = valArr;
  obj["isAnimated"] = prop.isAnimated();

  if (prop.isAnimated()) {
    QJsonArray kfArray;
    for (const auto &kf : prop.keyframes()) {
      QJsonObject kfObj;
      kfObj["frame"] = static_cast<qint64>(kf.frame);
      QJsonArray arr;
      for (int i = 0; i < 4; ++i) {
        arr.append(static_cast<double>(kf.value[i]));
      }
      kfObj["value"] = arr;
      kfObj["interp"] = static_cast<int>(kf.interpolation);
      kfArray.append(kfObj);
    }
    obj["keyframes"] = kfArray;
  }
  return obj;
}

void deserializeVec4Prop(const QJsonObject &obj,
                         anim::AnimatableProperty<std::array<float, 4>> &prop,
                         std::array<float, 4> defaultVal) {
  QJsonArray valArr = obj.value("value").toArray();
  if (valArr.size() >= 4) {
    prop.setStaticValue({static_cast<float>(valArr[0].toDouble()),
                         static_cast<float>(valArr[1].toDouble()),
                         static_cast<float>(valArr[2].toDouble()),
                         static_cast<float>(valArr[3].toDouble())});
  } else {
    prop.setStaticValue(defaultVal);
  }

  if (obj.value("isAnimated").toBool(false)) {
    QJsonArray kfArray = obj.value("keyframes").toArray();
    for (const auto &item : kfArray) {
      QJsonObject kfObj = item.toObject();
      auto frame =
          static_cast<anim::FrameIndex>(kfObj.value("frame").toInteger());
      QJsonArray arr = kfObj.value("value").toArray();
      if (arr.size() >= 4) {
        std::array<float, 4> kfVal = {static_cast<float>(arr[0].toDouble()),
                                      static_cast<float>(arr[1].toDouble()),
                                      static_cast<float>(arr[2].toDouble()),
                                      static_cast<float>(arr[3].toDouble())};
        auto interp = static_cast<anim::InterpolationType>(
            kfObj.value("interp").toInt(1));
        prop.setKeyframe(frame, kfVal, interp);
      }
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
  xformObj["position"] = serializeVec2Prop(m_transform.position);
  xformObj["scale"] = serializeVec2Prop(m_transform.scale);
  xformObj["anchorPoint"] = serializeVec2Prop(m_transform.anchorPoint);
  xformObj["rotation"] = serializeFloatProp(m_transform.rotation);
  xformObj["opacity"] = serializeFloatProp(m_transform.opacity);
  obj["transform"] = xformObj;

  QJsonObject colorObj;
  colorObj["lift"] = serializeVec4Prop(m_color.lift);
  colorObj["gamma"] = serializeVec4Prop(m_color.gamma);
  colorObj["gain"] = serializeVec4Prop(m_color.gain);
  colorObj["offset"] = serializeVec4Prop(m_color.offset);

  colorObj["temperature"] = serializeFloatProp(m_color.temperature);
  colorObj["tint"] = serializeFloatProp(m_color.tint);
  colorObj["contrast"] = serializeFloatProp(m_color.contrast);
  colorObj["pivot"] = serializeFloatProp(m_color.pivot);
  colorObj["midDetail"] = serializeFloatProp(m_color.midDetail);

  colorObj["colorBoost"] = serializeFloatProp(m_color.colorBoost);
  colorObj["shadows"] = serializeFloatProp(m_color.shadows);
  colorObj["highlights"] = serializeFloatProp(m_color.highlights);
  colorObj["saturation"] = serializeFloatProp(m_color.saturation);
  colorObj["hue"] = serializeFloatProp(m_color.hue);
  colorObj["lumMix"] = serializeFloatProp(m_color.lumMix);
  colorObj["bypass"] = m_color.bypass;
  obj["color"] = colorObj;

  QJsonObject audioObj;
  audioObj["volume"] = serializeFloatProp(m_audio.volume);
  audioObj["pan"] = serializeFloatProp(m_audio.pan);
  audioObj["channelMode"] = m_audio.channelMode;
  obj["audio"] = audioObj;

  // Backward compatibility keys
  obj["positionX"] = static_cast<double>(m_transform.position.staticValue()[0]);
  obj["positionY"] = static_cast<double>(m_transform.position.staticValue()[1]);
  obj["scaleX"] = static_cast<double>(m_transform.scale.staticValue()[0]);
  obj["scaleY"] = static_cast<double>(m_transform.scale.staticValue()[1]);
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

  // 1. Deserialize Transform
  if (obj.contains("transform") && obj["transform"].isObject()) {
    QJsonObject xformObj = obj["transform"].toObject();
    deserializeVec2Prop(xformObj["position"].toObject(),
                        clip.transform().position, {0.0f, 0.0f});
    deserializeVec2Prop(xformObj["scale"].toObject(), clip.transform().scale,
                        {1.0f, 1.0f});
    deserializeVec2Prop(xformObj["anchorPoint"].toObject(),
                        clip.transform().anchorPoint, {0.0f, 0.0f});
    deserializeFloatProp(xformObj["rotation"].toObject(),
                         clip.transform().rotation, 0.0f);
    deserializeFloatProp(xformObj["opacity"].toObject(),
                         clip.transform().opacity, 1.0f);
  } else {
    // Legacy fallback
    clip.setTransform(
        obj.value("positionX").toDouble(0.0),
        obj.value("positionY").toDouble(0.0), obj.value("scaleX").toDouble(1.0),
        obj.value("scaleY").toDouble(1.0), obj.value("opacity").toDouble(1.0));
  }

  // 2. Deserialize Color
  if (obj.contains("color") && obj["color"].isObject()) {
    QJsonObject colorObj = obj["color"].toObject();
    deserializeVec4Prop(colorObj["lift"].toObject(), clip.color().lift,
                        {0.0f, 0.0f, 0.0f, 0.0f});
    deserializeVec4Prop(colorObj["gamma"].toObject(), clip.color().gamma,
                        {1.0f, 1.0f, 1.0f, 0.0f});
    deserializeVec4Prop(colorObj["gain"].toObject(), clip.color().gain,
                        {1.0f, 1.0f, 1.0f, 0.0f});
    deserializeVec4Prop(colorObj["offset"].toObject(), clip.color().offset,
                        {0.0f, 0.0f, 0.0f, 0.0f});

    deserializeFloatProp(colorObj["temperature"].toObject(),
                         clip.color().temperature, 0.0f);
    deserializeFloatProp(colorObj["tint"].toObject(), clip.color().tint, 0.0f);
    deserializeFloatProp(colorObj["contrast"].toObject(), clip.color().contrast,
                         1.0f);
    deserializeFloatProp(colorObj["pivot"].toObject(), clip.color().pivot,
                         0.435f);
    deserializeFloatProp(colorObj["midDetail"].toObject(),
                         clip.color().midDetail, 0.0f);

    deserializeFloatProp(colorObj["colorBoost"].toObject(),
                         clip.color().colorBoost, 0.0f);
    deserializeFloatProp(colorObj["shadows"].toObject(), clip.color().shadows,
                         0.0f);
    deserializeFloatProp(colorObj["highlights"].toObject(),
                         clip.color().highlights, 0.0f);
    deserializeFloatProp(colorObj["saturation"].toObject(),
                         clip.color().saturation, 50.0f);
    deserializeFloatProp(colorObj["hue"].toObject(), clip.color().hue, 50.0f);
    deserializeFloatProp(colorObj["lumMix"].toObject(), clip.color().lumMix,
                         100.0f);

    clip.color().bypass = colorObj.value("bypass").toBool(false);
  }

  // 3. Deserialize Audio
  if (obj.contains("audio") && obj["audio"].isObject()) {
    QJsonObject audioObj = obj["audio"].toObject();
    deserializeFloatProp(audioObj["volume"].toObject(), clip.audio().volume,
                         1.0f);
    deserializeFloatProp(audioObj["pan"].toObject(), clip.audio().pan, 0.0f);
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

  // 1. Intrinsic Transform Map for QML
  QVariantMap xform;
  xform["positionX"] =
      static_cast<double>(m_transform.position.staticValue()[0]);
  xform["positionY"] =
      static_cast<double>(m_transform.position.staticValue()[1]);
  xform["scaleX"] = static_cast<double>(m_transform.scale.staticValue()[0]);
  xform["scaleY"] = static_cast<double>(m_transform.scale.staticValue()[1]);
  xform["rotation"] = static_cast<double>(m_transform.rotation.staticValue());
  xform["opacity"] = static_cast<double>(m_transform.opacity.staticValue());
  map["transform"] = xform;

  // 2. Intrinsic Color Map for QML Color Wheels
  QVariantMap col;
  auto l = m_color.lift.staticValue();
  auto gm = m_color.gamma.staticValue();
  auto gn = m_color.gain.staticValue();
  auto o = m_color.offset.staticValue();

  col["lift"] = QVariantList{l[0], l[1], l[2], l[3]};
  col["gamma"] = QVariantList{gm[0], gm[1], gm[2], gm[3]};
  col["gain"] = QVariantList{gn[0], gn[1], gn[2], gn[3]};
  col["offset"] = QVariantList{o[0], o[1], o[2], o[3]};

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

  // 3. Intrinsic Audio Map for QML
  QVariantMap aud;
  aud["volume"] = m_audio.volume.staticValue();
  aud["pan"] = m_audio.pan.staticValue();
  aud["channelMode"] = m_audio.channelMode;
  map["audio"] = aud;

  // Legacy flat fields
  map["positionX"] = static_cast<double>(m_transform.position.staticValue()[0]);
  map["positionY"] = static_cast<double>(m_transform.position.staticValue()[1]);
  map["scaleX"] = static_cast<double>(m_transform.scale.staticValue()[0]);
  map["scaleY"] = static_cast<double>(m_transform.scale.staticValue()[1]);
  map["opacity"] = static_cast<double>(m_transform.opacity.staticValue());

  map["nodes"] = nodeGraphNodes();
  map["links"] = nodeGraphLinks();

  return map;
}

} // namespace xyla
