#include "xylaActionManager.hpp"
#include "core/log/logger.hpp"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace xyla {

XylaActionManager::XylaActionManager(QObject *parent) : QObject(parent) {
  loadShortcuts();
}

void XylaActionManager::registerAction(const XylaActionData &action) {
  if (m_actions.contains(action.id)) {
    XYLA_LOG_WARN("XylaActionManager",
                  "Action already registered: " + action.id.toStdString());
    return;
  }
  m_actions.insert(action.id, action);
}

bool XylaActionManager::triggerAction(const QString &actionId) {
  auto it = m_actions.find(actionId);
  if (it == m_actions.end()) {
    XYLA_LOG_WARN("XylaActionManager",
                  "Attempted trigger for unknown action: " +
                      actionId.toStdString());
    return false;
  }

  if (!it->enabled) {
    XYLA_LOG_INFO("XylaActionManager", "Action disabled, ignoring trigger: " +
                                           actionId.toStdString());
    return false;
  }

  XYLA_LOG_INFO("XylaActionManager",
                "Action triggered: " + actionId.toStdString());

  if (it->callback) {
    it->callback();
  }

  emit actionTriggered(actionId);
  return true;
}

QString XylaActionManager::shortcut(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->currentShortcut : QString();
}

bool XylaActionManager::setShortcut(const QString &actionId,
                                    const QString &keySequence) {
  auto it = m_actions.find(actionId);
  if (it == m_actions.end())
    return false;

  if (it->currentShortcut != keySequence) {
    it->currentShortcut = keySequence;
    emit shortcutChanged(actionId, keySequence);
    saveShortcuts();
    XYLA_LOG_INFO("XylaActionManager", "Shortcut updated for " +
                                           actionId.toStdString() + " -> " +
                                           keySequence.toStdString());
  }
  return true;
}

bool XylaActionManager::isEnabled(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->enabled : false;
}

void XylaActionManager::setEnabled(const QString &actionId, bool enabled) {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end() && it->enabled != enabled) {
    it->enabled = enabled;
    emit actionStateChanged(actionId, enabled);
  }
}

QVariantMap XylaActionManager::getAction(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->toVariantMap() : QVariantMap();
}

QVariantMap XylaActionManager::getTooltip(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->tooltip.toVariantMap() : QVariantMap();
}

QString XylaActionManager::getShortcutsFilePath() const {
  QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  QDir().mkpath(configDir);
  return configDir + "/shortcuts.json";
}

void XylaActionManager::loadShortcuts() {
  QFile file(getShortcutsFilePath());
  if (!file.open(QIODevice::ReadOnly))
    return;

  QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
  file.close();

  if (!doc.isObject())
    return;
  QJsonObject obj = doc.object();

  for (auto it = obj.begin(); it != obj.end(); ++it) {
    if (m_actions.contains(it.key())) {
      m_actions[it.key()].currentShortcut = it.value().toString();
    }
  }
}

void XylaActionManager::saveShortcuts() const {
  QFile file(getShortcutsFilePath());
  if (!file.open(QIODevice::WriteOnly)) {
    XYLA_LOG_ERROR("XylaActionManager", "Failed to save shortcuts file to: " +
                                            file.fileName().toStdString());
    return;
  }

  QJsonObject obj;
  for (auto it = m_actions.begin(); it != m_actions.end(); ++it) {
    if (it->currentShortcut != it->defaultShortcut) {
      obj[it.key()] = it->currentShortcut;
    }
  }

  file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
  file.close();
}

} // namespace xyla
