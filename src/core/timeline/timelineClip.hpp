#pragma once

#include "timelineTypes.hpp"
#include <QString>
#include <QVariantMap>

namespace xyla {

class TimelineClip {
public:
  TimelineClip(QString clipId, QString assetId, QString name,
               FrameIndex startFrame, FrameIndex durationFrames,
               FrameIndex sourceInFrame = 0, int trackIndex = 0)
      : m_clipId(std::move(clipId)), m_assetId(std::move(assetId)),
        m_name(std::move(name)), m_startFrame(startFrame),
        m_durationFrames(durationFrames), m_sourceInFrame(sourceInFrame),
        m_trackIndex(trackIndex) {}

  // Getters
  [[nodiscard]] const QString &clipId() const noexcept { return m_clipId; }
  [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
  [[nodiscard]] const QString &name() const noexcept { return m_name; }
  [[nodiscard]] FrameIndex startFrame() const noexcept { return m_startFrame; }
  [[nodiscard]] FrameIndex durationFrames() const noexcept {
    return m_durationFrames;
  }
  [[nodiscard]] FrameIndex endFrame() const noexcept {
    return m_startFrame + m_durationFrames;
  }
  [[nodiscard]] FrameIndex sourceInFrame() const noexcept {
    return m_sourceInFrame;
  }
  [[nodiscard]] FrameIndex sourceOutFrame() const noexcept {
    return m_sourceInFrame + m_durationFrames;
  }
  [[nodiscard]] int trackIndex() const noexcept { return m_trackIndex; }
  [[nodiscard]] double speed() const noexcept { return m_speed; }
  [[nodiscard]] bool isMuted() const noexcept { return m_isMuted; }

  // Setters
  void setStartFrame(FrameIndex frame) noexcept { m_startFrame = frame; }
  void setDurationFrames(FrameIndex duration) noexcept {
    m_durationFrames = std::max<FrameIndex>(1, duration);
  }
  void setSourceInFrame(FrameIndex frame) noexcept {
    m_sourceInFrame = std::max<FrameIndex>(0, frame);
  }
  void setTrackIndex(int track) noexcept { m_trackIndex = track; }
  void setSpeed(double speed) noexcept { m_speed = speed; }
  void setMuted(bool muted) noexcept { m_isMuted = muted; }

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"clipId", m_clipId},
            {"assetId", m_assetId},
            {"name", m_name},
            {"startFrame", static_cast<qlonglong>(m_startFrame)},
            {"durationFrames", static_cast<qlonglong>(m_durationFrames)},
            {"sourceInFrame", static_cast<qlonglong>(m_sourceInFrame)},
            {"trackIndex", m_trackIndex}};
  }

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;
  FrameIndex m_startFrame{0};
  FrameIndex m_durationFrames{30};
  FrameIndex m_sourceInFrame{0};
  int m_trackIndex{0};
  double m_speed{1.0};
  bool m_isMuted{false};
};

} // namespace xyla
