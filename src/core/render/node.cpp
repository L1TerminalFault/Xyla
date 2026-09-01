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
