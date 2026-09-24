#pragma once
#include "core/log/logger.hpp"
#include "core/timeline/timelineTypes.hpp"

#include <QJsonObject>

#include <algorithm>
#include <cstdint>

namespace xyla {
struct ClipTiming {
  FrameIndex startFrame{0};
  FrameIndex durationFrames{1};
  FrameIndex sourceInFrame{0};

  int trackIndex{0};
  double speed{1.0};

  [[nodiscard]] FrameIndex endFrame() const noexcept {
    return startFrame + durationFrames;
  }

  [[nodiscard]] FrameIndex sourceOutFrame() const noexcept {
    return sourceInFrame + durationFrames;
  }

  [[nodiscard]] bool containsFrame(FrameIndex frame) const noexcept {
    return frame >= startFrame && frame < endFrame();
  }

  [[nodiscard]] bool overlaps(FrameIndex otherStart,
                              FrameIndex otherDuration) const noexcept {
    const FrameIndex otherEnd = otherStart + otherDuration;

    return startFrame < otherEnd && endFrame() > otherStart;
  }

  // --------------------------------------------------------------------------
  // Frame Conversion
  // --------------------------------------------------------------------------

  [[nodiscard]] FrameIndex
  timelineToLocalFrame(FrameIndex globalTimelineFrame) const noexcept {
    return globalTimelineFrame - startFrame;
  }

  [[nodiscard]] FrameIndex
  timelineToSourceFrame(FrameIndex globalTimelineFrame) const noexcept {
    const FrameIndex localFrame = timelineToLocalFrame(globalTimelineFrame);

    return sourceInFrame + static_cast<FrameIndex>(localFrame * speed);
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------
  //
  // Serialization keys are intentionally unchanged because they are part of
  // the existing project/file format.
  //

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
    ClipTiming timing;

    timing.startFrame =
        static_cast<FrameIndex>(obj.value("startFrame").toInteger(0));

    timing.durationFrames = std::max<FrameIndex>(
        1, static_cast<FrameIndex>(obj.value("durationFrames").toInteger(1)));

    timing.sourceInFrame = std::max<FrameIndex>(
        0, static_cast<FrameIndex>(obj.value("sourceInFrame").toInteger(0)));

    timing.trackIndex = obj.value("trackIndex").toInt(0);

    timing.speed = obj.value("speed").toDouble(1.0);

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

enum class ClipType : std::uint8_t { Video = 0, Audio, Text, Svg, All };
[[nodiscard]] constexpr std::string_view
clipTypeToString(ClipType type) noexcept {
  switch (type) {
  case ClipType::Video:
    return "Video";
  case ClipType::Audio:
    return "Audio";
  case ClipType::Text:
    return "Text";
  case ClipType::Svg:
    return "Svg";
  case ClipType::All:
    return "All";
  }
  return "Unknown";
}

class ClipTypeFilter {
public:
  // Compile-time prevention: getSelectedClips({}) will fail to compile.
  ClipTypeFilter() = delete;

  // Single-type constructor.
  constexpr ClipTypeFilter(ClipType singleType) noexcept
      : m_allowsAll(singleType == ClipType::All), m_isValid(true) {
    if (!m_allowsAll) {
      m_types.push_back(singleType);
    }
  }

  // Initializer-list constructor for syntax like: {ClipType::Video,
  // ClipType::Text}
  ClipTypeFilter(std::initializer_list<ClipType> types) {
    validateAndInitialize(std::vector<ClipType>(types));
  }

  explicit ClipTypeFilter(std::vector<ClipType> types) {
    validateAndInitialize(std::move(types));
  }

  [[nodiscard]] bool matches(ClipType type) const noexcept {
    if (!m_isValid) {
      XYLA_LOG_ERROR("ClipTypeFilter",
                     "matches() called on an invalid ClipTypeFilter!");
      return false;
    }
    if (m_allowsAll) {
      return true;
    }
    for (const auto t : m_types) {
      if (t == type) {
        return true;
      }
    }
    return false;
  }

  [[nodiscard]] bool allowsAll() const noexcept { return m_allowsAll; }
  [[nodiscard]] bool isValid() const noexcept { return m_isValid; }
  [[nodiscard]] const std::vector<ClipType> &types() const noexcept {
    return m_types;
  }

private:
  void validateAndInitialize(std::vector<ClipType> inputTypes) {
    if (inputTypes.empty()) {
      XYLA_LOG_ERROR(
          "ClipTypeFilter",
          "Invalid ClipTypeFilter: Filter collection cannot be empty!");
      m_isValid = false;
      return;
    }

    bool hasAll = false;
    bool hasSpecific = false;

    for (const auto t : inputTypes) {
      if (t == ClipType::All) {
        hasAll = true;
      } else {
        hasSpecific = true;
      }
    }

    if (hasAll && hasSpecific) {
      XYLA_LOG_ERROR("ClipTypeFilter",
                     "Invalid ClipTypeFilter: ClipType::All cannot be combined "
                     "with specific clip types!");
      m_isValid = false;
      return;
    }

    if (hasAll) {
      m_allowsAll = true;
      m_isValid = true;
      return;
    }

    m_allowsAll = false;
    m_types.reserve(inputTypes.size());
    for (const auto t : inputTypes) {
      bool duplicate = false;
      for (const auto existing : m_types) {
        if (existing == t) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) {
        m_types.push_back(t);
      }
    }
    m_isValid = true;
  }

  std::vector<ClipType> m_types;
  bool m_allowsAll{false};
  bool m_isValid{false};
};
} // namespace xyla
