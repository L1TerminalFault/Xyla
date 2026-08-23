#pragma once

#include <QQuickImageProvider>

namespace xyla {

class MediaThumbnailProvider : public QQuickImageProvider {
public:
  MediaThumbnailProvider();

  QImage requestImage(const QString &id, QSize *size,
                      const QSize &requestedSize) override;
};

} // namespace xyla
