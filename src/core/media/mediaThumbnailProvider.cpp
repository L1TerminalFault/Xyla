#include "core/media/mediaThumbnailProvider.hpp"
#include "core/media/thumbnailGenerator.hpp"
#include <QUrl>
#include <QUrlQuery>

namespace xyla {

MediaThumbnailProvider::MediaThumbnailProvider()
    : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage MediaThumbnailProvider::requestImage(const QString &id, QSize *size,
                                            const QSize &requestedSize) {
  QUrl url(QString("image://thumbnails/%1").arg(id));
  QString filePath = url.path();

  int targetWidth = requestedSize.width() > 0 ? requestedSize.width() : 320;
  double timePos = -1.0;

  QUrlQuery query(url.query());
  if (query.hasQueryItem("time")) {
    timePos = query.queryItemValue("time").toDouble();
  }
  if (query.hasQueryItem("width")) {
    targetWidth = query.queryItemValue("width").toInt();
  }

  QImage img =
      ThumbnailGenerator::extractThumbnail(filePath, targetWidth, timePos);

  if (size && !img.isNull()) {
    *size = img.size();
  }

  return img;
}

} // namespace xyla
