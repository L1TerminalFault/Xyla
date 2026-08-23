#pragma once

#include "xylaActionData.hpp"
#include <QHash>
#include <QObject>
#include <QVariantMap>

namespace xyla {

class XylaActionManager : public QObject {
  Q_OBJECT

public:
  explicit XylaActionManager(QObject *parent = nullptr);
  ~XylaActionManager() override = default;

  void registerAction(const XylaActionData &action);

  Q_INVOKABLE bool triggerAction(const QString &actionId);
  Q_INVOKABLE QString shortcut(const QString &actionId) const;
  Q_INVOKABLE bool setShortcut(const QString &actionId,
                               const QString &keySequence);
  Q_INVOKABLE bool isEnabled(const QString &actionId) const;
  Q_INVOKABLE void setEnabled(const QString &actionId, bool enabled);

  Q_INVOKABLE QVariantMap getAction(const QString &actionId) const;
  Q_INVOKABLE QVariantMap getTooltip(const QString &actionId) const;

  void loadShortcuts();
  void saveShortcuts() const;

signals:
  void actionTriggered(const QString &actionId);
  void shortcutChanged(const QString &actionId, const QString &newShortcut);
  void actionStateChanged(const QString &actionId, bool enabled);

private:
  QString getShortcutsFilePath() const;
  QHash<QString, XylaActionData> m_actions;
};

} // namespace xyla
