#include "core/animation/animChannel.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "ui/models/timelineModel.hpp"

namespace xyla {

bool TimelineModel::hasKeyframe(const QString &clipId,
                                const QString &propertyId,
                                int64_t frame) const {
  auto *clip = const_cast<TimelineModel *>(this)->resolveVideoClip(clipId);
  if (!clip)
    return false;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return false;

  const int64_t relFrame = frame - clip->startFrame() + clip->sourceInFrame();
  return prop->hasKeyframe(relFrame);
}

void TimelineModel::toggleKeyframe(const QString &clipId,
                                   const QString &propertyId, int64_t frame,
                                   const QVariant &currentValue) {
  auto *clip = resolveVideoClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return;

  const int64_t relFrame = frame - clip->startFrame() + clip->sourceInFrame();

  if (prop->hasKeyframe(relFrame)) {
    prop->removeKeyframe(relFrame);
  } else {
    prop->setKeyframe(relFrame, currentValue.toFloat());
  }

  emit clipPropertiesChanged(clipId);
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

void TimelineModel::removeKeyframe(const QString &clipId,
                                   const QString &propertyId, int64_t frame) {
  auto *clip = resolveVideoClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return;

  const int64_t relFrame = frame - clip->startFrame() + clip->sourceInFrame();
  prop->removeKeyframe(relFrame);

  emit clipPropertiesChanged(clipId);
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

void TimelineModel::moveKeyframe(const QString &clipId,
                                 const QString &propertyId, int64_t oldFrame,
                                 int64_t newFrame) {
  if (oldFrame == newFrame)
    return;

  auto *clip = resolveVideoClip(clipId);
  if (!clip)
    return;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return;

  const int64_t oldRel = oldFrame - clip->startFrame() + clip->sourceInFrame();
  const int64_t newRel = newFrame - clip->startFrame() + clip->sourceInFrame();

  if (!prop->moveKeyframe(oldRel, newRel))
    return;

  emit clipPropertiesChanged(clipId);
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

QVariantList TimelineModel::getClipAnimChannels(const QString &clipId,
                                                int64_t currentFrame) const {
  auto *clip = const_cast<TimelineModel *>(this)->resolveVideoClip(clipId);
  if (!clip)
    return {};

  // Determine track kind so we can filter categories
  TrackKind kind = TrackKind::Video;
  if (auto *track = getTrack(static_cast<size_t>(clip->trackIndex())))
    kind = track->kind();

  const int64_t clipStart = clip->startFrame();
  const int64_t srcIn = clip->sourceInFrame();
  const int64_t relFrame = currentFrame - clipStart + srcIn;

  // First pass: collect every descriptor that belongs to this track kind
  // and record which parents have at least one animated child.
  struct Entry {
    const anim::PropertyDescriptor *desc = nullptr;
    anim::AnimProperty *prop = nullptr;
    bool animated = false;
  };
  std::vector<Entry> entries;
  std::unordered_set<QString> animatedParents; // "group|parent"

  for (const auto &desc : anim::propertyRegistry()) {
    // Category filter
    if (kind == TrackKind::Video &&
        desc.category == anim::PropertyCategory::Audio)
      continue;
    if (kind == TrackKind::Audio &&
        desc.category != anim::PropertyCategory::Audio)
      continue;

    anim::AnimProperty *prop = desc.accessor ? desc.accessor(*clip) : nullptr;
    if (!prop)
      continue;

    const bool animated = prop->isAnimated();
    entries.push_back({&desc, prop, animated});

    if (animated && !desc.parent.isEmpty())
      animatedParents.insert(desc.group + QLatin1Char('|') + desc.parent);
  }

  // Second pass: emit a channel when it is animated OR when any sibling
  // under the same parent is animated.
  QVariantList result;
  for (const Entry &e : entries) {
    const bool show =
        e.animated || (!e.desc->parent.isEmpty() &&
                       animatedParents.count(e.desc->group + QLatin1Char('|') +
                                             e.desc->parent) > 0);

    if (!show)
      continue;

    anim::AnimChannelInfo info;
    info.id = e.desc->id;
    info.name = e.desc->name;
    info.group = e.desc->group;
    info.parent = e.desc->parent;
    info.color = e.desc->color;
    info.isAnimated = e.animated;

    for (int64_t kf : e.prop->keyframeFrames()) {
      const int64_t absFrame = kf - srcIn + clipStart;
      info.keyframeFrames.push_back(absFrame);
      if (kf == relFrame)
        info.hasKeyframeAtPlayhead = true;
    }

    result.append(info.toVariantMap());
  }

  return result;
}

float TimelineModel::getClipEvaluatedProperty(const QString &clipId,
                                              const QString &propertyId,
                                              int64_t frame) const {
  auto *clip = const_cast<TimelineModel *>(this)->findClip(clipId);
  if (!clip)
    return 0.0f;

  auto *prop = clip->findAnimProperty(propertyId);
  if (!prop)
    return 0.0f;

  const int64_t relFrame = frame - clip->startFrame() + clip->sourceInFrame();
  return prop->evaluate(relFrame);
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

    auto *clip = findClip(clipId);
    if (!clip)
      continue;
    auto *prop = clip->findAnimProperty(propId);
    if (!prop)
      continue;

    const int64_t relFrame =
        absFrame - clip->startFrame() + clip->sourceInFrame();

    // Use findKeyframe to snapshot the exact keyframe
    if (const auto *kf = prop->findKeyframe(relFrame)) {
      DeleteKeyframesCommand::KeyframeRecord rec;
      rec.clipId = clipId;
      rec.propId = propId;
      rec.absFrame = absFrame;
      rec.relFrame = relFrame;
      rec.value = kf->value;
      rec.interpolation = kf->interpolation;
      rec.bezier = kf->bezier;
      records.push_back(rec);
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
} // namespace xyla
