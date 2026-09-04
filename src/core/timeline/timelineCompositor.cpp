#include "timelineCompositor.hpp"
#include "core/memory/xylaArena.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "project/projectManager.hpp"
#include <QMetaObject>
#include <cmath>
#include <vector>
#include <vulkan/vulkan.h>

namespace xyla {

TimelineCompositor::TimelineCompositor(PlaybackManager *playbackManager,
                                       TimelineModel *timelineModel,
                                       MediaPool *mediaPool, QObject *parent)
    : QObject(parent), m_playbackManager(playbackManager),
      m_timelineModel(timelineModel), m_mediaPool(mediaPool) {

  if (m_playbackManager) {
    connect(m_playbackManager, &PlaybackManager::frameChanged, this,
            &TimelineCompositor::onFrameChanged, Qt::QueuedConnection);
  }

  if (m_timelineModel) {
    connect(m_timelineModel, &QAbstractItemModel::dataChanged, this, [this]() {
      m_lastCompositedFrame = -1;
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    });
    connect(m_timelineModel, &QAbstractItemModel::rowsInserted, this, [this]() {
      m_lastCompositedFrame = -1;
      if (m_playbackManager) {
        onFrameChanged(m_playbackManager->currentFrame(), 0.0);
      }
    });
  }

  connect(
      &render::VideoFrameCache::instance(),
      &render::VideoFrameCache::frameReady, this,
      [this](const QString &assetId, qint64 frameIndex) {
        Q_UNUSED(assetId);
        Q_UNUSED(frameIndex);
        m_hasPendingRequest.store(true, std::memory_order_release);
        if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
          QMetaObject::invokeMethod(this,
                                    &TimelineCompositor::processPendingRender,
                                    Qt::QueuedConnection);
        }
      },
      Qt::QueuedConnection);

  connect(&render::VideoFrameCache::instance(),
          &render::VideoFrameCache::cacheRangesUpdated, this,
          &TimelineCompositor::updateTimelineCacheRanges, Qt::QueuedConnection);
}

void TimelineCompositor::updateTimelineCacheRanges() {
  if (!m_timelineModel || !m_playbackManager) {
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    return;
  }

  auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
  auto marker = scratchpad.getMarker();

  FrameIndex currentTimelineFrame = m_playbackManager->currentFrame();
  int trackCount = m_timelineModel->rowCount();
  TimelineClip *activeClip = nullptr;

  for (int i = 0; i < trackCount; ++i) {
    auto *track = m_timelineModel->getTrack(i);
    if (track && track->kind() == TrackKind::Video) {
      auto *clip = track->findClipAtFrame(currentTimelineFrame);
      if (clip && !clip->isMuted()) {
        activeClip = clip;
        break;
      }
    }
  }

  if (!activeClip) {
    m_cachedStartFrame = -1;
    m_cachedEndFrame = -1;
    m_cachedRanges.clear();
    scratchpad.resetToMarker(marker);

    emit cacheRangeChanged(-1, -1);
    emit cachedRangesChanged(m_cachedRanges);
    return;
  }

  auto *decoder =
      m_mediaPool ? m_mediaPool->getDecoder(activeClip->assetId()) : nullptr;
  double nativeFps =
      (decoder && decoder->nativeFps() > 0.0) ? decoder->nativeFps() : 30.0;

  double projectFps = 30.0;
  if (m_playbackManager->projectManager() &&
      m_playbackManager->projectManager()->hasActiveProject()) {
    if (const auto *proj =
            m_playbackManager->projectManager()->activeProject()) {
      if (proj->fps() > 0.0) {
        projectFps = proj->fps();
      }
    }
  }

  QVariantList mediaRanges =
      render::VideoFrameCache::instance().getCacheRangesForAsset(
          activeClip->assetId());

  QVariantList timelineRanges;
  int64_t overallStart = -1;
  int64_t overallEnd = -1;

  for (const QVariant &item : mediaRanges) {
    QVariantMap seg = item.toMap();
    qint64 startMediaFrame = seg["start"].toLongLong();
    qint64 endMediaFrame = seg["end"].toLongLong();

    double startSec = static_cast<double>(startMediaFrame) / nativeFps;
    double endSec = static_cast<double>(endMediaFrame) / nativeFps;

    int64_t startTL = activeClip->startFrame() +
                      static_cast<int64_t>(std::round(startSec * projectFps)) -
                      activeClip->sourceInFrame();

    int64_t endTL = activeClip->startFrame() +
                    static_cast<int64_t>(std::round(endSec * projectFps)) -
                    activeClip->sourceInFrame();

    QVariantMap timelineSeg;
    timelineSeg["start"] = static_cast<qlonglong>(startTL);
    timelineSeg["end"] = static_cast<qlonglong>(endTL);
    timelineRanges.append(timelineSeg);

    if (overallStart == -1 || startTL < overallStart)
      overallStart = startTL;
    if (overallEnd == -1 || endTL > overallEnd)
      overallEnd = endTL;
  }

  bool rangesChanged = (m_cachedRanges != timelineRanges);
  m_cachedRanges = timelineRanges;
  m_cachedStartFrame = overallStart;
  m_cachedEndFrame = overallEnd;

  scratchpad.resetToMarker(marker);

  if (rangesChanged) {
    emit cacheRangeChanged(m_cachedStartFrame, m_cachedEndFrame);
    emit cachedRangesChanged(m_cachedRanges);
  }
}

void TimelineCompositor::onFrameChanged(FrameIndex frameIndex,
                                        double timeSeconds) {
  Q_UNUSED(timeSeconds);

  bool isScrubbing =
      m_playbackManager ? m_playbackManager->isScrubbing() : false;
  if (!isScrubbing) {
    m_lastCompositedFrame = -1;
  }

  m_latestRequestedFrame.store(frameIndex, std::memory_order_release);
  m_hasPendingRequest.store(true, std::memory_order_release);

  if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
    QMetaObject::invokeMethod(this, &TimelineCompositor::processPendingRender,
                              Qt::QueuedConnection);
  }
}

void TimelineCompositor::processPendingRender() {
  while (true) {
    if (!m_timelineModel) {
      m_renderInProgress.store(false, std::memory_order_release);
      return;
    }

    FrameIndex frameIndex =
        m_latestRequestedFrame.exchange(-1, std::memory_order_acq_rel);
    if (frameIndex < 0) {
      frameIndex = m_currentTimelineFrame.load(std::memory_order_acquire);
    }
    m_hasPendingRequest.store(false, std::memory_order_release);

    if (frameIndex < 0 || frameIndex == m_lastCompositedFrame) {
      m_renderInProgress.store(false, std::memory_order_release);
      if (m_hasPendingRequest.load(std::memory_order_acquire)) {
        if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
          continue;
        }
      }
      return;
    }

    m_lastCompositedFrame = frameIndex;
    m_currentTimelineFrame.store(frameIndex, std::memory_order_release);

    auto &scratchpad = memory::XylaArena::threadLocalScratchpad();
    auto marker = scratchpad.getMarker();

    double projectFps = 30.0;
    if (m_playbackManager && m_playbackManager->projectManager() &&
        m_playbackManager->projectManager()->hasActiveProject()) {
      if (const auto *proj =
              m_playbackManager->projectManager()->activeProject()) {
        if (proj->fps() > 0.0) {
          projectFps = proj->fps();
        }
      }
    }

    bool isPlaying = m_playbackManager ? m_playbackManager->isPlaying() : false;
    bool isScrubbing =
        m_playbackManager ? m_playbackManager->isScrubbing() : false;

    int direction = 1;
    if (m_playbackManager) {
      direction = m_playbackManager->isPlayingReverse() ? -1 : 1;
    }

    int trackCount = m_timelineModel->rowCount();
    std::vector<render::RenderLayer> activeLayers;
    bool hasVisibleClipsAtPlayhead = false;

    double scrubVelocity =
        m_playbackManager ? m_playbackManager->scrubVelocity() : 0.0;

    // BOTTOM-TO-TOP Track Compositing
    for (int i = trackCount - 1; i >= 0; --i) {
      auto *track = m_timelineModel->getTrack(i);
      if (!track || track->kind() != TrackKind::Video || track->isMuted()) {
        continue;
      }

      auto *clip = track->findClipAtFrame(frameIndex);
      if (clip && !clip->isMuted()) {
        hasVisibleClipsAtPlayhead = true;

        FrameIndex timelineSourceFrame =
            (frameIndex - clip->startFrame()) + clip->sourceInFrame();

        auto *decoder = dynamic_cast<VulkanVideoDecoder *>(
            m_mediaPool ? m_mediaPool->getDecoder(clip->assetId()) : nullptr);

        if (decoder) {
          double nativeFps =
              decoder->nativeFps() > 0.0 ? decoder->nativeFps() : 30.0;
          int64_t actualMediaFrame = static_cast<int64_t>(std::floor(
              (static_cast<double>(timelineSourceFrame) * nativeFps) /
              projectFps));

          // Asynchronously notify lookahead engine
          render::FramePrefetcher::instance().updatePlayhead(
              clip->assetId(), actualMediaFrame, m_mediaPool, direction,
              isPlaying, isScrubbing, scrubVelocity);

          // Fast non-blocking texture probe
          auto [yView, uvView] =
              render::VideoFrameCache::instance().getFramePlanes(
                  clip->assetId(), actualMediaFrame, decoder, isPlaying,
                  isScrubbing, false, scrubVelocity);

          if (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE) {
            render::RenderLayer layer;
            layer.graph = clip->nodeGraph();
            layer.yView = yView;
            layer.uvView = uvView;
            layer.pushConstantValues = clip->pushConstantValues();
            activeLayers.push_back(layer);
          }
        }
      }
    }

    if (activeLayers.empty()) {
      // ONLY clear screen to black if this part of the timeline is truly empty.
      // If there IS a clip here but its texture is still decoding in the
      // background, DO NOT clear to black. Preserve the previous frame on
      // screen!
      if (!hasVisibleClipsAtPlayhead) {
        m_cachedStartFrame = -1;
        m_cachedEndFrame = -1;
        m_cachedRanges.clear();

        render::XylaRenderer::instance().renderFrame(
            std::vector<render::RenderLayer>{}, 1920, 1080);

        emit cacheRangeChanged(-1, -1);
        emit cachedRangesChanged(m_cachedRanges);
        emit frameComposited();
      }
    } else {
      render::XylaRenderer::instance().renderFrame(activeLayers, 1920, 1080);
      emit frameComposited();
    }

    scratchpad.resetToMarker(marker);

    // Check if new frame arrived during current render cycle
    if (!m_hasPendingRequest.load(std::memory_order_acquire)) {
      m_renderInProgress.store(false, std::memory_order_release);
      if (m_hasPendingRequest.load(std::memory_order_acquire)) {
        if (!m_renderInProgress.exchange(true, std::memory_order_acq_rel)) {
          continue;
        }
      }
      break;
    }
  }
}

} // namespace xyla
