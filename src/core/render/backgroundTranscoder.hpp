#pragma once

#include <QObject>
#include <QString>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <queue>
#include <thread>

namespace xyla {

struct TranscodeJob {
  QString assetId;
  QString inputPath;
  QString outputPath;
};

class BackgroundTranscoder : public QObject {
  Q_OBJECT

public:
  static BackgroundTranscoder &instance() {
    static BackgroundTranscoder transcoder;
    return transcoder;
  }

  void start();
  void stop();
  void queueTranscode(const QString &assetId, const QString &inputFilePath);

signals:
  void transcodeCompleted(const QString &assetId,
                          const QString &optimizedFilePath);

private:
  BackgroundTranscoder();
  ~BackgroundTranscoder() override;

  void workerLoop();
  bool transcodeToAllIntra(const QString &inputPath, const QString &outputPath);

  std::thread m_workerThread;
  std::atomic<bool> m_running{false};

  std::mutex m_queueMutex;
  std::condition_variable m_cv;
  std::queue<TranscodeJob> m_jobQueue;
};

} // namespace xyla
