#pragma once

#include "mediaData.hpp"
#include <QObject>
#include <QString>
#include <QStringList>
#include <QThreadPool>
#include <memory>

namespace xyla {

struct ProbeResult {
  QString targetBinId;
  MediaMetadata metadata;
  QString errorMessage;
  bool success{false};
};

class MediaProbeEngine : public QObject {
  Q_OBJECT

public:
  explicit MediaProbeEngine(QObject *parent = nullptr);
  ~MediaProbeEngine() override;

  void probeFilesAsync(const QStringList &filePaths,
                       const QString &targetBinId);

  static MediaMetadata executeHeaderProbe(const QString &filePath);

signals:
  void probeCompleted(const xyla::ProbeResult &result);

private:
  std::unique_ptr<QThreadPool> m_threadPool;
};

} // namespace xyla
