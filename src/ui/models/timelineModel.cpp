
#include "ui/models/timelineModel.hpp"
#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "core/log/logger.hpp"
#include "core/timeline/component/audioComponent.hpp"
#include "core/timeline/component/textComponent.hpp"
#include "core/timeline/component/transformComponent.hpp"
#include "core/undo/commands/timelineCommands.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QDebug>
#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>
#include <algorithm>
#include <qcolor.h>
#include <qfontdatabase.h>
#include <unordered_set>
#include <vector>

namespace xyla {

void TimelineModel::registerActions(xyla::XylaActionManager *actionMgr,
                                    xyla::PlaybackManager *playbackMgr) {
  if (!actionMgr) {
    return;
  }

  // Timeline Zoom In
  actionMgr->registerAction(
      {"timeline.zoomIn",
       {"Zoom In Timeline", "Magnify timeline horizontal view",
        "Expands timeline scale horizontally centered at the current viewport "
        "anchor",
        "https://docs.xyla.dev/timeline/navigation#zoomin"},
       "qrc:/assets/icons/zoom-in.svg",
       true,
       [this]() { setZoomFactor(std::min(10.0, getZoomFactor() * 1.35)); }});

  // Timeline Zoom Out
  actionMgr->registerAction(
      {"timeline.zoomOut",
       {"Zoom Out Timeline", "Reduce timeline horizontal view",
        "Compresses timeline scale horizontally to reveal a wider edit "
        "overview",
        "https://docs.xyla.dev/timeline/navigation#zoomout"},
       "qrc:/assets/icons/zoom-out.svg",
       true,
       [this]() { setZoomFactor(std::max(0.1, getZoomFactor() * 0.74)); }});

  // Timeline Zoom to Fit
  actionMgr->registerAction(
      {"timeline.zoomFit",
       {"Zoom to Fit", "Fit active project range to view",
        "Resets offset and scales zoom factor so all timeline clips fit inside "
        "the visible viewport",
        "https://docs.xyla.dev/timeline/navigation#zoomfit"},
       "qrc:/assets/icons/arrows-maximize.svg",
       true,
       [this]() {
         setHorizontalOffset(0.0);
         setZoomFactor(1.0);
       }});

  // Ripple Trim Start to Playhead (In)
  actionMgr->registerAction(
      {"timeline.rippleTrimIn",
       {"Ripple Trim Start to Playhead",
        "Trim clip start point to current playhead",
        "Trims in-point of selected clips to current playhead position and "
        "ripples subsequent clips leftward",
        "https://docs.xyla.dev/timeline/trimming#ripplein"},
       "",
       true,
       [this, playbackMgr]() {
         if (playbackMgr) {
           rippleTrimToPlayhead(playbackMgr->currentFrame(), true);
         }
       }});

  // Ripple Trim End to Playhead (Out)
  actionMgr->registerAction(
      {"timeline.rippleTrimOut",
       {"Ripple Trim End to Playhead",
        "Trim clip end point to current playhead",
        "Trims out-point of selected clips to current playhead position and "
        "closes the resulting gap",
        "https://docs.xyla.dev/timeline/trimming#rippleout"},
       "",
       true,
       [this, playbackMgr]() {
         if (playbackMgr) {
           rippleTrimToPlayhead(playbackMgr->currentFrame(), false);
         }
       }});

  // Razor / Split Clip
  actionMgr->registerAction(
      {"timeline.splitClip",
       {"Split Clip", "Razor clip at the current playhead frame",
        "Splits all active or selected clips precisely at the current playhead "
        "position into separate independent segments",
        "https://docs.xyla.dev/timeline/editing#split"},
       "qrc:/assets/icons/cut.svg",
       true,
       [this, playbackMgr]() {
         if (playbackMgr) {
           cutAtPlayhead(playbackMgr->currentFrame());
         }
       }});

  // Clip Deletion
  actionMgr->registerAction({"timeline.delete",
                             {"Delete", "Delete selected clips",
                              "Removes selected clips from the active timeline "
                              "leaving an empty gap (Lift operation)",
                              "https://docs.xyla.dev/timeline/editing#delete"},
                             "qrc:/assets/icons/trash.svg",
                             true,
                             [this]() { deleteSelectedClips(); }});

  actionMgr->registerAction(
      {"dopesheet.delete",
       {"Delete", "Delete selected keyframes",
        "Removes all currently selected keyframes in the dope sheet",
        "https://docs.xyla.dev/animation/dopesheet#delete"},
       "qrc:/assets/icons/trash.svg",
       true,
       [this]() { emit deleteSelectedKeyframesRequested(); }});

  // TODO: finish this
  actionMgr->registerAction({"timeline.copy",
                             {"Copy", "Copy selected clips",
                              "Copies selected clips to clipboard", ""},
                             "qrc:/assets/icons/copy.svg",
                             true,
                             [this]() {
                               XYLA_LOG_DEBUG("timeline action",
                                              "timeline copy triggered");
                             }});

  actionMgr->registerAction(
      {"timeline.paste",
       {"Paste", "Paste clips", "Pastes clips at playhead", ""},
       "qrc:/assets/icons/clipboard.svg",
       true,
       [this]() { /* stub for now */ }});

  actionMgr->registerAction(
      {"dopesheet.copy",
       {"Copy", "Copy selected keyframes",
        "Copies selected keyframes to the animation clipboard",
        "https://docs.xyla.dev/animation/dopesheet#copy"},
       "qrc:/assets/icons/copy.svg",
       true,
       [this]() { emit copyKeyframesRequested(); }});

  actionMgr->registerAction(
      {"dopesheet.paste",
       {"Paste", "Paste keyframes",
        "Pastes keyframes at current playhead frame",
        "https://docs.xyla.dev/animation/dopesheet#paste"},
       "qrc:/assets/icons/clipboard.svg",
       true,
       [this]() { emit pasteKeyframesRequested(); }});
  // Link Clips
  actionMgr->registerAction(
      {"timeline.linkClips",
       {"Link Clips", "Link selected audio and video clips together",
        "Binds selected video and audio elements so future move and trim "
        "operations move in sync",
        "https://docs.xyla.dev/timeline/clips#link"},
       "qrc:/assets/icons/link.svg",
       true,
       [this]() {
         if (canLinkSelection()) {
           linkSelectedClips();
         }
       }});

  // Unlink Clips
  actionMgr->registerAction(
      {"timeline.unlinkClips",
       {"Unlink Clips", "Sever link between selected audio and video",
        "Breaks synchronization link between selected tracks allowing "
        "individual editing",
        "https://docs.xyla.dev/timeline/clips#unlink"},
       "qrc:/assets/icons/unlink.svg",
       true,
       [this]() {
         if (canUnlinkSelection()) {
           unlinkSelectedClips();
         }
       }});

  // Clip Locking
  actionMgr->registerAction(
      {"timeline.toggleClipLock",
       {"Lock / Unlock Selected Clip", "Toggle edit lock on selected clips",
        "Prevents accidental moving, trimming, or deleting of the selected "
        "clips",
        "https://docs.xyla.dev/timeline/clips#lock"},
       "qrc:/assets/icons/lock.svg",
       true,
       [this]() {
         const QStringList ids = getSelectedClipIds();
         if (!ids.isEmpty()) {
           for (const QString &id : ids) {
             toggleClipLock(id);
           }
         } else if (!getSelectedClipId().isEmpty()) {
           toggleClipLock(getSelectedClipId());
         }
       }});

  // Snapping Toggle
  actionMgr->registerAction(
      {"timeline.toggleSnapping",
       {"Toggle Snapping", "Enable or disable clip edge snapping",
        "Toggles magnetic alignment when moving playhead or dragging clip "
        "boundaries",
        "https://docs.xyla.dev/timeline/navigation#snapping"},
       "qrc:/assets/icons/magnet.svg",
       true,
       [this]() { setSnappingEnabled(!m_snappingEnabled); }});
}

// queries and resolvers

void TimelineModel::setClipUniformScale(const QString &clipId, bool uniform) {
  auto *clip = findClip(clipId);
  if (!clip)
    return;

  clip->setIsUniformScale(uniform);

  if (auto *xform = clip->getComponent<TransformComponent>()) {
    xform->uniformScale = uniform;

    if (!uniform) {
      xform->scaleY = xform->scaleX;
    } else {
      xform->scaleY.clearKeyframes();
      xform->scaleY.setStaticValue(xform->scaleX.getStaticValue());
    }
  }

  emit clipPropertiesChanged(clip->getClipId());
  emit selectedClipDataChanged();
  markDirty();
  emit visualFrameInvalidated();
}

QVariantList TimelineModel::getClipWaveformPeaks(const QString &assetId,
                                                 int64_t startFrame,
                                                 int64_t durationFrames,
                                                 int targetPixels) const {
  QVariantList peaksList;
  if (assetId.isEmpty() || durationFrames <= 0 || targetPixels <= 0)
    return peaksList;

  const std::string assetKey = assetId.toStdString();
  auto clipBuffer =
      audio::AudioTimelineManager::instance().getClipBuffer(assetKey);
  if (!clipBuffer)
    return peaksList;

  auto pyramid =
      audio::WaveformGenerator::instance().getOrGenerate(assetKey, clipBuffer);
  if (!pyramid || !pyramid->isGenerated())
    return peaksList;

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  double sampleRate = 48000.0;
  const int64_t startSample = static_cast<int64_t>(
      (static_cast<double>(startFrame) / fps) * sampleRate);
  const size_t sampleCount = static_cast<size_t>(
      std::max(0.0, (static_cast<double>(durationFrames) / fps) * sampleRate));
  if (sampleCount == 0)
    return peaksList;

  const size_t pixels = static_cast<size_t>(std::clamp(targetPixels, 1, 8192));
  auto peaks = pyramid->getPeaks(0, startSample, sampleCount, pixels);

  peaksList.reserve(static_cast<int>(peaks.size()));
  for (const auto &p : peaks) {
    QVariantMap map;
    map.insert(QStringLiteral("min"), p.min);
    map.insert(QStringLiteral("max"), p.max);
    peaksList.append(std::move(map));
  }
  return peaksList;
}

// queries and resolvers

TimelineClip *TimelineModel::findClip(const QString &clipId) {
  if (clipId.isEmpty()) {
    return nullptr;
  }
  for (auto &track : m_tracks) {
    if (!track)
      continue;
    if (auto *c = track->findClip(clipId)) {
      return c;
    }
  }
  return nullptr;
}

QVariantMap TimelineModel::getSelectedClipData() const {
  if (m_selectedClipId.isEmpty()) {
    return {};
  }

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    const auto *clip = m_tracks[t]->findClip(m_selectedClipId);
    if (clip) {
      QVariantMap data;
      data["clipId"] = clip->getClipId();
      data["name"] = clip->getName();
      data["assetId"] = clip->getAssetId();
      data["trackIndex"] = static_cast<int>(t);
      data["startFrame"] = static_cast<double>(clip->getTiming().startFrame);
      data["durationFrames"] =
          static_cast<double>(clip->getTiming().durationFrames);
      data["sourceInFrame"] =
          static_cast<double>(clip->getTiming().sourceInFrame);
      data["trackIndex"] = static_cast<int>(t);
      data["trackKind"] = static_cast<int>(m_tracks[t]->getKind());
      data["isAudio"] = (m_tracks[t]->getKind() == TrackKind::Audio);

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip->getAssetId(), currentFps);
        if (totalFrames > 0) {
          data["sourceDurationFrames"] = static_cast<double>(totalFrames);
        }
      }

      auto graph = clip->getNodeGraph();
      if (graph) {
        data["nodes"] = graph->toVariantList();
        data["links"] = graph->linksToVariantList();
        data["editorNodes"] = graph->listEditorNodes();
        data["defaultEditorNodeId"] = graph->defaultEditorNodeId();
      }
      return data;
    }
  }
  return {};
}

QVariantList TimelineModel::getAllClips() const {
  QVariantList all;
  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t])
      continue;

    const bool isAudioTrack = (m_tracks[t]->getKind() == TrackKind::Audio);
    const int trackKindInt = static_cast<int>(m_tracks[t]->getKind());

    for (const auto &clip : m_tracks[t]->getClips()) {
      QVariantMap map;
      map["clipId"] = clip.getClipId();
      map["name"] = clip.getName();
      map["assetId"] = clip.getAssetId();
      map["linkGroupId"] = m_linkGraph.getGroupId(clip.getClipId());
      map["startFrame"] = static_cast<double>(clip.getTiming().startFrame);
      map["durationFrames"] =
          static_cast<double>(clip.getTiming().durationFrames);
      map["sourceInFrame"] =
          static_cast<double>(clip.getTiming().sourceInFrame);
      map["trackIndex"] = static_cast<int>(t);
      map["trackKind"] = trackKindInt;
      map["isAudio"] = isAudioTrack;

      if (m_mediaPool) {
        qlonglong totalFrames =
            m_mediaPool->getAssetDurationFrames(clip.getAssetId(), currentFps);
        if (totalFrames > 0) {
          map["sourceDurationFrames"] = static_cast<double>(totalFrames);
        }
      }

      all.append(map);
    }
  }
  return all;
}

QVariantList TimelineModel::getClipsForTrack(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  if (!track)
    return {};

  const auto *proj =
      m_projectManager ? m_projectManager->activeProject() : nullptr;
  const double currentFps = proj ? proj->fps() : 30.0;
  const bool isAudioTrack = (track->getKind() == TrackKind::Audio);
  const int trackKindInt = static_cast<int>(track->getKind());

  QVariantList list;
  for (const auto &clip : track->getClips()) {
    QVariantMap map;
    map["clipId"] = clip.getClipId();
    map["name"] = clip.getName();
    map["assetId"] = clip.getAssetId();
    map["linkGroupId"] = m_linkGraph.getGroupId(clip.getClipId());
    map["startFrame"] = static_cast<double>(clip.getTiming().startFrame);
    map["durationFrames"] =
        static_cast<double>(clip.getTiming().durationFrames);
    map["sourceInFrame"] = static_cast<double>(clip.getTiming().sourceInFrame);
    map["trackIndex"] = trackIndex;
    map["trackKind"] = trackKindInt;
    map["isAudio"] = isAudioTrack;

    if (m_mediaPool) {
      qlonglong totalFrames =
          m_mediaPool->getAssetDurationFrames(clip.getAssetId(), currentFps);
      if (totalFrames > 0) {
        map["sourceDurationFrames"] = static_cast<double>(totalFrames);
      }
    }

    list.append(map);
  }
  return list;
}

QString TimelineModel::addClip(const QString &assetId, const QString &name,
                               int trackIndex, int64_t startFrame,
                               int64_t durationFrames, int64_t sourceInFrame) {
  if (assetId.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineModel", "addClip rejected: assetId is empty!");
    return "";
  }

  if (durationFrames <= 0) {
    XYLA_LOG_ERROR("TimelineModel",
                   std::format("addClip rejected: durationFrames must be > 0! "
                               "Received: {} for asset: '{}'",
                               durationFrames, assetId.toStdString()));
    return "";
  }

  auto *targetTrk = getTrack(trackIndex);
  if (!targetTrk) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format(
            "addClip rejected: trackIndex {} is out of range! Total tracks: {}",
            trackIndex, m_tracks.size()));
    return "";
  }

  if (targetTrk->getIsLocked()) {
    XYLA_LOG_WARN(
        "TimelineModel",
        std::format("addClip rejected: track {} is locked.", trackIndex));
    return "";
  }

  bool hasVideo = false;
  bool hasAudio = false;

  if (m_mediaPool) {
    auto asset = m_mediaPool->getAsset(assetId);
    if (!asset) {
      QString realId = m_mediaPool->getAssetId(assetId);
      if (!realId.isEmpty()) {
        asset = m_mediaPool->getAsset(realId);
      }
    }

    if (asset) {
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    } else {
      XYLA_LOG_ERROR(
          "TimelineModel",
          std::format("addClip failed: asset '{}' not found in MediaPool!",
                      assetId.toStdString()));
      return "";
    }
  } else {
    XYLA_LOG_ERROR("TimelineModel", "addClip failed: MediaPool is null!");
    return "";
  }

  std::vector<AddClipsCommand::AddClipInfo> clipsToAdd;
  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString sharedGroupId;

  if (!hasVideo && hasAudio) {
    int audioTrackIndex = trackIndex;
    if (targetTrk->getKind() != TrackKind::Audio) {
      int firstAudio = firstAudioTrackIndex();
      if (firstAudio == -1) {
        XYLA_LOG_ERROR(
            "TimelineModel",
            "addClip failed: no audio tracks exist to place audio asset!");
        return "";
      }
      audioTrackIndex = firstAudio;
    }

    TimelineClipCreateInfo info{.clipId = primaryClipId,
                                .assetId = assetId,
                                .name = name,
                                .timing = {
                                    .startFrame = startFrame,
                                    .durationFrames = durationFrames,
                                    .sourceInFrame = sourceInFrame,
                                    .trackIndex = audioTrackIndex,
                                    .speed = 1.0,
                                }};

    TimelineClip audioClip(info);
    audioClip.addComponent(std::make_unique<xyla::AudioComponent>());
    clipsToAdd.push_back({std::move(audioClip), audioTrackIndex});
  } else {
    int videoTrackIndex = trackIndex;
    if (targetTrk->getKind() != TrackKind::Video) {
      int firstVideo = firstVideoTrackIndex();
      if (firstVideo == -1) {
        XYLA_LOG_ERROR(
            "TimelineModel",
            "addClip failed: no video tracks exist to place video asset!");
        return "";
      }
      videoTrackIndex = firstVideo;
    }

    if (hasAudio) {
      sharedGroupId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }

    TimelineClipCreateInfo videoInfo{.clipId = primaryClipId,
                                     .assetId = assetId,
                                     .name = name,
                                     .timing = {
                                         .startFrame = startFrame,
                                         .durationFrames = durationFrames,
                                         .sourceInFrame = sourceInFrame,
                                         .trackIndex = videoTrackIndex,
                                         .speed = 1.0,
                                     }};

    TimelineClip videoClip(videoInfo);
    videoClip.addComponent(std::make_unique<xyla::TransformComponent>());
    clipsToAdd.push_back({std::move(videoClip), videoTrackIndex});

    if (hasAudio) {
      int audioTrackIndex = findMatchingAudioTrack(videoTrackIndex);
      auto *audioTrk = getTrack(audioTrackIndex);

      if (audioTrk && audioTrk->getKind() == TrackKind::Audio) {
        QString audioClipId =
            QUuid::createUuid().toString(QUuid::WithoutBraces);

        TimelineClipCreateInfo audioInfo{.clipId = audioClipId,
                                         .assetId = assetId,
                                         .name = name,
                                         .timing = {
                                             .startFrame = startFrame,
                                             .durationFrames = durationFrames,
                                             .sourceInFrame = sourceInFrame,
                                             .trackIndex = audioTrackIndex,
                                             .speed = 1.0,
                                         }};

        TimelineClip audioClip(audioInfo);
        audioClip.addComponent(std::make_unique<AudioComponent>());
        clipsToAdd.push_back({std::move(audioClip), audioTrackIndex});
      }
    }
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<AddClipsCommand>(this, std::move(clipsToAdd),
                                                  sharedGroupId));
  } else {
    QStringList addedIds;
    for (const auto &item : clipsToAdd) {
      applyDirectAdd(item.clip, item.trackIndex);
      addedIds.append(item.clip.getClipId());
    }
    if (addedIds.size() > 1 && !sharedGroupId.isEmpty()) {
      applyDirectLink(addedIds, sharedGroupId);
    }
    applyDirectSelection(getLinkedClipIds(primaryClipId));
  }

  return primaryClipId;
}

void TimelineModel::applyDirectAdd(TimelineClip clip, int trackIndex) {
  if (auto *track = getTrack(trackIndex)) {
    track->insertClip(std::move(clip));
    if (m_animationManager) {
      clip.bindAnimationManager(*m_animationManager);
    }
    notifyTimelineChanged(trackIndex);
  }
}

bool TimelineModel::removeClip(const QString &clipId, int trackIndex) {
  if (clipId.isEmpty())
    return false;

  bool removed = false;
  int affectedTrack = -1;

  if (auto *track = getTrack(trackIndex)) {
    if (track->removeClip(clipId)) {
      removed = true;
      affectedTrack = trackIndex;
    }
  } else {
    for (size_t i = 0; i < m_tracks.size(); ++i) {
      if (m_tracks[i] && m_tracks[i]->removeClip(clipId)) {
        removed = true;
        affectedTrack = static_cast<int>(i);
        break;
      }
    }
  }

  if (removed) {
    m_selectedClipIds.removeAll(clipId);
    if (m_selectedClipId == clipId) {
      m_selectedClipId =
          m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
      emit selectedClipIdChanged(m_selectedClipId);
      emit selectedClipDataChanged();
    }
    emit selectedClipsChanged(m_selectedClipIds);
    notifyTimelineChanged(affectedTrack);
  }

  return removed;
}

void TimelineModel::applyDirectRemove(const QString &clipId, int trackIndex) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  m_linkGraph.unregisterClip(clipId);
  track->removeClip(clipId);
  notifyTimelineChanged(trackIndex);
}

void TimelineModel::deleteSelectedClips() {
  if (m_selectedClipIds.isEmpty())
    return;

  std::vector<DeleteClipsCommand::DeletedClipInfo> toDelete;
  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      toDelete.push_back({*c, c->getTiming().trackIndex});
    }
  }

  clearSelection();

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<DeleteClipsCommand>(this, std::move(toDelete)));
  } else {
    for (const auto &info : toDelete) {
      applyDirectRemove(info.clip.getClipId(), info.trackIndex);
    }
  }
}

// selection management

void TimelineModel::setSelectedClipId(const QString &clipId) {
  if (m_selectedClipId != clipId) {
    m_selectedClipId = clipId;
    if (m_selectedClipId.isEmpty()) {
      m_selectedClipIds.clear();
      m_lastSelectedClipId.clear();
    } else if (!m_selectedClipIds.contains(m_selectedClipId)) {
      m_selectedClipIds = QStringList{m_selectedClipId};
      m_lastSelectedClipId = m_selectedClipId;
    }
    emit selectedClipIdChanged(m_selectedClipId);
    emit selectedClipsChanged(m_selectedClipIds);
    emit selectedClipDataChanged();
  }
}

void TimelineModel::startSelectionBatch() {
  m_isBatchingSelection = true;
  m_selectionBatchStart = m_selectedClipIds;
}

void TimelineModel::commitSelectionBatch() {
  if (!m_isBatchingSelection)
    return;
  m_isBatchingSelection = false;

  if (m_selectionBatchStart != m_selectedClipIds) {
    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<SelectClipsCommand>(
          this, m_selectionBatchStart, m_selectedClipIds));
    }
  }
  m_selectionBatchStart.clear();
}

void TimelineModel::applyDirectSelection(const QStringList &selection) {
  m_selectedClipIds = selection;
  m_selectedClipId =
      m_selectedClipIds.isEmpty() ? "" : m_selectedClipIds.last();
  m_lastSelectedClipId = m_selectedClipId;

  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit selectedClipDataChanged();
}

void TimelineModel::selectBox(int64_t startFrame, int64_t endFrame,
                              int startTrack, int endTrack, bool toggle) {
  int minT = std::max(0, std::min(startTrack, endTrack));
  int maxT = std::min(static_cast<int>(m_tracks.size()) - 1,
                      std::max(startTrack, endTrack));

  int64_t minF = std::max<int64_t>(0, std::min(startFrame, endFrame));
  int64_t maxF = std::max(startFrame, endFrame);

  QStringList boxSelection;
  for (int t = minT; t <= maxT; ++t) {
    if (!m_tracks[t])
      continue;
    for (const auto &c : m_tracks[t]->getClips()) {
      if (c.getTiming().startFrame < maxF && c.getTiming().endFrame() > minF) {
        QStringList linked = getLinkedClipIds(c.getClipId());
        for (const auto &lid : linked) {
          if (!boxSelection.contains(lid)) {
            boxSelection.append(lid);
          }
        }
      }
    }
  }

  QStringList newSelection;
  if (toggle) {
    newSelection =
        m_isBatchingSelection ? m_selectionBatchStart : m_selectedClipIds;
    for (const auto &id : boxSelection) {
      if (newSelection.contains(id)) {
        newSelection.removeAll(id);
      } else {
        newSelection.append(id);
      }
    }
  } else {
    newSelection = boxSelection;
  }

  if (m_isBatchingSelection) {
    applyDirectSelection(newSelection);
  } else {
    if (newSelection == m_selectedClipIds)
      return;
    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                       newSelection));
    } else {
      applyDirectSelection(newSelection);
    }
  }
}

void TimelineModel::clearSelection() {
  if (m_selectedClipIds.isEmpty() && m_selectedClipId.isEmpty())
    return;

  QStringList emptyList;
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     emptyList));
  } else {
    applyDirectSelection(emptyList);
  }
}

void TimelineModel::selectClip(const QString &clipId, bool toggle,
                               bool isRange) {
  auto *clickedClip = findClip(clipId);
  if (!clickedClip)
    return;

  QStringList newSelection;

  if (isRange && !m_lastSelectedClipId.isEmpty()) {
    auto *anchorClip = findClip(m_lastSelectedClipId);
    if (anchorClip) {
      int minT = std::min(anchorClip->getTiming().trackIndex,
                          clickedClip->getTiming().trackIndex);
      int maxT = std::max(anchorClip->getTiming().trackIndex,
                          clickedClip->getTiming().trackIndex);

      int64_t minF = std::min(anchorClip->getTiming().startFrame,
                              clickedClip->getTiming().startFrame);
      int64_t maxF = std::max(anchorClip->getTiming().endFrame(),
                              clickedClip->getTiming().endFrame());

      for (int t = minT; t <= maxT; ++t) {
        if (!getTrack(t))
          continue;

        for (const auto &c : m_tracks[t]->getClips()) {
          if (c.getTiming().startFrame < maxF &&
              c.getTiming().endFrame() > minF) {
            QStringList linked = getLinkedClipIds(c.getClipId());
            for (const auto &lid : linked) {
              if (!newSelection.contains(lid)) {
                newSelection.append(lid);
              }
            }
          }
        }
      }
    } else {
      newSelection = getLinkedClipIds(clipId);
      m_lastSelectedClipId = clipId;
    }
  } else if (toggle) {
    newSelection = m_selectedClipIds;
    QStringList targetIds = getLinkedClipIds(clipId);

    bool allIn = true;
    for (const auto &id : targetIds) {
      if (!newSelection.contains(id)) {
        allIn = false;
        break;
      }
    }

    if (allIn) {
      for (const auto &id : targetIds) {
        newSelection.removeAll(id);
      }
    } else {
      for (const auto &id : targetIds) {
        if (!newSelection.contains(id)) {
          newSelection.append(id);
        }
      }
      m_lastSelectedClipId = clipId;
    }
  } else {
    newSelection = getLinkedClipIds(clipId);
    m_lastSelectedClipId = clipId;
  }

  if (newSelection == m_selectedClipIds)
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<SelectClipsCommand>(this, m_selectedClipIds,
                                                     newSelection));
  } else {
    applyDirectSelection(newSelection);
  }
}

// linking

bool TimelineModel::canLinkSelection() const {
  if (m_selectedClipIds.size() < 2)
    return false;

  QString firstGroupId;
  bool hasFirst = false;
  bool allSameGroup = true;

  for (const auto &id : m_selectedClipIds) {
    if (!findClip(id))
      continue;

    const QString groupId = m_linkGraph.getGroupId(id);
    if (groupId.isEmpty()) {
      return true;
    }

    if (!hasFirst) {
      firstGroupId = groupId;
      hasFirst = true;
    } else if (groupId != firstGroupId) {
      allSameGroup = false;
    }
  }

  return hasFirst && !allSameGroup;
}

bool TimelineModel::canUnlinkSelection() const {
  for (const auto &id : m_selectedClipIds) {
    if (findClip(id) && m_linkGraph.hasLink(id)) {
      return true;
    }
  }
  return false;
}

void TimelineModel::linkSelectedClips() {
  if (m_selectedClipIds.size() < 2)
    return;

  std::vector<std::pair<QString, QString>> previousGroups;
  for (const auto &id : m_selectedClipIds) {
    if (findClip(id)) {
      previousGroups.emplace_back(id, m_linkGraph.getGroupId(id));
    }
  }

  QString newGroupId = QUuid::createUuid().toString(QUuid::WithoutBraces);

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<LinkClipsCommand>(
        this, m_selectedClipIds, newGroupId, std::move(previousGroups)));
    return;
  }

  applyDirectLink(m_selectedClipIds, newGroupId);
}

void TimelineModel::unlinkSelectedClips() {
  if (m_selectedClipIds.isEmpty())
    return;

  QStringList allToUnlink;
  std::vector<std::pair<QString, QString>> previousGroups;

  for (const auto &id : m_selectedClipIds) {
    const QStringList linked = getLinkedClipIds(id);
    for (const auto &lid : linked) {
      if (!allToUnlink.contains(lid)) {
        allToUnlink.append(lid);
        if (findClip(lid)) {
          previousGroups.emplace_back(lid, m_linkGraph.getGroupId(lid));
        }
      }
    }
  }

  if (allToUnlink.isEmpty())
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<UnlinkClipsCommand>(
        this, allToUnlink, std::move(previousGroups)));
    return;
  }

  applyDirectLink(allToUnlink, "");
}

void TimelineModel::applyDirectRestoreLinkGroups(
    const std::vector<std::pair<QString, QString>> &groups) {
  m_linkGraph.restoreLinkGroups(groups);

  for (const auto &[id, groupId] : groups) {
    if (const auto *c = findClip(id)) {
      emit clipPropertiesChanged(id);
      emit trackDataChanged(c->getTiming().trackIndex);
    }
  }

  emit selectedClipDataChanged();
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
}

// clip locking

bool TimelineModel::isClipLocked(const QString &clipId) const {
  return isClipOrGroupLocked(clipId);
}

void TimelineModel::setClipLocked(const QString &clipId, bool locked) {
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<LockClipCommand>(this, clipId, locked));
    return;
  }
  applyDirectClipLock(clipId, locked);
}

void TimelineModel::toggleClipLock(const QString &clipId) {
  setClipLocked(clipId, !isClipLocked(clipId));
}

bool TimelineModel::isClipOrGroupLocked(const QString &clipId) const {
  const auto *clip = findClip(clipId);
  if (!clip)
    return false;

  const QStringList linkedIds = m_linkGraph.getLinkedClipIds(clipId);
  for (const auto &id : linkedIds) {
    if (const auto *c = findClip(id)) {
      if (c->getIsLocked() || isTrackLocked(c->getTiming().trackIndex)) {
        return true;
      }
    }
  }

  return false;
}

void TimelineModel::applyDirectClipLock(const QString &clipId, bool locked) {
  const QStringList targetIds = m_linkGraph.getLinkedClipIds(clipId);
  std::unordered_set<int> changedTracks;

  for (const auto &id : targetIds) {
    if (auto *clip = findClip(id)) {
      if (clip->getIsLocked() != locked) {
        clip->setIsLocked(locked);
        emit clipPropertiesChanged(id);
        changedTracks.insert(clip->getTiming().trackIndex);
      }
    }
  }

  for (int trackIndex : changedTracks) {
    emit trackDataChanged(trackIndex);
  }

  emit selectedClipDataChanged();
  markDirty();
}

bool TimelineModel::insertClip(const QString &assetId, int64_t sourceIn,
                               int64_t sourceOut, int64_t playheadFrame,
                               int targetTrack) {
  if (assetId.isEmpty() || m_tracks.empty())
    return false;

  if (playheadFrame < 0) {
    playheadFrame = m_playbackManager ? m_playbackManager->currentFrame() : 0;
  }
  if (targetTrack < 0) {
    targetTrack = m_selectedTrackIndex >= 0 ? m_selectedTrackIndex
                                            : firstVideoTrackIndex();
  }
  if (!getTrack(targetTrack))
    return false;

  int64_t durationFrames = std::max<int64_t>(1, sourceOut - sourceIn + 1);

  QString assetName = "Clip";
  bool hasVideo = false;
  bool hasAudio = false;
  if (m_mediaPool) {
    if (auto asset = m_mediaPool->getAsset(assetId)) {
      assetName = asset->name();
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    }
  }
  if (!hasVideo && !hasAudio)
    hasVideo = true;

  struct TargetInfo {
    int trackIndex;
    bool isAudio;
  };
  std::vector<TargetInfo> targets;

  if (!hasVideo && hasAudio) {
    int aTrack = (getTrack(targetTrack)->getKind() == TrackKind::Audio)
                     ? targetTrack
                     : firstAudioTrackIndex();
    if (aTrack >= 0)
      targets.push_back({aTrack, true});
  } else {
    int vTrack = (getTrack(targetTrack)->getKind() == TrackKind::Video)
                     ? targetTrack
                     : firstVideoTrackIndex();
    if (vTrack >= 0)
      targets.push_back({vTrack, false});

    if (hasAudio) {
      int aTrack = findMatchingAudioTrack(vTrack);
      if (auto *tr = getTrack(aTrack)) {
        if (tr->getKind() == TrackKind::Audio)
          targets.push_back({aTrack, true});
      }
    }
  }

  if (targets.empty())
    return false;

  QString sharedGroupId =
      (targets.size() > 1) ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                           : "";
  QStringList newlyPlacedIds;
  std::vector<std::pair<QString, QString>> splitOldToNewIds;
  std::vector<ThreePointEditCommand::TrackDelta> deltas;

  std::unordered_set<int> tracksToRipple;
  if (m_globalRippleMode) {
    for (size_t t = 0; t < m_tracks.size(); ++t) {
      if (m_tracks[t] && !m_tracks[t]->getIsLocked())
        tracksToRipple.insert(static_cast<int>(t));
    }
  } else {
    for (const auto &tgt : targets)
      tracksToRipple.insert(tgt.trackIndex);
  }

  for (int tIdx : tracksToRipple) {
    auto *track = getTrack(tIdx);
    if (!track || track->getIsLocked())
      continue;

    ThreePointEditCommand::TrackDelta delta;
    delta.trackIndex = tIdx;

    for (const auto &c : track->getClips()) {
      if (c.getTiming().containsFrame(playheadFrame)) {
        ClipTiming oldTiming = c.getTiming();
        ClipTiming leftTiming = oldTiming;
        leftTiming.durationFrames = playheadFrame - oldTiming.startFrame;

        delta.modifiedClips.push_back(
            {c.getClipId(), tIdx, oldTiming, leftTiming});

        QString rightClipId =
            QUuid::createUuid().toString(QUuid::WithoutBraces);
        splitOldToNewIds.emplace_back(c.getClipId(), rightClipId);

        TimelineClipCreateInfo rightInfo{
            .clipId = rightClipId,
            .assetId = c.getAssetId(),
            .name = c.getName(),
            .timing = {
                .startFrame = playheadFrame + durationFrames,
                .durationFrames = oldTiming.endFrame() - playheadFrame,
                .sourceInFrame = oldTiming.sourceInFrame +
                                 (playheadFrame - oldTiming.startFrame),
                .trackIndex = tIdx,
                .speed = oldTiming.speed,
            }};
        delta.addedClips.push_back(TimelineClip(rightInfo));
      } else if (c.getTiming().startFrame >= playheadFrame) {
        ClipTiming oldTiming = c.getTiming();
        ClipTiming newTiming = oldTiming;
        newTiming.startFrame += durationFrames;
        delta.modifiedClips.push_back(
            {c.getClipId(), tIdx, oldTiming, newTiming});
      }
    }

    for (const auto &tgt : targets) {
      if (tgt.trackIndex == tIdx) {
        QString newClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        if (!sharedGroupId.isEmpty()) {
          newlyPlacedIds.append(newClipId);
        }

        TimelineClipCreateInfo newInfo{.clipId = newClipId,
                                       .assetId = assetId,
                                       .name = assetName,
                                       .timing = {
                                           .startFrame = playheadFrame,
                                           .durationFrames = durationFrames,
                                           .sourceInFrame = sourceIn,
                                           .trackIndex = tIdx,
                                           .speed = 1.0,
                                       }};
        delta.addedClips.push_back(TimelineClip(newInfo));
      }
    }

    deltas.push_back(std::move(delta));
  }

  auto cmd = std::make_unique<ThreePointEditCommand>(this, std::move(deltas),
                                                     "Insert Clip");
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::move(cmd));
  } else {
    cmd->redo();
  }

  if (!splitOldToNewIds.empty()) {
    m_linkGraph.splitLink(splitOldToNewIds);
  }

  if (newlyPlacedIds.size() > 1 && !sharedGroupId.isEmpty()) {
    applyDirectLink(newlyPlacedIds, sharedGroupId);
  }

  return true;
}

bool TimelineModel::overwriteClip(const QString &assetId, int64_t sourceIn,
                                  int64_t sourceOut, int64_t playheadFrame,
                                  int targetTrack) {
  if (assetId.isEmpty() || m_tracks.empty())
    return false;

  if (playheadFrame < 0) {
    playheadFrame = m_playbackManager ? m_playbackManager->currentFrame() : 0;
  }
  if (targetTrack < 0) {
    targetTrack = m_selectedTrackIndex >= 0 ? m_selectedTrackIndex
                                            : firstVideoTrackIndex();
  }
  if (!getTrack(targetTrack))
    return false;

  int64_t durationFrames = std::max<int64_t>(1, sourceOut - sourceIn + 1);
  int64_t rangeStart = playheadFrame;
  int64_t rangeEnd = playheadFrame + durationFrames;

  QString assetName = "Clip";
  bool hasVideo = false;
  bool hasAudio = false;
  if (m_mediaPool) {
    if (auto asset = m_mediaPool->getAsset(assetId)) {
      assetName = asset->name();
      hasVideo = !asset->metadata().videoStreams.empty();
      hasAudio = !asset->metadata().audioStreams.empty();
    }
  }
  if (!hasVideo && !hasAudio)
    hasVideo = true;

  struct TargetInfo {
    int trackIndex;
    bool isAudio;
  };
  std::vector<TargetInfo> targets;

  if (!hasVideo && hasAudio) {
    int aTrack = (getTrack(targetTrack)->getKind() == TrackKind::Audio)
                     ? targetTrack
                     : firstAudioTrackIndex();
    if (aTrack >= 0)
      targets.push_back({aTrack, true});
  } else {
    int vTrack = (getTrack(targetTrack)->getKind() == TrackKind::Video)
                     ? targetTrack
                     : firstVideoTrackIndex();
    if (vTrack >= 0)
      targets.push_back({vTrack, false});

    if (hasAudio) {
      int aTrack = findMatchingAudioTrack(vTrack);
      if (auto *tr = getTrack(aTrack)) {
        if (tr->getKind() == TrackKind::Audio)
          targets.push_back({aTrack, true});
      }
    }
  }

  if (targets.empty())
    return false;

  QString sharedGroupId =
      (targets.size() > 1) ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                           : "";
  QStringList newlyPlacedIds;
  std::vector<std::pair<QString, QString>> splitOldToNewIds;
  std::vector<ThreePointEditCommand::TrackDelta> deltas;

  for (const auto &tgt : targets) {
    auto *track = getTrack(tgt.trackIndex);
    if (!track || track->getIsLocked())
      continue;

    ThreePointEditCommand::TrackDelta delta;
    delta.trackIndex = tgt.trackIndex;

    for (const auto &c : track->getClips()) {
      if (c.getTiming().endFrame() <= rangeStart ||
          c.getTiming().startFrame >= rangeEnd) {
        continue;
      }

      ClipTiming oldTiming = c.getTiming();

      if (oldTiming.startFrame < rangeStart &&
          oldTiming.endFrame() > rangeEnd) {
        ClipTiming leftTiming = oldTiming;
        leftTiming.durationFrames = rangeStart - oldTiming.startFrame;
        delta.modifiedClips.push_back(
            {c.getClipId(), tgt.trackIndex, oldTiming, leftTiming});

        QString rightClipId =
            QUuid::createUuid().toString(QUuid::WithoutBraces);
        splitOldToNewIds.emplace_back(c.getClipId(), rightClipId);

        TimelineClipCreateInfo rightInfo{
            .clipId = rightClipId,
            .assetId = c.getAssetId(),
            .name = c.getName(),
            .timing = {
                .startFrame = rangeEnd,
                .durationFrames = oldTiming.endFrame() - rangeEnd,
                .sourceInFrame =
                    oldTiming.sourceInFrame + (rangeEnd - oldTiming.startFrame),
                .trackIndex = tgt.trackIndex,
                .speed = oldTiming.speed,
            }};
        delta.addedClips.push_back(TimelineClip(rightInfo));
      } else if (oldTiming.startFrame >= rangeStart &&
                 oldTiming.endFrame() <= rangeEnd) {
        delta.removedClips.push_back(c);
      } else if (oldTiming.startFrame < rangeStart &&
                 oldTiming.endFrame() <= rangeEnd) {
        ClipTiming newTiming = oldTiming;
        newTiming.durationFrames = rangeStart - oldTiming.startFrame;
        delta.modifiedClips.push_back(
            {c.getClipId(), tgt.trackIndex, oldTiming, newTiming});
      } else if (oldTiming.startFrame >= rangeStart &&
                 oldTiming.endFrame() > rangeEnd) {
        ClipTiming newTiming = oldTiming;
        int64_t cutOffset = rangeEnd - oldTiming.startFrame;
        newTiming.startFrame = rangeEnd;
        newTiming.durationFrames = oldTiming.durationFrames - cutOffset;
        newTiming.sourceInFrame = oldTiming.sourceInFrame + cutOffset;
        delta.modifiedClips.push_back(
            {c.getClipId(), tgt.trackIndex, oldTiming, newTiming});
      }
    }

    QString newClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!sharedGroupId.isEmpty()) {
      newlyPlacedIds.append(newClipId);
    }

    TimelineClipCreateInfo newInfo{.clipId = newClipId,
                                   .assetId = assetId,
                                   .name = assetName,
                                   .timing = {
                                       .startFrame = rangeStart,
                                       .durationFrames = durationFrames,
                                       .sourceInFrame = sourceIn,
                                       .trackIndex = tgt.trackIndex,
                                       .speed = 1.0,
                                   }};
    delta.addedClips.push_back(TimelineClip(newInfo));

    deltas.push_back(std::move(delta));
  }

  auto cmd = std::make_unique<xyla::ThreePointEditCommand>(
      this, std::move(deltas), "Overwrite Clip");
  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::move(cmd));
  } else {
    cmd->redo();
  }

  if (!splitOldToNewIds.empty()) {
    m_linkGraph.splitLink(splitOldToNewIds);
  }

  if (newlyPlacedIds.size() > 1 && !sharedGroupId.isEmpty()) {
    applyDirectLink(newlyPlacedIds, sharedGroupId);
  }

  return true;
}

void TimelineModel::notifyTimelineChanged(int trackA, int trackB) {
  // if (trackA >= 0) {
  //   emit trackDataChanged(trackA);
  // }
  // if (trackB >= 0 && trackB != trackA) {
  //   emit trackDataChanged(trackB);
  // }
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
  emit selectedClipDataChanged();
  markDirty();
}

void TimelineModel::shiftAllTracksAfter(FrameIndex fromFrame,
                                        int64_t deltaFrames,
                                        const QString &ignoreClipId) {
  for (auto &track : m_tracks) {
    if (track && !track->getIsLocked()) {
      track->shiftClipsAfter(fromFrame, deltaFrames, ignoreClipId);
    }
  }
}

bool TimelineModel::cutClip(const QString &clipId, int64_t frame) {
  auto *clip = findClip(clipId);
  if (!clip || !clip->getTiming().containsFrame(frame) ||
      frame <= clip->getTiming().startFrame) {
    return false;
  }

  QStringList linkedClipIds = getLinkedClipIds(clipId);
  QString newRightGroupId =
      m_linkGraph.hasLink(clipId)
          ? QUuid::createUuid().toString(QUuid::WithoutBraces)
          : "";

  std::vector<MultiCutCommand::CutInfo> cuts;
  for (const QString &id : linkedClipIds) {
    if (auto *c = findClip(id)) {
      if (c->getTiming().containsFrame(frame) &&
          frame > c->getTiming().startFrame) {
        QString newRightId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        cuts.push_back({id, c->getTiming().trackIndex, frame, newRightId,
                        newRightGroupId});
      }
    }
  }

  if (cuts.empty()) {
    return false;
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiCutCommand>(this, std::move(cuts)));
  } else {
    QStringList newSelected;
    for (const auto &c : cuts) {
      applyDirectCut(c.id, c.track, c.frame, c.rightId, c.rightGroupId);
      newSelected.append(c.rightId);
    }
    applyDirectSelection(newSelected);
  }

  return true;
}

bool TimelineModel::cutAtPlayhead(int64_t playheadFrame) {
  std::vector<TimelineClip *> clipsToCut;

  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      auto *track = getTrack(c->getTiming().trackIndex);
      if (!track || track->getIsLocked()) {
        continue;
      }
      if (c->getTiming().containsFrame(playheadFrame) &&
          playheadFrame > c->getTiming().startFrame) {
        clipsToCut.push_back(c);
      }
    }
  }

  if (clipsToCut.empty()) {
    for (const auto &track : m_tracks) {
      if (!track || track->getIsLocked()) {
        continue;
      }
      if (auto *c = track->findClipAtFrame(playheadFrame)) {
        if (c->getTiming().containsFrame(playheadFrame) &&
            playheadFrame > c->getTiming().startFrame) {
          clipsToCut.push_back(c);
        }
      }
    }
  }

  if (clipsToCut.empty()) {
    return false;
  }

  std::unordered_map<QString, QString> oldToNewGroupMap;
  for (auto *c : clipsToCut) {
    QString origGroup = m_linkGraph.getGroupId(c->getClipId());
    if (!origGroup.isEmpty() && !oldToNewGroupMap.count(origGroup)) {
      oldToNewGroupMap[origGroup] =
          QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
  }

  std::vector<MultiCutCommand::CutInfo> cuts;
  cuts.reserve(clipsToCut.size());

  for (auto *c : clipsToCut) {
    QString rightId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString origGroup = m_linkGraph.getGroupId(c->getClipId());
    QString rightGroupId =
        origGroup.isEmpty() ? "" : oldToNewGroupMap[origGroup];
    cuts.push_back({c->getClipId(), c->getTiming().trackIndex, playheadFrame,
                    rightId, rightGroupId});
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiCutCommand>(this, std::move(cuts)));
  } else {
    QStringList newSelected;
    for (const auto &c : cuts) {
      applyDirectCut(c.id, c.track, c.frame, c.rightId, c.rightGroupId);
      newSelected.append(c.rightId);
    }
    applyDirectSelection(newSelected);
  }

  return true;
}

void TimelineModel::applyDirectCut(const QString &clipId, int trackIndex,
                                   int64_t cutFrame,
                                   const QString &newRightClipId,
                                   const QString &newRightGroupId) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->splitClip(clipId, cutFrame, newRightClipId)) {
    if (!newRightGroupId.isEmpty()) {
      m_linkGraph.registerClip(newRightClipId, newRightGroupId);
    }
    notifyTimelineChanged(trackIndex);
  }
}

void TimelineModel::applyDirectUncut(const QString &leftClipId, int trackIndex,
                                     const QString &rightClipId) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->uncutClips(leftClipId, rightClipId)) {
    m_linkGraph.unregisterClip(rightClipId);
    notifyTimelineChanged(trackIndex);
  }
}

bool TimelineModel::moveClip(const QString &clipId, int fromTrack, int toTrack,
                             int64_t newStartFrame) {
  auto *src = getTrack(fromTrack);
  auto *dst = getTrack(toTrack);
  if (!src || !dst || src->getKind() != dst->getKind()) {
    return false;
  }

  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int64_t deltaFrames = newStartFrame - clip->getTiming().startFrame;
  int deltaTracks = toTrack - fromTrack;
  return moveClips(QStringList{clipId}, deltaFrames, deltaTracks);
}

bool TimelineModel::moveClips(const QStringList &clipIds, int64_t deltaFrames,
                              int deltaTracks) {
  if (clipIds.isEmpty() || (deltaFrames == 0 && deltaTracks == 0)) {
    return false;
  }

  std::vector<TimelineClip> movingClips;
  int64_t minStart = std::numeric_limits<int64_t>::max();

  QString leaderId =
      m_groupDragLeaderId.isEmpty() ? clipIds.first() : m_groupDragLeaderId;
  auto *leaderClip = findClip(leaderId);
  auto *leaderTrack =
      leaderClip ? getTrack(leaderClip->getTiming().trackIndex) : nullptr;
  TrackKind leaderKind =
      leaderTrack ? leaderTrack->getKind() : TrackKind::Video;

  for (const auto &id : clipIds) {
    if (auto *c = findClip(id)) {
      movingClips.push_back(*c);
      minStart =
          std::min(minStart, static_cast<int64_t>(c->getTiming().startFrame));
    }
  }

  if (movingClips.empty())
    return false;

  if (minStart + deltaFrames < 0) {
    deltaFrames = -minStart;
  }

  for (const auto &c : movingClips) {
    int srcIdx = c.getTiming().trackIndex;
    auto *srcTrack = getTrack(srcIdx);
    if (!srcTrack)
      return false;

    int effectiveDeltaTracks =
        (srcTrack->getKind() == leaderKind) ? deltaTracks : -deltaTracks;
    int targetTrackIdx = srcIdx + effectiveDeltaTracks;
    auto *dstTrack = getTrack(targetTrackIdx);

    if (!dstTrack || srcTrack->getKind() != dstTrack->getKind()) {
      return false;
    }

    ClipTiming targetTiming = c.getTiming();
    targetTiming.startFrame += deltaFrames;

    for (const auto &other : dstTrack->getClips()) {
      if (clipIds.contains(other.getClipId()))
        continue;
      if (targetTiming.startFrame < other.getTiming().endFrame() &&
          targetTiming.endFrame() > other.getTiming().startFrame) {
        return false;
      }
    }
  }

  std::vector<MoveClipsCommand::ClipMoveRecord> moves;
  for (const auto &c : movingClips) {
    int srcIdx = c.getTiming().trackIndex;
    auto *srcTrack = getTrack(srcIdx);
    int effectiveDeltaTracks =
        (srcTrack->getKind() == leaderKind) ? deltaTracks : -deltaTracks;
    int dstIdx = srcIdx + effectiveDeltaTracks;
    int64_t dstStart = c.getTiming().startFrame + deltaFrames;

    moves.push_back(
        {c.getClipId(), srcIdx, dstIdx, c.getTiming().startFrame, dstStart});
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MoveClipsCommand>(this, std::move(moves)));
    return true;
  }

  for (const auto &m : moves) {
    applyDirectMove(m.clipId, m.srcTrack, m.dstTrack, m.newStart);
  }
  return true;
}

void TimelineModel::applyDirectMove(const QString &clipId, int srcTrack,
                                    int dstTrack, int64_t newStart) {
  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  bool ok = (srcTrack == dstTrack)
                ? src->moveClip(clipId, newStart)
                : src->transferClipTo(clipId, *dst, newStart, dstTrack);

  if (ok) {
    notifyTimelineChanged(srcTrack, dstTrack);
  }
}

void TimelineModel::setGlobalRippleMode(bool enabled) {
  if (m_globalRippleMode != enabled) {
    m_globalRippleMode = enabled;
    emit globalRippleModeChanged(m_globalRippleMode);
  }
}

bool TimelineModel::rippleMoveClip(const QString &clipId, int toTrack,
                                   int64_t dropFrame, bool global) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  int srcTrack = clip->getTiming().trackIndex;
  if (!getTrack(toTrack))
    return false;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<RippleMoveCommand>(
        this, clipId, srcTrack, toTrack, dropFrame, global));
    return true;
  }

  FrameIndex origStart = 0;
  QString splitRightId;
  applyDirectRippleMove(clipId, srcTrack, toTrack, dropFrame, global, origStart,
                        splitRightId);
  return true;
}

void TimelineModel::applyDirectRippleMove(const QString &clipId, int srcTrack,
                                          int dstTrack, int64_t dropFrame,
                                          bool global,
                                          FrameIndex &outOriginalStart,
                                          QString &outSplitRightId) {
  outSplitRightId.clear();
  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  auto *clip = src->findClip(clipId);
  if (!clip)
    return;

  outOriginalStart = clip->getTiming().startFrame;
  int64_t clipDuration = clip->getTiming().durationFrames;
  TimelineClip movingClip = *clip;

  dropFrame = std::max<int64_t>(0, dropFrame);
  int64_t deltaFrames = dropFrame - outOriginalStart;
  if (deltaFrames == 0 && srcTrack == dstTrack)
    return;

  src->removeClip(clipId);

  if (global) {
    shiftAllTracksAfter(outOriginalStart, -clipDuration, clipId);
  } else {
    src->shiftClipsAfter(outOriginalStart, -clipDuration, clipId);
  }

  int64_t insertFrame = dst->resolveInsertFrame(dropFrame, clipDuration);
  if (global) {
    shiftAllTracksAfter(insertFrame, clipDuration, clipId);
  } else {
    dst->shiftClipsAfter(insertFrame, clipDuration, clipId);
  }

  ClipTiming newTiming = movingClip.getTiming();
  newTiming.startFrame = insertFrame;
  newTiming.trackIndex = dstTrack;
  movingClip.setTiming(newTiming);

  dst->insertClip(std::move(movingClip));
  notifyTimelineChanged(srcTrack, dstTrack);
}

void TimelineModel::applyDirectUndoRippleMove(const QString &clipId,
                                              int srcTrack, int dstTrack,
                                              int64_t dropFrame, bool global,
                                              FrameIndex originalStart,
                                              const QString &splitRightId) {
  Q_UNUSED(dropFrame);
  Q_UNUSED(splitRightId);

  auto *src = getTrack(srcTrack);
  auto *dst = getTrack(dstTrack);
  if (!src || !dst)
    return;

  auto *clip = dst->findClip(clipId);
  if (!clip)
    return;

  int64_t clipDuration = clip->getTiming().durationFrames;
  int64_t currentStart = clip->getTiming().startFrame;
  TimelineClip movingClip = *clip;

  dst->removeClip(clipId);

  if (global) {
    shiftAllTracksAfter(currentStart, -clipDuration, clipId);
    shiftAllTracksAfter(originalStart, clipDuration, clipId);
  } else {
    dst->shiftClipsAfter(currentStart, -clipDuration, clipId);
    src->shiftClipsAfter(originalStart, clipDuration, clipId);
  }

  ClipTiming restoredTiming = movingClip.getTiming();
  restoredTiming.startFrame = originalStart;
  restoredTiming.trackIndex = srcTrack;
  movingClip.setTiming(restoredTiming);

  src->insertClip(std::move(movingClip));
  notifyTimelineChanged(srcTrack, dstTrack);
}

bool TimelineModel::trimClip(const QString &clipId, int trackIndex,
                             int64_t newStartFrame, int64_t newDuration,
                             int64_t newSourceInFrame, bool isRipple) {
  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  if (clip->getComponent<xyla::TextComponent>()) {
    newSourceInFrame = 0;
  }
  int64_t deltaStart = newStartFrame - clip->getTiming().startFrame;
  int64_t deltaDuration = newDuration - clip->getTiming().durationFrames;
  int64_t deltaIn = newSourceInFrame - clip->getTiming().sourceInFrame;

  if (deltaStart == 0 && deltaDuration == 0 && deltaIn == 0) {
    return false;
  }

  QStringList linkedClipIds = getLinkedClipIds(clipId);

  for (const QString &lid : linkedClipIds) {
    auto *linkedClip = findClip(lid);
    if (!linkedClip)
      continue;

    int64_t targetStart =
        std::max<int64_t>(0, linkedClip->getTiming().startFrame + deltaStart);
    int64_t targetDur = std::max<int64_t>(
        1, linkedClip->getTiming().durationFrames + deltaDuration);
    int64_t targetIn =
        std::max<int64_t>(0, linkedClip->getTiming().sourceInFrame + deltaIn);
    int targetTrack = linkedClip->getTiming().trackIndex;

    if (auto *stack = XylaUndoStack::instance()) {
      stack->push(std::make_unique<TrimClipCommand>(
          this, lid, targetTrack, linkedClip->getTiming().startFrame,
          linkedClip->getTiming().durationFrames,
          linkedClip->getTiming().sourceInFrame, targetStart, targetDur,
          targetIn, isRipple, m_globalRippleMode));
    } else {
      applyDirectTrim(lid, targetTrack, targetStart, targetDur, targetIn,
                      isRipple, m_globalRippleMode);
    }
  }

  return true;
}

bool TimelineModel::rippleTrimToPlayhead(int64_t playheadFrame, bool trimIn) {
  struct Target {
    QString id;
    int track;
    int64_t start, dur, in;
  };
  std::vector<Target> targets;

  for (const auto &id : m_selectedClipIds) {
    if (auto *c = findClip(id)) {
      if (c->getTiming().containsFrame(playheadFrame)) {
        targets.push_back(
            {id, c->getTiming().trackIndex, c->getTiming().startFrame,
             c->getTiming().durationFrames, c->getTiming().sourceInFrame});
      }
    }
  }

  if (targets.empty()) {
    for (int t = 0; t < static_cast<int>(m_tracks.size()); ++t) {
      if (!m_tracks[t] || m_tracks[t]->getIsLocked())
        continue;
      if (auto *c = m_tracks[t]->findClipAtFrame(playheadFrame)) {
        targets.push_back({c->getClipId(), t, c->getTiming().startFrame,
                           c->getTiming().durationFrames,
                           c->getTiming().sourceInFrame});
      }
    }
  }

  if (targets.empty())
    return false;

  std::vector<MultiRippleTrimCommand::TrimAction> actions;
  int64_t maxDelta = 0;

  for (const auto &t : targets) {
    int64_t delta = 0;
    int64_t newStart = t.start, newDur = t.dur, newIn = t.in;

    if (trimIn && playheadFrame > t.start && playheadFrame < t.start + t.dur) {
      delta = playheadFrame - t.start;
      newStart = t.start;
      newDur = t.dur - delta;
      newIn = t.in + delta;
    } else if (!trimIn && playheadFrame > t.start &&
               playheadFrame <= t.start + t.dur) {
      newDur = playheadFrame - t.start;
      delta = newDur - t.dur;
    } else {
      continue;
    }

    actions.push_back(
        {t.id, t.track, t.start, t.dur, t.in, newStart, newDur, newIn});
    maxDelta = delta;
  }

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(std::make_unique<MultiRippleTrimCommand>(
        this, std::move(actions), maxDelta, m_globalRippleMode));
  } else {
    for (const auto &a : actions) {
      applyDirectTrim(a.clipId, a.trackIndex, a.newStart, a.newDur, a.newIn,
                      true, m_globalRippleMode);
    }
  }

  return true;
}

QString TimelineModel::registerCustomFont(const QString &filePath) {
  int fontId = QFontDatabase::addApplicationFont(filePath);
  if (fontId != -1) {
    QStringList families = QFontDatabase::applicationFontFamilies(fontId);
    if (!families.isEmpty()) {
      return families.first();
    }
  }
  return QString();
}
void TimelineModel::applyDirectTrim(const QString &clipId, int trackIndex,
                                    int64_t start, int64_t dur, int64_t in,
                                    bool isRipple, bool global, bool isUndo) {
  Q_UNUSED(isUndo);
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  auto *clip = track->findClip(clipId);
  if (!clip)
    return;

  FrameIndex currentEnd = clip->getTiming().endFrame();
  int64_t deltaFrames = dur - clip->getTiming().durationFrames;

  if (isRipple && deltaFrames > 0) {
    if (global) {
      shiftAllTracksAfter(currentEnd, deltaFrames, clipId);
    } else {
      track->shiftClipsAfter(currentEnd, deltaFrames, clipId);
    }
  }

  if (!track->trimClip(clipId, start, dur, in)) {
    if (isRipple && deltaFrames > 0) {
      if (global) {
        shiftAllTracksAfter(currentEnd + deltaFrames, -deltaFrames, clipId);
      } else {
        track->shiftClipsAfter(currentEnd + deltaFrames, -deltaFrames, clipId);
      }
    }
    return;
  }

  if (isRipple && deltaFrames < 0) {
    if (global) {
      shiftAllTracksAfter(currentEnd, deltaFrames, clipId);
    } else {
      track->shiftClipsAfter(currentEnd, deltaFrames, clipId);
    }
  }

  if (isRipple && global) {
    for (int t = 0; t < static_cast<int>(m_tracks.size()); ++t) {
      notifyTimelineChanged(t);
    }
  } else {
    notifyTimelineChanged(trackIndex);
  }
}

QVariantMap TimelineModel::querySnap(int64_t candidateStart, int64_t duration,
                                     int targetTrack, int64_t playheadFrame,
                                     double zoomFactor,
                                     const QStringList &ignoreClipIds,
                                     double snapPixelThreshold) const {
  if (zoomFactor <= 0.0) {
    return SnapResult1D{}.toVariantMap();
  }

  m_snapEngine.clearAll();

  m_snapEngine.addPoint(0.0, 0.0, "timeline_origin", 100);
  if (playheadFrame >= 0) {
    m_snapEngine.addPoint(static_cast<double>(playheadFrame), 0.0, "playhead",
                          50);
  }

  for (size_t t = 0; t < m_tracks.size(); ++t) {
    if (!m_tracks[t] || m_tracks[t]->getIsLocked())
      continue;

    for (const auto &c : m_tracks[t]->getClips()) {
      if (ignoreClipIds.contains(c.getClipId()))
        continue;

      m_snapEngine.addPoint(c.getTiming().startFrame, 0.0, "clip_edge", 10);
      m_snapEngine.addPoint(c.getTiming().endFrame(), 0.0, "clip_edge", 10);

      if (static_cast<int>(t) == targetTrack) {
        m_snapEngine.addIntervalX(c.getTiming().startFrame,
                                  c.getTiming().endFrame(), "track_gap");
      }
    }
  }

  double worldThreshold = snapPixelThreshold / zoomFactor;
  SnapResult1D result =
      m_snapEngine.snap1D(static_cast<double>(candidateStart),
                          static_cast<double>(duration), worldThreshold);

  return result.toVariantMap();
}

TimelineClip *TimelineModel::resolveVideoClip(const QString &clipId) {
  auto *clip = findClip(clipId);
  if (!clip)
    return nullptr;

  auto *track = getTrack(clip->getTiming().trackIndex);
  if (track && track->getKind() == TrackKind::Video) {
    return clip;
  }

  if (m_linkGraph.hasLink(clipId)) {
    QStringList linked = getLinkedClipIds(clipId);
    for (const auto &lid : linked) {
      if (auto *candidate = findClip(lid)) {
        auto *tr = getTrack(candidate->getTiming().trackIndex);
        if (tr && tr->getKind() == TrackKind::Video) {
          return candidate;
        }
      }
    }
  }

  return clip;
}

TimelineModel::TimelineModel(ProjectManager *projectManager,
                             MediaPool *mediaPool, XylaUndoStack *undoStack,
                             QObject *parent)
    : QAbstractListModel(parent), m_projectManager(projectManager),
      m_mediaPool(mediaPool), m_undoStack(undoStack) {

  m_animationTable = std::make_shared<anim::AnimationPropertyTable>();
  m_animationManager =
      std::make_unique<anim::AnimationManager>(undoStack, this);
  m_animationManager->setActiveTable(m_animationTable);

  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v2", "Video 2", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_v1", "Video 1", TrackKind::Video));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a1", "Audio 1", TrackKind::Audio));
  m_tracks.push_back(
      std::make_shared<TimelineTrack>("track_a2", "Audio 2", TrackKind::Audio));
}

ProjectManager *TimelineModel::projectManager() noexcept {
  return m_projectManager;
}

XylaUndoStack *TimelineModel::undoStack() const noexcept { return m_undoStack; }

void TimelineModel::setPlaybackManagerP(PlaybackManager *playbackManagerP) {
  m_playbackManager = playbackManagerP;
}

void TimelineModel::markDirty() {
  if (m_projectManager) {
    m_projectManager->setHasUnsavedChanges(true);
  }
}

int TimelineModel::rowCount(const QModelIndex &parent) const {
  Q_UNUSED(parent);
  return static_cast<int>(m_tracks.size());
}

QVariant TimelineModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      static_cast<size_t>(index.row()) >= m_tracks.size()) {
    return {};
  }

  const auto &track = m_tracks[index.row()];
  if (!track) {
    return {};
  }

  switch (role) {
  case TrackIdRole:
    return track->getTrackId();
  case TrackNameRole:
    return track->getName();
  case TrackKindRole:
    return static_cast<int>(track->getKind());
  case TrackLockedRole:
    return track->getIsLocked();
  case TrackMutedRole:
    return track->getIsMuted();
  case TrackSelectedRole:
    return (index.row() == m_selectedTrackIndex);
  default:
    return {};
  }
}

QHash<int, QByteArray> TimelineModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[TrackIdRole] = "trackId";
  roles[TrackNameRole] = "trackName";
  roles[TrackKindRole] = "trackKind";
  roles[TrackLockedRole] = "trackLocked";
  roles[TrackMutedRole] = "trackMuted";
  roles[TrackSelectedRole] = "isTrackSelected";
  return roles;
}

qint64 TimelineModel::getDurationFrames() const {
  int64_t maxFrame = 0;
  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    for (const auto &clip : track->getClips()) {
      if (clip.getTiming().endFrame() > maxFrame) {
        maxFrame = clip.getTiming().endFrame();
      }
    }
  }
  return maxFrame;
}

double TimelineModel::getZoomFactor() const noexcept { return m_zoomFactor; }

void TimelineModel::setZoomFactor(double factor) {
  factor = std::clamp(factor, 0.1, 10.0);
  if (std::abs(m_zoomFactor - factor) > 0.0001) {
    m_zoomFactor = factor;
    emit zoomFactorChanged(m_zoomFactor);
  }
}

double TimelineModel::getHorizontalOffset() const noexcept {
  return m_horizontalOffset;
}

void TimelineModel::setHorizontalOffset(double offset) {
  offset = std::max(0.0, offset);
  if (std::abs(m_horizontalOffset - offset) > 0.0001) {
    m_horizontalOffset = offset;
    emit horizontalOffsetChanged(m_horizontalOffset);
  }
}

bool TimelineModel::getSnappingEnabled() const noexcept {
  return m_snappingEnabled;
}

void TimelineModel::setSnappingEnabled(bool enabled) {
  if (m_snappingEnabled != enabled) {
    m_snappingEnabled = enabled;
    emit snappingEnabledChanged(m_snappingEnabled);
  }
}

bool TimelineModel::getGlobalRippleMode() const noexcept {
  return m_globalRippleMode;
}

size_t TimelineModel::trackCount() const noexcept { return m_tracks.size(); }

const std::vector<std::shared_ptr<TimelineTrack>> &
TimelineModel::tracks() const noexcept {
  return m_tracks;
}

void TimelineModel::addTrack(std::shared_ptr<TimelineTrack> track) {
  if (!track)
    return;

  int insertIndex = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), insertIndex, insertIndex);
  m_tracks.push_back(std::move(track));
  endInsertRows();

  emit trackCountChanged();
  markDirty();
}

void TimelineModel::addVideoTrack() {
  int videoCount = 0;
  for (const auto &t : m_tracks) {
    if (t && t->getKind() == TrackKind::Video) {
      videoCount++;
    }
  }

  auto track = std::make_shared<TimelineTrack>(
      QUuid::createUuid().toString(QUuid::WithoutBraces),
      QString("Video %1").arg(videoCount + 1), TrackKind::Video);

  beginInsertRows(QModelIndex(), 0, 0);
  m_tracks.insert(m_tracks.begin(), track);
  endInsertRows();

  emit trackCountChanged();
  markDirty();
}

void TimelineModel::addAudioTrack() {
  int audioCount = 0;
  for (const auto &t : m_tracks) {
    if (t && t->getKind() == TrackKind::Audio) {
      audioCount++;
    }
  }

  auto track = std::make_shared<TimelineTrack>(
      QUuid::createUuid().toString(QUuid::WithoutBraces),
      QString("Audio %1").arg(audioCount + 1), TrackKind::Audio);

  int insertIndex = static_cast<int>(m_tracks.size());
  beginInsertRows(QModelIndex(), insertIndex, insertIndex);
  m_tracks.push_back(track);
  endInsertRows();

  emit trackCountChanged();
  markDirty();
}

void TimelineModel::createDefaultTracks(int videoCount, int audioCount) {
  beginResetModel();
  m_tracks.clear();

  for (int i = 0; i < videoCount; ++i) {
    int videoNum = videoCount - i;
    auto track = std::make_shared<TimelineTrack>(
        QUuid::createUuid().toString(QUuid::WithoutBraces),
        QString("Video %1").arg(videoNum), TrackKind::Video);
    m_tracks.push_back(track);
  }

  for (int i = 0; i < audioCount; ++i) {
    int audioNum = i + 1;
    auto track = std::make_shared<TimelineTrack>(
        QUuid::createUuid().toString(QUuid::WithoutBraces),
        QString("Audio %1").arg(audioNum), TrackKind::Audio);
    m_tracks.push_back(track);
  }

  endResetModel();
  emit trackCountChanged();
  markDirty();
}

int TimelineModel::getTrackKind(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? static_cast<int>(track->getKind()) : -1;
}

int TimelineModel::firstAudioTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getKind() == TrackKind::Audio) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int TimelineModel::firstVideoTrackIndex() const {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getKind() == TrackKind::Video) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int TimelineModel::findMatchingAudioTrack(int videoTrackIndex) const {
  std::vector<int> videoTracks;
  std::vector<int> audioTracks;

  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i]) {
      if (m_tracks[i]->getKind() == TrackKind::Video) {
        videoTracks.push_back(static_cast<int>(i));
      } else if (m_tracks[i]->getKind() == TrackKind::Audio) {
        audioTracks.push_back(static_cast<int>(i));
      }
    }
  }

  if (audioTracks.empty())
    return -1;

  auto it = std::find(videoTracks.begin(), videoTracks.end(), videoTrackIndex);
  size_t vRank =
      (it != videoTracks.end()) ? std::distance(videoTracks.begin(), it) : 0;

  size_t targetAudioRank = 0;
  if (!videoTracks.empty()) {
    size_t distFromDivider = (videoTracks.size() - 1) - vRank;
    targetAudioRank = std::min(distFromDivider, audioTracks.size() - 1);
  }

  return audioTracks[targetAudioRank];
}

bool TimelineModel::isTrackLocked(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? track->getIsLocked() : false;
}

void TimelineModel::setTrackLocked(int trackIndex, bool locked) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<xyla::LockTrackCommand>(this, trackIndex, locked));
    return;
  }
  applyDirectTrackLock(trackIndex, locked);
}

void TimelineModel::applyDirectTrackLock(int trackIndex, bool locked) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->getIsLocked() != locked) {
    track->setIsLocked(locked);
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                     {TrackLockedRole});
    markDirty();
  }
}

void TimelineModel::toggleTrackLock(int trackIndex) {
  setTrackLocked(trackIndex, !isTrackLocked(trackIndex));
}

bool TimelineModel::isTrackMuted(int trackIndex) const {
  auto *track = getTrack(trackIndex);
  return track ? track->getIsMuted() : false;
}

void TimelineModel::setTrackMuted(int trackIndex, bool muted) {
  auto *track = getTrack(trackIndex);
  if (!track)
    return;

  if (track->getIsMuted() != muted) {
    track->setIsMuted(muted);
    emit trackDataChanged(trackIndex);
    emit dataChanged(index(trackIndex, 0), index(trackIndex, 0),
                     {TrackMutedRole});
    markDirty();
  }
}

void TimelineModel::toggleTrackMute(int trackIndex) {
  setTrackMuted(trackIndex, !isTrackMuted(trackIndex));
}

int TimelineModel::getSelectedTrackIndex() const noexcept {
  return m_selectedTrackIndex;
}

QString TimelineModel::getSelectedTrackId() const noexcept {
  auto *track = getTrack(m_selectedTrackIndex);
  return track ? track->getTrackId() : QString();
}

void TimelineModel::setSelectedTrackIndex(int trackIndex) {
  selectTrack(trackIndex);
}

void TimelineModel::selectTrack(int trackIndex) {
  if (trackIndex < 0 || static_cast<size_t>(trackIndex) >= m_tracks.size()) {
    return;
  }

  if (m_selectedTrackIndex == trackIndex) {
    return;
  }

  int prevIndex = m_selectedTrackIndex;
  m_selectedTrackIndex = trackIndex;

  if (auto *prevTrack = getTrack(prevIndex)) {
    prevTrack->setIsSelected(false);
    emit dataChanged(index(prevIndex, 0), index(prevIndex, 0),
                     {TrackSelectedRole});
  }

  if (auto *curTrack = getTrack(m_selectedTrackIndex)) {
    curTrack->setIsSelected(true);
    emit dataChanged(index(m_selectedTrackIndex, 0),
                     index(m_selectedTrackIndex, 0), {TrackSelectedRole});
  }

  emit selectedTrackIndexChanged(m_selectedTrackIndex);
}

void TimelineModel::selectTrackById(const QString &trackId) {
  for (size_t i = 0; i < m_tracks.size(); ++i) {
    if (m_tracks[i] && m_tracks[i]->getTrackId() == trackId) {
      selectTrack(static_cast<int>(i));
      return;
    }
  }
}

QJsonObject TimelineModel::serialize() const {
  QJsonObject obj;
  obj[QStringLiteral("globalRippleMode")] = m_globalRippleMode;
  obj[QStringLiteral("snappingEnabled")] = m_snappingEnabled;
  obj[QStringLiteral("zoomFactor")] = m_zoomFactor;
  obj[QStringLiteral("horizontalOffset")] = m_horizontalOffset;

  if (m_animationTable) {
    obj[QStringLiteral("animationTable")] = m_animationTable->serialize();
  }

  QJsonArray tracksArray;
  for (const auto &track : m_tracks) {
    if (track) {
      tracksArray.append(track->serialize());
    }
  }
  obj[QStringLiteral("tracks")] = tracksArray;

  obj[QStringLiteral("linkGraph")] = m_linkGraph.serialize();

  return obj;
}

void TimelineModel::deserialize(const QJsonObject &obj) {
  beginResetModel();

  m_tracks.clear();
  m_linkGraph.clear();
  m_selectedClipIds.clear();
  m_selectedClipId.clear();
  m_groupDragLeaderId.clear();
  m_groupDragDeltaFrames = 0;
  m_groupDragDeltaTracks = 0;

  m_globalRippleMode =
      obj.value(QStringLiteral("globalRippleMode")).toBool(false);
  m_snappingEnabled = obj.value(QStringLiteral("snappingEnabled")).toBool(true);
  m_zoomFactor = obj.value(QStringLiteral("zoomFactor")).toDouble(1.0);
  m_horizontalOffset =
      obj.value(QStringLiteral("horizontalOffset")).toDouble(0.0);

  // 1. RESTORE ANIMATION PROPERTY TABLE
  if (!m_animationTable) {
    m_animationTable = std::make_shared<anim::AnimationPropertyTable>();
  } else {
    m_animationTable->clear();
  }

  if (obj.contains(QStringLiteral("animationTable")) &&
      obj[QStringLiteral("animationTable")].isObject()) {
    m_animationTable->deserialize(
        obj[QStringLiteral("animationTable")].toObject());
  }

  if (m_animationManager) {
    m_animationManager->setActiveTable(m_animationTable);
  }

  // 2. RESTORE TRACKS & CLIPS
  QJsonArray tracksArray = obj.value(QStringLiteral("tracks")).toArray();
  for (const auto &trackVal : tracksArray) {
    if (trackVal.isObject()) {
      auto track = TimelineTrack::deserialize(trackVal.toObject());
      if (track) {
        m_tracks.push_back(std::move(track));
      }
    }
  }

  // 3. BIND LOADED CLIPS TO ANIMATION MANAGER (Fixed loop syntax)
  if (m_animationManager) {
    for (auto &track : m_tracks) {
      if (!track)
        continue;
      for (const auto &clip : track->getClips()) {
        const_cast<TimelineClip &>(clip).bindAnimationManager(
            *m_animationManager);
      }
    }
  }

  // 4. RESTORE LINK GRAPH
  if (obj.contains(QStringLiteral("linkGraph")) &&
      obj[QStringLiteral("linkGraph")].isObject()) {
    m_linkGraph.deserialize(obj[QStringLiteral("linkGraph")].toObject());
  }

  endResetModel();

  emit trackCountChanged();
  emit selectedClipsChanged(m_selectedClipIds);
  emit selectedClipIdChanged(m_selectedClipId);
  emit globalRippleModeChanged(m_globalRippleMode);
  emit snappingEnabledChanged(m_snappingEnabled);
  emit zoomFactorChanged(m_zoomFactor);
  emit horizontalOffsetChanged(m_horizontalOffset);
}

void TimelineModel::clearTimeline() {
  beginResetModel();
  m_tracks.clear();
  m_linkGraph.clear();
  m_selectedClipIds.clear();
  m_selectedClipId.clear();
  endResetModel();
  emit trackCountChanged();
  markDirty();
}

QString TimelineModel::getSelectedClipId() const noexcept {
  return m_selectedClipId;
}

QStringList TimelineModel::getSelectedClipIds() const noexcept {
  return m_selectedClipIds;
}

int TimelineModel::getGroupDragDeltaFrames() const noexcept {
  return m_groupDragDeltaFrames;
}

int TimelineModel::getGroupDragDeltaTracks() const noexcept {
  return m_groupDragDeltaTracks;
}

QString TimelineModel::getGroupDragLeaderId() const noexcept {
  return m_groupDragLeaderId;
}

void TimelineModel::updateGroupDrag(const QString &leaderId, int deltaFrames,
                                    int deltaTracks) {
  if (m_groupDragLeaderId != leaderId ||
      m_groupDragDeltaFrames != deltaFrames ||
      m_groupDragDeltaTracks != deltaTracks) {
    m_groupDragLeaderId = leaderId;
    m_groupDragDeltaFrames = deltaFrames;
    m_groupDragDeltaTracks = deltaTracks;
    emit groupDragChanged();
  }
}

void TimelineModel::clearGroupDrag() { updateGroupDrag("", 0, 0); }

xyla::TimelineTrack *TimelineModel::getTrack(int index) const noexcept {
  if (index < 0 || static_cast<size_t>(index) >= m_tracks.size()) {
    return nullptr;
  }
  return m_tracks[static_cast<size_t>(index)].get();
}

QStringList TimelineModel::getLinkedClipIds(const QString &clipId) const {
  return m_linkGraph.getLinkedClipIds(clipId);
}

void TimelineModel::applyDirectLink(const QStringList &clipIds,
                                    const QString &groupId) {
  if (groupId.isEmpty()) {
    m_linkGraph.unlink(clipIds);
  } else {
    m_linkGraph.link(clipIds, groupId);
  }

  for (const auto &id : clipIds) {
    if (const auto *c = findClip(id)) {
      emit clipPropertiesChanged(id);
      emit trackDataChanged(c->getTiming().trackIndex);
    }
  }

  emit selectedClipDataChanged();
  emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
}

const TimelineClip *TimelineModel::findClip(const QString &clipId) const {
  if (clipId.isEmpty())
    return nullptr;
  for (const auto &track : m_tracks) {
    if (!track)
      continue;
    if (const auto *c = track->findClip(clipId))
      return c;
  }
  return nullptr;
}

bool TimelineModel::updateClipProperty(const QString &clipId,
                                       const QString &propertyId,
                                       const QVariant &value) {
  if (clipId.isEmpty() || propertyId.isEmpty())
    return false;

  auto *clip = findClip(clipId);
  if (!clip)
    return false;

  const int64_t currentFrame =
      m_playbackManager ? m_playbackManager->currentFrame() : 0;
  const FrameIndex localFrame =
      clip->getTiming().timelineToLocalFrame(currentFrame);

  // Try to set on the selected clip directly (Works for Text, Transform,
  // Font, etc.)
  if (clip->setProperty(propertyId, value, localFrame)) {
    notifyTimelineChanged(clip->getTiming().trackIndex);
    emit clipPropertiesChanged(clip->getClipId());
    emit selectedClipDataChanged();
    markDirty();
    emit visualFrameInvalidated();
    return true;
  }

  // If the selected clip didn't handle it, try its linked clips (e.g. Linked
  // Audio for Volume)
  bool anyLinkedHandled = false;
  const auto linkedIds = m_linkGraph.getLinkedClipIds(clipId);
  for (const auto &id : linkedIds) {
    if (id == clipId)
      continue;
    if (auto *linked = findClip(id)) {
      const FrameIndex linkedLocal =
          linked->getTiming().timelineToLocalFrame(currentFrame);
      if (linked->setProperty(propertyId, value, linkedLocal)) {
        anyLinkedHandled = true;
        notifyTimelineChanged(linked->getTiming().trackIndex);
        emit clipPropertiesChanged(linked->getClipId());
      }
    }
  }

  if (anyLinkedHandled) {
    emit selectedClipDataChanged();
    markDirty();
    emit visualFrameInvalidated();
    return true;
  }

  XYLA_LOG_WARN(
      "TimelineModel",
      std::format("updateClipProperty: property '{}' not handled by clip '{}'.",
                  propertyId.toStdString(), clipId.toStdString()));
  return false;
}

int64_t TimelineModel::getAssetDuration(const QString &assetId) const {
  if (assetId.startsWith("asset_title_") || assetId.startsWith("asset_svg_")) {
    return 86400 * 60;
  }

  if (!m_mediaPool)
    return 0;

  auto asset = m_mediaPool->getAsset(assetId);
  if (!asset)
    return 0;

  double fps = 30.0;
  if (m_playbackManager && m_playbackManager->projectManager() &&
      m_playbackManager->projectManager()->hasActiveProject()) {
    if (const auto *proj =
            m_playbackManager->projectManager()->activeProject()) {
      if (proj->fps() > 0.0) {
        fps = proj->fps();
      }
    }
  }

  return asset->metadata().durationFrames(fps);
}

QString TimelineModel::addTitleClip(int trackIndex, int64_t startFrame,
                                    int64_t durationFrames,
                                    const QString &text) {
  if (durationFrames <= 0) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format("addTitleClip rejected: durationFrames must be > 0! "
                    "Received: {}",
                    durationFrames));
    return "";
  }

  auto *targetTrk = getTrack(trackIndex);
  if (!targetTrk) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format("addTitleClip rejected: trackIndex {} is out of range! "
                    "Total tracks: {}",
                    trackIndex, m_tracks.size()));
    return "";
  }

  if (targetTrk->getIsLocked()) {
    XYLA_LOG_WARN(
        "TimelineModel",
        std::format("addTitleClip rejected: track {} is locked.", trackIndex));
    return "";
  }

  int videoTrackIndex = trackIndex;
  if (targetTrk->getKind() != TrackKind::Video) {
    int firstVideo = firstVideoTrackIndex();
    if (firstVideo == -1) {
      XYLA_LOG_ERROR(
          "TimelineModel",
          "addTitleClip failed: no video tracks exist to place title clip!");
      return "";
    }
    videoTrackIndex = firstVideo;
  }

  auto *finalTrk = getTrack(videoTrackIndex);
  ClipTiming timing{
      .startFrame = static_cast<FrameIndex>(startFrame),
      .durationFrames = static_cast<FrameIndex>(durationFrames),
      .sourceInFrame = 0,
      .trackIndex = videoTrackIndex,
      .speed = 1.0,
  };

  if (finalTrk && finalTrk->hasCollision(timing)) {
    XYLA_LOG_WARN("TimelineModel",
                  std::format("addTitleClip rejected: collision detected on "
                              "track {} at frame {}.",
                              videoTrackIndex, startFrame));
    return "";
  }

  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString clipName = text.trimmed().isEmpty() ? QStringLiteral("Title") : text;

  TimelineClipCreateInfo info{
      .clipId = primaryClipId,
      .assetId = QString("asset_title_%1").arg(primaryClipId),
      .name = clipName,
      .timing = timing,
  };

  TimelineClip titleClip = TimelineClip::createTitleClip(info, clipName);

  // --- BIND ANIMATION MANAGER ---
  if (m_animationManager) {
    titleClip.bindAnimationManager(*m_animationManager);
  } else {
    XYLA_LOG_WARN("TimelineModel",
                  "addTitleClip: m_animationManager is NULL on TimelineModel! "
                  "Clip cannot allocate table handles!");
  }

  std::vector<AddClipsCommand::AddClipInfo> clipsToAdd;
  clipsToAdd.push_back({std::move(titleClip), videoTrackIndex});

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<AddClipsCommand>(this, std::move(clipsToAdd), ""));
  } else {
    for (const auto &item : clipsToAdd) {
      applyDirectAdd(item.clip, item.trackIndex);
    }
    applyDirectSelection({primaryClipId});
  }

  return primaryClipId;
}

QString TimelineModel::addSvgClip(const QString &filePath, int trackIndex,
                                  int64_t startFrame, int64_t durationFrames) {
  if (filePath.trimmed().isEmpty()) {
    XYLA_LOG_ERROR("TimelineModel", "addSvgClip rejected: filePath is empty!");
    return "";
  }

  QFileInfo fileInfo(filePath);
  if (!fileInfo.exists() || !fileInfo.isFile()) {
    XYLA_LOG_ERROR("TimelineModel",
                   std::format("addSvgClip rejected: file '{}' does not exist!",
                               filePath.toStdString()));
    return "";
  }

  if (durationFrames <= 0) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format("addSvgClip rejected: durationFrames must be > 0! "
                    "Received: {}",
                    durationFrames));
    return "";
  }

  auto *targetTrk = getTrack(trackIndex);
  if (!targetTrk) {
    XYLA_LOG_ERROR(
        "TimelineModel",
        std::format("addSvgClip rejected: trackIndex {} is out of range! "
                    "Total tracks: {}",
                    trackIndex, m_tracks.size()));
    return "";
  }

  if (targetTrk->getIsLocked()) {
    XYLA_LOG_WARN(
        "TimelineModel",
        std::format("addSvgClip rejected: track {} is locked.", trackIndex));
    return "";
  }

  int videoTrackIndex = trackIndex;
  if (targetTrk->getKind() != TrackKind::Video) {
    int firstVideo = firstVideoTrackIndex();
    if (firstVideo == -1) {
      XYLA_LOG_ERROR(
          "TimelineModel",
          "addSvgClip failed: no video tracks exist to place SVG clip!");
      return "";
    }
    videoTrackIndex = firstVideo;
  }

  auto *finalTrk = getTrack(videoTrackIndex);
  ClipTiming timing{
      .startFrame = static_cast<FrameIndex>(startFrame),
      .durationFrames = static_cast<FrameIndex>(durationFrames),
      .sourceInFrame = 0,
      .trackIndex = videoTrackIndex,
      .speed = 1.0,
  };

  if (finalTrk && finalTrk->hasCollision(timing)) {
    XYLA_LOG_WARN(
        "TimelineModel",
        std::format(
            "addSvgClip rejected: collision detected on track {} at frame {}.",
            videoTrackIndex, startFrame));
    return "";
  }

  QString primaryClipId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString clipName = fileInfo.fileName().isEmpty()
                         ? QStringLiteral("Vector Graphic")
                         : fileInfo.fileName();

  TimelineClipCreateInfo info{
      .clipId = primaryClipId,
      .assetId = filePath,
      .name = clipName,
      .timing = timing,
  };

  TimelineClip svgClip = TimelineClip::createSvgClip(info, filePath);

  // --- BIND ANIMATION MANAGER ---
  if (m_animationManager) {
    svgClip.bindAnimationManager(*m_animationManager);
  } else {
    XYLA_LOG_WARN("TimelineModel",
                  "addSvgClip: m_animationManager is NULL on TimelineModel! "
                  "Clip cannot allocate table handles!");
  }

  std::vector<AddClipsCommand::AddClipInfo> clipsToAdd;
  clipsToAdd.push_back({std::move(svgClip), videoTrackIndex});

  if (auto *stack = XylaUndoStack::instance()) {
    stack->push(
        std::make_unique<AddClipsCommand>(this, std::move(clipsToAdd), ""));
  } else {
    for (const auto &item : clipsToAdd) {
      applyDirectAdd(item.clip, item.trackIndex);
    }
    applyDirectSelection({primaryClipId});
  }

  return primaryClipId;
}

} // namespace xyla
