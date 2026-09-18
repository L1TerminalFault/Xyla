#pragma once

#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include <array>
#include <mutex>
#include <vector>
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

struct CachedRangeSelectorState {
  float start{0.0f};
  float end{0.0f};
  float offset{0.0f};
  xyla::vector::SelectorShape shape{xyla::vector::SelectorShape::Square};
  xyla::vector::CombineMode combine{xyla::vector::CombineMode::Add};
  xyla::vector::BasedOn basedOn{xyla::vector::BasedOn::Characters};
  int chunkSize{2};
  QString customSeparator;
  QString regexPattern;
  bool randomize{false};
  uint32_t randomSeed{0};
};

struct CachedAnimatorState {
  bool enabled{true};
  std::vector<xyla::vector::AnimatorDelta> deltas;
  std::vector<CachedRangeSelectorState> selectors;
};

struct TextRenderCache {
  QString text;
  QString fontFamily;
  int fontWeight{400};
  bool italic{false};
  bool underline{false};
  bool strikethrough{false};
  TextHAlignment hAlign{TextHAlignment::Center};
  TextVAlignment vAlign{TextVAlignment::Middle};

  float fontSize{0.0f};
  float tracking{0.0f};
  float lineSpacing{0.0f};
  StrokePosition strokePosition{StrokePosition::Center};

  std::array<float, 4> fillColor{0.0f, 0.0f, 0.0f, 0.0f};
  float strokeWidth{0.0f};
  std::array<float, 4> strokeColor{0.0f, 0.0f, 0.0f, 0.0f};

  QJsonObject fillGradientData;
  QJsonObject strokeGradientData;

  float trimStart{0.0f};
  float trimEnd{1.0f};
  float trimOffset{0.0f};
  uint32_t width{0};
  uint32_t height{0};

  std::vector<CachedAnimatorState> animatorsState;

  bool matches(const TextComponent &comp, int64_t frame, uint32_t w,
               uint32_t h) const;
  void store(const TextComponent &comp, int64_t frame, uint32_t w, uint32_t h);
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
               uint32_t h) const;
  void store(const SvgComponent &comp, int64_t frame, uint32_t w, uint32_t h);
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

  QBrush resolveBrush(const GradientConfig &grad, const QColor &fallbackColor,
                      const QRectF &targetRect, float opacityMultiplier) const;

  VectorRenderSlot m_textSlot;
  VectorRenderSlot m_svgSlot;
  std::mutex m_mutex;

  TextRenderCache m_textCache;
  SvgRenderCache m_svgCache;
};

} // namespace xyla::render
