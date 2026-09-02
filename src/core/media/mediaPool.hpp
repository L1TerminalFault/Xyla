#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/media/mediaAsset.hpp"
#include "core/media/mediaProbeEngine.hpp"
#include "core/render/transcodeEngine.hpp"
#include <QDir>
#include <QObject>
#include <QSet>
#include <QString>
#include <memory>
#include <mutex>
#include <qjsonobject.h>
#include <unordered_map>

namespace xyla {

class MediaPool : public QObject {
  Q_OBJECT

public:
  explicit MediaPool(QObject *parent = nullptr);
  ~MediaPool() override = default;

  [[nodiscard]] QJsonObject serialize() const;
  QJsonObject deserialize(const QJsonObject &data, const QDir &projectDir);

  Q_INVOKABLE QString getAssetId(const QString &rawInput) const;
  Q_INVOKABLE qlonglong getAssetDurationFrames(const QString &assetId,
                                               double projectFps) const;

  Q_INVOKABLE void importFilesAsync(const QStringList &filePaths,
                                    const QString &targetBinId = "root");

  Q_INVOKABLE void requestProxyGeneration(const QString &assetId);

  std::shared_ptr<MediaAsset> getAsset(const QString &assetId) const;

  // Main/Display Thread Decoder (Used by TimelineCompositor & VideoFrameCache)
  VulkanVideoDecoder *getDecoder(const QString &assetId);

  // Dedicated Background Prefetch Decoder (Used by FramePrefetcher)
  VulkanVideoDecoder *getPrefetchDecoder(const QString &assetId);

  bool swapDecoder(const QString &assetId,
                   std::unique_ptr<VulkanVideoDecoder> newDecoder);

signals:
  void assetImported(const QString &binId, std::shared_ptr<MediaAsset> asset);
  void importFailed(const QString &filePath, const QString &errorMessage);
  void decoderSwapped(const QString &assetId);

  // Proxy Status Signals
  void proxyTranscodeStarted(const QString &assetId);
  void proxyTranscodeProgress(const QString &assetId, double progress);
  void proxyTranscodeCompleted(const QString &assetId,
                               const QString &proxyPath);
  void proxyTranscodeFailed(const QString &assetId, const QString &errorMsg);

private slots:
  void onProbeCompleted(const ProbeResult &result);

  // Transcode Engine Callbacks
  void onTranscodeStarted(const QString &assetId);
  void onTranscodeProgress(const QString &assetId, double progress);
  void onTranscodeCompleted(const QString &assetId, const QString &outputPath);
  void onTranscodeFailed(const QString &assetId, const QString &errorMsg);

private:
  void checkAndQueueProxy(const QString &assetId,
                          const MediaMetadata &metadata);

  MediaProbeEngine m_probeEngine;
  TranscodeEngine m_transcodeEngine;

  std::unordered_map<QString, std::shared_ptr<MediaAsset>> m_assets;
  std::unordered_map<QString, std::unique_ptr<IDecoder>> m_decoders;

  // Dedicated prefetch decoders for thread-isolated background lookahead
  std::unordered_map<QString, std::unique_ptr<IDecoder>> m_prefetchDecoders;

  // Asset Proxy Maps
  std::unordered_map<QString, QString> m_proxyPaths;

  mutable std::recursive_mutex m_poolMutex;
};

} // namespace xyla
