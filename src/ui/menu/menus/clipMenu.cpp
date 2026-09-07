#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupClipActions() {
  registerMenuItem("Clip/Add Clip",
                   {"clip.add_video",
                    {"Video Clip", "Add a video track clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/video.svg",
                    true,
                    [this]() { emit requestAddVideoClip(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_audio",
                    {"Audio Clip", "Add an audio track clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music.svg",
                    true,
                    [this]() { emit requestAddAudioClip(); }});

  registerMenuItem("Clip/Add Clip", {"clip.add_image",
                                     {"Image", "Add a static image clip", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/photo.svg",
                                     true,
                                     [this]() { emit requestAddImageClip(); }});

  registerMenuItem("Clip/Add Clip", {"clip.add_text",
                                     {"Text", "Add a title or text clip", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/text.svg",
                                     true,
                                     [this]() { emit requestAddTextClip(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_vector",
                    {"Vector", "Add a vector graphics clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/vector.svg",
                    true,
                    [this]() { emit requestAddVectorClip(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_subtitle",
                    {"Subtitle", "Add a subtitle track element", ""},
                    "",
                    "",
                    "qrc:/assets/icons/subtitles.svg",
                    true,
                    [this]() { emit requestAddSubtitleClip(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_adjustment",
                    {"Adjustment Clip", "Add an adjustment layer clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/adjustments.svg",
                    true,
                    [this]() { emit requestAddAdjustmentClip(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_color_matte",
                    {"Color Matte", "Add a color matte clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/square.svg",
                    true,
                    [this]() { emit requestAddColorMatte(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_title_template",
                    {"Title Template", "Add a title template clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/typography.svg",
                    true,
                    [this]() { emit requestAddTitleTemplate(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_lower_third",
                    {"Lower Third", "Add lower-third graphic clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/text-caption.svg",
                    true,
                    [this]() { emit requestAddLowerThird(); }});

  registerMenuItem("Clip/Add Clip",
                   {"clip.add_overlay",
                    {"Overlay", "Add overlay graphics clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layers-linked.svg",
                    true,
                    [this]() { emit requestAddOverlay(); }});

  registerSeparator("Clip");

  registerMenuItem("Clip",
                   {"clip.add_effect",
                    {"Add Effect...", "Add effect to selected clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/adjustments.svg",
                    true,
                    [this]() { emit requestAddEffect(); }});

  registerMenuItem(
      "Clip", {"clip.add_transition",
               {"Add Transition...", "Add transition to selected edit", ""},
               "",
               "",
               "qrc:/assets/icons/transition.svg",
               true,
               [this]() { emit requestAddTransition(); }});

  registerMenuItem("Clip", {"clip.add_keyframe",
                            {"Add Keyframe", "Add keyframe at playhead", ""},
                            "",
                            "",
                            "qrc:/assets/icons/keyframe.svg",
                            true,
                            [this]() { emit requestAddKeyframe(); }});

  registerSeparator("Clip/Trim");

  registerMenuItem("Clip/Trim", {"clip.split",
                                 {"Split Clip", "Split clip at playhead", ""},
                                 "Ctrl+K",
                                 "Ctrl+K",
                                 "qrc:/assets/icons/cut.svg",
                                 true,
                                 [this]() { emit requestSplitClip(); }});

  registerMenuItem("Clip/Trim", {"clip.split_sample",
                                 {"Split at Sample Level",
                                  "Split clip at precise sample boundary", ""},
                                 "S",
                                 "S",
                                 "qrc:/assets/icons/cut.svg",
                                 true,
                                 [this]() { emit requestSplitSample(); }});

  registerMenuItem("Clip/Trim", {"clip.slice",
                                 {"Slice Clip", "Slice clip using blade", ""},
                                 "",
                                 "",
                                 "qrc:/assets/icons/scissors.svg",
                                 true,
                                 [this]() { emit requestSliceClip(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.trim_start",
                    {"Trim Start", "Trim clip start to playhead", ""},
                    "Q",
                    "Q",
                    "qrc:/assets/icons/bracket-left.svg",
                    true,
                    [this]() { emit requestTrimStart(); }});

  registerMenuItem("Clip/Trim", {"clip.trim_end",
                                 {"Trim End", "Trim clip end to playhead", ""},
                                 "W",
                                 "W",
                                 "qrc:/assets/icons/bracket-right.svg",
                                 true,
                                 [this]() { emit requestTrimEnd(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.ripple_trim",
                    {"Ripple Trim", "Trim and ripple timeline", ""},
                    "",
                    "",
                    "qrc:/assets/icons/resize.svg",
                    true,
                    [this]() { emit requestRippleTrim(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.roll_trim",
                    {"Roll Trim", "Roll trim adjacent edit point", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-horizontal.svg",
                    true,
                    [this]() { emit requestRollTrim(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.slip_trim",
                    {"Slip Trim", "Slip clip content without moving clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-move-horizontal.svg",
                    true,
                    [this]() { emit requestSlipTrim(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.slide_trim",
                    {"Slide Trim", "Slide clip while preserving duration", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-move.svg",
                    true,
                    [this]() { emit requestSlideTrim(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.extend_to_playhead",
                    {"Extend to Playhead", "Extend clip edge to playhead", ""},
                    "E",
                    "E",
                    "qrc:/assets/icons/arrow-right.svg",
                    true,
                    [this]() { emit requestExtendToPlayhead(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.shrink_to_playhead",
                    {"Shrink to Playhead", "Shrink clip edge to playhead", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-left.svg",
                    true,
                    [this]() { emit requestShrinkToPlayhead(); }});

  registerMenuItem("Clip/Trim",
                   {"clip.snap_to_playhead",
                    {"Snap to Playhead", "Snap selected clip to playhead", ""},
                    "",
                    "",
                    "qrc:/assets/icons/magnet.svg",
                    true,
                    [this]() { emit requestSnapToPlayhead(); }});

  registerSeparator("Clip");

  registerMenuItem("Clip",
                   {"clip.transcode",
                    {"Transcode Clip...",
                     "Transcode selected clip to proxy or editing codec", ""},
                    "",
                    "",
                    "qrc:/assets/icons/refresh.svg",
                    true,
                    [this]() { emit requestTranscodeClip(); }});

  registerMenuItem(
      "Clip", {"clip.replace_clip",
               {"Replace Clip...", "Replace selected clip in timeline", ""},
               "",
               "",
               "qrc:/assets/icons/replace.svg",
               true,
               [this]() { emit requestReplaceClip(); }});

  registerMenuItem("Clip",
                   {"clip.replace_source",
                    {"Replace Source...", "Replace clip source media", ""},
                    "",
                    "",
                    "qrc:/assets/icons/link.svg",
                    true,
                    [this]() { emit requestReplaceSource(); }});

  registerMenuItem("Clip",
                   {"clip.reconnect_clip",
                    {"Reconnect Clip...", "Relink selected clip media", ""},
                    "",
                    "",
                    "qrc:/assets/icons/link.svg",
                    true,
                    [this]() { emit requestReconnectClip(); }});

  registerSeparator("Clip");

  registerMenuItem("Clip",
                   {"clip.open_in_asset_manager",
                    {"Open Clip in Asset Manager",
                     "Locate and highlight clip in project bin", ""},
                    "",
                    "",
                    "qrc:/assets/icons/folder-search.svg",
                    true,
                    [this]() { emit requestOpenClipInAssetManager(); }});

  registerMenuItem("Clip", {"clip.open_in_new_timeline",
                            {"Open Clip in New Timeline",
                             "Open selected clip as a nested timeline", ""},
                            "",
                            "",
                            "qrc:/assets/icons/timeline.svg",
                            true,
                            [this]() { emit requestOpenClipInNewTimeline(); }});

  registerMenuItem(
      "Clip", {"clip.open_in_source_monitor",
               {"Open in Source Monitor", "Open clip in source monitor", ""},
               "",
               "",
               "qrc:/assets/icons/player-play.svg",
               true,
               [this]() { emit requestOpenInSourceMonitor(); }});

  registerMenuItem("Clip", {"clip.replace_selected",
                            {"Replace Selected Clips",
                             "Replace contents of active clip selection", ""},
                            "",
                            "",
                            "qrc:/assets/icons/replace.svg",
                            true,
                            [this]() { emit requestReplaceSelectedClips(); }});

  registerMenuItem("Clip",
                   {"clip.ripple_replace",
                    {"Ripple Replace Clip Occurrences",
                     "Replace all clip occurrences maintaining timing", ""},
                    "",
                    "",
                    "qrc:/assets/icons/replace-all.svg",
                    true,
                    [this]() { emit requestRippleReplaceClipOccurrences(); }});

  registerSeparator("Clip/Select");

  registerMenuItem("Clip/Select",
                   {"clip.select_all_occurrences",
                    {"Select All Occurrences",
                     "Select all instances of this clip in sequence", ""},
                    "",
                    "",
                    "qrc:/assets/icons/select-all.svg",
                    true,
                    [this]() { emit requestSelectAllOccurrences(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_matching",
                    {"Select Matching", "Select matching clips", ""},
                    "",
                    "",
                    "qrc:/assets/icons/filter.svg",
                    true,
                    [this]() { emit requestSelectMatching(); }});

  registerMenuItem("Clip/Select",
                   {"clip.checker_deselect",
                    {"Checker Deselect",
                     "Deselect alternating clips along active selection", ""},
                    "",
                    "",
                    "qrc:/assets/icons/grid-dots.svg",
                    true,
                    [this]() { emit requestCheckerDeselect(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_first",
                    {"Select First", "Select the initial clip occurrence", ""},
                    "",
                    "",
                    "qrc:/assets/icons/player-skip-back.svg",
                    true,
                    [this]() { emit requestSelectFirst(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_last",
                    {"Select Last", "Select the terminal clip occurrence", ""},
                    "",
                    "",
                    "qrc:/assets/icons/player-skip-forward.svg",
                    true,
                    [this]() { emit requestSelectLast(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_first_and_last",
                    {"Select First and Last",
                     "Select boundaries of matching clip occurrences", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-left-right.svg",
                    true,
                    [this]() { emit requestSelectFirstAndLast(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_previous",
                    {"Select Previous", "Select previous clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/chevron-left.svg",
                    true,
                    [this]() { emit requestSelectPrevious(); }});

  registerMenuItem("Clip/Select", {"clip.select_next",
                                   {"Select Next", "Select next clip", ""},
                                   "",
                                   "",
                                   "qrc:/assets/icons/chevron-right.svg",
                                   true,
                                   [this]() { emit requestSelectNext(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_left_edge",
                    {"Select Left Edge", "Select left edge of clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bracket-left.svg",
                    true,
                    [this]() { emit requestSelectLeftEdge(); }});

  registerMenuItem("Clip/Select",
                   {"clip.select_right_edge",
                    {"Select Right Edge", "Select right edge of clip", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bracket-right.svg",
                    true,
                    [this]() { emit requestSelectRightEdge(); }});

  registerSeparator("Clip");

  registerMenuItem(
      "Clip", {"clip.properties",
               {"Clip Properties...", "View metadata and technical specs", ""},
               "Alt+Enter",
               "Alt+Enter",
               "qrc:/assets/icons/info-circle.svg",
               true,
               [this]() { emit requestClipProperties(); }});

  registerMenuItem("Clip",
                   {"clip.rename",
                    {"Rename Clip...", "Change display name of clip", ""},
                    "F2",
                    "F2",
                    "qrc:/assets/icons/edit.svg",
                    true,
                    [this]() { emit requestRenameClip(); }});

  registerMenuItem("Clip", {"clip.duplicate",
                            {"Duplicate Clip", "Duplicate selected clip", ""},
                            "",
                            "",
                            "qrc:/assets/icons/copy-plus.svg",
                            true,
                            [this]() { emit requestDuplicateClip(); }});

  registerMenuItem("Clip",
                   {"clip.delete",
                    {"Delete Clip", "Remove clip from current timeline", ""},
                    "Delete",
                    "Delete",
                    "qrc:/assets/icons/trash.svg",
                    true,
                    [this]() { emit requestDeleteClip(); }});

  registerSeparator("Clip");

  registerMenuItem("Clip/Time",
                   {"clip.reverse",
                    {"Reverse Clip", "Reverse clip playback direction", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-back-up.svg",
                    true,
                    [this]() { emit requestReverseClip(); }});

  registerMenuItem("Clip/Time",
                   {"clip.freeze_frame",
                    {"Freeze Frame", "Create freeze frame at playhead", ""},
                    "",
                    "",
                    "qrc:/assets/icons/snowflake.svg",
                    true,
                    [this]() { emit requestFreezeFrame(); }});

  registerMenuItem("Clip/Time",
                   {"clip.speed_duration",
                    {"Speed/Duration...", "Change clip speed and duration", ""},
                    "Ctrl+R",
                    "Ctrl+R",
                    "qrc:/assets/icons/gauge.svg",
                    true,
                    [this]() { emit requestSpeedDuration(); }});

  registerMenuItem("Clip/Time",
                   {"clip.time_remapping",
                    {"Time Remapping", "Enable time remapping controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/clock.svg",
                    true,
                    [this]() { emit requestTimeRemapping(); }});

  registerSeparator("Clip");

  registerMenuItem("Clip/Nesting",
                   {"clip.nest_sequence",
                    {"Nest Sequence", "Nest selected clips into sequence", ""},
                    "",
                    "",
                    "qrc:/assets/icons/folder-plus.svg",
                    true,
                    [this]() { emit requestNestSequence(); }});

  registerMenuItem("Clip/Nesting",
                   {"clip.unnest_sequence",
                    {"Unnest Sequence", "Expand nested sequence", ""},
                    "",
                    "",
                    "qrc:/assets/icons/folder-minus.svg",
                    true,
                    [this]() { emit requestUnnestSequence(); }});
}
} // namespace xyla
