#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/propertyHandle.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "nodeSocket.hpp"
#include "renderTypes.hpp"

#include <QJsonObject>
#include <QVariantMap>
#include <unordered_map>
#include <vector>

namespace xyla::render {

class Node {
public:
  explicit Node(QString id);
  virtual ~Node() = default;

  Node(const Node &) = delete;
  Node &operator=(const Node &) = delete;
  Node(Node &&) noexcept = default;
  Node &operator=(Node &&) noexcept = default;

  [[nodiscard]] const QString &id() const noexcept { return m_id; }
  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  void setName(QString newName) noexcept { m_name = std::move(newName); }

  [[nodiscard]] virtual QString defaultName() const noexcept = 0;
  [[nodiscard]] virtual QString typeName() const noexcept = 0;

  [[nodiscard]] double positionX() const noexcept { return m_positionX; }
  [[nodiscard]] double positionY() const noexcept { return m_positionY; }
  void setPosition(double x, double y) noexcept;

  [[nodiscard]] const std::vector<NodeSocket> &inputs() const noexcept {
    return m_inputs;
  }
  [[nodiscard]] const std::vector<NodeSocket> &outputs() const noexcept {
    return m_outputs;
  }

  [[nodiscard]] const NodeSocket *
  findInput(const QString &socketId) const noexcept;
  [[nodiscard]] NodeSocket *findInput(const QString &socketId) noexcept;
  [[nodiscard]] const NodeSocket *
  findOutput(const QString &socketId) const noexcept;
  [[nodiscard]] NodeSocket *findOutput(const QString &socketId) noexcept;

  void addInput(QString id, QString name, SocketDataType type,
                SocketValue defaultVal = {});
  void addEnumInput(QString id, QString name, QStringList options,
                    int32_t defaultIndex = 0) {
    NodeSocket sock{std::move(id), std::move(name), SocketDataType::Int,
                    SocketKind::Input, defaultIndex};
    sock.enumOptions = std::move(options);
    m_inputs.push_back(std::move(sock));
  }
  void addOutput(QString id, QString name, SocketDataType type);

  virtual void bindAnimationManager(const QString &scopeId,
                                    anim::AnimationManager &animMgr);
  [[nodiscard]] anim::PropertyHandle
  propertyHandle(const QString &socketId) const noexcept;

  [[nodiscard]] SocketValue
  evaluateInputSocket(const QString &socketId, FrameIndex frame,
                      const anim::AnimationManager *animMgr = nullptr) const;

  [[nodiscard]] virtual std::vector<QString> declaredSamplerNames() const {
    return {};
  }

  [[nodiscard]] virtual PixelRect computeRegionOfDefinition(
      const std::unordered_map<QString, PixelRect> &inputRods,
      const RenderContext &ctx) const;

  [[nodiscard]] virtual PixelRect
  queryInputRegionOfInterest(const QString &inputSocketId,
                             const PixelRect &downstreamRoi,
                             const RenderContext &ctx) const;

  [[nodiscard]] virtual bool hasCustomEditor() const noexcept { return false; }
  [[nodiscard]] virtual QString customEditorQmlUrl() const { return {}; }
  [[nodiscard]] virtual QString editorCategory() const {
    return QStringLiteral("General");
  }
  [[nodiscard]] virtual QString editorIcon() const {
    return QStringLiteral("tune");
  }

  [[nodiscard]] virtual QString generateGlslUniforms() const { return {}; }
  [[nodiscard]] virtual QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const = 0;

  [[nodiscard]] virtual QVariantMap
  toVariantMap(FrameIndex currentFrame,
               const anim::AnimationManager *animMgr) const;
  [[nodiscard]] virtual QJsonObject serialize() const;
  virtual bool deserialize(const QJsonObject &json);

  [[nodiscard]] bool bypassed() const noexcept { return m_bypassed; }
  void setBypassed(bool b) noexcept { m_bypassed = b; }

  [[nodiscard]] bool isPreviewTarget() const noexcept {
    return m_isPreviewTarget;
  }
  void setPreviewTarget(bool target) noexcept { m_isPreviewTarget = target; }

protected:
  QString m_id;
  QString m_name;
  double m_positionX{0.0};
  double m_positionY{0.0};

  std::vector<NodeSocket> m_inputs;
  std::vector<NodeSocket> m_outputs;
  std::unordered_map<QString, anim::PropertyHandle> m_propertyHandles;

  bool m_bypassed{false};
  bool m_isPreviewTarget{false};
};

} // namespace xyla::render
