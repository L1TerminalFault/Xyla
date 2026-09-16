#include "animCurve.hpp"
#include "core/animation/animMath.hpp"
#include "core/log/logger.hpp"

#include <QJsonArray>
#include <algorithm>
#include <format>
#include <iterator>

namespace xyla::anim {

QJsonObject AnimCurve::serialize() const {
  QJsonObject obj;
  QJsonArray kfArray;

  for (const auto &kf : m_keys) {
    QJsonObject kfObj;
    kfObj["frame"] = static_cast<qint64>(kf.frame);
    kfObj["value"] = static_cast<double>(kf.value);
    kfObj["interp"] = static_cast<int>(kf.interpolation);

    kfObj["inX"] = static_cast<double>(kf.bezier.inX);
    kfObj["inY"] = static_cast<double>(kf.bezier.inY);
    kfObj["outX"] = static_cast<double>(kf.bezier.outX);
    kfObj["outY"] = static_cast<double>(kf.bezier.outY);

    kfArray.append(kfObj);
  }

  obj["keyframes"] = kfArray;
  return obj;
}

AnimCurve AnimCurve::deserialize(const QJsonObject &obj) {
  AnimCurve curve;

  if (!obj.contains("keyframes") || !obj["keyframes"].isArray()) {
    return curve;
  }

  QJsonArray kfArray = obj["keyframes"].toArray();
  for (const auto &item : kfArray) {
    QJsonObject kfObj = item.toObject();
    auto frame = static_cast<FrameIndex>(kfObj.value("frame").toInteger(0));
    auto val = static_cast<float>(kfObj.value("value").toDouble(0.0));
    auto interp = static_cast<Interpolation>(kfObj.value("interp").toInt(1));

    BezierHandles bezier;
    bezier.inX = static_cast<float>(kfObj.value("inX").toDouble(0.666));
    bezier.inY = static_cast<float>(kfObj.value("inY").toDouble(0.0));
    bezier.outX = static_cast<float>(kfObj.value("outX").toDouble(0.333));
    bezier.outY = static_cast<float>(kfObj.value("outY").toDouble(0.0));

    curve.setKeyframe(frame, val, interp, bezier);
  }

  return curve;
}

float AnimCurve::evaluate(FrameIndex frame) const noexcept {
  if (m_keys.empty()) {
    return 0.0f;
  }

  if (frame <= m_keys.front().frame) {
    return m_keys.front().value;
  }
  if (frame >= m_keys.back().frame) {
    return m_keys.back().value;
  }

  auto it = std::lower_bound(
      m_keys.begin(), m_keys.end(), frame,
      [](const Keyframe<float> &kf, FrameIndex f) { return kf.frame < f; });

  if (it != m_keys.end() && it->frame == frame) {
    return it->value;
  }

  const size_t right = static_cast<size_t>(std::distance(m_keys.begin(), it));
  const size_t left = right - 1;
  const Keyframe<float> &k0 = m_keys[left];
  const Keyframe<float> &k1 = m_keys[right];

  if (k0.interpolation == Interpolation::Hold) {
    return k0.value;
  }

  const float tNorm = static_cast<float>(frame - k0.frame) /
                      static_cast<float>(k1.frame - k0.frame);

  if (k0.interpolation == Interpolation::Linear) {
    return lerp(k0.value, k1.value, tNorm);
  }

  // Bezier Interpolation
  const float t = solveBezierT(tNorm, k0.bezier.outX, k1.bezier.inX);
  const float y = evalBezierY(t, k0.bezier.outY, 1.0f + k1.bezier.inY);
  return lerp(k0.value, k1.value, y);
}

bool AnimCurve::isEmpty() const noexcept { return m_keys.empty(); }

size_t AnimCurve::getKeyframeCount() const noexcept { return m_keys.size(); }

bool AnimCurve::hasKeyframe(FrameIndex frame) const noexcept {
  return findKeyframe(frame) != nullptr;
}

const Keyframe<float> *
AnimCurve::findKeyframe(FrameIndex frame) const noexcept {
  auto it = std::lower_bound(
      m_keys.begin(), m_keys.end(), frame,
      [](const Keyframe<float> &kf, FrameIndex f) { return kf.frame < f; });

  if (it != m_keys.end() && it->frame == frame) {
    return &(*it);
  }
  return nullptr;
}

const std::vector<Keyframe<float>> &AnimCurve::getKeyframes() const noexcept {
  return m_keys;
}

std::vector<FrameIndex> AnimCurve::getKeyframeFrames() const {
  std::vector<FrameIndex> frames;
  frames.reserve(m_keys.size());
  for (const auto &k : m_keys) {
    frames.push_back(k.frame);
  }
  return frames;
}

void AnimCurve::setKeyframe(FrameIndex frame, float value, Interpolation interp,
                            BezierHandles bezier) {
  // safety clamps
  bezier.outX = std::clamp(bezier.outX, 0.0f, 1.0f);
  bezier.inX = std::clamp(bezier.inX, 0.0f, 1.0f);

  auto it = std::lower_bound(
      m_keys.begin(), m_keys.end(), frame,
      [](const Keyframe<float> &kf, FrameIndex f) { return kf.frame < f; });

  if (it != m_keys.end() && it->frame == frame) {
    it->value = value;
    it->interpolation = interp;
    it->bezier = bezier;
  } else {
    m_keys.insert(it, Keyframe<float>{frame, value, interp, bezier});
  }
}

bool AnimCurve::removeKeyframe(FrameIndex frame) {
  auto it = std::lower_bound(
      m_keys.begin(), m_keys.end(), frame,
      [](const Keyframe<float> &kf, FrameIndex f) { return kf.frame < f; });

  if (it != m_keys.end() && it->frame == frame) {
    m_keys.erase(it);
    return true;
  }

  XYLA_LOG_WARN(
      "AnimCurve",
      std::format("removeKeyframe failed: keyframe at frame {} not found.",
                  frame));
  return false;
}

bool AnimCurve::moveKeyframe(FrameIndex oldFrame, FrameIndex newFrame) {
  if (oldFrame == newFrame) {
    return true;
  }

  auto it = std::lower_bound(
      m_keys.begin(), m_keys.end(), oldFrame,
      [](const Keyframe<float> &kf, FrameIndex f) { return kf.frame < f; });

  if (it == m_keys.end() || it->frame != oldFrame) {
    XYLA_LOG_ERROR(
        "AnimCurve",
        std::format("moveKeyframe failed: no keyframe at frame {}.", oldFrame));
    return false;
  }

  Keyframe<float> key = *it;
  m_keys.erase(it);
  key.frame = newFrame;
  setKeyframe(key.frame, key.value, key.interpolation, key.bezier);
  return true;
}

void AnimCurve::clearKeyframes() noexcept { m_keys.clear(); }

} // namespace xyla::anim
