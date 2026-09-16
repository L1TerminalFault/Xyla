#include "keyframeContextMenuController.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "ui/models/timelineModel.hpp"
#include <cmath>
#include <limits>
#include <unordered_set>

namespace xyla::anim {

namespace {
inline TimelineModel *resolveModel(QObject *obj) {
  return qobject_cast<TimelineModel *>(obj);
}
} // namespace

KeyframeContextMenuController::KeyframeContextMenuController(QObject *parent)
    : QObject(parent) {}

void KeyframeContextMenuController::copy(QObject *modelObj,
                                         const QVariantList &selectedKeys) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.isEmpty())
    return;

  m_clipboard.clear();
  int64_t minF = std::numeric_limits<int64_t>::max();
  int64_t maxF = std::numeric_limits<int64_t>::min();

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t absFrame = map.value("frame").toLongLong();

    auto *clip = model->findClip(clipId);
    if (!clip)
      continue;
    auto *prop = clip->findAnimProperty(propId);
    if (!prop)
      continue;

    const int64_t relFrame = absFrame - clip->getTiming().startFrame +
                             clip->getTiming().sourceInFrame;

    // Directly read from the clip property in C++
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
  auto *model = resolveModel(modelObj);
  if (model)
    executePaste(model, playheadFrame, MergeMode::Mix, true);
}

void KeyframeContextMenuController::pasteNoOffset(QObject *modelObj) {
  auto *model = resolveModel(modelObj);
  if (model)
    executePaste(model, 0, MergeMode::Mix, false);
}

void KeyframeContextMenuController::pasteOverwriteRange(QObject *modelObj,
                                                        int64_t playheadFrame) {
  auto *model = resolveModel(modelObj);
  if (model)
    executePaste(model, playheadFrame, MergeMode::OverwriteRange, true);
}

void KeyframeContextMenuController::pasteOverwriteAll(QObject *modelObj,
                                                      int64_t playheadFrame) {
  auto *model = resolveModel(modelObj);
  if (model)
    executePaste(model, playheadFrame, MergeMode::OverwriteAll, true);
}

void KeyframeContextMenuController::executePaste(TimelineModel *model,
                                                 int64_t playheadFrame,
                                                 MergeMode mode,
                                                 bool useOffset) {
  if (!model || m_clipboard.isEmpty())
    return;

  const int64_t offset =
      useOffset ? (playheadFrame - m_clipboard.earliestFrame) : 0;

  std::vector<PasteKeyframesCommand::KeyRecord> pastedRecords;
  std::vector<PasteKeyframesCommand::KeyRecord> overwrittenRecords;

  const int64_t spanMinAbs = m_clipboard.earliestFrame + offset;
  const int64_t spanMaxAbs = m_clipboard.latestFrame + offset;

  std::unordered_set<QString> clearedChannels;

  for (const auto &k : m_clipboard.keys) {
    auto *clip = model->findClip(k.clipId);
    if (!clip)
      continue;
    auto *prop = clip->findAnimProperty(k.propId);
    if (!prop)
      continue;

    const int64_t clipStart = clip->getTiming().startFrame;
    const int64_t srcIn = clip->getTiming().sourceInFrame;

    const int64_t targetAbsFrame = std::max<int64_t>(0, k.frame + offset);
    const int64_t targetRelFrame = targetAbsFrame - clipStart + srcIn;

    const QString channelKey = k.clipId + QLatin1Char('|') + k.propId;

    // 1. OverwriteAll: Clear and snapshot the entire curve
    if (mode == MergeMode::OverwriteAll) {
      if (clearedChannels.find(channelKey) == clearedChannels.end()) {
        clearedChannels.insert(channelKey);
        for (const auto &existing : prop->getKeyframes()) {
          overwrittenRecords.push_back({k.clipId, k.propId, existing.frame,
                                        existing.value, existing.interpolation,
                                        existing.bezier});
        }
      }
    }
    // 2. OverwriteRange: Clear and snapshot keys within [spanMin, spanMax]
    else if (mode == MergeMode::OverwriteRange) {
      if (clearedChannels.find(channelKey) == clearedChannels.end()) {
        clearedChannels.insert(channelKey);
        const int64_t minRel = spanMinAbs - clipStart + srcIn;
        const int64_t maxRel = spanMaxAbs - clipStart + srcIn;

        for (const auto &existing : prop->getKeyframes()) {
          if (existing.frame >= minRel && existing.frame <= maxRel) {
            overwrittenRecords.push_back(
                {k.clipId, k.propId, existing.frame, existing.value,
                 existing.interpolation, existing.bezier});
          }
        }
      }
    }
    // 3. Mix: Snapshot only if a key already exists at targetFrame
    else if (mode == MergeMode::Mix) {
      if (const auto *existing = prop->findKeyframe(targetRelFrame)) {
        overwrittenRecords.push_back({k.clipId, k.propId, targetRelFrame,
                                      existing->value, existing->interpolation,
                                      existing->bezier});
      }
    }

    anim::BezierHandles bezier;
    bezier.inX = k.inX;
    bezier.inY = k.inY;
    bezier.outX = k.outX;
    bezier.outY = k.outY;

    pastedRecords.push_back({k.clipId, k.propId, targetRelFrame, k.value,
                             static_cast<anim::Interpolation>(k.interpolation),
                             bezier});
  }

  if (pastedRecords.empty())
    return;

  if (auto *stack = model->undoStack()) {
    stack->push(std::make_unique<PasteKeyframesCommand>(
        model, std::move(pastedRecords), std::move(overwrittenRecords)));
  } else {
    auto cmd = std::make_unique<PasteKeyframesCommand>(
        model, std::move(pastedRecords), std::move(overwrittenRecords));
    cmd->redo();
  }
}

void KeyframeContextMenuController::setInterpolation(
    QObject *modelObj, const QVariantList &selectedKeys, int interpMode) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.isEmpty())
    return;

  for (const auto &item : selectedKeys) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t frame = map.value("frame").toLongLong();
    const float val = model->getClipEvaluatedProperty(clipId, propId, frame);

    model->updateKeyframe(clipId, propId, frame, frame, val, interpMode, 0.666f,
                          0.0f, 0.333f, 0.0f);
  }
}

void KeyframeContextMenuController::setHandleType(
    QObject *modelObj, const QVariantList &selectedKeys, int handleTypeInt) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.isEmpty())
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
    const float val = model->getClipEvaluatedProperty(clipId, propId, frame);

    model->updateKeyframe(clipId, propId, frame, frame, val, 2, inX, 0.0f, outX,
                          0.0f);
  }
}

void KeyframeContextMenuController::setEasing(QObject *modelObj,
                                              const QVariantList &selectedKeys,
                                              int easingTypeInt) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.isEmpty())
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
    const float val = model->getClipEvaluatedProperty(clipId, propId, frame);

    model->updateKeyframe(clipId, propId, frame, frame, val, 2, inX, inY, outX,
                          outY);
  }
}

void KeyframeContextMenuController::cleanKeys(QObject *modelObj,
                                              const QVariantList &selectedKeys,
                                              float tolerance) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.size() < 3)
    return;

  QVariantList redundantKeys;
  for (int i = 1; i < selectedKeys.size() - 1; ++i) {
    const auto prev = selectedKeys[i - 1].toMap();
    const auto curr = selectedKeys[i].toMap();
    const auto next = selectedKeys[i + 1].toMap();

    const float v0 = model->getClipEvaluatedProperty(
        prev["clipId"].toString(), prev["propId"].toString(),
        prev["frame"].toLongLong());
    const float v1 = model->getClipEvaluatedProperty(
        curr["clipId"].toString(), curr["propId"].toString(),
        curr["frame"].toLongLong());
    const float v2 = model->getClipEvaluatedProperty(
        next["clipId"].toString(), next["propId"].toString(),
        next["frame"].toLongLong());

    if (std::abs(v1 - v0) < tolerance && std::abs(v2 - v1) < tolerance) {
      redundantKeys.push_back(selectedKeys[i]);
    }
  }
  if (!redundantKeys.isEmpty()) {
    model->removeKeyframes(redundantKeys);
  }
}

void KeyframeContextMenuController::sampleKeys(
    QObject *modelObj, const QVariantList &selectedKeys) {
  auto *model = resolveModel(modelObj);
  if (!model || selectedKeys.size() < 2)
    return;

  const auto first = selectedKeys.front().toMap();
  const auto last = selectedKeys.back().toMap();
  const QString clipId = first["clipId"].toString();
  const QString propId = first["propId"].toString();
  const int64_t startF = first["frame"].toLongLong();
  const int64_t endF = last["frame"].toLongLong();

  for (int64_t f = startF; f <= endF; ++f) {
    const float val = model->getClipEvaluatedProperty(clipId, propId, f);
    model->updateKeyframe(clipId, propId, f, f, val, 1, 0.666f, 0.0f, 0.333f,
                          0.0f);
  }
}

void KeyframeContextMenuController::bakeCurve(QObject *modelObj,
                                              const QString &clipId,
                                              const QString &propId) {
  sampleKeys(modelObj, {});
}

void KeyframeContextMenuController::deleteKeys(
    QObject *modelObj, const QVariantList &selectedKeys) {
  auto *model = resolveModel(modelObj);
  if (model && !selectedKeys.isEmpty()) {
    model->removeKeyframes(selectedKeys);
  }
}

// TODO: finish set extrapolcation
void KeyframeContextMenuController::setExtrapolation(QObject *modelObj,
                                                     const QString &clipId,
                                                     const QString &propId,
                                                     int modeInt) {}

void KeyframeContextMenuController::muteChannel(QObject *modelObj,
                                                const QString &clipId,
                                                const QString &propId,
                                                bool mute) {
  auto *model = resolveModel(modelObj);
  if (!model)
    return;

  auto *clip = model->findClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propId);
  if (!prop)
    return;

  prop->setIsMuted(mute);
  emit model->clipPropertiesChanged(clipId);
}

void KeyframeContextMenuController::lockChannel(QObject *modelObj,
                                                const QString &clipId,
                                                const QString &propId,
                                                bool lock) {
  auto *model = resolveModel(modelObj);
  if (!model)
    return;

  auto *clip = model->findClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propId);
  if (!prop)
    return;

  prop->setIsLocked(lock);
  emit model->clipPropertiesChanged(clipId);
}
} // namespace xyla::anim
