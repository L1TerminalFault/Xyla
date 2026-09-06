#pragma once

#include "core/settings/shortcutManager.hpp"
#include "xylaActionData.hpp"
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>

namespace xyla {

class XylaActionManager : public QObject {
  Q_OBJECT

public:
  explicit XylaActionManager(ShortcutManager *shortcutManager,
                             QObject *parent = nullptr);
  ~XylaActionManager() override = default;

  // 1. Action Registration (Domain subsystems call this)
  void registerAction(XylaActionData action);
  [[nodiscard]] bool hasAction(const QString &actionId) const;

  // 2. Execution Dispatch
  Q_INVOKABLE bool triggerAction(const QString &actionId);

  // 3. State Management (Enabled/Disabled)
  [[nodiscard]] Q_INVOKABLE bool isEnabled(const QString &actionId) const;
  Q_INVOKABLE void setEnabled(const QString &actionId, bool enabled);

  // 4. Data Inspection (Used by MenuManager and Tooltips)
  [[nodiscard]] Q_INVOKABLE QString shortcut(const QString &actionId) const;
  [[nodiscard]] Q_INVOKABLE QVariantMap
  getAction(const QString &actionId) const;
  [[nodiscard]] Q_INVOKABLE QVariantMap
  getTooltip(const QString &actionId) const;

signals:
  void actionTriggered(const QString &actionId);
  void actionStateChanged(const QString &actionId, bool enabled);
  void shortcutChanged(const QString &actionId, const QString &newShortcut);

public slots:
  // Automatically called when ShortcutManager changes presets or alters a key
  void reloadShortcutsFromManager();

private:
  ShortcutManager *m_shortcutManager{nullptr};
  QHash<QString, XylaActionData> m_actions;
};

} // namespace xyla
