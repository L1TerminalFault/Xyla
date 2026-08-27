#include "xylaVideoSurface.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QQuickWindow>
#include <QRectF>
#include <QSGDynamicTexture>
#include <QSGSimpleTextureNode>

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
    // Reusing custom texture pointers requires node->setOwnsTexture(false)
    node->setOwnsTexture(false);
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

  // Reuse texture handle when dimensions match to avoid VRAM reallocation
  // thrashing
  QSGTexture *existingTex = node->texture();
  if (existingTex && existingTex->textureSize() == img.size()) {
    if (auto *dynamicTex = qobject_cast<QSGDynamicTexture *>(existingTex)) {
      dynamicTex->updateTexture();
    } else {
      delete existingTex;
      node->setTexture(window()->createTextureFromImage(img));
    }
  } else {
    delete existingTex;
    node->setTexture(window()->createTextureFromImage(img));
  }

  // Calculate aspect-ratio fit
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
