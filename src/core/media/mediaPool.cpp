#include "mediaPool.hpp"
#include "core/log/logger.hpp"
#include "decoderRegistry.hpp"
#include <QFileInfo>
#include <QUuid>
#include <qurl.h>
namespace {

QString sanitizeFilePath(const QString &rawInput) {
  if (rawInput.trimmed().isEmpty()) {
    return {};
  }

  QString localPath;

  QUrl url(rawInput);
  if (url.isValid() && url.isLocalFile()) {
    localPath = url.toLocalFile();
  } else if (rawInput.startsWith("file://", Qt::CaseInsensitive)) {
    localPath = QUrl(rawInput).toLocalFile();
  } else {
    localPath = rawInput;
  }

  localPath = localPath.trimmed();
  if (localPath.isEmpty()) {
    return {};
  }

  QFileInfo fileInfo(localPath);

  QString canonicalPath = fileInfo.canonicalFilePath();
  if (canonicalPath.isEmpty()) {
    canonicalPath = fileInfo.absoluteFilePath();
  }

  QFileInfo canonicalInfo(canonicalPath);

  if (!canonicalInfo.exists() || !canonicalInfo.isFile() ||
      !canonicalInfo.isReadable()) {
    return {};
  }

  return canonicalPath;
}

} // namespace

namespace xyla {

MediaPool::MediaPool(QObject *parent) : QObject(parent) {
  // Connect asynchronous worker engine results back to main thread handlers
  connect(&m_probeEngine, &MediaProbeEngine::probeCompleted, this,
          &MediaPool::onProbeCompleted, Qt::QueuedConnection);
}

void MediaPool::importFilesAsync(const QStringList &filePaths,
                                 const QString &targetBinId) {
  if (filePaths.isEmpty())
    return;

  QStringList sanitizedPaths;
  QSet<QString> seenPaths; // Deduplicate paths in the same import batch

  for (const QString &rawPath : filePaths) {
    QString cleanPath = sanitizeFilePath(rawPath);
    if (!cleanPath.isEmpty() && !seenPaths.contains(cleanPath)) {
      seenPaths.insert(cleanPath);
      sanitizedPaths.append(cleanPath);
    } else if (cleanPath.isEmpty()) {
      XYLA_LOG_WARN("MediaPool", "Skipping invalid or unreadable path: " +
                                     rawPath.toStdString());
    }
  }

  if (sanitizedPaths.isEmpty()) {
    XYLA_LOG_WARN("MediaPool",
                  "No valid files to dispatch after path sanitization.");
    return;
  }

  XYLA_LOG_INFO("MediaPool", "Dispatching " +
                                 std::to_string(sanitizedPaths.size()) +
                                 " valid file(s) to probe worker pool.");

  m_probeEngine.probeFilesAsync(sanitizedPaths, targetBinId);
}

void MediaPool::onProbeCompleted(const ProbeResult &result) {
  if (!result.success) {
    XYLA_LOG_WARN("MediaPool", "Import failed for file: " +
                                   result.errorMessage.toStdString());
    emit importFailed(result.metadata.filePath, result.errorMessage);
    return;
  }

  DecoderScore score;
  auto decoder =
      DecoderRegistry::instance().selectBestDecoder(result.metadata, &score);

  if (!score.isValid()) {
    XYLA_LOG_WARN("MediaPool",
                  "No valid decoder factory found for probed asset: " +
                      result.metadata.filePath.toStdString());
    emit importFailed(result.metadata.filePath,
                      "No supported decoder factory found.");
    return;
  }

  QString assetId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QFileInfo fileInfo(result.metadata.filePath);
  QString assetName = fileInfo.fileName();

  auto asset =
      std::make_shared<MediaAsset>(assetId, assetName, result.metadata);
  m_assets[assetId] = asset;

  XYLA_LOG_INFO("MediaPool", "Successfully registered MediaAsset [" +
                                 assetId.toStdString() + "] using " +
                                 score.decoderName.toStdString());

  emit assetImported(result.targetBinId, asset);
}

std::shared_ptr<MediaAsset> MediaPool::getAsset(const QString &assetId) const {
  auto it = m_assets.find(assetId);
  return (it != m_assets.end()) ? it->second : nullptr;
}

} // namespace xyla
