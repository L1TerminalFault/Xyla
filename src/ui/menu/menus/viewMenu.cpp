#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
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
                    "qrc:/assets/icons/effect.svg",
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
                    "qrc:/assets/icons/info.svg",
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

  // registerMenuItem("View/Interface Scale",
  //                  {"view.interface_scale_up",
  //                   {"Increase Interface Scale", "Make UI elements larger", ""},
  //                   "Ctrl++",
  //                   "Ctrl++",
  //                   "qrc:/assets/icons/zoom-in.svg",
  //                   true,
  //                   [this]() { emit requestIncreaseInterfaceScale(); }});
  //
  // registerMenuItem(
  //     "View/Interface Scale",
  //     {"view.interface_scale_down",
  //      {"Decrease Interface Scale", "Make UI elements smaller", ""},
  //      "Ctrl+-",
  //      "Ctrl+-",
  //      "qrc:/assets/icons/zoom-out.svg",
  //      true,
  //      [this]() { emit requestDecreaseInterfaceScale(); }});
  //
  // registerMenuItem("View/Interface Scale",
  //                  {"view.interface_scale_reset",
  //                   {"Reset Interface Scale", "Reset UI scale to default", ""},
  //                   "",
  //                   "",
  //                   "qrc:/assets/icons/refresh.svg",
  //                   true,
  //                   [this]() { emit requestResetInterfaceScale(); }});

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

  // registerSeparator("View/Overlays");

  registerSubmenuMeta("View/Overlays", "qrc:/assets/icons/app.svg",
                      "Export timeline/project data to external formats", "",
                      true);

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
} // namespace xyla
