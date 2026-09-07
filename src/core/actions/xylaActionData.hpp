#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <functional>

namespace xyla {

struct XylaActionTooltip {
  QString title{""};
  QString shortDescription{""};
  QString longDescription{""};
  QString docsUrl{""};
  XylaActionTooltip() = default;
  // 2. Old 3-argument constructor: {"Title", "Description", "docsUrl"}
  XylaActionTooltip(QString t, QString shortDesc, QString url = "")
      : title(std::move(t)), shortDescription(std::move(shortDesc)),
        docsUrl(std::move(url)) {}
  // 3. New 4-argument rich constructor: {"Title", "Short Desc", "Long Desc",
  // "docsUrl"}
  XylaActionTooltip(QString t, QString shortDesc, QString longDesc, QString url)
      : title(std::move(t)), shortDescription(std::move(shortDesc)),
        longDescription(std::move(longDesc)), docsUrl(std::move(url)) {}

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"title", title},
            {"description", shortDescription},
            {"shortDescription", shortDescription},
            {"longDescription", longDescription},
            {"docsUrl", docsUrl}};
  }
};

struct XylaActionData {
  QString id{""};
  XylaActionTooltip tooltip{};
  QString icon{""};
  bool enabled{true};
  std::function<void()> callback{nullptr};
  // Populated exclusively by ShortcutManager via ActionManager
  QString currentShortcut{""};
  // 1. Default constructor
  XylaActionData() = default;

  // 2. New Clean 5-argument constructor (no shortcuts)
  XylaActionData(QString id_, XylaActionTooltip tooltip_, QString icon_,
                 bool enabled_, std::function<void()> callback_)
      : id(std::move(id_)), tooltip(std::move(tooltip_)),
        icon(std::move(icon_)), enabled(enabled_),
        callback(std::move(callback_)) {}

  // 3. Backward-compatible 7-argument constructor (ignores old defaultShortcut
  // & currentShortcut)
  XylaActionData(QString id_, XylaActionTooltip tooltip_,
                 const QString & /*defaultShortcut*/,
                 const QString & /*currentShortcut*/, QString icon_,
                 bool enabled_, std::function<void()> callback_)
      : id(std::move(id_)), tooltip(std::move(tooltip_)),
        icon(std::move(icon_)), enabled(enabled_),
        callback(std::move(callback_)) {}

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"id", id},
            {"icon", icon},
            {"enabled", enabled},
            {"currentShortcut", currentShortcut},
            {"shortcut", currentShortcut},
            {"tooltip", tooltip.toVariantMap()}};
  }
};

} // namespace xyla
