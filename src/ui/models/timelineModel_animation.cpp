#include "core/animation/animChannel.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "timelineModel.hpp"

#include <QDebug>
#include <algorithm>
#include <unordered_set>

namespace xyla {

// queries and resolvers

TimelineClip *
TimelineModel::resolveClipForProperty(const QString &clipId,
                                      const anim::PropertyDescriptor &desc) {
  auto *clip = findClip(clipId);
  if (!clip)
    return nullptr;

  const bool isAudioProp = (desc.category == anim::PropertyCategory::Audio);
  const int tIdx = clip->getTiming().trackIndex;
  auto *track = getTrack(tIdx);

  if (track) {
    const TrackKind k = track->getKind();
    if (isAudioProp && k == TrackKind::Audio)
      return clip;
    if (!isAudioProp && k == TrackKind::Video)
      return clip;
  }

  const QString &groupId = clip->getLinkGroupId();
  if (!groupId.isEmpty()) {
    for (const auto &t : m_tracks) {
      if (!t)
        continue;
      const TrackKind neededKind =
          isAudioProp ? TrackKind::Audio : TrackKind::Video;
      if (t->getKind() != neededKind)
        continue;

      for (const auto &c : t->getClips()) {
        if (c.getLinkGroupId() == groupId) {
          return findClip(c.getClipId());
        }
      }
    }
  }

  return nullptr;
}

// keyframe queries and mutations

bool TimelineModel::hasKeyframe(const QString &clipId,
                                const QString &propertyId,
                                int64_t frame) const {
  const auto *desc = anim::findPropertyDescriptor(propertyId);
  if (!desc)
    return false;

  auto *clip =
      const_cast<TimelineModel *>(this)->resolveClipForProperty(clipId, *desc);
  if (!clip)
    return false;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return false;

  const FrameIndex localFrame = clip->getTiming().timelineToLocalFrame(frame);
  return prop->hasKeyframe(localFrame);
}

void TimelineModel::toggleKeyframe(const QString &clipId,
                                   const QString &propertyId, int64_t frame,
                                   const QVariant &currentValue) {
  const auto *desc = anim::findPropertyDescriptor(propertyId);
  if (!desc)
    return;

  auto *clip = resolveClipForProperty(clipId, *desc);
  if (!clip)
    return;

  const FrameIndex localFrame = clip->getTiming().timelineToLocalFrame(frame);
  const float val = currentValue.toFloat();

  auto toggleOnProp = [&](anim::AnimProperty *p) {
    if (!p)
      return;
    if (p->hasKeyframe(localFrame)) {
      p->removeKeyframe(localFrame);
    } else {
      p->setKeyframe(localFrame, val);
    }
  };

  if (propertyId == "scale" ||
      (clip->getIsUniformScale() &&
       (propertyId == "scaleX" || propertyId == "scaleY"))) {
    toggleOnProp(&clip->getTransform().scaleX);
    toggleOnProp(&clip->getTransform().scaleY);
  } else {
    toggleOnProp(clip->findAnimProperty(propertyId));
  }

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

void TimelineModel::removeKeyframe(const QString &clipId,
                                   const QString &propertyId, int64_t frame) {
  const auto *desc = anim::findPropertyDescriptor(propertyId);
  auto *clip = desc ? resolveClipForProperty(clipId, *desc) : findClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return;

  const FrameIndex localFrame = clip->getTiming().timelineToLocalFrame(frame);
  prop->removeKeyframe(localFrame);

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

void TimelineModel::moveKeyframes(const QVariantList &keyframeList,
                                  int64_t deltaFrames) {
  if (keyframeList.isEmpty() || deltaFrames == 0) {
    return;
  }

  std::vector<MoveKeyframesCommand::MoveRecord> records;

  for (const auto &item : keyframeList) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t oldAbs = map.value("frame").toLongLong();
    const int64_t newAbs = std::max<int64_t>(0, oldAbs + deltaFrames);

    if (oldAbs == newAbs)
      continue;

    const auto *desc = anim::findPropertyDescriptor(propId);
    auto *clip =
        desc ? resolveClipForProperty(clipId, *desc) : findClip(clipId);
    if (!clip)
      continue;

    const int64_t oldRel = clip->getTiming().timelineToLocalFrame(oldAbs);
    const int64_t newRel = clip->getTiming().timelineToLocalFrame(newAbs);

    // Summary diamond moved -> move all animated properties at that frame
    if (propId.isEmpty()) {
      for (const auto &d : anim::propertyRegistry()) {
        auto *p = d.accessor ? d.accessor(*clip) : nullptr;
        if (!p || !p->getIsAnimated())
          continue;

        if (p->hasKeyframe(oldRel)) {
          records.push_back(
              {clip->getClipId(), d.id, oldAbs, newAbs, oldRel, newRel});
        }
      }
      continue;
    }

    auto *prop = clip->findAnimProperty(propId);
    if (!prop)
      continue;

    if (prop->hasKeyframe(oldRel)) {
      records.push_back(
          {clip->getClipId(), propId, oldAbs, newAbs, oldRel, newRel});
    }
  }

  if (records.empty())
    return;

  if (m_undoStack) {
    m_undoStack->push(
        std::make_unique<MoveKeyframesCommand>(this, std::move(records)));
  } else {
    auto cmd = std::make_unique<MoveKeyframesCommand>(this, std::move(records));
    cmd->redo();
  }
}

void TimelineModel::moveKeyframe(const QString &clipId,
                                 const QString &propertyId, int64_t oldFrame,
                                 int64_t newFrame) {
  if (oldFrame == newFrame)
    return;

  QVariantMap map;
  map["clipId"] = clipId;
  map["propId"] = propertyId;
  map["frame"] = static_cast<qlonglong>(oldFrame);

  moveKeyframes({map}, newFrame - oldFrame);
}

// animation channels inspection

QVariantList TimelineModel::getClipAnimChannels(const QString &clipId,
                                                int64_t currentFrame) const {
  auto *primaryClip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!primaryClip)
    return {};

  std::vector<TimelineClip *> contextClips;
  contextClips.push_back(primaryClip);

  // Collect linked audio/video companions
  if (!primaryClip->getLinkGroupId().isEmpty()) {
    for (const auto &track : m_tracks) {
      if (!track)
        continue;
      for (const auto &c : track->getClips()) {
        if (c.getLinkGroupId() == primaryClip->getLinkGroupId() &&
            c.getClipId() != primaryClip->getClipId()) {
          if (auto *companion =
                  const_cast<TimelineModel *>(this)->findClip(c.getClipId())) {
            contextClips.push_back(companion);
          }
        }
      }
    }
  }

  QVariantList result;

  for (auto *clip : contextClips) {
    TrackKind kind = TrackKind::Video;
    if (auto *track = getTrack(clip->getTiming().trackIndex)) {
      kind = track->getKind();
    }

    const int64_t clipStart = clip->getTiming().startFrame;
    const int64_t relFrame =
        clip->getTiming().timelineToLocalFrame(currentFrame);

    struct Entry {
      const anim::PropertyDescriptor *desc = nullptr;
      anim::AnimProperty *prop = nullptr;
      bool animated = false;
      bool isUnifiedScale = false;
    };
    std::vector<Entry> entries;
    std::unordered_set<QString> animatedParents;

    for (const auto &desc : anim::propertyRegistry()) {
      if (kind == TrackKind::Video &&
          desc.category == anim::PropertyCategory::Audio)
        continue;
      if (kind == TrackKind::Audio &&
          desc.category != anim::PropertyCategory::Audio)
        continue;

      if (clip->getIsUniformScale()) {
        if (desc.id == "scaleY" || desc.id == "scale")
          continue;
      } else {
        if (desc.id == "scale")
          continue;
      }

      anim::AnimProperty *prop = desc.accessor ? desc.accessor(*clip) : nullptr;
      if (!prop)
        continue;

      const bool animated = prop->getIsAnimated();
      const bool isUnified = clip->getIsUniformScale() && (desc.id == "scaleX");

      entries.push_back({&desc, prop, animated, isUnified});

      if (animated && !desc.parent.isEmpty() && !isUnified) {
        animatedParents.insert(desc.group + QLatin1Char('|') + desc.parent);
      }
    }

    for (const Entry &e : entries) {
      const bool show =
          e.animated || e.isUnifiedScale ||
          (!e.desc->parent.isEmpty() &&
           animatedParents.count(e.desc->group + QLatin1Char('|') +
                                 e.desc->parent) > 0);
      if (!show)
        continue;

      anim::AnimChannelInfo info;
      info.clipId = clip->getClipId();

      if (e.isUnifiedScale) {
        info.id = QStringLiteral("scale");
        info.name = QStringLiteral("Scale");
        info.group = QStringLiteral("Transform");
        info.parent = QString();
        info.color = e.desc->color;
      } else {
        info.id = e.desc->id;
        info.name = e.desc->name;
        info.group = e.desc->group;
        info.parent = e.desc->parent;
        info.color = e.desc->color;
      }

      info.isAnimated = e.animated;

      for (const auto &k : e.prop->getKeyframes()) {
        const int64_t absFrame = k.frame + clipStart;
        info.keyframeFrames.push_back(absFrame);
        if (k.frame == relFrame) {
          info.hasKeyframeAtPlayhead = true;
        }

        anim::KeyframeDetail det;
        det.frame = absFrame;
        det.value = k.value;
        det.interpolation = static_cast<int>(k.interpolation);
        det.inX = k.bezier.inX;
        det.inY = k.bezier.inY;
        det.outX = k.bezier.outX;
        det.outY = k.bezier.outY;
        info.details.push_back(det);
      }

      QVariantMap channelMap = info.toVariantMap();
      channelMap[QStringLiteral("isMuted")] = e.prop->getIsMuted();
      channelMap[QStringLiteral("isLocked")] = e.prop->getIsLocked();
      channelMap[QStringLiteral("currentValue")] =
          static_cast<double>(e.prop->evaluate(relFrame));
      channelMap[QStringLiteral("staticValue")] =
          static_cast<double>(e.prop->getStaticValue());

      result.append(std::move(channelMap));
    }
  }

  return result;
}

float TimelineModel::getClipEvaluatedProperty(const QString &clipId,
                                              const QString &propertyId,
                                              int64_t frame) const {
  const auto *desc = anim::findPropertyDescriptor(propertyId);
  auto *clip = desc ? const_cast<TimelineModel *>(this)->resolveClipForProperty(
                          clipId, *desc)
                    : const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip)
    return 0.0f;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return 0.0f;

  const FrameIndex localFrame = clip->getTiming().timelineToLocalFrame(frame);
  return prop->evaluate(localFrame);
}

void TimelineModel::removeKeyframes(const QVariantList &keyframeList) {
  if (keyframeList.isEmpty())
    return;

  std::vector<DeleteKeyframesCommand::KeyframeRecord> records;

  for (const auto &item : keyframeList) {
    const QVariantMap map = item.toMap();
    const QString clipId = map.value("clipId").toString();
    const QString propId = map.value("propId").toString();
    const int64_t absFrame = map.value("frame").toLongLong();

    const auto *desc = anim::findPropertyDescriptor(propId);
    auto *clip =
        desc ? resolveClipForProperty(clipId, *desc) : findClip(clipId);
    if (!clip)
      clip = resolveVideoClip(clipId);
    if (!clip)
      continue;

    const FrameIndex relFrame =
        clip->getTiming().timelineToLocalFrame(absFrame);

    if (propId.isEmpty()) {
      for (const auto &d : anim::propertyRegistry()) {
        auto *p = d.accessor ? d.accessor(*clip) : nullptr;
        if (!p || !p->getIsAnimated())
          continue;

        if (const auto *kf = p->findKeyframe(relFrame)) {
          records.push_back({clip->getClipId(), d.id, absFrame, relFrame,
                             kf->value, kf->interpolation, kf->bezier});
        }
      }
      continue;
    }

    auto *prop = clip->findAnimProperty(propId);
    if (!prop)
      continue;

    if (const auto *kf = prop->findKeyframe(relFrame)) {
      records.push_back({clip->getClipId(), propId, absFrame, relFrame,
                         kf->value, kf->interpolation, kf->bezier});
    }
  }

  if (records.empty())
    return;

  if (m_undoStack) {
    m_undoStack->push(
        std::make_unique<DeleteKeyframesCommand>(this, std::move(records)));
  } else {
    auto cmd =
        std::make_unique<DeleteKeyframesCommand>(this, std::move(records));
    cmd->redo();
  }
}

void TimelineModel::updateKeyframe(const QString &clipId,
                                   const QString &propertyId, int64_t oldFrame,
                                   int64_t newFrame, float newValue, int interp,
                                   float inX, float inY, float outX,
                                   float outY) {
  const auto *desc = anim::findPropertyDescriptor(propertyId);
  auto *clip = desc ? resolveClipForProperty(clipId, *desc) : findClip(clipId);
  if (!clip)
    return;

  const FrameIndex oldRel = clip->getTiming().timelineToLocalFrame(oldFrame);
  const FrameIndex newRel = clip->getTiming().timelineToLocalFrame(newFrame);

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop && propertyId == "scale") {
    prop = &clip->getTransform().scaleX;
  }
  if (!prop)
    return;

  const auto *existingKf = prop->findKeyframe(oldRel);
  if (!existingKf)
    return;

  UpdateKeyframeCommand::KeyframeState oldState{.relFrame = oldRel,
                                                .value = existingKf->value,
                                                .interpolation =
                                                    existingKf->interpolation,
                                                .bezier = existingKf->bezier};

  anim::Interpolation it = (interp >= 0)
                               ? static_cast<anim::Interpolation>(interp)
                               : existingKf->interpolation;
  anim::BezierHandles bz{.outX = outX, .outY = outY, .inX = inX, .inY = inY};

  UpdateKeyframeCommand::KeyframeState newState{
      .relFrame = newRel, .value = newValue, .interpolation = it, .bezier = bz};

  if (oldState.relFrame == newState.relFrame &&
      qFuzzyCompare(oldState.value, newState.value) &&
      oldState.interpolation == newState.interpolation &&
      qFuzzyCompare(oldState.bezier.inX, newState.bezier.inX) &&
      qFuzzyCompare(oldState.bezier.inY, newState.bezier.inY) &&
      qFuzzyCompare(oldState.bezier.outX, newState.bezier.outX) &&
      qFuzzyCompare(oldState.bezier.outY, newState.bezier.outY)) {
    return;
  }

  std::vector<UpdateKeyframeCommand::Record> records;
  const bool isScaleLocked =
      (propertyId == "scale") ||
      (clip->getIsUniformScale() &&
       (propertyId == "scaleX" || propertyId == "scaleY"));

  if (isScaleLocked) {
    records.push_back({clip->getClipId(), "scaleX", oldState, newState});
    records.push_back({clip->getClipId(), "scaleY", oldState, newState});
  } else {
    records.push_back({clip->getClipId(), propertyId, oldState, newState});
  }

  QString descText =
      (oldRel == newRel && qFuzzyCompare(oldState.value, newState.value))
          ? "Adjust Bezier Handles"
          : "Edit Keyframe";

  if (m_undoStack) {
    m_undoStack->push(std::make_unique<UpdateKeyframeCommand>(
        this, std::move(records), descText));
  } else {
    auto cmd = std::make_unique<UpdateKeyframeCommand>(this, std::move(records),
                                                       descText);
    cmd->redo();
  }
}

void TimelineModel::pasteKeyframes(
    const std::vector<anim::ClipboardKeyframe> &keys, int64_t offset,
    anim::MergeMode mode) {
  if (keys.empty())
    return;

  std::vector<PasteKeyframesCommand::KeyRecord> pastedRecords;
  std::vector<PasteKeyframesCommand::KeyRecord> overwrittenRecords;

  for (const auto &k : keys) {
    const auto *desc = anim::findPropertyDescriptor(k.propId);
    auto *clip =
        desc ? resolveClipForProperty(k.clipId, *desc) : findClip(k.clipId);
    if (!clip)
      continue;

    auto *prop = clip->findAnimProperty(k.propId);
    if (!prop)
      continue;

    const int64_t targetAbsFrame = std::max<int64_t>(0, k.frame + offset);
    const FrameIndex targetRelFrame =
        clip->getTiming().timelineToLocalFrame(targetAbsFrame);

    if (mode == anim::MergeMode::OverwriteAll) {
      for (const auto &existing : prop->getKeyframes()) {
        overwrittenRecords.push_back({clip->getClipId(), k.propId,
                                      existing.frame, existing.value,
                                      existing.interpolation, existing.bezier});
      }
    } else {
      if (const auto *existing = prop->findKeyframe(targetRelFrame)) {
        overwrittenRecords.push_back(
            {clip->getClipId(), k.propId, targetRelFrame, existing->value,
             existing->interpolation, existing->bezier});
      }
    }

    anim::BezierHandles bezier{
        .outX = k.outX, .outY = k.outY, .inX = k.inX, .inY = k.inY};
    pastedRecords.push_back(
        {clip->getClipId(), k.propId, targetRelFrame, k.value,
         static_cast<anim::Interpolation>(k.interpolation), bezier});
  }

  if (pastedRecords.empty())
    return;

  if (m_undoStack) {
    m_undoStack->push(std::make_unique<PasteKeyframesCommand>(
        this, std::move(pastedRecords), std::move(overwrittenRecords)));
  } else {
    auto cmd = std::make_unique<PasteKeyframesCommand>(
        this, std::move(pastedRecords), std::move(overwrittenRecords));
    cmd->redo();
  }
}

void TimelineModel::setClipUniformScale(const QString &clipId, bool uniform) {
  auto *clip = resolveVideoClip(clipId);
  if (!clip)
    clip = findClip(clipId);
  if (!clip || clip->getIsUniformScale() == uniform)
    return;

  clip->setIsUniformScale(uniform);

  if (uniform) {
    clip->getTransform().scaleY = clip->getTransform().scaleX;
  }

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

} // namespace xyla
