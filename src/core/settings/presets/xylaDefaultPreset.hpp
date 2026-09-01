#pragma once

#include "QstringHash.hpp"
#include <QString>
#include <unordered_map>

namespace xyla::presets {

inline std::unordered_map<QString, QString> getXylaDefaultPreset() {
  return {{"playback.togglePlay", "Space"},
          {"playback.playReverse", "J"},
          {"playback.pause", "K"},
          {"playback.playForward", "L"},
          {"playback.stepForward", "Right"},
          {"playback.stepBackward", "Left"},
          {"playback.stepLargeFwd", "Shift+Right"},
          {"playback.stepLargeBack", "Shift+Left"},
          {"playback.jumpStart", "Home"},
          {"playback.jumpEnd", "End"},
          {"playback.jumpNextEdit", "Down"},
          {"playback.jumpPrevEdit", "Up"},
          {"playback.loopToggle", "Ctrl+/"},

          // Timeline & Tools
          {"timeline.splitClip", "C"},
          {"timeline.selectionTool", "V"},
          {"timeline.bladeTool", "C"},
          {"timeline.rippleTrimIn", "Q"},
          {"timeline.rippleTrimOut", "W"},
          {"timeline.markIn", "I"},
          {"timeline.markOut", "O"},
          {"timeline.clearInOut", "Alt+X"},
          {"timeline.rippleDelete", "Shift+Delete"},
          {"timeline.delete", "Delete"},
          {"timeline.snapToggle", "N"},
          {"timeline.duplicate", "Ctrl+D"},

          // Zoom
          {"timeline.zoomIn", "="},
          {"timeline.zoomOut", "-"},
          {"timeline.zoomFit", "Shift+Z"},

          // Node Graph
          {"nodegraph.addNode", "Tab"},
          {"nodegraph.resetView", "Home"},
          {"nodegraph.deleteNode", "Delete"},
          {"nodegraph.bypassGrade", "Shift+D"},

          // Application
          {"app.undo", "Ctrl+Z"},
          {"app.redo", "Ctrl+Shift+Z"},
          {"app.save", "Ctrl+S"},
          {"app.saveAs", "Ctrl+Shift+S"},
          {"app.importMedia", "Ctrl+I"},
          {"app.fullscreen", "Ctrl+F"}};
}

} // namespace xyla::presets
