#include "animProperty.hpp"
#include "core/log/logger.hpp"

namespace xyla::anim {

namespace {
const std::vector<Keyframe<float>> s_emptyKeyframes{};
}

AnimProperty::AnimProperty(float staticValue) : m_staticValue(staticValue) {}

AnimProperty::AnimProperty(const AnimProperty &other)
    : m_staticValue(other.m_staticValue), m_isMuted(other.m_isMuted),
      m_isLocked(other.m_isLocked),
      m_curve(other.m_curve ? std::make_unique<AnimCurve>(*other.m_curve)
                            : nullptr) {}

AnimProperty &AnimProperty::operator=(const AnimProperty &other) {
  if (this == &other) {
    return *this;
  }
  m_staticValue = other.m_staticValue;
  m_isMuted = other.m_isMuted;
  m_isLocked = other.m_isLocked;
  m_curve =
      other.m_curve ? std::make_unique<AnimCurve>(*other.m_curve) : nullptr;
  return *this;
}

// serialization

QJsonObject AnimProperty::serialize() const {
  QJsonObject obj;
  obj["value"] = static_cast<double>(m_staticValue);
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;
  obj["isAnimated"] = getIsAnimated();

  if (m_curve && !m_curve->isEmpty()) {
    QJsonObject curveObj = m_curve->serialize();
    obj["keyframes"] = curveObj["keyframes"];
  }

  return obj;
}

AnimProperty AnimProperty::deserialize(const QJsonObject &obj,
                                       float defaultVal) {
  AnimProperty prop(defaultVal);
  prop.deserializeInto(obj, defaultVal);
  return prop;
}

void AnimProperty::deserializeInto(const QJsonObject &obj, float defaultVal) {
  m_staticValue = static_cast<float>(obj.value("value").toDouble(defaultVal));
  m_isMuted = obj.value("isMuted").toBool(false);
  m_isLocked = obj.value("isLocked").toBool(false);

  if (obj.contains("keyframes") && obj["keyframes"].isArray()) {
    m_curve = std::make_unique<AnimCurve>(AnimCurve::deserialize(obj));
    if (m_curve->isEmpty()) {
      m_curve.reset();
    }
  } else {
    m_curve.reset();
  }
}

// evaluation and queries

float AnimProperty::evaluate(FrameIndex frame) const noexcept {
  if (m_isMuted || !m_curve || m_curve->isEmpty()) {
    return m_staticValue;
  }
  return m_curve->evaluate(frame);
}

float AnimProperty::getStaticValue() const noexcept { return m_staticValue; }

bool AnimProperty::getIsAnimated() const noexcept {
  return m_curve && !m_curve->isEmpty();
}

bool AnimProperty::getIsMuted() const noexcept { return m_isMuted; }

bool AnimProperty::getIsLocked() const noexcept { return m_isLocked; }

bool AnimProperty::hasKeyframe(FrameIndex frame) const noexcept {
  return m_curve ? m_curve->hasKeyframe(frame) : false;
}

const Keyframe<float> *
AnimProperty::findKeyframe(FrameIndex frame) const noexcept {
  return m_curve ? m_curve->findKeyframe(frame) : nullptr;
}

const std::vector<Keyframe<float>> &
AnimProperty::getKeyframes() const noexcept {
  return m_curve ? m_curve->getKeyframes() : s_emptyKeyframes;
}

std::vector<FrameIndex> AnimProperty::getKeyframeFrames() const {
  return m_curve ? m_curve->getKeyframeFrames() : std::vector<FrameIndex>{};
}

const AnimCurve *AnimProperty::getCurve() const noexcept {
  return m_curve.get();
}

// mutations

void AnimProperty::setStaticValue(float value) noexcept {
  m_staticValue = value;
}

void AnimProperty::setIsMuted(bool muted) noexcept { m_isMuted = muted; }

void AnimProperty::setIsLocked(bool locked) noexcept { m_isLocked = locked; }

void AnimProperty::setKeyframe(FrameIndex frame, float value,
                               Interpolation interp, BezierHandles bezier) {
  if (m_isLocked) {
    XYLA_LOG_WARN("AnimProperty", "setKeyframe rejected: property is locked.");
    return;
  }

  if (!m_curve) {
    m_curve = std::make_unique<AnimCurve>();
  }

  m_curve->setKeyframe(frame, value, interp, bezier);
}

bool AnimProperty::removeKeyframe(FrameIndex frame) {
  if (m_isLocked) {
    XYLA_LOG_WARN("AnimProperty",
                  "removeKeyframe rejected: property is locked.");
    return false;
  }

  if (!m_curve) {
    return false;
  }

  bool removed = m_curve->removeKeyframe(frame);
  if (m_curve->isEmpty()) {
    m_curve.reset();
  }
  return removed;
}

bool AnimProperty::moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame) {
  if (m_isLocked) {
    return false;
  }

  if (!m_curve) {
    XYLA_LOG_ERROR("AnimProperty",
                   "moveKeyframe failed: property has no animation curve.");
    return false;
  }

  return m_curve->moveKeyframe(oldFrame, newFrame);
}

void AnimProperty::clearKeyframes() noexcept {
  if (m_isLocked) {
    XYLA_LOG_WARN("AnimProperty",
                  "clearKeyframes rejected: property is locked.");
    return;
  }
  m_curve.reset();
}

} // namespace xyla::anim
