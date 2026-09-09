#pragma once

#include "core/settings/shortcutManager.hpp"
#include "ui/workspaceLayoutController.hpp"
#include "xylaActionData.hpp"

#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>

namespace xyla {

class XylaActionManager : public QObject {
  Q_OBJECT

public:
  explicit XylaActionManager(
      ShortcutManager *shortcutManager,
      WorkspaceLayoutController *workspaceLayoutController = nullptr,
      QObject *parent = nullptr);
  ~XylaActionManager() override = default;

  // 1. Action Registration
  void registerAction(XylaActionData action);
  [[nodiscard]] bool hasAction(const QString &actionId) const;

  // 2. Execution Dispatch (Context-Aware)
  Q_INVOKABLE bool triggerAction(const QString &actionId);

  // 3. State Management
  [[nodiscard]] Q_INVOKABLE bool isEnabled(const QString &actionId) const;
  Q_INVOKABLE void setEnabled(const QString &actionId, bool enabled);

  // 4. Data Inspection
  [[nodiscard]] Q_INVOKABLE QString shortcut(const QString &actionId) const;
  [[nodiscard]] Q_INVOKABLE QVariantMap
  getAction(const QString &actionId) const;
  [[nodiscard]] Q_INVOKABLE QVariantMap
  getTooltip(const QString &actionId) const;

  // 5. Context Resolution Helper
  [[nodiscard]] Q_INVOKABLE QString
  resolveActionId(const QString &actionId) const;
  [[nodiscard]] QString currentDockPrefix() const;

signals:
  void actionTriggered(const QString &actionId);
  void actionStateChanged(const QString &actionId, bool enabled);
  void shortcutChanged(const QString &actionId, const QString &newShortcut);

public slots:
  void reloadShortcutsFromManager();

private:
  ShortcutManager *m_shortcutManager{nullptr};
  WorkspaceLayoutController *m_workspaceLayoutController{nullptr};
  QHash<QString, XylaActionData> m_actions;
};

} // namespace xyla
