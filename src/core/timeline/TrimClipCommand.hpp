#pragma once

#include "core/timeline/timelineTrack.hpp"
#include "core/undo/xylaCommand.hpp"

namespace xyla {

class TrimClipCommand : public XylaCommand {
public:
  TrimClipCommand(TimelineTrack *track, QString clipId, FrameIndex oldStart,
                  FrameIndex newStart, FrameIndex oldDuration,
                  FrameIndex newDuration, FrameIndex oldSourceIn,
                  FrameIndex newSourceIn, bool isRipple = false)
      : m_track(track), m_clipId(std::move(clipId)), m_oldStart(oldStart),
        m_newStart(newStart), m_oldDuration(oldDuration),
        m_newDuration(newDuration), m_oldSourceIn(oldSourceIn),
        m_newSourceIn(newSourceIn), m_isRipple(isRipple) {}

  void redo() override {
    if (!m_track)
      return;
    auto *clip = m_track->findClip(m_clipId);
    if (!clip)
      return;

    FrameIndex deltaDuration = m_newDuration - clip->durationFrames();

    clip->setStartFrame(m_newStart);
    clip->setDurationFrames(m_newDuration);
    clip->setSourceInFrame(m_newSourceIn);

    if (m_isRipple && deltaDuration != 0) {
      m_track->rippleClipsFrom(m_oldStart + 1, deltaDuration, m_clipId);
    }
  }

  void undo() override {
    if (!m_track)
      return;
    auto *clip = m_track->findClip(m_clipId);
    if (!clip)
      return;

    FrameIndex deltaDuration = m_oldDuration - clip->durationFrames();

    clip->setStartFrame(m_oldStart);
    clip->setDurationFrames(m_oldDuration);
    clip->setSourceInFrame(m_oldSourceIn);

    if (m_isRipple && deltaDuration != 0) {
      m_track->rippleClipsFrom(m_oldStart + 1, deltaDuration, m_clipId);
    }
  }

  QString text() const override {
    return m_isRipple ? "Ripple Trim Clip" : "Trim Clip";
  }

  // Merges 60Hz mouse drag events into a SINGLE undo step
  bool mergeWith(const XylaCommand *other) override {
    const auto *next = dynamic_cast<const TrimClipCommand *>(other);
    if (!next || next->m_track != m_track || next->m_clipId != m_clipId ||
        next->m_isRipple != m_isRipple) {
      return false;
    }
    m_newStart = next->m_newStart;
    m_newDuration = next->m_newDuration;
    m_newSourceIn = next->m_newSourceIn;
    return true;
  }

private:
  TimelineTrack *m_track{nullptr};
  QString m_clipId;
  FrameIndex m_oldStart, m_newStart;
  FrameIndex m_oldDuration, m_newDuration;
  FrameIndex m_oldSourceIn, m_newSourceIn;
  bool m_isRipple{false};
};

} // namespace xyla
