#pragma once

#include "mediaAsset.hpp"
#include "mediaProbeEngine.hpp"
#include <QObject>
#include <QStringList>
#include <memory>
#include <unordered_map>

namespace xyla {

class MediaPool : public QObject {
  Q_OBJECT

public:
  explicit MediaPool(QObject *parent = nullptr);
  ~MediaPool() override = default;

  // Trigger non-blocking async imports
  Q_INVOKABLE void importFilesAsync(const QStringList &filePaths,
                                    const QString &targetBinId = "root");

  // Asset Retrieval
  std::shared_ptr<MediaAsset> getAsset(const QString &assetId) const;

signals:
  void assetImported(const QString &binId,
                     std::shared_ptr<xyla::MediaAsset> asset);
  void importFailed(const QString &filePath, const QString &reason);

private slots:
  void onProbeCompleted(const xyla::ProbeResult &result);

private:
  MediaProbeEngine m_probeEngine;
  std::unordered_map<QString, std::shared_ptr<MediaAsset>> m_assets;
};

} // namespace xyla
