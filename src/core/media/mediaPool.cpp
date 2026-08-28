#include "mediaPool.hpp"
#include "core/log/logger.hpp"
#include "core/media/mediaData.hpp"
#include "core/render/xylaRenderer.hpp"
#include "decoderRegistry.hpp"
#include <QFileInfo>
#include <QThreadPool>
#include <QUrl>
#include <QUuid>
#include <qjsonarray.h>
#include <qjsonobject.h>
#include <qjsonvalue.h>

namespace {

QString sanitizeFilePath(const QString &rawInput) {
  if (rawInput.trimmed().isEmpty())
    return {};

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
  if (localPath.isEmpty())
    return {};

  QFileInfo fileInfo(localPath);
  QString canonicalPath = fileInfo.canonicalFilePath();
  if (canonicalPath.isEmpty())
    canonicalPath = fileInfo.absoluteFilePath();

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
  connect(&m_probeEngine, &MediaProbeEngine::probeCompleted, this,
          &MediaPool::onProbeCompleted, Qt::QueuedConnection);
}

QString MediaPool::getAssetId(const QString &rawInput) const {
  if (rawInput.trimmed().isEmpty())
    return {};

  auto asset = getAsset(rawInput);
  if (asset && !asset->id().isEmpty()) {
    return asset->id();
  }
  return rawInput;
}

qlonglong MediaPool::getAssetDurationFrames(const QString &assetId,
                                            double projectFps) const {
  auto asset = getAsset(assetId);
  if (!asset)
    return 150;

  const auto &meta = asset->metadata();
  double durationSec = meta.durationSeconds;

  if (durationSec <= 0.001 && !meta.videoStreams.empty()) {
    const auto &vs = meta.videoStreams[0];
    if (vs.frameRate > 0.0 && vs.totalFrames > 0) {
      durationSec = static_cast<double>(vs.totalFrames) / vs.frameRate;
    }
  }

  if (durationSec > 0.001) {
    return static_cast<qlonglong>(durationSec *
                                  (projectFps > 0.0 ? projectFps : 30.0));
  }
  return 150;
}

void MediaPool::importFilesAsync(const QStringList &filePaths,
                                 const QString &targetBinId) {
  if (filePaths.isEmpty())
    return;

  QStringList sanitizedPaths;
  QSet<QString> seenPaths;

  for (const QString &rawPath : filePaths) {
    QString cleanPath = sanitizeFilePath(rawPath);
    if (!cleanPath.isEmpty() && !seenPaths.contains(cleanPath)) {
      seenPaths.insert(cleanPath);
      sanitizedPaths.append(cleanPath);
    }
  }

  if (sanitizedPaths.isEmpty())
    return;

  m_probeEngine.probeFilesAsync(sanitizedPaths, targetBinId);
}

void MediaPool::onProbeCompleted(const ProbeResult &result) {
  if (!result.success) {
    emit importFailed(result.metadata.filePath, result.errorMessage);
    return;
  }

  DecoderScore score;
  auto decoder =
      DecoderRegistry::instance().selectBestDecoder(result.metadata, &score);

  if (!score.isValid()) {
    emit importFailed(result.metadata.filePath,
                      "No supported decoder factory found.");
    return;
  }

  QString assetId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QFileInfo fileInfo(result.metadata.filePath);
  QString assetName = fileInfo.fileName();

  auto asset =
      std::make_shared<MediaAsset>(assetId, assetName, result.metadata);

  {
    std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
    m_assets[assetId] = asset;
  }

  // Pre-warm decoder and precompile shader
  QThreadPool::globalInstance()->start([this, assetId]() {
    getDecoder(assetId);
    auto graph = render::NodeGraph::createDefaultClipGraph(assetId);
    render::XylaRenderer::instance().precompileGraph(graph);
  });

  XYLA_LOG_INFO("MediaPool", "Successfully registered asset [" +
                                 assetId.toStdString() + "] using " +
                                 score.decoderName.toStdString());

  emit assetImported(result.targetBinId, asset);
}

bool MediaPool::swapDecoder(const QString &assetId,
                            std::unique_ptr<VulkanVideoDecoder> newDecoder) {
  if (!newDecoder || assetId.isEmpty())
    return false;

  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  m_decoders[assetId] = std::move(newDecoder);
  return true;
}

std::shared_ptr<MediaAsset> MediaPool::getAsset(const QString &assetId) const {
  if (assetId.trimmed().isEmpty())
    return nullptr;

  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto it = m_assets.find(assetId);
  if (it != m_assets.end())
    return it->second;

  QString cleanInput = sanitizeFilePath(assetId);
  for (const auto &[id, asset] : m_assets) {
    if (asset && (asset->metadata().filePath == assetId ||
                  asset->metadata().filePath == cleanInput)) {
      return asset;
    }
  }
  return nullptr;
}

VulkanVideoDecoder *MediaPool::getDecoder(const QString &assetId) {
  if (assetId.trimmed().isEmpty())
    return nullptr;

  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  auto asset = getAsset(assetId); // Safe now with recursive_mutex!
  QString realId = asset ? asset->id() : assetId;
  QString filePath =
      asset ? asset->metadata().filePath : sanitizeFilePath(assetId);

  if (filePath.isEmpty())
    filePath = assetId;

  auto decIt = m_decoders.find(realId);
  if (decIt != m_decoders.end()) {
    return dynamic_cast<VulkanVideoDecoder *>(decIt->second.get());
  }

  auto decoder = std::make_unique<VulkanVideoDecoder>();
  if (!decoder->open(filePath)) {
    return nullptr;
  }

  auto *vkDecoder = decoder.get();
  m_decoders[realId] = std::move(decoder);
  return vkDecoder;
}

[[nodiscard]] QJsonObject MediaPool::serialize() const {
  QJsonArray assetArray;
  for (const auto &[id, asset] : m_assets) {
    if (!asset)
      continue;
    assetArray.append(QJsonObject::fromVariantMap(asset->toVariantMap()));
  }

  QJsonObject root;
  root["assets"] = assetArray;
  return root;
};

QJsonObject MediaPool::deserialize(const QJsonObject &data,
                                   const QDir &projectDir) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  m_assets.clear();
  m_decoders.clear();

  QJsonArray assetsArray = data["assets"].toArray();
  for (const QJsonValue &val : assetsArray) {
    QJsonObject obj = val.toObject();
    QVariantMap assetMap = obj.toVariantMap();

    QString id = assetMap.value("id").toString();
    QString name = assetMap.value("name").toString();

    // Grab the nested metadata map that MediaAsset::toVariantMap() outputted
    QVariantMap metaMap = assetMap.value("metadata").toMap();
    MediaMetadata meta = MediaMetadata::fromVariantMap(metaMap);

    // Reconstruct asset
    auto asset = std::make_shared<MediaAsset>(id, name, meta);
    QString filePath = meta.filePath;

    // Direct check before feeding to FFmpeg
    QFileInfo checkFile(filePath);
    if (filePath.isEmpty() || !checkFile.exists() || checkFile.isDir()) {
      XYLA_LOG_ERROR("MediaPool", "Invalid media path for asset " +
                                      id.toStdString() + ": " +
                                      filePath.toStdString());
      continue;
    }

    m_assets[id] = asset;

    // 1. Notify UI model immediately
    QString binId = assetMap.value("binId", "root").toString();
    emit assetImported(binId, asset);

    // 2. Open hardware decoder asynchronously
    QThreadPool::globalInstance()->start([this, id, filePath]() {
      auto decoder = std::make_unique<VulkanVideoDecoder>();
      if (decoder->open(filePath)) {
        {
          std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
          m_decoders[id] = std::move(decoder);
        }

        QMetaObject::invokeMethod(
            this, [this, id]() { emit decoderSwapped(id); },
            Qt::QueuedConnection);
      } else {
        XYLA_LOG_ERROR("MediaPool",
                       "Failed to open decoder for: " + filePath.toStdString());
      }
    });
  }

  return QJsonObject{};
};
} // namespace xyla
