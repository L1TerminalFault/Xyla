#pragma once

#include "core/animation/animProperty.hpp"
#include "core/animation/propertyDescriptor.hpp"
#include "core/render/nodeGraph.hpp"
#include "core/timeline/clip/clipTypes.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include "timelineTypes.hpp"

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <vector>

namespace xyla {

class TimelineClip {
public:
  explicit TimelineClip(TimelineClipCreateInfo info);

  // serialization
  [[nodiscard]] QJsonObject serialize() const;
  static TimelineClip deserialize(const QJsonObject &obj);
  [[nodiscard]] QVariantMap toVariantMap() const;

  // Identity & Metadata
  [[nodiscard]] const QString &getClipId() const noexcept;
  void setClipId(QString clipId);

  [[nodiscard]] const QString &getAssetId() const noexcept;
  void setAssetId(QString assetId);

  [[nodiscard]] const QString &getName() const noexcept;
  void setName(QString name);

  // Timeline Placement & Timing
  [[nodiscard]] const ClipTiming &getTiming() const noexcept;
  void setTiming(const ClipTiming &timing);

  [[nodiscard]] TimelineClip split(const QString &newRightClipId,
                                   FrameIndex cutFrame);
  [[nodiscard]] bool canUncutWith(const TimelineClip &rightClip) const noexcept;
  bool uncut(const TimelineClip &rightClip);

  // State & Playback Flags
  [[nodiscard]] bool getIsLocked() const noexcept;
  void setIsLocked(bool locked) noexcept;

  [[nodiscard]] bool getIsMuted() const noexcept;
  void setIsMuted(bool muted) noexcept;

  [[nodiscard]] int getBlendMode() const noexcept;
  void setBlendMode(int mode);

  [[nodiscard]] bool getIsUniformScale() const noexcept;
  void setIsUniformScale(bool uniform) noexcept;

  // Intrinsic Inspector Components
  [[nodiscard]] ClipTransformData &getTransform() noexcept;
  [[nodiscard]] const ClipTransformData &getTransform() const noexcept;

  [[nodiscard]] ClipColorData &getColor() noexcept;
  [[nodiscard]] const ClipColorData &getColor() const noexcept;

  [[nodiscard]] ClipAudioData &getAudio() noexcept;
  [[nodiscard]] const ClipAudioData &getAudio() const noexcept;

  // Node Graph FX Bindings
  [[nodiscard]] const std::vector<QString> &getNodeGraphIds() const noexcept;
  [[nodiscard]] size_t getActiveGraphIndex() const noexcept;
  void setActiveGraphIndex(size_t index);

  [[nodiscard]] QString getActiveGraphId() const;
  void setActiveGraphId(const QString &graphId);

  [[nodiscard]] std::shared_ptr<render::NodeGraph> getNodeGraph() const;
  void setNodeGraph(std::shared_ptr<render::NodeGraph> graph);

  void attachNodeGraphId(const QString &graphId);
  bool detachNodeGraphId(const QString &graphId);
  void setAttachedNodeGraphIds(const QStringList &ids);
  void copyGraphReferencesFrom(const TimelineClip &other) noexcept;

  [[nodiscard]] QVariantList getNodeGraphNodes() const;
  [[nodiscard]] QVariantList getNodeGraphLinks() const;

  // Animation & Constant Buffer Interface
  [[nodiscard]] anim::AnimProperty *findAnimProperty(const QString &key);
  [[nodiscard]] const anim::AnimProperty *
  findAnimProperty(const QString &key) const;

  [[nodiscard]] std::vector<const anim::PropertyDescriptor *>
  getAnimatableProperties() const;

  [[nodiscard]] QVariantMap
  getPushConstantValues(FrameIndex relativeFrame = 0) const;

  void fillPushConstants(ClipPushConstants &out,
                         FrameIndex relativeFrame = 0) const noexcept;

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;

  ClipTiming m_timing;

  bool m_isLocked{false};
  bool m_isMuted{false};
  bool m_uniformScale{true};
  int m_blendMode{0};

  ClipTransformData m_transform;
  ClipColorData m_color;
  ClipAudioData m_audio;

  std::vector<QString> m_nodeGraphIds;
  size_t m_activeGraphIndex{0};
};

} // namespace xyla
