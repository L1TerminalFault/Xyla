#include "mediaThumbnailProvider.hpp"
#include "core/media/thumbnailGenerator.hpp"
#include <QFileInfo>
#include <QUrl>
#include <QUrlQuery>

namespace xyla {

MediaThumbnailProvider::MediaThumbnailProvider(MediaPool *mediaPool)
    : QQuickImageProvider(QQuickImageProvider::Image), m_mediaPool(mediaPool) {
  m_cache.setMaxCost(200);
}

QImage MediaThumbnailProvider::requestImage(const QString &id, QSize *size,
                                            const QSize &requestedSize) {
  {
    QMutexLocker locker(&m_cacheMutex);
    if (m_cache.contains(id)) {
      QImage cached = *m_cache.object(id);
      if (size)
        *size = cached.size();
      return cached;
    }
  }

  QUrl url(QString("image://thumbnails/%1").arg(id));
  QString rawTarget = url.path();
  if (rawTarget.startsWith('/')) {
    rawTarget.remove(0, 1);
  }

  int targetWidth = requestedSize.width() > 0 ? requestedSize.width() : 240;
  double timePos = -1.0;

  QUrlQuery query(url.query());
  if (query.hasQueryItem("time")) {
    timePos = query.queryItemValue("time").toDouble();
  }
  if (query.hasQueryItem("width")) {
    targetWidth = query.queryItemValue("width").toInt();
  }

  QString resolvedFilePath = rawTarget;
  if (m_mediaPool) {
    auto asset = m_mediaPool->getAsset(rawTarget);
    if (asset) {
      resolvedFilePath = asset->metadata().filePath;
    }
  }

  if (resolvedFilePath.startsWith("file://")) {
    resolvedFilePath = QUrl(resolvedFilePath).toLocalFile();
  }

  if (resolvedFilePath.isEmpty() || !QFileInfo::exists(resolvedFilePath)) {
    return {};
  }

  QImage img = ThumbnailGenerator::extractThumbnail(resolvedFilePath,
                                                    targetWidth, timePos);

  if (!img.isNull()) {
    if (size)
      *size = img.size();

    QMutexLocker locker(&m_cacheMutex);
    m_cache.insert(id, new QImage(img), 1);
  }

  return img;
}

} // namespace xyla
