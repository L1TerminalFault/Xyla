#include "xylaVideoSurface.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QQuickWindow>
#include <QRectF>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <algorithm>
#include <cmath>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

namespace xyla {

XylaVideoSurface::XylaVideoSurface(QQuickItem *parent) : QQuickItem(parent) {
  setFlag(ItemHasContents, true);

  connect(&render::XylaRenderer::instance(),
          &render::XylaRenderer::frameRendered, this,
          &XylaVideoSurface::onFrameComposited, Qt::QueuedConnection);

  connect(
      &render::XylaRenderer::instance(),
      &render::XylaRenderer::clipFrameRendered, this,
      [this]() {
        if (m_surfaceType == Clip)
          update();
      },
      Qt::QueuedConnection);
}

void XylaVideoSurface::onFrameComposited() { update(); }

void XylaVideoSurface::setSurfaceType(SurfaceType type) {
  if (m_surfaceType != type) {
    m_surfaceType = type;
    emit surfaceTypeChanged();
    update();
  }
}

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

  // Branch snapshot based on surfaceType
  auto snap = (m_surfaceType == Clip)
                  ? render::XylaRenderer::instance().currentClipSnapshot()
                  : render::XylaRenderer::instance().currentOutputSnapshot();

  if (snap.image == VK_NULL_HANDLE || snap.width == 0 || snap.height == 0) {
    QImage dummy(1, 1, QImage::Format_RGBA8888);
    dummy.fill(Qt::black);
    QSGTexture *dummyTex = window()->createTextureFromImage(dummy);
    node->setTexture(dummyTex);
    node->setFiltering(QSGTexture::Nearest);
    node->setRect(boundingRect());
    return node;
  }

  // Wrap the Vulkan image as a QSGTexture
  QSGTexture *texture = QNativeInterface::QSGVulkanTexture::fromNative(
      snap.image, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, window(),
      QSize(static_cast<int>(snap.width), static_cast<int>(snap.height)));

  if (texture) {
    // High-quality linear texture filtering
    texture->setFiltering(QSGTexture::Linear);
    texture->setMipmapFiltering(QSGTexture::Linear);

    node->setTexture(texture);
    node->setFiltering(QSGTexture::Linear);
  }

  double viewportW = boundingRect().width();
  double viewportH = boundingRect().height();
  double w = static_cast<double>(snap.width);
  double h = static_cast<double>(snap.height);

  double scale =
      std::min(viewportW / std::max(w, 1.0), viewportH / std::max(h, 1.0));

  // Pixel-aligned integer bounding box prevents sub-pixel rasterization blur
  double targetW = std::floor(w * scale);
  double targetH = std::floor(h * scale);
  double targetX = std::floor((viewportW - targetW) / 2.0);
  double targetY = std::floor((viewportH - targetH) / 2.0);

  node->setRect(QRectF(targetX, targetY, targetW, targetH));
  return node;
}

} // namespace xyla
