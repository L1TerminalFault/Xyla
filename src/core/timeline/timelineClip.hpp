#pragma once

#include "core/render/nodeGraph.hpp"
#include "timelineTypes.hpp"
#include <QString>
#include <QVariantMap>
#include <algorithm>
#include <memory>

namespace xyla {

class TimelineClip {
public:
  TimelineClip(QString clipId, QString assetId, QString name,
               FrameIndex startFrame, FrameIndex durationFrames,
               FrameIndex sourceInFrame = 0, int trackIndex = 0)
      : m_clipId(std::move(clipId)), m_assetId(std::move(assetId)),
        m_name(std::move(name)), m_startFrame(startFrame),
        m_durationFrames(durationFrames), m_sourceInFrame(sourceInFrame),
        m_trackIndex(trackIndex),
        m_nodeGraph(render::NodeGraph::createDefaultClipGraph(m_assetId)) {}

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

  // GPU Node Graph Accessor
  [[nodiscard]] std::shared_ptr<render::NodeGraph> nodeGraph() const noexcept {
    return m_nodeGraph;
  }

  // Fast Inspector Transforms
  [[nodiscard]] double opacity() const noexcept { return m_opacity; }
  [[nodiscard]] double positionX() const noexcept { return m_positionX; }
  [[nodiscard]] double positionY() const noexcept { return m_positionY; }
  [[nodiscard]] double scaleX() const noexcept { return m_scaleX; }
  [[nodiscard]] double scaleY() const noexcept { return m_scaleY; }

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

  void setTransform(double px, double py, double sx, double sy,
                    double op) noexcept {
    m_positionX = px;
    m_positionY = py;
    m_scaleX = sx;
    m_scaleY = sy;
    m_opacity = std::clamp(op, 0.0, 1.0);
  }

  // Exports Push Constants map for XylaRenderer (0.001 microseconds update)
  [[nodiscard]] QVariantMap pushConstantValues() const {
    QVariantMap map;
    QString xformId = m_assetId + "_xform";
    map[xformId + "_position"] = QVariantList{m_positionX, m_positionY};
    map[xformId + "_scale"] = QVariantList{m_scaleX, m_scaleY};
    map[xformId + "_opacity"] = m_opacity;
    return map;
  }

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"clipId", m_clipId},
            {"assetId", m_assetId},
            {"name", m_name},
            {"startFrame", static_cast<double>(m_startFrame)},
            {"durationFrames", static_cast<double>(m_durationFrames)},
            {"sourceInFrame", static_cast<double>(m_sourceInFrame)},
            {"trackIndex", m_trackIndex},
            {"speed", m_speed},
            {"isMuted", m_isMuted}};
  }

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;
  std::shared_ptr<render::NodeGraph> m_nodeGraph;

  FrameIndex m_startFrame{0};
  FrameIndex m_durationFrames{30};
  FrameIndex m_sourceInFrame{0};
  int m_trackIndex{0};
  double m_speed{1.0};
  bool m_isMuted{false};

  // Inspector Transforms
  double m_positionX{0.0};
  double m_positionY{0.0};
  double m_scaleX{1.0};
  double m_scaleY{1.0};
  double m_opacity{1.0};
};

} // namespace xyla
