#include "keyframeContextMenuController.hpp"
#include "core/animation/clipboardKeyframe.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "ui/models/AnimationModel.hpp"
#include "ui/models/timelineModel.hpp"

#include <cmath>
#include <limits>

namespace xyla::anim {

namespace {

struct ResolvedContext {
  AnimationModel *animModel{nullptr};
  TimelineModel *timelineModel{nullptr};
};

ResolvedContext resolveContext(QObject *obj) {
  ResolvedContext ctx;
  if (!obj)
    return ctx;

  if (auto *am = qobject_cast<AnimationModel *>(obj)) {
    ctx.animModel = am;
  } else if (auto *tm = qobject_cast<TimelineModel *>(obj)) {
    ctx.timelineModel = tm;
  }
  return ctx;
}

} // namespace

KeyframeContextMenuController::KeyframeContextMenuController(QObject *parent)
    : QObject(parent) {}

void KeyframeContextMenuController::copy(QObject *modelObj,
                                         const QVariantList &selectedKeys) {
  auto ctx = resolveContext(modelObj);
  if (selectedKeys.isEmpty())
    return;

  m_clipboard.clear();
  int64_t minF = std::numeric_limits<int64_t>::max();
  int64_t maxF = std::numeric_limits<int64_t>::min();

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t absFrame = map.value("frame").toLongLong();

    const TimelineClip *clip = nullptr;
    if (ctx.timelineModel) {
      clip = ctx.timelineModel->findClip(clipId);
    }

    if (!clip)
      continue;

    const auto *prop = clip->findPropertyByPath(propId);
    if (!prop)
      continue;

    const int64_t relFrame = clip->getTiming().timelineToLocalFrame(absFrame);

    if (const auto *kf = prop->findKeyframe(relFrame)) {
      ClipboardKeyframe ck;
      ck.clipId = clipId;
      ck.propId = propId;
      ck.frame = absFrame;
      ck.value = kf->value;
      ck.interpolation = static_cast<int>(kf->interpolation);
      ck.inX = kf->bezier.inX;
      ck.inY = kf->bezier.inY;
      ck.outX = kf->bezier.outX;
      ck.outY = kf->bezier.outY;

      minF = std::min(minF, absFrame);
      maxF = std::max(maxF, absFrame);
      m_clipboard.keys.push_back(ck);
    }
  }

  if (!m_clipboard.keys.empty()) {
    m_clipboard.earliestFrame = minF;
    m_clipboard.latestFrame = maxF;
    emit clipboardChanged();
  }
}

void KeyframeContextMenuController::paste(QObject *modelObj,
                                          int64_t playheadFrame) {
  auto ctx = resolveContext(modelObj);
  if (ctx.animModel) {
    const int64_t offset = playheadFrame - m_clipboard.earliestFrame;
    ctx.animModel->pasteKeyframes(m_clipboard.keys, offset, MergeMode::Mix);
  }
}

void KeyframeContextMenuController::pasteNoOffset(QObject *modelObj) {
  auto ctx = resolveContext(modelObj);
  if (ctx.animModel) {
    ctx.animModel->pasteKeyframes(m_clipboard.keys, 0, MergeMode::Mix);
  }
}

void KeyframeContextMenuController::pasteOverwriteRange(QObject *modelObj,
                                                        int64_t playheadFrame) {
  auto ctx = resolveContext(modelObj);
  if (ctx.animModel) {
    const int64_t offset = playheadFrame - m_clipboard.earliestFrame;
    ctx.animModel->pasteKeyframes(m_clipboard.keys, offset,
                                  MergeMode::OverwriteRange);
  }
}

void KeyframeContextMenuController::pasteOverwriteAll(QObject *modelObj,
                                                      int64_t playheadFrame) {
  auto ctx = resolveContext(modelObj);
  if (ctx.animModel) {
    const int64_t offset = playheadFrame - m_clipboard.earliestFrame;
    ctx.animModel->pasteKeyframes(m_clipboard.keys, offset,
                                  MergeMode::OverwriteAll);
  }
}

void KeyframeContextMenuController::setInterpolation(
    QObject *modelObj, const QVariantList &selectedKeys, int interpMode) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.animModel || selectedKeys.isEmpty())
    return;

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t frame = map.value("frame").toLongLong();
    const float val =
        ctx.animModel->getClipEvaluatedProperty(clipId, propId, frame);

    ctx.animModel->updateKeyframe(clipId, propId, frame, frame, val, interpMode,
                                  0.666f, 0.0f, 0.333f, 0.0f);
  }
}

void KeyframeContextMenuController::setHandleType(
    QObject *modelObj, const QVariantList &selectedKeys, int handleTypeInt) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.animModel || selectedKeys.isEmpty())
    return;

  const auto type = static_cast<HandleType>(handleTypeInt);
  float inX = 0.666f, outX = 0.333f;

  if (type == HandleType::Vector) {
    inX = 1.0f;
    outX = 0.0f;
  } else if (type == HandleType::Auto || type == HandleType::AutoClamped) {
    inX = 0.666f;
    outX = 0.333f;
  }

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t frame = map.value("frame").toLongLong();
    const float val =
        ctx.animModel->getClipEvaluatedProperty(clipId, propId, frame);

    ctx.animModel->updateKeyframe(clipId, propId, frame, frame, val, 2, inX,
                                  0.0f, outX, 0.0f);
  }
}

void KeyframeContextMenuController::setEasing(QObject *modelObj,
                                              const QVariantList &selectedKeys,
                                              int easingTypeInt) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.animModel || selectedKeys.isEmpty())
    return;

  const auto easing = static_cast<EasingType>(easingTypeInt);
  float inX = 0.666f, inY = 0.0f, outX = 0.333f, outY = 0.0f;

  if (easing == EasingType::EaseIn) {
    inX = 0.5f;
    inY = -0.5f;
    outX = 0.0f;
    outY = 0.0f;
  } else if (easing == EasingType::EaseOut) {
    inX = 1.0f;
    inY = 0.0f;
    outX = 0.5f;
    outY = 0.5f;
  } else if (easing == EasingType::EaseInOut) {
    inX = 0.75f;
    inY = 0.0f;
    outX = 0.25f;
    outY = 0.0f;
  }

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t frame = map.value("frame").toLongLong();
    const float val =
        ctx.animModel->getClipEvaluatedProperty(clipId, propId, frame);

    ctx.animModel->updateKeyframe(clipId, propId, frame, frame, val, 2, inX,
                                  inY, outX, outY);
  }
}

void KeyframeContextMenuController::cleanKeys(QObject *modelObj,
                                              const QVariantList &selectedKeys,
                                              float tolerance) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.animModel || selectedKeys.size() < 3)
    return;

  QVariantList redundantKeys;
  for (int i = 1; i < selectedKeys.size() - 1; ++i) {
    const auto prev = selectedKeys[i - 1].toMap();
    const auto curr = selectedKeys[i].toMap();
    const auto next = selectedKeys[i + 1].toMap();

    const float v0 = ctx.animModel->getClipEvaluatedProperty(
        prev["clipId"].toString(), prev["propId"].toString(),
        prev["frame"].toLongLong());
    const float v1 = ctx.animModel->getClipEvaluatedProperty(
        curr["clipId"].toString(), curr["propId"].toString(),
        curr["frame"].toLongLong());
    const float v2 = ctx.animModel->getClipEvaluatedProperty(
        next["clipId"].toString(), next["propId"].toString(),
        next["frame"].toLongLong());

    if (std::abs(v1 - v0) < tolerance && std::abs(v2 - v1) < tolerance) {
      redundantKeys.push_back(selectedKeys[i]);
    }
  }
  if (!redundantKeys.isEmpty()) {
    ctx.animModel->removeKeyframes(redundantKeys);
  }
}

void KeyframeContextMenuController::sampleKeys(
    QObject *modelObj, const QVariantList &selectedKeys) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.animModel || selectedKeys.size() < 2)
    return;

  const auto first = selectedKeys.front().toMap();
  const auto last = selectedKeys.back().toMap();
  const QString clipId = first["clipId"].toString();
  const QString propId = first["propId"].toString();
  const int64_t startF = first["frame"].toLongLong();
  const int64_t endF = last["frame"].toLongLong();

  for (int64_t f = startF; f <= endF; ++f) {
    const float val =
        ctx.animModel->getClipEvaluatedProperty(clipId, propId, f);
    ctx.animModel->updateKeyframe(clipId, propId, f, f, val, 1, 0.666f, 0.0f,
                                  0.333f, 0.0f);
  }
}

void KeyframeContextMenuController::bakeCurve(QObject *modelObj,
                                              const QString &clipId,
                                              const QString &propId) {
  Q_UNUSED(clipId);
  Q_UNUSED(propId);
  sampleKeys(modelObj, {});
}

void KeyframeContextMenuController::deleteKeys(
    QObject *modelObj, const QVariantList &selectedKeys) {
  auto ctx = resolveContext(modelObj);
  if (ctx.animModel && !selectedKeys.isEmpty()) {
    ctx.animModel->removeKeyframes(selectedKeys);
  }
}

void KeyframeContextMenuController::setExtrapolation(QObject *modelObj,
                                                     const QString &clipId,
                                                     const QString &propId,
                                                     int modeInt) {
  Q_UNUSED(modelObj);
  Q_UNUSED(clipId);
  Q_UNUSED(propId);
  Q_UNUSED(modeInt);
}

void KeyframeContextMenuController::muteChannel(QObject *modelObj,
                                                const QString &clipId,
                                                const QString &propId,
                                                bool mute) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.timelineModel)
    return;

  auto *clip = ctx.timelineModel->findClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findPropertyByPath(propId);
  if (!prop)
    return;

  prop->setIsMuted(mute);
  emit ctx.timelineModel->clipPropertiesChanged(clipId);
}

void KeyframeContextMenuController::lockChannel(QObject *modelObj,
                                                const QString &clipId,
                                                const QString &propId,
                                                bool lock) {
  auto ctx = resolveContext(modelObj);
  if (!ctx.timelineModel)
    return;

  auto *clip = ctx.timelineModel->findClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findPropertyByPath(propId);
  if (!prop)
    return;

  prop->setIsLocked(lock);
  emit ctx.timelineModel->clipPropertiesChanged(clipId);
}

} // namespace xyla::anim
