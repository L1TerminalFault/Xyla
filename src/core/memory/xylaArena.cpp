#include "xylaArena.hpp"
#include "core/log/logger.hpp"
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>

namespace xyla::memory {
XylaArena::XylaArena(size_t capacityBytes)
    : m_capacity(capacityBytes), m_offset(0), m_ownsBuffer(true) {
  if (m_capacity == 0) {
    m_capacity = kDefaultCapacity;
  }

#if defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE >= 200112L) ||                \
    defined(__APPLE__)
  void *ptr = nullptr;
  if (posix_memalign(&ptr, 64, m_capacity) == 0) {
    m_buffer = static_cast<uint8_t *>(ptr);
  } else {
    m_buffer = new (std::nothrow) uint8_t[m_capacity];
  }
#else
  m_buffer = new (std::nothrow) uint8_t[m_capacity];
#endif

  if (!m_buffer) {
    XYLA_LOG_ERROR("XylaArena", "Failed to allocate arena buffer of " +
                                    std::to_string(m_capacity) + " bytes!");
    m_capacity = 0;
  }
}

XylaArena::~XylaArena() {
  if (m_ownsBuffer && m_buffer) {
#if defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE >= 200112L) ||                \
    defined(__APPLE__)
    std::free(m_buffer);
#else
    delete[] m_buffer;
#endif
    m_buffer = nullptr;
  }
}

XylaArena::XylaArena(XylaArena &&other) noexcept
    : m_buffer(other.m_buffer), m_capacity(other.m_capacity),
      m_offset(other.m_offset), m_ownsBuffer(other.m_ownsBuffer) {
  other.m_buffer = nullptr;
  other.m_capacity = 0;
  other.m_offset = 0;
  other.m_ownsBuffer = false;
}

XylaArena &XylaArena::operator=(XylaArena &&other) noexcept {
  if (this != &other) {
    if (m_ownsBuffer && m_buffer) {
#if defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE >= 200112L) ||                \
    defined(__APPLE__)
      std::free(m_buffer);
#else
      delete[] m_buffer;
#endif
    }
    m_buffer = other.m_buffer;
    m_capacity = other.m_capacity;
    m_offset = other.m_offset;
    m_ownsBuffer = other.m_ownsBuffer;

    other.m_buffer = nullptr;
    other.m_capacity = 0;
    other.m_offset = 0;
    other.m_ownsBuffer = false;
  }
  return *this;
}

void *XylaArena::allocate(size_t bytes, size_t alignment) noexcept {
  if (bytes == 0 || !m_buffer) {
    return nullptr;
  }

  alignment = std::max(size_t(1), alignment);

  uintptr_t currentAddress = reinterpret_cast<uintptr_t>(m_buffer + m_offset);
  uintptr_t alignedAddress =
      (currentAddress + (alignment - 1)) & ~(alignment - 1);
  size_t padding = alignedAddress - currentAddress;

  if (m_offset + padding + bytes > m_capacity) {
    XYLA_LOG_ERROR("XylaArena", "Arena capacity exceeded! Requested " +
                                    std::to_string(bytes) + " bytes (" +
                                    std::to_string(remaining()) +
                                    " bytes remaining).");
    return nullptr;
  }

  m_offset += padding + bytes;
  return reinterpret_cast<void *>(alignedAddress);
}

void XylaArena::reset() noexcept { m_offset = 0; }

ArenaMarker XylaArena::getMarker() const noexcept {
  return ArenaMarker{m_offset};
}

void XylaArena::resetToMarker(ArenaMarker marker) noexcept {
  if (marker.offset <= m_capacity) {
    m_offset = marker.offset;
  }
}

size_t XylaArena::capacity() const noexcept { return m_capacity; }
size_t XylaArena::used() const noexcept { return m_offset; }
size_t XylaArena::remaining() const noexcept {
  return (m_capacity >= m_offset) ? (m_capacity - m_offset) : 0;
}

XylaArena &XylaArena::threadLocalScratchpad() {
  thread_local XylaArena scratchpad(kDefaultCapacity);
  return scratchpad;
}
} // namespace xyla::memory
