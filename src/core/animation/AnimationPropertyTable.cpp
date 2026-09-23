#include "AnimationPropertyTable.hpp"

#include <QJsonArray>
#include <qhashfunctions.h>

namespace xyla::anim {

PropertyHandle AnimationPropertyTable::registerFloatProperty(
    const QString &scopeId, const QString &address, float defaultValue,
    const QString &displayName, const QString &group) {
  auto it = m_addressToSlot.find(address);
  if (it != m_addressToSlot.end()) {
    uint32_t idx = it->second;
    return {idx, m_slots[idx].generation};
  }

  uint32_t slotIdx = allocateSlot();
  auto &slot = m_slots[slotIdx];

  QString prefixedAdress = QString("%1.%2").arg(scopeId, address);

  slot.address = prefixedAdress;
  slot.scopeId = scopeId;
  slot.name = displayName.isEmpty() ? address : displayName;
  slot.group = group;
  slot.isAnimatableFloat = true;
  slot.animProp = AnimProperty(defaultValue);
  slot.inUse = true;

  m_addressToSlot[address] = slotIdx;
  return {slotIdx, slot.generation};
}

PropertyHandle AnimationPropertyTable::registerStaticProperty(
    const QString &scopeId, const QString &address,
    const QVariant &defaultValue, const QString &displayName) {
  auto it = m_addressToSlot.find(address);
  if (it != m_addressToSlot.end()) {
    uint32_t idx = it->second;
    return {idx, m_slots[idx].generation};
  }

  uint32_t slotIdx = allocateSlot();
  auto &slot = m_slots[slotIdx];

  QString prefixedAdress = QString("%1.%2").arg(scopeId, address);
  slot.address = prefixedAdress;
  slot.scopeId = scopeId;
  slot.name = displayName.isEmpty() ? address : displayName;
  slot.isAnimatableFloat = false;
  slot.staticValue = defaultValue;
  slot.inUse = true;

  m_addressToSlot[address] = slotIdx;
  return {slotIdx, slot.generation};
}

PropertyHandle
AnimationPropertyTable::findHandle(const QString &uuid) const noexcept {
  auto it = m_addressToSlot.find(uuid);
  if (it == m_addressToSlot.end()) {
    return {};
  }
  uint32_t idx = it->second;
  return {idx, m_slots[idx].generation};
}

float AnimationPropertyTable::evaluateFloat(
    PropertyHandle handle, FrameIndex localFrame) const noexcept {
  if (!isHandleValid(handle)) {
    return 0.0f;
  }
  return m_slots[handle.index].animProp.evaluate(localFrame);
}

QVariant AnimationPropertyTable::evaluateValue(PropertyHandle handle,
                                               FrameIndex localFrame) const {
  if (!isHandleValid(handle)) {
    return {};
  }
  const auto &slot = m_slots[handle.index];
  if (slot.isAnimatableFloat) {
    return slot.animProp.evaluate(localFrame);
  }
  return slot.staticValue;
}

PropertySlot *AnimationPropertyTable::getSlot(PropertyHandle handle) noexcept {
  if (!isHandleValid(handle)) {
    return nullptr;
  }
  return &m_slots[handle.index];
}

const PropertySlot *
AnimationPropertyTable::getSlot(PropertyHandle handle) const noexcept {
  if (!isHandleValid(handle)) {
    return nullptr;
  }
  return &m_slots[handle.index];
}

const std::vector<PropertySlot> &
AnimationPropertyTable::allSlots() const noexcept {
  return m_slots;
}

void AnimationPropertyTable::unregisterProperty(const QString &address) {
  auto it = m_addressToSlot.find(address);
  if (it == m_addressToSlot.end()) {
    return;
  }

  uint32_t slotIdx = it->second;
  m_slots[slotIdx].inUse = false;
  m_freeSlots.push_back(slotIdx);
  m_addressToSlot.erase(it);
}

void AnimationPropertyTable::clear() {
  m_slots.clear();
  m_freeSlots.clear();
  m_addressToSlot.clear();
}

bool AnimationPropertyTable::isHandleValid(
    PropertyHandle handle) const noexcept {
  return handle.index < m_slots.size() && m_slots[handle.index].inUse &&
         m_slots[handle.index].generation == handle.generation;
}

uint32_t AnimationPropertyTable::allocateSlot() {
  if (!m_freeSlots.empty()) {
    uint32_t idx = m_freeSlots.back();
    m_freeSlots.pop_back();
    m_slots[idx].generation++;
    return idx;
  }
  m_slots.emplace_back();
  return static_cast<uint32_t>(m_slots.size() - 1);
}

QJsonObject AnimationPropertyTable::serialize() const {
  QJsonObject root;
  QJsonArray slotsArray;

  for (const auto &slot : m_slots) {
    if (!slot.inUse)
      continue;

    QJsonObject sObj;
    sObj["address"] = slot.address;
    sObj["scopeId"] = slot.scopeId;
    sObj["name"] = slot.name;
    sObj["group"] = slot.group;
    sObj["isAnimatableFloat"] = slot.isAnimatableFloat;

    if (slot.isAnimatableFloat) {
      sObj["animProp"] = slot.animProp.serialize();
    } else {
      sObj["staticValue"] = QJsonValue::fromVariant(slot.staticValue);
    }

    slotsArray.append(sObj);
  }

  root["slots"] = slotsArray;
  return root;
}

void AnimationPropertyTable::deserialize(const QJsonObject &obj) {
  clear();

  if (!obj.contains("slots") || !obj["slots"].isArray())
    return;

  QJsonArray slotsArray = obj["slots"].toArray();
  for (const auto &val : slotsArray) {
    QJsonObject sObj = val.toObject();
    const QString address = sObj.value("address").toString();
    const QString clipId = sObj.value("clipId").toString();
    const QString name = sObj.value("name").toString();
    const QString group = sObj.value("group").toString();
    const bool isFloat = sObj.value("isAnimatableFloat").toBool(true);

    if (isFloat) {
      auto handle = registerFloatProperty(clipId, address, 0.0f, name, group);
      if (auto *slot = getSlot(handle)) {
        if (sObj.contains("animProp") && sObj["animProp"].isObject()) {
          slot->animProp.deserializeInto(sObj["animProp"].toObject(), 0.0f);
        }
      }
    } else {
      QVariant staticVal = sObj.value("staticValue").toVariant();
      registerStaticProperty(clipId, address, staticVal, name);
    }
  }
}

} // namespace xyla::anim
