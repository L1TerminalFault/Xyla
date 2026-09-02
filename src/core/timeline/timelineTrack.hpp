#pragma once

#include "timelineClip.hpp"
#include "timelineTypes.hpp"
#include <vector>

namespace xyla {

class TimelineTrack {
public:
  TimelineTrack(QString trackId, QString name, TrackKind kind)
      : m_trackId(std::move(trackId)), m_name(std::move(name)), m_kind(kind) {}

  [[nodiscard]] const QString &trackId() const noexcept { return m_trackId; }
  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  [[nodiscard]] TrackKind kind() const noexcept { return m_kind; }
  [[nodiscard]] const std::vector<TimelineClip> &clips() const noexcept {
    return m_clips;
  }
  [[nodiscard]] bool isMuted() const noexcept { return m_isMuted; }
  [[nodiscard]] bool
  hasCollision(FrameIndex startFrame, FrameIndex durationFrames,
               const QString &ignoreClipId = "") const noexcept;

  [[nodiscard]] FrameIndex
  clampPlacement(FrameIndex desiredStart, FrameIndex duration,
                 const QString &ignoreClipId = "") const noexcept;

  void shiftClipsFrom(FrameIndex fromFrame, int64_t deltaFrames,
                      const QString &ignoreClipId = "");

  [[nodiscard]] FrameIndex
  maxTrimDuration(FrameIndex startFrame, FrameIndex maxAvailableDuration,
                  const QString &ignoreClipId = "") const noexcept;

  void addClip(TimelineClip clip);
  bool removeClip(const QString &clipId);
  TimelineClip *findClip(const QString &clipId);

  // binary Search for playhead collision
  TimelineClip *findClipAtFrame(FrameIndex frame);

  void rippleClipsFrom(FrameIndex fromFrame, FrameIndex deltaFrames,
                       const QString &ignoreClipId = "");

  void sortClips();

private:
  QString m_trackId;
  QString m_name;
  TrackKind m_kind;
  std::vector<TimelineClip> m_clips;
  bool m_isMuted = false;
};

} // namespace xyla
