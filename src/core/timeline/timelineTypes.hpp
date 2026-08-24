#pragma once

#include <cstdint>

namespace xyla {

using FrameIndex = int64_t;

enum class TrackKind { Video, Audio };

enum class EditMode {
  Overwrite, // Replaces overlapping clip portions
  Ripple,    // Shifts all subsequent clips on the track/timeline
  Roll,      // Trims adjacent clip edges together
  Slip,      // Shifts source In/Out points without moving timeline position
  Slide      // Moves clip and adjusts adjacent clips
};

} // namespace xyla
