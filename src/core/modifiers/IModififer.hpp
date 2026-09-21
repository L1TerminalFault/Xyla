#pragma once

#include "core/animation/AnimationManager.hpp"
#include <QString>
#include <cstdint>
#include <memory>

namespace xyla {
enum class ModifierCatagory : uint8_t {
  TextKinetic = 0,
  ColorGrade,
  Spatial,
  Audio,
  Visual,
};

class IModifier {
public:
  virtual ~IModifier() = default;
  [[nodiscard]] virtual QString id() const noexcept = 0;
  [[nodiscard]] virtual QString typeId() const noexcept = 0;
  [[nodiscard]] virtual QString name() const = 0;
  virtual void setName(const QString &name) = 0;
  [[nodiscard]] virtual ModifierCatagory kind() const noexcept = 0;

  [[nodiscard]] virtual bool isEnabled() const noexcept = 0;
  virtual void setEnabled(bool enabled) noexcept = 0;

  [[nodiscard]] virtual std::unique_ptr<IModifier> clone() const = 0;
  virtual void registerProperties(const QString &clipId,
                                  anim::AnimationManager &animMgr) = 0;

  virtual bool applyPreset(const QString &presetName,
                           anim::AnimationManager &animMgr) {
    Q_UNUSED(presetName);
    Q_UNUSED(animMgr);
    return false;
  }
  [[nodiscard]] virtual QStringList availablePresets() const { return {}; }

  [[nodiscard]] virtual QJsonObject serialize() const = 0;
  virtual void deserialize(const QJsonObject &obj) = 0;
};
} // namespace xyla
