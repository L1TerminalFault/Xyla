#pragma once

#include <QQuickItem>
#include <QSGSimpleTextureNode>

namespace xyla {

class XylaVideoSurface : public QQuickItem {
  Q_OBJECT

public:
  enum SurfaceType { Timeline = 0, Clip = 1 };
  Q_ENUM(SurfaceType)
  Q_PROPERTY(SurfaceType surfaceType READ surfaceType WRITE setSurfaceType
                 NOTIFY surfaceTypeChanged)

  SurfaceType surfaceType() const { return m_surfaceType; }
  void setSurfaceType(SurfaceType type);
  explicit XylaVideoSurface(QQuickItem *parent = nullptr);

public slots:
  void onFrameComposited();

signals:
  void surfaceTypeChanged();

protected:
  QSGNode *updatePaintNode(QSGNode *oldNode,
                           UpdatePaintNodeData *data) override;

private:
  SurfaceType m_surfaceType{Timeline};
};

} // namespace xyla
