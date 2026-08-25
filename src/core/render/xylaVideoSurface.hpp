#pragma once

#include <QQuickItem>
#include <QSGSimpleTextureNode>

namespace xyla {

class XylaVideoSurface : public QQuickItem {
  Q_OBJECT

public:
  explicit XylaVideoSurface(QQuickItem *parent = nullptr);

public slots:
  void onFrameComposited();

protected:
  QSGNode *updatePaintNode(QSGNode *oldNode,
                           UpdatePaintNodeData *data) override;
};

} // namespace xyla
