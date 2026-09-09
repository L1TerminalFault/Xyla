#include "ui/menu/xylaMenuManager.hpp"
#include <QCoreApplication>

namespace xyla {
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
                            "qrc:/assets/icons/folder-open.svg",
                            true,
                            [this]() { emit requestOpenProject(); }});

  registerMenuItem("File",
                   {"file.open_recent",
                    {"Open Recent", "Open a recently accessed project", ""},
                    "",
                    "",
                            "qrc:/assets/icons/folder-open-recent.svg",
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
                            "qrc:/assets/icons/drive.svg",
                            true,
                            [this]() { emit requestSaveProject(); }});

  registerMenuItem("File",
                   {"file.save_as",
                    {"Save As", "Save current project under a new name or path",
                     "https://docs.xyla.dev/manual/saving"},
                    "Ctrl+Shift+S",
                    "Ctrl+Shift+S",
                    "qrc:/assets/icons/drive-cog.svg",
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
               "qrc:/assets/icons/timeline.svg",
       true,
       [this]() { emit requestExportTimeline(); }});

  registerMenuItem("File/Export", {"file.frame",
                                   {"Frame", "Export current frame image", ""},
                                   "",
                                   "",
               "qrc:/assets/icons/frame.svg",
                                   true,
                                   [this]() { emit requestExportFrame(); }});

  registerMenuItem("File/Export", {"file.audio",
                                   {"Audio", "Export audio mixdown/stems", ""},
                                   "",
                                   "",
               "qrc:/assets/icons/audio.svg",
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
               "qrc:/assets/icons/png.svg",
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
               "qrc:/assets/icons/csv.svg",
       true,
       [this]() { emit requestExportMarkersCSV(); }});

  registerSeparator("File/Export");
  registerMenuItem("File/Export",
                   {"file.subtitles",
                    {"Subtitles", "Export subtitle tracks (e.g. SRT/VTT)", ""},
                    "",
                    "",
               "qrc:/assets/icons/subtitles.svg",
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

  registerSubmenuMeta("File/Project", "qrc:/assets/icons/app.svg",
                      "Export timeline/project data to external formats", "",
                      true);

  registerMenuItem("File/Project",
                   {"file.project_settings",
                    {"Project Settings", "Configure project settings", ""},
                    "",
                    "",
               "qrc:/assets/icons/settings.svg",
                    true,
                    [this]() { emit requestProjectSettings(); }});

  registerMenuItem("File/Project",
                   {"file.project_metadata",
                    {"Project Metadata", "Edit project metadata", ""},
                    "",
                    "",
               "qrc:/assets/icons/edit.svg",
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
} // namespace xyla
