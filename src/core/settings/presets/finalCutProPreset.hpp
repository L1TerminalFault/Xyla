#pragma once

#include "xylaDefaultPreset.hpp"
#include <QString>
#include <unordered_map>

namespace xyla::presets {

inline std::unordered_map<QString, QString> getFinalCutProPreset() {
  auto map = getXylaDefaultPreset();

  // Apple Final Cut Pro Overrides
  map["timeline.splitClip"] = "Cmd+B";
  map["timeline.selectionTool"] = "A";
  map["timeline.bladeTool"] = "B";
  map["timeline.rippleTrimIn"] = "Option+[";
  map["timeline.rippleTrimOut"] = "Option+]";
  map["timeline.zoomFit"] = "Shift+Z";
  map["timeline.zoomIn"] = "Cmd+=";
  map["timeline.zoomOut"] = "Cmd+-";
  map["timeline.rippleDelete"] = "Delete";
  map["timeline.delete"] = "Shift+Delete";
  map["nodegraph.bypassGrade"] = "Option+B";
  map["app.redo"] = "Cmd+Shift+Z";
  map["app.fullscreen"] = "Cmd+Control+F";

  return map;
}

} // namespace xyla::presets
