#include "xylaMenuManager.hpp"
#include <QCoreApplication>
#include <QDebug>
#include <QMap>

namespace xyla {

MenuManager::MenuManager(XylaActionManager *actionManager, QObject *parent)
    : QObject(parent), m_actionManager(actionManager) {

  Q_ASSERT(m_actionManager != nullptr);

  connect(m_actionManager, &XylaActionManager::shortcutChanged, this,
          &MenuManager::rebuildMenuTree);
  connect(m_actionManager, &XylaActionManager::actionStateChanged, this,
          &MenuManager::rebuildMenuTree);

  setupDefaultActions();
}

void MenuManager::setupDefaultActions() {
  setupFileActions();
  setupEditActions();
  setupViewActions();
  setupClipActions();
  setupTimelineActions();
  setupEffectsActions();
  setupTitleGraphicsActions();
  setupAudioActions();
  setupColorActions();
  setupReviewActions();
  setupToolsActions();
  setupWindowActions();
  setupHelpActions();
  emit menuTreeChanged();
}

void MenuManager::setupFileActions() {
  registerMenuItem("File", {"file.new",
                            {"New Project", "Create a new Xyla project",
                             "https://docs.xyla.dev/manual/new-project"},
                            "Ctrl+N",
                            "Ctrl+N",
                            "qrc:/assets/icons/folder-plus.svg",
                            true,
                            [this]() { emit requestNewProject(); }});

  registerMenuItem("File", {"file.open",
                            {"Open Project", "Open an existing Xyla project",
                             "https://docs.xyla.dev/manual/open-project"},
                            "Ctrl+O",
                            "Ctrl+O",
                            "qrc:/assets/icons/folder.svg",
                            true,
                            [this]() { emit requestOpenProject(); }});

  registerMenuItem("File",
                   {"file.open_recent",
                    {"Open Recent", "Open a recently accessed project", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestOpenRecent(); }});

  registerMenuItem("File", {"file.close_project",
                            {"Close Project", "Close the current project", ""},
                            "Ctrl+W",
                            "Ctrl+W",
                            "qrc:/assets/icons/folder-x.svg",
                            true,
                            [this]() { emit requestCloseProject(); }});

  registerSeparator("File");

  registerMenuItem("File", {"file.save",
                            {"Save Project", "Save current project changes",
                             "https://docs.xyla.dev/manual/saving"},
                            "Ctrl+S",
                            "Ctrl+S",
                            "qrc:/assets/icons/device-floppy.svg",
                            true,
                            [this]() { emit requestSaveProject(); }});

  registerMenuItem("File",
                   {"file.save_as",
                    {"Save As", "Save current project under a new name or path",
                     "https://docs.xyla.dev/manual/saving"},
                    "Ctrl+Shift+S",
                    "Ctrl+Shift+S",
                    "qrc:/assets/icons/device-floppy.svg",
                    true,
                    [this]() { emit requestSaveProjectAs(); }});

  registerMenuItem(
      "File",
      {"file.revert_to_saved",
       {"Revert to Saved", "Discard unsaved changes and reload from disk", ""},
       "",
       "",
       "qrc:/assets/icons/history.svg",
       true,
       [this]() { emit requestRevertToSaved(); }});

  registerSeparator("File");

  // Interchange / IO together
  registerMenuItem(
      "File", {"file.import",
               {"Import", "Import media, timelines, or project assets", ""},
               "Ctrl+I",
               "Ctrl+I",
               "qrc:/assets/icons/file-import.svg",
               true,
               [this]() { emit requestImport(); }});

  registerSubmenuMeta("File/Export", "qrc:/assets/icons/file-export.svg",
                      "Export timeline/project data to external formats", "",
                      true);

  // No "Export " prefix in visible labels
  registerMenuItem(
      "File/Export",
      {"file.timeline",
       {"Timeline", "Export active timeline as interchange data", ""},
       "",
       "",
       "",
       true,
       [this]() { emit requestExportTimeline(); }});

  registerMenuItem("File/Export", {"file.frame",
                                   {"Frame", "Export current frame image", ""},
                                   "",
                                   "",
                                   "",
                                   true,
                                   [this]() { emit requestExportFrame(); }});

  registerMenuItem("File/Export", {"file.audio",
                                   {"Audio", "Export audio mixdown/stems", ""},
                                   "",
                                   "",
                                   "",
                                   true,
                                   [this]() { emit requestExportAudio(); }});

  registerSeparator("File/Export");

  registerMenuItem("File/Export",
                   {"file.otio",
                    {"OTIO", "Export as OpenTimelineIO (.otio)", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() {
                      emit requestExportTimeline();
                    }}); // map to timeline export pipeline

  registerMenuItem("File/Export", {"file.fcpxml",
                                   {"FCPXML", "Export Final Cut Pro XML", ""},
                                   "",
                                   "",
                                   "",
                                   true,
                                   [this]() { emit requestExportXML(); }});

  registerMenuItem("File/Export",
                   {"file.aaf",
                    {"AAF", "Export Advanced Authoring Format", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestExportAAF(); }});

  registerMenuItem("File/Export", {"file.edl",
                                   {"EDL", "Export Edit Decision List", ""},
                                   "",
                                   "",
                                   "",
                                   true,
                                   [this]() { emit requestExportEDL(); }});
  registerSeparator("File/Export");

  registerMenuItem(
      "File/Export",
      {"file.export.omf",
       {"OMF",
        "Export Open Media Framework audio interchange for Pro Tools/DAW", ""},
       "",
       "",
       "",
       true,
       [this]() { emit requestExportOMF(); }});

  registerMenuItem(
      "File/Export",
      {"file.export.png_sequence",
       {"PNG Sequence", "Export active range as an 8/16-bit PNG image sequence",
        ""},
       "",
       "",
       "",
       true,
       [this]() { emit requestExportPNGSequence(); }});

  registerMenuItem(
      "File/Export",
      {"file.export.tiff_sequence",
       {"TIFF Sequence",
        "Export active range as an uncompressed TIFF image sequence", ""},
       "",
       "",
       "",
       true,
       [this]() { emit requestExportTIFFSequence(); }});

  registerMenuItem("File/Export",
                   {"file.export.exr_sequence",
                    {"OpenEXR Sequence",
                     "Export active range as a multi-channel OpenEXR sequence "
                     "for VFX/grading",
                     ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestExportEXRSequence(); }});

  registerMenuItem(
      "File/Export",
      {"file.export.markers_csv",
       {"Markers as CSV",
        "Export timeline markers, notes, and timecodes as CSV", ""},
       "",
       "",
       "",
       true,
       [this]() { emit requestExportMarkersCSV(); }});

  registerSeparator("File/Export");
  registerMenuItem("File/Export",
                   {"file.subtitles",
                    {"Subtitles", "Export subtitle tracks (e.g. SRT/VTT)", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestExportSubtitle(); }});

  // Render separate from interchange
  registerMenuItem(
      "File", {"file.render",
               {"Render", "Render timeline to deliverable media output", ""},
               "Ctrl+M",
               "Ctrl+M",
               "qrc:/assets/icons/player-play.svg",
               true,
               [this]() { emit requestExport(); }});

  registerSeparator("File");

  registerMenuItem("File/Project",
                   {"file.project_settings",
                    {"Project Settings", "Configure project settings", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestProjectSettings(); }});

  registerMenuItem("File/Project",
                   {"file.project_metadata",
                    {"Project Metadata", "Edit project metadata", ""},
                    "",
                    "",
                    "",
                    true,
                    [this]() { emit requestProjectMetadata(); }});

  registerSeparator("File");

  registerMenuItem("File", {"file.quit",
                            {"Quit", "Exit application", ""},
                            "Ctrl+Q",
                            "Ctrl+Q",
                            "qrc:/assets/icons/x.svg",
                            true,
                            []() { QCoreApplication::quit(); }});
}

void MenuManager::setupEditActions() {
  registerMenuItem("Edit", {"edit.undo",
                            {"Undo", "Revert last action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Z",
                            "Ctrl+Z",
                            "qrc:/assets/icons/arrow-left.svg",
                            true,
                            [this]() { emit requestUndo(); }});

  registerMenuItem("Edit", {"edit.redo",
                            {"Redo", "Re-apply last undone action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Y",
                            "Ctrl+Y",
                            "qrc:/assets/icons/arrow-right.svg",
                            true,
                            [this]() { emit requestRedo(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.cut",
                            {"Cut", "Cut selected items to clipboard", ""},
                            "Ctrl+X",
                            "Ctrl+X",
                            "qrc:/assets/icons/scissors.svg",
                            true,
                            [this]() { emit requestCut(); }});

  registerMenuItem("Edit", {"edit.copy",
                            {"Copy", "Copy selected items to clipboard", ""},
                            "Ctrl+C",
                            "Ctrl+C",
                            "qrc:/assets/icons/copy.svg",
                            true,
                            [this]() { emit requestCopy(); }});

  registerMenuItem("Edit", {"edit.paste",
                            {"Paste", "Paste items from clipboard", ""},
                            "Ctrl+V",
                            "Ctrl+V",
                            "qrc:/assets/icons/clipboard.svg",
                            true,
                            [this]() { emit requestPaste(); }});

  registerMenuItem("Edit",
                   {"edit.paste_insert",
                    {"Paste Insert", "Insert pasted item at playhead", ""},
                    "Ctrl+Shift+V",
                    "Ctrl+Shift+V",
                    "qrc:/assets/icons/clipboard-plus.svg",
                    true,
                    [this]() { emit requestPasteInsert(); }});

  registerMenuItem("Edit",
                   {"edit.paste_overwrite",
                    {"Paste Overwrite", "Overwrite with pasted item", ""},
                    "Ctrl+Alt+V",
                    "Ctrl+Alt+V",
                    "qrc:/assets/icons/clipboard-check.svg",
                    true,
                    [this]() { emit requestPasteOverwrite(); }});

  registerMenuItem("Edit", {"edit.duplicate",
                            {"Duplicate", "Duplicate selected item(s)", ""},
                            "Ctrl+D",
                            "Ctrl+D",
                            "qrc:/assets/icons/copy-plus.svg",
                            true,
                            [this]() { emit requestDuplicate(); }});

  registerMenuItem("Edit", {"edit.delete",
                            {"Delete", "Delete selected item(s)", ""},
                            "Delete",
                            "Delete",
                            "qrc:/assets/icons/trash.svg",
                            true,
                            [this]() { emit requestDelete(); }});

  registerMenuItem("Edit",
                   {"edit.ripple_delete",
                    {"Ripple Delete", "Delete and close resulting gap", ""},
                    "Shift+Delete",
                    "Shift+Delete",
                    "qrc:/assets/icons/trash-x.svg",
                    true,
                    [this]() { emit requestRippleDelete(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit/Select", {"edit.select_all",
                                   {"Select All", "Select all elements", ""},
                                   "Ctrl+A",
                                   "Ctrl+A",
                                   "qrc:/assets/icons/select-all.svg",
                                   true,
                                   [this]() { emit requestSelectAll(); }});

  registerMenuItem("Edit/Select",
                   {"edit.deselect_all",
                    {"Deselect All", "Clear active selection", ""},
                    "Ctrl+Shift+A",
                    "Ctrl+Shift+A",
                    "qrc:/assets/icons/select.svg",
                    true,
                    [this]() { emit requestDeselectAll(); }});

  registerMenuItem("Edit/Select",
                   {"edit.invert_selection",
                    {"Invert Selection", "Invert current selection", ""},
                    "",
                    "",
                    "qrc:/assets/icons/switch-horizontal.svg",
                    true,
                    [this]() { emit requestInvertSelection(); }});

  registerMenuItem("Edit/Select",
                   {"edit.select_timeline",
                    {"Select Timeline", "Select timeline panel/content", ""},
                    "",
                    "",
                    "qrc:/assets/icons/timeline.svg",
                    true,
                    [this]() { emit requestSelectTimeline(); }});

  registerMenuItem("Edit/Select",
                   {"edit.select_clips",
                    {"Select Clips", "Select all clips on active context", ""},
                    "",
                    "",
                    "qrc:/assets/icons/video.svg",
                    true,
                    [this]() { emit requestSelectClips(); }});

  registerMenuItem("Edit/Select",
                   {"edit.select_tracks",
                    {"Select Tracks", "Select timeline tracks", ""},
                    "",
                    "",
                    "qrc:/assets/icons/stack.svg",
                    true,
                    [this]() { emit requestSelectTracks(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.find",
                            {"Find...", "Find items in project/timeline", ""},
                            "Ctrl+F",
                            "Ctrl+F",
                            "qrc:/assets/icons/search.svg",
                            true,
                            [this]() { emit requestFind(); }});

  registerMenuItem("Edit",
                   {"edit.find_replace",
                    {"Find and Replace...", "Find and replace values/text", ""},
                    "Ctrl+H",
                    "Ctrl+H",
                    "qrc:/assets/icons/replace.svg",
                    true,
                    [this]() { emit requestFindAndReplace(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.shortcuts",
                            {"Keyboard Shortcuts...",
                             "Customize keyboard shortcuts and presets", ""},
                            "Ctrl+Alt+K",
                            "Ctrl+Alt+K",
                            "qrc:/assets/icons/keyboard.svg",
                            true,
                            [this]() { emit requestKeyboardShortcuts(); }});

  registerMenuItem("Edit",
                   {"edit.preferences",
                    {"Preferences...", "Open workspace preferences", ""},
                    "Ctrl+,",
                    "Ctrl+,",
                    "qrc:/assets/icons/settings.svg",
                    true,
                    [this]() { emit requestPreferences(); }});
}

void MenuManager::setupViewActions() {
  registerMenuItem(
      "View", {"view.fullscreen",
               {"Fullscreen Window", "Toggle fullscreen application view", ""},
               "F11",
               "F11",
               "qrc:/assets/icons/maximize.svg",
               true,
               [this]() { emit requestToggleFullscreen(); }});

  registerSeparator("View/Panels");

  registerMenuItem("View/Panels",
                   {"view.toggle_timeline",
                    {"Toggle Timeline", "Show/hide timeline panel", ""},
                    "",
                    "",
                    "qrc:/assets/icons/timeline.svg",
                    true,
                    [this]() { emit requestToggleTimelineVisibility(); }});

  registerMenuItem("View/Panels",
                   {"view.toggle_project",
                    {"Toggle Project Panel", "Show/hide project panel", ""},
                    "",
                    "",
                    "qrc:/assets/icons/folder.svg",
                    true,
                    [this]() { emit requestToggleProjectPanel(); }});

  registerMenuItem("View/Panels",
                   {"view.toggle_effects",
                    {"Toggle Effects Panel", "Show/hide effects panel", ""},
                    "",
                    "",
                    "qrc:/assets/icons/adjustments.svg",
                    true,
                    [this]() { emit requestToggleEffectsPanel(); }});

  registerMenuItem(
      "View/Panels",
      {"view.toggle_properties",
       {"Toggle Properties Panel", "Show/hide properties panel", ""},
       "",
       "",
       "qrc:/assets/icons/sliders.svg",
       true,
       [this]() { emit requestTogglePropertiesPanel(); }});

  registerMenuItem("View/Panels",
                   {"view.toggle_audio",
                    {"Toggle Audio Panel", "Show/hide audio tools", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music.svg",
                    true,
                    [this]() { emit requestToggleAudioPanel(); }});

  registerMenuItem("View/Panels",
                   {"view.toggle_color",
                    {"Toggle Color Panel", "Show/hide color tools", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestToggleColorPanel(); }});

  registerMenuItem("View/Panels",
                   {"view.toggle_metadata",
                    {"Toggle Metadata Panel", "Show/hide metadata panel", ""},
                    "",
                    "",
                    "qrc:/assets/icons/info-circle.svg",
                    true,
                    [this]() { emit requestToggleMetadataPanel(); }});

  registerSeparator("View");

  registerMenuItem("View/Zoom", {"view.zoom_in",
                                 {"Zoom In", "Zoom in timeline/view", ""},
                                 "Ctrl+=",
                                 "Ctrl+=",
                                 "qrc:/assets/icons/zoom-in.svg",
                                 true,
                                 [this]() { emit requestZoomIn(); }});

  registerMenuItem("View/Zoom", {"view.zoom_out",
                                 {"Zoom Out", "Zoom out timeline/view", ""},
                                 "Ctrl+-",
                                 "Ctrl+-",
                                 "qrc:/assets/icons/zoom-out.svg",
                                 true,
                                 [this]() { emit requestZoomOut(); }});

  registerMenuItem("View/Zoom",
                   {"view.zoom_fit",
                    {"Zoom to Fit", "Fit content in visible area", ""},
                    "Shift+Z",
                    "Shift+Z",
                    "qrc:/assets/icons/zoom-fit.svg",
                    true,
                    [this]() { emit requestZoomToFit(); }});

  registerMenuItem("View/Zoom",
                   {"view.zoom_selection",
                    {"Zoom to Selection", "Focus zoom on selection", ""},
                    "",
                    "",
                    "qrc:/assets/icons/focus.svg",
                    true,
                    [this]() { emit requestZoomToSelection(); }});

  registerMenuItem("View", {"view.reset_view",
                            {"Reset View", "Reset panel and zoom view", ""},
                            "",
                            "",
                            "qrc:/assets/icons/refresh.svg",
                            true,
                            [this]() { emit requestResetView(); }});

  registerSeparator("View");

  registerMenuItem("View", {"view.load_workspace",
                            {"Load Workspace Layout...",
                             "Load a saved workspace preset", ""},
                            "",
                            "",
                            "qrc:/assets/icons/layout-grid.svg",
                            true,
                            [this]() { emit requestLoadWorkspaceLayout(); }});

  registerMenuItem(
      "View", {"view.save_workspace",
               {"Save Workspace Layout...", "Save current panel layout", ""},
               "",
               "",
               "qrc:/assets/icons/layout-grid-add.svg",
               true,
               [this]() { emit requestSaveWorkspaceLayout(); }});

  registerMenuItem("View", {"view.manage_layouts",
                            {"Manage Layout Presets...",
                             "Organize and edit custom UI layouts", ""},
                            "",
                            "",
                            "qrc:/assets/icons/layout-board.svg",
                            true,
                            [this]() { emit requestManageLayoutPresets(); }});

  registerSeparator("View");

  registerMenuItem("View/Interface Scale",
                   {"view.interface_scale_up",
                    {"Increase Interface Scale", "Make UI elements larger", ""},
                    "Ctrl++",
                    "Ctrl++",
                    "qrc:/assets/icons/zoom-in.svg",
                    true,
                    [this]() { emit requestIncreaseInterfaceScale(); }});

  registerMenuItem(
      "View/Interface Scale",
      {"view.interface_scale_down",
       {"Decrease Interface Scale", "Make UI elements smaller", ""},
       "Ctrl+-",
       "Ctrl+-",
       "qrc:/assets/icons/zoom-out.svg",
       true,
       [this]() { emit requestDecreaseInterfaceScale(); }});

  registerMenuItem("View/Interface Scale",
                   {"view.interface_scale_reset",
                    {"Reset Interface Scale", "Reset UI scale to default", ""},
                    "",
                    "",
                    "qrc:/assets/icons/refresh.svg",
                    true,
                    [this]() { emit requestResetInterfaceScale(); }});

  registerMenuItem("View", {"view.theme_settings",
                            {"Theme Settings...",
                             "Customize editor colors and visual theme", ""},
                            "",
                            "",
                            "qrc:/assets/icons/palette.svg",
                            true,
                            [this]() { emit requestThemeSettings(); }});

  registerMenuItem("View",
                   {"view.goto_timecode",
                    {"Go to Timecode...", "Jump playhead to timecode", ""},
                    "Ctrl+G",
                    "Ctrl+G",
                    "qrc:/assets/icons/clock.svg",
                    true,
                    [this]() { emit requestGotoTimecode(); }});

  registerSeparator("View/Overlays");

  registerMenuItem("View/Overlays", {"view.show_grid",
                                     {"Show Grid", "Toggle grid overlay", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/grid-dots.svg",
                                     true,
                                     [this]() { emit requestShowGrid(); }});

  registerMenuItem("View/Overlays", {"view.show_rulers",
                                     {"Show Rulers", "Toggle rulers", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/ruler.svg",
                                     true,
                                     [this]() { emit requestShowRulers(); }});

  registerMenuItem("View/Overlays",
                   {"view.show_safe_areas",
                    {"Show Safe Areas", "Toggle title/action safe areas", ""},
                    "",
                    "",
                    "qrc:/assets/icons/box.svg",
                    true,
                    [this]() { emit requestShowSafeAreas(); }});

  registerMenuItem("View/Overlays",
                   {"view.show_markers",
                    {"Show Markers", "Toggle timeline markers visibility", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bookmark.svg",
                    true,
                    [this]() { emit requestShowMarkers(); }});

  registerMenuItem("View/Overlays",
                   {"view.show_waveforms",
                    {"Show Waveforms", "Toggle audio waveforms", ""},
                    "",
                    "",
                    "qrc:/assets/icons/wave-sine.svg",
                    true,
                    [this]() { emit requestShowWaveforms(); }});

  registerMenuItem("View/Overlays",
                   {"view.show_thumbnails",
                    {"Show Thumbnails", "Toggle clip thumbnails", ""},
                    "",
                    "",
                    "qrc:/assets/icons/photo.svg",
                    true,
                    [this]() { emit requestShowThumbnails(); }});

  registerMenuItem("View/Overlays",
                   {"view.show_keyframes",
                    {"Show Keyframes", "Toggle keyframe overlays", ""},
                    "",
                    "",
                    "qrc:/assets/icons/keyframe.svg",
                    true,
                    [this]() { emit requestShowKeyframes(); }});
}

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

void MenuManager::setupEffectsActions() {
  registerMenuItem("Effects/Color",
                   {"effects.color_correction",
                    {"Color Correction", "Apply primary color correction", ""},
                    "",
                    "",
                    "qrc:/assets/icons/color-filter.svg",
                    true,
                    [this]() { emit requestApplyColorCorrection(); }});

  registerMenuItem("Effects/Color", {"effects.lut",
                                     {"Apply LUT...", "Apply lookup table", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/palette.svg",
                                     true,
                                     [this]() { emit requestApplyLUT(); }});

  registerMenuItem("Effects/Color",
                   {"effects.hdr_tools",
                    {"HDR Tools", "Apply HDR processing tools", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestApplyHDRTools(); }});

  registerMenuItem("Effects/Color", {"effects.scopes",
                                     {"Scopes", "Open video scopes", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/chart-line.svg",
                                     true,
                                     [this]() { emit requestApplyScopes(); }});

  registerSeparator("Effects/Video");

  registerMenuItem("Effects/Video", {"effects.keyer",
                                     {"Keyer", "Apply keyer effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/eyedropper.svg",
                                     true,
                                     [this]() { emit requestApplyKeyer(); }});

  registerMenuItem("Effects/Video",
                   {"effects.spill_suppressor",
                    {"Spill Suppressor", "Suppress chroma spill", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet-off.svg",
                    true,
                    [this]() { emit requestApplySpillSuppressor(); }});

  registerMenuItem("Effects/Video", {"effects.tracker",
                                     {"Tracker", "Apply tracking effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/target.svg",
                                     true,
                                     [this]() { emit requestApplyTracker(); }});

  registerMenuItem("Effects/Video",
                   {"effects.stabilizer",
                    {"Stabilizer", "Apply stabilization", ""},
                    "",
                    "",
                    "qrc:/assets/icons/anchor.svg",
                    true,
                    [this]() { emit requestApplyStabilizer(); }});

  registerMenuItem("Effects/Video",
                   {"effects.transform",
                    {"Transform", "Apply transform controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transform.svg",
                    true,
                    [this]() { emit requestApplyTransform(); }});

  registerMenuItem("Effects/Video", {"effects.crop",
                                     {"Crop", "Apply crop effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/crop.svg",
                                     true,
                                     [this]() { emit requestApplyCrop(); }});

  registerMenuItem("Effects/Video", {"effects.blur",
                                     {"Blur", "Apply blur effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/blur.svg",
                                     true,
                                     [this]() { emit requestApplyBlur(); }});

  registerMenuItem("Effects/Video", {"effects.sharpen",
                                     {"Sharpen", "Apply sharpen effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/adjustments.svg",
                                     true,
                                     [this]() { emit requestApplySharpen(); }});

  registerMenuItem("Effects/Video", {"effects.glow",
                                     {"Glow", "Apply glow effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/sparkles.svg",
                                     true,
                                     [this]() { emit requestApplyGlow(); }});

  registerSeparator("Effects/Transitions");

  registerMenuItem("Effects/Transitions",
                   {"effects.fade",
                    {"Fade", "Apply fade transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transition.svg",
                    true,
                    [this]() { emit requestApplyFade(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.wipe",
                    {"Wipe", "Apply wipe transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rectangle.svg",
                    true,
                    [this]() { emit requestApplyWipe(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.slide",
                    {"Slide", "Apply slide transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-right-left.svg",
                    true,
                    [this]() { emit requestApplySlide(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.push",
                    {"Push", "Apply push transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-left-right.svg",
                    true,
                    [this]() { emit requestApplyPush(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.cross_dissolve",
                    {"Cross Dissolve", "Apply cross dissolve transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transition.svg",
                    true,
                    [this]() { emit requestApplyCrossDissolve(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.dip_to_black",
                    {"Dip to Black", "Apply dip-to-black transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/moon.svg",
                    true,
                    [this]() { emit requestApplyDipToBlack(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.dip_to_white",
                    {"Dip to White", "Apply dip-to-white transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestApplyDipToWhite(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.film_dissolve",
                    {"Film Dissolve", "Apply film dissolve transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/camera.svg",
                    true,
                    [this]() { emit requestApplyFilmDissolve(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.audio_transition",
                    {"Audio Transition", "Apply audio transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/wave-sine.svg",
                    true,
                    [this]() { emit requestApplyAudioTransition(); }});

  registerSeparator("Effects/Audio");

  registerMenuItem("Effects/Audio",
                   {"effects.audio_fade_in",
                    {"Audio Fade In", "Apply audio fade in", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume.svg",
                    true,
                    [this]() { emit requestApplyAudioFadeIn(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.audio_fade_out",
                    {"Audio Fade Out", "Apply audio fade out", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume-off.svg",
                    true,
                    [this]() { emit requestApplyAudioFadeOut(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.audio_crossfade",
                    {"Audio Crossfade", "Apply audio crossfade", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-left-right.svg",
                    true,
                    [this]() { emit requestApplyAudioCrossfade(); }});

  registerMenuItem(
      "Effects/Audio",
      {"effects.audio_ducking",
       {"Audio Ducking", "Automatically duck background audio", ""},
       "",
       "",
       "qrc:/assets/icons/wave-square.svg",
       true,
       [this]() { emit requestApplyAudioDucking(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.noise_reduction",
                    {"Noise Reduction", "Reduce background noise", ""},
                    "",
                    "",
                    "qrc:/assets/icons/noise.svg",
                    true,
                    [this]() { emit requestApplyNoiseReduction(); }});

  registerMenuItem("Effects/Audio", {"effects.eq",
                                     {"EQ", "Apply equalizer", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/sliders.svg",
                                     true,
                                     [this]() { emit requestApplyEQ(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.compressor",
                    {"Compressor", "Apply dynamic compression", ""},
                    "",
                    "",
                    "qrc:/assets/icons/compress.svg",
                    true,
                    [this]() { emit requestApplyCompressor(); }});

  registerMenuItem("Effects/Audio", {"effects.limiter",
                                     {"Limiter", "Apply limiter", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/gauge.svg",
                                     true,
                                     [this]() { emit requestApplyLimiter(); }});

  registerMenuItem("Effects/Audio", {"effects.reverb",
                                     {"Reverb", "Apply reverberation", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/wave-triangle.svg",
                                     true,
                                     [this]() { emit requestApplyReverb(); }});

  registerMenuItem("Effects/Audio", {"effects.delay",
                                     {"Delay", "Apply delay effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/history.svg",
                                     true,
                                     [this]() { emit requestApplyDelay(); }});

  registerMenuItem("Effects/Audio", {"effects.chorus",
                                     {"Chorus", "Apply chorus effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/waves.svg",
                                     true,
                                     [this]() { emit requestApplyChorus(); }});

  registerMenuItem("Effects/Audio", {"effects.flanger",
                                     {"Flanger", "Apply flanger effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/wave-sine.svg",
                                     true,
                                     [this]() { emit requestApplyFlanger(); }});

  registerMenuItem("Effects/Audio", {"effects.phaser",
                                     {"Phaser", "Apply phaser effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/rotate.svg",
                                     true,
                                     [this]() { emit requestApplyPhaser(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.distortion",
                    {"Distortion", "Apply distortion effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/alert-triangle.svg",
                    true,
                    [this]() { emit requestApplyDistortion(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.pitch_shift",
                    {"Pitch Shift", "Shift pitch of audio", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music-note.svg",
                    true,
                    [this]() { emit requestApplyPitchShift(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.time_stretch",
                    {"Time Stretch", "Stretch audio duration", ""},
                    "",
                    "",
                    "qrc:/assets/icons/resize.svg",
                    true,
                    [this]() { emit requestApplyTimeStretch(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.vocal_remover",
                    {"Vocal Remover", "Reduce centered vocals", ""},
                    "",
                    "",
                    "qrc:/assets/icons/microphone-off.svg",
                    true,
                    [this]() { emit requestApplyVocalRemover(); }});

  registerMenuItem("Effects/Audio", {"effects.panning",
                                     {"Panning", "Apply stereo panning", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/arrows-left-right.svg",
                                     true,
                                     [this]() { emit requestApplyPanning(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.stereo_width",
                    {"Stereo Width", "Adjust stereo image width", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rectangle-wide.svg",
                    true,
                    [this]() { emit requestApplyStereoWidth(); }});

  registerSeparator("Effects/Advanced");

  registerMenuItem(
      "Effects/Advanced",
      {"effects.keyframe_animation",
       {"Keyframe Animation", "Apply keyframe animation preset", ""},
       "",
       "",
       "qrc:/assets/icons/keyframe.svg",
       true,
       [this]() { emit requestApplyKeyframeAnimation(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.motion_blur",
                    {"Motion Blur", "Apply motion blur effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/blur.svg",
                    true,
                    [this]() { emit requestApplyMotionBlur(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.optical_flow",
                    {"Optical Flow", "Apply optical flow interpolation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/activity.svg",
                    true,
                    [this]() { emit requestApplyOpticalFlow(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.neural_enhance",
                    {"Neural Enhance", "Apply AI enhancement", ""},
                    "",
                    "",
                    "qrc:/assets/icons/brain.svg",
                    true,
                    [this]() { emit requestApplyNeuralEnhance(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.noise",
                    {"Noise", "Add procedural noise", ""},
                    "",
                    "",
                    "qrc:/assets/icons/noise.svg",
                    true,
                    [this]() { emit requestApplyNoise(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.grain",
                    {"Film Grain", "Add film grain texture", ""},
                    "",
                    "",
                    "qrc:/assets/icons/grain.svg",
                    true,
                    [this]() { emit requestApplyGrain(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.vignette",
                    {"Vignette", "Apply vignette shading", ""},
                    "",
                    "",
                    "qrc:/assets/icons/circle.svg",
                    true,
                    [this]() { emit requestApplyVignette(); }});

  registerMenuItem(
      "Effects/Advanced",
      {"effects.chromatic_aberration",
       {"Chromatic Aberration", "Apply lens chromatic aberration", ""},
       "",
       "",
       "qrc:/assets/icons/rainbow.svg",
       true,
       [this]() { emit requestApplyChromaticAberration(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.lens_distortion",
                    {"Lens Distortion", "Apply lens distortion effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lens.svg",
                    true,
                    [this]() { emit requestApplyLensDistortion(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.depth_of_field",
                    {"Depth of Field", "Simulate depth of field", ""},
                    "",
                    "",
                    "qrc:/assets/icons/focus.svg",
                    true,
                    [this]() { emit requestApplyDepthOfField(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.color_grading",
                    {"Color Grading", "Apply grading workflow preset", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestApplyColorGrading(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.look_table",
                    {"Look Table", "Apply look table style", ""},
                    "",
                    "",
                    "qrc:/assets/icons/table.svg",
                    true,
                    [this]() { emit requestApplyLookTable(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.custom_shader",
                    {"Custom Shader...", "Apply custom shader effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/code.svg",
                    true,
                    [this]() { emit requestApplyCustomShader(); }});
}

void MenuManager::setupTitleGraphicsActions() {
  registerMenuItem("Title & Graphics", {"title.new",
                                        {"New Title", "Create a new title", ""},
                                        "",
                                        "",
                                        "qrc:/assets/icons/typography.svg",
                                        true,
                                        [this]() { emit requestNewTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.edit",
                    {"Edit Title", "Edit selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/edit.svg",
                    true,
                    [this]() { emit requestEditTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.duplicate",
                    {"Duplicate Title", "Duplicate selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/copy-plus.svg",
                    true,
                    [this]() { emit requestDuplicateTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.delete",
                    {"Delete Title", "Delete selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/trash.svg",
                    true,
                    [this]() { emit requestDeleteTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.import_template",
                    {"Import Title Template...", "Import title template", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-import.svg",
                    true,
                    [this]() { emit requestImportTitleTemplate(); }});

  registerMenuItem("Title & Graphics",
                   {"title.export_template",
                    {"Export Title Template...", "Export title template", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-export.svg",
                    true,
                    [this]() { emit requestExportTitleTemplate(); }});

  registerSeparator("Title & Graphics/Layers");

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_text_layer",
                    {"Add Text Layer", "Add text layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/text-plus.svg",
                    true,
                    [this]() { emit requestAddTextLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_shape_layer",
                    {"Add Shape Layer", "Add shape layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/shape.svg",
                    true,
                    [this]() { emit requestAddShapeLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_image_layer",
                    {"Add Image Layer", "Add image layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/photo.svg",
                    true,
                    [this]() { emit requestAddImageLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_vector_layer",
                    {"Add Vector Layer", "Add vector layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/vector.svg",
                    true,
                    [this]() { emit requestAddVectorLayer(); }});

  registerSeparator("Title & Graphics/Arrange");

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.bring_to_front",
                    {"Bring to Front", "Bring selected layer to front", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layers-intersect.svg",
                    true,
                    [this]() { emit requestBringToFront(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.send_to_back",
                    {"Send to Back", "Send selected layer to back", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layers-subtract.svg",
                    true,
                    [this]() { emit requestSendToBack(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.bring_forward",
                    {"Bring Forward", "Move layer one step forward", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-up.svg",
                    true,
                    [this]() { emit requestBringForward(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.send_backward",
                    {"Send Backward", "Move layer one step backward", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-down.svg",
                    true,
                    [this]() { emit requestSendBackward(); }});

  registerSeparator("Title & Graphics/Align");

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_left",
                    {"Align Left", "Align layers to left edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-left.svg",
                    true,
                    [this]() { emit requestAlignLeft(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_right",
                    {"Align Right", "Align layers to right edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-right.svg",
                    true,
                    [this]() { emit requestAlignRight(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_center",
                    {"Align Center", "Align layers horizontally centered", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-center.svg",
                    true,
                    [this]() { emit requestAlignCenter(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_top",
                    {"Align Top", "Align layers to top edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-top.svg",
                    true,
                    [this]() { emit requestAlignTop(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_bottom",
                    {"Align Bottom", "Align layers to bottom edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-bottom.svg",
                    true,
                    [this]() { emit requestAlignBottom(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_middle",
                    {"Align Middle", "Align layers vertically centered", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-middle.svg",
                    true,
                    [this]() { emit requestAlignMiddle(); }});

  registerMenuItem(
      "Title & Graphics/Align",
      {"title.distribute_horizontal",
       {"Distribute Horizontal", "Distribute layers horizontally", ""},
       "",
       "",
       "qrc:/assets/icons/distribute-horizontal.svg",
       true,
       [this]() { emit requestDistributeHorizontal(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.distribute_vertical",
                    {"Distribute Vertical", "Distribute layers vertically", ""},
                    "",
                    "",
                    "qrc:/assets/icons/distribute-vertical.svg",
                    true,
                    [this]() { emit requestDistributeVertical(); }});

  registerSeparator("Title & Graphics/Match");

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_position",
                    {"Match Position", "Match layer position", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-move.svg",
                    true,
                    [this]() { emit requestMatchPosition(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_scale",
                    {"Match Scale", "Match layer scale", ""},
                    "",
                    "",
                    "qrc:/assets/icons/resize.svg",
                    true,
                    [this]() { emit requestMatchScale(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_rotation",
                    {"Match Rotation", "Match layer rotation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rotate.svg",
                    true,
                    [this]() { emit requestMatchRotation(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_opacity",
                    {"Match Opacity", "Match layer opacity", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet.svg",
                    true,
                    [this]() { emit requestMatchOpacity(); }});

  registerSeparator("Title & Graphics/Layer Ops");

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.group_layers",
                    {"Group Layers", "Group selected layers", ""},
                    "Ctrl+G",
                    "Ctrl+G",
                    "qrc:/assets/icons/folder-plus.svg",
                    true,
                    [this]() { emit requestGroupLayers(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.ungroup_layers",
                    {"Ungroup Layers", "Ungroup selected layers", ""},
                    "Ctrl+Shift+G",
                    "Ctrl+Shift+G",
                    "qrc:/assets/icons/folder-minus.svg",
                    true,
                    [this]() { emit requestUngroupLayers(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.lock_layer",
                    {"Lock Layer", "Lock selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock.svg",
                    true,
                    [this]() { emit requestLockLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.unlock_layer",
                    {"Unlock Layer", "Unlock selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock-open.svg",
                    true,
                    [this]() { emit requestUnlockLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.hide_layer",
                    {"Hide Layer", "Hide selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/eye-off.svg",
                    true,
                    [this]() { emit requestHideLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.show_layer",
                    {"Show Layer", "Show selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/eye.svg",
                    true,
                    [this]() { emit requestShowLayer(); }});
}

void MenuManager::setupAudioActions() {
  registerMenuItem("Audio", {"audio.gain",
                             {"Audio Gain...", "Adjust clip gain", ""},
                             "G",
                             "G",
                             "qrc:/assets/icons/volume.svg",
                             true,
                             [this]() { emit requestAudioGain(); }});

  registerMenuItem("Audio",
                   {"audio.normalize",
                    {"Normalize Audio", "Normalize selected audio levels", ""},
                    "",
                    "",
                    "qrc:/assets/icons/wave-sine.svg",
                    true,
                    [this]() { emit requestAudioNormalize(); }});

  registerMenuItem("Audio", {"audio.levels",
                             {"Audio Levels...", "Adjust audio levels", ""},
                             "",
                             "",
                             "qrc:/assets/icons/sliders.svg",
                             true,
                             [this]() { emit requestAudioLevels(); }});

  registerMenuItem("Audio", {"audio.pan",
                             {"Audio Pan", "Adjust stereo pan", ""},
                             "",
                             "",
                             "qrc:/assets/icons/arrows-left-right.svg",
                             true,
                             [this]() { emit requestAudioPan(); }});

  registerMenuItem("Audio", {"audio.balance",
                             {"Audio Balance", "Adjust channel balance", ""},
                             "",
                             "",
                             "qrc:/assets/icons/balance.svg",
                             true,
                             [this]() { emit requestAudioBalance(); }});

  registerMenuItem("Audio",
                   {"audio.track_color",
                    {"Audio Track Color...", "Set audio track color", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestAudioTrackColor(); }});

  registerMenuItem("Audio", {"audio.render",
                             {"Render Audio", "Render audio previews", ""},
                             "",
                             "",
                             "qrc:/assets/icons/player-play.svg",
                             true,
                             [this]() { emit requestAudioRender(); }});

  registerMenuItem("Audio",
                   {"audio.replace",
                    {"Replace Audio...", "Replace selected audio source", ""},
                    "",
                    "",
                    "qrc:/assets/icons/replace.svg",
                    true,
                    [this]() { emit requestAudioReplace(); }});

  registerMenuItem("Audio", {"audio.sync",
                             {"Sync Audio", "Synchronize audio with video", ""},
                             "",
                             "",
                             "qrc:/assets/icons/clock.svg",
                             true,
                             [this]() { emit requestAudioSync(); }});

  registerMenuItem(
      "Audio", {"audio.scene_detection",
                {"Audio Scene Detection", "Detect scene changes via audio", ""},
                "",
                "",
                "qrc:/assets/icons/activity.svg",
                true,
                [this]() { emit requestAudioSceneDetection(); }});
}

void MenuManager::setupColorActions() {
  registerMenuItem(
      "Color",
      {"color.primary",
       {"Primary Correction", "Adjust primary correction controls", ""},
       "",
       "",
       "qrc:/assets/icons/color-filter.svg",
       true,
       [this]() { emit requestColorPrimaryCorrection(); }});

  registerMenuItem(
      "Color", {"color.secondary",
                {"Secondary Correction", "Adjust secondary corrections", ""},
                "",
                "",
                "qrc:/assets/icons/color-swatch.svg",
                true,
                [this]() { emit requestColorSecondaryCorrection(); }});

  registerMenuItem("Color", {"color.wheels",
                             {"Color Wheels", "Open color wheels", ""},
                             "",
                             "",
                             "qrc:/assets/icons/palette.svg",
                             true,
                             [this]() { emit requestColorWheels(); }});

  registerMenuItem("Color", {"color.curves",
                             {"Color Curves", "Open curve controls", ""},
                             "",
                             "",
                             "qrc:/assets/icons/chart-line.svg",
                             true,
                             [this]() { emit requestColorCurves(); }});

  registerMenuItem("Color",
                   {"color.lut",
                    {"Color LUT...", "Apply LUT in color workspace", ""},
                    "",
                    "",
                    "qrc:/assets/icons/table.svg",
                    true,
                    [this]() { emit requestColorLUT(); }});

  registerMenuItem("Color", {"color.keyer",
                             {"Color Keyer", "Open color keyer tools", ""},
                             "",
                             "",
                             "qrc:/assets/icons/eyedropper.svg",
                             true,
                             [this]() { emit requestColorKeyer(); }});

  registerMenuItem("Color", {"color.qualifier",
                             {"Color Qualifier", "Open color qualifier", ""},
                             "",
                             "",
                             "qrc:/assets/icons/filter.svg",
                             true,
                             [this]() { emit requestColorQualifier(); }});

  registerMenuItem("Color", {"color.window",
                             {"Color Window", "Add color window mask", ""},
                             "",
                             "",
                             "qrc:/assets/icons/square.svg",
                             true,
                             [this]() { emit requestColorWindow(); }});

  registerMenuItem("Color", {"color.power_window",
                             {"Power Window", "Edit power window controls", ""},
                             "",
                             "",
                             "qrc:/assets/icons/octagon.svg",
                             true,
                             [this]() { emit requestColorPowerWindow(); }});

  registerMenuItem("Color",
                   {"color.tracker",
                    {"Color Tracker", "Track color window/qualifier", ""},
                    "",
                    "",
                    "qrc:/assets/icons/target.svg",
                    true,
                    [this]() { emit requestColorTracker(); }});

  registerMenuItem("Color",
                   {"color.stabilizer",
                    {"Color Stabilizer", "Stabilize image for grading", ""},
                    "",
                    "",
                    "qrc:/assets/icons/anchor.svg",
                    true,
                    [this]() { emit requestColorStabilizer(); }});

  registerMenuItem("Color",
                   {"color.render",
                    {"Render Color Cache", "Render color previews/cache", ""},
                    "",
                    "",
                    "qrc:/assets/icons/player-play.svg",
                    true,
                    [this]() { emit requestColorRender(); }});

  registerMenuItem("Color",
                   {"color.snapshot",
                    {"Take Color Snapshot", "Capture grading snapshot", ""},
                    "",
                    "",
                    "qrc:/assets/icons/camera.svg",
                    true,
                    [this]() { emit requestColorSnapshot(); }});

  registerMenuItem("Color", {"color.match",
                             {"Color Match", "Match grade between shots", ""},
                             "",
                             "",
                             "qrc:/assets/icons/arrows-left-right.svg",
                             true,
                             [this]() { emit requestColorMatch(); }});

  registerSeparator("Color/Adjustments");

  registerMenuItem("Color/Adjustments",
                   {"color.balance",
                    {"Color Balance", "Adjust color balance", ""},
                    "",
                    "",
                    "qrc:/assets/icons/balance.svg",
                    true,
                    [this]() { emit requestColorBalance(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.temperature",
                    {"Temperature", "Adjust white balance temperature", ""},
                    "",
                    "",
                    "qrc:/assets/icons/thermometer.svg",
                    true,
                    [this]() { emit requestColorTemperature(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.tint",
                    {"Tint", "Adjust green-magenta tint", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet.svg",
                    true,
                    [this]() { emit requestColorTint(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.saturation",
                    {"Saturation", "Adjust color saturation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestColorSaturation(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.contrast",
                    {"Contrast", "Adjust image contrast", ""},
                    "",
                    "",
                    "qrc:/assets/icons/contrast.svg",
                    true,
                    [this]() { emit requestColorContrast(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.shadows",
                    {"Shadows", "Adjust shadow tones", ""},
                    "",
                    "",
                    "qrc:/assets/icons/moon.svg",
                    true,
                    [this]() { emit requestColorShadows(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.midtones",
                    {"Midtones", "Adjust midtone range", ""},
                    "",
                    "",
                    "qrc:/assets/icons/circle-half.svg",
                    true,
                    [this]() { emit requestColorMidtones(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.highlights",
                    {"Highlights", "Adjust highlight range", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestColorHighlights(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.log",
                    {"Log Controls", "Adjust log wheels/controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/chart-dots.svg",
                    true,
                    [this]() { emit requestColorLog(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.hdr",
                    {"HDR Controls", "Adjust HDR grading controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sparkles.svg",
                    true,
                    [this]() { emit requestColorHDR(); }});
}

void MenuManager::setupReviewActions() {
  registerMenuItem("Review", {"review.add_marker",
                              {"Add Marker", "Add timeline marker", ""},
                              "M",
                              "M",
                              "qrc:/assets/icons/bookmark.svg",
                              true,
                              [this]() { emit requestAddMarker(); }});

  registerMenuItem("Review", {"review.delete_marker",
                              {"Delete Marker", "Delete selected marker", ""},
                              "",
                              "",
                              "qrc:/assets/icons/bookmark-off.svg",
                              true,
                              [this]() { emit requestDeleteMarker(); }});

  registerMenuItem("Review", {"review.goto_marker",
                              {"Go to Marker", "Jump to marker", ""},
                              "",
                              "",
                              "qrc:/assets/icons/map-pin.svg",
                              true,
                              [this]() { emit requestGotoMarker(); }});

  registerSeparator("Review");

  registerMenuItem("Review", {"review.add_comment",
                              {"Add Comment", "Add review comment", ""},
                              "",
                              "",
                              "qrc:/assets/icons/message.svg",
                              true,
                              [this]() { emit requestAddComment(); }});

  registerMenuItem("Review", {"review.add_note",
                              {"Add Note", "Add note annotation", ""},
                              "",
                              "",
                              "qrc:/assets/icons/note.svg",
                              true,
                              [this]() { emit requestAddNote(); }});

  registerMenuItem("Review", {"review.add_todo",
                              {"Add To-Do", "Add task marker/to-do", ""},
                              "",
                              "",
                              "qrc:/assets/icons/checklist.svg",
                              true,
                              [this]() { emit requestAddToDo(); }});

  registerMenuItem("Review", {"review.submit_feedback",
                              {"Submit Feedback", "Submit review feedback", ""},
                              "",
                              "",
                              "qrc:/assets/icons/send.svg",
                              true,
                              [this]() { emit requestSubmitFeedback(); }});

  registerMenuItem("Review",
                   {"review.export_feedback",
                    {"Export Feedback...", "Export review/feedback report", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-export.svg",
                    true,
                    [this]() { emit requestExportFeedback(); }});

  registerSeparator("Review");

  registerMenuItem("Review", {"review.mode",
                              {"Review Mode", "Toggle review mode", ""},
                              "",
                              "",
                              "qrc:/assets/icons/eye.svg",
                              true,
                              [this]() { emit requestReviewMode(); }});

  registerMenuItem("Review",
                   {"review.comparison_view",
                    {"Comparison View", "Open before/after comparison", ""},
                    "",
                    "",
                    "qrc:/assets/icons/columns.svg",
                    true,
                    [this]() { emit requestComparisonView(); }});

  registerMenuItem("Review",
                   {"review.split_view",
                    {"Split View", "Split viewer for side-by-side", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layout-split.svg",
                    true,
                    [this]() { emit requestSplitView(); }});
}

void MenuManager::setupToolsActions() {
  registerMenuItem("Tools", {"tools.selection",
                             {"Selection Tool", "Activate selection tool", ""},
                             "V",
                             "V",
                             "qrc:/assets/icons/cursor.svg",
                             true,
                             [this]() { emit requestSelectionTool(); }});

  registerMenuItem("Tools", {"tools.razor",
                             {"Razor Tool", "Activate blade/razor tool", ""},
                             "C",
                             "C",
                             "qrc:/assets/icons/cut.svg",
                             true,
                             [this]() { emit requestRazorTool(); }});

  registerMenuItem("Tools", {"tools.roll",
                             {"Roll Tool", "Activate roll trim tool", ""},
                             "N",
                             "N",
                             "qrc:/assets/icons/arrows-horizontal.svg",
                             true,
                             [this]() { emit requestRollTool(); }});

  registerMenuItem("Tools", {"tools.ripple",
                             {"Ripple Tool", "Activate ripple trim tool", ""},
                             "B",
                             "B",
                             "qrc:/assets/icons/resize.svg",
                             true,
                             [this]() { emit requestRippleTool(); }});

  registerMenuItem("Tools", {"tools.slip",
                             {"Slip Tool", "Activate slip tool", ""},
                             "Y",
                             "Y",
                             "qrc:/assets/icons/arrows-move-horizontal.svg",
                             true,
                             [this]() { emit requestSlipTool(); }});

  registerMenuItem("Tools", {"tools.slide",
                             {"Slide Tool", "Activate slide tool", ""},
                             "U",
                             "U",
                             "qrc:/assets/icons/arrows-move.svg",
                             true,
                             [this]() { emit requestSlideTool(); }});

  registerMenuItem("Tools", {"tools.pen",
                             {"Pen Tool", "Activate pen drawing tool", ""},
                             "P",
                             "P",
                             "qrc:/assets/icons/pen.svg",
                             true,
                             [this]() { emit requestPenTool(); }});

  registerMenuItem("Tools", {"tools.hand",
                             {"Hand Tool", "Activate panning hand tool", ""},
                             "H",
                             "H",
                             "qrc:/assets/icons/hand-stop.svg",
                             true,
                             [this]() { emit requestHandTool(); }});

  registerMenuItem("Tools", {"tools.zoom",
                             {"Zoom Tool", "Activate zoom tool", ""},
                             "Z",
                             "Z",
                             "qrc:/assets/icons/zoom-in.svg",
                             true,
                             [this]() { emit requestZoomTool(); }});

  registerMenuItem("Tools", {"tools.crop",
                             {"Crop Tool", "Activate crop tool", ""},
                             "",
                             "",
                             "qrc:/assets/icons/crop.svg",
                             true,
                             [this]() { emit requestCropTool(); }});

  registerMenuItem("Tools", {"tools.mask",
                             {"Mask Tool", "Activate mask tool", ""},
                             "",
                             "",
                             "qrc:/assets/icons/mask.svg",
                             true,
                             [this]() { emit requestMaskTool(); }});

  registerMenuItem("Tools", {"tools.text",
                             {"Text Tool", "Activate text tool", ""},
                             "T",
                             "T",
                             "qrc:/assets/icons/text-size.svg",
                             true,
                             [this]() { emit requestTextTool(); }});
}

void MenuManager::setupWindowActions() {
  registerMenuItem("Window",
                   {"window.new",
                    {"New Window", "Open a new application window", ""},
                    "Ctrl+Shift+N",
                    "Ctrl+Shift+N",
                    "qrc:/assets/icons/window.svg",
                    true,
                    [this]() { emit requestNewWindow(); }});

  registerMenuItem("Window",
                   {"window.close",
                    {"Close Window", "Close current application window", ""},
                    "Ctrl+Shift+W",
                    "Ctrl+Shift+W",
                    "qrc:/assets/icons/x.svg",
                    true,
                    [this]() { emit requestCloseWindow(); }});

  registerMenuItem("Window", {"window.toggle_dock",
                              {"Toggle Dock", "Show/hide dock areas", ""},
                              "",
                              "",
                              "qrc:/assets/icons/layout-sidebar.svg",
                              true,
                              [this]() { emit requestToggleDock(); }});

  registerMenuItem("Window",
                   {"window.reset_layout",
                    {"Reset Window Layout", "Reset dock/window layout", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layout-grid.svg",
                    true,
                    [this]() { emit requestResetWindowLayout(); }});

  registerMenuItem("Window", {"window.fullscreen",
                              {"Fullscreen Window",
                               "Toggle fullscreen for active window", ""},
                              "F11",
                              "F11",
                              "qrc:/assets/icons/maximize.svg",
                              true,
                              [this]() { emit requestFullScreenWindow(); }});

  registerMenuItem("Window",
                   {"window.minimize",
                    {"Minimize Window", "Minimize application window", ""},
                    "",
                    "",
                    "qrc:/assets/icons/minus.svg",
                    true,
                    [this]() { emit requestMinimizeWindow(); }});

  registerMenuItem("Window",
                   {"window.maximize",
                    {"Maximize Window", "Maximize application window", ""},
                    "",
                    "",
                    "qrc:/assets/icons/maximize.svg",
                    true,
                    [this]() { emit requestMaximizeWindow(); }});
}

void MenuManager::setupHelpActions() {
  registerMenuItem("Help", {"help.documentation",
                            {"Documentation", "Open Xyla documentation",
                             "https://docs.xyla.dev"},
                            "F1",
                            "F1",
                            "qrc:/assets/icons/book.svg",
                            true,
                            [this]() { emit requestDocumentation(); }});

  registerMenuItem("Help", {"help.tutorials",
                            {"Tutorials", "Open getting started tutorials", ""},
                            "",
                            "",
                            "qrc:/assets/icons/video.svg",
                            true,
                            [this]() { emit requestTutorials(); }});

  registerMenuItem("Help",
                   {"help.shortcuts",
                    {"Keyboard Shortcuts Help", "View shortcut reference", ""},
                    "",
                    "",
                    "qrc:/assets/icons/keyboard.svg",
                    true,
                    [this]() { emit requestKeyboardShortcutsHelp(); }});

  registerMenuItem(
      "Help", {"help.community",
               {"Community Forums", "Open community discussion forums", ""},
               "",
               "",
               "qrc:/assets/icons/users.svg",
               true,
               [this]() { emit requestCommunityForums(); }});

  registerSeparator("Help");

  registerMenuItem("Help",
                   {"help.report_issue",
                    {"Report Issue", "Report a bug or unexpected behavior", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bug.svg",
                    true,
                    [this]() { emit requestReportIssue(); }});

  registerMenuItem("Help", {"help.feature_request",
                            {"Feature Request", "Suggest a new feature", ""},
                            "",
                            "",
                            "qrc:/assets/icons/bulb.svg",
                            true,
                            [this]() { emit requestFeatureRequest(); }});

  registerMenuItem("Help", {"help.check_updates",
                            {"Check for Updates",
                             "Check for latest application updates", ""},
                            "",
                            "",
                            "qrc:/assets/icons/refresh.svg",
                            true,
                            [this]() { emit requestCheckForUpdates(); }});

  registerSeparator("Help");

  registerMenuItem("Help",
                   {"help.about",
                    {"About Xyla", "Show app and version information", ""},
                    "",
                    "",
                    "qrc:/assets/icons/info-circle.svg",
                    true,
                    [this]() { emit requestAbout(); }});

  registerMenuItem("Help",
                   {"help.system_info",
                    {"System Info", "Show runtime/system diagnostics", ""},
                    "",
                    "",
                    "qrc:/assets/icons/cpu.svg",
                    true,
                    [this]() { emit requestSystemInfo(); }});
}

void MenuManager::registerMenuItem(const QString &menuPath,
                                   const XylaActionData &action) {
  m_actionManager->registerAction(action);
  m_menuStructure.push_back({menuPath, action.id, false});
  rebuildMenuTree();
}

void MenuManager::registerSeparator(const QString &menuPath) {
  static int separatorCounter = 0;
  QString sepId = QString("sep_%1").arg(++separatorCounter);

  m_menuStructure.push_back({menuPath, sepId, true});
  rebuildMenuTree();
}

void MenuManager::triggerAction(const QString &actionId) {
  if (m_actionManager) {
    m_actionManager->triggerAction(actionId);
  }
}

void MenuManager::updateMenuTreeState() { rebuildMenuTree(); }

void MenuManager::rebuildMenuTree() {
  struct MenuEntry {
    bool isSubmenu{false};
    QString key;
    QVariantMap item;
  };

  struct MenuNode {
    QString title;
    QString fullPath;
    QMap<QString, MenuNode> submenus;
    QList<MenuEntry> entries;
  };

  QMap<QString, MenuNode> rootMenus;
  QList<QString> rootOrder;

  auto ensureSubmenuEntry = [](MenuNode &node, const QString &token) {
    for (const auto &e : node.entries) {
      if (e.isSubmenu && e.key == token)
        return;
    }
    MenuEntry entry;
    entry.isSubmenu = true;
    entry.key = token;
    node.entries.append(entry);
  };

  auto firstLeafMeta = [](const MenuNode &node) -> QVariantMap {
    for (const auto &entry : node.entries) {
      if (entry.isSubmenu)
        continue;
      const QVariantMap item = entry.item;
      if (item.value("isSeparator").toBool())
        continue;

      QVariantMap meta;
      meta["icon"] = item.value("icon").toString();
      meta["description"] = item.value("description").toString();
      meta["shortcut"] = "";
      meta["enabled"] =
          item.contains("enabled") ? item.value("enabled").toBool() : true;
      return meta;
    }
    return {};
  };

  for (const auto &item : m_menuStructure) {
    QStringList pathTokens = item.menuPath.split('/', Qt::SkipEmptyParts);
    if (pathTokens.isEmpty())
      continue;

    const QString rootName = pathTokens.first();
    if (!rootMenus.contains(rootName)) {
      MenuNode rootNode;
      rootNode.title = rootName;
      rootNode.fullPath = rootName;
      rootMenus.insert(rootName, rootNode);
      rootOrder.append(rootName);
    }

    MenuNode *currentNode = &rootMenus[rootName];
    QString currentPath = rootName;

    for (int i = 1; i < pathTokens.size(); ++i) {
      const QString token = pathTokens[i];
      currentPath += "/" + token;

      if (!currentNode->submenus.contains(token)) {
        MenuNode subNode;
        subNode.title = token;
        subNode.fullPath = currentPath;
        currentNode->submenus.insert(token, subNode);
      }

      ensureSubmenuEntry(*currentNode, token);
      currentNode = &currentNode->submenus[token];
    }

    QVariantMap itemMap;
    itemMap["isSeparator"] = item.isSeparator;
    itemMap["isSubmenu"] = false;

    if (item.isSeparator) {
      itemMap["id"] = item.actionId;
    } else {
      const QVariantMap actionMap = m_actionManager->getAction(item.actionId);
      const QVariantMap tooltip = actionMap.value("tooltip").toMap();

      itemMap["id"] = item.actionId;
      itemMap["title"] = tooltip.value("title").toString();
      itemMap["description"] = tooltip.value("description").toString();
      itemMap["docsUrl"] = tooltip.value("docsUrl").toString();
      itemMap["shortcut"] = actionMap.value("currentShortcut").toString();
      itemMap["icon"] = actionMap.value("icon").toString();
      itemMap["enabled"] = actionMap.value("enabled").toBool();
    }

    MenuEntry actionEntry;
    actionEntry.isSubmenu = false;
    actionEntry.item = itemMap;
    currentNode->entries.append(actionEntry);
  }

  std::function<QVariantMap(const MenuNode &)> serializeNode =
      [&](const MenuNode &node) -> QVariantMap {
    QVariantMap result;
    result["title"] = node.title;

    QVariantList itemsList;
    for (const auto &entry : node.entries) {
      if (!entry.isSubmenu) {
        itemsList.append(entry.item);
        continue;
      }

      const QString &subName = entry.key;
      if (!node.submenus.contains(subName))
        continue;

      const MenuNode &childNode = node.submenus[subName];

      QVariantMap submenuItem;
      submenuItem["isSubmenu"] = true;
      submenuItem["isSeparator"] = false;
      submenuItem["id"] = QString("submenu_%1").arg(subName);
      submenuItem["title"] = subName;

      QVariantMap meta = m_submenuMeta.value(childNode.fullPath);
      if (meta.isEmpty())
        meta = firstLeafMeta(childNode);

      submenuItem["icon"] = meta.value("icon").toString();
      submenuItem["description"] = meta.value("description").toString();
      submenuItem["shortcut"] = meta.value("shortcut").toString();
      submenuItem["enabled"] =
          meta.contains("enabled") ? meta.value("enabled").toBool() : true;

      const QVariantMap childData = serializeNode(childNode);
      submenuItem["items"] = childData.value("items");

      itemsList.append(submenuItem);
    }

    result["items"] = itemsList;
    return result;
  };

  QVariantList tree;
  for (const QString &rootName : rootOrder)
    tree.append(serializeNode(rootMenus[rootName]));

  m_cachedMenuTree = tree;
  emit menuTreeChanged();
}

void MenuManager::registerSubmenuMeta(const QString &menuPath,
                                      const QString &icon,
                                      const QString &description,
                                      const QString &shortcut, bool enabled) {
  QVariantMap meta;
  meta["icon"] = icon;
  meta["description"] = description;
  meta["shortcut"] = shortcut;
  meta["enabled"] = enabled;
  m_submenuMeta[menuPath] = meta;
}

} // namespace xyla
