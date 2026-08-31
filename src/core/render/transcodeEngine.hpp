#pragma once

#include <QDir>
#include <QMutex>
#include <QObject>
#include <QQueue>
#include <QString>
#include <QThread>
#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/buffer.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_vaapi.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>
}

namespace xyla {

struct TranscodeJob {
  QString assetId;
  QString inputPath;
  QString outputPath;
  double durationSeconds{0.0};
};

class TranscodeEngine : public QObject {
  Q_OBJECT

public:
  explicit TranscodeEngine(QObject *parent = nullptr);
  ~TranscodeEngine() override;

  void queueTranscode(const QString &assetId, const QString &inputPath,
                      double durationSeconds);
  void cancelAll();

signals:
  void transcodeStarted(const QString &assetId);
  void transcodeProgress(const QString &assetId, double progress);
  void transcodeCompleted(const QString &assetId, const QString &outputPath);
  void transcodeFailed(const QString &assetId, const QString &errorMsg);

private:
  void workerLoop();
  bool processJob(const TranscodeJob &job);

  bool setupVaapiFramesContext(AVCodecContext *encCtx, AVBufferRef *hwDeviceCtx,
                               int width, int height);

  bool initHardwareDevice();

  QQueue<TranscodeJob> m_jobQueue;
  std::mutex m_queueMutex;
  std::condition_variable m_cv;

  std::thread m_workerThread;
  std::atomic<bool> m_running{false};

  AVBufferRef *m_hwDeviceCtx{nullptr};
  bool m_hwSupported{false};
  enum AVHWDeviceType m_hwType { AV_HWDEVICE_TYPE_NONE };
};

} // namespace xyla
