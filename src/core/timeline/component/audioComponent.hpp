#pragma once

#include "clipComponent.hpp"
#include "core/timeline/clipIntrinsicData.hpp"
#include <memory>

namespace xyla {

class AudioComponent : public ClipComponent, public ClipAudioData {
public:
  AudioComponent() = default;

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

  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &propertyId) override {
    if (propertyId == "volume")
      return &volume;
    if (propertyId == "pan")
      return &pan;
    return nullptr;
  }

  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &propertyId) const override {
    return const_cast<AudioComponent *>(this)->findProperty(propertyId);
  }

  void
  collectChannelInfo(const QString &clipId, int64_t clipStartFrame,
                     int64_t relPlayheadFrame,
                     std::vector<anim::AnimChannelInfo> &out) const override {
    auto appendProp = [&](const anim::AnimProperty &p, const QString &id,
                          const QString &name, const QString &group,
                          const QString &color) {
      if (!p.getIsAnimated())
        return;

      anim::AnimChannelInfo info;
      info.clipId = clipId;
      info.id = QStringLiteral("audio.") + id;
      info.name = name;
      info.group = group;
      info.color = color;
      info.isAnimated = true;

      for (const auto &k : p.getKeyframes()) {
        int64_t absF = k.frame + clipStartFrame;
        info.keyframeFrames.push_back(absF);
        if (k.frame == relPlayheadFrame)
          info.hasKeyframeAtPlayhead = true;

        anim::KeyframeDetail det;
        det.frame = absF;
        det.value = k.value;
        det.interpolation = static_cast<int>(k.interpolation);
        det.inX = k.bezier.inX;
        det.inY = k.bezier.inY;
        det.outX = k.bezier.outX;
        det.outY = k.bezier.outY;
        info.details.push_back(det);
      }
      out.push_back(std::move(info));
    };

    appendProp(volume, "volume", "Volume", "Audio", "#06B6D4");
    appendProp(pan, "pan", "Pan", "Audio", "#F97316");
  }

  [[nodiscard]] QJsonObject serialize() const override {
    QJsonObject obj;
    obj["volume"] = volume.serialize();
    obj["pan"] = pan.serialize();
    obj["channelMode"] = channelMode;
    return obj;
  }

  void deserialize(const QJsonObject &obj) override {
    if (obj.contains("volume"))
      volume.deserializeInto(obj["volume"].toObject(), 1.0f);
    if (obj.contains("pan"))
      pan.deserializeInto(obj["pan"].toObject(), 0.0f);
    channelMode = obj.value("channelMode").toInt(0);
  }
};

} // namespace xyla
