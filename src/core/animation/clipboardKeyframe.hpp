#pragma once

#include <QObject>
#include <QString>
#include <cstdint>
#include <vector>

namespace xyla::anim {

Q_NAMESPACE

struct ClipboardKeyframe {
  // Individual Keyframe Data
  QString clipId{};
  QString propId{};
  int64_t frame{0};
  float value{0.0f};
  int interpolation{0};
  float inX{0.666f};
  float inY{0.0f};
  float outX{0.333f};
  float outY{0.0f};

  // Clipboard Container Data
  std::vector<ClipboardKeyframe> keys{};
  int64_t earliestFrame{0};
  int64_t latestFrame{0};

  [[nodiscard]] bool isEmpty() const noexcept { return keys.empty(); }

  void clear() noexcept {
    keys.clear();
    earliestFrame = 0;
    latestFrame = 0;
  }

  bool operator==(const ClipboardKeyframe &other) const = default;
};

enum class MergeMode : uint8_t {
  Mix = 0,
  OverwriteRange = 1,
  OverwriteAll = 2
};
Q_ENUM_NS(MergeMode)

enum class HandleType : uint8_t {
  Free = 0,
  Aligned = 1,
  Vector = 2,
  Auto = 3,
  AutoClamped = 4
};
Q_ENUM_NS(HandleType)

enum class EasingType : uint8_t {
  Linear = 0,
  EaseIn = 1,
  EaseOut = 2,
  EaseInOut = 3
};
Q_ENUM_NS(EasingType)

} // namespace xyla::anim
