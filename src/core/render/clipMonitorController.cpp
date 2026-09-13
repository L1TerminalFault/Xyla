#include "clipMonitorController.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include <algorithm>
#include <cmath>

namespace xyla {

ClipMonitorController::ClipMonitorController(MediaPool *mediaPool,
                                             QObject *parent)
    : QObject(parent), m_mediaPool(mediaPool) {

  connect(&m_playbackTimer, &QTimer::timeout, this,
          &ClipMonitorController::onPlaybackTick);

  connect(
      &render::VideoFrameCache::instance(),
      &render::VideoFrameCache::frameReady, this,
      [this](const QString &assetId, qint64 frameIndex) {
        if (assetId == m_currentAssetId && frameIndex == m_currentFrame) {
          renderCurrentFrame();
        }
      },
      Qt::QueuedConnection);
}

ClipMonitorController::~ClipMonitorController() { pause(); }

void ClipMonitorController::loadAsset(const QString &assetId) {
  if (assetId.isEmpty() || !m_mediaPool)
    return;

  pause();

  auto asset = m_mediaPool->getAsset(assetId);
  if (!asset)
    return;

  const auto &meta = asset->metadata();
  m_currentAssetId = assetId;
  m_currentMediaType = meta.type;
  m_hasVideo = meta.hasVideo();
  m_hasAudio = meta.hasAudio();
  m_currentFrame = 0;

  // Frame rate & Total frames detection
  m_fps = 30.0;
  if (m_hasVideo && !meta.videoStreams.empty()) {
    if (meta.videoStreams[0].frameRate > 0.0) {
      m_fps = meta.videoStreams[0].frameRate;
    }
    m_totalFrames = meta.videoStreams[0].totalFrames > 0
                        ? meta.videoStreams[0].totalFrames
                        : m_mediaPool->getAssetDurationFrames(assetId, m_fps);
  } else {
    m_totalFrames = m_mediaPool->getAssetDurationFrames(assetId, m_fps);
  }

  m_playbackTimer.setInterval(static_cast<int>(std::round(1000.0 / m_fps)));

  // Reopen dedicated decoder
  if (m_clipDecoder) {
    m_clipDecoder->close();
    m_clipDecoder.reset();
  }

  if (m_hasVideo || meta.type == MediaType::Image) {
    m_clipDecoder = DecoderRegistry::instance().selectBestDecoder(meta);
    if (m_clipDecoder) {
      if (m_clipDecoder->open(meta.filePath)) {
        // Crucial: Warm up decoder to frame 0 immediately
        m_clipDecoder->seekToFrame(0, m_fps);
      } else {
        m_clipDecoder.reset();
      }
    }
  }

  emit currentAssetChanged(m_currentAssetId);
  emit totalFramesChanged(m_totalFrames);
  emit frameChanged(m_currentFrame);

  renderCurrentFrame();
}

void ClipMonitorController::seekFrame(qint64 frameIndex) {
  if (m_currentAssetId.isEmpty() || !m_clipDecoder)
    return;

  qint64 clamped =
      std::clamp<qint64>(frameIndex, 0, std::max<qint64>(0, m_totalFrames - 1));

  bool isNextLinearFrame = (clamped == m_currentFrame + 1);
  m_currentFrame = clamped;
  emit frameChanged(m_currentFrame);

  if (m_hasVideo) {
    bool decoded = false;
    // Fast path: Linear playback uses ultra-fast decodeNextFrame()
    if (m_isPlaying && isNextLinearFrame) {
      decoded = m_clipDecoder->decodeNextFrame();
    }
    // Scrub / Seek path: Jumps to exact timestamp
    if (!decoded) {
      decoded = m_clipDecoder->seekToFrame(m_currentFrame, m_fps);
    }

    if (decoded) {
      AVFrame *frame = m_clipDecoder->currentFrame();
      if (frame) {
        // Upload decoded frame into Vulkan texture cache
        render::VideoFrameCache::instance().uploadAndCacheFrame(
            m_currentAssetId, m_currentFrame, frame);
      }
    }

    renderCurrentFrame();
  }
}

void ClipMonitorController::togglePlay() {
  if (m_isPlaying) {
    pause();
  } else {
    play();
  }
}

void ClipMonitorController::play() {
  if (m_isPlaying || m_currentAssetId.isEmpty())
    return;

  if (m_currentFrame >= m_totalFrames - 1) {
    m_currentFrame = 0;
    emit frameChanged(m_currentFrame);
  }

  m_isPlaying = true;
  m_playbackTimer.start();
  emit isPlayingChanged(m_isPlaying);
}

void ClipMonitorController::pause() {
  if (!m_isPlaying)
    return;

  m_isPlaying = false;
  m_playbackTimer.stop();
  emit isPlayingChanged(m_isPlaying);
}

void ClipMonitorController::stepForward() {
  pause();
  seekFrame(m_currentFrame + 1);
}

void ClipMonitorController::stepBackward() {
  pause();
  seekFrame(m_currentFrame - 1);
}

void ClipMonitorController::onPlaybackTick() {
  if (m_currentFrame + 1 < m_totalFrames) {
    seekFrame(m_currentFrame + 1);
  } else {
    pause();
  }
}

void ClipMonitorController::renderCurrentFrame() {
  if (m_currentAssetId.isEmpty() || !m_clipDecoder || !m_hasVideo ||
      !m_mediaPool) {
    qWarning() << "[ClipMonitor] Early return: missing asset/decoder/video.";
    return;
  }

  auto asset = m_mediaPool->getAsset(m_currentAssetId);
  if (!asset)
    return;

  const auto &meta = asset->metadata();
  uint32_t w = 1920;
  uint32_t h = 1080;
  if (!meta.videoStreams.empty()) {
    w = static_cast<uint32_t>(meta.videoStreams[0].width);
    h = static_cast<uint32_t>(meta.videoStreams[0].height);
  }

  auto *vkDecoder = dynamic_cast<VulkanVideoDecoder *>(m_clipDecoder.get());

  auto [yView, uvView] = render::VideoFrameCache::instance().getFramePlanes(
      m_currentAssetId, m_currentFrame, vkDecoder, m_isPlaying, false, false,
      0.0);

  if (yView == VK_NULL_HANDLE || uvView == VK_NULL_HANDLE) {
    bool sought = m_clipDecoder->seekToFrame(m_currentFrame, m_fps);
    AVFrame *frame = m_clipDecoder->currentFrame();
    if (frame) {
      bool uploaded = render::VideoFrameCache::instance().uploadAndCacheFrame(
          m_currentAssetId, m_currentFrame, frame);

      auto planes = render::VideoFrameCache::instance().getFramePlanes(
          m_currentAssetId, m_currentFrame, vkDecoder, m_isPlaying, false,
          false, 0.0);
      yView = planes.first;
      uvView = planes.second;
    }
  }

  if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
    bool ok =
        render::XylaRenderer::instance().renderClipFrame(yView, uvView, w, h);
    if (ok) {
      emit frameComposited();
    }
  }
}

} // namespace xyla
