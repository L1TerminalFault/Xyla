#include "core/log/logger.hpp"
#include "ui/models/timelineModel.hpp"

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
} // namespace xyla
