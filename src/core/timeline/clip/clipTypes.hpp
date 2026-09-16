#pragma once

#include "core/timeline/timelineTypes.hpp"
#include <QJsonObject>
#include <algorithm>
#include <cstdint>

namespace xyla {

// time geometry
struct ClipTiming {
  FrameIndex startFrame{0};
  FrameIndex durationFrames{1};
  FrameIndex sourceInFrame{0};
  int trackIndex{0};
  double speed{1.0};

  // boundaries
  [[nodiscard]] FrameIndex endFrame() const noexcept {
    return startFrame + durationFrames;
  }
  [[nodiscard]] FrameIndex sourceOutFrame() const noexcept {
    return sourceInFrame + durationFrames;
  }

  // spatial and interval queries
  [[nodiscard]] bool containsFrame(FrameIndex frame) const noexcept {
    return frame >= startFrame && frame < endFrame();
  }

  [[nodiscard]] bool overlaps(FrameIndex otherStart,
                              FrameIndex otherDuration) const noexcept {
    FrameIndex otherEnd = otherStart + otherDuration;
    return startFrame < otherEnd && endFrame() > otherStart;
  }

  // time space conversions
  [[nodiscard]] FrameIndex
  timelineToLocalFrame(FrameIndex globalTimelineFrame) const noexcept {
    return globalTimelineFrame - startFrame;
  }

  [[nodiscard]] FrameIndex
  timelineToSourceFrame(FrameIndex globalTimelineFrame) const noexcept {
    FrameIndex local = timelineToLocalFrame(globalTimelineFrame);
    return sourceInFrame + static_cast<FrameIndex>(local * speed);
  }

  // serialization
  [[nodiscard]] QJsonObject serialize() const {
    QJsonObject obj;
    obj["startFrame"] = static_cast<qint64>(startFrame);
    obj["durationFrames"] = static_cast<qint64>(durationFrames);
    obj["sourceInFrame"] = static_cast<qint64>(sourceInFrame);
    obj["trackIndex"] = trackIndex;
    obj["speed"] = speed;
    return obj;
  }

  static ClipTiming deserialize(const QJsonObject &obj) {
    ClipTiming t;
    t.startFrame =
        static_cast<FrameIndex>(obj.value("startFrame").toInteger(0));
    t.durationFrames = std::max<FrameIndex>(
        1, static_cast<FrameIndex>(obj.value("durationFrames").toInteger(1)));
    t.sourceInFrame = std::max<FrameIndex>(
        0, static_cast<FrameIndex>(obj.value("sourceInFrame").toInteger(0)));
    t.trackIndex = obj.value("trackIndex").toInt(0);
    t.speed = obj.value("speed").toDouble(1.0);
    return t;
  }
};

// creation descriptor
struct TimelineClipCreateInfo {
  QString clipId;
  QString assetId;
  QString name;
  ClipTiming timing;
};

// gpu push constants block
struct alignas(16) ClipPushConstants {
  float posX{0.0f};
  float posY{0.0f};
  float scaleX{1.0f};
  float scaleY{1.0f};

  float anchorX{0.0f};
  float anchorY{0.0f};
  float rotation{0.0f};
  float opacity{1.0f};

  int32_t blendMode{0};
  float _pad0{0.0f};
  float _pad1{0.0f};
  float _pad2{0.0f};

  float lift[4]{0.0f, 0.0f, 0.0f, 0.0f};
  float gamma[4]{1.0f, 1.0f, 1.0f, 0.0f};
  float gain[4]{1.0f, 1.0f, 1.0f, 0.0f};
  float offset[4]{0.0f, 0.0f, 0.0f, 0.0f};

  float temperature{0.0f};
  float tint{0.0f};
  float contrast{1.0f};
  float pivot{0.435f};

  float midDetail{0.0f};
  float colorBoost{0.0f};
  float shadows{0.0f};
  float highlights{0.0f};

  float saturation{50.0f};
  float hue{50.0f};
  float lumMix{100.0f};
  float bypassColor{0.0f};
};

} // namespace xyla
