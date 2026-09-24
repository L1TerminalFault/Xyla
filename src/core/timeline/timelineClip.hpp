#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/animProperty.hpp"
#include "core/render/nodeGraph.hpp"
#include "core/timeline/clip/clipTypes.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include "core/timeline/component/audioComponent.hpp"
#include "core/timeline/component/clipComponent.hpp"
#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "core/timeline/component/transformComponent.hpp"
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
  TimelineClip(const TimelineClip &other);
  TimelineClip &operator=(const TimelineClip &other);
  TimelineClip(TimelineClip &&other) noexcept = default;
  TimelineClip &operator=(TimelineClip &&other) noexcept = default;
  ~TimelineClip() = default;

  // Semantic clip factories
  [[nodiscard]] static TimelineClip
  createVideoClip(TimelineClipCreateInfo info);

  [[nodiscard]] static TimelineClip
  createAudioClip(TimelineClipCreateInfo info);

  [[nodiscard]] static TimelineClip
  createTitleClip(TimelineClipCreateInfo info,
                  const QString &initialText = QStringLiteral("Title"));

  [[nodiscard]] static TimelineClip createSvgClip(TimelineClipCreateInfo info,
                                                  const QString &svgPath);

  // Semantic Clip Type Queries
  [[nodiscard]] ClipType getClipType() const noexcept;
  [[nodiscard]] bool matchesType(ClipType type) const noexcept;

  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame);

  [[nodiscard]] QJsonObject serialize() const;
  [[nodiscard]] static TimelineClip deserialize(const QJsonObject &obj);
  [[nodiscard]] QVariantMap toVariantMap() const;

  [[nodiscard]] const QString &getClipId() const noexcept;
  void setClipId(QString clipId);

  [[nodiscard]] const QString &getAssetId() const noexcept;
  void setAssetId(QString assetId);

  [[nodiscard]] const QString &getName() const noexcept;
  void setName(QString name);

  [[nodiscard]] const ClipTiming &getTiming() const noexcept;
  void setTiming(const ClipTiming &timing);

  [[nodiscard]] TimelineClip split(const QString &newRightClipId,
                                   FrameIndex cutFrame);
  [[nodiscard]] bool canUncutWith(const TimelineClip &rightClip) const noexcept;
  bool uncut(const TimelineClip &rightClip);

  [[nodiscard]] bool getIsLocked() const noexcept;
  void setIsLocked(bool locked) noexcept;

  [[nodiscard]] bool getIsMuted() const noexcept;
  void setIsMuted(bool muted) noexcept;

  [[nodiscard]] int getBlendMode() const noexcept;
  void setBlendMode(int mode);

  [[nodiscard]] bool getIsUniformScale() const noexcept;
  void setIsUniformScale(bool uniform) noexcept;

  [[nodiscard]] ClipColorData &getColor() noexcept;
  [[nodiscard]] const ClipColorData &getColor() const noexcept;

  // Component accessors
  template <typename T> [[nodiscard]] bool hasComponent() const noexcept {
    return getComponent<T>() != nullptr;
  }

  template <typename T> [[nodiscard]] T *getComponent() noexcept {
    for (auto &c : m_components) {
      if (auto *ptr = dynamic_cast<T *>(c.get())) {
        return ptr;
      }
    }
    return nullptr;
  }

  template <typename T> [[nodiscard]] const T *getComponent() const noexcept {
    for (const auto &c : m_components) {
      if (const auto *ptr = dynamic_cast<const T *>(c.get())) {
        return ptr;
      }
    }
    return nullptr;
  }

  [[nodiscard]] AudioComponent *getAudioComponent() noexcept {
    return getComponent<AudioComponent>();
  }

  [[nodiscard]] const AudioComponent *getAudioComponent() const noexcept {
    return getComponent<AudioComponent>();
  }

  [[nodiscard]] TransformComponent *getTransformComponent() noexcept {
    return getComponent<TransformComponent>();
  }

  [[nodiscard]] const TransformComponent *
  getTransformComponent() const noexcept {
    return getComponent<TransformComponent>();
  }

  void addComponent(std::unique_ptr<ClipComponent> component);
  bool removeComponent(const QString &componentId);
  [[nodiscard]] ClipComponent *
  findComponent(const QString &componentId) noexcept;
  [[nodiscard]] const ClipComponent *
  findComponent(const QString &componentId) const noexcept;
  [[nodiscard]] const std::vector<std::unique_ptr<ClipComponent>> &
  getComponents() const noexcept;

  void bindAnimationManager(anim::AnimationManager &animMgr);

  [[nodiscard]] anim::AnimProperty *findPropertyByPath(const QString &path);
  [[nodiscard]] const anim::AnimProperty *
  findPropertyByPath(const QString &path) const;

  [[nodiscard]] anim::AnimProperty *findAnimProperty(const QString &key);
  [[nodiscard]] const anim::AnimProperty *
  findAnimProperty(const QString &key) const;

  // Render node graph management
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

private:
  QString m_clipId;
  QString m_assetId;
  QString m_name;

  ClipTiming m_timing;

  bool m_isLocked{false};
  bool m_isMuted{false};
  bool m_uniformScale{true};
  int m_blendMode{0};

  ClipColorData m_color;

  std::vector<std::unique_ptr<ClipComponent>> m_components;

  std::vector<QString> m_nodeGraphIds;
  size_t m_activeGraphIndex{0};
};

} // namespace xyla
