#pragma once

#include "timelineClip.hpp"
#include "timelineTypes.hpp"
#include <QJsonObject>
#include <memory>
#include <vector>

namespace xyla {

class TimelineTrack {
public:
  // construction and lifecycle
  TimelineTrack(QString trackId, QString name, TrackKind kind);

  // serialization
  [[nodiscard]] QJsonObject serialize() const;
  static std::shared_ptr<TimelineTrack> deserialize(const QJsonObject &obj);

  // identity and state
  [[nodiscard]] const QString &getTrackId() const noexcept;
  [[nodiscard]] const QString &getName() const noexcept;
  void setName(QString name);

  [[nodiscard]] TrackKind getKind() const noexcept;
  [[nodiscard]] bool getIsLocked() const noexcept;
  void setIsLocked(bool locked) noexcept;
  [[nodiscard]] bool getIsMuted() const noexcept;
  void setIsMuted(bool muted) noexcept;
  [[nodiscard]] bool getIsSelected() const noexcept;
  void setIsSelected(bool selected) noexcept;

  // clip queries (const and safe)
  [[nodiscard]] const std::vector<TimelineClip> &getClips() const noexcept;
  [[nodiscard]] size_t getClipCount() const noexcept;
  [[nodiscard]] bool isEmpty() const noexcept;

  [[nodiscard]] bool
  hasCollision(const ClipTiming &timing,
               const QString &ignoreClipId = "") const noexcept;
  [[nodiscard]] const TimelineClip *
  findClip(const QString &clipId) const noexcept;
  [[nodiscard]] TimelineClip *findClip(const QString &clipId) noexcept;

  [[nodiscard]] const TimelineClip *
  findClipAtFrame(FrameIndex frame) const noexcept;
  [[nodiscard]] TimelineClip *findClipAtFrame(FrameIndex frame) noexcept;

  // track editing actions (self-sorting and invariant safe)
  bool insertClip(TimelineClip clip);
  bool removeClip(const QString &clipId);
  bool splitClip(const QString &clipId, FrameIndex cutFrame,
                 const QString &newRightId);
  bool uncutClips(const QString &leftClipId, const QString &rightClipId);

  bool rippleDeleteClip(const QString &clipId);

  void shiftClipsAfter(FrameIndex fromFrame, int64_t deltaFrames,
                       const QString &ignoreClipId = "");
  bool moveClip(const QString &clipId, FrameIndex newStartFrame);
  bool transferClipTo(const QString &clipId, TimelineTrack &dstTrack,
                      FrameIndex newStartFrame);

  bool trimClip(const QString &clipId, FrameIndex newStart,
                FrameIndex newDuration, FrameIndex newSourceIn);

  [[nodiscard]] std::vector<FrameIndex>
  getEdgeFrames(const QString &ignoreClipId = "") const;
  [[nodiscard]] FrameIndex
  resolveInsertFrame(FrameIndex dropFrame,
                     FrameIndex clipDuration) const noexcept;

  void setClips(std::vector<TimelineClip> clips);

private:
  void sortClipsInternal() noexcept;

  QString m_trackId;
  QString m_name;
  TrackKind m_kind;
  bool m_isLocked{false};
  bool m_isMuted{false};
  bool m_isSelected{false};
  std::vector<TimelineClip> m_clips;
};

} // namespace xyla
