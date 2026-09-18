#include "timelineTrack.hpp"
#include "core/log/logger.hpp"

#include <QJsonArray>
#include <algorithm>
#include <format>

namespace xyla {

// construction and lifecycle

TimelineTrack::TimelineTrack(QString trackId, QString name, TrackKind kind)
    : m_trackId(std::move(trackId)), m_name(std::move(name)), m_kind(kind) {
  if (m_trackId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineTrack",
                   "TimelineTrack created with an empty trackId!");
  }
}

// serialization

QJsonObject TimelineTrack::serialize() const {
  QJsonObject obj;
  obj["trackId"] = m_trackId;
  obj["name"] = m_name;
  obj["kind"] = static_cast<int>(m_kind);
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;

  QJsonArray clipsArray;
  for (const auto &clip : m_clips) {
    clipsArray.append(clip.serialize());
  }
  obj["clips"] = clipsArray;

  return obj;
}

std::shared_ptr<TimelineTrack>
TimelineTrack::deserialize(const QJsonObject &obj) {
  QString trackId = obj.value("trackId").toString();
  QString name = obj.value("name").toString();
  TrackKind kind = static_cast<TrackKind>(obj.value("kind").toInt(0));

  auto track = std::make_shared<TimelineTrack>(trackId, name, kind);
  track->setIsMuted(obj.value("isMuted").toBool(false));
  track->setIsLocked(obj.value("isLocked").toBool(false));

  QJsonArray clipsArray = obj.value("clips").toArray();
  for (const auto &clipVal : clipsArray) {
    if (clipVal.isObject()) {
      track->insertClip(TimelineClip::deserialize(clipVal.toObject()));
    }
  }

  return track;
}

// identity and state

const QString &TimelineTrack::getTrackId() const noexcept { return m_trackId; }

const QString &TimelineTrack::getName() const noexcept { return m_name; }

void TimelineTrack::setName(QString name) {
  if (name.trimmed().isEmpty()) {
    XYLA_LOG_WARN("TimelineTrack", "setName called with empty string.");
    return;
  }
  m_name = std::move(name);
}

TrackKind TimelineTrack::getKind() const noexcept { return m_kind; }

bool TimelineTrack::getIsLocked() const noexcept { return m_isLocked; }
void TimelineTrack::setIsLocked(bool locked) noexcept { m_isLocked = locked; }

bool TimelineTrack::getIsMuted() const noexcept { return m_isMuted; }
void TimelineTrack::setIsMuted(bool muted) noexcept { m_isMuted = muted; }

bool TimelineTrack::getIsSelected() const noexcept { return m_isSelected; }
void TimelineTrack::setIsSelected(bool selected) noexcept {
  m_isSelected = selected;
}

// clip queries

const std::vector<TimelineClip> &TimelineTrack::getClips() const noexcept {
  return m_clips;
}

size_t TimelineTrack::getClipCount() const noexcept { return m_clips.size(); }

bool TimelineTrack::isEmpty() const noexcept { return m_clips.empty(); }

bool TimelineTrack::hasCollision(const ClipTiming &timing,
                                 const QString &ignoreClipId) const noexcept {
  FrameIndex startFrame = timing.startFrame;
  FrameIndex endFrame = timing.endFrame();

  for (const auto &c : m_clips) {
    if (c.getClipId() == ignoreClipId) {
      continue;
    }
    if (startFrame < c.getTiming().endFrame() &&
        endFrame > c.getTiming().startFrame) {
      return true;
    }
  }
  return false;
}

const TimelineClip *
TimelineTrack::findClip(const QString &clipId) const noexcept {
  for (const auto &c : m_clips) {
    if (c.getClipId() == clipId) {
      return &c;
    }
  }
  return nullptr;
}

TimelineClip *TimelineTrack::findClip(const QString &clipId) noexcept {
  for (auto &c : m_clips) {
    if (c.getClipId() == clipId) {
      return &c;
    }
  }
  return nullptr;
}

const TimelineClip *
TimelineTrack::findClipAtFrame(FrameIndex frame) const noexcept {
  if (m_clips.empty()) {
    return nullptr;
  }

  // Binary search for O(log N) lookup
  auto it = std::upper_bound(m_clips.begin(), m_clips.end(), frame,
                             [](FrameIndex f, const TimelineClip &c) {
                               return f < c.getTiming().startFrame;
                             });

  if (it != m_clips.begin()) {
    --it;
    if (frame >= it->getTiming().startFrame &&
        frame < it->getTiming().endFrame()) {
      return &(*it);
    }
  }
  return nullptr;
}

TimelineClip *TimelineTrack::findClipAtFrame(FrameIndex frame) noexcept {
  return const_cast<TimelineClip *>(
      static_cast<const TimelineTrack *>(this)->findClipAtFrame(frame));
}

// track editing actions

bool TimelineTrack::insertClip(TimelineClip clip) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "insertClip rejected: track is locked.");
    return false;
  }

  if (hasCollision(clip.getTiming(), clip.getClipId())) {
    XYLA_LOG_WARN(
        "TimelineTrack",
        std::format("insertClip failed: collision detected at frame {}.",
                    clip.getTiming().startFrame));
    return false;
  }

  // Insert in sorted position O(log N + N) to maintain strict invariant
  auto it = std::upper_bound(m_clips.begin(), m_clips.end(),
                             clip.getTiming().startFrame,
                             [](FrameIndex start, const TimelineClip &c) {
                               return start < c.getTiming().startFrame;
                             });

  m_clips.insert(it, std::move(clip));
  return true;
}

bool TimelineTrack::removeClip(const QString &clipId) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "removeClip rejected: track is locked.");
    return false;
  }

  auto it =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == clipId;
      });

  if (it != m_clips.end()) {
    m_clips.erase(it);
    return true;
  }

  return false;
}

bool TimelineTrack::splitClip(const QString &clipId, FrameIndex cutFrame,
                              const QString &newRightId) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "splitClip rejected: track is locked.");
    return false;
  }

  auto it =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == clipId;
      });

  if (it == m_clips.end()) {
    XYLA_LOG_ERROR("TimelineTrack",
                   std::format("splitClip failed: clip '{}' not found.",
                               clipId.toStdString()));
    return false;
  }

  if (cutFrame <= it->getTiming().startFrame ||
      cutFrame >= it->getTiming().endFrame()) {
    XYLA_LOG_ERROR(
        "TimelineTrack",
        std::format("splitClip failed: cutFrame {} out of range [{}, {}).",
                    cutFrame, it->getTiming().startFrame,
                    it->getTiming().endFrame()));
    return false;
  }

  TimelineClip rightHalf = it->split(newRightId, cutFrame);

  m_clips.insert(it + 1, std::move(rightHalf));
  return true;
}

std::vector<FrameIndex>
TimelineTrack::getEdgeFrames(const QString &ignoreClipId) const {
  std::vector<FrameIndex> edges;
  edges.reserve(m_clips.size() * 2);

  for (const auto &c : m_clips) {
    if (c.getClipId() == ignoreClipId) {
      continue;
    }
    edges.push_back(c.getTiming().startFrame);
    edges.push_back(c.getTiming().endFrame());
  }
  return edges;
}

FrameIndex
TimelineTrack::resolveInsertFrame(FrameIndex dropFrame,
                                  FrameIndex clipDuration) const noexcept {
  dropFrame = std::max<FrameIndex>(0, dropFrame);

  if (const auto *hovered = findClipAtFrame(dropFrame)) {
    FrameIndex hStart = hovered->getTiming().startFrame;
    FrameIndex hEnd = hovered->getTiming().endFrame();
    FrameIndex hMid = hStart + ((hEnd - hStart) / 2);

    if (dropFrame < hMid) {
      return hStart;
    } else {
      return hEnd;
    }
  }

  return dropFrame;
}

// track editing actions

bool TimelineTrack::uncutClips(const QString &leftClipId,
                               const QString &rightClipId) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "uncutClips rejected: track is locked.");
    return false;
  }

  auto leftIt =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == leftClipId;
      });
  auto rightIt =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == rightClipId;
      });

  if (leftIt == m_clips.end() || rightIt == m_clips.end()) {
    XYLA_LOG_ERROR("TimelineTrack",
                   "uncutClips failed: one or both clips not found on track.");
    return false;
  }

  // Delegate contiguous math to TimelineClip
  if (!leftIt->uncut(*rightIt)) {
    return false;
  }

  // Erase the right-hand clip since it has been absorbed
  m_clips.erase(rightIt);
  return true;
}

bool TimelineTrack::moveClip(const QString &clipId, FrameIndex newStartFrame) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "moveClip rejected: track is locked.");
    return false;
  }

  auto *clip = findClip(clipId);
  if (!clip) {
    XYLA_LOG_ERROR("TimelineTrack",
                   std::format("moveClip failed: clip '{}' not found.",
                               clipId.toStdString()));
    return false;
  }

  ClipTiming newTiming = clip->getTiming();
  newTiming.startFrame = std::max<FrameIndex>(0, newStartFrame);

  if (hasCollision(newTiming, clipId)) {
    XYLA_LOG_WARN(
        "TimelineTrack",
        std::format("moveClip failed: collision at frame {}.", newStartFrame));
    return false;
  }

  clip->setTiming(newTiming);
  sortClipsInternal();
  return true;
}

bool TimelineTrack::transferClipTo(const QString &clipId,
                                   TimelineTrack &dstTrack,
                                   FrameIndex newStartFrame,
                                   int dstTrackIndex) { // <-- Added parameter
  if (m_isLocked || dstTrack.getIsLocked()) {
    XYLA_LOG_WARN(
        "TimelineTrack",
        "transferClipTo rejected: source or destination track is locked.");
    return false;
  }

  auto it =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == clipId;
      });

  if (it == m_clips.end()) {
    XYLA_LOG_ERROR(
        "TimelineTrack",
        std::format(
            "transferClipTo failed: clip '{}' not found on source track.",
            clipId.toStdString()));
    return false;
  }

  TimelineClip movingClip = *it;
  ClipTiming newTiming = movingClip.getTiming();
  newTiming.startFrame = std::max<FrameIndex>(0, newStartFrame);

  newTiming.trackIndex = dstTrackIndex; 

  movingClip.setTiming(newTiming);

  // Validate placement on destination track
  if (dstTrack.hasCollision(movingClip.getTiming())) {
    XYLA_LOG_WARN("TimelineTrack",
                  std::format("transferClipTo failed: collision on destination "
                              "track at frame {}.",
                              newStartFrame));
    return false;
  }

  // Remove from this track and insert into destination
  m_clips.erase(it);
  dstTrack.insertClip(std::move(movingClip));
  return true;
}

bool TimelineTrack::trimClip(const QString &clipId, FrameIndex newStart,
                             FrameIndex newDuration, FrameIndex newSourceIn) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack", "trimClip rejected: track is locked.");
    return false;
  }

  auto *clip = findClip(clipId);
  if (!clip) {
    XYLA_LOG_ERROR("TimelineTrack",
                   std::format("trimClip failed: clip '{}' not found.",
                               clipId.toStdString()));
    return false;
  }

  ClipTiming targetTiming{
      .startFrame = std::max<FrameIndex>(0, newStart),
      .durationFrames = std::max<FrameIndex>(1, newDuration),
      .sourceInFrame = std::max<FrameIndex>(0, newSourceIn),
      .trackIndex = clip->getTiming().trackIndex,
      .speed = clip->getTiming().speed,
  };

  if (hasCollision(targetTiming, clipId)) {
    XYLA_LOG_WARN(
        "TimelineTrack",
        std::format("trimClip failed: collision detected for clip '{}'.",
                    clipId.toStdString()));
    return false;
  }

  clip->setTiming(targetTiming);
  sortClipsInternal();
  return true;
}

bool TimelineTrack::rippleDeleteClip(const QString &clipId) {
  if (m_isLocked) {
    XYLA_LOG_WARN("TimelineTrack",
                  "rippleDeleteClip rejected: track is locked.");
    return false;
  }

  auto it =
      std::find_if(m_clips.begin(), m_clips.end(), [&](const TimelineClip &c) {
        return c.getClipId() == clipId;
      });

  if (it == m_clips.end()) {
    return false;
  }

  FrameIndex deletedStart = it->getTiming().startFrame;
  int64_t deletedDuration = it->getTiming().durationFrames;

  // Erase the target clip
  m_clips.erase(it);

  // Pull all subsequent clips to the left
  shiftClipsAfter(deletedStart, -deletedDuration);
  return true;
}

void TimelineTrack::shiftClipsAfter(FrameIndex fromFrame, int64_t deltaFrames,
                                    const QString &ignoreClipId) {
  if (deltaFrames == 0) {
    return;
  }

  for (auto &c : m_clips) {
    if (c.getClipId() == ignoreClipId) {
      continue;
    }
    if (c.getTiming().startFrame >= fromFrame) {
      ClipTiming timing = c.getTiming();
      int64_t newStart = static_cast<int64_t>(timing.startFrame) + deltaFrames;
      timing.startFrame =
          std::max<FrameIndex>(0, static_cast<FrameIndex>(newStart));
      c.setTiming(timing);
    }
  }

  sortClipsInternal();
}

void TimelineTrack::sortClipsInternal() noexcept {
  std::sort(m_clips.begin(), m_clips.end(),
            [](const TimelineClip &a, const TimelineClip &b) {
              return a.getTiming().startFrame < b.getTiming().startFrame;
            });
}

void TimelineTrack::setClips(std::vector<TimelineClip> clips) {
  m_clips = std::move(clips);
  sortClipsInternal();
}
} // namespace xyla
