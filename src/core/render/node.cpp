#include "node.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include <QVariantList>
#include <cmath>

namespace xyla::render {

namespace {

QString socketDataTypeToString(SocketDataType type) {
  switch (type) {
  case SocketDataType::Float:
    return QStringLiteral("Float");
  case SocketDataType::Vec2:
    return QStringLiteral("Vec2");
  case SocketDataType::Color:
    return QStringLiteral("Color");
  case SocketDataType::Int:
    return QStringLiteral("Int");
  case SocketDataType::Bool:
    return QStringLiteral("Bool");
  case SocketDataType::Image:
    return QStringLiteral("Image");
  }
  return QStringLiteral("Unknown");
}

QVariant socketValueToQVariant(const SocketValue &val) {
  return std::visit(
      [](const auto &v) -> QVariant {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, std::monostate>) {
          return {};
        } else if constexpr (std::is_same_v<T, float> ||
                             std::is_same_v<T, double>) {
          return static_cast<double>(v);
        } else if constexpr (std::is_same_v<T, Vec2Val>) {
          return QVariantList{static_cast<double>(v[0]),
                              static_cast<double>(v[1])};
        } else if constexpr (std::is_same_v<T, ColorVal>) {
          return QVariantList{
              static_cast<double>(v[0]), static_cast<double>(v[1]),
              static_cast<double>(v[2]), static_cast<double>(v[3])};
        } else if constexpr (std::is_same_v<T, int32_t>) {
          return static_cast<int>(v);
        } else if constexpr (std::is_same_v<T, bool>) {
          return v;
        } else if constexpr (std::is_same_v<T, QString>) {
          return v;
        }
        return {};
      },
      val);
}

} // namespace

Node::Node(QString id) : m_id(std::move(id)) {}

void Node::setPosition(double x, double y) noexcept {
  if (std::isfinite(x) && std::isfinite(y)) {
    m_positionX = x;
    m_positionY = y;
  }
}

const NodeSocket *Node::findInput(const QString &socketId) const noexcept {
  for (const auto &input : m_inputs) {
    if (input.id == socketId)
      return &input;
  }
  return nullptr;
}

NodeSocket *Node::findInput(const QString &socketId) noexcept {
  for (auto &input : m_inputs) {
    if (input.id == socketId)
      return &input;
  }
  return nullptr;
}

const NodeSocket *Node::findOutput(const QString &socketId) const noexcept {
  for (const auto &output : m_outputs) {
    if (output.id == socketId)
      return &output;
  }
  return nullptr;
}

NodeSocket *Node::findOutput(const QString &socketId) noexcept {
  for (auto &output : m_outputs) {
    if (output.id == socketId)
      return &output;
  }
  return nullptr;
}

void Node::addInput(QString id, QString name, SocketDataType type,
                    SocketValue defaultVal) {
  m_inputs.push_back({std::move(id), std::move(name), type, SocketKind::Input,
                      std::move(defaultVal)});
}

void Node::addOutput(QString id, QString name, SocketDataType type) {
  m_outputs.push_back(
      {std::move(id), std::move(name), type, SocketKind::Output, {}});
}

void Node::bindAnimationManager(const QString &scopeId,
                                anim::AnimationManager &animMgr) {
  m_propertyHandles.clear();
  if (scopeId.isEmpty())
    return;

  const QString nodeAddress = QStringLiteral("%1.%2").arg(scopeId, m_id);

  for (const auto &input : m_inputs) {
    if (input.dataType == SocketDataType::Image)
      continue;

    const QString propAddress =
        QStringLiteral("%1.%2").arg(nodeAddress, input.id);
    const QString category = editorCategory();

    switch (input.dataType) {
    case SocketDataType::Float: {
      const float defVal = std::holds_alternative<float>(input.defaultValue)
                               ? std::get<float>(input.defaultValue)
                               : 0.0f;
      m_propertyHandles[input.id] = animMgr.registerFloatProperty(
          scopeId, propAddress, defVal, input.name, category);
      break;
    }
    case SocketDataType::Int: {
      const int32_t defVal = std::holds_alternative<int32_t>(input.defaultValue)
                                 ? std::get<int32_t>(input.defaultValue)
                                 : 0;
      m_propertyHandles[input.id] = animMgr.registerStaticProperty(
          scopeId, propAddress, defVal, input.name);
      break;
    }
    case SocketDataType::Bool: {
      const bool defVal = std::holds_alternative<bool>(input.defaultValue)
                              ? std::get<bool>(input.defaultValue)
                              : false;
      m_propertyHandles[input.id] = animMgr.registerStaticProperty(
          scopeId, propAddress, defVal, input.name);
      break;
    }
    case SocketDataType::Vec2: {
      Vec2Val defVal{0.0f, 0.0f};
      if (std::holds_alternative<Vec2Val>(input.defaultValue)) {
        defVal = std::get<Vec2Val>(input.defaultValue);
      }
      m_propertyHandles[input.id + QStringLiteral(".x")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".x"), defVal[0],
              input.name + QStringLiteral(" X"), category);
      m_propertyHandles[input.id + QStringLiteral(".y")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".y"), defVal[1],
              input.name + QStringLiteral(" Y"), category);
      break;
    }
    case SocketDataType::Color: {
      ColorVal defVal{0.0f, 0.0f, 0.0f, 1.0f};
      if (std::holds_alternative<ColorVal>(input.defaultValue)) {
        defVal = std::get<ColorVal>(input.defaultValue);
      }
      m_propertyHandles[input.id + QStringLiteral(".r")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".r"), defVal[0],
              input.name + QStringLiteral(" R"), category);
      m_propertyHandles[input.id + QStringLiteral(".g")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".g"), defVal[1],
              input.name + QStringLiteral(" G"), category);
      m_propertyHandles[input.id + QStringLiteral(".b")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".b"), defVal[2],
              input.name + QStringLiteral(" B"), category);
      m_propertyHandles[input.id + QStringLiteral(".a")] =
          animMgr.registerFloatProperty(
              scopeId, propAddress + QStringLiteral(".a"), defVal[3],
              input.name + QStringLiteral(" A"), category);
      break;
    }
    case SocketDataType::Image:
      break;
    }
  }
}

anim::PropertyHandle
Node::propertyHandle(const QString &socketId) const noexcept {
  const auto it = m_propertyHandles.find(socketId);
  return (it != m_propertyHandles.end()) ? it->second : anim::PropertyHandle{};
}

SocketValue
Node::evaluateInputSocket(const QString &socketId, FrameIndex frame,
                          const anim::AnimationManager *animMgr) const {
  const auto *input = findInput(socketId);
  if (!input)
    return {};

  if (!animMgr) {
    return input->defaultValue;
  }

  const auto handle = propertyHandle(socketId);

  switch (input->dataType) {
  case SocketDataType::Float: {
    if (handle.isValid()) {
      return animMgr->evaluateFloat(handle, frame);
    }
    return input->defaultValue;
  }
  case SocketDataType::Int: {
    if (handle.isValid()) {
      const QVariant val = animMgr->evaluateValue(handle, frame);
      if (val.isValid())
        return val.toInt();
    }
    return input->defaultValue;
  }
  case SocketDataType::Bool: {
    if (handle.isValid()) {
      const QVariant val = animMgr->evaluateValue(handle, frame);
      if (val.isValid())
        return val.toBool();
    }
    return input->defaultValue;
  }
  case SocketDataType::Vec2: {
    const auto handleX = propertyHandle(socketId + QStringLiteral(".x"));
    const auto handleY = propertyHandle(socketId + QStringLiteral(".y"));
    if (handleX.isValid() && handleY.isValid()) {
      const float x = animMgr->evaluateFloat(handleX, frame);
      const float y = animMgr->evaluateFloat(handleY, frame);
      return Vec2Val{x, y};
    }
    return input->defaultValue;
  }
  case SocketDataType::Color: {
    const auto handleR = propertyHandle(socketId + QStringLiteral(".r"));
    const auto handleG = propertyHandle(socketId + QStringLiteral(".g"));
    const auto handleB = propertyHandle(socketId + QStringLiteral(".b"));
    const auto handleA = propertyHandle(socketId + QStringLiteral(".a"));
    if (handleR.isValid() && handleG.isValid() && handleB.isValid() &&
        handleA.isValid()) {
      const float r = animMgr->evaluateFloat(handleR, frame);
      const float g = animMgr->evaluateFloat(handleG, frame);
      const float b = animMgr->evaluateFloat(handleB, frame);
      const float a = animMgr->evaluateFloat(handleA, frame);
      return ColorVal{r, g, b, a};
    }
    return input->defaultValue;
  }
  case SocketDataType::Image:
    return {};
  }

  return input->defaultValue;
}

PixelRect Node::computeRegionOfDefinition(
    const std::unordered_map<QString, PixelRect> &inputRods,
    const RenderContext &ctx) const {
  PixelRect united;
  for (const auto &[_, rect] : inputRods) {
    united = united.united(rect);
  }
  return united.isEmpty() ? ctx.rod : united;
}

PixelRect Node::queryInputRegionOfInterest(const QString &,
                                           const PixelRect &downstreamRoi,
                                           const RenderContext &) const {
  return downstreamRoi;
}

QJsonObject Node::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("id")] = m_id;
  obj[QStringLiteral("name")] = m_name.isEmpty() ? defaultName() : m_name;
  obj[QStringLiteral("typeName")] = typeName();
  obj[QStringLiteral("posX")] = m_positionX;
  obj[QStringLiteral("posY")] = m_positionY;
  obj[QStringLiteral("bypassed")] = m_bypassed;
  return obj;
}

bool Node::deserialize(const QJsonObject &json) {
  if (!json.contains(QStringLiteral("id")))
    return false;
  m_id = json[QStringLiteral("id")].toString();
  m_name = json[QStringLiteral("name")].toString(defaultName());
  m_positionX = json[QStringLiteral("posX")].toDouble(0.0);
  m_positionY = json[QStringLiteral("posY")].toDouble(0.0);
  m_bypassed = json[QStringLiteral("bypassed")].toBool(false);
  return true;
}

QVariantMap Node::toVariantMap(FrameIndex currentFrame,
                               const anim::AnimationManager *animMgr) const {
  QVariantMap map;
  map[QStringLiteral("id")] = m_id;
  map[QStringLiteral("name")] = m_name.isEmpty() ? defaultName() : m_name;
  map[QStringLiteral("typeName")] = typeName();
  map[QStringLiteral("x")] = m_positionX;
  map[QStringLiteral("y")] = m_positionY;
  map[QStringLiteral("bypassed")] = m_bypassed;
  map[QStringLiteral("isPreviewTarget")] = m_isPreviewTarget;
  map[QStringLiteral("hasCustomEditor")] = hasCustomEditor();
  map[QStringLiteral("customEditorQmlUrl")] = customEditorQmlUrl();
  map[QStringLiteral("editorCategory")] = editorCategory();
  map[QStringLiteral("editorIcon")] = editorIcon();

  QVariantList inList;
  inList.reserve(static_cast<qsizetype>(m_inputs.size()));
  for (const auto &s : m_inputs) {
    QVariantMap sMap;
    sMap[QStringLiteral("id")] = s.id;
    sMap[QStringLiteral("name")] = s.name;
    sMap[QStringLiteral("dataType")] = static_cast<int>(s.dataType);
    sMap[QStringLiteral("dataTypeName")] = socketDataTypeToString(s.dataType);
    sMap[QStringLiteral("defaultValue")] =
        socketValueToQVariant(s.defaultValue);
    sMap[QStringLiteral("value")] =
        socketValueToQVariant(evaluateInputSocket(s.id, currentFrame, animMgr));
    sMap[QStringLiteral("minValue")] = s.minValue;
    sMap[QStringLiteral("maxValue")] = s.maxValue;
    sMap[QStringLiteral("stepSize")] = s.stepSize;
    sMap[QStringLiteral("unit")] = s.unit;
    inList.append(sMap);
  }
  map[QStringLiteral("inputs")] = inList;

  QVariantList outList;
  outList.reserve(static_cast<qsizetype>(m_outputs.size()));
  for (const auto &s : m_outputs) {
    QVariantMap sMap;
    sMap[QStringLiteral("id")] = s.id;
    sMap[QStringLiteral("name")] = s.name;
    sMap[QStringLiteral("dataType")] = static_cast<int>(s.dataType);
    sMap[QStringLiteral("dataTypeName")] = socketDataTypeToString(s.dataType);
    outList.append(sMap);
  }
  map[QStringLiteral("outputs")] = outList;

  return map;
}

} // namespace xyla::render
