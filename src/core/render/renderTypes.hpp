#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace xyla::render {

struct PixelRect {
  int32_t x{0};
  int32_t y{0};
  int32_t width{0};
  int32_t height{0};

  [[nodiscard]] constexpr int32_t right() const noexcept { return x + width; }
  [[nodiscard]] constexpr int32_t top() const noexcept { return y + height; }
  [[nodiscard]] constexpr bool isEmpty() const noexcept {
    return width <= 0 || height <= 0;
  }

  [[nodiscard]] PixelRect scaled(float scale) const noexcept {
    if (isEmpty() || scale <= 0.0f) {
      return {};
    }
    const auto sx =
        static_cast<int32_t>(std::lround(static_cast<float>(x) * scale));
    const auto sy =
        static_cast<int32_t>(std::lround(static_cast<float>(y) * scale));
    const auto sw = std::max(1, static_cast<int32_t>(std::lround(
                                    static_cast<float>(width) * scale)));
    const auto sh = std::max(1, static_cast<int32_t>(std::lround(
                                    static_cast<float>(height) * scale)));
    return {sx, sy, sw, sh};
  }

  [[nodiscard]] PixelRect expanded(int32_t padX, int32_t padY) const noexcept {
    if (isEmpty())
      return {};
    return {x - padX, y - padY, width + (padX * 2), height + (padY * 2)};
  }

  [[nodiscard]] PixelRect intersected(const PixelRect &other) const noexcept {
    if (isEmpty() || other.isEmpty())
      return {};
    const int32_t nx = std::max(x, other.x);
    const int32_t ny = std::max(y, other.y);
    const int32_t nr = std::min(right(), other.right());
    const int32_t nt = std::min(top(), other.top());
    return {nx, ny, std::max(0, nr - nx), std::max(0, nt - ny)};
  }

  [[nodiscard]] PixelRect united(const PixelRect &other) const noexcept {
    if (isEmpty())
      return other;
    if (other.isEmpty())
      return *this;
    const int32_t nx = std::min(x, other.x);
    const int32_t ny = std::min(y, other.y);
    const int32_t nr = std::max(right(), other.right());
    const int32_t nt = std::max(top(), other.top());
    return {nx, ny, nr - nx, nt - ny};
  }
};

struct RenderContext {
  uint32_t formatWidth{0};
  uint32_t formatHeight{0};
  PixelRect roi{};
  PixelRect rod{};
  float qualityScale{1.0f};
  int64_t frame{0};

  [[nodiscard]] constexpr bool isValid() const noexcept {
    return formatWidth > 0 && formatHeight > 0 && !roi.isEmpty() &&
           qualityScale > 0.0f;
  }

  [[nodiscard]] PixelRect effectiveRoi() const noexcept {
    return roi.scaled(qualityScale);
  }

  [[nodiscard]] PixelRect effectiveRod() const noexcept {
    return rod.scaled(qualityScale);
  }

  static RenderContext createFullFrame(uint32_t fWidth, uint32_t fHeight,
                                       int64_t frameIdx = 0,
                                       float scale = 1.0f) noexcept {
    RenderContext ctx;
    ctx.formatWidth = fWidth;
    ctx.formatHeight = fHeight;
    ctx.roi = {0, 0, static_cast<int32_t>(fWidth),
               static_cast<int32_t>(fHeight)};
    ctx.rod = ctx.roi;
    ctx.qualityScale = scale;
    ctx.frame = frameIdx;
    return ctx;
  }
};

} // namespace xyla::render
