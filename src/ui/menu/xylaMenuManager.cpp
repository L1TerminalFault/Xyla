#include "xylaMenuManager.hpp"
#include <QCoreApplication>
#include <QDebug>
#include <QMap>

namespace xyla {

MenuManager::MenuManager(XylaActionManager *actionManager, QObject *parent)
    : QObject(parent), m_actionManager(actionManager) {

  Q_ASSERT(m_actionManager != nullptr);

  connect(m_actionManager, &XylaActionManager::shortcutChanged, this,
          &MenuManager::rebuildMenuTree);
  connect(m_actionManager, &XylaActionManager::actionStateChanged, this,
          &MenuManager::rebuildMenuTree);

  setupDefaultActions();
}

void MenuManager::setupDefaultActions() {
  setupFileActions();
  setupEditActions();
  setupViewActions();
  setupClipActions();
  setupTimelineActions();
  setupEffectsActions();
  setupTitleGraphicsActions();
  setupAudioActions();
  setupColorActions();
  setupReviewActions();
  setupToolsActions();
  setupWindowActions();
  setupHelpActions();

  rebuildMenuTree();
}

void MenuManager::registerMenuItem(const QString &menuPath,
                                   const XylaActionData &action) {
  m_actionManager->registerAction(action);
  m_menuStructure.push_back({menuPath, action.id, false});
}

void MenuManager::registerSeparator(const QString &menuPath) {
  static int separatorCounter = 0;
  QString sepId = QString("sep_%1").arg(++separatorCounter);

  m_menuStructure.push_back({menuPath, sepId, true});
}

void MenuManager::triggerAction(const QString &actionId) {
  if (m_actionManager) {
    m_actionManager->triggerAction(actionId);
  }
}

void MenuManager::updateMenuTreeState() { rebuildMenuTree(); }

void MenuManager::registerSubmenuMeta(const QString &menuPath,
                                      const QString &icon,
                                      const QString &description,
                                      const QString &shortcut, bool enabled) {
  QVariantMap meta;
  meta["icon"] = icon;
  meta["description"] = description;
  meta["shortcut"] = shortcut;
  meta["enabled"] = enabled;
  m_submenuMeta[menuPath] = meta;
}

void MenuManager::rebuildMenuTree() {
  struct MenuEntry {
    bool isSubmenu{false};
    QString key;
    QVariantMap item;
  };

  struct MenuNode {
    QString title;
    QString fullPath;
    QMap<QString, MenuNode> submenus;
    QList<MenuEntry> entries;
  };

  QMap<QString, MenuNode> rootMenus;
  QList<QString> rootOrder;

  auto ensureSubmenuEntry = [](MenuNode &node, const QString &token) {
    for (const auto &e : node.entries) {
      if (e.isSubmenu && e.key == token)
        return;
    }
    MenuEntry entry;
    entry.isSubmenu = true;
    entry.key = token;
    node.entries.append(entry);
  };

  auto firstLeafMeta = [](const MenuNode &node) -> QVariantMap {
    for (const auto &entry : node.entries) {
      if (entry.isSubmenu)
        continue;
      const QVariantMap item = entry.item;
      if (item.value("isSeparator").toBool())
        continue;

      QVariantMap meta;
      meta["icon"] = item.value("icon").toString();
      meta["description"] = item.value("description").toString();
      meta["shortcut"] = "";
      meta["enabled"] =
          item.contains("enabled") ? item.value("enabled").toBool() : true;
      return meta;
    }
    return {};
  };

  for (const auto &item : m_menuStructure) {
    QStringList pathTokens = item.menuPath.split('/', Qt::SkipEmptyParts);
    if (pathTokens.isEmpty())
      continue;

    const QString rootName = pathTokens.first();
    if (!rootMenus.contains(rootName)) {
      MenuNode rootNode;
      rootNode.title = rootName;
      rootNode.fullPath = rootName;
      rootMenus.insert(rootName, rootNode);
      rootOrder.append(rootName);
    }

    MenuNode *currentNode = &rootMenus[rootName];
    QString currentPath = rootName;

    for (int i = 1; i < pathTokens.size(); ++i) {
      const QString token = pathTokens[i];
      currentPath += "/" + token;

      if (!currentNode->submenus.contains(token)) {
        MenuNode subNode;
        subNode.title = token;
        subNode.fullPath = currentPath;
        currentNode->submenus.insert(token, subNode);
      }

      ensureSubmenuEntry(*currentNode, token);
      currentNode = &currentNode->submenus[token];
    }

    QVariantMap itemMap;
    itemMap["isSeparator"] = item.isSeparator;
    itemMap["isSubmenu"] = false;

    if (item.isSeparator) {
      itemMap["id"] = item.actionId;
    } else {
      const QVariantMap actionMap = m_actionManager->getAction(item.actionId);
      const QVariantMap tooltip = actionMap.value("tooltip").toMap();

      itemMap["id"] = item.actionId;
      itemMap["title"] = tooltip.value("title").toString();
      itemMap["description"] = tooltip.value("description").toString();
      itemMap["docsUrl"] = tooltip.value("docsUrl").toString();
      itemMap["shortcut"] = actionMap.value("currentShortcut").toString();
      itemMap["icon"] = actionMap.value("icon").toString();
      itemMap["enabled"] = actionMap.value("enabled").toBool();
    }

    MenuEntry actionEntry;
    actionEntry.isSubmenu = false;
    actionEntry.item = std::move(itemMap);
    currentNode->entries.append(std::move(actionEntry));
  }

  std::function<QVariantMap(const MenuNode &)> serializeNode =
      [&](const MenuNode &node) -> QVariantMap {
    QVariantMap result;
    result["title"] = node.title;

    QVariantList itemsList;
    for (const auto &entry : node.entries) {
      if (!entry.isSubmenu) {
        itemsList.append(entry.item);
        continue;
      }

      const QString &subName = entry.key;
      if (!node.submenus.contains(subName))
        continue;

      const MenuNode &childNode = node.submenus[subName];

      QVariantMap submenuItem;
      submenuItem["isSubmenu"] = true;
      submenuItem["isSeparator"] = false;
      submenuItem["id"] = QString("submenu_%1").arg(subName);
      submenuItem["title"] = subName;

      QVariantMap meta = m_submenuMeta.value(childNode.fullPath);
      if (meta.isEmpty())
        meta = firstLeafMeta(childNode);

      submenuItem["icon"] = meta.value("icon").toString();
      submenuItem["description"] = meta.value("description").toString();
      submenuItem["shortcut"] = meta.value("shortcut").toString();
      submenuItem["enabled"] =
          meta.contains("enabled") ? meta.value("enabled").toBool() : true;

      const QVariantMap childData = serializeNode(childNode);
      submenuItem["items"] = childData.value("items");

      itemsList.append(std::move(submenuItem));
    }

    result["items"] = std::move(itemsList);
    return result;
  };

  QVariantList tree;
  for (const QString &rootName : rootOrder) {
    tree.append(serializeNode(rootMenus[rootName]));
  }

  m_cachedMenuTree = std::move(tree);
  emit menuTreeChanged();
}

} // namespace xyla
