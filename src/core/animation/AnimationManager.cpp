#include "AnimationManager.hpp"
#include "core/animation/animChannel.hpp"

namespace xyla::anim {

AnimationManager::AnimationManager(XylaUndoStack *undoStack, QObject *parent)
    : QObject(parent), m_undoStack(undoStack),
      m_activeTable(std::make_shared<AnimationPropertyTable>()) {}

void AnimationManager::setActiveTable(
    std::shared_ptr<AnimationPropertyTable> table) noexcept {
  m_activeTable = table ? table : std::make_shared<AnimationPropertyTable>();
  emit tableSwapped();
  emit channelsInvalidated();
}

std::shared_ptr<AnimationPropertyTable>
AnimationManager::activeTable() const noexcept {
  return m_activeTable;
}

AnimationPropertyTable *AnimationManager::table() noexcept {
  return m_activeTable.get();
}

const AnimationPropertyTable *AnimationManager::table() const noexcept {
  return m_activeTable.get();
}

void AnimationManager::setUndoStack(XylaUndoStack *undoStack) noexcept {
  m_undoStack = undoStack;
}

PropertyHandle AnimationManager::registerFloatProperty(
    const QString &clipId, const QString &address, float defaultValue,
    const QString &displayName, const QString &group) {
  if (!m_activeTable)
    return {};
  return m_activeTable->registerFloatProperty(clipId, address, defaultValue,
                                              displayName, group);
}

PropertyHandle AnimationManager::registerStaticProperty(
    const QString &clipId, const QString &address, const QVariant &defaultValue,
    const QString &displayName) {
  if (!m_activeTable)
    return {};
  return m_activeTable->registerStaticProperty(clipId, address, defaultValue,
                                               displayName);
}

PropertyHandle
AnimationManager::findHandle(const QString &address) const noexcept {
  if (!m_activeTable)
    return {};
  return m_activeTable->findHandle(address);
}

float AnimationManager::evaluateFloat(PropertyHandle handle,
                                      FrameIndex localFrame) const noexcept {
  if (!m_activeTable)
    return 0.0f;
  return m_activeTable->evaluateFloat(handle, localFrame);
}

QVariant AnimationManager::evaluateValue(PropertyHandle handle,
                                         FrameIndex localFrame) const {
  if (!m_activeTable)
    return {};
  return m_activeTable->evaluateValue(handle, localFrame);
}

float AnimationManager::evaluateFloatByAddress(const QString &address,
                                               FrameIndex localFrame) const {
  if (!m_activeTable)
    return 0.0f;
  auto handle = m_activeTable->findHandle(address);
  return m_activeTable->evaluateFloat(handle, localFrame);
}

QVariant AnimationManager::evaluateValueByAddress(const QString &address,
                                                  FrameIndex localFrame) const {
  if (!m_activeTable)
    return {};
  auto handle = m_activeTable->findHandle(address);
  return m_activeTable->evaluateValue(handle, localFrame);
}

bool AnimationManager::setProperty(PropertyHandle handle, const QVariant &value,
                                   FrameIndex localFrame) {
  if (!m_activeTable)
    return false;

  auto *slot = m_activeTable->getSlot(handle);
  if (!slot)
    return false;

  if (slot->isAnimatableFloat) {
    bool ok = false;
    float fVal = value.toFloat(&ok);
    if (!ok)
      return false;

    if (slot->animProp.getIsAnimated()) {
      slot->animProp.setKeyframe(localFrame, fVal);
    } else {
      slot->animProp.setStaticValue(fVal);
    }
  } else {
    slot->staticValue = value;
  }

  emit propertyChanged(slot->address);
  emit keyframesChanged(slot->clipId);
  return true;
}

bool AnimationManager::setProperty(const QString &address,
                                   const QVariant &value,
                                   FrameIndex localFrame) {
  if (!m_activeTable)
    return false;
  auto handle = m_activeTable->findHandle(address);
  return setProperty(handle, value, localFrame);
}

bool AnimationManager::hasKeyframe(PropertyHandle handle,
                                   FrameIndex localFrame) const noexcept {
  if (!m_activeTable)
    return false;
  const auto *slot = m_activeTable->getSlot(handle);
  if (!slot || !slot->isAnimatableFloat)
    return false;
  return slot->animProp.hasKeyframe(localFrame);
}

bool AnimationManager::hasKeyframe(const QString &address,
                                   FrameIndex localFrame) const noexcept {
  if (!m_activeTable)
    return false;
  auto handle = m_activeTable->findHandle(address);
  return hasKeyframe(handle, localFrame);
}

void AnimationManager::toggleKeyframe(const QString &address,
                                      FrameIndex localFrame,
                                      const QVariant &currentValue) {
  if (!m_activeTable)
    return;

  auto handle = m_activeTable->findHandle(address);
  auto *slot = m_activeTable->getSlot(handle);
  if (!slot || !slot->isAnimatableFloat)
    return;

  float val = 0.0f;
  if (currentValue.isValid() && !currentValue.isNull()) {
    val = currentValue.toFloat();
  } else {
    val = slot->animProp.evaluate(localFrame);
  }

  if (slot->animProp.hasKeyframe(localFrame)) {
    slot->animProp.removeKeyframe(localFrame);
  } else {
    slot->animProp.setKeyframe(localFrame, val);
  }

  emit propertyChanged(slot->address);
  emit keyframesChanged(slot->clipId);
  emit channelsInvalidated();
}

void AnimationManager::removeKeyframe(const QString &address,
                                      FrameIndex localFrame) {
  if (!m_activeTable)
    return;

  auto handle = m_activeTable->findHandle(address);
  auto *slot = m_activeTable->getSlot(handle);
  if (!slot || !slot->isAnimatableFloat)
    return;

  if (slot->animProp.removeKeyframe(localFrame)) {
    emit propertyChanged(slot->address);
    emit keyframesChanged(slot->clipId);
    emit channelsInvalidated();
  }
}

QVariantList AnimationManager::getClipAnimChannels(const QString &clipId,
                                                   int64_t currentFrame) const {
  QVariantList result;
  if (!m_activeTable || clipId.isEmpty())
    return result;

  for (const auto &slot : m_activeTable->allSlots()) {
    if (!slot.inUse || slot.clipId != clipId || !slot.isAnimatableFloat)
      continue;

    AnimChannelInfo info;
    info.clipId = slot.clipId;
    info.id = slot.address;
    info.name = slot.name;
    info.group = slot.group;
    info.isAnimated = slot.animProp.getIsAnimated();

    if (info.isAnimated) {
      for (const auto &k : slot.animProp.getKeyframes()) {
        info.keyframeFrames.push_back(k.frame);
        if (k.frame == currentFrame) {
          info.hasKeyframeAtPlayhead = true;
        }

        KeyframeDetail det;
        det.frame = k.frame;
        det.value = k.value;
        det.interpolation = static_cast<int>(k.interpolation);
        det.inX = k.bezier.inX;
        det.inY = k.bezier.inY;
        det.outX = k.bezier.outX;
        det.outY = k.bezier.outY;
        info.details.push_back(det);
      }
    }

    result.append(info.toVariantMap());
  }

  return result;
}

} // namespace xyla::anim
