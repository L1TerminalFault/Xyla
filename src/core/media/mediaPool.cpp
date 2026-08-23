#include "mediaPool.hpp"
#include "core/log/logger.hpp"
#include "decoderRegistry.hpp"
#include <QFileInfo>
#include <QUuid>

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

  XYLA_LOG_INFO("MediaPool", "Dispatching " + std::to_string(filePaths.size()) +
                                 " files to probe worker pool.");
  m_probeEngine.probeFilesAsync(filePaths, targetBinId);
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
