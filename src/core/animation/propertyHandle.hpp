#pragma once

#include <cstdint>

namespace xyla::anim {

struct PropertyHandle {
  uint32_t index{UINT32_MAX};
  uint32_t generation{
      0}; // Protects against stale handles if slots are recycled

  [[nodiscard]] constexpr bool isValid() const noexcept {
    return index != UINT32_MAX;
  }

  constexpr bool
  operator==(const PropertyHandle &other) const noexcept = default;
};

} // namespace xyla::anim
