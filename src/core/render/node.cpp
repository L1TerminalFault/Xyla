#include "node.hpp"
#include <type_traits>

namespace xyla::render {

namespace {

QString socketDataTypeToString(SocketDataType type) {
  switch (type) {
  case SocketDataType::Float:
    return "Float";
  case SocketDataType::Vec2:
    return "Vec2";
  case SocketDataType::Color:
    return "Color";
  case SocketDataType::Mat4:
    return "Mat4";
  case SocketDataType::Int:
    return "Int";
  case SocketDataType::Bool:
    return "Bool";
  case SocketDataType::Image:
    return "Image";
  }
  return "Unknown";
}

QVariant socketValueToQVariant(const SocketValue &val) {
  return std::visit(
      [](const auto &v) -> QVariant {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, std::monostate>) {
          return {};
        } else if constexpr (std::is_same_v<T, float>) {
          return static_cast<double>(v);
        } else if constexpr (std::is_same_v<T, double>) {
          return v;
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

Node::Node(QString id, QString name, QString typeName)
    : m_id(std::move(id)), m_name(std::move(name)),
      m_typeName(std::move(typeName)) {}

void Node::addInput(QString id, QString name, SocketDataType type,
                    SocketValue defaultVal) {
  m_properties[id] = defaultVal;
  m_inputs.push_back({std::move(id), std::move(name), type, SocketKind::Input,
                      std::move(defaultVal)});
}

void Node::addOutput(QString id, QString name, SocketDataType type) {
  m_outputs.push_back(
      {std::move(id), std::move(name), type, SocketKind::Output, {}});
}

bool Node::setInputSocketValue(const QString &socketId,
                               const SocketValue &val) {
  for (auto &input : m_inputs) {
    if (input.id == socketId) {
      input.defaultValue = val;
      m_properties[socketId] = val;
      return true;
    }
  }
  m_properties[socketId] = val;
  return false;
}

SocketValue Node::property(const QString &key) const {
  auto it = m_properties.find(key);
  if (it != m_properties.end()) {
    return it->second;
  }
  return {};
}

void Node::setProperty(const QString &key, const SocketValue &val) {
  m_properties[key] = val;
  for (auto &input : m_inputs) {
    if (input.id == key) {
      input.defaultValue = val;
      break;
    }
  }
}

void Node::bindAnimationManager(const QString &clipId,
                                anim::AnimationManager &animMgr) {
  m_propertyHandles.clear();

  for (const auto &input : m_inputs) {
    if (input.dataType == SocketDataType::Image)
      continue;

    const QString address = QString("%1.%2.%3").arg(clipId, m_id, input.id);

    if (input.dataType == SocketDataType::Float) {
      float defVal = 0.0f;
      if (std::holds_alternative<float>(input.defaultValue)) {
        defVal = std::get<float>(input.defaultValue);
      }
      auto handle = animMgr.registerFloatProperty(clipId, address, defVal,
                                                  input.name, editorCategory());
      m_propertyHandles[input.id] = handle;
    } else {
      QVariant defVal = socketValueToQVariant(input.defaultValue);
      auto handle =
          animMgr.registerStaticProperty(clipId, address, defVal, input.name);
      m_propertyHandles[input.id] = handle;
    }
  }
}

anim::PropertyHandle
Node::propertyHandle(const QString &socketId) const noexcept {
  auto it = m_propertyHandles.find(socketId);
  if (it != m_propertyHandles.end()) {
    return it->second;
  }
  return {};
}

SocketValue
Node::evaluateInputSocket(const QString &socketId, FrameIndex localFrame,
                          const anim::AnimationManager *animMgr) const {
  if (animMgr) {
    auto handle = propertyHandle(socketId);
    if (handle.isValid()) {
      for (const auto &input : m_inputs) {
        if (input.id == socketId) {
          if (input.dataType == SocketDataType::Float) {
            return animMgr->evaluateFloat(handle, localFrame);
          }
          QVariant val = animMgr->evaluateValue(handle, localFrame);
          if (input.dataType == SocketDataType::Int) {
            return val.toInt();
          }
          if (input.dataType == SocketDataType::Bool) {
            return val.toBool();
          }
          if (input.dataType == SocketDataType::Vec2 &&
              val.canConvert<QVariantList>()) {
            QVariantList l = val.toList();
            if (l.size() == 2) {
              return Vec2Val{l[0].toFloat(), l[1].toFloat()};
            }
          }
          if (input.dataType == SocketDataType::Color &&
              val.canConvert<QVariantList>()) {
            QVariantList l = val.toList();
            if (l.size() == 4) {
              return ColorVal{l[0].toFloat(), l[1].toFloat(), l[2].toFloat(),
                              l[3].toFloat()};
            }
          }
        }
      }
    }
  }

  return property(socketId);
}

RenderContext
Node::queryInputContext(const QString &inputSocketId,
                        const RenderContext &downstreamCtx) const {
  Q_UNUSED(inputSocketId);
  return downstreamCtx;
}

QVariantMap Node::toVariantMap() const {
  QVariantMap map;
  map["id"] = m_id;
  map["name"] = m_name;
  map["typeName"] = m_typeName;
  map["x"] = m_positionX;
  map["y"] = m_positionY;
  map["hasCustomEditor"] = hasCustomEditor();
  map["customEditorQmlUrl"] = customEditorQmlUrl();
  map["editorCategory"] = editorCategory();
  map["editorIcon"] = editorIcon();

  QVariantMap propsMap;
  for (const auto &[key, val] : m_properties) {
    propsMap[key] = socketValueToQVariant(val);
  }
  map["properties"] = propsMap;

  QVariantList inputsList;
  for (const auto &s : m_inputs) {
    QVariantMap sMap;
    sMap["id"] = s.id;
    sMap["name"] = s.name;
    sMap["dataType"] = static_cast<int>(s.dataType);
    sMap["dataTypeName"] = socketDataTypeToString(s.dataType);
    sMap["defaultValue"] = socketValueToQVariant(s.defaultValue);
    sMap["minValue"] = s.minValue;
    sMap["maxValue"] = s.maxValue;
    sMap["stepSize"] = s.stepSize;
    sMap["unit"] = s.unit;
    inputsList.append(sMap);
  }
  map["inputs"] = inputsList;

  QVariantList outputsList;
  for (const auto &s : m_outputs) {
    QVariantMap sMap;
    sMap["id"] = s.id;
    sMap["name"] = s.name;
    sMap["dataType"] = static_cast<int>(s.dataType);
    sMap["dataTypeName"] = socketDataTypeToString(s.dataType);
    outputsList.append(sMap);
  }
  map["outputs"] = outputsList;

  return map;
}

} // namespace xyla::render
