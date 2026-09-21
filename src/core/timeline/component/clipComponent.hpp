#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/animChannel.hpp"
#include "core/animation/animProperty.hpp"
#include "core/timeline/playback/playbackManager.hpp"

#include <QJsonObject>
#include <QString>
#include <memory>
#include <vector>

namespace xyla {

enum class ComponentKind : uint8_t {
  IntrinsicTransform = 0,
  IntrinsicColor,
  IntrinsicAudio,
  GeneratorText,
  VideoModifier,
  AudioModifier
};

class ClipComponent {
public:
  virtual ~ClipComponent() = default;

  [[nodiscard]] virtual std::unique_ptr<ClipComponent> clone() const = 0;
  virtual bool setProperty(const QString &propertyId, const QVariant &value,
                           FrameIndex localFrame) {
    Q_UNUSED(propertyId);
    Q_UNUSED(value);
    Q_UNUSED(localFrame);
    return false;
  }
  [[nodiscard]] virtual ComponentKind kind() const noexcept = 0;
  [[nodiscard]] virtual QString componentId() const noexcept = 0;
  [[nodiscard]] virtual QString displayName() const = 0;

  virtual void bindAnimationManager(const QString &clipId,
                                    anim::AnimationManager &animMgr) {
    Q_UNUSED(clipId);
    Q_UNUSED(animMgr);
  }

  [[nodiscard]] virtual anim::AnimProperty *
  findProperty(const QString &propertyId) = 0;
  [[nodiscard]] virtual const anim::AnimProperty *
  findProperty(const QString &propertyId) const = 0;

  virtual void
  collectChannelInfo(const QString &clipId, int64_t clipStartFrame,
                     int64_t relPlayheadFrame,
                     std::vector<anim::AnimChannelInfo> &out) const = 0;

  [[nodiscard]] virtual QJsonObject serialize() const = 0;
  virtual void deserialize(const QJsonObject &obj) = 0;
};

} // namespace xyla
