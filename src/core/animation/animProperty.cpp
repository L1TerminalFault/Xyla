#include "animProperty.hpp"
#include "core/log/logger.hpp"

namespace xyla::anim {

namespace {
const std::vector<Keyframe<float>> s_emptyKeyframes{};
}

DriverExpressionSolver AnimProperty::s_driverSolver = nullptr;

AnimProperty::AnimProperty(float staticValue) : m_staticValue(staticValue) {}

AnimProperty::AnimProperty(const AnimProperty &other)
    : m_staticValue(other.m_staticValue), m_mode(other.m_mode),
      m_isMuted(other.m_isMuted), m_isLocked(other.m_isLocked),
      m_driverExpression(other.m_driverExpression),
      m_curve(other.m_curve ? std::make_unique<AnimCurve>(*other.m_curve)
                            : nullptr) {}

AnimProperty &AnimProperty::operator=(const AnimProperty &other) {
  if (this == &other) {
    return *this;
  }
  m_staticValue = other.m_staticValue;
  m_mode = other.m_mode;
  m_isMuted = other.m_isMuted;
  m_isLocked = other.m_isLocked;
  m_driverExpression = other.m_driverExpression;
  m_curve =
      other.m_curve ? std::make_unique<AnimCurve>(*other.m_curve) : nullptr;
  return *this;
}

QJsonObject AnimProperty::serialize() const {
  QJsonObject obj;
  obj["value"] = static_cast<double>(m_staticValue);
  obj["mode"] = static_cast<int>(m_mode);
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;
  obj["expression"] = QString::fromStdString(m_driverExpression);

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

float AnimProperty::evaluate(FrameIndex frame) const noexcept {
  if (m_isMuted) {
    return m_staticValue;
  }

  if (m_mode == AnimMode::Driven && s_driverSolver &&
      !m_driverExpression.empty()) {
    EvaluationContext ctx{.timelineFrame = frame, .localFrame = frame};
    return s_driverSolver(m_driverExpression, ctx);
  }

  if (m_curve && !m_curve->isEmpty()) {
    return m_curve->evaluate(frame);
  }

  return m_staticValue;
}

bool AnimProperty::getIsAnimated() const noexcept {
  return m_curve && !m_curve->isEmpty();
}

void AnimProperty::deserializeInto(const QJsonObject &obj, float defaultVal) {
  m_staticValue = static_cast<float>(obj.value("value").toDouble(defaultVal));
  m_mode = static_cast<AnimMode>(obj.value("mode").toInt(0));
  m_isMuted = obj.value("isMuted").toBool(false);
  m_isLocked = obj.value("isLocked").toBool(false);
  m_driverExpression = obj.value("expression").toString().toStdString();

  if (obj.contains("keyframes") && obj["keyframes"].isArray()) {
    m_curve = std::make_unique<AnimCurve>(AnimCurve::deserialize(obj));
    if (m_curve->isEmpty()) {
      m_curve.reset();
    } else {
      m_mode = AnimMode::Keyframed;
    }
  } else {
    m_curve.reset();
  }
}

float AnimProperty::evaluateWithContext(
    const EvaluationContext &ctx) const noexcept {
  if (m_isMuted) {
    return m_staticValue;
  }

  if (m_mode == AnimMode::Driven && s_driverSolver &&
      !m_driverExpression.empty()) {
    return s_driverSolver(m_driverExpression, ctx);
  }

  if (m_mode == AnimMode::Keyframed && m_curve && !m_curve->isEmpty()) {
    return m_curve->evaluate(ctx.localFrame);
  }

  return m_staticValue;
}

AnimMode AnimProperty::getMode() const noexcept { return m_mode; }

void AnimProperty::setMode(AnimMode mode) noexcept { m_mode = mode; }

float AnimProperty::getStaticValue() const noexcept { return m_staticValue; }

void AnimProperty::setStaticValue(float value) noexcept {
  m_staticValue = value;
  if (m_mode == AnimMode::Static) {
    return;
  }
}

bool AnimProperty::getIsDriven() const noexcept {
  return m_mode == AnimMode::Driven && !m_driverExpression.empty();
}

bool AnimProperty::getIsMuted() const noexcept { return m_isMuted; }

void AnimProperty::setIsMuted(bool muted) noexcept { m_isMuted = muted; }

bool AnimProperty::getIsLocked() const noexcept { return m_isLocked; }

void AnimProperty::setIsLocked(bool locked) noexcept { m_isLocked = locked; }

const std::string &AnimProperty::getDriverExpression() const noexcept {
  return m_driverExpression;
}

void AnimProperty::setDriverExpression(std::string expression) {
  if (m_isLocked) {
    XYLA_LOG_WARN("AnimProperty",
                  "setDriverExpression rejected: property is locked.");
    return;
  }
  m_driverExpression = std::move(expression);
  m_mode = m_driverExpression.empty() ? AnimMode::Static : AnimMode::Driven;
}

void AnimProperty::setGlobalDriverSolver(DriverExpressionSolver solver) {
  s_driverSolver = std::move(solver);
}

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
  m_mode = AnimMode::Keyframed;
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
    m_mode = AnimMode::Static;
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
  m_mode = AnimMode::Static;
}

} // namespace xyla::anim
