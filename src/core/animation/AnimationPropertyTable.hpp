#pragma once

#include "animProperty.hpp"
#include "propertyHandle.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariant>
#include <unordered_map>
#include <vector>

namespace xyla::anim {

struct PropertySlot {
  QString address;
  QString scopeId;
  QString name;
  QString group;

  uint32_t generation{1};
  bool inUse{true};

  AnimProperty animProp{0.0f};
  QVariant staticValue;
  bool isAnimatableFloat{true};
};

class AnimationPropertyTable {
public:
  AnimationPropertyTable() = default;

  PropertyHandle registerFloatProperty(const QString &scopeId,
                                       const QString &address,
                                       float defaultValue,
                                       const QString &displayName,
                                       const QString &group);

  PropertyHandle registerStaticProperty(const QString &scopeId,
                                        const QString &address,
                                        const QVariant &defaultValue,
                                        const QString &displayName = "");

  [[nodiscard]] PropertyHandle
  findHandle(const QString &address) const noexcept;

  [[nodiscard]] float evaluateFloat(PropertyHandle handle,
                                    FrameIndex localFrame) const noexcept;

  [[nodiscard]] QVariant evaluateValue(PropertyHandle handle,
                                       FrameIndex localFrame) const;

  [[nodiscard]] PropertySlot *getSlot(PropertyHandle handle) noexcept;
  [[nodiscard]] const PropertySlot *
  getSlot(PropertyHandle handle) const noexcept;

  [[nodiscard]] const std::vector<PropertySlot> &allSlots() const noexcept;

  void unregisterProperty(const QString &address);
  void clear();

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);

private:
  [[nodiscard]] bool isHandleValid(PropertyHandle handle) const noexcept;
  uint32_t allocateSlot();

  std::vector<PropertySlot> m_slots;
  std::vector<uint32_t> m_freeSlots;
  std::unordered_map<QString, uint32_t> m_addressToSlot;
};

} // namespace xyla::anim
