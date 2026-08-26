#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/media/mediaAsset.hpp"
#include "core/media/mediaProbeEngine.hpp"
#include <QObject>
#include <QSet>
#include <QString>
#include <memory>
#include <mutex> // Contains std::recursive_mutex
#include <unordered_map>

namespace xyla {

class MediaPool : public QObject {
  Q_OBJECT

public:
  explicit MediaPool(QObject *parent = nullptr);
  ~MediaPool() override = default;

  Q_INVOKABLE QString getAssetId(const QString &rawInput) const;
  Q_INVOKABLE qlonglong getAssetDurationFrames(const QString &assetId,
                                               double projectFps = 30.0) const;

  Q_INVOKABLE void importFilesAsync(const QStringList &filePaths,
                                    const QString &targetBinId = "root");

  std::shared_ptr<MediaAsset> getAsset(const QString &assetId) const;
  VulkanVideoDecoder *getDecoder(const QString &assetId);

  bool swapDecoder(const QString &assetId,
                   std::unique_ptr<VulkanVideoDecoder> newDecoder);

signals:
  void assetImported(const QString &binId, std::shared_ptr<MediaAsset> asset);
  void importFailed(const QString &filePath, const QString &errorMessage);
  void decoderSwapped(const QString &assetId);

private slots:
  void onProbeCompleted(const ProbeResult &result);

private:
  MediaProbeEngine m_probeEngine;
  std::unordered_map<QString, std::shared_ptr<MediaAsset>> m_assets;
  std::unordered_map<QString, std::unique_ptr<IDecoder>> m_decoders;

  // FIX: Change to std::recursive_mutex to prevent self-deadlock when
  // getDecoder calls getAsset
  mutable std::recursive_mutex m_poolMutex;
};

} // namespace xyla
