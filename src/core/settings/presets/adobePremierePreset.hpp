#pragma once

#include "xylaDefaultPreset.hpp"
#include <QString>
#include <unordered_map>

namespace xyla::presets {

inline std::unordered_map<QString, QString> getAdobePremierePreset() {
  auto map = getXylaDefaultPreset();

  // Adobe Premiere Pro Overrides
  map["timeline.splitClip"] = "Ctrl+K";
  map["timeline.selectionTool"] = "V";
  map["timeline.bladeTool"] = "C";
  map["timeline.rippleTrimIn"] = "Q";
  map["timeline.rippleTrimOut"] = "W";
  map["timeline.zoomFit"] = "\\";
  map["timeline.zoomIn"] = "=";
  map["timeline.zoomOut"] = "-";
  map["timeline.rippleDelete"] = "Shift+Delete";
  map["timeline.delete"] = "Delete";
  map["timeline.clearInOut"] = "Ctrl+Shift+X";
  map["app.redo"] = "Ctrl+Shift+Z";
  map["app.fullscreen"] = "`";

  return map;
}

} // namespace xyla::presets
