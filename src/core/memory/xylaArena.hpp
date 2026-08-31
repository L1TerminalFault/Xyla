#pragma once

#include <cstddef>
#include <cstdint>
#include <type_traits>
#include <utility>

namespace xyla::memory {
struct ArenaMarker {
  size_t offset{0};
};

class XylaArena {
public:
  // 16 MB default scratchpad
  static constexpr size_t kDefaultCapacity = 16 * 1024 * 1024;
  static constexpr size_t kDefaultAlignment = 16;

  explicit XylaArena(size_t capacityBytes = kDefaultCapacity);
  ~XylaArena();

  XylaArena(const XylaArena &) = delete;
  XylaArena &operator=(const XylaArena &) = delete;
  XylaArena(XylaArena &&other) noexcept;
  XylaArena &operator=(XylaArena &&other) noexcept;

  [[nodiscard]] void *allocate(size_t bytes,
                               size_t alignment = kDefaultAlignment) noexcept;

  // Typed single object allocation with constructor forwarding
  template <typename T, typename... Args>
  [[nodiscard]] T *allocateObject(Args &&...args) {
    void *mem = allocate(sizeof(T), alignof(T));
    if (!mem)
      return nullptr;
    return ::new (mem) T(std::forward<Args>(args)...);
  }

  // Typed array allocation
  template <typename T> [[nodiscard]] T *allocateArray(size_t count) {
    if (count == 0)
      return nullptr;
    size_t totalBytes = sizeof(T) * count;
    void *mem = allocate(totalBytes, alignof(T));
    if (!mem)
      return nullptr;

    T *elements = static_cast<T *>(mem);
    if constexpr (!std::is_trivially_default_constructible_v<T>) {
      for (size_t i = 0; i < count; ++i) {
        ::new (static_cast<void *>(elements + i)) T();
      }
    }
    return elements;
  }

  void reset() noexcept;

  [[nodiscard]] ArenaMarker getMarker() const noexcept;
  void resetToMarker(ArenaMarker marker) noexcept;

  [[nodiscard]] size_t capacity() const noexcept;
  [[nodiscard]] size_t used() const noexcept;
  [[nodiscard]] size_t remaining() const noexcept;

  static XylaArena &threadLocalScratchpad();

private:
  uint8_t *m_buffer{nullptr};
  size_t m_capacity{0};
  size_t m_offset{0};
  bool m_ownsBuffer{true};
};
} // namespace xyla::memory
