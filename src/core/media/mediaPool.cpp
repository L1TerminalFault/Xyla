#include "mediaPool.hpp"
#include "core/log/logger.hpp"
#include "core/render/xylaRenderer.hpp"
#include "decoderRegistry.hpp"
#include <QFileInfo>
#include <QThreadPool>
#include <QUrl>
#include <QUuid>

namespace {

// Normalizes file URLs and raw system paths
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

// Connects async media probe engine signal listeners
MediaPool::MediaPool(QObject *parent) : QObject(parent) {
  connect(&m_probeEngine, &MediaProbeEngine::probeCompleted, this,
          &MediaPool::onProbeCompleted, Qt::QueuedConnection);
}

// Kicks off async probe for newly imported video files
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

// Registers probed media metadata and asynchronously pre-warms decoders
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
  m_assets[assetId] = asset;

  // Asynchronously pre-warm hardware NVDEC decoder and precompile shader
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

// Fetches asset handle by asset UUID or path
std::shared_ptr<MediaAsset> MediaPool::getAsset(const QString &assetId) const {
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

// Instantiates or fetches cached Vulkan video decoder
VulkanVideoDecoder *MediaPool::getDecoder(const QString &assetId) {
  auto asset = getAsset(assetId);
  if (!asset)
    return nullptr;

  QString realId = asset->id();
  auto decIt = m_decoders.find(realId);
  if (decIt != m_decoders.end()) {
    return dynamic_cast<VulkanVideoDecoder *>(decIt->second.get());
  }

  DecoderScore score;
  auto decoder =
      DecoderRegistry::instance().selectBestDecoder(asset->metadata(), &score);
  if (!decoder)
    return nullptr;

  auto *vkDecoder = dynamic_cast<VulkanVideoDecoder *>(decoder.get());
  if (vkDecoder) {
    if (!vkDecoder->open(asset->metadata().filePath)) {
      return nullptr;
    }
  }

  m_decoders[realId] = std::move(decoder);
  return vkDecoder;
}

} // namespace xyla
