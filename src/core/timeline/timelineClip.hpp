#pragma once

#include "core/render/nodeGraph.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
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

  // Basic Getters
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

  // --- Intrinsic Components ---
  [[nodiscard]] ClipTransformData &transform() noexcept { return m_transform; }
  [[nodiscard]] const ClipTransformData &transform() const noexcept {
    return m_transform;
  }

  [[nodiscard]] ClipColorData &color() noexcept { return m_color; }
  [[nodiscard]] const ClipColorData &color() const noexcept { return m_color; }

  [[nodiscard]] ClipAudioData &audio() noexcept { return m_audio; }
  [[nodiscard]] const ClipAudioData &audio() const noexcept { return m_audio; }

  // Backward Compatibility Helpers for existing Inspector
  [[nodiscard]] double opacity() const noexcept {
    return m_transform.opacity.staticValue();
  }
  [[nodiscard]] double positionX() const noexcept {
    return m_transform.position.staticValue()[0];
  }
  [[nodiscard]] double positionY() const noexcept {
    return m_transform.position.staticValue()[1];
  }
  [[nodiscard]] double scaleX() const noexcept {
    return m_transform.scale.staticValue()[0];
  }
  [[nodiscard]] double scaleY() const noexcept {
    return m_transform.scale.staticValue()[1];
  }

  void setTransform(double px, double py, double sx, double sy,
                    double op) noexcept {
    m_transform.position.setStaticValue(
        {static_cast<float>(px), static_cast<float>(py)});
    m_transform.scale.setStaticValue(
        {static_cast<float>(sx), static_cast<float>(sy)});
    m_transform.opacity.setStaticValue(
        static_cast<float>(std::clamp(op, 0.0, 1.0)));
  }

  // --- Optional Effect Node Graph ---
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
  pushConstantValues(FrameIndex relativeFrame = 0) const {
    QVariantMap map;
    auto pos = m_transform.position.evaluate(relativeFrame);
    auto scl = m_transform.scale.evaluate(relativeFrame);
    auto anch = m_transform.anchorPoint.evaluate(relativeFrame);
    float rot = m_transform.rotation.evaluate(relativeFrame);
    float op = m_transform.opacity.evaluate(relativeFrame);

    map["position"] =
        QVariantList{static_cast<double>(pos[0]), static_cast<double>(pos[1])};
    map["scale"] =
        QVariantList{static_cast<double>(scl[0]), static_cast<double>(scl[1])};
    map["anchor"] = QVariantList{static_cast<double>(anch[0]),
                                 static_cast<double>(anch[1])};
    map["rotation"] = rot;
    map["opacity"] = op;
    map["blendMode"] = m_blendMode;

    auto lft = m_color.lift.evaluate(relativeFrame);
    auto gma = m_color.gamma.evaluate(relativeFrame);
    auto gan = m_color.gain.evaluate(relativeFrame);
    auto off = m_color.offset.evaluate(relativeFrame);

    QVariantList liftList{lft[0], lft[1], lft[2], lft[3]};
    QVariantList gammaList{gma[0], gma[1], gma[2], gma[3]};
    QVariantList gainList{gan[0], gan[1], gan[2], gan[3]};
    QVariantList offsetList{off[0], off[1], off[2], off[3]};

    float temp = m_color.temperature.evaluate(relativeFrame);
    float tint = m_color.tint.evaluate(relativeFrame);
    float cont = m_color.contrast.evaluate(relativeFrame);
    float piv = m_color.pivot.evaluate(relativeFrame);
    float mid = m_color.midDetail.evaluate(relativeFrame);
    float cboost = m_color.colorBoost.evaluate(relativeFrame);
    float shd = m_color.shadows.evaluate(relativeFrame);
    float high = m_color.highlights.evaluate(relativeFrame);
    float sat = m_color.saturation.evaluate(relativeFrame);
    float hue = m_color.hue.evaluate(relativeFrame);
    float lmix = m_color.lumMix.evaluate(relativeFrame);

    map["lift"] = liftList;
    map["gamma"] = gammaList;
    map["gain"] = gainList;
    map["offset"] = offsetList;
    map["temperature"] = temp;
    map["tint"] = tint;
    map["contrast"] = cont;
    map["pivot"] = piv;
    map["midDetail"] = mid;
    map["colorBoost"] = cboost;
    map["shadows"] = shd;
    map["highlights"] = high;
    map["saturation"] = sat;
    map["hue"] = hue;
    map["lumMix"] = lmix;

    if (m_nodeGraph) {
      for (const auto &node : m_nodeGraph->nodes()) {
        if (!node)
          continue;
        const QString &nId = node->id();
        map[nId + "_lift"] = liftList;
        map[nId + "_gamma"] = gammaList;
        map[nId + "_gain"] = gainList;
        map[nId + "_offset"] = offsetList;
        map[nId + "_temperature"] = temp;
        map[nId + "_tint"] = tint;
        map[nId + "_contrast"] = cont;
        map[nId + "_pivot"] = piv;
        map[nId + "_midDetail"] = mid;
        map[nId + "_colorBoost"] = cboost;
        map[nId + "_shadows"] = shd;
        map[nId + "_highlights"] = high;
        map[nId + "_saturation"] = sat;
        map[nId + "_hue"] = hue;
        map[nId + "_lumMix"] = lmix;
      }
    }

    return map;
  }

  [[nodiscard]] const QString &linkGroupId() const noexcept {
    return m_linkGroupId;
  }
  void setLinkGroupId(QString groupId) noexcept {
    m_linkGroupId = std::move(groupId);
  }

  [[nodiscard]] QJsonObject serialize() const;
  static TimelineClip deserialize(const QJsonObject &obj);

  [[nodiscard]] QVariantMap toVariantMap() const;

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

  // --- Intrinsic Components ---
  ClipTransformData m_transform;
  ClipColorData m_color;
  ClipAudioData m_audio;
};

} // namespace xyla
