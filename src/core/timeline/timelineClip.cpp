#include "timelineClip.hpp"
#include "core/log/logger.hpp"
#include "core/render/nodeGraphManager.hpp"

#include <QJsonArray>
#include <algorithm>
#include <format>
#include <stdexcept>

namespace xyla {

TimelineClip::TimelineClip(TimelineClipCreateInfo info)
    : m_clipId(std::move(info.clipId)), m_assetId(std::move(info.assetId)),
      m_name(std::move(info.name)), m_timing(info.timing),
      m_nodeGraphIds{render::DEFAULT_IO_GRAPH_ID} {
  if (m_clipId.isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip",
                   "TimelineClip created with an empty clipId!");
  }
  if (m_timing.durationFrames < 1) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format("TimelineClip created with duration < 1. Value: {}",
                    m_timing.durationFrames));
    m_timing.durationFrames = 1;
  }
  if (m_timing.sourceInFrame < 0) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format(
            "TimelineClip created with negative sourceInFrame. Value: {}",
            m_timing.sourceInFrame));
    m_timing.sourceInFrame = 0;
  }
}

QJsonObject TimelineClip::serialize() const {
  QJsonObject obj;
  obj["clipId"] = m_clipId;
  obj["assetId"] = m_assetId;
  obj["name"] = m_name;
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;
  obj["blendMode"] = m_blendMode;
  obj["uniformScale"] = m_uniformScale;

  obj["timing"] = m_timing.serialize();

  QJsonObject xformObj;
  xformObj["posX"] = m_transform.posX.serialize();
  xformObj["posY"] = m_transform.posY.serialize();
  xformObj["scaleX"] = m_transform.scaleX.serialize();
  xformObj["scaleY"] = m_transform.scaleY.serialize();
  xformObj["rotation"] = m_transform.rotation.serialize();
  xformObj["opacity"] = m_transform.opacity.serialize();
  obj["transform"] = xformObj;

  QJsonObject colorObj;
  colorObj["liftR"] = m_color.liftR.serialize();
  colorObj["liftG"] = m_color.liftG.serialize();
  colorObj["liftB"] = m_color.liftB.serialize();
  colorObj["gammaR"] = m_color.gammaR.serialize();
  colorObj["gammaG"] = m_color.gammaG.serialize();
  colorObj["gammaB"] = m_color.gammaB.serialize();
  colorObj["gainR"] = m_color.gainR.serialize();
  colorObj["gainG"] = m_color.gainG.serialize();
  colorObj["gainB"] = m_color.gainB.serialize();
  colorObj["offsetR"] = m_color.offsetR.serialize();
  colorObj["offsetG"] = m_color.offsetG.serialize();
  colorObj["offsetB"] = m_color.offsetB.serialize();

  colorObj["temperature"] = m_color.temperature.serialize();
  colorObj["tint"] = m_color.tint.serialize();
  colorObj["contrast"] = m_color.contrast.serialize();
  colorObj["pivot"] = m_color.pivot.serialize();
  colorObj["midDetail"] = m_color.midDetail.serialize();
  colorObj["colorBoost"] = m_color.colorBoost.serialize();
  colorObj["shadows"] = m_color.shadows.serialize();
  colorObj["highlights"] = m_color.highlights.serialize();
  colorObj["saturation"] = m_color.saturation.serialize();
  colorObj["hue"] = m_color.hue.serialize();
  colorObj["lumMix"] = m_color.lumMix.serialize();
  colorObj["bypass"] = m_color.bypass;
  obj["color"] = colorObj;

  QJsonObject audioObj;
  audioObj["volume"] = m_audio.volume.serialize();
  audioObj["pan"] = m_audio.pan.serialize();
  audioObj["channelMode"] = m_audio.channelMode;
  obj["audio"] = audioObj;

  QJsonArray gArr;
  for (const auto &gId : m_nodeGraphIds) {
    gArr.append(gId);
  }
  obj["nodeGraphIds"] = gArr;
  obj["activeGraphIndex"] = static_cast<int>(m_activeGraphIndex);

  return obj;
}

TimelineClip TimelineClip::deserialize(const QJsonObject &obj) {
  TimelineClipCreateInfo info;
  info.clipId = obj.value("clipId").toString();
  info.assetId = obj.value("assetId").toString();
  info.name = obj.value("name").toString("Clip");

  if (obj.contains("timing") && obj["timing"].isObject()) {
    info.timing = ClipTiming::deserialize(obj["timing"].toObject());
  } else {
    info.timing = ClipTiming::deserialize(obj);
  }

  TimelineClip clip(info);
  clip.setIsMuted(obj.value("isMuted").toBool(false));
  clip.setIsLocked(obj.value("isLocked").toBool(false));
  clip.setBlendMode(obj.value("blendMode").toInt(0));
  clip.setIsUniformScale(obj.value("uniformScale").toBool(true));

  if (obj.contains("transform") && obj["transform"].isObject()) {
    QJsonObject xformObj = obj["transform"].toObject();
    clip.getTransform().posX.deserializeInto(xformObj["posX"].toObject(), 0.0f);
    clip.getTransform().posY.deserializeInto(xformObj["posY"].toObject(), 0.0f);
    clip.getTransform().scaleX.deserializeInto(xformObj["scaleX"].toObject(),
                                               1.0f);
    clip.getTransform().scaleY.deserializeInto(xformObj["scaleY"].toObject(),
                                               1.0f);
    clip.getTransform().rotation.deserializeInto(
        xformObj["rotation"].toObject(), 0.0f);
    clip.getTransform().opacity.deserializeInto(xformObj["opacity"].toObject(),
                                                1.0f);
  }

  if (obj.contains("color") && obj["color"].isObject()) {
    QJsonObject colorObj = obj["color"].toObject();
    clip.getColor().liftR.deserializeInto(colorObj["liftR"].toObject(), 0.0f);
    clip.getColor().liftG.deserializeInto(colorObj["liftG"].toObject(), 0.0f);
    clip.getColor().liftB.deserializeInto(colorObj["liftB"].toObject(), 0.0f);
    clip.getColor().gammaR.deserializeInto(colorObj["gammaR"].toObject(), 1.0f);
    clip.getColor().gammaG.deserializeInto(colorObj["gammaG"].toObject(), 1.0f);
    clip.getColor().gammaB.deserializeInto(colorObj["gammaB"].toObject(), 1.0f);
    clip.getColor().gainR.deserializeInto(colorObj["gainR"].toObject(), 1.0f);
    clip.getColor().gainG.deserializeInto(colorObj["gainG"].toObject(), 1.0f);
    clip.getColor().gainB.deserializeInto(colorObj["gainB"].toObject(), 1.0f);
    clip.getColor().offsetR.deserializeInto(colorObj["offsetR"].toObject(),
                                            0.0f);
    clip.getColor().offsetG.deserializeInto(colorObj["offsetG"].toObject(),
                                            0.0f);
    clip.getColor().offsetB.deserializeInto(colorObj["offsetB"].toObject(),
                                            0.0f);

    clip.getColor().temperature.deserializeInto(
        colorObj["temperature"].toObject(), 0.0f);
    clip.getColor().tint.deserializeInto(colorObj["tint"].toObject(), 0.0f);
    clip.getColor().contrast.deserializeInto(colorObj["contrast"].toObject(),
                                             1.0f);
    clip.getColor().pivot.deserializeInto(colorObj["pivot"].toObject(), 0.435f);
    clip.getColor().midDetail.deserializeInto(colorObj["midDetail"].toObject(),
                                              0.0f);
    clip.getColor().colorBoost.deserializeInto(
        colorObj["colorBoost"].toObject(), 0.0f);
    clip.getColor().shadows.deserializeInto(colorObj["shadows"].toObject(),
                                            0.0f);
    clip.getColor().highlights.deserializeInto(
        colorObj["highlights"].toObject(), 0.0f);
    clip.getColor().saturation.deserializeInto(
        colorObj["saturation"].toObject(), 50.0f);
    clip.getColor().hue.deserializeInto(colorObj["hue"].toObject(), 50.0f);
    clip.getColor().lumMix.deserializeInto(colorObj["lumMix"].toObject(),
                                           100.0f);
    clip.getColor().bypass = colorObj.value("bypass").toBool(false);
  }

  if (obj.contains("audio") && obj["audio"].isObject()) {
    QJsonObject audioObj = obj["audio"].toObject();
    clip.getAudio().volume.deserializeInto(audioObj["volume"].toObject(), 1.0f);
    clip.getAudio().pan.deserializeInto(audioObj["pan"].toObject(), 0.0f);
    clip.getAudio().channelMode = audioObj.value("channelMode").toInt(0);
  }
  if (obj.contains("nodeGraphIds")) {
    clip.m_nodeGraphIds.clear();
    QJsonArray arr = obj["nodeGraphIds"].toArray();
    for (const auto &val : arr) {
      clip.m_nodeGraphIds.push_back(val.toString());
    }
    if (clip.m_nodeGraphIds.empty()) {
      clip.m_nodeGraphIds.push_back(render::DEFAULT_IO_GRAPH_ID);
    }
    size_t activeIdx = static_cast<size_t>(
        std::max(0, obj.value("activeGraphIndex").toInt(0)));
    clip.setActiveGraphIndex(activeIdx);
  }

  return clip;
}

QVariantMap TimelineClip::toVariantMap() const {
  QVariantMap map;
  map["clipId"] = m_clipId;
  map["assetId"] = m_assetId;
  map["name"] = m_name;
  map["isMuted"] = m_isMuted;
  map["isLocked"] = m_isLocked;
  map["blendMode"] = m_blendMode;
  map["uniformScale"] = m_uniformScale;

  map["startFrame"] = static_cast<double>(m_timing.startFrame);
  map["durationFrames"] = static_cast<double>(m_timing.durationFrames);
  map["sourceInFrame"] = static_cast<double>(m_timing.sourceInFrame);
  map["trackIndex"] = m_timing.trackIndex;
  map["speed"] = m_timing.speed;

  QVariantMap xform;
  xform["positionX"] = static_cast<double>(m_transform.posX.getStaticValue());
  xform["positionY"] = static_cast<double>(m_transform.posY.getStaticValue());
  xform["scaleX"] = static_cast<double>(m_transform.scaleX.getStaticValue());
  xform["scaleY"] = static_cast<double>(m_transform.scaleY.getStaticValue());
  xform["rotation"] =
      static_cast<double>(m_transform.rotation.getStaticValue());
  xform["opacity"] = static_cast<double>(m_transform.opacity.getStaticValue());
  map["transform"] = xform;

  QVariantMap col;
  col["lift"] =
      QVariantList{static_cast<double>(m_color.liftR.getStaticValue()),
                   static_cast<double>(m_color.liftG.getStaticValue()),
                   static_cast<double>(m_color.liftB.getStaticValue()), 0.0};
  col["gamma"] =
      QVariantList{static_cast<double>(m_color.gammaR.getStaticValue()),
                   static_cast<double>(m_color.gammaG.getStaticValue()),
                   static_cast<double>(m_color.gammaB.getStaticValue()), 0.0};
  col["gain"] =
      QVariantList{static_cast<double>(m_color.gainR.getStaticValue()),
                   static_cast<double>(m_color.gainG.getStaticValue()),
                   static_cast<double>(m_color.gainB.getStaticValue()), 0.0};
  col["offset"] =
      QVariantList{static_cast<double>(m_color.offsetR.getStaticValue()),
                   static_cast<double>(m_color.offsetG.getStaticValue()),
                   static_cast<double>(m_color.offsetB.getStaticValue()), 0.0};

  col["temperature"] = m_color.temperature.getStaticValue();
  col["tint"] = m_color.tint.getStaticValue();
  col["contrast"] = m_color.contrast.getStaticValue();
  col["pivot"] = m_color.pivot.getStaticValue();
  col["midDetail"] = m_color.midDetail.getStaticValue();
  col["colorBoost"] = m_color.colorBoost.getStaticValue();
  col["shadows"] = m_color.shadows.getStaticValue();
  col["highlights"] = m_color.highlights.getStaticValue();
  col["saturation"] = m_color.saturation.getStaticValue();
  col["hue"] = m_color.hue.getStaticValue();
  col["lumMix"] = m_color.lumMix.getStaticValue();
  col["bypass"] = m_color.bypass;
  map["color"] = col;

  QVariantMap aud;
  aud["volume"] = m_audio.volume.getStaticValue();
  aud["pan"] = m_audio.pan.getStaticValue();
  aud["channelMode"] = m_audio.channelMode;
  map["audio"] = aud;

  map["nodes"] = getNodeGraphNodes();
  map["links"] = getNodeGraphLinks();

  return map;
}

const QString &TimelineClip::getClipId() const noexcept { return m_clipId; }

void TimelineClip::setClipId(QString clipId) {
  if (clipId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip", "setClipId called with empty string!");
    return;
  }
  m_clipId = std::move(clipId);
}

const QString &TimelineClip::getAssetId() const noexcept { return m_assetId; }

void TimelineClip::setAssetId(QString assetId) {
  if (assetId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip", "setAssetId called with empty string!");
    return;
  }
  m_assetId = std::move(assetId);
}

const QString &TimelineClip::getName() const noexcept { return m_name; }

void TimelineClip::setName(QString name) {
  if (name.trimmed().isEmpty()) {
    XYLA_LOG_WARN(
        "TimelineClip",
        "setName called with empty string. Defaulting to 'Untitled'.");
    m_name = "Untitled";
    return;
  }
  m_name = std::move(name);
}

const ClipTiming &TimelineClip::getTiming() const noexcept { return m_timing; }

void TimelineClip::setTiming(const ClipTiming &timing) {
  if (timing.durationFrames < 1) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format(
            "setTiming failed: durationFrames must be >= 1! Received: {}",
            timing.durationFrames));
    return;
  }
  if (timing.sourceInFrame < 0) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format(
            "setTiming failed: sourceInFrame must be >= 0! Received: {}",
            timing.sourceInFrame));
    return;
  }
  if (timing.speed <= 0.0) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format("setTiming failed: speed must be > 0.0! Received: {}",
                    timing.speed));
    return;
  }
  m_timing = timing;
}

TimelineClip TimelineClip::split(const QString &newRightClipId,
                                 FrameIndex cutFrame) {
  if (newRightClipId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip",
                   "split failed: newRightClipId cannot be empty!");
    throw std::invalid_argument("Empty newRightClipId in TimelineClip::split");
  }

  if (cutFrame <= m_timing.startFrame || cutFrame >= m_timing.endFrame()) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format("split failed: cutFrame {} is outside bounds [{}, {})",
                    cutFrame, m_timing.startFrame, m_timing.endFrame()));
    throw std::out_of_range("cutFrame out of range in TimelineClip::split");
  }

  FrameIndex leftDuration = cutFrame - m_timing.startFrame;
  FrameIndex rightDuration = m_timing.durationFrames - leftDuration;
  FrameIndex rightSourceIn = m_timing.sourceInFrame + leftDuration;

  TimelineClipCreateInfo rightInfo{.clipId = newRightClipId,
                                   .assetId = m_assetId,
                                   .name = m_name,
                                   .timing = {
                                       .startFrame = cutFrame,
                                       .durationFrames = rightDuration,
                                       .sourceInFrame = rightSourceIn,
                                       .trackIndex = m_timing.trackIndex,
                                       .speed = m_timing.speed,
                                   }};

  TimelineClip rightClip(rightInfo);
  rightClip.setIsMuted(m_isMuted);
  rightClip.setBlendMode(m_blendMode);
  rightClip.setIsUniformScale(m_uniformScale);

  rightClip.getTransform() = m_transform;
  rightClip.getColor() = m_color;
  rightClip.getAudio() = m_audio;
  rightClip.copyGraphReferencesFrom(*this);

  m_timing.durationFrames = leftDuration;

  return rightClip;
}

bool TimelineClip::canUncutWith(const TimelineClip &rightClip) const noexcept {
  if (m_assetId != rightClip.m_assetId) {
    return false;
  }

  if (m_timing.endFrame() != rightClip.getTiming().startFrame) {
    return false;
  }

  if (m_timing.sourceOutFrame() != rightClip.getTiming().sourceInFrame) {
    return false;
  }

  if (m_timing.speed != rightClip.getTiming().speed) {
    return false;
  }

  return true;
}

bool TimelineClip::uncut(const TimelineClip &rightClip) {
  if (!canUncutWith(rightClip)) {
    XYLA_LOG_WARN(
        "TimelineClip",
        std::format("uncut rejected: clips '{}' and '{}' are not contiguous.",
                    m_clipId.toStdString(),
                    rightClip.getClipId().toStdString()));
    return false;
  }

  m_timing.durationFrames += rightClip.getTiming().durationFrames;
  return true;
}

bool TimelineClip::getIsLocked() const noexcept { return m_isLocked; }
void TimelineClip::setIsLocked(bool locked) noexcept { m_isLocked = locked; }

bool TimelineClip::getIsMuted() const noexcept { return m_isMuted; }
void TimelineClip::setIsMuted(bool muted) noexcept { m_isMuted = muted; }

int TimelineClip::getBlendMode() const noexcept { return m_blendMode; }
void TimelineClip::setBlendMode(int mode) {
  if (mode < 0) {
    XYLA_LOG_ERROR("TimelineClip",
                   std::format("setBlendMode failed: mode cannot be negative! "
                               "Received: {}",
                               mode));
    return;
  }
  m_blendMode = mode;
}

bool TimelineClip::getIsUniformScale() const noexcept { return m_uniformScale; }
void TimelineClip::setIsUniformScale(bool uniform) noexcept {
  m_uniformScale = uniform;
}

ClipTransformData &TimelineClip::getTransform() noexcept { return m_transform; }
const ClipTransformData &TimelineClip::getTransform() const noexcept {
  return m_transform;
}

ClipColorData &TimelineClip::getColor() noexcept { return m_color; }
const ClipColorData &TimelineClip::getColor() const noexcept { return m_color; }

ClipAudioData &TimelineClip::getAudio() noexcept { return m_audio; }
const ClipAudioData &TimelineClip::getAudio() const noexcept { return m_audio; }

const std::vector<QString> &TimelineClip::getNodeGraphIds() const noexcept {
  return m_nodeGraphIds;
}

size_t TimelineClip::getActiveGraphIndex() const noexcept {
  return m_activeGraphIndex;
}

void TimelineClip::setActiveGraphIndex(size_t index) {
  if (index >= m_nodeGraphIds.size()) {
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format("setActiveGraphIndex out of range! Index: {}, Size: {}",
                    index, m_nodeGraphIds.size()));
    return;
  }
  m_activeGraphIndex = index;
}

QString TimelineClip::getActiveGraphId() const {
  if (m_activeGraphIndex < m_nodeGraphIds.size()) {
    return m_nodeGraphIds[m_activeGraphIndex];
  }
  XYLA_LOG_ERROR(
      "TimelineClip",
      std::format("m_activeGraphIndex {} was out of bounds! Returning default.",
                  m_activeGraphIndex));
  return render::DEFAULT_IO_GRAPH_ID;
}

void TimelineClip::setActiveGraphId(const QString &graphId) {
  for (size_t i = 0; i < m_nodeGraphIds.size(); ++i) {
    if (m_nodeGraphIds[i] == graphId) {
      m_activeGraphIndex = i;
      return;
    }
  }
  XYLA_LOG_ERROR(
      "TimelineClip",
      std::format("setActiveGraphId failed: graphId '{}' is not attached!",
                  graphId.toStdString()));
}

std::shared_ptr<render::NodeGraph> TimelineClip::getNodeGraph() const {
  return render::NodeGraphManager::instance().getGraph(getActiveGraphId());
}

void TimelineClip::setNodeGraph(std::shared_ptr<render::NodeGraph> graph) {
  if (!graph) {
    XYLA_LOG_ERROR("TimelineClip", "setNodeGraph called with null graph!");
    return;
  }
  attachNodeGraphId(graph->id());
  setActiveGraphId(graph->id());
}

void TimelineClip::attachNodeGraphId(const QString &graphId) {
  if (graphId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip",
                   "attachNodeGraphId called with empty graphId!");
    return;
  }
  for (const auto &id : m_nodeGraphIds) {
    if (id == graphId) {
      return;
    }
  }
  m_nodeGraphIds.push_back(graphId);
}

bool TimelineClip::detachNodeGraphId(const QString &graphId) {
  if (graphId == render::DEFAULT_IO_GRAPH_ID) {
    XYLA_LOG_WARN("TimelineClip",
                  "Cannot detach the default immutable I/O graph!");
    return false;
  }

  auto it =
      std::find(m_nodeGraphIds.begin() + 1, m_nodeGraphIds.end(), graphId);
  if (it != m_nodeGraphIds.end()) {
    m_nodeGraphIds.erase(it);
    if (m_activeGraphIndex >= m_nodeGraphIds.size()) {
      m_activeGraphIndex = m_nodeGraphIds.size() - 1;
    }
    return true;
  }

  XYLA_LOG_WARN(
      "TimelineClip",
      std::format("detachNodeGraphId failed: graphId '{}' was not attached.",
                  graphId.toStdString()));
  return false;
}

void TimelineClip::setAttachedNodeGraphIds(const QStringList &ids) {
  m_nodeGraphIds.clear();
  m_nodeGraphIds.push_back(render::DEFAULT_IO_GRAPH_ID);

  for (const auto &id : ids) {
    if (id != render::DEFAULT_IO_GRAPH_ID && !id.trimmed().isEmpty()) {
      m_nodeGraphIds.push_back(id);
    }
  }
  m_activeGraphIndex = 0;
}

void TimelineClip::copyGraphReferencesFrom(const TimelineClip &other) noexcept {
  m_nodeGraphIds = other.m_nodeGraphIds;
  m_activeGraphIndex = other.m_activeGraphIndex;
}

QVariantList TimelineClip::getNodeGraphNodes() const {
  auto g = getNodeGraph();
  return g ? g->toVariantList() : QVariantList();
}

QVariantList TimelineClip::getNodeGraphLinks() const {
  auto g = getNodeGraph();
  return g ? g->linksToVariantList() : QVariantList();
}

anim::AnimProperty *TimelineClip::findAnimProperty(const QString &key) {
  if (key == "scale") {
    return &m_transform.scaleX;
  }
  const anim::PropertyDescriptor *desc = anim::findPropertyDescriptor(key);
  if (!desc || !desc->accessor) {
    return nullptr;
  }
  return desc->accessor(*this);
}

const anim::AnimProperty *
TimelineClip::findAnimProperty(const QString &key) const {
  return const_cast<TimelineClip *>(this)->findAnimProperty(key);
}

std::vector<const anim::PropertyDescriptor *>
TimelineClip::getAnimatableProperties() const {
  std::vector<const anim::PropertyDescriptor *> result;
  for (const auto &desc : anim::propertyRegistry()) {
    result.push_back(&desc);
  }
  return result;
}

QVariantMap
TimelineClip::getPushConstantValues(FrameIndex relativeFrame) const {
  ClipPushConstants pc;
  fillPushConstants(pc, relativeFrame);

  QVariantMap map;
  map["position"] =
      QVariantList{static_cast<double>(pc.posX), static_cast<double>(pc.posY)};
  map["scale"] = QVariantList{static_cast<double>(pc.scaleX),
                              static_cast<double>(pc.scaleY)};
  map["anchor"] = QVariantList{static_cast<double>(pc.anchorX),
                               static_cast<double>(pc.anchorY)};
  map["rotation"] = static_cast<double>(pc.rotation);
  map["opacity"] = static_cast<double>(pc.opacity);
  map["blendMode"] = pc.blendMode;

  map["lift"] = QVariantList{static_cast<double>(pc.lift[0]),
                             static_cast<double>(pc.lift[1]),
                             static_cast<double>(pc.lift[2]), 0.0};
  map["gamma"] = QVariantList{static_cast<double>(pc.gamma[0]),
                              static_cast<double>(pc.gamma[1]),
                              static_cast<double>(pc.gamma[2]), 0.0};
  map["gain"] = QVariantList{static_cast<double>(pc.gain[0]),
                             static_cast<double>(pc.gain[1]),
                             static_cast<double>(pc.gain[2]), 0.0};
  map["offset"] = QVariantList{static_cast<double>(pc.offset[0]),
                               static_cast<double>(pc.offset[1]),
                               static_cast<double>(pc.offset[2]), 0.0};

  map["temperature"] = static_cast<double>(pc.temperature);
  map["tint"] = static_cast<double>(pc.tint);
  map["contrast"] = static_cast<double>(pc.contrast);
  map["pivot"] = static_cast<double>(pc.pivot);
  map["midDetail"] = static_cast<double>(pc.midDetail);
  map["colorBoost"] = static_cast<double>(pc.colorBoost);
  map["shadows"] = static_cast<double>(pc.shadows);
  map["highlights"] = static_cast<double>(pc.highlights);
  map["saturation"] = static_cast<double>(pc.saturation);
  map["hue"] = static_cast<double>(pc.hue);
  map["lumMix"] = static_cast<double>(pc.lumMix);

  return map;
}

void TimelineClip::fillPushConstants(ClipPushConstants &out,
                                     FrameIndex relativeFrame) const noexcept {
  out.posX = m_transform.posX.evaluate(relativeFrame);
  out.posY = m_transform.posY.evaluate(relativeFrame);

  float sx = m_transform.scaleX.evaluate(relativeFrame);
  float sy = m_uniformScale ? sx : m_transform.scaleY.evaluate(relativeFrame);
  out.scaleX = sx;
  out.scaleY = sy;

  out.anchorX = 0.0f;
  out.anchorY = 0.0f;
  out.rotation = m_transform.rotation.evaluate(relativeFrame);
  out.opacity = m_transform.opacity.evaluate(relativeFrame);
  out.blendMode = m_blendMode;

  out.lift[0] = m_color.liftR.evaluate(relativeFrame);
  out.lift[1] = m_color.liftG.evaluate(relativeFrame);
  out.lift[2] = m_color.liftB.evaluate(relativeFrame);
  out.lift[3] = 0.0f;

  out.gamma[0] = m_color.gammaR.evaluate(relativeFrame);
  out.gamma[1] = m_color.gammaG.evaluate(relativeFrame);
  out.gamma[2] = m_color.gammaB.evaluate(relativeFrame);
  out.gamma[3] = 0.0f;

  out.gain[0] = m_color.gainR.evaluate(relativeFrame);
  out.gain[1] = m_color.gainG.evaluate(relativeFrame);
  out.gain[2] = m_color.gainB.evaluate(relativeFrame);
  out.gain[3] = 0.0f;

  out.offset[0] = m_color.offsetR.evaluate(relativeFrame);
  out.offset[1] = m_color.offsetG.evaluate(relativeFrame);
  out.offset[2] = m_color.offsetB.evaluate(relativeFrame);
  out.offset[3] = 0.0f;

  out.temperature = m_color.temperature.evaluate(relativeFrame);
  out.tint = m_color.tint.evaluate(relativeFrame);
  out.contrast = m_color.contrast.evaluate(relativeFrame);
  out.pivot = m_color.pivot.evaluate(relativeFrame);
  out.midDetail = m_color.midDetail.evaluate(relativeFrame);
  out.colorBoost = m_color.colorBoost.evaluate(relativeFrame);
  out.shadows = m_color.shadows.evaluate(relativeFrame);
  out.highlights = m_color.highlights.evaluate(relativeFrame);
  out.saturation = m_color.saturation.evaluate(relativeFrame);
  out.hue = m_color.hue.evaluate(relativeFrame);
  out.lumMix = m_color.lumMix.evaluate(relativeFrame);
  out.bypassColor = m_color.bypass ? 1.0f : 0.0f;
}

} // namespace xyla
