#include "mediaProbeEngine.hpp"
#include "core/log/logger.hpp"
#include "ffmpegProbe.hpp"
#include <QFileInfo>
#include <QRunnable>
#include <algorithm>

namespace xyla {

class ProbeTask : public QRunnable {
public:
  ProbeTask(QString filePath, QString targetBinId, MediaProbeEngine *engine)
      : m_filePath(std::move(filePath)), m_targetBinId(std::move(targetBinId)),
        m_engine(engine) {}

  void run() override {
    ProbeResult result;
    result.targetBinId = m_targetBinId;

    QFileInfo checkFile(m_filePath);
    if (!checkFile.exists() || !checkFile.isFile()) {
      result.success = false;
      result.errorMessage =
          "File does not exist or is unreadable: " + m_filePath;
      QMetaObject::invokeMethod(m_engine, "probeCompleted",
                                Qt::QueuedConnection,
                                Q_ARG(xyla::ProbeResult, result));
      return;
    }

    // Delegate directly to the real dynamic probe engine
    MediaMetadata meta = MediaProbeEngine::executeHeaderProbe(m_filePath);

    if (meta.isValid()) {
      result.success = true;
      result.metadata = std::move(meta);
    } else {
      result.success = false;
      result.errorMessage =
          "Corrupted or unsupported media format: " + m_filePath;
    }

    QMetaObject::invokeMethod(m_engine, "probeCompleted", Qt::QueuedConnection,
                              Q_ARG(xyla::ProbeResult, result));
  }

private:
  QString m_filePath;
  QString m_targetBinId;
  MediaProbeEngine *m_engine{nullptr};
};

MediaProbeEngine::MediaProbeEngine(QObject *parent) : QObject(parent) {
  qRegisterMetaType<xyla::ProbeResult>("xyla::ProbeResult");
  m_threadPool = std::make_unique<QThreadPool>();
  // Leave 1 core free for UI responsiveness
  m_threadPool->setMaxThreadCount(std::max(1, QThread::idealThreadCount() - 1));
}

MediaProbeEngine::~MediaProbeEngine() {
  m_threadPool->clear();
  m_threadPool->waitForDone();
}

void MediaProbeEngine::probeFilesAsync(const QStringList &filePaths,
                                       const QString &targetBinId) {
  for (const auto &path : filePaths) {
    auto *task = new ProbeTask(path, targetBinId, this);
    task->setAutoDelete(true);
    m_threadPool->start(task);
  }
}

MediaMetadata MediaProbeEngine::executeHeaderProbe(const QString &filePath) {
  FFmpegProbe probe;
  MediaMetadata meta;
  if (!probe.probe(filePath, meta)) {
    XYLA_LOG_WARN("MediaProbeEngine",
                  "Header probe failed for file: " + filePath.toStdString());
  }
  return meta;
}

} // namespace xyla
