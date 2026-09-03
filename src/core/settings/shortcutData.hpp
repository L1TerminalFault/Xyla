#pragma once

#include <QString>
#include <QVariantMap>
#include <vector>

namespace xyla {

struct ShortcutAction {
  QString id;
  QString name;
  QString category;
  QString description;
  QString defaultKey;
  QString currentKey;

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"id", id},
            {"name", name},
            {"category", category},
            {"description", description},
            {"defaultKey", defaultKey},
            {"currentKey", currentKey.isEmpty() ? defaultKey : currentKey}};
  }
};

inline std::vector<ShortcutAction> getMasterActionCatalog() {
  return {
      {"playback.togglePlay", "Play / Pause", "Playback",
       "Toggle forward playback", "Space", "Space"},
      {"playback.playReverse", "Shuttle Reverse (J)", "Playback",
       "Play timeline backwards", "J", "J"},
      {"playback.pause", "Shuttle Pause (K)", "Playback", "Pause playback", "K",
       "K"},
      {"playback.playForward", "Shuttle Forward (L)", "Playback",
       "Play timeline forward", "L", "L"},
      {"playback.stepForward", "Step 1 Frame Forward", "Playback",
       "Move playhead 1 frame right", "Right", "Right"},
      {"playback.stepBackward", "Step 1 Frame Backward", "Playback",
       "Move playhead 1 frame left", "Left", "Left"},
      {"playback.stepLargeFwd", "Step 1 Second Forward", "Playback",
       "Move playhead 1 second right", "Shift+Right", "Shift+Right"},
      {"playback.stepLargeBack", "Step 1 Second Backward", "Playback",
       "Move playhead 1 second left", "Shift+Left", "Shift+Left"},
      {"playback.jumpStart", "Go to Start / Home", "Playback",
       "Move playhead to timeline start", "Home", "Home"},
      {"playback.jumpEnd", "Go to End", "Playback",
       "Move playhead to timeline end", "End", "End"},
      {"playback.jumpNextEdit", "Next Edit / Clip Cut", "Playback",
       "Jump to next clip boundary", "Down", "Down"},
      {"playback.jumpPrevEdit", "Previous Edit / Clip Cut", "Playback",
       "Jump to previous clip boundary", "Up", "Up"},
      {"playback.loopToggle", "Loop Playback", "Playback",
       "Toggle loop playback mode", "Ctrl+/", "Ctrl+/"},

      // --- TIMELINE EDITING & TOOLS ---
      {"timeline.splitClip", "Split / Razor Blade", "Timeline",
       "Cut selected clips at playhead", "C", "C"},
      {"timeline.selectionTool", "Selection Tool (Arrow)", "Timeline",
       "Activate standard selection tool", "V", "V"},
      {"timeline.bladeTool", "Blade / Razor Tool", "Timeline",
       "Activate razor blade tool", "C", "C"},
      {"timeline.rippleTrimIn", "Ripple Trim Start (Top)", "Timeline",
       "Ripple trim from clip in to playhead", "Q", "Q"},
      {"timeline.rippleTrimOut", "Ripple Trim End (Tail)", "Timeline",
       "Ripple trim from playhead to out", "W", "W"},
      {"timeline.markIn", "Mark In Point", "Timeline", "Set timeline In point",
       "I", "I"},
      {"timeline.markOut", "Mark Out Point", "Timeline",
       "Set timeline Out point", "O", "O"},
      {"timeline.clearInOut", "Clear In and Out", "Timeline",
       "Clear marked In/Out range", "Alt+X", "Alt+X"},
      {"timeline.rippleDelete", "Ripple Delete", "Timeline",
       "Delete clip and close gap", "Shift+Delete", "Shift+Delete"},
      {"timeline.delete", "Delete / Lift", "Timeline",
       "Remove clip leaving empty gap", "Delete", "Delete"},
      {"timeline.linkClips", "Link Clips", "Timeline",
       "Link selected clips together", "Ctrl+L", "Ctrl+L"},
      {"timeline.unlinkClips", "Unlink Clips", "Timeline",
       "Unlink selected clips", "Ctrl+Shift+L", "Ctrl+Shift+L"},
      {"timeline.toggleClipLock", "Lock / Unlock Selected Clip", "Timeline",
       "Toggle lock state for selected clips", "Ctrl+Alt+L", "Ctrl+Alt+L"},
      {"timeline.toggleSnapping", "Toggle Snapping", "Timeline",
       "Enable or disable timeline snapping", "N", "N"},
      {"timeline.duplicate", "Duplicate Clip", "Timeline",
       "Duplicate selected clip", "Ctrl+D", "Ctrl+D"},

      // --- TIMELINE ZOOM & PAN ---
      {"timeline.zoomIn", "Zoom In", "Zoom & View", "Zoom in on timeline", "=",
       "="},
      {"timeline.zoomOut", "Zoom Out", "Zoom & View", "Zoom out on timeline",
       "-", "-"},
      {"timeline.zoomFit", "Zoom to Fit", "Zoom & View",
       "Fit entire timeline in view", "Shift+Z", "Shift+Z"},

      // --- NODE GRAPH & GRADING ---
      {"nodegraph.addNode", "Add Node Search Palette", "Node Graph",
       "Open node creation popup", "Tab", "Tab"},
      {"nodegraph.resetView", "Reset Graph View", "Node Graph",
       "Reset node graph zoom and pan", "Home", "Home"},
      {"nodegraph.deleteNode", "Delete Selected Nodes", "Node Graph",
       "Remove active node from graph", "Delete", "Delete"},
      {"nodegraph.bypassGrade", "Bypass All Color / Effects", "Node Graph",
       "Toggle master color bypass", "Shift+D", "Shift+D"},

      // --- APPLICATION & PROJECT ---
      {"app.undo", "Undo", "Application", "Undo last operation", "Ctrl+Z",
       "Ctrl+Z"},
      {"app.redo", "Redo", "Application", "Redo last undone operation",
       "Ctrl+Shift+Z", "Ctrl+Shift+Z"},
      {"app.save", "Save Project", "Application", "Save project to disk",
       "Ctrl+S", "Ctrl+S"},
      {"app.saveAs", "Save Project As", "Application",
       "Save project under new name", "Ctrl+Shift+S", "Ctrl+Shift+S"},
      {"app.importMedia", "Import Media", "Application",
       "Import video/audio files", "Ctrl+I", "Ctrl+I"},
      {"app.fullscreen", "Toggle Fullscreen", "Application",
       "Maximize viewport to full screen", "Ctrl+F", "Ctrl+F"},
      {"app.shortcuts", "Keyboard Shortcuts...", "Application",
       "Open the keyboard shortcuts visualizer", "Ctrl+Alt+K", "Ctrl+Alt+K"},
      {"app.preferences", "Preferences...", "Application",
       "Open workspace preferences", "Ctrl+,", "Ctrl+,"},
  };
}

} // namespace xyla
