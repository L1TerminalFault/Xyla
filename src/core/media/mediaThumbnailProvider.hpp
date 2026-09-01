#pragma once

#include "core/media/mediaPool.hpp"
#include <QCache>
#include <QMutex>
#include <QQuickImageProvider>

namespace xyla {

class MediaThumbnailProvider : public QQuickImageProvider {
public:
  explicit MediaThumbnailProvider(MediaPool *mediaPool = nullptr);
  ~MediaThumbnailProvider() override = default;

  QImage requestImage(const QString &id, QSize *size,
                      const QSize &requestedSize) override;

private:
  MediaPool *m_mediaPool{nullptr};
  QCache<QString, QImage> m_cache;
  QMutex m_cacheMutex;
};

} // namespace xyla
