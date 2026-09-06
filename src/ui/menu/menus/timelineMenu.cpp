#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupTimelineActions() {
  registerMenuItem("Timeline/Tracks", {"timeline.add_track",
                                       {"Add Track", "Add generic track", ""},
                                       "",
                                       "",
                                       "qrc:/assets/icons/plus.svg",
                                       true,
                                       [this]() { emit requestAddTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.add_video_track",
                    {"Add Video Track", "Add video track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/video-plus.svg",
                    true,
                    [this]() { emit requestAddVideoTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.add_audio_track",
                    {"Add Audio Track", "Add audio track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music-plus.svg",
                    true,
                    [this]() { emit requestAddAudioTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.delete_track",
                    {"Delete Track", "Delete selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/trash.svg",
                    true,
                    [this]() { emit requestDeleteTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.delete_video_track",
                    {"Delete Video Track", "Delete selected video track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/video-minus.svg",
                    true,
                    [this]() { emit requestDeleteVideoTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.delete_audio_track",
                    {"Delete Audio Track", "Delete selected audio track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music-minus.svg",
                    true,
                    [this]() { emit requestDeleteAudioTrack(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.move_track_up",
                    {"Move Track Up", "Move selected track up", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-up.svg",
                    true,
                    [this]() { emit requestMoveTrackUp(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.move_track_down",
                    {"Move Track Down", "Move selected track down", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-down.svg",
                    true,
                    [this]() { emit requestMoveTrackDown(); }});

  registerMenuItem("Timeline/Tracks",
                   {"timeline.merge_tracks",
                    {"Merge Tracks", "Merge selected tracks", ""},
                    "",
                    "",
                    "qrc:/assets/icons/git-merge.svg",
                    true,
                    [this]() { emit requestMergeTracks(); }});

  registerSeparator("Timeline/Track State");

  registerMenuItem("Timeline/Track State",
                   {"timeline.lock_track",
                    {"Lock Track", "Lock selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock.svg",
                    true,
                    [this]() { emit requestLockTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.unlock_track",
                    {"Unlock Track", "Unlock selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock-open.svg",
                    true,
                    [this]() { emit requestUnlockTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.mute_track",
                    {"Mute Track", "Mute selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume-off.svg",
                    true,
                    [this]() { emit requestMuteTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.unmute_track",
                    {"Unmute Track", "Unmute selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume.svg",
                    true,
                    [this]() { emit requestUnmuteTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.solo_track",
                    {"Solo Track", "Solo selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/headphones.svg",
                    true,
                    [this]() { emit requestSoloTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.unsolo_track",
                    {"Unsolo Track", "Remove solo from track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/headphones-off.svg",
                    true,
                    [this]() { emit requestUnsoloTrack(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.set_track_color",
                    {"Set Track Color...", "Set track display color", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestSetTrackColor(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.set_track_name",
                    {"Set Track Name...", "Rename selected track", ""},
                    "",
                    "",
                    "qrc:/assets/icons/edit.svg",
                    true,
                    [this]() { emit requestSetTrackName(); }});

  registerMenuItem("Timeline/Track State",
                   {"timeline.sync_tracks",
                    {"Sync Tracks", "Synchronize selected tracks", ""},
                    "",
                    "",
                    "qrc:/assets/icons/clock.svg",
                    true,
                    [this]() { emit requestSyncTracks(); }});

  registerMenuItem(
      "Timeline/Track State",
      {"timeline.toggle_track_linking",
       {"Toggle Track Linking", "Enable/disable track linking", ""},
       "",
       "",
       "qrc:/assets/icons/link.svg",
       true,
       [this]() { emit requestToggleTrackLinking(); }});

  registerSeparator("Timeline/Gaps");

  registerMenuItem("Timeline/Gaps",
                   {"timeline.insert_gap",
                    {"Insert Gap", "Insert gap at playhead", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layout-gap.svg",
                    true,
                    [this]() { emit requestInsertGap(); }});

  registerMenuItem("Timeline/Gaps", {"timeline.delete_gap",
                                     {"Delete Gap", "Delete selected gap", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/trash.svg",
                                     true,
                                     [this]() { emit requestDeleteGap(); }});

  registerMenuItem("Timeline/Gaps",
                   {"timeline.ripple_delete_gap",
                    {"Ripple Delete Gap", "Delete gap and ripple timeline", ""},
                    "",
                    "",
                    "qrc:/assets/icons/trash-x.svg",
                    true,
                    [this]() { emit requestRippleDeleteGap(); }});

  registerMenuItem("Timeline/Gaps",
                   {"timeline.close_gap",
                    {"Close Gap", "Close nearest timeline gap", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-horizontal.svg",
                    true,
                    [this]() { emit requestCloseGap(); }});

  registerSeparator("Timeline/Snapping");

  registerMenuItem("Timeline/Snapping",
                   {"timeline.snap_grid",
                    {"Snap to Grid", "Snap edits to grid intervals", ""},
                    "",
                    "",
                    "qrc:/assets/icons/grid-dots.svg",
                    true,
                    [this]() { emit requestSnapToGrid(); }});

  registerMenuItem("Timeline/Snapping",
                   {"timeline.snap_frames",
                    {"Snap to Frames", "Snap edits to frame boundaries", ""},
                    "",
                    "",
                    "qrc:/assets/icons/frame.svg",
                    true,
                    [this]() { emit requestSnapToFrames(); }});

  registerMenuItem("Timeline/Snapping",
                   {"timeline.snap_markers",
                    {"Snap to Markers", "Snap edits to timeline markers", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bookmark.svg",
                    true,
                    [this]() { emit requestSnapToMarkers(); }});

  registerMenuItem("Timeline/Snapping",
                   {"timeline.snap_clips",
                    {"Snap to Clips", "Snap edits to clip edges", ""},
                    "",
                    "",
                    "qrc:/assets/icons/magnet.svg",
                    true,
                    [this]() { emit requestSnapToClips(); }});

  registerSeparator("Timeline/In-Out");

  registerMenuItem("Timeline/In-Out",
                   {"timeline.set_in",
                    {"Set In Point", "Set in point at playhead", ""},
                    "I",
                    "I",
                    "qrc:/assets/icons/bracket-left.svg",
                    true,
                    [this]() { emit requestSetInPoint(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.set_out",
                    {"Set Out Point", "Set out point at playhead", ""},
                    "O",
                    "O",
                    "qrc:/assets/icons/bracket-right.svg",
                    true,
                    [this]() { emit requestSetOutPoint(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.clear_in",
                    {"Clear In Point", "Clear current in point", ""},
                    "Alt+I",
                    "Alt+I",
                    "qrc:/assets/icons/bracket-left-off.svg",
                    true,
                    [this]() { emit requestClearInPoint(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.clear_out",
                    {"Clear Out Point", "Clear current out point", ""},
                    "Alt+O",
                    "Alt+O",
                    "qrc:/assets/icons/bracket-right-off.svg",
                    true,
                    [this]() { emit requestClearOutPoint(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.clear_in_out",
                    {"Clear In/Out Points", "Clear both in and out points", ""},
                    "Alt+X",
                    "Alt+X",
                    "qrc:/assets/icons/clear-all.svg",
                    true,
                    [this]() { emit requestClearInOutPoints(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.goto_in",
                    {"Go to In Point", "Move playhead to in point", ""},
                    "Shift+I",
                    "Shift+I",
                    "qrc:/assets/icons/player-skip-back.svg",
                    true,
                    [this]() { emit requestGoToInPoint(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.goto_out",
                    {"Go to Out Point", "Move playhead to out point", ""},
                    "Shift+O",
                    "Shift+O",
                    "qrc:/assets/icons/player-skip-forward.svg",
                    true,
                    [this]() { emit requestGoToOutPoint(); }});

  registerMenuItem(
      "Timeline/In-Out",
      {"timeline.select_in_out",
       {"Select In/Out Range", "Select clips within in/out range", ""},
       "",
       "",
       "qrc:/assets/icons/select.svg",
       true,
       [this]() { emit requestSelectInOutPoints(); }});

  registerMenuItem("Timeline/In-Out",
                   {"timeline.ripple_select_in_out",
                    {"Ripple Select In/Out Range",
                     "Ripple-select clips within in/out range", ""},
                    "",
                    "",
                    "qrc:/assets/icons/select-all.svg",
                    true,
                    [this]() { emit requestRippleSelectInOutPoints(); }});

  registerMenuItem(
      "Timeline/In-Out",
      {"timeline.zoom_in_out",
       {"Zoom to In/Out Points", "Zoom timeline to in/out range", ""},
       "",
       "",
       "qrc:/assets/icons/zoom-fit.svg",
       true,
       [this]() { emit requestZoomToInOutPoints(); }});
}
} // namespace xyla
