#pragma once

#include "core/media/iDecoder.hpp"
#include "core/media/mediaData.hpp"
#include "core/media/mediaPool.hpp"
#include <QObject>
#include <QTimer>
#include <memory>

namespace xyla {

class ClipMonitorController : public QObject {
  Q_OBJECT
  Q_PROPERTY(
      QString currentAssetId READ currentAssetId NOTIFY currentAssetChanged)
  Q_PROPERTY(qint64 currentFrame READ currentFrame NOTIFY frameChanged)
  Q_PROPERTY(qint64 totalFrames READ totalFrames NOTIFY totalFramesChanged)
  Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
  Q_PROPERTY(int mediaType READ mediaType NOTIFY currentAssetChanged)
  Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY currentAssetChanged)
  Q_PROPERTY(bool hasAudio READ hasAudio NOTIFY currentAssetChanged)

public:
  explicit ClipMonitorController(MediaPool *mediaPool,
                                 QObject *parent = nullptr);
  ~ClipMonitorController() override;

  QString currentAssetId() const { return m_currentAssetId; }
  qint64 currentFrame() const { return m_currentFrame; }
  qint64 totalFrames() const { return m_totalFrames; }
  bool isPlaying() const { return m_isPlaying; }
  int mediaType() const { return static_cast<int>(m_currentMediaType); }
  bool hasVideo() const { return m_hasVideo; }
  bool hasAudio() const { return m_hasAudio; }

public slots:
  Q_INVOKABLE void loadAsset(const QString &assetId);
  Q_INVOKABLE void seekFrame(qint64 frameIndex);
  Q_INVOKABLE void togglePlay();
  Q_INVOKABLE void play();
  Q_INVOKABLE void pause();
  Q_INVOKABLE void stepForward();
  Q_INVOKABLE void stepBackward();

signals:
  void currentAssetChanged(const QString &assetId);
  void frameChanged(qint64 frame);
  void totalFramesChanged(qint64 total);
  void isPlayingChanged(bool isPlaying);
  void frameComposited();

private slots:
  void onPlaybackTick();

private:
  void renderCurrentFrame();

  MediaPool *m_mediaPool{nullptr};
  QString m_currentAssetId;
  qint64 m_currentFrame{0};
  qint64 m_totalFrames{0};
  double m_fps{30.0};

  bool m_isPlaying{false};
  QTimer m_playbackTimer;

  MediaType m_currentMediaType{MediaType::Unknown};
  bool m_hasVideo{false};
  bool m_hasAudio{false};

  std::unique_ptr<IDecoder> m_clipDecoder;
};

} // namespace xyla
