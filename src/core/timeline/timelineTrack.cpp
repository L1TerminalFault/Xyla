#include "timelineTrack.hpp"
#include <algorithm>

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
  auto it = std::lower_bound(
      m_clips.begin(), m_clips.end(), frame,
      [](const TimelineClip &c, FrameIndex f) { return c.endFrame() <= f; });

  if (it != m_clips.end() && frame >= it->startFrame() &&
      frame < it->endFrame()) {
    return &(*it);
  }
  return nullptr;
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

} // namespace xyla
