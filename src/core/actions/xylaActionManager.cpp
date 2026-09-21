#include "xylaActionManager.hpp"
#include "../log/logger.hpp"

namespace xyla {

XylaActionManager::XylaActionManager(
    ShortcutManager *shortcutManager,
    WorkspaceLayoutController *workspaceLayoutController, QObject *parent)
    : QObject(parent), m_shortcutManager(shortcutManager),
      m_workspaceLayoutController(workspaceLayoutController) {
  Q_ASSERT(m_shortcutManager != nullptr);

  connect(m_shortcutManager, &ShortcutManager::shortcutsChanged, this,
          &XylaActionManager::reloadShortcutsFromManager);
  connect(m_shortcutManager, &ShortcutManager::presetApplied, this,
          &XylaActionManager::reloadShortcutsFromManager);
}

QString XylaActionManager::currentDockPrefix() const {
  if (!m_workspaceLayoutController)
    return QStringLiteral("timeline");

  const QString dockId = m_workspaceLayoutController->activeDockId();

  if (dockId == QLatin1String("DopesheetPanel"))
    return QStringLiteral("dopesheet");
  if (dockId == QLatin1String("TimelinePanel"))
    return QStringLiteral("timeline");
  if (dockId == QLatin1String("NodegraphPanel"))
    return QStringLiteral("nodegraph");
  if (dockId == QLatin1String("MediaPanel"))
    return QStringLiteral("media");
  if (dockId == QLatin1String("ColorgradePanel"))
    return QStringLiteral("color");
  if (dockId == QLatin1String("MixerPanel"))
    return QStringLiteral("mixer");
  if (dockId == QLatin1String("ProjectmonitorPanel"))
    return QStringLiteral("monitor");
  if (dockId == QLatin1String("InspectorPanel"))
    return QStringLiteral("properties");

  return QStringLiteral("timeline");
}

// @brief Resolves context-sensitive action ID taking active dock prefix into
// account.
QString XylaActionManager::resolveActionId(const QString &rawActionId) const {
  if (rawActionId.isEmpty())
    return {};

  const int dotIdx = rawActionId.lastIndexOf(QLatin1Char('.'));
  const QString suffix =
      (dotIdx != -1) ? rawActionId.mid(dotIdx + 1) : rawActionId;
  const QString domain = (dotIdx != -1) ? rawActionId.left(dotIdx) : QString();

  // 1. Global application actions that NEVER depend on the active panel
  if (domain == QLatin1String("file") || domain == QLatin1String("app") ||
      domain == QLatin1String("project") || domain == QLatin1String("window") ||
      domain == QLatin1String("help") || domain == QLatin1String("edit") ||
      suffix == QLatin1String("undo") || suffix == QLatin1String("redo")) {

    // If registered directly under rawActionId (e.g. "edit.undo"), return it
    if (m_actions.contains(rawActionId))
      return rawActionId;

    // If passed as bare "undo" or "redo", resolve to "edit.undo" / "edit.redo"
    const QString editAction = QStringLiteral("edit.") + suffix;
    if (m_actions.contains(editAction))
      return editAction;

    return rawActionId;
  }

  // 2. Check if the active dock has a specific action for this verb (e.g.
  // "dopesheet.delete")
  const QString activePrefix = currentDockPrefix();
  const QString contextAction = activePrefix + QLatin1Char('.') + suffix;

  if (m_actions.contains(contextAction)) {
    return contextAction;
  }

  // 3. If the active dock doesn't override it, check if the raw ID exists
  if (m_actions.contains(rawActionId)) {
    return rawActionId;
  }

  // 4. Fallback: check if exactly one action matches this suffix
  QString singleMatch;
  int matchCount = 0;

  for (auto it = m_actions.cbegin(); it != m_actions.cend(); ++it) {
    const QString &key = it.key();
    if (key == suffix || key.endsWith(QLatin1Char('.') + suffix)) {
      matchCount++;
      singleMatch = key;
    }
  }

  if (matchCount == 1) {
    return singleMatch;
  }

  return {};
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
    // 1. Try direct shortcut lookup
    action.currentShortcut = m_shortcutManager->getShortcut(action.id);

    // 2. AUTOMATIC FALLBACK INHERITANCE:
    // If "dopesheet.delete" has no explicit shortcut, inherit from
    // "timeline.delete" or "delete"
    if (action.currentShortcut.isEmpty()) {
      const int dotIdx = action.id.lastIndexOf(QLatin1Char('.'));
      const QString suffix =
          (dotIdx != -1) ? action.id.mid(dotIdx + 1) : action.id;

      action.currentShortcut = m_shortcutManager->getShortcut(suffix);
      if (action.currentShortcut.isEmpty()) {
        action.currentShortcut = m_shortcutManager->getShortcut(
            QStringLiteral("timeline.") + suffix);
      }
    }
  }

  m_actions.insert(action.id, std::move(action));
}

bool XylaActionManager::hasAction(const QString &actionId) const {
  if (m_actions.contains(actionId))
    return true;
  const QString resolved = resolveActionId(actionId);
  return !resolved.isEmpty() && m_actions.contains(resolved);
}

bool XylaActionManager::triggerAction(const QString &actionId) {
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty()) {
    return false;
  }

  auto it = m_actions.find(resolved);
  if (it == m_actions.end() || !it->enabled) {
    return false;
  }

  // If the action is not global, ensure its domain matches the active dock prefix
  if (!it->global) {
    const int dotIdx = resolved.lastIndexOf(QLatin1Char('.'));
    const QString domain = (dotIdx != -1) ? resolved.left(dotIdx) : QString();

    if (domain != currentDockPrefix()) {
      return false;
    }
  }

  XYLA_LOG_INFO("XylaActionManager", "Action triggered [" +
                                         currentDockPrefix().toStdString() +
                                         "]: " + resolved.toStdString());

  if (it->callback) {
    it->callback();
  }

  emit actionTriggered(resolved);
  return true;
}

bool XylaActionManager::isEnabled(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end())
    return it->enabled;

  const QString resolved = resolveActionId(actionId);
  if (!resolved.isEmpty()) {
    auto rit = m_actions.find(resolved);
    return (rit != m_actions.end()) ? rit->enabled : false;
  }
  return false;
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
  if (it != m_actions.end() && !it->currentShortcut.isEmpty())
    return it->currentShortcut;

  const QString resolved = resolveActionId(actionId);
  if (!resolved.isEmpty()) {
    auto rit = m_actions.find(resolved);
    if (rit != m_actions.end())
      return rit->currentShortcut;
  }
  return {};
}

QVariantMap XylaActionManager::getAction(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end())
    return it->toVariantMap();

  const QString resolved = resolveActionId(actionId);
  if (!resolved.isEmpty()) {
    auto rit = m_actions.find(resolved);
    return (rit != m_actions.end()) ? rit->toVariantMap() : QVariantMap();
  }
  return {};
}

QVariantMap XylaActionManager::getTooltip(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end())
    return it->tooltip.toVariantMap();

  const QString resolved = resolveActionId(actionId);
  if (!resolved.isEmpty()) {
    auto rit = m_actions.find(resolved);
    return (rit != m_actions.end()) ? rit->tooltip.toVariantMap()
                                    : QVariantMap();
  }
  return {};
}

void XylaActionManager::reloadShortcutsFromManager() {
  if (!m_shortcutManager)
    return;

  for (auto it = m_actions.begin(); it != m_actions.end(); ++it) {
    QString updatedKey = m_shortcutManager->getShortcut(it.key());

    // Sibling inheritance on reload as well
    if (updatedKey.isEmpty()) {
      const int dotIdx = it.key().lastIndexOf(QLatin1Char('.'));
      const QString suffix =
          (dotIdx != -1) ? it.key().mid(dotIdx + 1) : it.key();
      updatedKey = m_shortcutManager->getShortcut(suffix);
      if (updatedKey.isEmpty()) {
        updatedKey = m_shortcutManager->getShortcut(
            QStringLiteral("timeline.") + suffix);
      }
    }

    if (it->currentShortcut != updatedKey) {
      it->currentShortcut = updatedKey;
      emit shortcutChanged(it.key(), updatedKey);
    }
  }
}

} // namespace xyla
