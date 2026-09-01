#pragma once

#include "nodeSocket.hpp"
#include <QVariantMap>
#include <unordered_map>
#include <vector>

namespace xyla::render {

class Node {
public:
  Node(QString id, QString name, QString typeName);
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

  // Sockets & Properties
  [[nodiscard]] const std::vector<NodeSocket> &inputs() const noexcept {
    return m_inputs;
  }
  [[nodiscard]] const std::vector<NodeSocket> &outputs() const noexcept {
    return m_outputs;
  }

  void addInput(QString id, QString name, SocketDataType type,
                SocketValue defaultVal = {});
  void addOutput(QString id, QString name, SocketDataType type);

  bool setInputSocketValue(const QString &socketId, const SocketValue &val);
  [[nodiscard]] SocketValue property(const QString &key) const;
  void setProperty(const QString &key, const SocketValue &val);
  [[nodiscard]] const std::unordered_map<QString, SocketValue> &
  properties() const noexcept {
    return m_properties;
  }

  // EffectEditor Interface Contract
  [[nodiscard]] virtual bool hasCustomEditor() const { return false; }
  [[nodiscard]] virtual QString customEditorQmlUrl() const { return ""; }
  [[nodiscard]] virtual QString editorCategory() const { return "Transform"; }
  [[nodiscard]] virtual QString editorIcon() const { return "tune"; }

  // GLSL Generation
  [[nodiscard]] virtual QString generateGlslUniforms() const { return ""; }
  [[nodiscard]] virtual QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const = 0;

  [[nodiscard]] virtual QVariantMap toVariantMap() const;

protected:
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
