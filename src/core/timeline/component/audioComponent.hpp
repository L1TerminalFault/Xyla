#pragma once

#include "clipComponent.hpp"
#include "core/animation/AnimationManager.hpp"
#include "core/animation/propertyHandle.hpp"
#include "core/log/logger.hpp"
#include <array>
#include <memory>

namespace xyla {

enum class AudioPropertyId : uint8_t { Volume = 0, Pan, Count };

struct AudioHandles {
  std::array<anim::PropertyHandle, static_cast<size_t>(AudioPropertyId::Count)>
      channels;
};

class AudioComponent : public ClipComponent {
public:
  AudioComponent() = default;

  AudioComponent(const AudioComponent &other)
      : ClipComponent(other), channelMode(other.channelMode),
        handles(other.handles), m_animMgr(other.m_animMgr) {}

  AudioComponent &operator=(const AudioComponent &other) {
    if (this == &other)
      return *this;
    ClipComponent::operator=(other);
    channelMode = other.channelMode;
    handles = other.handles;
    m_animMgr = other.m_animMgr;
    return *this;
  }

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override {
    return std::make_unique<AudioComponent>(*this);
  }

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::IntrinsicAudio;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("audio");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Audio");
  }

  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override {
    m_animMgr = &animMgr;
    const QString prefix = clipId + QStringLiteral(".audio.");

    auto reg = [&](AudioPropertyId id, const QString &name, float def,
                   const QString &group) {
      handles.channels[static_cast<size_t>(id)] = animMgr.registerFloatProperty(
          clipId, prefix + name, def, name, group);
    };

    reg(AudioPropertyId::Volume, QStringLiteral("volume"), 1.0f,
        QStringLiteral("Audio"));
    reg(AudioPropertyId::Pan, QStringLiteral("pan"), 0.0f,
        QStringLiteral("Audio"));
  }

  [[nodiscard]] anim::AnimProperty *findProperty(const QString &) override {
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &) const override {
    return nullptr;
  }

  void collectChannelInfo(const QString &, int64_t, int64_t,
                          std::vector<anim::AnimChannelInfo> &) const override {
  }

  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override {
    QString id = propertyId.startsWith(QLatin1String("audio."))
                     ? propertyId.mid(6)
                     : propertyId;

    if (id == QLatin1String("channelMode")) {
      channelMode = value.toInt();
      return true;
    }

    auto setTableHandle = [&](AudioPropertyId propId,
                              const QVariant &val) -> bool {
      if (!m_animMgr) {
        XYLA_LOG_WARN("AudioComponent",
                      "setTableHandle failed: m_animMgr is NULL!");
        return false;
      }
      const auto handle = handles.channels[static_cast<size_t>(propId)];
      if (!handle.isValid()) {
        XYLA_LOG_WARN(
            "AudioComponent",
            std::format(
                "setTableHandle failed: handle is invalid for propId {}!",
                static_cast<int>(propId)));
        return false;
      }
      return m_animMgr->setProperty(handle, val, localFrame);
    };

    bool ok = false;
    float fVal = value.toFloat(&ok);
    if (!ok)
      return false;

    if (id == QLatin1String("volume"))
      return setTableHandle(AudioPropertyId::Volume, fVal);

    if (id == QLatin1String("pan"))
      return setTableHandle(AudioPropertyId::Pan, fVal);

    return false;
  }

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;
    obj[QStringLiteral("channelMode")] = channelMode;
    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    channelMode = obj.value(QStringLiteral("channelMode")).toInt(0);
  }

  [[nodiscard]] anim::PropertyHandle handle(AudioPropertyId id) const noexcept {
    return handles.channels[static_cast<size_t>(id)];
  }

  int channelMode{0};
  AudioHandles handles;

private:
  anim::AnimationManager *m_animMgr{nullptr};
};

} // namespace xyla
