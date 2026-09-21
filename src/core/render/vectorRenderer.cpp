#include "vectorRenderer.hpp"
#include "core/render/xylaRenderer.hpp"
#include "core/vector/text/textLayout.hpp"

#include <QImage>
#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QRadialGradient>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <qnamespace.h>

namespace xyla::render {

static QList<QPainterPath> decomposeSubpaths(const QPainterPath &path) {
  QList<QPainterPath> list;
  QPainterPath current;
  for (int i = 0; i < path.elementCount(); ++i) {
    const auto e = path.elementAt(i);
    if (e.isMoveTo() && !current.isEmpty()) {
      list.append(current);
      current = QPainterPath();
    }
    if (e.isMoveTo()) {
      current.moveTo(e.x, e.y);
    } else if (e.isLineTo()) {
      current.lineTo(e.x, e.y);
    } else if (e.isCurveTo()) {
      if (i + 2 < path.elementCount()) {
        const auto e2 = path.elementAt(i + 1);
        const auto e3 = path.elementAt(i + 2);
        current.cubicTo(e.x, e.y, e2.x, e2.y, e3.x, e3.y);
        i += 2;
      }
    }
  }
  if (!current.isEmpty()) {
    list.append(current);
  }
  return list;
}

VectorRenderer &VectorRenderer::instance() {
  static VectorRenderer renderer;
  return renderer;
}

VectorRenderer::~VectorRenderer() { cleanup(); }

void VectorRenderer::destroySlot(VectorRenderSlot &slot) {
  VkDevice dev = XylaRenderer::instance().device();
  if (dev == VK_NULL_HANDLE)
    return;

  if (slot.fence != VK_NULL_HANDLE) {
    vkWaitForFences(dev, 1, &slot.fence, VK_TRUE, UINT64_MAX);
    vkDestroyFence(dev, slot.fence, nullptr);
    slot.fence = VK_NULL_HANDLE;
  }

  if (slot.cmdBuffer != VK_NULL_HANDLE) {
    VkCommandPool pool = XylaRenderer::instance().commandPool();
    if (pool != VK_NULL_HANDLE) {
      vkFreeCommandBuffers(dev, pool, 1, &slot.cmdBuffer);
    }
    slot.cmdBuffer = VK_NULL_HANDLE;
  }

  if (slot.mappedStaging) {
    vkUnmapMemory(dev, slot.stagingMemory);
    slot.mappedStaging = nullptr;
  }

  if (slot.stagingBuffer != VK_NULL_HANDLE) {
    vkDestroyBuffer(dev, slot.stagingBuffer, nullptr);
    slot.stagingBuffer = VK_NULL_HANDLE;
  }

  if (slot.stagingMemory != VK_NULL_HANDLE) {
    vkFreeMemory(dev, slot.stagingMemory, nullptr);
    slot.stagingMemory = VK_NULL_HANDLE;
  }

  if (slot.targetView != VK_NULL_HANDLE) {
    vkDestroyImageView(dev, slot.targetView, nullptr);
    slot.targetView = VK_NULL_HANDLE;
  }

  if (slot.targetImage != VK_NULL_HANDLE) {
    vkDestroyImage(dev, slot.targetImage, nullptr);
    slot.targetImage = VK_NULL_HANDLE;
  }

  if (slot.targetMemory != VK_NULL_HANDLE) {
    vkFreeMemory(dev, slot.targetMemory, nullptr);
    slot.targetMemory = VK_NULL_HANDLE;
  }

  slot.stagingSize = 0;
  slot.width = 0;
  slot.height = 0;
  slot.hasValidImage = false;
}

void VectorRenderer::ensureSlot(VectorRenderSlot &slot, uint32_t width,
                                uint32_t height) {
  if (slot.width == width && slot.height == height &&
      slot.targetImage != VK_NULL_HANDLE && slot.mappedStaging != nullptr)
    return;

  destroySlot(slot);
  slot.width = width;
  slot.height = height;

  VkDevice dev = XylaRenderer::instance().device();
  VkPhysicalDevice physDev = XylaRenderer::instance().physicalDevice();
  if (dev == VK_NULL_HANDLE || physDev == VK_NULL_HANDLE)
    return;

  if (!XylaRenderer::instance().allocateRgbaTexture(
          width, height, &slot.targetImage, &slot.targetMemory,
          &slot.targetView)) {
    return;
  }

  slot.stagingSize = static_cast<size_t>(width) * height * 4;

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = slot.stagingSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  if (vkCreateBuffer(dev, &bufInfo, nullptr, &slot.stagingBuffer) !=
      VK_SUCCESS) {
    return;
  }

  VkMemoryRequirements memReqs;
  vkGetBufferMemoryRequirements(dev, slot.stagingBuffer, &memReqs);

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(physDev, &memProps);

  uint32_t hostMemType = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((memReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
      hostMemType = i;
      break;
    }
  }

  if (hostMemType == UINT32_MAX) {
    vkDestroyBuffer(dev, slot.stagingBuffer, nullptr);
    slot.stagingBuffer = VK_NULL_HANDLE;
    return;
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = hostMemType;
  if (vkAllocateMemory(dev, &allocInfo, nullptr, &slot.stagingMemory) !=
      VK_SUCCESS) {
    vkDestroyBuffer(dev, slot.stagingBuffer, nullptr);
    slot.stagingBuffer = VK_NULL_HANDLE;
    return;
  }

  if (vkBindBufferMemory(dev, slot.stagingBuffer, slot.stagingMemory, 0) !=
      VK_SUCCESS) {
    vkFreeMemory(dev, slot.stagingMemory, nullptr);
    slot.stagingMemory = VK_NULL_HANDLE;
    vkDestroyBuffer(dev, slot.stagingBuffer, nullptr);
    slot.stagingBuffer = VK_NULL_HANDLE;
    return;
  }

  if (vkMapMemory(dev, slot.stagingMemory, 0, slot.stagingSize, 0,
                  &slot.mappedStaging) != VK_SUCCESS ||
      !slot.mappedStaging) {
    slot.mappedStaging = nullptr;
    return;
  }

  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
  if (vkCreateFence(dev, &fenceInfo, nullptr, &slot.fence) != VK_SUCCESS)
    return;

  VkCommandPool pool = XylaRenderer::instance().commandPool();
  if (pool == VK_NULL_HANDLE)
    return;

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = pool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 1;
  vkAllocateCommandBuffers(dev, &cmdAlloc, &slot.cmdBuffer);
}

bool VectorRenderer::copyStagingToTarget(VectorRenderSlot &slot) {
  VkDevice dev = XylaRenderer::instance().device();
  VkQueue queue = XylaRenderer::instance().computeQueue();
  if (dev == VK_NULL_HANDLE || queue == VK_NULL_HANDLE ||
      slot.cmdBuffer == VK_NULL_HANDLE)
    return false;

  vkWaitForFences(dev, 1, &slot.fence, VK_TRUE, UINT64_MAX);
  vkResetFences(dev, 1, &slot.fence);

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(slot.cmdBuffer, &beginInfo);

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout =
      slot.hasValidImage ? VK_IMAGE_LAYOUT_GENERAL : VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = slot.targetImage;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = slot.hasValidImage ? VK_ACCESS_SHADER_READ_BIT : 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(slot.cmdBuffer,
                       slot.hasValidImage ? VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
                                          : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  VkBufferImageCopy copyRegion{};
  copyRegion.bufferOffset = 0;
  copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  copyRegion.imageSubresource.layerCount = 1;
  copyRegion.imageExtent = {slot.width, slot.height, 1};

  vkCmdCopyBufferToImage(slot.cmdBuffer, slot.stagingBuffer, slot.targetImage,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(slot.cmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  vkEndCommandBuffer(slot.cmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &slot.cmdBuffer;

  vkQueueSubmit(queue, 1, &submitInfo, slot.fence);
  vkWaitForFences(dev, 1, &slot.fence, VK_TRUE, UINT64_MAX);
  slot.hasValidImage = true;
  return true;
}

void VectorRenderer::cleanup() {
  std::lock_guard<std::mutex> lock(m_mutex);
  destroySlot(m_textSlot);
  destroySlot(m_svgSlot);
  m_textCache = TextRenderCache();
  m_svgCache = SvgRenderCache();
}

QBrush VectorRenderer::resolveBrush(const GradientConfig &grad,
                                    const QColor &fallbackColor,
                                    const QRectF &targetRect,
                                    float opacityMultiplier) const {
  if (grad.type == GradientType::None || grad.stops.empty()) {
    QColor c = fallbackColor;
    c.setAlphaF(std::clamp(c.alphaF() * opacityMultiplier, 0.0f, 1.0f));
    return QBrush(c);
  }

  QRectF r = targetRect.isValid() ? targetRect : QRectF(-100, -100, 200, 200);

  if (grad.type == GradientType::Linear) {
    float rad = grad.angleDegrees * 3.14159265f / 180.0f;
    QPointF center = r.center();
    float halfDiag = std::hypot(r.width(), r.height()) * 0.5f;

    QPointF p1 =
        center - QPointF(std::cos(rad) * halfDiag, std::sin(rad) * halfDiag);
    QPointF p2 =
        center + QPointF(std::cos(rad) * halfDiag, std::sin(rad) * halfDiag);

    QLinearGradient qlg(p1, p2);
    for (const auto &s : grad.stops) {
      QColor c = s.color;
      c.setAlphaF(std::clamp(c.alphaF() * opacityMultiplier, 0.0f, 1.0f));
      qlg.setColorAt(std::clamp(s.position, 0.0f, 1.0f), c);
    }
    return QBrush(qlg);
  }

  if (grad.type == GradientType::Radial) {
    QPointF center = r.center();
    float radius =
        std::max(1.0, std::max(r.width(), r.height()) * grad.radialRadius);

    QRadialGradient qrg(center, radius);
    for (const auto &s : grad.stops) {
      QColor c = s.color;
      c.setAlphaF(std::clamp(c.alphaF() * opacityMultiplier, 0.0f, 1.0f));
      qrg.setColorAt(std::clamp(s.position, 0.0f, 1.0f), c);
    }
    return QBrush(qrg);
  }

  return QBrush(fallbackColor);
}

bool VectorRenderer::renderText(const TextComponent &comp,
                                const anim::AnimationPropertyTable &table,
                                int64_t localFrame, uint32_t width,
                                uint32_t height, VkImageView *outView) {
  if (width == 0 || height == 0 || !outView)
    return false;

  std::lock_guard<std::mutex> lock(m_mutex);
  ensureSlot(m_textSlot, width, height);

  if (!m_textSlot.mappedStaging || m_textSlot.targetView == VK_NULL_HANDLE)
    return false;

  // --- 1. PRE-EVALUATE TABLE ONCE PER FRAME (ZERO STRING QUERIES) ---
  vector::EvaluatedTextFrameState frameState;
  for (size_t i = 0; i < vector::kTextPropertyCount; ++i) {
    frameState.baseValues[i] =
        table.evaluateFloat(comp.handles.base[i], localFrame);
    frameState.animatorDeltas[i] =
        table.evaluateFloat(comp.handles.animatorDelta[i], localFrame);
  }
  frameState.animatorActive = (comp.animator && comp.animator->isEnabled());

  // --- 2. CACHE HIT CHECK ---
  if (m_textSlot.hasValidImage &&
      m_textCache.matches(comp, frameState, width, height)) {
    *outView = m_textSlot.targetView;
    return true;
  }

  const auto getProp = [&](vector::TextPropertyId id) {
    return frameState.baseValues[static_cast<size_t>(id)];
  };

  QFont baseFont(comp.fontFamily.isEmpty() ? QStringLiteral("Sans")
                                           : comp.fontFamily);
  baseFont.setPixelSize(
      std::max(1, static_cast<int>(getProp(vector::TextPropertyId::FontSize))));
  baseFont.setWeight(
      static_cast<QFont::Weight>(std::clamp(comp.fontWeight, 100, 900)));
  if (comp.italic) {
    baseFont.setStyle(QFont::StyleItalic);
  }

  float trackingVal = getProp(vector::TextPropertyId::Tracking);
  float lineSpacingVal = getProp(vector::TextPropertyId::LineSpacing);

  // --- 3. VECTOR LAYOUT ENGINE WITH RICH TEXT SPANS ---
  auto layout = vector::TextLayoutEngine::layoutString(
      comp.text, baseFont, trackingVal, lineSpacingVal,
      comp.horizontalAlignment, comp.verticalAlignment, comp.underline,
      comp.strikethrough, comp.richTextSpans);

  QImage canvas(static_cast<uchar *>(m_textSlot.mappedStaging), width, height,
                width * 4, QImage::Format_RGBA8888);
  canvas.fill(Qt::transparent);

  QPainter painter(&canvas);
  painter.setRenderHint(QPainter::Antialiasing, true);
  painter.setRenderHint(QPainter::TextAntialiasing, true);
  painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

  painter.translate(QPointF(width * 0.5, height * 0.5));

  const float baseFillR = getProp(vector::TextPropertyId::FillRed);
  const float baseFillG = getProp(vector::TextPropertyId::FillGreen);
  const float baseFillB = getProp(vector::TextPropertyId::FillBlue);
  const float baseFillA = getProp(vector::TextPropertyId::FillAlpha);

  const float baseStrokeW = getProp(vector::TextPropertyId::StrokeWidth);
  const float baseStrokeR = getProp(vector::TextPropertyId::StrokeRed);
  const float baseStrokeG = getProp(vector::TextPropertyId::StrokeGreen);
  const float baseStrokeB = getProp(vector::TextPropertyId::StrokeBlue);
  const float baseStrokeA = getProp(vector::TextPropertyId::StrokeAlpha);

  const float trimS =
      std::clamp(getProp(vector::TextPropertyId::TrimStart), 0.0f, 1.0f);
  const float trimE =
      std::clamp(getProp(vector::TextPropertyId::TrimEnd), 0.0f, 1.0f);
  const float trimO = getProp(vector::TextPropertyId::TrimOffset);
  const bool isTrimmed =
      (trimS > 0.001f || trimE < 0.999f || std::abs(trimO) > 0.001f);

  const size_t totalClusters = layout.clusters.size();
  const size_t totalTextLength =
      static_cast<size_t>(std::max<qsizetype>(1, comp.text.length()));

  for (size_t i = 0; i < totalClusters; ++i) {
    const auto &c = layout.clusters[i];

    // Check Rich Text Span Overrides for this cluster
    std::optional<QColor> spanFill;
    std::optional<QColor> spanStroke;
    std::optional<float> spanStrokeW;

    for (const auto &span : comp.richTextSpans) {
      if (c.charIndex >= span.startChar &&
          c.charIndex < (span.startChar + span.length)) {
        if (span.fillColor)
          spanFill = span.fillColor;
        if (span.strokeColor)
          spanStroke = span.strokeColor;
        if (span.strokeWidth)
          spanStrokeW = span.strokeWidth;
        break;
      }
    }

    // Evaluate Character Kinetic Deltas (Polymorphic, zero-string hot path)
    vector::EvaluatedCharacterTransform xform;
    if (frameState.animatorActive) {
      xform = comp.animator->evaluateCharacter(c.charIndex, totalTextLength,
                                               localFrame, comp.text,
                                               frameState, table);
    }

    painter.save();
    painter.translate(c.layoutPosition.x + xform.translation.x,
                      c.layoutPosition.y + xform.translation.y);

    if (std::abs(xform.rotationDegrees) > 0.001f) {
      painter.rotate(xform.rotationDegrees);
    }

    float finalScaleX = std::max(0.0f, 1.0f + xform.scale.x);
    float finalScaleY = std::max(0.0f, 1.0f + xform.scale.y);
    if (std::abs(finalScaleX - 1.0f) > 0.001f ||
        std::abs(finalScaleY - 1.0f) > 0.001f) {
      painter.scale(finalScaleX, finalScaleY);
    }

    // Fill Color: Span -> Base -> Animator Delta
    float fR = spanFill ? static_cast<float>(spanFill->redF()) : baseFillR;
    float fG = spanFill ? static_cast<float>(spanFill->greenF()) : baseFillG;
    float fB = spanFill ? static_cast<float>(spanFill->blueF()) : baseFillB;
    float fA = spanFill ? static_cast<float>(spanFill->alphaF()) : baseFillA;
    float finalAlpha = std::clamp(fA + xform.opacityDelta, 0.0f, 1.0f);

    QColor solidFillCol =
        QColor::fromRgbF(std::clamp(fR, 0.0f, 1.0f), std::clamp(fG, 0.0f, 1.0f),
                         std::clamp(fB, 0.0f, 1.0f), finalAlpha);

    QRectF fillBounds = layout.textBounds;
    fillBounds.translate(-c.layoutPosition.x, -c.layoutPosition.y);
    QBrush fillBrush =
        resolveBrush(comp.fillGradient, solidFillCol, fillBounds, finalAlpha);

    // Stroke Color: Span -> Base -> Animator Delta
    float effectiveStrokeW = spanStrokeW ? *spanStrokeW : baseStrokeW;
    float finalStrokeW =
        std::max(0.0f, effectiveStrokeW + xform.strokeWidthOffset);

    float sR =
        spanStroke ? static_cast<float>(spanStroke->redF()) : baseStrokeR;
    float sG =
        spanStroke ? static_cast<float>(spanStroke->greenF()) : baseStrokeG;
    float sB =
        spanStroke ? static_cast<float>(spanStroke->blueF()) : baseStrokeB;
    float sA =
        spanStroke ? static_cast<float>(spanStroke->alphaF()) : baseStrokeA;
    float finalStrokeAlpha = std::clamp(sA + xform.opacityDelta, 0.0f, 1.0f);

    bool strokeVisible = (finalStrokeW > 0.0001f) &&
                         (finalStrokeAlpha > 0.0001f) && (trimS < trimE);
    QColor solidStrokeCol =
        QColor::fromRgbF(std::clamp(sR, 0.0f, 1.0f), std::clamp(sG, 0.0f, 1.0f),
                         std::clamp(sB, 0.0f, 1.0f), finalStrokeAlpha);
    QBrush strokeBrush = resolveBrush(comp.strokeGradient, solidStrokeCol,
                                      fillBounds, finalStrokeAlpha);

    auto drawGlyphWithTrim = [&](const QPainterPath &path, float penWidth) {
      float effectiveW = std::max(0.5f, penWidth);
      if (!isTrimmed) {
        QPen pen(strokeBrush, effectiveW, Qt::SolidLine, Qt::RoundCap,
                 Qt::RoundJoin);
        painter.setPen(pen);
        painter.setBrush(Qt::NoBrush);
        painter.strokePath(path, pen);
        return;
      }
      auto subpaths = decomposeSubpaths(path);
      for (const auto &sub : subpaths) {
        qreal len = sub.length();
        if (len <= 0.001)
          continue;
        qreal drawLen = (trimE - trimS) * len;
        qreal gapLen = len - drawLen;
        QPen pen(strokeBrush, effectiveW, Qt::CustomDashLine, Qt::RoundCap,
                 Qt::RoundJoin);
        pen.setDashPattern(
            {drawLen / effectiveW, std::max(0.001, gapLen / effectiveW)});
        pen.setDashOffset(-(trimS + trimO) * len / effectiveW);
        painter.setPen(pen);
        painter.setBrush(Qt::NoBrush);
        painter.strokePath(sub, pen);
      }
    };

    if (strokeVisible) {
      drawGlyphWithTrim(c.rawPath, finalStrokeW);
    }
    painter.setPen(Qt::NoPen);
    painter.setBrush(fillBrush);
    painter.drawPath(c.rawPath);

    for (const auto &linePath : c.decorationLines) {
      painter.drawPath(linePath);
    }

    painter.restore();
  }

  painter.end();
  if (!copyStagingToTarget(m_textSlot))
    return false;

  m_textCache.store(comp, frameState, width, height);
  *outView = m_textSlot.targetView;
  return true;
}

bool VectorRenderer::renderSvg(const SvgComponent &comp, int64_t localFrame,
                               uint32_t width, uint32_t height,
                               VkImageView *outView) {
  if (width == 0 || height == 0 || !outView || !comp.document().isValid())
    return false;

  std::lock_guard<std::mutex> lock(m_mutex);
  ensureSlot(m_svgSlot, width, height);

  if (!m_svgSlot.mappedStaging || m_svgSlot.targetView == VK_NULL_HANDLE)
    return false;

  if (m_svgSlot.hasValidImage &&
      m_svgCache.matches(comp, localFrame, width, height)) {
    *outView = m_svgSlot.targetView;
    return true;
  }

  QImage canvas(static_cast<uchar *>(m_svgSlot.mappedStaging), width, height,
                width * 4, QImage::Format_RGBA8888);
  canvas.fill(Qt::transparent);

  QPainter painter(&canvas);
  painter.setRenderHint(QPainter::Antialiasing, true);
  painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

  QRectF vb = comp.document().viewBox();
  if (vb.width() > 0.0 && vb.height() > 0.0) {
    float scaleX = static_cast<float>(width) / static_cast<float>(vb.width());
    float scaleY = static_cast<float>(height) / static_cast<float>(vb.height());
    float fitScale = std::min(scaleX, scaleY);

    painter.translate((width - vb.width() * fitScale) * 0.5,
                      (height - vb.height() * fitScale) * 0.5);
    painter.scale(fitScale, fitScale);
    painter.translate(-vb.left(), -vb.top());
  }

  float strokeOverrideW = comp.strokeWidthOverride.evaluate(localFrame);

  for (const auto &shape : comp.document().shapes()) {
    painter.save();
    painter.setOpacity(shape.opacity);

    if (shape.path.hasFill()) {
      const auto &fc = shape.path.fillColor();
      painter.setBrush(QColor::fromRgbF(fc[0], fc[1], fc[2], fc[3]));
      painter.setPen(Qt::NoPen);
    } else {
      painter.setBrush(Qt::NoBrush);
    }

    if (shape.path.hasStroke()) {
      const auto &sc = shape.path.stroke().color;
      float w = (strokeOverrideW >= 0.0f) ? strokeOverrideW
                                          : shape.path.stroke().width;
      painter.setPen(QPen(QColor::fromRgbF(sc[0], sc[1], sc[2], sc[3]), w));
    }

    QPainterPath qPath;
    for (const auto &contour : shape.path.contours()) {
      for (size_t sIdx = 0; sIdx < contour.segments().size(); ++sIdx) {
        const auto &seg = contour.segments()[sIdx];
        if (sIdx == 0) {
          qPath.moveTo(seg.p0.x, seg.p0.y);
        }
        if (seg.type == vector::SegmentType::Line) {
          qPath.lineTo(seg.p1.x, seg.p1.y);
        } else if (seg.type == vector::SegmentType::Quadratic) {
          qPath.quadTo(seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y);
        } else if (seg.type == vector::SegmentType::Cubic) {
          qPath.cubicTo(seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y, seg.p3.x,
                        seg.p3.y);
        }
      }
      if (contour.isClosed()) {
        qPath.closeSubpath();
      }
    }

    painter.drawPath(qPath);
    painter.restore();
  }

  painter.end();

  if (!copyStagingToTarget(m_svgSlot))
    return false;

  m_svgCache.store(comp, localFrame, width, height);
  *outView = m_svgSlot.targetView;
  return true;
}

// =============================================================================
// CACHE IMPLEMENTATIONS
// =============================================================================

bool TextRenderCache::matches(const TextComponent &comp,
                              const vector::EvaluatedTextFrameState &state,
                              uint32_t w, uint32_t h) const {
  if (w != width || h != height || comp.text != text ||
      comp.fontFamily != fontFamily)
    return false;
  if (comp.fontWeight != fontWeight || comp.italic != italic ||
      comp.underline != underline || comp.strikethrough != strikethrough)
    return false;
  if (comp.horizontalAlignment != hAlign || comp.verticalAlignment != vAlign)
    return false;
  if (comp.strokePosition != strokePosition)
    return false;
  if (comp.fillGradient.serialize() != fillGradientData ||
      comp.strokeGradient.serialize() != strokeGradientData)
    return false;

  if (state.animatorActive != frameState.animatorActive)
    return false;

  for (size_t i = 0; i < vector::kTextPropertyCount; ++i) {
    if (std::abs(state.baseValues[i] - frameState.baseValues[i]) > 0.001f)
      return false;
    if (std::abs(state.animatorDeltas[i] - frameState.animatorDeltas[i]) >
        0.001f)
      return false;
  }

  return true;
}

void TextRenderCache::store(const TextComponent &comp,
                            const vector::EvaluatedTextFrameState &state,
                            uint32_t w, uint32_t h) {
  text = comp.text;
  fontFamily = comp.fontFamily;
  fontWeight = comp.fontWeight;
  italic = comp.italic;
  underline = comp.underline;
  strikethrough = comp.strikethrough;
  hAlign = comp.horizontalAlignment;
  vAlign = comp.verticalAlignment;
  strokePosition = comp.strokePosition;

  fillGradientData = comp.fillGradient.serialize();
  strokeGradientData = comp.strokeGradient.serialize();

  frameState = state;
  width = w;
  height = h;
}

bool SvgRenderCache::matches(const SvgComponent &comp, int64_t frame,
                             uint32_t w, uint32_t h) const {
  if (w != width || h != height || comp.sourcePath() != sourcePath)
    return false;
  if (std::abs(comp.strokeWidthOverride.evaluate(frame) - strokeWidthOverride) >
      0.001f)
    return false;
  if (std::abs(comp.trimStart.evaluate(frame) - trimStart) > 0.001f)
    return false;
  if (std::abs(comp.trimEnd.evaluate(frame) - trimEnd) > 0.001f)
    return false;
  if (std::abs(comp.trimOffset.evaluate(frame) - trimOffset) > 0.001f)
    return false;
  return true;
}

void SvgRenderCache::store(const SvgComponent &comp, int64_t frame, uint32_t w,
                           uint32_t h) {
  sourcePath = comp.sourcePath();
  strokeWidthOverride = comp.strokeWidthOverride.evaluate(frame);
  trimStart = comp.trimStart.evaluate(frame);
  trimEnd = comp.trimEnd.evaluate(frame);
  trimOffset = comp.trimOffset.evaluate(frame);
  width = w;
  height = h;
}

} // namespace xyla::render
