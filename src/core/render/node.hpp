#pragma once

#include "core/render/nodeSocket.hpp"
#include <QMap>
#include <QString>
#include <QVariantMap>
#include <unordered_map>
#include <vector>

namespace xyla::render {

class Node {
public:
  Node(QString id, QString name, QString typeName)
      : m_id(std::move(id)), m_name(std::move(name)),
        m_typeName(std::move(typeName)) {}

  virtual ~Node() = default;

  [[nodiscard]] const QString &id() const noexcept { return m_id; }
  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  [[nodiscard]] const QString &typeName() const noexcept { return m_typeName; }

  [[nodiscard]] double positionX() const noexcept { return m_positionX; }
  [[nodiscard]] double positionY() const noexcept { return m_positionY; }
  void setPosition(double x, double y) noexcept {
    m_positionX = x;
    m_positionY = y;
  }

  [[nodiscard]] const std::vector<NodeSocket> &inputs() const noexcept {
    return m_inputs;
  }
  [[nodiscard]] const std::vector<NodeSocket> &outputs() const noexcept {
    return m_outputs;
  }

  // Updates input socket default value
  bool setInputSocketValue(const QString &socketId, SocketValue val) {
    for (auto &s : m_inputs) {
      if (s.id == socketId) {
        s.defaultValue = std::move(val);
        return true;
      }
    }
    return false;
  }

  void setPropertyValue(const QString &key, SocketValue val) {
    m_properties[key] = std::move(val);
  }

  [[nodiscard]] SocketValue propertyValue(const QString &key) const {
    auto it = m_properties.find(key);
    if (it != m_properties.end()) {
      return it->second;
    }
    return {};
  }

  // Pure virtual functions for GLSL code generation
  [[nodiscard]] virtual QString generateGlslUniforms() const = 0;
  [[nodiscard]] virtual QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const = 0;

  // Exports node property representation to QML
  [[nodiscard]] QVariantMap toVariantMap() const;

protected:
  void addInput(QString id, QString name, SocketDataType type,
                SocketValue defaultVal = {});
  void addOutput(QString id, QString name, SocketDataType type);

  QString m_id;
  QString m_name;
  QString m_typeName;
  double m_positionX{0.0};
  double m_positionY{0.0};

  std::vector<NodeSocket> m_inputs;
  std::vector<NodeSocket> m_outputs;
  std::unordered_map<QString, SocketValue> m_properties;
};

} // namespace xyla::render
