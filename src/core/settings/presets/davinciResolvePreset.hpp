#pragma once

#include "xylaDefaultPreset.hpp"
#include <QString>
#include <unordered_map>

namespace xyla::presets {

inline std::unordered_map<QString, QString> getDaVinciResolvePreset() {
  auto map = getXylaDefaultPreset();

  // DaVinci Resolve Overrides
  map["timeline.splitClip"] = "Ctrl+\\";
  map["timeline.selectionTool"] = "A";
  map["timeline.bladeTool"] = "B";
  map["timeline.rippleTrimIn"] = "Shift+[";
  map["timeline.rippleTrimOut"] = "Shift+]";
  map["timeline.zoomFit"] = "Shift+Z";
  map["timeline.zoomIn"] = "Ctrl+=";
  map["timeline.zoomOut"] = "Ctrl+-";
  map["timeline.rippleDelete"] = "Shift+Backspace";
  map["timeline.delete"] = "Backspace";
  map["nodegraph.bypassGrade"] = "Shift+D";
  map["app.redo"] = "Ctrl+Shift+Z";
  map["app.fullscreen"] = "Ctrl+F";

  return map;
}

} // namespace xyla::presets
