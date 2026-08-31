#include "xylaVideoSurface.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QQuickWindow>
#include <QRectF>
#include <QSGSimpleTextureNode>
#include <algorithm>
#include <vulkan/vulkan.h>

namespace xyla {

XylaVideoSurface::XylaVideoSurface(QQuickItem *parent) : QQuickItem(parent) {
  setFlag(ItemHasContents, true);

  connect(&render::XylaRenderer::instance(),
          &render::XylaRenderer::frameRendered, this,
          &XylaVideoSurface::onFrameComposited, Qt::QueuedConnection);
}

void XylaVideoSurface::onFrameComposited() { update(); }

QSGNode *XylaVideoSurface::updatePaintNode(QSGNode *oldNode,
                                           UpdatePaintNodeData *data) {
  Q_UNUSED(data);

  if (!window()) {
    delete oldNode;
    return nullptr;
  }

  auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);
  if (!node) {
    node = new QSGSimpleTextureNode();
    node->setOwnsTexture(true);
  }

  // Atomic snapshot read under a single lock guard (Prevents torn state reads)
  auto snap = render::XylaRenderer::instance().currentOutputSnapshot();

  if (snap.image == VK_NULL_HANDLE || snap.width == 0 || snap.height == 0) {
    QImage dummy(1, 1, QImage::Format_RGBA8888);
    dummy.fill(Qt::black);
    node->setTexture(window()->createTextureFromImage(dummy));
    node->setRect(boundingRect());
    return node;
  }

  // Qt 6 Native Vulkan Zero-Copy Texture Import
  QSGTexture *texture = QNativeInterface::QSGVulkanTexture::fromNative(
      snap.image, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, window(),
      QSize(static_cast<int>(snap.width), static_cast<int>(snap.height)));

  if (texture) {
    node->setTexture(texture);
  }

  // Aspect-ratio fit calculation (letterbox / pillarbox)
  double viewportW = boundingRect().width();
  double viewportH = boundingRect().height();
  double w = static_cast<double>(snap.width);
  double h = static_cast<double>(snap.height);

  double scale =
      std::min(viewportW / std::max(w, 1.0), viewportH / std::max(h, 1.0));
  double targetW = w * scale;
  double targetH = h * scale;
  double targetX = (viewportW - targetW) / 2.0;
  double targetY = (viewportH - targetH) / 2.0;

  node->setRect(QRectF(targetX, targetY, targetW, targetH));
  return node;
}

} // namespace xyla
