#include "xylaVideoSurface.hpp"
#include "core/render/xylaRenderer.hpp"
#include <QQuickWindow>
#include <QSGTexture>

namespace xyla {

// Custom Qt Quick viewport node constructor
XylaVideoSurface::XylaVideoSurface(QQuickItem *parent) : QQuickItem(parent) {
  setFlag(ItemHasContents, true);
}

// Triggers Scene Graph repaint when video frame composite completes
void XylaVideoSurface::onFrameComposited() { update(); }

// Draws composited video frame or fallback texture onto Scene Graph node
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
    }
  } else {
    node->setTexture(window()->createTextureFromImage(img));
  }

  node->setRect(boundingRect());
  return node;
}

} // namespace xyla
