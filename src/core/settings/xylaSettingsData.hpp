#pragma once

#include <QString>

namespace xyla {

struct XylaSettingsData {
  QString theme{"Dark"};
  double uiScale{1.0};

  bool autoSaveEnabled{true};
  int autoSaveIntervalMinutes{5};

  int maxRecentProjects{10};
  bool reopenLastProjectOnStartup{false};

  bool operator==(const XylaSettingsData &other) const = default;
};

} // namespace xyla
