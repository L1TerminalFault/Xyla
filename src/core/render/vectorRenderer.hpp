#pragma once

#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include <array>
#include <mutex>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct VectorRenderSlot {
  VkImage targetImage{VK_NULL_HANDLE};
  VkDeviceMemory targetMemory{VK_NULL_HANDLE};
  VkImageView targetView{VK_NULL_HANDLE};

  VkBuffer stagingBuffer{VK_NULL_HANDLE};
  VkDeviceMemory stagingMemory{VK_NULL_HANDLE};
  void *mappedStaging{nullptr};
  size_t stagingSize{0};

  VkCommandBuffer cmdBuffer{VK_NULL_HANDLE};
  VkFence fence{VK_NULL_HANDLE};

  uint32_t width{0};
  uint32_t height{0};
  bool hasValidImage{false};
};

struct TextRenderCache {
  QString text;
  QString fontFamily;
  float fontSize{0.0f};
  float tracking{0.0f};
  float lineSpacing{0.0f};
  int alignment{0};
  StrokePosition strokePosition{StrokePosition::Center};

  std::array<float, 4> fillColor{0.0f, 0.0f, 0.0f, 0.0f};
  float strokeWidth{0.0f};
  std::array<float, 4> strokeColor{0.0f, 0.0f, 0.0f, 0.0f};
  float trimStart{0.0f};
  float trimEnd{1.0f};
  float trimOffset{0.0f};
  uint32_t width{0};
  uint32_t height{0};
  QJsonArray animatorsState;

  bool matches(const TextComponent &comp, int64_t frame, uint32_t w,
               uint32_t h) const {

    QJsonArray currentAnimators;
    for (const auto &a : comp.animators) {
      currentAnimators.append(a.serialize());
    }
    if (animatorsState != currentAnimators)
      return false;

    if (strokePosition != comp.strokePosition) {
      return false;
    }
    if (w != width || h != height || comp.text != text ||
        comp.fontFamily != fontFamily)
      return false;
    if (static_cast<int>(comp.alignment) != alignment)
      return false;
    if (std::abs(comp.fontSize.evaluate(frame) - fontSize) > 0.001f)
      return false;
    if (std::abs(comp.tracking.evaluate(frame) - tracking) > 0.001f)
      return false;
    if (std::abs(comp.lineSpacing.evaluate(frame) - lineSpacing) > 0.001f)
      return false;
    if (std::abs(comp.strokeWidth.evaluate(frame) - strokeWidth) > 0.001f)
      return false;
    if (std::abs(comp.trimStart.evaluate(frame) - trimStart) > 0.001f)
      return false;
    if (std::abs(comp.trimEnd.evaluate(frame) - trimEnd) > 0.001f)
      return false;
    if (std::abs(comp.trimOffset.evaluate(frame) - trimOffset) > 0.001f)
      return false;

    if (std::abs(comp.fillRed.evaluate(frame) - fillColor[0]) > 0.001f ||
        std::abs(comp.fillGreen.evaluate(frame) - fillColor[1]) > 0.001f ||
        std::abs(comp.fillBlue.evaluate(frame) - fillColor[2]) > 0.001f ||
        std::abs(comp.fillAlpha.evaluate(frame) - fillColor[3]) > 0.001f)
      return false;

    if (std::abs(comp.strokeRed.evaluate(frame) - strokeColor[0]) > 0.001f ||
        std::abs(comp.strokeGreen.evaluate(frame) - strokeColor[1]) > 0.001f ||
        std::abs(comp.strokeBlue.evaluate(frame) - strokeColor[2]) > 0.001f ||
        std::abs(comp.strokeAlpha.evaluate(frame) - strokeColor[3]) > 0.001f)
      return false;

    return true;
  }

  void store(const TextComponent &comp, int64_t frame, uint32_t w, uint32_t h) {
    animatorsState = QJsonArray();
    for (const auto &a : comp.animators) {
      animatorsState.append(a.serialize());
    }
    text = comp.text;
    fontFamily = comp.fontFamily;
    fontSize = comp.fontSize.evaluate(frame);
    tracking = comp.tracking.evaluate(frame);
    lineSpacing = comp.lineSpacing.evaluate(frame);
    alignment = static_cast<int>(comp.alignment);
    strokePosition = comp.strokePosition;
    strokeWidth = comp.strokeWidth.evaluate(frame);
    trimStart = comp.trimStart.evaluate(frame);
    trimEnd = comp.trimEnd.evaluate(frame);
    trimOffset = comp.trimOffset.evaluate(frame);

    fillColor[0] = comp.fillRed.evaluate(frame);
    fillColor[1] = comp.fillGreen.evaluate(frame);
    fillColor[2] = comp.fillBlue.evaluate(frame);
    fillColor[3] = comp.fillAlpha.evaluate(frame);

    strokeColor[0] = comp.strokeRed.evaluate(frame);
    strokeColor[1] = comp.strokeGreen.evaluate(frame);
    strokeColor[2] = comp.strokeBlue.evaluate(frame);
    strokeColor[3] = comp.strokeAlpha.evaluate(frame);

    width = w;
    height = h;
  }
};

struct SvgRenderCache {
  QString sourcePath;
  float strokeWidthOverride{-1.0f};
  float trimStart{0.0f};
  float trimEnd{1.0f};
  float trimOffset{0.0f};
  uint32_t width{0};
  uint32_t height{0};

  bool matches(const SvgComponent &comp, int64_t frame, uint32_t w,
               uint32_t h) const {
    if (w != width || h != height || comp.sourcePath() != sourcePath)
      return false;
    if (std::abs(comp.strokeWidthOverride.evaluate(frame) -
                 strokeWidthOverride) > 0.001f)
      return false;
    if (std::abs(comp.trimStart.evaluate(frame) - trimStart) > 0.001f)
      return false;
    if (std::abs(comp.trimEnd.evaluate(frame) - trimEnd) > 0.001f)
      return false;
    if (std::abs(comp.trimOffset.evaluate(frame) - trimOffset) > 0.001f)
      return false;
    return true;
  }

  void store(const SvgComponent &comp, int64_t frame, uint32_t w, uint32_t h) {
    sourcePath = comp.sourcePath();
    strokeWidthOverride = comp.strokeWidthOverride.evaluate(frame);
    trimStart = comp.trimStart.evaluate(frame);
    trimEnd = comp.trimEnd.evaluate(frame);
    trimOffset = comp.trimOffset.evaluate(frame);
    width = w;
    height = h;
  }
};

class VectorRenderer {
public:
  static VectorRenderer &instance();
  ~VectorRenderer();

  bool renderText(const TextComponent &comp, int64_t localFrame, uint32_t width,
                  uint32_t height, VkImageView *outView);

  bool renderSvg(const SvgComponent &comp, int64_t localFrame, uint32_t width,
                 uint32_t height, VkImageView *outView);

  void cleanup();

private:
  VectorRenderer() = default;
  Q_DISABLE_COPY_MOVE(VectorRenderer)

  void ensureSlot(VectorRenderSlot &slot, uint32_t width, uint32_t height);
  void destroySlot(VectorRenderSlot &slot);
  bool copyStagingToTarget(VectorRenderSlot &slot);

  VectorRenderSlot m_textSlot;
  VectorRenderSlot m_svgSlot;
  std::mutex m_mutex;

  TextRenderCache m_textCache;
  SvgRenderCache m_svgCache;
};

} // namespace xyla::render
