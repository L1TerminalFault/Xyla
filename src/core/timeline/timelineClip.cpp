#include "timelineClip.hpp"
#include "core/log/logger.hpp"
#include "core/render/nodeGraphManager.hpp"
#include "core/render/nodes/outputNode.hpp"
#include "core/render/nodes/videoInNode.hpp"
#include "core/timeline/component/audioComponent.hpp"
#include "core/timeline/component/clipComponent.hpp"
#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "core/timeline/component/transformComponent.hpp"

#include <QJsonArray>
#include <QUuid>
#include <algorithm>
#include <format>
#include <stdexcept>

namespace xyla {

TimelineClip::TimelineClip(TimelineClipCreateInfo info)
    : m_clipId(std::move(info.clipId)), m_assetId(std::move(info.assetId)),
      m_name(std::move(info.name)), m_timing(info.timing),
      m_nodeGraphIds{render::DEFAULT_IO_GRAPH_ID}, m_activeGraphIndex(0) {

  if (m_clipId.isEmpty()) {
    XYLA_LOG_ERROR("TimelineClip",
                   "TimelineClip created with an empty clipId!");
  }
  if (m_timing.durationFrames < 1) {
    m_timing.durationFrames = 1;
  }
  if (m_timing.sourceInFrame < 0) {
    m_timing.sourceInFrame = 0;
  }
}

TimelineClip::TimelineClip(const TimelineClip &other)
    : m_clipId(other.m_clipId), m_assetId(other.m_assetId),
      m_name(other.m_name), m_timing(other.m_timing),
      m_isLocked(other.m_isLocked), m_isMuted(other.m_isMuted),
      m_uniformScale(other.m_uniformScale), m_blendMode(other.m_blendMode),
      m_transform(other.m_transform), m_color(other.m_color),
      m_audio(other.m_audio), m_nodeGraphIds(other.m_nodeGraphIds),
      m_activeGraphIndex(other.m_activeGraphIndex) {
  m_components.reserve(other.m_components.size());
  for (const auto &comp : other.m_components) {
    if (comp) {
      m_components.push_back(comp->clone());
    }
  }
}

TimelineClip &TimelineClip::operator=(const TimelineClip &other) {
  if (this == &other) {
    return *this;
  }
  m_clipId = other.m_clipId;
  m_assetId = other.m_assetId;
  m_name = other.m_name;
  m_timing = other.m_timing;
  m_isLocked = other.m_isLocked;
  m_isMuted = other.m_isMuted;
  m_uniformScale = other.m_uniformScale;
  m_blendMode = other.m_blendMode;
  m_transform = other.m_transform;
  m_color = other.m_color;
  m_audio = other.m_audio;
  m_nodeGraphIds = other.m_nodeGraphIds;
  m_activeGraphIndex = other.m_activeGraphIndex;

  m_components.clear();
  m_components.reserve(other.m_components.size());
  for (const auto &comp : other.m_components) {
    if (comp) {
      m_components.push_back(comp->clone());
    }
  }
  return *this;
}

TimelineClip TimelineClip::createTitleClip(TimelineClipCreateInfo info,
                                           const QString &initialText) {
  TimelineClip clip(info);

  clip.addComponent(std::make_unique<TransformComponent>());

  auto textComp = std::make_unique<TextComponent>();
  textComp->text = initialText;
  clip.addComponent(std::move(textComp));

  auto graph = render::NodeGraphManager::instance().createGraph(
      QStringLiteral("Title Graph"));
  const QString prefix =
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

  auto srcNode = std::make_shared<render::VideoInNode>(
      QStringLiteral("%1_src").arg(prefix), QStringLiteral("Title In"),
      info.assetId);
  srcNode->setPosition(-150.0, 0.0);

  auto outNode = std::make_shared<render::OutputNode>(
      QStringLiteral("%1_out").arg(prefix), QStringLiteral("Video Out"));
  outNode->setPosition(150.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(outNode);
  graph->connectSockets(srcNode->id(), QStringLiteral("video_out"),
                        outNode->id(), QStringLiteral("video_in"));

  clip.setNodeGraph(graph);
  return clip;
}

TimelineClip TimelineClip::createSvgClip(TimelineClipCreateInfo info,
                                         const QString &svgPath) {
  TimelineClip clip(info);

  clip.addComponent(std::make_unique<TransformComponent>());

  auto svgComp = std::make_unique<SvgComponent>();
  svgComp->setSourcePath(svgPath);
  clip.addComponent(std::move(svgComp));

  auto graph = render::NodeGraphManager::instance().createGraph(
      QStringLiteral("SVG Graph"));
  const QString prefix =
      QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

  auto srcNode = std::make_shared<render::VideoInNode>(
      QStringLiteral("%1_src").arg(prefix), QStringLiteral("SVG In"),
      info.assetId);
  srcNode->setPosition(-150.0, 0.0);

  auto outNode = std::make_shared<render::OutputNode>(
      QStringLiteral("%1_out").arg(prefix), QStringLiteral("Video Out"));
  outNode->setPosition(150.0, 0.0);

  graph->addNode(srcNode);
  graph->addNode(outNode);
  graph->connectSockets(srcNode->id(), QStringLiteral("video_out"),
                        outNode->id(), QStringLiteral("video_in"));

  clip.setNodeGraph(graph);
  return clip;
}

void TimelineClip::bindAnimationManager(anim::AnimationManager &animMgr) {
  for (auto &comp : m_components) {
    if (comp) {
      comp->bindAnimationManager(m_clipId, animMgr);
    }
  }

  if (auto graph = getNodeGraph()) {
    graph->bindAnimationManager(animMgr);
  }
}

QJsonObject TimelineClip::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("clipId")] = m_clipId;
  obj[QStringLiteral("assetId")] = m_assetId;
  obj[QStringLiteral("name")] = m_name;
  obj[QStringLiteral("isMuted")] = m_isMuted;
  obj[QStringLiteral("isLocked")] = m_isLocked;
  obj[QStringLiteral("blendMode")] = m_blendMode;
  obj[QStringLiteral("uniformScale")] = m_uniformScale;

  obj[QStringLiteral("timing")] = m_timing.serialize();

  QJsonObject xformObj;
  xformObj[QStringLiteral("posX")] = m_transform.posX.serialize();
  xformObj[QStringLiteral("posY")] = m_transform.posY.serialize();
  xformObj[QStringLiteral("scaleX")] = m_transform.scaleX.serialize();
  xformObj[QStringLiteral("scaleY")] = m_transform.scaleY.serialize();
  xformObj[QStringLiteral("rotation")] = m_transform.rotation.serialize();
  xformObj[QStringLiteral("opacity")] = m_transform.opacity.serialize();
  obj[QStringLiteral("transform")] = xformObj;

  QJsonObject colorObj;
  colorObj[QStringLiteral("liftR")] = m_color.liftR.serialize();
  colorObj[QStringLiteral("liftG")] = m_color.liftG.serialize();
  colorObj[QStringLiteral("liftB")] = m_color.liftB.serialize();
  colorObj[QStringLiteral("gammaR")] = m_color.gammaR.serialize();
  colorObj[QStringLiteral("gammaG")] = m_color.gammaG.serialize();
  colorObj[QStringLiteral("gammaB")] = m_color.gammaB.serialize();
  colorObj[QStringLiteral("gainR")] = m_color.gainR.serialize();
  colorObj[QStringLiteral("gainG")] = m_color.gainG.serialize();
  colorObj[QStringLiteral("gainB")] = m_color.gainB.serialize();
  colorObj[QStringLiteral("offsetR")] = m_color.offsetR.serialize();
  colorObj[QStringLiteral("offsetG")] = m_color.offsetG.serialize();
  colorObj[QStringLiteral("offsetB")] = m_color.offsetB.serialize();

  colorObj[QStringLiteral("temperature")] = m_color.temperature.serialize();
  colorObj[QStringLiteral("tint")] = m_color.tint.serialize();
  colorObj[QStringLiteral("contrast")] = m_color.contrast.serialize();
  colorObj[QStringLiteral("pivot")] = m_color.pivot.serialize();
  colorObj[QStringLiteral("midDetail")] = m_color.midDetail.serialize();
  colorObj[QStringLiteral("colorBoost")] = m_color.colorBoost.serialize();
  colorObj[QStringLiteral("shadows")] = m_color.shadows.serialize();
  colorObj[QStringLiteral("highlights")] = m_color.highlights.serialize();
  colorObj[QStringLiteral("saturation")] = m_color.saturation.serialize();
  colorObj[QStringLiteral("hue")] = m_color.hue.serialize();
  colorObj[QStringLiteral("lumMix")] = m_color.lumMix.serialize();
  colorObj[QStringLiteral("bypass")] = m_color.bypass;
  obj[QStringLiteral("color")] = colorObj;

  QJsonObject audioObj;
  audioObj[QStringLiteral("volume")] = m_audio.volume.serialize();
  audioObj[QStringLiteral("pan")] = m_audio.pan.serialize();
  audioObj[QStringLiteral("channelMode")] = m_audio.channelMode;
  obj[QStringLiteral("audio")] = audioObj;

  QJsonArray gArr;
  for (const auto &gId : m_nodeGraphIds) {
    gArr.append(gId);
  }
  obj[QStringLiteral("nodeGraphIds")] = gArr;
  obj[QStringLiteral("activeGraphIndex")] =
      static_cast<int>(m_activeGraphIndex);

  QJsonArray compArray;
  for (const auto &comp : m_components) {
    if (comp) {
      QJsonObject cObj = comp->serialize();
      cObj[QStringLiteral("_componentKind")] = static_cast<int>(comp->kind());
      cObj[QStringLiteral("_componentId")] = comp->componentId();
      compArray.append(cObj);
    }
  }
  obj[QStringLiteral("components")] = compArray;

  return obj;
}

TimelineClip TimelineClip::deserialize(const QJsonObject &obj) {
  TimelineClipCreateInfo info;
  info.clipId = obj.value(QStringLiteral("clipId")).toString();
  info.assetId = obj.value(QStringLiteral("assetId")).toString();
  info.name =
      obj.value(QStringLiteral("name")).toString(QStringLiteral("Clip"));

  if (obj.contains(QStringLiteral("timing")) &&
      obj[QStringLiteral("timing")].isObject()) {
    info.timing =
        ClipTiming::deserialize(obj[QStringLiteral("timing")].toObject());
  } else {
    info.timing = ClipTiming::deserialize(obj);
  }

  TimelineClip clip(info);
  clip.setIsMuted(obj.value(QStringLiteral("isMuted")).toBool(false));
  clip.setIsLocked(obj.value(QStringLiteral("isLocked")).toBool(false));
  clip.setBlendMode(obj.value(QStringLiteral("blendMode")).toInt(0));
  clip.setIsUniformScale(
      obj.value(QStringLiteral("uniformScale")).toBool(true));

  auto xform = std::make_unique<TransformComponent>();
  if (obj.contains(QStringLiteral("transform")) &&
      obj[QStringLiteral("transform")].isObject()) {
    xform->deserialize(obj[QStringLiteral("transform")].toObject());
  }
  clip.addComponent(std::move(xform));

  auto audio = std::make_unique<AudioComponent>();
  if (obj.contains(QStringLiteral("audio")) &&
      obj[QStringLiteral("audio")].isObject()) {
    audio->deserialize(obj[QStringLiteral("audio")].toObject());
  }
  clip.addComponent(std::move(audio));

  if (obj.contains(QStringLiteral("components")) &&
      obj[QStringLiteral("components")].isArray()) {
    const QJsonArray arr = obj[QStringLiteral("components")].toArray();
    for (const auto &val : arr) {
      const QJsonObject cObj = val.toObject();
      const auto kind = static_cast<ComponentKind>(
          cObj.value(QStringLiteral("_componentKind")).toInt(-1));
      const QString cId = cObj.value(QStringLiteral("_componentId")).toString();

      if (kind == ComponentKind::GeneratorText ||
          cId == QStringLiteral("text")) {
        auto textComp = std::make_unique<TextComponent>();
        textComp->deserialize(cObj);
        clip.addComponent(std::move(textComp));
      } else if (kind == ComponentKind::VideoModifier &&
                 cId == QStringLiteral("svg")) {
        auto svgComp = std::make_unique<SvgComponent>();
        svgComp->deserialize(cObj);
        clip.addComponent(std::move(svgComp));
      }
    }
  }

  if (obj.contains(QStringLiteral("color")) &&
      obj[QStringLiteral("color")].isObject()) {
    const QJsonObject colorObj = obj[QStringLiteral("color")].toObject();
    clip.getColor().liftR.deserializeInto(
        colorObj[QStringLiteral("liftR")].toObject(), 0.0f);
    clip.getColor().liftG.deserializeInto(
        colorObj[QStringLiteral("liftG")].toObject(), 0.0f);
    clip.getColor().liftB.deserializeInto(
        colorObj[QStringLiteral("liftB")].toObject(), 0.0f);
    clip.getColor().gammaR.deserializeInto(
        colorObj[QStringLiteral("gammaR")].toObject(), 1.0f);
    clip.getColor().gammaG.deserializeInto(
        colorObj[QStringLiteral("gammaG")].toObject(), 1.0f);
    clip.getColor().gammaB.deserializeInto(
        colorObj[QStringLiteral("gammaB")].toObject(), 1.0f);
    clip.getColor().gainR.deserializeInto(
        colorObj[QStringLiteral("gainR")].toObject(), 1.0f);
    clip.getColor().gainG.deserializeInto(
        colorObj[QStringLiteral("gainG")].toObject(), 1.0f);
    clip.getColor().gainB.deserializeInto(
        colorObj[QStringLiteral("gainB")].toObject(), 1.0f);
    clip.getColor().offsetR.deserializeInto(
        colorObj[QStringLiteral("offsetR")].toObject(), 0.0f);
    clip.getColor().offsetG.deserializeInto(
        colorObj[QStringLiteral("offsetG")].toObject(), 0.0f);
    clip.getColor().offsetB.deserializeInto(
        colorObj[QStringLiteral("offsetB")].toObject(), 0.0f);

    clip.getColor().temperature.deserializeInto(
        colorObj[QStringLiteral("temperature")].toObject(), 0.0f);
    clip.getColor().tint.deserializeInto(
        colorObj[QStringLiteral("tint")].toObject(), 0.0f);
    clip.getColor().contrast.deserializeInto(
        colorObj[QStringLiteral("contrast")].toObject(), 1.0f);
    clip.getColor().pivot.deserializeInto(
        colorObj[QStringLiteral("pivot")].toObject(), 0.435f);
    clip.getColor().midDetail.deserializeInto(
        colorObj[QStringLiteral("midDetail")].toObject(), 0.0f);
    clip.getColor().colorBoost.deserializeInto(
        colorObj[QStringLiteral("colorBoost")].toObject(), 0.0f);
    clip.getColor().shadows.deserializeInto(
        colorObj[QStringLiteral("shadows")].toObject(), 0.0f);
    clip.getColor().highlights.deserializeInto(
        colorObj[QStringLiteral("highlights")].toObject(), 0.0f);
    clip.getColor().saturation.deserializeInto(
        colorObj[QStringLiteral("saturation")].toObject(), 50.0f);
    clip.getColor().hue.deserializeInto(
        colorObj[QStringLiteral("hue")].toObject(), 50.0f);
    clip.getColor().lumMix.deserializeInto(
        colorObj[QStringLiteral("lumMix")].toObject(), 100.0f);
    clip.getColor().bypass =
        colorObj.value(QStringLiteral("bypass")).toBool(false);
  }

  if (obj.contains(QStringLiteral("nodeGraphIds"))) {
    clip.m_nodeGraphIds.clear();
    const QJsonArray arr = obj[QStringLiteral("nodeGraphIds")].toArray();
    for (const auto &val : arr) {
      clip.m_nodeGraphIds.push_back(val.toString());
    }
    if (clip.m_nodeGraphIds.empty()) {
      clip.m_nodeGraphIds.push_back(render::DEFAULT_IO_GRAPH_ID);
    }
    const size_t activeIdx = static_cast<size_t>(
        std::max(0, obj.value(QStringLiteral("activeGraphIndex")).toInt(0)));
    clip.setActiveGraphIndex(activeIdx);
  }

  return clip;
}

QVariantMap TimelineClip::toVariantMap() const {
  QVariantMap map;
  map[QStringLiteral("clipId")] = m_clipId;
  map[QStringLiteral("assetId")] = m_assetId;
  map[QStringLiteral("name")] = m_name;
  map[QStringLiteral("isTextClip")] =
      (getComponent<TextComponent>() != nullptr);

  if (const auto *textComp = getComponent<TextComponent>()) {
    QVariantList animList;
    if (textComp->animator) {
      animList.append(textComp->animator->serialize().toVariantMap());
    }
    map[QStringLiteral("textAnimators")] = animList;

    QVariantList spanList;
    for (const auto &span : textComp->richTextSpans) {
      spanList.append(span.serialize().toVariantMap());
    }
    map[QStringLiteral("richTextSpans")] = spanList;
  }

  map[QStringLiteral("isMuted")] = m_isMuted;
  map[QStringLiteral("isLocked")] = m_isLocked;
  map[QStringLiteral("blendMode")] = m_blendMode;
  map[QStringLiteral("uniformScale")] = m_uniformScale;

  map[QStringLiteral("startFrame")] = static_cast<double>(m_timing.startFrame);
  map[QStringLiteral("durationFrames")] =
      static_cast<double>(m_timing.durationFrames);
  map[QStringLiteral("sourceInFrame")] =
      static_cast<double>(m_timing.sourceInFrame);
  map[QStringLiteral("trackIndex")] = m_timing.trackIndex;
  map[QStringLiteral("speed")] = m_timing.speed;

  QVariantMap xform;
  xform[QStringLiteral("positionX")] =
      static_cast<double>(m_transform.posX.getStaticValue());
  xform[QStringLiteral("positionY")] =
      static_cast<double>(m_transform.posY.getStaticValue());
  xform[QStringLiteral("scaleX")] =
      static_cast<double>(m_transform.scaleX.getStaticValue());
  xform[QStringLiteral("scaleY")] =
      static_cast<double>(m_transform.scaleY.getStaticValue());
  xform[QStringLiteral("rotation")] =
      static_cast<double>(m_transform.rotation.getStaticValue());
  xform[QStringLiteral("opacity")] =
      static_cast<double>(m_transform.opacity.getStaticValue());
  map[QStringLiteral("transform")] = xform;

  QVariantMap col;
  col[QStringLiteral("lift")] =
      QVariantList{static_cast<double>(m_color.liftR.getStaticValue()),
                   static_cast<double>(m_color.liftG.getStaticValue()),
                   static_cast<double>(m_color.liftB.getStaticValue()), 0.0};
  col[QStringLiteral("gamma")] =
      QVariantList{static_cast<double>(m_color.gammaR.getStaticValue()),
                   static_cast<double>(m_color.gammaG.getStaticValue()),
                   static_cast<double>(m_color.gammaB.getStaticValue()), 0.0};
  col[QStringLiteral("gain")] =
      QVariantList{static_cast<double>(m_color.gainR.getStaticValue()),
                   static_cast<double>(m_color.gainG.getStaticValue()),
                   static_cast<double>(m_color.gainB.getStaticValue()), 0.0};
  col[QStringLiteral("offset")] =
      QVariantList{static_cast<double>(m_color.offsetR.getStaticValue()),
                   static_cast<double>(m_color.offsetG.getStaticValue()),
                   static_cast<double>(m_color.offsetB.getStaticValue()), 0.0};

  col[QStringLiteral("temperature")] = m_color.temperature.getStaticValue();
  col[QStringLiteral("tint")] = m_color.tint.getStaticValue();
  col[QStringLiteral("contrast")] = m_color.contrast.getStaticValue();
  col[QStringLiteral("pivot")] = m_color.pivot.getStaticValue();
  col[QStringLiteral("midDetail")] = m_color.midDetail.getStaticValue();
  col[QStringLiteral("colorBoost")] = m_color.colorBoost.getStaticValue();
  col[QStringLiteral("shadows")] = m_color.shadows.getStaticValue();
  col[QStringLiteral("highlights")] = m_color.highlights.getStaticValue();
  col[QStringLiteral("saturation")] = m_color.saturation.getStaticValue();
  col[QStringLiteral("hue")] = m_color.hue.getStaticValue();
  col[QStringLiteral("lumMix")] = m_color.lumMix.getStaticValue();
  col[QStringLiteral("bypass")] = m_color.bypass;
  map[QStringLiteral("color")] = col;

  QVariantMap aud;
  aud[QStringLiteral("volume")] = m_audio.volume.getStaticValue();
  aud[QStringLiteral("pan")] = m_audio.pan.getStaticValue();
  aud[QStringLiteral("channelMode")] = m_audio.channelMode;
  map[QStringLiteral("audio")] = aud;

  map[QStringLiteral("nodes")] = getNodeGraphNodes();
  map[QStringLiteral("links")] = getNodeGraphLinks();

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
    m_name = QStringLiteral("Untitled");
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

void TimelineClip::addComponent(std::unique_ptr<ClipComponent> component) {
  if (!component)
    return;

  const QString id = component->componentId();
  for (auto it = m_components.begin(); it != m_components.end(); ++it) {
    if ((*it)->componentId() == id) {
      *it = std::move(component);
      return;
    }
  }
  m_components.push_back(std::move(component));
}

bool TimelineClip::removeComponent(const QString &componentId) {
  const auto it = std::remove_if(
      m_components.begin(), m_components.end(),
      [&](const auto &c) { return c && c->componentId() == componentId; });
  if (it != m_components.end()) {
    m_components.erase(it, m_components.end());
    return true;
  }
  return false;
}

ClipComponent *TimelineClip::findComponent(const QString &componentId) {
  for (auto &c : m_components) {
    if (c && c->componentId() == componentId)
      return c.get();
  }
  return nullptr;
}

const ClipComponent *
TimelineClip::findComponent(const QString &componentId) const {
  return const_cast<TimelineClip *>(this)->findComponent(componentId);
}

const std::vector<std::unique_ptr<ClipComponent>> &
TimelineClip::getComponents() const noexcept {
  return m_components;
}

anim::AnimProperty *TimelineClip::findPropertyByPath(const QString &path) {
  if (path.isEmpty())
    return nullptr;

  const int dotIdx = path.indexOf(QLatin1Char('.'));
  if (dotIdx != -1) {
    const QString compId = path.left(dotIdx);
    const QString propId = path.mid(dotIdx + 1);
    if (auto *comp = findComponent(compId)) {
      return comp->findProperty(propId);
    }
  }

  for (auto &comp : m_components) {
    if (comp) {
      if (auto *prop = comp->findProperty(path))
        return prop;
    }
  }
  return nullptr;
}

const anim::AnimProperty *
TimelineClip::findPropertyByPath(const QString &path) const {
  return const_cast<TimelineClip *>(this)->findPropertyByPath(path);
}

anim::AnimProperty *TimelineClip::findAnimProperty(const QString &key) {
  return findPropertyByPath(key);
}

const anim::AnimProperty *
TimelineClip::findAnimProperty(const QString &key) const {
  return findPropertyByPath(key);
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

  const FrameIndex leftDuration = cutFrame - m_timing.startFrame;
  const FrameIndex rightDuration = m_timing.durationFrames - leftDuration;
  const FrameIndex rightSourceIn = m_timing.sourceInFrame + leftDuration;

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

  rightClip.copyGraphReferencesFrom(*this);

  for (const auto &comp : m_components) {
    if (comp) {
      rightClip.addComponent(comp->clone());
    }
  }

  m_timing.durationFrames = leftDuration;
  return rightClip;
}

bool TimelineClip::canUncutWith(const TimelineClip &rightClip) const noexcept {
  if (m_assetId != rightClip.m_assetId)
    return false;
  if (m_timing.endFrame() != rightClip.getTiming().startFrame)
    return false;
  if (m_timing.sourceOutFrame() != rightClip.getTiming().sourceInFrame)
    return false;
  if (m_timing.speed != rightClip.getTiming().speed)
    return false;
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
    XYLA_LOG_ERROR(
        "TimelineClip",
        std::format(
            "setBlendMode failed: mode cannot be negative! Received: {}",
            mode));
    return;
  }
  m_blendMode = mode;
}

bool TimelineClip::getIsUniformScale() const noexcept { return m_uniformScale; }
void TimelineClip::setIsUniformScale(bool uniform) noexcept {
  m_uniformScale = uniform;
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
  const QString graphId = getActiveGraphId();
  if (!graphId.isEmpty()) {
    if (auto g = render::NodeGraphManager::instance().getGraph(graphId)) {
      return g;
    }
  }
  return render::NodeGraphManager::instance().defaultIOGraph();
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
    if (id == graphId)
      return;
  }
  m_nodeGraphIds.push_back(graphId);
}

bool TimelineClip::detachNodeGraphId(const QString &graphId) {
  if (graphId == render::DEFAULT_IO_GRAPH_ID) {
    XYLA_LOG_WARN("TimelineClip",
                  "Cannot detach the default immutable I/O graph!");
    return false;
  }

  const auto it =
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
  if (const auto g = getNodeGraph()) {
    return g->toVariantList(0, nullptr);
  }
  return {};
}

QVariantList TimelineClip::getNodeGraphLinks() const {
  if (const auto g = getNodeGraph()) {
    return g->linksToVariantList();
  }
  return {};
}

bool TimelineClip::setProperty(const QString &propertyId, const QVariant &value,
                               FrameIndex localFrame) {
  const int dotIdx = propertyId.indexOf(QLatin1Char('.'));
  if (dotIdx != -1) {
    const QString compId = propertyId.left(dotIdx);
    const QString propId = propertyId.mid(dotIdx + 1);
    if (auto *comp = findComponent(compId)) {
      return comp->setProperty(propId, value, localFrame);
    }
  }

  for (auto &comp : m_components) {
    if (comp && comp->setProperty(propertyId, value, localFrame)) {
      return true;
    }
  }
  return false;
}

} // namespace xyla
