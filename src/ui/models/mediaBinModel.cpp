#include "ui/models/mediaBinModel.hpp"
#include "core/log/logger.hpp"
#include "project/projectManager.hpp"
#include "core/settings/settingsManager.hpp"
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QUuid>
#include <algorithm>
#include <functional>

namespace xyla {

static QString tagToColor(AssetTag tag) {
  switch (tag) {
  case AssetTag::Red:     return QStringLiteral("#FF0000"); // ("#ef4444");
  case AssetTag::Orange:  return QStringLiteral("#FF9800"); // ("#f97316");
  case AssetTag::Yellow:  return QStringLiteral("#FFFF00"); // ("#eab308");
  case AssetTag::Green:   return QStringLiteral("#00FF00"); // ("#22c55e");
  case AssetTag::Cyan:    return QStringLiteral("#06b6d4");
  case AssetTag::Blue:    return QStringLiteral("#0000FF"); // ("#3b82f6");
  case AssetTag::Purple:  return QStringLiteral("#F000FF"); // ("#a855f7");
  case AssetTag::Pink:    return QStringLiteral("#FF0088"); // ("#ec4899");
  case AssetTag::White:   return QStringLiteral("#FFFFFF");
  case AssetTag::None:
  default:
    return QStringLiteral("transparent");
  }
}

MediaBinModel::MediaBinModel(MediaPool *pool, QObject *parent)
    : QAbstractListModel(parent), m_pool(pool) {

  m_mediaPanelSettings = new MediaPanelSettings(this);

  m_treeMode = (m_mediaPanelSettings->defaultView().compare(
                    "list", Qt::CaseInsensitive) == 0);
  if (m_mediaPanelSettings->sortMode().compare("Duration",
                                               Qt::CaseInsensitive) == 0) {
    m_sortRole = DurationRole;
  } else if (m_mediaPanelSettings->sortMode().compare(
                 "Path", Qt::CaseInsensitive) == 0) {
    m_sortRole = PathRole;
  } else {
    m_sortRole = NameRole;
  }

  if (m_pool) {
    // 1. Clear model when a new project loads
    connect(m_pool, &MediaPool::projectReloading, this, [this]() {
      beginResetModel();
      m_allItems.clear();
      m_visibleItems.clear();
      m_expandedFolderIds.clear();
      endResetModel();
    });

    // 2. Restore folders and auto-expand them so their children are visible
    connect(m_pool, &MediaPool::folderImported, this,
            [this](const QString &id, const QString &name, const QString &parentBinId) {
              BinItem folder;
              folder.id = id;
              folder.name = name;
              folder.parentBinId = parentBinId;
              folder.isFolder = true;
              m_allItems.push_back(folder);
              m_expandedFolderIds.insert(id); // Keep folders expanded on load
              rebuildVisibleItems();
            });

    // 3. THIS WAS MISSING: Connect assetImported to onAssetImported!
    connect(m_pool, &MediaPool::assetImported, this, &MediaBinModel::onAssetImported);
  }
}

void MediaBinModel::registerActions(xyla::XylaActionManager *actionMgr) {
  if (!actionMgr) {
    return;
  }

  actionMgr->registerAction(
      {"assetmanager.rename",
       {"Rename", "Rename the selected asset",
        "Starts inline rename on the current selection",
        "https://docs.xyla.dev/assetmanager/organization#rename"},
       "qrc:/assets/icons/rename.svg",
       true,
       [this]() { emit renameRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.duplicate",
       {"Duplicate", "Duplicate the selected asset(s)",
        "Duplicates each selected item, keeping copies in their original bin",
        "https://docs.xyla.dev/assetmanager/organization#duplicate"},
       "qrc:/assets/icons/duplicate.svg",
       true,
       [this]() { emit duplicateRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.newfolder",
       {"Add New Folder", "Create a new folder in the media bin",
        "Adds a new folder under the current bin, or inside the selected "
        "folder in tree mode",
        "https://docs.xyla.dev/assetmanager/organization#newfolder"},
       "qrc:/assets/icons/new-folder.svg",
       true,
       [this]() { emit newFolderRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.selectall",
       {"Select All", "Select all visible items",
        "Selects every item currently visible in the media bin",
        "https://docs.xyla.dev/assetmanager/organization#selectall"},
       "qrc:/assets/icons/select-all.svg",
       true,
       [this]() { emit selectAllRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.import",
       {"Import Asset", "Import files into the media bin",
        "Opens the file dialog and imports the chosen files into the "
        "current bin",
        "https://docs.xyla.dev/assetmanager/organization#import"},
       "qrc:/assets/icons/import.svg",
       true,
       [this]() { emit importRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.copy",
       {"Copy Asset", "Copy the selected asset(s)",
        "Copies the current selection to the internal clipboard",
        "https://docs.xyla.dev/assetmanager/organization#copy"},
       "qrc:/assets/icons/copy.svg",
       true,
       [this]() { emit copyRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.cut",
       {"Cut Asset", "Cut the selected asset(s)",
        "Marks the current selection for move on next paste",
        "https://docs.xyla.dev/assetmanager/organization#cut"},
       "qrc:/assets/icons/cut.svg",
       true,
       [this]() { emit cutRequested(); }});

  actionMgr->registerAction(
      {"assetmanager.paste",
       {"Paste Asset", "Paste the clipboard contents",
        "Copies or moves clipboard items into the current bin",
        "https://docs.xyla.dev/assetmanager/organization#paste"},
       "qrc:/assets/icons/paste.svg",
       true,
       [this]() { emit pasteRequested(); }});
}

void MediaBinModel::markDirty() {
  if (m_projectManager) {
    m_projectManager->setHasUnsavedChanges(true);
  }
}

MediaPanelSettings::MediaPanelSettings(QObject *parent) : QObject(parent) {
  applyDefaults();
  loadSettings();
}

void MediaPanelSettings::setDefaultView(const QString &v) {
  const QString value = v.trimmed();

  if (value.isEmpty() || m_defaultView == value)
    return;

  m_defaultView = value;

  emit defaultViewChanged();
  saveSettings();
}

void MediaPanelSettings::setShowFileExtensions(bool v) {
  if (m_showFileExtensions == v)
    return;

  m_showFileExtensions = v;

  emit showFileExtensionsChanged();
  saveSettings();
}

void MediaPanelSettings::setSortMode(const QString &v) {
  const QString value = v.trimmed();

  if (value.isEmpty() || m_sortMode == value)
    return;

  m_sortMode = value;

  emit sortModeChanged();
  saveSettings();
}

void MediaPanelSettings::setShowTooltips(bool v) {
  if (m_showTooltips == v)
    return;

  m_showTooltips = v;

  emit showTooltipsChanged();
  saveSettings();
}

void MediaPanelSettings::setHoverScrub(bool v) {
  if (m_hoverScrub == v)
    return;

  m_hoverScrub = v;

  emit hoverScrubChanged();
  saveSettings();
}

void MediaPanelSettings::setShowWaveforms(bool v) {
  if (m_showWaveforms == v)
    return;

  m_showWaveforms = v;

  emit showWaveformsChanged();
  saveSettings();
}

void MediaPanelSettings::applyDefaults() {
  m_defaultView = QStringLiteral("grid");
  m_showFileExtensions = true;
  m_sortMode = QStringLiteral("Name");
  m_showTooltips = true;
  m_hoverScrub = false;
  m_showWaveforms = false;
}

void MediaPanelSettings::loadSettings() {
  if (g_settingsManager) {
    const auto &data = g_settingsManager->data();
    m_defaultView = data.mediaPanelDefaultView;
    m_hoverScrub = data.mediaPanelHoverScrub;
    m_showWaveforms = data.mediaPanelShowWaveforms;
    m_showFileExtensions = data.mediaPanelShowFileExtensions;
    m_sortMode = data.mediaPanelSortMode;
    m_showTooltips = data.mediaPanelShowTooltips;
  } else {
    applyDefaults();
  }

  emit defaultViewChanged();
  emit showFileExtensionsChanged();
  emit sortModeChanged();
  emit showTooltipsChanged();
  emit showWaveformsChanged();
  emit hoverScrubChanged();
}

void MediaPanelSettings::saveSettings() const {
  if (!g_settingsManager)
    return;

  auto data = g_settingsManager->data();
  data.mediaPanelDefaultView = m_defaultView;
  data.mediaPanelShowFileExtensions = m_showFileExtensions;
  data.mediaPanelSortMode = m_sortMode;
  data.mediaPanelShowTooltips = m_showTooltips;
  data.mediaPanelShowWaveforms = m_showWaveforms;
  data.mediaPanelHoverScrub = m_hoverScrub;

  g_settingsManager->updateData(data);
}

int MediaBinModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) {
    return 0;
  }
  return static_cast<int>(m_visibleItems.size());
}

QVariant MediaBinModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= static_cast<int>(m_visibleItems.size())) {
    return {};
  }

  const auto &vItem = m_visibleItems[static_cast<size_t>(index.row())];
  if (vItem.allItemIndex >= m_allItems.size()) {
    return {};
  }

  const auto &item = m_allItems[vItem.allItemIndex];

  switch (role) {
  case IdRole:
    return item.id;
  case NameRole:
    return item.name;
  case PathRole:
    return item.path;
  // case DurationRole:
  //   return item.isFolder ? ""
  //                        : (QString::number(item.durationSec, 'f', 1) + "s");
  case DurationRole: {
    if (item.isFolder || item.durationSec <= 0.001)
        return QString();
    int totalSec = static_cast<int>(std::round(item.durationSec));
    int hours = totalSec / 3600;
    int minutes = (totalSec % 3600) / 60;
    int seconds = totalSec % 60;
    if (hours > 0)
        return QString("%1:%2:%3")
            .arg(hours, 2, 10, QChar('0'))
            .arg(minutes, 2, 10, QChar('0'))
            .arg(seconds, 2, 10, QChar('0'));
    return QString("%1:%2")
        .arg(minutes, 2, 10, QChar('0'))
        .arg(seconds, 2, 10, QChar('0'));
}
  case ResolutionRole:
    return item.resolution;
  case IsFolderRole:
    return item.isFolder;
  case ParentBinIdRole:
    return item.parentBinId;
  case DepthRole:
    return vItem.depth;
  case IsExpandedRole:
    return vItem.isExpanded;
  case HasChildrenRole:
    return vItem.hasChildren;
  case IsLastChildRole:
    return vItem.isLastChild;
  case AncestorMaskRole:
    return vItem.ancestorMask;
  case HasVideoRole:
    return item.hasVideo;
  case HasAudioRole:
    return item.hasAudio;
  case TagRole:
    return static_cast<int>(item.tag);
  case TagColorRole:
    return tagToColor(item.tag);
  default:
    return {};
  }
}

QHash<int, QByteArray> MediaBinModel::roleNames() const {
  return {{IdRole, "id"},
          {NameRole, "name"},
          {PathRole, "path"},
          {DurationRole, "duration"},
          {ResolutionRole, "resolution"},
          {IsFolderRole, "isFolder"},
          {ParentBinIdRole, "parentBinId"},
          {DepthRole, "depth"},
          {IsExpandedRole, "isExpanded"},
          {HasChildrenRole, "hasChildren"},
          {IsLastChildRole, "isLastChild"},
          {AncestorMaskRole, "ancestorMask"},
          {HasAudioRole, "hasAudio"},
          {HasVideoRole, "hasVideo"},
          {TagRole, "tag"},
          {TagColorRole, "tagColor"},
  };
}

QString MediaBinModel::currentBinName() const {
  if (m_currentBinId == "root" || m_currentBinId.isEmpty()) {
    return QStringLiteral("Master");
  }
  for (const auto &item : m_allItems) {
    if (item.id == m_currentBinId && item.isFolder) {
      return item.name;
    }
  }
  return m_currentBinId;
}

QString MediaBinModel::parentBinId() const {
  if (m_currentBinId == "root" || m_currentBinId.isEmpty()) {
    return QStringLiteral("root");
  }
  for (const auto &item : m_allItems) {
    if (item.id == m_currentBinId && item.isFolder) {
      return item.parentBinId.isEmpty() ? QStringLiteral("root")
                                        : item.parentBinId;
    }
  }
  return QStringLiteral("root");
}

void MediaBinModel::resetVisibleItems() {
  beginResetModel();
  m_visibleItems = computeVisibleItems();
  endResetModel();
}

void MediaBinModel::setTreeMode(bool enabled) {
  if (m_treeMode == enabled)
    return;
  m_treeMode = enabled;
  emit treeModeChanged();
  resetVisibleItems();   // was rebuildVisibleItems()
}

bool MediaBinModel::isFolderExpanded(const QString &folderId) const {
  return m_expandedFolderIds.contains(folderId);
}

void MediaBinModel::expandAll() {
  for (const auto &item : m_allItems) {
    if (item.isFolder) {
      m_expandedFolderIds.insert(item.id);
    }
  }
  rebuildVisibleItems();
}

void MediaBinModel::collapseAll() {
  m_expandedFolderIds.clear();
  rebuildVisibleItems();
}

void MediaBinModel::setSearchFilter(const QString &filter) {
  if (m_searchFilter == filter)
    return;
  m_searchFilter = filter;
  emit searchFilterChanged();
  resetVisibleItems();
}

void MediaBinModel::setSortRole(int role) {
  int targetRole = NameRole;
  if (role == 1) {
    targetRole = DurationRole;
  } else if (role == 2) {
    targetRole = PathRole;
  } else if (role > 2) {
    targetRole = role;
  }

  if (m_sortRole == targetRole)
    return;
  m_sortRole = targetRole;
  emit sortRoleChanged();
  resetVisibleItems();
}

void MediaBinModel::setSortAscending(bool ascending) {
  if (m_sortAscending == ascending)
    return;
  m_sortAscending = ascending;
  emit sortAscendingChanged();
  resetVisibleItems();
}

void MediaBinModel::setCurrentBinId(const QString &binId) {
  const QString target = binId.isEmpty() ? QStringLiteral("root") : binId;
  if (m_currentBinId == target)
    return;
  m_currentBinId = target;
  emit currentBinIdChanged();
  resetVisibleItems();
}

void MediaBinModel::goToParentBin() {
  if (m_currentBinId == "root" || m_currentBinId.isEmpty())
    return;
  setCurrentBinId(parentBinId());
}

QString MediaBinModel::generateUniqueName(const QString &originalName,
                                          bool isFolder,
                                          const QString &targetBinId) const {
  QString baseStem;
  QString ext;

  if (isFolder) {
    static const QRegularExpression folderRegex(R"(^(.*?)(?:\s*\((\d+)\))?$)");
    QRegularExpressionMatch match = folderRegex.match(originalName);
    if (match.hasMatch() && !match.captured(1).trimmed().isEmpty()) {
      baseStem = match.captured(1).trimmed();
    } else {
      baseStem = originalName.trimmed();
    }
  } else {
    int lastDot = originalName.lastIndexOf(QLatin1Char('.'));
    QString rawStem = (lastDot > 0) ? originalName.left(lastDot) : originalName;
    ext = (lastDot > 0) ? originalName.mid(lastDot + 1) : QString();

    static const QRegularExpression fileRegex(R"(^(.*?)(?:\s*\((\d+)\))?$)");
    QRegularExpressionMatch match = fileRegex.match(rawStem);
    if (match.hasMatch() && !match.captured(1).trimmed().isEmpty()) {
      baseStem = match.captured(1).trimmed();
    } else {
      baseStem = rawStem.trimmed();
    }
  }

  int count = 1;
  while (true) {
    QString candidate;
    if (isFolder || ext.isEmpty()) {
      candidate = QStringLiteral("%1 (%2)").arg(baseStem).arg(count);
    } else {
      candidate =
          QStringLiteral("%1 (%2).%3").arg(baseStem).arg(count).arg(ext);
    }

    bool exists = false;
    for (const auto &item : m_allItems) {
      if (item.parentBinId == targetBinId &&
          item.name.compare(candidate, Qt::CaseInsensitive) == 0) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      return candidate;
    }
    ++count;
  }
}

int MediaBinModel::createFolder(const QString &folderName,
                                const QString &parentBin) {
  const QString targetBin =
      parentBin.isEmpty()
          ? (m_treeMode ? QStringLiteral("root") : m_currentBinId)
          : parentBin;

  QString initialName = folderName.trimmed().isEmpty()
                            ? QStringLiteral("New Folder")
                            : folderName.trimmed();
  QString name = initialName;

  bool exists = false;
  for (const auto &it : m_allItems) {
    if (it.parentBinId == targetBin && it.isFolder &&
        it.name.compare(name, Qt::CaseInsensitive) == 0) {
      exists = true;
      break;
    }
  }

  if (exists) {
    name = generateUniqueName(initialName, true, targetBin);
  }

  BinItem item;
  item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
  item.name = name;
  item.isFolder = true;
  item.parentBinId = targetBin;

  m_allItems.push_back(item);

  if (m_pool) {
    m_pool->addFolder(item.id, item.name, item.parentBinId);
  }

  // Automatically expand parent folder so the new child is visible immediately
  // in the tree
  if (targetBin != "root") {
    m_expandedFolderIds.insert(targetBin);
  }

  // Rebuild visible items so it is placed in exact sorted tree hierarchy under
  // its parent
  rebuildVisibleItems();

  emit itemsAdded({item.id});

  // Return the exact visual row in m_visibleItems
  for (size_t i = 0; i < m_visibleItems.size(); ++i) {
    if (m_allItems[m_visibleItems[i].allItemIndex].id == item.id) {
      return static_cast<int>(i);
    }
  }

  return -1;
}

void MediaBinModel::removeAsset(int index) {
  if (index < 0 || index >= static_cast<int>(m_visibleItems.size()))
    return;
  size_t actualIdx = m_visibleItems[static_cast<size_t>(index)].allItemIndex;
  if (actualIdx < m_allItems.size()) {
    removeAssetsById({m_allItems[actualIdx].id});
  }
}

void MediaBinModel::renameAsset(int visualIndex, const QString &newName) {
  if (visualIndex < 0 || visualIndex >= static_cast<int>(m_visibleItems.size()))
    return;

  size_t allIdx = m_visibleItems[visualIndex].allItemIndex;
  if (allIdx < m_allItems.size()) {
    renameAssetById(m_allItems[allIdx].id, newName);
  }
}

void MediaBinModel::renameAssetById(const QString &assetId,
                                    const QString &newName) {
  const QString trimmed = newName.trimmed();
  if (trimmed.isEmpty())
    return;

  bool found = false;
  for (auto &item : m_allItems) {
    if (item.id == assetId) {
      item.name = trimmed;
      found = true;
      if (m_pool) {
        if (item.isFolder) m_pool->renameFolder(assetId, trimmed);
        else m_pool->renameAsset(assetId, trimmed);
      }
      break;
    }
  }
  if (!found)
    return;

  rebuildVisibleItems();

  // A rename can leave a row's position (and therefore its diffed
  // metadata) untouched while its content changes — the diff won't
  // catch that, so say so explicitly.
  for (size_t i = 0; i < m_visibleItems.size(); ++i) {
    if (m_allItems[m_visibleItems[i].allItemIndex].id == assetId) {
      QModelIndex idx = index(static_cast<int>(i));
      emit dataChanged(idx, idx, {NameRole});
      break;
    }
  }

  emit itemRenamed(assetId);
}

void MediaBinModel::removeAssetsById(const QStringList &assetIds) {
  if (assetIds.isEmpty())
    return;

  // 1. Collect all targeted IDs AND all recursive descendants (subfolders and files)
  QSet<QString> allIdsToRemove(assetIds.begin(), assetIds.end());

  bool addedMore = true;
  while (addedMore) {
    addedMore = false;
    for (const auto &item : m_allItems) {
      if (allIdsToRemove.contains(item.parentBinId) &&
          !allIdsToRemove.contains(item.id)) {
        allIdsToRemove.insert(item.id);
        addedMore = true; // Keep looping until all levels of sub-children are caught
      }
    }
  }

  // 2. Erase from MediaPool so decoders, waveforms, and pool memory are wiped
  if (m_pool) {
    for (const QString &id : allIdsToRemove) {
      m_pool->removeFolder(id); // Deletes from m_folders
      m_pool->removeAsset(id);  // Deletes from m_assets, decoders, waveforms
    }
  }

  // 3. Clean up expanded folder state
  for (const QString &id : allIdsToRemove) {
    m_expandedFolderIds.remove(id);
  }

  // 4. Remove all collected items from the UI model
  m_allItems.erase(
      std::remove_if(m_allItems.begin(), m_allItems.end(),
                     [&allIdsToRemove](const BinItem &item) {
                       return allIdsToRemove.contains(item.id);
                     }),
      m_allItems.end());

  rebuildVisibleItems();

  // XYLA_LOG_INFO("MediaBinModel",
  //               QString("Recursively removed %1 items from bin.")
  //                   .arg(allIdsToRemove.size())
  //                   .toStdString()
  //                   .c_str());
}

QString MediaBinModel::duplicateItemRecursive(const QString &itemId,
                                              const QString &targetBinId) {
  // Find original item
  auto it = std::find_if(m_allItems.begin(), m_allItems.end(),
                         [&](const BinItem &b) { return b.id == itemId; });
  if (it == m_allItems.end())
    return {};

  BinItem original = *it;
  BinItem newItem = original;
  newItem.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
  newItem.parentBinId = targetBinId;
  newItem.name = generateUniqueName(original.name, original.isFolder, targetBinId);

  m_allItems.push_back(newItem);

  // ---> NOTIFY MEDIAPOOL SO IT GETS SAVED! <---
  if (m_pool) {
    if (newItem.isFolder) {
      m_pool->addFolder(newItem.id, newItem.name, newItem.parentBinId);
    } else {
      // Pass newItem.name so MediaPool receives the "(1)" name!
      m_pool->duplicateAsset(original.id, newItem.id, newItem.name, newItem.parentBinId);
    }
  }

  // If it's a folder, duplicate all its children recursively
  if (original.isFolder) {
    for (const auto &child : m_allItems) {
      if (child.parentBinId == original.id) {
        duplicateItemRecursive(child.id, newItem.id);
      }
    }
  }

  return newItem.id;
}

void MediaBinModel::toggleFolderExpanded(const QString &folderId) {
  if (folderId.isEmpty())
    return;

  bool willExpand = !m_expandedFolderIds.contains(folderId);
  setFolderExpanded(folderId, willExpand);
}

void MediaBinModel::setFolderExpanded(const QString &folderId, bool expanded) {
  if (folderId.isEmpty())
    return;

  if (m_expandedFolderIds.contains(folderId) == expanded)
    return;

  if (m_treeMode && m_searchFilter.trimmed().isEmpty()) {
    if (expanded) {
      expandFolderIncremental(folderId);
    } else {
      collapseFolderIncremental(folderId);
    }
  } else {
    if (expanded) {
      m_expandedFolderIds.insert(folderId);
    } else {
      m_expandedFolderIds.remove(folderId);
    }
    rebuildVisibleItems();
  }
}

QVariantList MediaBinModel::getFolderContents(const QString &folderId,
                                              bool recursive) const {
  QVariantList result;
  if (folderId.isEmpty())
    return result;

  // Helper lambda to collect child items
  std::function<void(const QString &)> collect = [&](const QString &parentId) {
    for (const auto &item : m_allItems) {
      if (item.parentBinId == parentId) {
        QVariantMap map;
        map[QStringLiteral("id")] = item.id;
        map[QStringLiteral("name")] = item.name;
        map[QStringLiteral("isFolder")] = item.isFolder;
        map[QStringLiteral("path")] = item.path;
        // map[QStringLiteral("type")] = item.type;
        map[QStringLiteral("parentBinId")] = item.parentBinId;
        result.append(map);

        if (recursive && item.isFolder) {
          collect(item.id);
        }
      }
    }
  };

  collect(folderId);
  return result;
}

void MediaBinModel::duplicateAssetsById(const QStringList &assetIds,
                                        const QString &targetBinId) {
  if (assetIds.isEmpty())
    return;
  const QString dest =
      targetBinId.isEmpty()
          ? (m_treeMode ? QStringLiteral("root") : m_currentBinId)
          : targetBinId;

  QStringList createdIds;
  for (const QString &id : assetIds) {
    QString newId = duplicateItemRecursive(id, dest);
    if (!newId.isEmpty()) {
      createdIds.append(newId);
    }
  }
  rebuildVisibleItems();

  if (!createdIds.isEmpty()) {
    emit itemsAdded(createdIds);
  }
}

void MediaBinModel::groupByMediaType() {
  const QString targetBin =
      m_treeMode ? QStringLiteral("root") : m_currentBinId;

  QString videoFolderId, audioFolderId, imagesFolderId;

  for (const auto &it : m_allItems) {
    if (it.parentBinId == targetBin && it.isFolder) {
      if (it.name.compare("Video", Qt::CaseInsensitive) == 0)
        videoFolderId = it.id;
      else if (it.name.compare("Audio", Qt::CaseInsensitive) == 0)
        audioFolderId = it.id;
      else if (it.name.compare("Images", Qt::CaseInsensitive) == 0)
        imagesFolderId = it.id;
    }
  }

  auto ensureFolder = [this, &targetBin](const QString &name,
                                         QString &folderId) {
    if (folderId.isEmpty()) {
      BinItem f;
      f.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
      f.name = name;
      f.isFolder = true;
      f.parentBinId = targetBin;
      m_allItems.push_back(f);
      folderId = f.id;
      m_expandedFolderIds.insert(f.id);
    }
  };

  const QSet<QString> videoExts = {"mp4", "mov", "mkv",  "avi", "webm", "m4v",
                                   "flv", "wmv", "m2ts", "ts",  "mts"};
  const QSet<QString> audioExts = {"mp3", "wav", "aac",  "flac", "ogg",
                                   "m4a", "wma", "aiff", "alac"};
  const QSet<QString> imageExts = {"png", "jpg", "jpeg", "webp", "bmp",
                                   "svg", "gif", "tiff", "tif",  "tga"};

  bool createdAny = false;

  for (size_t i = 0; i < m_allItems.size(); ++i) {
    if (m_allItems[i].parentBinId == targetBin && !m_allItems[i].isFolder) {
      QString ext = QFileInfo(m_allItems[i].path).suffix().toLower();
      if (ext.isEmpty()) {
        ext = QFileInfo(m_allItems[i].name).suffix().toLower();
      }

      if (videoExts.contains(ext) || !m_allItems[i].resolution.isEmpty()) {
        ensureFolder(QStringLiteral("Video"), videoFolderId);
        m_allItems[i].parentBinId = videoFolderId;
        createdAny = true;
      } else if (audioExts.contains(ext)) {
        ensureFolder(QStringLiteral("Audio"), audioFolderId);
        m_allItems[i].parentBinId = audioFolderId;
        createdAny = true;
      } else if (imageExts.contains(ext)) {
        ensureFolder(QStringLiteral("Images"), imagesFolderId);
        m_allItems[i].parentBinId = imagesFolderId;
        createdAny = true;
      }
    }
  }

  if (createdAny) {
    resetVisibleItems();
  }
}

void MediaBinModel::onAssetImported(const QString &binId,
                                    std::shared_ptr<MediaAsset> asset) {
  if (!asset)
    return;

  BinItem item;
  item.id = asset->id();
  item.name = asset->name();
  item.path = asset->metadata().filePath;
  item.durationSec = asset->metadata().durationSeconds;

  item.hasVideo = !asset->metadata().videoStreams.empty();
  item.hasAudio = !asset->metadata().audioStreams.empty();

  item.isFolder = false;
  item.parentBinId = binId.isEmpty() ? QStringLiteral("root") : binId;

  QFileInfo fi(item.path);
  if (fi.exists()) {
    item.fileSizeBytes = fi.size();
  }

  if (!asset->metadata().videoStreams.empty()) {
    const auto &vs = asset->metadata().videoStreams[0];
    item.resolution = QString("%1x%2").arg(vs.width).arg(vs.height);
  }

  // Also register with pool so the pool knows this asset's current folder!
  if (m_pool) {
    m_pool->setAssetBin(item.id, item.parentBinId);
    item.tag = static_cast<AssetTag>(m_pool->getAssetTag(item.id));
  }

  m_allItems.push_back(item);
  rebuildVisibleItems();

  emit itemsAdded({item.id});

  // XYLA_LOG_INFO(
  //     "MediaBinModel",
  //     QString("Added item to model: %1").arg(item.name).toStdString().c_str());
}

void MediaBinModel::collectSubtreeVisibleItems(
    const QString &folderId, int depth, int currentMask,
    std::vector<VisibleBinItem> &out) const {
  std::vector<size_t> levelIndices;
  for (size_t i = 0; i < m_allItems.size(); ++i) {
    if (m_allItems[i].parentBinId == folderId) {
      levelIndices.push_back(i);
    }
  }

  std::sort(levelIndices.begin(), levelIndices.end(),
            [this](size_t a, size_t b) { return lessThan(a, b); });

  for (size_t i = 0; i < levelIndices.size(); ++i) {
    size_t idx = levelIndices[i];
    const auto &item = m_allItems[idx];
    bool isLast = (i == levelIndices.size() - 1);
    bool hasChildren = false;

    if (item.isFolder) {
      for (const auto &child : m_allItems) {
        if (child.parentBinId == item.id) {
          hasChildren = true;
          break;
        }
      }
    }

    bool isExpanded = item.isFolder && m_expandedFolderIds.contains(item.id);
    out.push_back({idx, depth, isExpanded, hasChildren, isLast, currentMask});

    if (isExpanded) {
      int nextMask = currentMask;
      if (!isLast) {
        nextMask |= (1 << (depth - 1));
      }
      collectSubtreeVisibleItems(item.id, depth + 1, nextMask, out);
    }
  }
}

void MediaBinModel::expandFolderIncremental(const QString &folderId) {
  if (folderId.isEmpty())
    return;

  int folderRow = -1;
  for (size_t i = 0; i < m_visibleItems.size(); ++i) {
    if (m_allItems[m_visibleItems[i].allItemIndex].id == folderId) {
      folderRow = static_cast<int>(i);
      break;
    }
  }

  if (folderRow == -1)
    return;

  m_expandedFolderIds.insert(folderId);
  m_visibleItems[static_cast<size_t>(folderRow)].isExpanded = true;

  // 1. Collect all visible children to insert below this folder
  std::vector<VisibleBinItem> toInsert;
  int depth = m_visibleItems[static_cast<size_t>(folderRow)].depth + 1;
  int parentMask = m_visibleItems[static_cast<size_t>(folderRow)].ancestorMask;
  if (!m_visibleItems[static_cast<size_t>(folderRow)].isLastChild &&
      m_visibleItems[static_cast<size_t>(folderRow)].depth > 0) {
    parentMask |=
        (1 << (m_visibleItems[static_cast<size_t>(folderRow)].depth - 1));
  }

  collectSubtreeVisibleItems(folderId, depth, parentMask, toInsert);

  // 2. Insert items and collect their IDs
  QStringList insertedIds;
  if (!toInsert.empty()) {
    int insertFirst = folderRow + 1;
    int insertLast = folderRow + static_cast<int>(toInsert.size());

    for (const auto &v : toInsert) {
      insertedIds.append(m_allItems[v.allItemIndex].id);
    }

    beginInsertRows(QModelIndex(), insertFirst, insertLast);
    m_visibleItems.insert(m_visibleItems.begin() + insertFirst,
                          toInsert.begin(), toInsert.end());
    endInsertRows();
  }

  // 3. Notify folder delegate for chevron rotation
  QModelIndex idx = index(folderRow);
  emit dataChanged(idx, idx, {IsExpandedRole});

  // 4. Emit signal to trigger cascade animation on newly revealed children
  if (!insertedIds.isEmpty()) {
    emit folderExpanded(insertedIds);
  }
}

void MediaBinModel::collapseFolderIncremental(const QString &folderId) {
  int folderRow = -1;
  for (size_t i = 0; i < m_visibleItems.size(); ++i) {
    if (m_allItems[m_visibleItems[i].allItemIndex].id == folderId) {
      folderRow = static_cast<int>(i);
      break;
    }
  }

  if (folderRow == -1)
    return;

  m_expandedFolderIds.remove(folderId);
  m_visibleItems[static_cast<size_t>(folderRow)].isExpanded = false;

  // 1. Notify the folder delegate so the chevron animates in place
  QModelIndex idx = index(folderRow);
  emit dataChanged(idx, idx, {IsExpandedRole});

  // 2. Determine how many visible descendants to remove
  int parentDepth = m_visibleItems[static_cast<size_t>(folderRow)].depth;
  size_t removeCount = 0;
  for (size_t i = static_cast<size_t>(folderRow) + 1; i < m_visibleItems.size();
       ++i) {
    if (m_visibleItems[i].depth > parentDepth) {
      ++removeCount;
    } else {
      break;
    }
  }

  if (removeCount == 0)
    return;

  int removeFirst = folderRow + 1;
  int removeLast = folderRow + static_cast<int>(removeCount);

  beginRemoveRows(QModelIndex(), removeFirst, removeLast);
  m_visibleItems.erase(m_visibleItems.begin() + removeFirst,
                       m_visibleItems.begin() + removeLast + 1);
  endRemoveRows();
}

std::vector<VisibleBinItem> MediaBinModel::computeVisibleItems() const {
  std::vector<VisibleBinItem> result;
  // ... your existing filtering / tree-mode / flat-grid logic, unchanged,
  // except every m_visibleItems.push_back(...) becomes result.push_back(...)
  // and the std::sort calls at the end of the filtering branch sort `result`
  // instead of `m_visibleItems` ...
  //
  //
  //
  //

  // m_visibleItems.clear();

  const QString textQuery = m_searchFilter.trimmed();
  const bool hasText = !textQuery.isEmpty();
  const bool hasTag = (m_tagFilter != 0);
  const bool hasType = (m_typeFilter > 0);
  const bool hasExt = !m_extensionFilter.isEmpty();

  const bool hasMinDuration = (m_minDurationFilter > 0.0);
  const bool hasMaxDuration = (m_maxDurationFilter > 0.0);
  const bool hasDurationFilter = hasMinDuration || hasMaxDuration;

  const bool hasMinSize = (m_minSizeMBFilter > 0.0);
  const bool hasMaxSize = (m_maxSizeMBFilter > 0.0);
  const bool hasSizeFilter = hasMinSize || hasMaxSize;

  constexpr double BYTES_PER_MB = 1024.0 * 1024.0;

  const bool isFiltering = hasText || hasTag || hasType || hasExt ||
                           hasDurationFilter || hasSizeFilter;

  if (isFiltering) {
    for (size_t i = 0; i < m_allItems.size(); ++i) {
      const auto &item = m_allItems[i];

      // 1. Text Search Filter (name or path)
      // 1. Text Search Filter (name or path)
      if (hasText) {
        // If searching only current folder (in grid view), skip items outside current folder
        if (!m_globalSearch && !m_treeMode && item.parentBinId != m_currentBinId) {
          continue;
        }

        if (!item.name.contains(textQuery, Qt::CaseInsensitive) &&
            !item.path.contains(textQuery, Qt::CaseInsensitive)) {
          continue;
        }
      }
      // if (hasText &&
      //     !item.name.contains(textQuery, Qt::CaseInsensitive) &&
      //     !item.path.contains(textQuery, Qt::CaseInsensitive)) {
      //   continue;
      // }

      // 2. Tag Filter
      if (m_tagFilter > 0) {
        // Normal tag filter: show only the selected tag.
        if (static_cast<int>(item.tag) != m_tagFilter)
          continue;
      } else if (m_tagFilter < 0) {
        // No Tag filter: exclude every tagged item.
        // AssetTag::None == 0, so only untagged items remain.
        if (item.tag != AssetTag::None)
          continue;
      }
      // if (hasTag && static_cast<int>(item.tag) != m_tagFilter) {
      //   continue;
      // }

      // 3. Media Type Filter
      if (hasType) {
        auto type = static_cast<MediaTypeFilter>(m_typeFilter);
        bool matchesType = false;
        switch (type) {
        case MediaTypeFilter::Folder:
          matchesType = item.isFolder;
          break;
        case MediaTypeFilter::VideoAll:
          matchesType = !item.isFolder && item.hasVideo;
          break;
        case MediaTypeFilter::VideoWithAudio:
          matchesType = !item.isFolder && item.hasVideo && item.hasAudio;
          break;
        case MediaTypeFilter::VideoOnly:
          matchesType = !item.isFolder && item.hasVideo && !item.hasAudio;
          break;
        case MediaTypeFilter::AudioOnly:
          matchesType = !item.isFolder && !item.hasVideo && item.hasAudio;
          break;
        case MediaTypeFilter::Image: {
          if (!item.isFolder && !item.hasAudio && item.hasVideo && item.durationSec <= 0.04) {
            matchesType = true;
          } else {
            QString ext = QFileInfo(item.path).suffix().toLower();
            matchesType = (ext == "png" || ext == "jpg" || ext == "jpeg" ||
                           ext == "webp" || ext == "bmp" || ext == "tiff" || ext == "svg");
          }
          break;
        }
        case MediaTypeFilter::All:
        default:
          matchesType = true;
          break;
        }
        if (!matchesType)
          continue;
      }

      // 4. Free Min/Max Duration (only applies to files, not folders)
      if (hasDurationFilter) {
        if (item.isFolder)
          continue;

        if (hasMinDuration && item.durationSec < m_minDurationFilter)
          continue;
        if (hasMaxDuration && item.durationSec > m_maxDurationFilter)
          continue;
      }

      // 5. Free Min/Max Size in MB (only applies to files)
      if (hasSizeFilter) {
        if (item.isFolder)
          continue;

        double sizeMB = static_cast<double>(item.fileSizeBytes) / BYTES_PER_MB;
        if (hasMinSize && sizeMB < m_minSizeMBFilter)
          continue;
        if (hasMaxSize && sizeMB > m_maxSizeMBFilter)
          continue;
      }

      // 6. Extension Filter (e.g. "mp4", "wav", "png")
      if (hasExt) {
        if (item.isFolder)
          continue;

        QString ext = QFileInfo(item.path).suffix().toLower();
        if (ext != m_extensionFilter)
          continue;
      }

      result.push_back({i, 0, false, false});
    }

    std::sort(result.begin(), result.end(),
              [this](const VisibleBinItem &a, const VisibleBinItem &b) {
                return lessThan(a.allItemIndex, b.allItemIndex);
              });

  } else if (m_treeMode) {
    // Recursive tree hierarchy in List View
    std::function<void(const QString &, int, int)> addLevel =
        [&](const QString &parentId, int depth, int currentMask) {
          std::vector<size_t> levelIndices;
          for (size_t i = 0; i < m_allItems.size(); ++i) {
            if (m_allItems[i].parentBinId == parentId) {
              levelIndices.push_back(i);
            }
          }

          std::sort(levelIndices.begin(), levelIndices.end(),
                    [this](size_t a, size_t b) { return lessThan(a, b); });

          for (size_t i = 0; i < levelIndices.size(); ++i) {
            size_t idx = levelIndices[i];
            const auto &item = m_allItems[idx];
            bool isLast = (i == levelIndices.size() - 1);
            bool hasChildren = false;
            if (item.isFolder) {
              for (const auto &child : m_allItems) {
                if (child.parentBinId == item.id) {
                  hasChildren = true;
                  break;
                }
              }
            }

            bool isExpanded =
                item.isFolder && m_expandedFolderIds.contains(item.id);
            result.push_back(
                {idx, depth, isExpanded, hasChildren, isLast, currentMask});

            if (isExpanded) {
              int nextMask = currentMask;
              if (!isLast && depth > 0) {
                nextMask |= (1 << (depth - 1));
              }
              addLevel(item.id, depth + 1, nextMask);
            }
          }
        };

    addLevel(QStringLiteral("root"), 0, 0);
  } else {
    // Flat Grid View in currentBinId
    std::vector<size_t> levelIndices;
    for (size_t i = 0; i < m_allItems.size(); ++i) {
      if (m_allItems[i].parentBinId == m_currentBinId) {
        levelIndices.push_back(i);
      }
    }

    std::sort(levelIndices.begin(), levelIndices.end(),
              [this](size_t a, size_t b) { return lessThan(a, b); });

    for (size_t idx : levelIndices) {
      result.push_back({idx, 0, false, false});
    }
  }

  return result;
}

void MediaBinModel::rebuildVisibleItems() {
  applyVisibleItemsDiff(computeVisibleItems());
}

std::vector<int> MediaBinModel::longestIncreasingSubsequenceIndices(
    const std::vector<int> &seq) {
  std::vector<int> tails;
  std::vector<int> prev(seq.size(), -1);

  for (int i = 0; i < static_cast<int>(seq.size()); ++i) {
    if (seq[static_cast<size_t>(i)] < 0) continue;
    auto it = std::lower_bound(
        tails.begin(), tails.end(), seq[static_cast<size_t>(i)],
        [&seq](int a, int b) { return seq[static_cast<size_t>(a)] < b; });
    if (it == tails.end()) {
      if (!tails.empty()) prev[static_cast<size_t>(i)] = tails.back();
      tails.push_back(i);
    } else {
      if (it != tails.begin()) prev[static_cast<size_t>(i)] = *(it - 1);
      *it = i;
    }
  }

  std::vector<int> result;
  if (!tails.empty()) {
    int k = tails.back();
    while (k != -1) {
      result.push_back(k);
      k = prev[static_cast<size_t>(k)];
    }
    std::reverse(result.begin(), result.end());
  }
  return result;
}

void MediaBinModel::applyVisibleItemsDiff(std::vector<VisibleBinItem> newItems) {
  auto idOf = [this](size_t allIdx) -> const QString & {
    return m_allItems[allIdx].id;
  };

  // 1. Remove rows whose id no longer exists, highest index first (contiguous runs)
  for (int i = static_cast<int>(m_visibleItems.size()) - 1; i >= 0; --i) {
    const QString id = idOf(m_visibleItems[static_cast<size_t>(i)].allItemIndex);
    bool stillPresent = std::any_of(newItems.begin(), newItems.end(),
        [&](const VisibleBinItem &v) { return idOf(v.allItemIndex) == id; });
    if (stillPresent) continue;

    int end = i;
    while (i - 1 >= 0) {
      const QString prevId = idOf(m_visibleItems[static_cast<size_t>(i - 1)].allItemIndex);
      bool prevPresent = std::any_of(newItems.begin(), newItems.end(),
          [&](const VisibleBinItem &v) { return idOf(v.allItemIndex) == prevId; });
      if (prevPresent) break;
      --i;
    }
    int start = i;
    beginRemoveRows(QModelIndex(), start, end);
    m_visibleItems.erase(m_visibleItems.begin() + start, m_visibleItems.begin() + end + 1);
    endRemoveRows();
  }

  // 2. Insert rows whose id is new, ascending
  QSet<QString> curIds;
  for (const auto &v : m_visibleItems) curIds.insert(idOf(v.allItemIndex));

  for (int i = 0; i < static_cast<int>(newItems.size()); ++i) {
    const QString id = idOf(newItems[static_cast<size_t>(i)].allItemIndex);
    if (curIds.contains(id)) continue;

    int end = i;
    while (end + 1 < static_cast<int>(newItems.size()) &&
           !curIds.contains(idOf(newItems[static_cast<size_t>(end + 1)].allItemIndex))) {
      ++end;
    }
    int start = i;
    beginInsertRows(QModelIndex(), start, end);
    m_visibleItems.insert(m_visibleItems.begin() + start,
                          newItems.begin() + start, newItems.begin() + end + 1);
    endInsertRows();
    for (int k = start; k <= end; ++k) curIds.insert(idOf(newItems[static_cast<size_t>(k)].allItemIndex));
    i = end;
  }

  // 3. Reorder: LIS marks items that can stay put; move everything else
  std::vector<int> curPosForTarget(newItems.size(), -1);
  for (int i = 0; i < static_cast<int>(newItems.size()); ++i) {
    const QString id = idOf(newItems[static_cast<size_t>(i)].allItemIndex);
    for (int j = 0; j < static_cast<int>(m_visibleItems.size()); ++j) {
      if (idOf(m_visibleItems[static_cast<size_t>(j)].allItemIndex) == id) {
        curPosForTarget[static_cast<size_t>(i)] = j;
        break;
      }
    }
  }

  QSet<int> keep;
  for (int i : longestIncreasingSubsequenceIndices(curPosForTarget)) keep.insert(i);

  for (int targetPos = 0; targetPos < static_cast<int>(newItems.size()); ++targetPos) {
    if (keep.contains(targetPos)) continue;
    const QString id = idOf(newItems[static_cast<size_t>(targetPos)].allItemIndex);

    int curPos = -1;
    for (int i = 0; i < static_cast<int>(m_visibleItems.size()); ++i) {
      if (idOf(m_visibleItems[static_cast<size_t>(i)].allItemIndex) == id) { curPos = i; break; }
    }
    if (curPos == -1 || curPos == targetPos) continue;

    int destPos = targetPos > curPos ? targetPos + 1 : targetPos;
    beginMoveRows(QModelIndex(), curPos, curPos, QModelIndex(), destPos);
    VisibleBinItem moved = m_visibleItems[static_cast<size_t>(curPos)];
    m_visibleItems.erase(m_visibleItems.begin() + curPos);
    m_visibleItems.insert(m_visibleItems.begin() + targetPos, moved);
    endMoveRows();
  }

  // 4. Sync per-row metadata (depth/expanded/hasChildren/isLastChild/ancestorMask)
  //    for rows that didn't move but whose visual attributes changed
  for (int i = 0; i < static_cast<int>(newItems.size()); ++i) {
    VisibleBinItem &cur = m_visibleItems[static_cast<size_t>(i)];
    const VisibleBinItem &target = newItems[static_cast<size_t>(i)];
    bool changed = cur.depth != target.depth || cur.isExpanded != target.isExpanded ||
                   cur.hasChildren != target.hasChildren || cur.isLastChild != target.isLastChild ||
                   cur.ancestorMask != target.ancestorMask;
    cur = target;
    if (changed) {
      QModelIndex idx = index(i);
      emit dataChanged(idx, idx, {DepthRole, IsExpandedRole, HasChildrenRole, IsLastChildRole, AncestorMaskRole});
    }
  }
}

bool MediaBinModel::lessThan(size_t a, size_t b) const {
  const auto &itemA = m_allItems[a];
  const auto &itemB = m_allItems[b];

  if (itemA.isFolder != itemB.isFolder) {
    return itemA.isFolder > itemB.isFolder;
  }

  bool result = false;
  switch (m_sortRole) {
  case DurationRole:
    result = itemA.durationSec < itemB.durationSec;
    break;
  case PathRole:
    result = itemA.path.localeAwareCompare(itemB.path) < 0;
    break;
  case NameRole:
  default:
    result = itemA.name.localeAwareCompare(itemB.name) < 0;
    break;
  }

  return m_sortAscending ? result : !result;
}

QVariantMap MediaBinModel::get(int index) const {
  QVariantMap result;
  if (index < 0 || index >= static_cast<int>(m_visibleItems.size()))
    return result;

  size_t actualIdx = m_visibleItems[static_cast<size_t>(index)].allItemIndex;
  if (actualIdx >= m_allItems.size())
    return result;

  const auto &item = m_allItems[actualIdx];
  result["id"] = item.id;
  result["name"] = item.name;
  result["path"] = item.path;
  result["duration"] = item.isFolder
                           ? QString("")
                           : (QString::number(item.durationSec, 'f', 1) + "s");
  result["resolution"] = item.resolution;
  result["isFolder"] = item.isFolder;
  result["parentBinId"] = item.parentBinId;
  return result;
}

bool MediaBinModel::isDescendantOf(const QString &candidateChildId,
                                   const QString &ancestorId) const {
  if (candidateChildId.isEmpty() || ancestorId.isEmpty())
    return false;
  if (candidateChildId == ancestorId)
    return true;

  QString currentParent;
  for (const auto &item : m_allItems) {
    if (item.id == candidateChildId) {
      currentParent = item.parentBinId;
      break;
    }
  }

  while (!currentParent.isEmpty() && currentParent != "root") {
    if (currentParent == ancestorId) {
      return true;
    }
    QString nextParent;
    for (const auto &item : m_allItems) {
      if (item.id == currentParent) {
        nextParent = item.parentBinId;
        break;
      }
    }
    if (nextParent == currentParent) // cycle guard
      break;
    currentParent = nextParent;
  }

  return false;
}

void MediaBinModel::moveAssetsById(const QStringList &assetIds,
                                   const QString &targetBinId) {
  if (assetIds.isEmpty())
    return;
  const QString dest =
      targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;

  QStringList validMovedIds;

  // 1. Move root assets while filtering out self or descendant targets
  for (const QString &id : assetIds) {
    if (id == dest)
      continue;

    // Block moving a folder into itself or any of its children
    if (dest != "root" && isDescendantOf(dest, id)) {
      continue;
    }

    for (auto &item : m_allItems) {
      if (item.id == id) {
        item.parentBinId = dest;
        validMovedIds.append(id);
        break;
      }
    }
  }

  if (validMovedIds.isEmpty())
    return;

  if (dest != "root") {
    m_expandedFolderIds.insert(dest);
  }

  // 2. Collect all moved asset IDs AND their recursive descendants for
  // animation
  QSet<QString> movedAllIds(validMovedIds.begin(), validMovedIds.end());
  bool addedMore = true;
  while (addedMore) {
    addedMore = false;
    for (const auto &item : m_allItems) {
      if (movedAllIds.contains(item.parentBinId) &&
          !movedAllIds.contains(item.id)) {
        movedAllIds.insert(item.id);
        addedMore = true;
      }
    }
  }

  if (m_pool) {
    for (const QString &id : validMovedIds) {
      m_pool->setAssetBin(id, dest);
    }
  }

  resetVisibleItems();

  // FIX: Only update the target folder to fetch its children
  // 3. Emit notification with all affected IDs + the destination folder
  QSet<QString> notifyIds = movedAllIds;
  if (dest != "root") {
    notifyIds.insert(dest); // Target folder triggers its pulse animation too
  }

  emit itemsMoved(QStringList(notifyIds.begin(), notifyIds.end()));
}

void MediaBinModel::setAssetTag(const QString &assetId, int tagValue) {
  setAssetsTag({assetId}, tagValue);
}

void MediaBinModel::setAssetsTag(const QStringList &assetIds, int tagValue) {
  if (assetIds.isEmpty()) return;
  AssetTag tag = static_cast<AssetTag>(tagValue);
  for (const QString &id : assetIds) {
    for (auto &item : m_allItems) {
      if (item.id == id) {
        item.tag = tag;
        if (m_pool) m_pool->setAssetTag(id, tagValue);
        emit itemTagChanged(id, tagValue);
        break;
      }
    }
  }

  rebuildVisibleItems();

  for (const QString &id : assetIds) {
    for (size_t i = 0; i < m_visibleItems.size(); ++i) {
      if (m_allItems[m_visibleItems[i].allItemIndex].id == id) {
        emit dataChanged(index(static_cast<int>(i)), index(static_cast<int>(i)),
                          {TagRole, TagColorRole});
        break;
      }
    }
  }
}

bool MediaBinModel::hasActiveFilters() const {
  return activeFilterCount() > 0;
}

int MediaBinModel::activeFilterCount() const {
  int count = 0;
  if (!m_searchFilter.trimmed().isEmpty()) count++;
  if (m_tagFilter != 0) count++;
  if (m_typeFilter > 0) count++;
  if (!m_extensionFilter.trimmed().isEmpty()) count++;
  if (m_minDurationFilter > 0.0 || m_maxDurationFilter > 0.0) count++;
  if (m_minSizeMBFilter > 0.0 || m_maxSizeMBFilter > 0.0) count++;
  return count;
}

void MediaBinModel::setTagFilter(int tag) {
  if (m_tagFilter != tag) {
    m_tagFilter = tag;
    resetVisibleItems();
    emit filterChanged();
  }
}

void MediaBinModel::setTypeFilter(int type) {
  if (m_typeFilter != type) {
    m_typeFilter = type;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setExtensionFilter(const QString &ext) {
  QString clean = ext.trimmed().toLower();
  if (clean.startsWith('.')) clean.remove(0, 1);
  if (m_extensionFilter != clean) {
    m_extensionFilter = clean;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setMinDurationFilter(double seconds) {
  double val = std::max(0.0, seconds);
  if (!qFuzzyCompare(m_minDurationFilter, val)) {
    m_minDurationFilter = val;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setMaxDurationFilter(double seconds) {
  double val = std::max(0.0, seconds);
  if (!qFuzzyCompare(m_maxDurationFilter, val)) {
    m_maxDurationFilter = val;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setMinSizeMBFilter(double mb) {
  double val = std::max(0.0, mb);
  if (!qFuzzyCompare(m_minSizeMBFilter, val)) {
    m_minSizeMBFilter = val;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setMaxSizeMBFilter(double mb) {
  double val = std::max(0.0, mb);
  if (!qFuzzyCompare(m_maxSizeMBFilter, val)) {
    m_maxSizeMBFilter = val;
    emit filterChanged();
    resetVisibleItems();
  }
}

void MediaBinModel::setDurationRange(double minSec, double maxSec) {
  m_minDurationFilter = std::max(0.0, minSec);
  m_maxDurationFilter = std::max(0.0, maxSec);
  emit filterChanged();
  resetVisibleItems();
}

void MediaBinModel::setSizeRangeMB(double minMB, double maxMB) {
  m_minSizeMBFilter = std::max(0.0, minMB);
  m_maxSizeMBFilter = std::max(0.0, maxMB);
  emit filterChanged();
  resetVisibleItems();
}

void MediaBinModel::resetAllFilters() {
  m_searchFilter.clear();
  m_tagFilter = 0;
  m_typeFilter = 0;
  m_extensionFilter.clear();
  m_minDurationFilter = 0.0;
  m_maxDurationFilter = 0.0;
  m_minSizeMBFilter = 0.0;
  m_maxSizeMBFilter = 0.0;

  emit searchFilterChanged();
  emit filterChanged();
  resetVisibleItems();
}

void MediaBinModel::setGlobalSearch(bool global) {
  if (m_globalSearch != global) {
    m_globalSearch = global;
    emit globalSearchChanged();
    resetVisibleItems();
  }
}

QVariantMap MediaBinModel::getFullMetadata(int visualIndex) const {
  if (visualIndex < 0 || visualIndex >= static_cast<int>(m_visibleItems.size()))
    return {};

  size_t allIdx = m_visibleItems[visualIndex].allItemIndex;
  if (allIdx >= m_allItems.size())
    return {};

  const auto &item = m_allItems[allIdx];
  QVariantMap map;
  map["id"] = item.id;
  map["name"] = item.name;
  map["path"] = item.path;
  map["isFolder"] = item.isFolder;
  map["parentBinId"] = item.parentBinId;
  map["tag"] = static_cast<int>(item.tag);
  map["tagColor"] = tagToColor(item.tag);
  map["fileSize"] = static_cast<qint64>(item.fileSizeBytes);

  if (m_pool && !item.isFolder) {
    auto asset = m_pool->getAsset(item.id);
    if (asset) {
      // Merge probe metadata
      QVariantMap meta = asset->metadata().toVariantMap();
      for (auto it = meta.begin(); it != meta.end(); ++it) {
        map[it.key()] = it.value();
      }
    }
  }

  return map;
}

} // namespace xyla
