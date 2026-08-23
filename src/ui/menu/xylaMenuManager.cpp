#include "xylaMenuManager.hpp"
#include <QCoreApplication>
#include <QDebug>
#include <QMap>

namespace xyla {

MenuManager::MenuManager(XylaActionManager *actionManager, QObject *parent)
    : QObject(parent), m_actionManager(actionManager) {

  Q_ASSERT(m_actionManager != nullptr);

  // Rebuild tree if dynamic keybindings change at runtime
  connect(m_actionManager, &XylaActionManager::shortcutChanged, this,
          &MenuManager::rebuildMenuTree);
  connect(m_actionManager, &XylaActionManager::actionStateChanged, this,
          &MenuManager::rebuildMenuTree);

  setupDefaultActions();
}

void MenuManager::setupDefaultActions() {
  // File Menu Actions
  registerMenuItem("File", {"file.new",
                            {"New Project...", "Create a new Xyla project",
                             "https://docs.xyla.dev/manual/new-project"},
                            "Ctrl+N",
                            "Ctrl+N",
                            "qrc:/assets/icons/folder-plus.svg",
                            true,
                            [this]() { emit requestNewProject(); }});

  registerMenuItem("File", {"file.open",
                            {"Open Project...", "Open an existing Xyla project",
                             "https://docs.xyla.dev/manual/open-project"},
                            "Ctrl+O",
                            "Ctrl+O",
                            "qrc:/assets/icons/folder.svg",
                            true,
                            [this]() { emit requestOpenProject(); }});

  registerMenuItem("File", {"file.save",
                            {"Save Project", "Save current project changes",
                             "https://docs.xyla.dev/manual/saving"},
                            "Ctrl+S",
                            "Ctrl+S",
                            "qrc:/assets/icons/settings.svg",
                            true,
                            [this]() { emit requestSaveProject(); }});

  registerSeparator("File");

  registerMenuItem("File", {"file.quit",
                            {"Quit", "Exit application", ""},
                            "Ctrl+Q",
                            "Ctrl+Q",
                            "qrc:/assets/icons/x.svg",
                            true,
                            []() { QCoreApplication::quit(); }});

  // Edit Menu Actions
  registerMenuItem("Edit", {"edit.undo",
                            {"Undo", "Revert last action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Z",
                            "Ctrl+Z",
                            "qrc:/assets/icons/arrow-left.svg",
                            true,
                            [this]() { emit requestUndo(); }});

  registerMenuItem("Edit", {"edit.redo",
                            {"Redo", "Re-apply last undone action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Y",
                            "Ctrl+Y",
                            "qrc:/assets/icons/arrow-right.svg",
                            true,
                            [this]() { emit requestRedo(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit",
                   {"edit.preferences",
                    {"Preferences...", "Open workspace preferences", ""},
                    "Ctrl+,",
                    "Ctrl+,",
                    "qrc:/assets/icons/settings.svg",
                    true,
                    [this]() { emit requestPreferences(); }});
}

void MenuManager::registerMenuItem(const QString &menuPath,
                                   const XylaActionData &action) {
  m_actionManager->registerAction(action);
  m_menuStructure.push_back({menuPath, action.id, false});
  rebuildMenuTree();
}

void MenuManager::registerSeparator(const QString &menuPath) {
  static int separatorCounter = 0;
  QString sepId = QString("sep_%1").arg(++separatorCounter);

  // Register structural separator node
  m_menuStructure.push_back({menuPath, sepId, true});
  rebuildMenuTree();
}

void MenuManager::triggerAction(const QString &actionId) {
  if (m_actionManager) {
    m_actionManager->triggerAction(actionId);
  }
}

void MenuManager::rebuildMenuTree() {
  QList<QString> menuOrder;
  QMap<QString, QVariantList> menuGroups;

  for (const auto &item : m_menuStructure) {
    if (!menuGroups.contains(item.menuPath)) {
      menuOrder.append(item.menuPath);
    }

    QVariantMap itemMap;
    itemMap["isSeparator"] = item.isSeparator;

    if (item.isSeparator) {
      itemMap["id"] = item.actionId;
    } else {
      QVariantMap actionMap = m_actionManager->getAction(item.actionId);
      itemMap["id"] = item.actionId;
      itemMap["title"] = actionMap["tooltip"].toMap()["title"].toString();
      itemMap["description"] =
          actionMap["tooltip"].toMap()["description"].toString();
      itemMap["docsUrl"] = actionMap["tooltip"].toMap()["docsUrl"].toString();
      itemMap["shortcut"] = actionMap["currentShortcut"].toString();
      itemMap["icon"] = actionMap["icon"].toString();
      itemMap["enabled"] = actionMap["enabled"].toBool();
    }

    menuGroups[item.menuPath].append(itemMap);
  }

  QVariantList tree;
  for (const QString &menuTitle : menuOrder) {
    QVariantMap topMenu;
    topMenu["title"] = menuTitle;
    topMenu["items"] = menuGroups[menuTitle];
    tree.append(topMenu);
  }

  m_cachedMenuTree = tree;
  emit menuTreeChanged();
}

} // namespace xyla
