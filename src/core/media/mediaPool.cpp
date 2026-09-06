#include "mediaPool.hpp"
#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/log/logger.hpp"
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <cmath>
#include <thread>

namespace xyla {

MediaPool::MediaPool(QObject *parent) : QObject(parent) {
  connect(&m_probeEngine, &MediaProbeEngine::probeCompleted, this,
          &MediaPool::onProbeCompleted);

  connect(&m_transcodeEngine, &TranscodeEngine::transcodeStarted, this,
          &MediaPool::onTranscodeStarted);
  connect(&m_transcodeEngine, &TranscodeEngine::transcodeProgress, this,
          &MediaPool::onTranscodeProgress);
  connect(&m_transcodeEngine, &TranscodeEngine::transcodeCompleted, this,
          &MediaPool::onTranscodeCompleted);
  connect(&m_transcodeEngine, &TranscodeEngine::transcodeFailed, this,
          &MediaPool::onTranscodeFailed);
}

QString MediaPool::getAssetId(const QString &rawInput) const {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  QString clean =
      QUrl(rawInput).isLocalFile() ? QUrl(rawInput).toLocalFile() : rawInput;

  for (const auto &[id, asset] : m_assets) {
    if (asset &&
        (asset->metadata().filePath == clean || asset->id() == rawInput)) {
      return id;
    }
  }
  return {};
}

qlonglong MediaPool::getAssetDurationFrames(const QString &assetId,
                                            double projectFps) const {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto asset = getAsset(assetId);
  if (!asset)
    return 0;

  const auto &meta = asset->metadata();
  if (meta.durationSeconds <= 0.001)
    return 0;

  double effectiveFps = projectFps;
  if (effectiveFps <= 0.0) {
    if (!meta.videoStreams.empty() && meta.videoStreams[0].frameRate > 0.0) {
      effectiveFps = meta.videoStreams[0].frameRate;
    } else {
      effectiveFps = 30.0;
    }
  }

  return static_cast<qlonglong>(
      std::max<int64_t>(1, std::round(meta.durationSeconds * effectiveFps)));
}

void MediaPool::importFilesAsync(const QStringList &filePaths,
                                 const QString &targetBinId) {
  m_probeEngine.probeFilesAsync(filePaths, targetBinId);
}

void MediaPool::requestProxyGeneration(const QString &assetId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto asset = getAsset(assetId);
  if (!asset) {
    XYLA_LOG_ERROR("MediaPool", "Cannot generate proxy, asset not found: " +
                                    assetId.toStdString());
    return;
  }

  m_transcodeEngine.queueTranscode(assetId, asset->metadata().filePath,
                                   asset->metadata().durationSeconds);
}

void MediaPool::checkAndQueueProxy(const QString &assetId,
                                   const MediaMetadata &metadata) {
  Q_UNUSED(assetId);
  Q_UNUSED(metadata);
}

void MediaPool::prewarmAudioStreamAsync(const QString &assetId,
                                        const QString &filePath) {
  std::thread([this, assetId, filePath]() {
    auto pcmBuffer = audio::AudioTimelineManager::instance().loadAssetAudio(
        assetId.toStdString(), filePath.toStdString());

    if (pcmBuffer) {
      audio::WaveformGenerator::instance().generateAsync(pcmBuffer);
      emit audioPrewarmed(assetId);
    }
  }).detach();
}

void MediaPool::onProbeCompleted(const ProbeResult &result) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  if (!result.success) {
    XYLA_LOG_ERROR(
        "MediaPool",
        "Probe failed for: " + result.metadata.filePath.toStdString() +
            " error: " + result.errorMessage.toStdString());
    emit importFailed(result.metadata.filePath, result.errorMessage);
    return;
  }

  // Generate unique UUID for each asset instance
  QString assetId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString fileName = QFileInfo(result.metadata.filePath).fileName();

  auto asset = std::make_shared<MediaAsset>(assetId, fileName, result.metadata);
  m_assets[assetId] = asset;

  // Track folder by UUID
  QString binId = result.targetBinId.isEmpty() ? QStringLiteral("root") : result.targetBinId;
  m_assetBins[assetId] = binId;

  // 1. Primary Display Video Decoder
  auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
  if (displayDecoder->open(result.metadata.filePath)) {
    m_decoders[assetId] = std::move(displayDecoder);
  }

  // 2. Pre-Warm Dedicated Prefetch Decoder
  auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
  if (prefetchDecoder->open(result.metadata.filePath)) {
    m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
  }

  // 3. Pre-Warm Audio Stream & Waveforms if asset contains audio
  if (!result.metadata.audioStreams.empty()) {
    prewarmAudioStreamAsync(assetId, result.metadata.filePath);
  }

  XYLA_LOG_INFO("MediaPool",
                "Imported asset [" + assetId.toStdString() + "]: " + result.metadata.filePath.toStdString());
  emit assetImported(binId, asset);
}
// void MediaPool::onProbeCompleted(const ProbeResult &result) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//
//   if (!result.success) {
//     XYLA_LOG_ERROR(
//         "MediaPool",
//         "Probe failed for: " + result.metadata.filePath.toStdString() +
//             " error: " + result.errorMessage.toStdString());
//     emit importFailed(result.metadata.filePath, result.errorMessage);
//     return;
//   }
//
//   QString assetId = result.metadata.filePath;
//   QString fileName = QFileInfo(result.metadata.filePath).fileName();
//
//   auto asset = std::make_shared<MediaAsset>(assetId, fileName, result.metadata);
//   m_assets[assetId] = asset;
//
//   // Track the folder this asset was imported into
//   QString binId = result.targetBinId.isEmpty() ? QStringLiteral("root") : result.targetBinId;
//   m_assetBins[assetId] = binId;
//
//   // 1. Primary Display Video Decoder
//   auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
//   if (displayDecoder->open(result.metadata.filePath)) {
//     m_decoders[assetId] = std::move(displayDecoder);
//   }
//
//   // 2. Pre-Warm Dedicated Prefetch Decoder
//   auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
//   if (prefetchDecoder->open(result.metadata.filePath)) {
//     m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
//   }
//
//   // 3. Pre-Warm Audio Stream & Waveforms if asset contains audio
//   if (!result.metadata.audioStreams.empty()) {
//     prewarmAudioStreamAsync(assetId, result.metadata.filePath);
//   }
//
//   XYLA_LOG_INFO("MediaPool",
//                 "Imported asset and warmed decoders: " + assetId.toStdString());
//   emit assetImported(binId, asset);
// }

QJsonObject MediaPool::serialize() const {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  QJsonObject root;

  // 1. Serialize folders
  QJsonArray foldersArray;
  for (const auto &folder : m_folders) {
    QJsonObject fObj;
    fObj[QStringLiteral("id")] = folder.id;
    fObj[QStringLiteral("name")] = folder.name;
    fObj[QStringLiteral("parentBinId")] = folder.parentBinId.isEmpty() ? QStringLiteral("root") : folder.parentBinId;
    foldersArray.append(fObj);
  }
  root[QStringLiteral("folders")] = foldersArray;

  // 2. Serialize assets
  QJsonArray assetsArray;
  for (const auto &[id, asset] : m_assets) {
    if (asset) {
      QJsonObject obj = QJsonObject::fromVariantMap(asset->toVariantMap());

      obj[QStringLiteral("id")] = id;
      obj[QStringLiteral("name")] = asset->name(); // <--- MUST BE AFTER toVariantMap()!

      auto proxyIt = m_proxyPaths.find(id);
      if (proxyIt != m_proxyPaths.end()) {
        obj[QStringLiteral("proxyPath")] = proxyIt->second;
      }

      auto binIt = m_assetBins.find(id);
      obj[QStringLiteral("parentBinId")] = (binIt != m_assetBins.end()) ? binIt->second : QStringLiteral("root");

      auto tagIt = m_assetTags.find(id);
      obj[QStringLiteral("tag")] = (tagIt != m_assetTags.end()) ? tagIt->second : 0;

      assetsArray.append(obj);
    }
    // if (asset) {
    //   QJsonObject obj = QJsonObject::fromVariantMap(asset->toVariantMap());
    //
    //   obj[QStringLiteral("id")] = id;
    //   obj[QStringLiteral("name")] = asset->name(); // <--- Explicitly save custom asset name!
    //
    //   auto proxyIt = m_proxyPaths.find(id);
    //   if (proxyIt != m_proxyPaths.end()) {
    //     obj[QStringLiteral("proxyPath")] = proxyIt->second;
    //   }
    //
    //   auto binIt = m_assetBins.find(id);
    //   obj[QStringLiteral("parentBinId")] = (binIt != m_assetBins.end()) ? binIt->second : QStringLiteral("root");
    //
    //   assetsArray.append(obj);
    // }
  }

  root[QStringLiteral("assets")] = assetsArray;
  return root;
}
// QJsonObject MediaPool::serialize() const {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//   QJsonObject root;
//
//   // 1. Serialize folders with their exact hierarchy
//   QJsonArray foldersArray;
//   for (const auto &folder : m_folders) {
//     QJsonObject fObj;
//     fObj[QStringLiteral("id")] = folder.id;
//     fObj[QStringLiteral("name")] = folder.name;
//     fObj[QStringLiteral("parentBinId")] = folder.parentBinId.isEmpty() ? QStringLiteral("root") : folder.parentBinId;
//     foldersArray.append(fObj);
//   }
//   root[QStringLiteral("folders")] = foldersArray;
//
//   // 2. Serialize assets with their exact parent folders
//   QJsonArray assetsArray;
//   for (const auto &[id, asset] : m_assets) {
//     if (asset) {
//       QJsonObject obj = QJsonObject::fromVariantMap(asset->toVariantMap());
//       auto proxyIt = m_proxyPaths.find(id);
//       if (proxyIt != m_proxyPaths.end()) {
//         obj[QStringLiteral("proxyPath")] = proxyIt->second;
//       }
//
//       auto binIt = m_assetBins.find(id);
//       obj[QStringLiteral("parentBinId")] = (binIt != m_assetBins.end()) ? binIt->second : QStringLiteral("root");
//
//       assetsArray.append(obj);
//     }
//   }
//
//   root[QStringLiteral("assets")] = assetsArray;
//   return root;
// }

// QJsonObject MediaPool::deserialize(const QJsonObject &data,
//                                    const QDir &projectDir) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//
//   // Clear pool and tell MediaBinModel to clear old project items
//   m_folders.clear();
//   m_assetBins.clear();
//   m_assets.clear();
//   m_proxyPaths.clear();
//   emit projectReloading();
//
//   // 1. Restore folders first
//   QJsonArray foldersArray = data[QStringLiteral("folders")].toArray();
//   for (const auto &val : foldersArray) {
//     QJsonObject fObj = val.toObject();
//     BinFolder folder;
//     folder.id = fObj[QStringLiteral("id")].toString();
//     folder.name = fObj[QStringLiteral("name")].toString();
//     folder.parentBinId = fObj[QStringLiteral("parentBinId")].toString(QStringLiteral("root"));
//     m_folders.push_back(folder);
//
//     emit folderImported(folder.id, folder.name, folder.parentBinId);
//   }
//
//   // 2. Restore assets into their respective folders
//   QJsonArray assetsArray = data[QStringLiteral("assets")].toArray();
//   for (const auto &val : assetsArray) {
//     QJsonObject assetObj = val.toObject();
//     MediaMetadata meta = MediaMetadata::fromVariantMap(
//         assetObj["metadata"].toObject().toVariantMap());
//
//     if (!meta.filePath.isEmpty() && QDir::isRelativePath(meta.filePath)) {
//       meta.filePath = projectDir.absoluteFilePath(meta.filePath);
//     }
//
//     QString assetId = assetObj["id"].toString();
//     if (assetId.isEmpty()) {
//       assetId = meta.filePath;
//     }
//
//     QString fileName = assetObj["name"].toString();
//     if (fileName.isEmpty()) {
//       fileName = QFileInfo(meta.filePath).fileName();
//     }
//
//     QString binId = assetObj["parentBinId"].toString();
//     if (binId.isEmpty()) {
//       binId = QStringLiteral("root");
//     }
//     m_assetBins[assetId] = binId;
//
//     QString proxyPath = assetObj["proxyPath"].toString();
//     if (!proxyPath.isEmpty()) {
//       m_proxyPaths[assetId] = proxyPath;
//     }
//
//     auto asset = std::make_shared<MediaAsset>(assetId, fileName, meta);
//     m_assets[assetId] = asset;
//
//     QString activePath = (!proxyPath.isEmpty() && QFileInfo::exists(proxyPath))
//                              ? proxyPath
//                              : meta.filePath;
//
//     auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
//     if (displayDecoder->open(activePath)) {
//       m_decoders[assetId] = std::move(displayDecoder);
//     }
//
//     auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
//     if (prefetchDecoder->open(activePath)) {
//       m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
//     }
//
//     if (!meta.audioStreams.empty()) {
//       prewarmAudioStreamAsync(assetId, activePath);
//     }
//
//     emit assetImported(binId, asset);
//   }
//
//   return data;
// }

void MediaPool::setAssetBin(const QString &assetId, const QString &targetBinId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  m_assetBins[assetId] = targetBinId;

  // Also update folder parentBinId if assetId is a folder!
  for (auto &folder : m_folders) {
    if (folder.id == assetId) {
      folder.parentBinId = targetBinId;
      break;
    }
  }
}
// void MediaPool::onProbeCompleted(const ProbeResult &result) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//
//   if (!result.success) {
//     XYLA_LOG_ERROR(
//         "MediaPool",
//         "Probe failed for: " + result.metadata.filePath.toStdString() +
//             " error: " + result.errorMessage.toStdString());
//     emit importFailed(result.metadata.filePath, result.errorMessage);
//     return;
//   }
//
//   QString assetId = result.metadata.filePath;
//   QString fileName = QFileInfo(result.metadata.filePath).fileName();
//
//   auto asset = std::make_shared<MediaAsset>(assetId, fileName, result.metadata);
//   m_assets[assetId] = asset;
//
//   // 1. Primary Display Video Decoder
//   auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
//   if (displayDecoder->open(result.metadata.filePath)) {
//     m_decoders[assetId] = std::move(displayDecoder);
//   }
//
//   // 2. Pre-Warm Dedicated Prefetch Decoder
//   auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
//   if (prefetchDecoder->open(result.metadata.filePath)) {
//     m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
//   }
//
//   // 3. Pre-Warm Audio Stream & Waveforms if asset contains audio
//   if (!result.metadata.audioStreams.empty()) {
//     prewarmAudioStreamAsync(assetId, result.metadata.filePath);
//   }
//
//   XYLA_LOG_INFO("MediaPool",
//                 "Imported asset and warmed decoders: " + assetId.toStdString());
//   emit assetImported(result.targetBinId, asset);
// }

void MediaPool::onTranscodeStarted(const QString &assetId) {
  emit proxyTranscodeStarted(assetId);
}

void MediaPool::onTranscodeProgress(const QString &assetId, double progress) {
  emit proxyTranscodeProgress(assetId, progress);
}

void MediaPool::onTranscodeCompleted(const QString &assetId,
                                     const QString &outputPath) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  m_proxyPaths[assetId] = outputPath;

  auto newDisplayDecoder = std::make_unique<VulkanVideoDecoder>();
  if (newDisplayDecoder->open(outputPath)) {
    m_decoders[assetId] = std::move(newDisplayDecoder);
    emit decoderSwapped(assetId);
  }

  auto newPrefetchDecoder = std::make_unique<VulkanVideoDecoder>();
  if (newPrefetchDecoder->open(outputPath)) {
    m_prefetchDecoders[assetId] = std::move(newPrefetchDecoder);
  }

  emit proxyTranscodeCompleted(assetId, outputPath);
}

void MediaPool::onTranscodeFailed(const QString &assetId,
                                  const QString &errorMsg) {
  XYLA_LOG_ERROR("MediaPool", "Proxy transcode failed for asset [" +
                                  assetId.toStdString() +
                                  "]: " + errorMsg.toStdString());
  emit proxyTranscodeFailed(assetId, errorMsg);
}

std::shared_ptr<MediaAsset> MediaPool::getAsset(const QString &assetId) const {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto it = m_assets.find(assetId);
  if (it != m_assets.end()) {
    return it->second;
  }
  return nullptr;
}

VulkanVideoDecoder *MediaPool::getDecoder(const QString &assetId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  auto it = m_decoders.find(assetId);
  if (it != m_decoders.end() && it->second) {
    return dynamic_cast<VulkanVideoDecoder *>(it->second.get());
  }

  auto asset = getAsset(assetId);
  if (!asset) {
    return nullptr;
  }

  QString pathToOpen = asset->metadata().filePath;
  auto proxyIt = m_proxyPaths.find(assetId);
  if (proxyIt != m_proxyPaths.end() && !proxyIt->second.isEmpty() &&
      QFileInfo::exists(proxyIt->second)) {
    pathToOpen = proxyIt->second;
  }

  auto newDecoder = std::make_unique<VulkanVideoDecoder>();
  if (newDecoder->open(pathToOpen)) {
    auto *ptr = newDecoder.get();
    m_decoders[assetId] = std::move(newDecoder);
    return ptr;
  }

  return nullptr;
}

VulkanVideoDecoder *MediaPool::getPrefetchDecoder(const QString &assetId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  auto it = m_prefetchDecoders.find(assetId);
  if (it != m_prefetchDecoders.end() && it->second) {
    return dynamic_cast<VulkanVideoDecoder *>(it->second.get());
  }

  auto asset = getAsset(assetId);
  if (!asset) {
    return nullptr;
  }

  QString pathToOpen = asset->metadata().filePath;
  auto proxyIt = m_proxyPaths.find(assetId);
  if (proxyIt != m_proxyPaths.end() && !proxyIt->second.isEmpty() &&
      QFileInfo::exists(proxyIt->second)) {
    pathToOpen = proxyIt->second;
  }

  auto newDecoder = std::make_unique<VulkanVideoDecoder>();
  if (newDecoder->open(pathToOpen)) {
    auto *ptr = newDecoder.get();
    m_prefetchDecoders[assetId] = std::move(newDecoder);
    return ptr;
  }

  return nullptr;
}

bool MediaPool::swapDecoder(const QString &assetId,
                            std::unique_ptr<VulkanVideoDecoder> newDecoder) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  if (!newDecoder)
    return false;

  m_decoders[assetId] = std::move(newDecoder);
  emit decoderSwapped(assetId);
  return true;
}

// QJsonObject MediaPool::serialize() const {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//   QJsonObject root;
//   QJsonArray assetsArray;
//
//   for (const auto &[id, asset] : m_assets) {
//     if (asset) {
//       QJsonObject obj = QJsonObject::fromVariantMap(asset->toVariantMap());
//       auto proxyIt = m_proxyPaths.find(id);
//       if (proxyIt != m_proxyPaths.end()) {
//         obj["proxyPath"] = proxyIt->second;
//       }
//       assetsArray.append(obj);
//     }
//   }
//
//   root["assets"] = assetsArray;
//   return root;
// }
// QJsonObject MediaPool::serialize() const {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//   QJsonObject root;
//
//   // 1. Serialize folders
//   QJsonArray foldersArray;
//   for (const auto &folder : m_folders) {
//     QJsonObject fObj;
//     fObj[QStringLiteral("id")] = folder.id;
//     fObj[QStringLiteral("name")] = folder.name;
//     fObj[QStringLiteral("parentBinId")] = folder.parentBinId;
//     foldersArray.append(fObj);
//   }
//   root[QStringLiteral("folders")] = foldersArray;
//
//   // 2. Serialize assets
//   QJsonArray assetsArray;
//   for (const auto &[id, asset] : m_assets) {
//     if (asset) {
//       QJsonObject obj = QJsonObject::fromVariantMap(asset->toVariantMap());
//       auto proxyIt = m_proxyPaths.find(id);
//       if (proxyIt != m_proxyPaths.end()) {
//         obj[QStringLiteral("proxyPath")] = proxyIt->second;
//       }
//       // Save current parent folder of this asset
//       auto binIt = m_assetBins.find(id);
//       obj[QStringLiteral("parentBinId")] = (binIt != m_assetBins.end()) ? binIt->second : QStringLiteral("root");
//
//       assetsArray.append(obj);
//     }
//   }
//
//   root[QStringLiteral("assets")] = assetsArray;
//   return root;
// }

QJsonObject MediaPool::deserialize(const QJsonObject &data,
                                   const QDir &projectDir) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  m_folders.clear();
  m_assetBins.clear();
  m_assets.clear();
  m_proxyPaths.clear();

  // 1. Restore folders first
  QJsonArray foldersArray = data[QStringLiteral("folders")].toArray();
  for (const auto &val : foldersArray) {
    QJsonObject fObj = val.toObject();
    BinFolder folder;
    folder.id = fObj[QStringLiteral("id")].toString();
    folder.name = fObj[QStringLiteral("name")].toString();
    folder.parentBinId = fObj[QStringLiteral("parentBinId")].toString(QStringLiteral("root"));
    m_folders.push_back(folder);

    emit folderImported(folder.id, folder.name, folder.parentBinId);
  }

  // 2. Restore assets
  QJsonArray assetsArray = data[QStringLiteral("assets")].toArray();
  for (const auto &val : assetsArray) {
    QJsonObject assetObj = val.toObject();
    MediaMetadata meta = MediaMetadata::fromVariantMap(
        assetObj["metadata"].toObject().toVariantMap());

    if (!meta.filePath.isEmpty() && QDir::isRelativePath(meta.filePath)) {
      meta.filePath = projectDir.absoluteFilePath(meta.filePath);
    }

    QString assetId = assetObj["id"].toString();
    if (assetId.isEmpty()) {
      assetId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }

    QString fileName = assetObj["name"].toString();
    if (fileName.isEmpty()) {
      fileName = QFileInfo(meta.filePath).fileName();
    }

    QString binId = assetObj["parentBinId"].toString();
    if (binId.isEmpty()) {
      binId = "root";
    }
    m_assetBins[assetId] = binId;

    QString proxyPath = assetObj["proxyPath"].toString();
    if (!proxyPath.isEmpty()) {
      m_proxyPaths[assetId] = proxyPath;
    }

    int tag = assetObj["tag"].toInt(0);
    m_assetTags[assetId] = tag;

    auto asset = std::make_shared<MediaAsset>(assetId, fileName, meta);
    m_assets[assetId] = asset;

    // Decoders prewarming...
    QString activePath = (!proxyPath.isEmpty() && QFileInfo::exists(proxyPath))
                             ? proxyPath
                             : meta.filePath;

    auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
    if (displayDecoder->open(activePath)) {
      m_decoders[assetId] = std::move(displayDecoder);
    }

    auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
    if (prefetchDecoder->open(activePath)) {
      m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
    }

    // Pre-warm audio and waveforms on project load
    if (!meta.audioStreams.empty()) {
      prewarmAudioStreamAsync(assetId, activePath);
    }

    emit assetImported(binId, asset);
  }

  return data;
}
// QJsonObject MediaPool::deserialize(const QJsonObject &data,
//                                    const QDir &projectDir) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//
//   QJsonArray assetsArray = data["assets"].toArray();
//   for (const auto &val : assetsArray) {
//     QJsonObject assetObj = val.toObject();
//     MediaMetadata meta = MediaMetadata::fromVariantMap(
//         assetObj["metadata"].toObject().toVariantMap());
//
//     if (!meta.filePath.isEmpty() && QDir::isRelativePath(meta.filePath)) {
//       meta.filePath = projectDir.absoluteFilePath(meta.filePath);
//     }
//
//     QString assetId = assetObj["id"].toString();
//     if (assetId.isEmpty()) {
//       assetId = meta.filePath;
//     }
//
//     QString fileName = assetObj["name"].toString();
//     if (fileName.isEmpty()) {
//       fileName = QFileInfo(meta.filePath).fileName();
//     }
//
//     QString binId = assetObj["parentBinId"].toString();
//     if (binId.isEmpty()) {
//       binId = "root";
//     }
//
//     QString proxyPath = assetObj["proxyPath"].toString();
//     if (!proxyPath.isEmpty()) {
//       m_proxyPaths[assetId] = proxyPath;
//     }
//
//     auto asset = std::make_shared<MediaAsset>(assetId, fileName, meta);
//     m_assets[assetId] = asset;
//
//     QString activePath = (!proxyPath.isEmpty() && QFileInfo::exists(proxyPath))
//                              ? proxyPath
//                              : meta.filePath;
//
//     auto displayDecoder = std::make_unique<VulkanVideoDecoder>();
//     if (displayDecoder->open(activePath)) {
//       m_decoders[assetId] = std::move(displayDecoder);
//     }
//
//     auto prefetchDecoder = std::make_unique<VulkanVideoDecoder>();
//     if (prefetchDecoder->open(activePath)) {
//       m_prefetchDecoders[assetId] = std::move(prefetchDecoder);
//     }
//
//     // Pre-warm audio and waveforms on project load
//     if (!meta.audioStreams.empty()) {
//       prewarmAudioStreamAsync(assetId, activePath);
//     }
//
//     emit assetImported(binId, asset);
//   }
//
//   return data;
// }

void MediaPool::addFolder(const QString &id, const QString &name, const QString &parentBinId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  m_folders.push_back({id, name, parentBinId.isEmpty() ? QStringLiteral("root") : parentBinId});
}

void MediaPool::removeFolder(const QString &id) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  // 1. Remove folder from m_folders
  m_folders.erase(std::remove_if(m_folders.begin(), m_folders.end(),
                                 [&](const BinFolder &f) { return f.id == id; }),
                  m_folders.end());

  // 2. Purge any stray assets assigned to this folder from m_assetBins
  std::vector<QString> assetsToDelete;
  for (const auto &[assetId, binId] : m_assetBins) {
    if (binId == id) {
      assetsToDelete.push_back(assetId);
    }
  }

  for (const auto &assetId : assetsToDelete) {
    m_assets.erase(assetId);
    m_assetBins.erase(assetId);
    m_proxyPaths.erase(assetId);
    m_decoders.erase(assetId);
    m_prefetchDecoders.erase(assetId);
  }
}

void MediaPool::removeAsset(const QString &assetId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  // 1. Remove from asset and bin maps
  m_assets.erase(assetId);
  m_assetBins.erase(assetId);
  m_proxyPaths.erase(assetId);

  // 2. Clean up allocated decoders
  m_decoders.erase(assetId);
  m_prefetchDecoders.erase(assetId);
}

void MediaPool::renameFolder(const QString &id, const QString &newName) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  for (auto &f : m_folders) {
    if (f.id == id) {
      f.name = newName;
      break;
    }
  }
}

std::shared_ptr<MediaAsset> MediaPool::duplicateAsset(const QString &sourceAssetId,
                                                      const QString &newAssetId,
                                                      const QString &newName,
                                                      const QString &targetBinId) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);

  auto it = m_assets.find(sourceAssetId);
  if (it == m_assets.end() || !it->second) {
    return nullptr;
  }

  const auto &src = it->second;
  // Initialize with the new generated name (e.g. "clip (1).mp4")!
  auto newAsset = std::make_shared<MediaAsset>(newAssetId, newName, src->metadata());
  m_assets[newAssetId] = newAsset;

  m_assetBins[newAssetId] = targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;

  auto proxyIt = m_proxyPaths.find(sourceAssetId);
  if (proxyIt != m_proxyPaths.end()) {
    m_proxyPaths[newAssetId] = proxyIt->second;
  }

  return newAsset;
}

int MediaPool::getAssetTag(const QString &assetId) const {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto it = m_assetTags.find(assetId);
  if (it != m_assetTags.end()) {
    return it->second;
  }
  return 0; // 0 = AssetTag::None
}
void MediaPool::setAssetTag(const QString &assetId, int tag) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  m_assetTags[assetId] = tag;
}

void MediaPool::renameAsset(const QString &assetId, const QString &newName) {
  std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
  auto it = m_assets.find(assetId);
  if (it != m_assets.end() && it->second) {
    // Re-construct the MediaAsset with the updated name, preserving its ID and metadata
    it->second = std::make_shared<MediaAsset>(it->second->id(), newName, it->second->metadata());
  }
}

// std::shared_ptr<MediaAsset> MediaPool::duplicateAsset(const QString &sourceAssetId,
//                                                       const QString &newAssetId,
//                                                       const QString &targetBinId) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//
//   auto it = m_assets.find(sourceAssetId);
//   if (it == m_assets.end() || !it->second) {
//     return nullptr;
//   }
//
//   const auto &src = it->second;
//   // Create a new MediaAsset sharing the same metadata and file path, but with its own unique new UUID
//   auto newAsset = std::make_shared<MediaAsset>(newAssetId, src->name(), src->metadata());
//   m_assets[newAssetId] = newAsset;
//
//   // Track the duplicate's folder
//   m_assetBins[newAssetId] = targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;
//
//   // Copy proxy path if original has one
//   auto proxyIt = m_proxyPaths.find(sourceAssetId);
//   if (proxyIt != m_proxyPaths.end()) {
//     m_proxyPaths[newAssetId] = proxyIt->second;
//   }
//
//   return newAsset;
// }

// void MediaPool::setAssetBin(const QString &assetId, const QString &targetBinId) {
//   std::lock_guard<std::recursive_mutex> lock(m_poolMutex);
//   m_assetBins[assetId] = targetBinId;
//
//   // IMPORTANT: Also update folder parentBinId if assetId is a folder!
//   for (auto &folder : m_folders) {
//     if (folder.id == assetId) {
//       folder.parentBinId = targetBinId;
//       break;
//     }
//   }
// }

} // namespace xyla
