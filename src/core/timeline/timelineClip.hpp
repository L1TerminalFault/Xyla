#pragma once

#include "core/render/nodeGraph.hpp"
#include "timelineTypes.hpp"
#include <QString>
#include <QVariantList>
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
  [[nodiscard]] int blendMode() const noexcept { return m_blendMode; }

  // GPU Node Graph Accessors
  [[nodiscard]] std::shared_ptr<render::NodeGraph> nodeGraph() const noexcept {
    return m_nodeGraph;
  }

  [[nodiscard]] QVariantList nodeGraphNodes() const {
    return m_nodeGraph ? m_nodeGraph->toVariantList() : QVariantList();
  }

  [[nodiscard]] QVariantList nodeGraphLinks() const {
    return m_nodeGraph ? m_nodeGraph->linksToVariantList() : QVariantList();
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
  void setBlendMode(int mode) noexcept { m_blendMode = mode; }

  void setTransform(double px, double py, double sx, double sy,
                    double op) noexcept {
    m_positionX = px;
    m_positionY = py;
    m_scaleX = sx;
    m_scaleY = sy;
    m_opacity = std::clamp(op, 0.0, 1.0);
  }

  // Dynamically exports ALL Node Graph Sockets to Vulkan Push Constants
  [[nodiscard]] QVariantMap pushConstantValues() const {
    QVariantMap map;
    if (m_nodeGraph) {
      for (const auto &node : m_nodeGraph->nodes()) {
        if (!node)
          continue;
        for (const auto &inSocket : node->inputs()) {
          if (inSocket.dataType != render::SocketDataType::Image) {
            QString fullKey = node->id() + "_" + inSocket.id;

            // Helper conversion from SocketValue variant to QVariant
            std::visit(
                [&map, &fullKey](const auto &v) {
                  using T = std::decay_t<decltype(v)>;
                  if constexpr (std::is_same_v<T, float>) {
                    map[fullKey] = static_cast<double>(v);
                  } else if constexpr (std::is_same_v<T, render::Vec2Val>) {
                    map[fullKey] = QVariantList{static_cast<double>(v[0]),
                                                static_cast<double>(v[1])};
                  } else if constexpr (std::is_same_v<T, render::ColorVal>) {
                    map[fullKey] = QVariantList{
                        static_cast<double>(v[0]), static_cast<double>(v[1]),
                        static_cast<double>(v[2]), static_cast<double>(v[3])};
                  } else if constexpr (std::is_same_v<T, int32_t>) {
                    map[fullKey] = static_cast<int>(v);
                  } else if constexpr (std::is_same_v<T, bool>) {
                    map[fullKey] = v;
                  }
                },
                inSocket.defaultValue);
          }
        }
      }
    }
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
            {"isMuted", m_isMuted},
            {"blendMode", m_blendMode},
            {"nodes", nodeGraphNodes()},
            {"links", nodeGraphLinks()}}; // <--- FIXED: Exporting links now!
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
  int m_blendMode{0};

  // Inspector Transforms
  double m_positionX{0.0};
  double m_positionY{0.0};
  double m_scaleX{1.0};
  double m_scaleY{1.0};
  double m_opacity{1.0};
};

} // namespace xyla
