#pragma once

#include <QString>
#include <QVariantMap>
#include <functional>

namespace xyla {

struct ActionTooltip {
  QString title;
  QString description;
  QString docsUrl;

  QVariantMap toVariantMap() const {
    return {
        {"title", title}, {"description", description}, {"docsUrl", docsUrl}};
  }
};

struct XylaActionData {
  QString id;
  ActionTooltip tooltip;
  QString defaultShortcut;
  QString currentShortcut;
  QString icon;
  bool enabled{true};

  std::function<void()> callback;

  QVariantMap toVariantMap() const {
    return {{"id", id},
            {"tooltip", tooltip.toVariantMap()},
            {"defaultShortcut", defaultShortcut},
            {"currentShortcut", currentShortcut},
            {"icon", icon},
            {"enabled", enabled}};
  }
};

} // namespace xyla
