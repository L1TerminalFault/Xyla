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

  QImage img = render::XylaRenderer::instance().getLatestRenderedFrameImage();

  if (img.isNull()) {
    if (!node->texture()) {
      QImage dummy(1, 1, QImage::Format_RGBA8888);
      dummy.fill(Qt::black);
      node->setTexture(window()->createTextureFromImage(dummy));
    }
    node->setRect(boundingRect());
    return node;
  }

  // Create texture with TextureHasAlphaChannel turned off for faster blitting
  QSGTexture *texture = window()->createTextureFromImage(
      img, QQuickWindow::TextureIsOpaque);
  if (texture) {
    node->setTexture(texture);
  }

  // --- PERFECT ASPECT RATIO PRESERVATION ---
  double viewportW = std::floor(boundingRect().width());
  double viewportH = std::floor(boundingRect().height());
  double vidW = static_cast<double>(img.width());
  double vidH = static_cast<double>(img.height());

  if (viewportW <= 0.0 || viewportH <= 0.0 || vidW <= 0.0 || vidH <= 0.0) {
    node->setRect(boundingRect());
    return node;
  }

  double scaleX = viewportW / vidW;
  double scaleY = viewportH / vidH;
  double scale = std::min(scaleX, scaleY);

  double targetW = std::round(vidW * scale);
  double targetH = std::round(vidH * scale);
  double targetX = std::round((viewportW - targetW) / 2.0);
  double targetY = std::round((viewportH - targetH) / 2.0);

  node->setRect(QRectF(targetX, targetY, targetW, targetH));
  node->setFiltering(QSGTexture::Linear);

  return node;
}

} // namespace xyla
