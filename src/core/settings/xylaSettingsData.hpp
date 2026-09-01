#pragma once

#include <QObject>
#include <QString>

namespace xyla {

class ZoomAnchor {
  Q_GADGET
public:
  enum Mode { MousePosition = 0, PlayheadPosition, CenterOfView };
  Q_ENUM(Mode)
};

struct XylaSettingsData {
  // NOTE: General Main Settings fields start here
  QString theme{"Dark"};
  double uiScale{1.0};

  bool autoSaveEnabled{true};
  int autoSaveIntervalMinutes{5};

  int maxRecentProjects{10};
  bool reopenLastProjectOnStartup{false};

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

  // NOTE: timeline settings start here
  ZoomAnchor::Mode zoomAnchorMode = ZoomAnchor::MousePosition;
  bool operator==(const XylaSettingsData &other) const = default;
};

} // namespace xyla
