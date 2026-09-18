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

// Helper: decomposes complex glyph paths (with outer outlines and inner holes)
// into discrete subpaths so trim path percentage calculations are
// mathematically exact.
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

  XylaRenderer::instance().allocateRgbaTexture(
      width, height, &slot.targetImage, &slot.targetMemory, &slot.targetView);

  VkDevice dev = XylaRenderer::instance().device();
  VkPhysicalDevice physDev = XylaRenderer::instance().physicalDevice();
  slot.stagingSize = static_cast<size_t>(width) * height * 4;

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = slot.stagingSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  vkCreateBuffer(dev, &bufInfo, nullptr, &slot.stagingBuffer);

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

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = hostMemType;
  vkAllocateMemory(dev, &allocInfo, nullptr, &slot.stagingMemory);
  vkBindBufferMemory(dev, slot.stagingBuffer, slot.stagingMemory, 0);

  vkMapMemory(dev, slot.stagingMemory, 0, slot.stagingSize, 0,
              &slot.mappedStaging);

  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
  vkCreateFence(dev, &fenceInfo, nullptr, &slot.fence);

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = XylaRenderer::instance().commandPool();
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

  // Synchronize fence before returning to prevent GPU read-after-write tearing
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

bool VectorRenderer::renderText(const TextComponent &comp, int64_t localFrame,
                                uint32_t width, uint32_t height,
                                VkImageView *outView) {
  if (width == 0 || height == 0 || !outView)
    return false;

  std::lock_guard<std::mutex> lock(m_mutex);
  ensureSlot(m_textSlot, width, height);

  if (m_textSlot.hasValidImage &&
      m_textCache.matches(comp, localFrame, width, height)) {
    *outView = m_textSlot.targetView;
    return true;
  }

  // --- 1. RESOLVE FONT WITH WEIGHT, ITALIC, AND SIZING ---
  QFont font(comp.fontFamily.isEmpty() ? QStringLiteral("Sans")
                                       : comp.fontFamily);
  font.setStyleHint(QFont::SansSerif);
  font.setHintingPreference(QFont::PreferFullHinting);
  font.setPixelSize(
      std::max(1, static_cast<int>(comp.fontSize.evaluate(localFrame))));
  font.setWeight(
      static_cast<QFont::Weight>(std::clamp(comp.fontWeight, 100, 900)));
  if (comp.italic) {
    font.setStyle(QFont::StyleItalic);
  }

  float trackingVal = comp.tracking.evaluate(localFrame);
  float lineSpacingVal = comp.lineSpacing.evaluate(localFrame);

  // --- 2. VECTOR LAYOUT ENGINE ---
  auto layout = vector::TextLayoutEngine::layoutString(
      comp.text, font, trackingVal, lineSpacingVal, comp.horizontalAlignment,
      comp.verticalAlignment, comp.underline, comp.strikethrough);

  QImage canvas(static_cast<uchar *>(m_textSlot.mappedStaging), width, height,
                width * 4, QImage::Format_RGBA8888);
  canvas.fill(Qt::transparent);

  QPainter painter(&canvas);
  painter.setRenderHint(QPainter::Antialiasing, true);
  painter.setRenderHint(QPainter::TextAntialiasing, true);
  painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

  QPointF centerOffset(width * 0.5, height * 0.5);
  painter.translate(centerOffset);

  float baseFillR = comp.fillRed.evaluate(localFrame);
  float baseFillG = comp.fillGreen.evaluate(localFrame);
  float baseFillB = comp.fillBlue.evaluate(localFrame);
  float baseFillA = comp.fillAlpha.evaluate(localFrame);

  float baseStrokeW = comp.strokeWidth.evaluate(localFrame);
  float baseStrokeR = comp.strokeRed.evaluate(localFrame);
  float baseStrokeG = comp.strokeGreen.evaluate(localFrame);
  float baseStrokeB = comp.strokeBlue.evaluate(localFrame);
  float baseStrokeA = comp.strokeAlpha.evaluate(localFrame);

  float trimS = std::clamp(comp.trimStart.evaluate(localFrame), 0.0f, 1.0f);
  float trimE = std::clamp(comp.trimEnd.evaluate(localFrame), 0.0f, 1.0f);
  float trimO = comp.trimOffset.evaluate(localFrame);
  bool isTrimmed =
      (trimS > 0.001f || trimE < 0.999f || std::abs(trimO) > 0.001f);

  size_t totalClusters = layout.clusters.size();
  size_t totalTextLength =
      static_cast<size_t>(std::max<qsizetype>(1, comp.text.length()));

  for (size_t i = 0; i < totalClusters; ++i) {
    const auto &c = layout.clusters[i];

    // --- 3. ACCUMULATE KINETIC DELTAS ---
    vector::EvaluatedCharacterTransform xform;
    for (const auto &animator : comp.animators) {
      if (!animator.enabled)
        continue;

      auto sub = animator.evaluateCharacter(c.charIndex, totalTextLength,
                                            localFrame, comp.text);
      xform.translation = xform.translation + sub.translation;
      xform.scale = xform.scale + sub.scale;
      xform.rotationDegrees += sub.rotationDegrees;
      xform.opacityDelta += sub.opacityDelta;
      xform.trackingOffset += sub.trackingOffset;
      xform.strokeWidthOffset += sub.strokeWidthOffset;
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

    float finalAlpha = std::clamp(baseFillA + xform.opacityDelta, 0.0f, 1.0f);
    QColor solidFillCol = QColor::fromRgbF(
        std::clamp(baseFillR, 0.0f, 1.0f), std::clamp(baseFillG, 0.0f, 1.0f),
        std::clamp(baseFillB, 0.0f, 1.0f), finalAlpha);

    // --- 4. MULTI-POINT GRADIENT FILL RESOLUTION ---
    QRectF fillBounds = layout.textBounds;
    if (comp.fillGradient.scope == GradientScope::PerLine &&
        c.lineIndex < layout.lineBounds.size()) {
      fillBounds = layout.lineBounds[c.lineIndex];
    } else if (comp.fillGradient.scope == GradientScope::PerWord &&
               c.wordIndex < layout.wordBounds.size()) {
      fillBounds = layout.wordBounds[c.wordIndex];
    } else if (comp.fillGradient.scope == GradientScope::PerCharacter) {
      fillBounds = c.bounds;
    }
    fillBounds.translate(-c.layoutPosition.x, -c.layoutPosition.y);

    QBrush fillBrush =
        resolveBrush(comp.fillGradient, solidFillCol, fillBounds, finalAlpha);

    float finalStrokeW = std::max(0.0f, baseStrokeW + xform.strokeWidthOffset);
    float finalStrokeAlpha =
        std::clamp(baseStrokeA + xform.opacityDelta, 0.0f, 1.0f);
    bool strokeVisible = (finalStrokeW > 0.0001f) &&
                         (finalStrokeAlpha > 0.0001f) && (trimS < trimE);

    // --- 5. MULTI-POINT GRADIENT STROKE RESOLUTION ---
    QRectF strokeBounds = fillBounds;
    QColor solidStrokeCol =
        QColor::fromRgbF(std::clamp(baseStrokeR, 0.0f, 1.0f),
                         std::clamp(baseStrokeG, 0.0f, 1.0f),
                         std::clamp(baseStrokeB, 0.0f, 1.0f), finalStrokeAlpha);
    QBrush strokeBrush = resolveBrush(comp.strokeGradient, solidStrokeCol,
                                      strokeBounds, finalStrokeAlpha);

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
      if (comp.strokePosition == StrokePosition::Outer) {
        if (solidFillCol.alphaF() >= 0.999f &&
            comp.fillGradient.type == GradientType::None) {
          drawGlyphWithTrim(c.rawPath, finalStrokeW * 2.0f);
          painter.setPen(Qt::NoPen);
          painter.setBrush(fillBrush);
          painter.drawPath(c.rawPath);
        } else {
          QPainterPathStroker stroker;
          stroker.setWidth(finalStrokeW * 2.0f);
          stroker.setCapStyle(Qt::RoundCap);
          stroker.setJoinStyle(Qt::RoundJoin);
          QPainterPath strokeOutline = stroker.createStroke(c.rawPath);
          QPainterPath outerOnly = strokeOutline.subtracted(c.rawPath);

          painter.save();
          painter.setClipPath(outerOnly, Qt::IntersectClip);
          drawGlyphWithTrim(c.rawPath, finalStrokeW * 2.0f);
          painter.restore();

          painter.setPen(Qt::NoPen);
          painter.setBrush(fillBrush);
          painter.drawPath(c.rawPath);
        }
      } else if (comp.strokePosition == StrokePosition::Inner) {
        painter.setPen(Qt::NoPen);
        painter.setBrush(fillBrush);
        painter.drawPath(c.rawPath);

        painter.save();
        painter.setClipPath(c.rawPath, Qt::IntersectClip);
        drawGlyphWithTrim(c.rawPath, finalStrokeW * 2.0f);
        painter.restore();
      } else {
        painter.setPen(Qt::NoPen);
        painter.setBrush(fillBrush);
        painter.drawPath(c.rawPath);
        drawGlyphWithTrim(c.rawPath, finalStrokeW);
      }
    } else {
      painter.setPen(Qt::NoPen);
      painter.setBrush(fillBrush);
      painter.drawPath(c.rawPath);
    }

    // --- 6. DRAW VECTOR DECORATIONS (Underline & Strikethrough) ---
    if (!c.decorationLines.empty()) {
      painter.setPen(Qt::NoPen);
      painter.setBrush(fillBrush);
      for (const auto &linePath : c.decorationLines) {
        painter.drawPath(linePath);
      }
    }

    painter.restore();
  }

  painter.end();

  if (!copyStagingToTarget(m_textSlot))
    return false;

  m_textCache.store(comp, localFrame, width, height);
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

bool TextRenderCache::matches(const TextComponent &comp, int64_t frame,
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

  if (comp.fillGradient.serialize() != fillGradientData ||
      comp.strokeGradient.serialize() != strokeGradientData)
    return false;

  if (comp.animators.size() != animatorsState.size())
    return false;

  for (size_t i = 0; i < comp.animators.size(); ++i) {
    const auto &a = comp.animators[i];
    const auto &cachedA = animatorsState[i];

    if (a.enabled != cachedA.enabled)
      return false;
    if (!a.enabled)
      continue;

    if (a.deltas.size() != cachedA.deltas.size())
      return false;
    for (size_t d = 0; d < a.deltas.size(); ++d) {
      if (a.deltas[d].propertyId != cachedA.deltas[d].propertyId ||
          std::abs(a.deltas[d].value - cachedA.deltas[d].value) > 0.0001f)
        return false;
    }

    if (a.selectors.size() != cachedA.selectors.size())
      return false;
    for (size_t s = 0; s < a.selectors.size(); ++s) {
      const auto &sel = a.selectors[s];
      const auto &cachedSel = cachedA.selectors[s];

      if (sel.shape != cachedSel.shape || sel.basedOn != cachedSel.basedOn ||
          sel.combine != cachedSel.combine ||
          sel.randomize != cachedSel.randomize ||
          sel.randomSeed != cachedSel.randomSeed ||
          sel.chunkSize != cachedSel.chunkSize ||
          sel.customSeparator != cachedSel.customSeparator ||
          sel.regexPattern != cachedSel.regexPattern)
        return false;

      if (std::abs(sel.start.evaluate(frame) - cachedSel.start) > 0.0005f ||
          std::abs(sel.end.evaluate(frame) - cachedSel.end) > 0.0005f ||
          std::abs(sel.offset.evaluate(frame) - cachedSel.offset) > 0.0005f)
        return false;
    }
  }

  return true;
}

void TextRenderCache::store(const TextComponent &comp, int64_t frame,
                            uint32_t w, uint32_t h) {
  text = comp.text;
  fontFamily = comp.fontFamily;
  fontWeight = comp.fontWeight;
  italic = comp.italic;
  underline = comp.underline;
  strikethrough = comp.strikethrough;
  hAlign = comp.horizontalAlignment;
  vAlign = comp.verticalAlignment;

  fontSize = comp.fontSize.evaluate(frame);
  tracking = comp.tracking.evaluate(frame);
  lineSpacing = comp.lineSpacing.evaluate(frame);
  strokePosition = comp.strokePosition;
  strokeWidth = comp.strokeWidth.evaluate(frame);

  trimStart = comp.trimStart.evaluate(frame);
  trimEnd = comp.trimEnd.evaluate(frame);
  trimOffset = comp.trimOffset.evaluate(frame);

  fillColor[0] = comp.fillRed.evaluate(frame);
  fillColor[1] = comp.fillGreen.evaluate(frame);
  fillColor[2] = comp.fillBlue.evaluate(frame);
  fillColor[3] = comp.fillAlpha.evaluate(frame);
  fillGradientData = comp.fillGradient.serialize();

  strokeColor[0] = comp.strokeRed.evaluate(frame);
  strokeColor[1] = comp.strokeGreen.evaluate(frame);
  strokeColor[2] = comp.strokeBlue.evaluate(frame);
  strokeColor[3] = comp.strokeAlpha.evaluate(frame);
  strokeGradientData = comp.strokeGradient.serialize();

  width = w;
  height = h;

  animatorsState.clear();
  animatorsState.reserve(comp.animators.size());
  for (const auto &a : comp.animators) {
    CachedAnimatorState cas;
    cas.enabled = a.enabled;
    cas.deltas = a.deltas;

    cas.selectors.reserve(a.selectors.size());
    for (const auto &sel : a.selectors) {
      CachedRangeSelectorState crs;
      crs.start = sel.start.evaluate(frame);
      crs.end = sel.end.evaluate(frame);
      crs.offset = sel.offset.evaluate(frame);
      crs.shape = sel.shape;
      crs.combine = sel.combine;
      crs.basedOn = sel.basedOn;
      crs.chunkSize = sel.chunkSize;
      crs.customSeparator = sel.customSeparator;
      crs.regexPattern = sel.regexPattern;
      crs.randomize = sel.randomize;
      crs.randomSeed = sel.randomSeed;
      cas.selectors.push_back(std::move(crs));
    }
    animatorsState.push_back(std::move(cas));
  }
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
