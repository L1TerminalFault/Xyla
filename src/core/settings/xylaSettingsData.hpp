#pragma once

#include <QString>

namespace xyla {

struct XylaSettingsData {
  // NOTE: General Main Settings fields start here
  QString theme{"Dark"};
  double uiScale{1.0};

  bool autoSaveEnabled{true};
  int autoSaveIntervalMinutes{5};

  int maxRecentProjects{10};
  bool reopenLastProjectOnStartup{false};
  // NOTE: General Main Settings fields end here

  // NOTE: File Manager Settings fields start here
  QString startupLocation{"Home"};
  QString defaultView{"Grid"};
  bool rememberLastFolder{true};
  bool confirmDelete{true};
  bool smoothAnimations{true};
  bool showHiddenFiles{false};
  bool showFileExtensions{true};
  QString sortMode{"Name"};
  bool openFoldersWithDoubleClick{true};
  bool showTooltips{true};
  // NOTE: File Manager Settings fields end here

  bool operator==(const XylaSettingsData &other) const = default;
};

} // namespace xyla
