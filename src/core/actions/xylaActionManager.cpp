#include "xylaActionManager.hpp"
#include "core/log/logger.hpp"

namespace xyla {

XylaActionManager::XylaActionManager(ShortcutManager *shortcutManager,
                                     QObject *parent)
    : QObject(parent), m_shortcutManager(shortcutManager) {
  Q_ASSERT(m_shortcutManager != nullptr);

  // When ShortcutManager updates a preset or single key, refresh all cached
  // actions
  connect(m_shortcutManager, &ShortcutManager::shortcutsChanged, this,
          &XylaActionManager::reloadShortcutsFromManager);
  connect(m_shortcutManager, &ShortcutManager::presetApplied, this,
          &XylaActionManager::reloadShortcutsFromManager);
}

void XylaActionManager::registerAction(XylaActionData action) {
  auto it = m_actions.find(action.id);
  if (it != m_actions.end()) {
    if (!action.callback && it->callback) {
      action.callback = it->callback;
    }
    action.enabled = it->enabled;
  }

  if (m_shortcutManager) {
    action.currentShortcut = m_shortcutManager->getShortcut(action.id);
  }

  m_actions.insert(action.id, std::move(action));
}

bool XylaActionManager::hasAction(const QString &actionId) const {
  return m_actions.contains(actionId);
}

bool XylaActionManager::triggerAction(const QString &actionId) {
  auto it = m_actions.find(actionId);
  if (it == m_actions.end()) {
    XYLA_LOG_WARN("XylaActionManager",
                  "Unknown action trigger: " + actionId.toStdString());
    return false;
  }

  if (!it->enabled) {
    XYLA_LOG_INFO("XylaActionManager",
                  "Action disabled, ignored: " + actionId.toStdString());
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

QString XylaActionManager::shortcut(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->currentShortcut : QString();
}

QVariantMap XylaActionManager::getAction(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->toVariantMap() : QVariantMap();
}

QVariantMap XylaActionManager::getTooltip(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->tooltip.toVariantMap() : QVariantMap();
}

void XylaActionManager::reloadShortcutsFromManager() {
  if (!m_shortcutManager)
    return;

  for (auto it = m_actions.begin(); it != m_actions.end(); ++it) {
    QString updatedKey = m_shortcutManager->getShortcut(it.key());
    if (it->currentShortcut != updatedKey) {
      it->currentShortcut = updatedKey;
      emit shortcutChanged(it.key(), updatedKey);
    }
  }
}

} // namespace xyla
