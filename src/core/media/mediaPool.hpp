#pragma once

#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/media/mediaAsset.hpp"
#include "core/media/mediaProbeEngine.hpp"
#include <QFileInfo>
#include <QObject>
#include <memory>
#include <unordered_map>

namespace xyla {

class MediaPool : public QObject {
  Q_OBJECT

public:
  explicit MediaPool(QObject *parent = nullptr);
  ~MediaPool() override = default;

  Q_INVOKABLE void importFilesAsync(const QStringList &filePaths,
                                    const QString &targetBinId = {});

  Q_INVOKABLE qlonglong getAssetDurationFrames(const QString &assetId,
                                               double projectFps = 30.0) const {
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

    return 150; // Fallback 5 seconds if unprobed
  }

  std::shared_ptr<xyla::MediaAsset> getAsset(const QString &assetId) const;
  VulkanVideoDecoder *getDecoder(const QString &assetId);

signals:
  void assetImported(const QString &binId, std::shared_ptr<MediaAsset> asset);
  void importFailed(const QString &filePath, const QString &error);

private slots:
  void onProbeCompleted(const ProbeResult &result);

private:
  MediaProbeEngine m_probeEngine;
  std::unordered_map<QString, std::shared_ptr<MediaAsset>> m_assets;
  std::unordered_map<QString, std::unique_ptr<IDecoder>> m_decoders;
};

} // namespace xyla
