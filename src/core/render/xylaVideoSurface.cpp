#include "xylaVideoSurface.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QQuickWindow>
#include <QRectF>
#include <QSGTexture>

namespace xyla {

XylaVideoSurface::XylaVideoSurface(QQuickItem *parent) : QQuickItem(parent) {
  setFlag(ItemHasContents, true);
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

  QImage img = render::XylaRenderer::instance().latestFrameImage();
  if (img.isNull()) {
    if (!node->texture()) {
      QImage dummy(1, 1, QImage::Format_RGBA8888);
      dummy.fill(Qt::black);
      node->setTexture(window()->createTextureFromImage(dummy));
      node->setRect(boundingRect());
    }
    return node;
  }

  node->setTexture(window()->createTextureFromImage(img));

  double viewportW = boundingRect().width();
  double viewportH = boundingRect().height();
  double imgW = img.width() > 0 ? img.width() : 1920.0;
  double imgH = img.height() > 0 ? img.height() : 1080.0;

  double scale = std::min(viewportW / imgW, viewportH / imgH);
  double targetW = imgW * scale;
  double targetH = imgH * scale;
  double targetX = (viewportW - targetW) / 2.0;
  double targetY = (viewportH - targetH) / 2.0;

  node->setRect(QRectF(targetX, targetY, targetW, targetH));
  return node;
}

} // namespace xyla
