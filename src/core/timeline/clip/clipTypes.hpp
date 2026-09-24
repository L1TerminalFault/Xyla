#pragma once

// ============================================================================
// Clip Types
// ============================================================================
//
// Shared data structures used by the timeline clip system.
//
// Current types:
//   - ClipTiming
//   - ClipCreateInfo
//   - ClipPushConstants
//
// These represent different architectural concerns, but are intentionally kept
// together for now to avoid unnecessary header fragmentation.
//
// Future extraction candidates:
//
//   ClipTiming
//       -> timeline/timing domain type
//
//   ClipCreateInfo
//       -> clip creation/factory API
//
//   ClipPushConstants
//       -> render/GPU layer
//
// Until those systems require independent ownership, keeping these types here
// is a reasonable compromise.
// ============================================================================

#include "core/timeline/timelineTypes.hpp"

#include <QJsonObject>

#include <algorithm>
#include <cstdint>

namespace xyla {

// ============================================================================
// ClipTiming
// ============================================================================
//
// Describes where a clip exists on the timeline and how its timeline position
// maps to the source media.
//
// Timeline space:
//
//   startFrame ... startFrame + durationFrames
//
// Source space:
//
//   sourceInFrame ... sourceInFrame + durationFrames
//
// speed controls the timeline-to-source conversion.
//
// This type intentionally contains timing calculations rather than leaving
// those calculations scattered throughout TimelineClip.
// ============================================================================

struct ClipTiming {
  // --------------------------------------------------------------------------
  // Timeline / Source State
  // --------------------------------------------------------------------------

  FrameIndex startFrame{0};
  FrameIndex durationFrames{1};
  FrameIndex sourceInFrame{0};

  int trackIndex{0};
  double speed{1.0};

  // --------------------------------------------------------------------------
  // Boundaries
  // --------------------------------------------------------------------------

  [[nodiscard]] FrameIndex
  endFrame() const noexcept {
    return startFrame + durationFrames;
  }

  [[nodiscard]] FrameIndex
  sourceOutFrame() const noexcept {
    return sourceInFrame + durationFrames;
  }

  // --------------------------------------------------------------------------
  // Interval Queries
  // --------------------------------------------------------------------------

  [[nodiscard]] bool
  containsFrame(FrameIndex frame) const noexcept {
    return frame >= startFrame &&
           frame < endFrame();
  }

  [[nodiscard]] bool
  overlaps(FrameIndex otherStart,
           FrameIndex otherDuration) const noexcept {
    const FrameIndex otherEnd =
        otherStart + otherDuration;

    return startFrame < otherEnd &&
           endFrame() > otherStart;
  }

  // --------------------------------------------------------------------------
  // Frame Conversion
  // --------------------------------------------------------------------------

  [[nodiscard]] FrameIndex
  timelineToLocalFrame(
      FrameIndex globalTimelineFrame) const noexcept {
    return globalTimelineFrame - startFrame;
  }

  [[nodiscard]] FrameIndex
  timelineToSourceFrame(
      FrameIndex globalTimelineFrame) const noexcept {
    const FrameIndex localFrame =
        timelineToLocalFrame(globalTimelineFrame);

    return sourceInFrame +
           static_cast<FrameIndex>(
               localFrame * speed);
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------
  //
  // Serialization keys are intentionally unchanged because they are part of
  // the existing project/file format.
  //

  [[nodiscard]] QJsonObject
  serialize() const {
    QJsonObject obj;

    obj["startFrame"] =
        static_cast<qint64>(startFrame);

    obj["durationFrames"] =
        static_cast<qint64>(durationFrames);

    obj["sourceInFrame"] =
        static_cast<qint64>(sourceInFrame);

    obj["trackIndex"] = trackIndex;
    obj["speed"] = speed;

    return obj;
  }

  static ClipTiming
  deserialize(const QJsonObject &obj) {
    ClipTiming timing;

    timing.startFrame =
        static_cast<FrameIndex>(
            obj.value("startFrame")
                .toInteger(0));

    timing.durationFrames =
        std::max<FrameIndex>(
            1,
            static_cast<FrameIndex>(
                obj.value("durationFrames")
                    .toInteger(1)));

    timing.sourceInFrame =
        std::max<FrameIndex>(
            0,
            static_cast<FrameIndex>(
                obj.value("sourceInFrame")
                    .toInteger(0)));

    timing.trackIndex =
        obj.value("trackIndex").toInt(0);

    timing.speed =
        obj.value("speed").toDouble(1.0);

    return timing;
  }
};

// ============================================================================
// ClipCreateInfo
// ============================================================================
//
// Initial state required to construct a TimelineClip.
//
// This is deliberately a simple value object. Validation and construction
// logic belong to the clip/factory layer rather than this structure.
// ============================================================================

struct TimelineClipCreateInfo {
  QString clipId;
  QString assetId;
  QString name;
  ClipTiming timing;
};

// ============================================================================
// ClipPushConstants
// ============================================================================
//
// GPU-facing rendering data for a clip.
//
// This does NOT represent TimelineClip's domain model. It exists here
// temporarily because the current project keeps the shared clip structures
// together.
//
// IMPORTANT:
//   - member ordering may be shader/ABI sensitive
//   - alignment must remain compatible with the corresponding GPU buffer
//   - changes should be coordinated with the renderer/shader code
//
// Future refactor:
// Move this structure into the rendering layer.
// ============================================================================

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

  float lift[4]{
      0.0f, 0.0f, 0.0f, 0.0f};

  float gamma[4]{
      1.0f, 1.0f, 1.0f, 0.0f};

  float gain[4]{
      1.0f, 1.0f, 1.0f, 0.0f};

  float offset[4]{
      0.0f, 0.0f, 0.0f, 0.0f};

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
