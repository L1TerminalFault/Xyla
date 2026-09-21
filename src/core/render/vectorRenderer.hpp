#pragma once

#include "core/animation/AnimationPropertyTable.hpp"
#include "core/timeline/component/svgComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "core/vector/text/textAnimator.hpp"

#include <QJsonArray>
#include <QJsonObject>
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
  int fontWeight{400};
  bool italic{false};
  bool underline{false};
  bool strikethrough{false};
  TextHAlignment hAlign{TextHAlignment::Center};
  TextVAlignment vAlign{TextVAlignment::Middle};
  StrokePosition strokePosition{StrokePosition::Center};

  QJsonObject fillGradientData;
  QJsonObject strokeGradientData;
  QJsonArray richTextSpansData;

  vector::EvaluatedTextFrameState frameState;
  uint32_t width{0};
  uint32_t height{0};

  bool matches(const TextComponent &comp,
               const vector::EvaluatedTextFrameState &state, uint32_t w,
               uint32_t h) const;
  void store(const TextComponent &comp,
             const vector::EvaluatedTextFrameState &state, uint32_t w,
             uint32_t h);
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

  bool renderText(const TextComponent &comp,
                  const anim::AnimationPropertyTable &table, int64_t localFrame,
                  uint32_t width, uint32_t height, VkImageView *outView);

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
