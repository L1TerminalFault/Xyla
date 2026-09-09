#include "xylaActionManager.hpp"
#include "core/log/logger.hpp"

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

  const QString dockId = m_workspaceLayoutController->activeDockId().toLower();

  if (dockId.contains(QLatin1String("timeline")))
    return QStringLiteral("timeline");
  if (dockId.contains(QLatin1String("dopesheet")))
    return QStringLiteral("dopesheet");
  if (dockId.contains(QLatin1String("nodegraph")))
    return QStringLiteral("nodegraph");
  if (dockId.contains(QLatin1String("media")))
    return QStringLiteral("media");
  if (dockId.contains(QLatin1String("color")))
    return QStringLiteral("color");
  if (dockId.contains(QLatin1String("mixer")))
    return QStringLiteral("mixer");
  if (dockId.contains(QLatin1String("monitor")))
    return QStringLiteral("monitor");
  if (dockId.contains(QLatin1String("properties")) ||
      dockId.contains(QLatin1String("inspector")))
    return QStringLiteral("properties");

  return dockId;
}

QString XylaActionManager::resolveActionId(const QString &rawActionId) const {
  if (rawActionId.isEmpty())
    return {};

  // 1. Extract domain and suffix verb (e.g. "timeline.delete" -> domain
  // "timeline", suffix "delete")
  const int dotIdx = rawActionId.lastIndexOf(QLatin1Char('.'));
  const QString suffix =
      (dotIdx != -1) ? rawActionId.mid(dotIdx + 1) : rawActionId;
  const QString domain = (dotIdx != -1) ? rawActionId.left(dotIdx) : QString();

  // 2. Global application actions that never depend on the active panel
  if (domain == QLatin1String("file") || domain == QLatin1String("app") ||
      domain == QLatin1String("project") || domain == QLatin1String("window") ||
      domain == QLatin1String("help") ||
      rawActionId == QLatin1String("edit.undo") ||
      rawActionId == QLatin1String("edit.redo")) {
    return rawActionId;
  }

  // 3. Check if the currently active dock has a registered action for this verb
  const QString activePrefix = currentDockPrefix();
  const QString contextAction = activePrefix + QLatin1Char('.') + suffix;

  if (m_actions.contains(contextAction)) {
    return contextAction;
  }

  // 4. The active dock does NOT have a handler for this action.
  // Search all registered actions across all domains to see how many match this
  // suffix.
  QString singleMatch;
  int matchCount = 0;

  for (auto it = m_actions.cbegin(); it != m_actions.cend(); ++it) {
    const QString &key = it.key();
    if (key == suffix || key.endsWith(QLatin1Char('.') + suffix)) {
      matchCount++;
      singleMatch = key;
    }
  }

  // Rule: If exactly ONE action exists anywhere in the app (e.g. only
  // timeline.play exists), execute it.
  if (matchCount == 1) {
    return singleMatch;
  }

  // Rule: If MORE THAN ONE action matches (e.g. timeline.selectAll vs
  // dopesheet.selectAll) and neither belongs to the current tab, do NOT execute
  // any to prevent corrupting another panel.
  if (matchCount > 1) {
    XYLA_LOG_INFO("XylaActionManager",
                  "Ambiguous action for active dock [" +
                      activePrefix.toStdString() +
                      "]: " + suffix.toStdString() + " matches " +
                      std::to_string(matchCount) + " actions. Ignored.");
    return {};
  }

  // 5. Fall back to the raw ID if directly registered
  if (m_actions.contains(rawActionId))
    return rawActionId;

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
    action.currentShortcut = m_shortcutManager->getShortcut(action.id);
  }

  m_actions.insert(action.id, std::move(action));
}

bool XylaActionManager::hasAction(const QString &actionId) const {
  const QString resolved = resolveActionId(actionId);
  return !resolved.isEmpty() && m_actions.contains(resolved);
}

bool XylaActionManager::triggerAction(const QString &actionId) {
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty()) {
    return false;
  }

  auto it = m_actions.find(resolved);
  if (it == m_actions.end()) {
    XYLA_LOG_WARN("XylaActionManager",
                  "Unknown action trigger: " + resolved.toStdString());
    return false;
  }

  if (!it->enabled) {
    XYLA_LOG_INFO("XylaActionManager",
                  "Action disabled, ignored: " + resolved.toStdString());
    return false;
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
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty())
    return false;

  auto it = m_actions.find(resolved);
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
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty())
    return {};

  auto it = m_actions.find(resolved);
  return (it != m_actions.end()) ? it->currentShortcut : QString();
}

QVariantMap XylaActionManager::getAction(const QString &actionId) const {
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty())
    return {};

  auto it = m_actions.find(resolved);
  return (it != m_actions.end()) ? it->toVariantMap() : QVariantMap();
}

QVariantMap XylaActionManager::getTooltip(const QString &actionId) const {
  const QString resolved = resolveActionId(actionId);
  if (resolved.isEmpty())
    return {};

  auto it = m_actions.find(resolved);
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
