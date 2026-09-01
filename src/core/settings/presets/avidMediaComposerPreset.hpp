#pragma once

#include "xylaDefaultPreset.hpp"
#include <QString>
#include <unordered_map>

namespace xyla::presets {

inline std::unordered_map<QString, QString> getAvidMediaComposerPreset() {
  auto map = getXylaDefaultPreset();

  // Avid Media Composer Overrides
  map["timeline.splitClip"] = "H";
  map["timeline.selectionTool"] = "Shift+A";
  map["timeline.bladeTool"] = "\\";
  map["timeline.rippleTrimIn"] = "U";
  map["timeline.rippleTrimOut"] = "I";
  map["timeline.zoomFit"] = "Ctrl+/";
  map["timeline.zoomIn"] = "Ctrl+L";
  map["timeline.zoomOut"] = "Ctrl+K";
  map["timeline.rippleDelete"] = "X";
  map["timeline.delete"] = "Z";
  map["timeline.clearInOut"] = "G";
  map["app.redo"] = "Ctrl+R";

  return map;
}

} // namespace xyla::presets
