#include "timelineTrack.hpp"
#include <algorithm>
#include <limits>
#include <qjsonarray.h>
#include <qjsonobject.h>

namespace xyla {

void TimelineTrack::addClip(TimelineClip clip) {
  m_clips.push_back(std::move(clip));
  sortClips();
}

bool TimelineTrack::removeClip(const QString &clipId) {
  auto it = std::remove_if(
      m_clips.begin(), m_clips.end(),
      [&clipId](const TimelineClip &c) { return c.clipId() == clipId; });
  if (it != m_clips.end()) {
    m_clips.erase(it, m_clips.end());
    return true;
  }
  return false;
}

TimelineClip *TimelineTrack::findClip(const QString &clipId) {
  for (auto &c : m_clips) {
    if (c.clipId() == clipId)
      return &c;
  }
  return nullptr;
}

TimelineClip *TimelineTrack::findClipAtFrame(FrameIndex frame) {
  for (auto &c : m_clips) {
    if (frame >= c.startFrame() && frame < c.endFrame()) {
      return &c;
    }
  }
  return nullptr;
}

bool TimelineTrack::hasCollision(FrameIndex startFrame,
                                 FrameIndex durationFrames,
                                 const QString &ignoreClipId) const noexcept {
  FrameIndex endFrame = startFrame + durationFrames;
  for (const auto &c : m_clips) {
    if (c.clipId() == ignoreClipId)
      continue;
    if (startFrame < c.endFrame() && endFrame > c.startFrame()) {
      return true;
    }
  }
  return false;
}

FrameIndex
TimelineTrack::clampPlacement(FrameIndex desiredStart, FrameIndex duration,
                              const QString &ignoreClipId) const noexcept {
  desiredStart = std::max<FrameIndex>(0, desiredStart);
  FrameIndex desiredEnd = desiredStart + duration;

  FrameIndex minStart = 0;
  FrameIndex maxStart = std::numeric_limits<FrameIndex>::max();

  for (const auto &c : m_clips) {
    if (c.clipId() == ignoreClipId)
      continue;

    if (c.endFrame() <= desiredStart) {
      minStart = std::max(minStart, c.endFrame());
    } else if (c.startFrame() >= desiredEnd) {
      maxStart = std::min(maxStart, c.startFrame() - duration);
    } else {
      FrameIndex clipMid = desiredStart + (duration / 2);
      FrameIndex cMid = c.startFrame() + (c.durationFrames() / 2);
      if (clipMid < cMid) {
        maxStart = std::min(maxStart, c.startFrame() - duration);
      } else {
        minStart = std::max(minStart, c.endFrame());
      }
    }
  }

  if (minStart > maxStart) {
    return minStart;
  }

  return std::clamp(desiredStart, minStart, maxStart);
}

FrameIndex
TimelineTrack::maxTrimDuration(FrameIndex startFrame,
                               FrameIndex maxAvailableDuration,
                               const QString &ignoreClipId) const noexcept {
  FrameIndex maxDur = maxAvailableDuration;
  for (const auto &c : m_clips) {
    if (c.clipId() == ignoreClipId)
      continue;
    if (c.startFrame() >= startFrame) {
      maxDur = std::min(maxDur, c.startFrame() - startFrame);
    }
  }
  return std::max<FrameIndex>(1, maxDur);
}

void TimelineTrack::rippleClipsFrom(FrameIndex fromFrame,
                                    FrameIndex deltaFrames,
                                    const QString &ignoreClipId) {
  for (auto &c : m_clips) {
    if (c.clipId() == ignoreClipId)
      continue;
    if (c.startFrame() >= fromFrame) {
      c.setStartFrame(std::max<FrameIndex>(0, c.startFrame() + deltaFrames));
    }
  }
  sortClips();
}

void TimelineTrack::sortClips() {
  std::sort(m_clips.begin(), m_clips.end(),
            [](const TimelineClip &a, const TimelineClip &b) {
              return a.startFrame() < b.startFrame();
            });
}

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
  track->m_isMuted = obj.value("isMuted").toBool(false);
  track->m_isLocked = obj.value("isLocked").toBool(false);

  QJsonArray clipsArray = obj.value("clips").toArray();
  for (const auto &clipVal : clipsArray) {
    if (clipVal.isObject()) {
      track->addClip(TimelineClip::deserialize(clipVal.toObject()));
    }
  }

  track->sortClips();
  return track;
}

void TimelineTrack::shiftClipsFrom(FrameIndex fromFrame, int64_t deltaFrames,
                                   const QString &ignoreClipId) {
  for (auto &c : m_clips) {
    if (c.clipId() == ignoreClipId)
      continue;
    if (c.startFrame() >= fromFrame) {
      int64_t newStart = static_cast<int64_t>(c.startFrame()) + deltaFrames;
      c.setStartFrame(std::max<int64_t>(0, newStart));
    }
  }
  sortClips();
}
} // namespace xyla
