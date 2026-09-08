#pragma once

#include "core/animation/animProperty.hpp"
#include "core/animation/propertyDescriptor.hpp"
#include "core/render/nodeGraph.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include "timelineTypes.hpp"

#include <QJsonObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <algorithm>
#include <memory>
#include <vector>

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

  [[nodiscard]] QJsonObject serialize() const;
  static TimelineClip deserialize(const QJsonObject &obj);

  [[nodiscard]] QVariantMap toVariantMap() const;

  [[nodiscard]] anim::AnimProperty *findAnimProperty(const QString &key);
  [[nodiscard]] const anim::AnimProperty *
  findAnimProperty(const QString &key) const;

  // Returns descriptors for every property this clip owns.
  // Filtering by track kind (Video / Audio) is done by the caller.
  [[nodiscard]] std::vector<const anim::PropertyDescriptor *>
  animatableProperties() const;

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
  [[nodiscard]] bool isLocked() const noexcept { return m_isLocked; }
  void setLocked(bool locked) noexcept { m_isLocked = locked; }

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

  [[nodiscard]] ClipTransformData &transform() noexcept { return m_transform; }
  [[nodiscard]] const ClipTransformData &transform() const noexcept {
    return m_transform;
  }
  [[nodiscard]] ClipColorData &color() noexcept { return m_color; }
  [[nodiscard]] const ClipColorData &color() const noexcept { return m_color; }
  [[nodiscard]] ClipAudioData &audio() noexcept { return m_audio; }
  [[nodiscard]] const ClipAudioData &audio() const noexcept { return m_audio; }

  [[nodiscard]] std::shared_ptr<render::NodeGraph> nodeGraph() const noexcept {
    return m_nodeGraph;
  }
  void setNodeGraph(std::shared_ptr<render::NodeGraph> graph) noexcept {
    m_nodeGraph = std::move(graph);
  }
  [[nodiscard]] QVariantList nodeGraphNodes() const {
    return m_nodeGraph ? m_nodeGraph->toVariantList() : QVariantList();
  }
  [[nodiscard]] QVariantList nodeGraphLinks() const {
    return m_nodeGraph ? m_nodeGraph->linksToVariantList() : QVariantList();
  }

  [[nodiscard]] QVariantMap
  pushConstantValues(FrameIndex relativeFrame = 0) const;

  [[nodiscard]] const QString &linkGroupId() const noexcept {
    return m_linkGroupId;
  }
  void setLinkGroupId(QString groupId) noexcept {
    m_linkGroupId = std::move(groupId);
  }

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;
  std::shared_ptr<render::NodeGraph> m_nodeGraph;
  QString m_linkGroupId;

  FrameIndex m_startFrame{0};
  FrameIndex m_durationFrames{30};
  FrameIndex m_sourceInFrame{0};
  int m_trackIndex{0};
  double m_speed{1.0};
  bool m_isMuted{false};
  bool m_isLocked{false};
  int m_blendMode{0};

  ClipTransformData m_transform;
  ClipColorData m_color;
  ClipAudioData m_audio;
};

} // namespace xyla
