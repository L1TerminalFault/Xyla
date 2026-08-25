#pragma once

#include "nodeSocket.hpp"
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

  [[nodiscard]] const std::vector<NodeSocket> &inputs() const noexcept {
    return m_inputs;
  }
  [[nodiscard]] const std::vector<NodeSocket> &outputs() const noexcept {
    return m_outputs;
  }

  void setPropertyValue(const QString &key, SocketValue value) {
    m_properties[key] = std::move(value);
  }
  [[nodiscard]] const SocketValue &
  getPropertyValue(const QString &key) const noexcept {
    static const SocketValue kEmptyValue{std::monostate{}};
    auto it = m_properties.find(key);
    return (it != m_properties.end()) ? it->second : kEmptyValue;
  }

  [[nodiscard]] virtual QString generateGlslUniforms() const = 0;

  [[nodiscard]] virtual QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const = 0;

  [[nodiscard]] virtual QVariantMap toVariantMap() const;

protected:
  void addInput(QString id, QString name, SocketDataType type,
                SocketValue defaultVal = {});
  void addOutput(QString id, QString name, SocketDataType type);

private:
  QString m_id;
  QString m_name;
  QString m_typeName;

  std::vector<NodeSocket> m_inputs;
  std::vector<NodeSocket> m_outputs;
  std::unordered_map<QString, SocketValue> m_properties;
};

} // namespace xyla::render
