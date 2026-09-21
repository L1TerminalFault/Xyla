#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/propertyHandle.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "nodeSocket.hpp"

#include <QVariantMap>
#include <algorithm>
#include <cstdint>
#include <unordered_map>
#include <vector>

namespace xyla::render {

struct RenderContext {
  uint32_t width{1920};
  uint32_t height{1080};
  float qualityScale{1.0f};
  int64_t frame{0};

  [[nodiscard]] uint32_t effectiveWidth() const noexcept {
    return std::max<uint32_t>(1, static_cast<uint32_t>(width * qualityScale));
  }
  [[nodiscard]] uint32_t effectiveHeight() const noexcept {
    return std::max<uint32_t>(1, static_cast<uint32_t>(height * qualityScale));
  }
};

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

  // Animation Engine Binding
  virtual void bindAnimationManager(const QString &clipId,
                                    anim::AnimationManager &animMgr);
  [[nodiscard]] anim::PropertyHandle
  propertyHandle(const QString &socketId) const noexcept;
  void setPropertyHandle(const QString &socketId,
                         anim::PropertyHandle handle) noexcept {
    m_propertyHandles[socketId] = handle;
  }
  [[nodiscard]] SocketValue
  evaluateInputSocket(const QString &socketId, FrameIndex localFrame,
                      const anim::AnimationManager *animMgr = nullptr) const;

  // Demand Pass Resolution Scaling
  [[nodiscard]] virtual RenderContext
  queryInputContext(const QString &inputSocketId,
                    const RenderContext &downstreamCtx) const;

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

  [[nodiscard]] bool bypassed() const noexcept { return m_bypassed; }
  void setBypassed(bool b) noexcept { m_bypassed = b; }

protected:
  QString m_id;
  QString m_name;
  QString m_typeName;
  double m_positionX{0.0};
  double m_positionY{0.0};

  std::vector<NodeSocket> m_inputs;
  std::vector<NodeSocket> m_outputs;
  std::unordered_map<QString, SocketValue> m_properties;
  std::unordered_map<QString, anim::PropertyHandle> m_propertyHandles;
  bool m_bypassed{false};
};

} // namespace xyla::render
