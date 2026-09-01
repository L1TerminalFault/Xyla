#include "ui/models/mediaBinModel.hpp"
#include "core/log/logger.hpp"
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QUuid>
#include <algorithm>
#include <functional>

namespace xyla {

MediaBinModel::MediaBinModel(MediaPool *pool, QObject *parent)
    : QAbstractListModel(parent), m_pool(pool) {

  m_mediaPanelSettings =
      new MediaPanelSettings(this); // parented → automatic cleanup

  // Initialize model state from loaded settings:
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
    connect(m_pool, &MediaPool::assetImported, this,
            &MediaBinModel::onAssetImported, Qt::QueuedConnection);
  }
}
// MediaBinModel::MediaBinModel(MediaPool *pool, QObject *parent)
//     : QAbstractListModel(parent), m_pool(pool) {
//
//   m_mediaPanelSettings =
//       new MediaPanelSettings(this); // parented → automatic cleanup
//
//   if (m_pool) {
//     connect(m_pool, &MediaPool::assetImported, this,
//             &MediaBinModel::onAssetImported, Qt::QueuedConnection);
//   }
// }

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
  case DurationRole:
    return item.isFolder ? ""
                         : (QString::number(item.durationSec, 'f', 1) + "s");
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
          {AncestorMaskRole, "ancestorMask"}};
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

void MediaBinModel::setTreeMode(bool enabled) {
  if (m_treeMode == enabled)
    return;
  m_treeMode = enabled;
  emit treeModeChanged();
  rebuildVisibleItems();
}

// void MediaBinModel::toggleFolderExpanded(const QString &folderId) {
//   if (folderId.isEmpty())
//     return;
//   if (m_expandedFolderIds.contains(folderId)) {
//     m_expandedFolderIds.remove(folderId);
//   } else {
//     m_expandedFolderIds.insert(folderId);
//   }
//   rebuildVisibleItems();
// }

// void MediaBinModel::setFolderExpanded(const QString &folderId, bool expanded)
// {
//   if (folderId.isEmpty())
//     return;
//   if (expanded) {
//     m_expandedFolderIds.insert(folderId);
//   } else {
//     m_expandedFolderIds.remove(folderId);
//   }
//   rebuildVisibleItems();
// }

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
  rebuildVisibleItems();
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
  rebuildVisibleItems();
}

void MediaBinModel::setSortAscending(bool ascending) {
  if (m_sortAscending == ascending)
    return;
  m_sortAscending = ascending;
  emit sortAscendingChanged();
  rebuildVisibleItems();
}

void MediaBinModel::setCurrentBinId(const QString &binId) {
  const QString target = binId.isEmpty() ? QStringLiteral("root") : binId;
  if (m_currentBinId == target)
    return;
  m_currentBinId = target;
  emit currentBinIdChanged();
  rebuildVisibleItems();
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

  // Automatically expand parent folder so the new child is visible immediately in the tree
  if (targetBin != "root") {
    m_expandedFolderIds.insert(targetBin);
  }

  // Rebuild visible items so it is placed in exact sorted tree hierarchy under its parent
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
// int MediaBinModel::createFolder(const QString &folderName,
//                                 const QString &parentBin) {
//   const QString targetBin =
//       parentBin.isEmpty()
//           ? (m_treeMode ? QStringLiteral("root") : m_currentBinId)
//           : parentBin;
//
//   QString initialName = folderName.trimmed().isEmpty()
//                             ? QStringLiteral("New Folder")
//                             : folderName.trimmed();
//   QString name = initialName;
//
//   bool exists = false;
//   for (const auto &it : m_allItems) {
//     if (it.parentBinId == targetBin && it.isFolder &&
//         it.name.compare(name, Qt::CaseInsensitive) == 0) {
//       exists = true;
//       break;
//     }
//   }
//   if (exists) {
//     name = generateUniqueName(initialName, true, targetBin);
//   }
//
//   BinItem item;
//   item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
//   item.name = name;
//   item.isFolder = true;
//   item.parentBinId = targetBin;
//
//   m_allItems.push_back(item);
//
//   if (targetBin != "root") {
//     m_expandedFolderIds.insert(targetBin);
//   }
//
//   // Insert single row incrementally
//   size_t newAllItemIdx = m_allItems.size() - 1;
//   int targetDepth = 0;
//   if (m_treeMode && targetBin != "root") {
//     for (const auto &v : m_visibleItems) {
//       if (m_allItems[v.allItemIndex].id == targetBin) {
//         targetDepth = v.depth + 1;
//         break;
//       }
//     }
//   }
//
//   int insertRow = static_cast<int>(m_visibleItems.size());
//   beginInsertRows(QModelIndex(), insertRow, insertRow);
//   m_visibleItems.push_back({newAllItemIdx, targetDepth, false, false, true, 0});
//   endInsertRows();
//
//   emit itemsAdded({item.id});
//   return insertRow;
// }

void MediaBinModel::removeAsset(int index) {
  if (index < 0 || index >= static_cast<int>(m_visibleItems.size()))
    return;
  size_t actualIdx = m_visibleItems[static_cast<size_t>(index)].allItemIndex;
  if (actualIdx < m_allItems.size()) {
    removeAssetsById({m_allItems[actualIdx].id});
  }
}

void MediaBinModel::removeAssetsById(const QStringList &assetIds) {
  if (assetIds.isEmpty())
    return;

  QSet<QString> idsToRemove(assetIds.begin(), assetIds.end());

  bool addedMore = true;
  while (addedMore) {
    addedMore = false;
    for (const auto &item : m_allItems) {
      if (idsToRemove.contains(item.parentBinId) &&
          !idsToRemove.contains(item.id)) {
        idsToRemove.insert(item.id);
        addedMore = true;
      }
    }
  }

  m_allItems.erase(std::remove_if(m_allItems.begin(), m_allItems.end(),
                                  [&idsToRemove](const BinItem &item) {
                                    return idsToRemove.contains(item.id);
                                  }),
                   m_allItems.end());

  for (const QString &id : idsToRemove) {
    m_expandedFolderIds.remove(id);
  }

  rebuildVisibleItems();
}

void MediaBinModel::renameAsset(int visualIndex, const QString &newName) {
  if (visualIndex < 0 || visualIndex >= static_cast<int>(m_visibleItems.size()))
    return;

  const QString trimmed = newName.trimmed();
  if (trimmed.isEmpty())
    return;

  size_t actualIdx = m_visibleItems[static_cast<size_t>(visualIndex)].allItemIndex;
  if (actualIdx >= m_allItems.size())
    return;

  if (m_allItems[actualIdx].name == trimmed)
    return;

  m_allItems[actualIdx].name = trimmed;
  QString id = m_allItems[actualIdx].id;

  // Update visible item order only if sorted by name
  if (m_sortRole == NameRole) {
    rebuildVisibleItems();
  } else {
    QModelIndex idx = index(visualIndex);
    emit dataChanged(idx, idx, {NameRole});
  }

  emit itemRenamed(id);
}

void MediaBinModel::renameAssetById(const QString &assetId,
                                    const QString &newName) {
  const QString trimmed = newName.trimmed();
  if (trimmed.isEmpty() || assetId.isEmpty())
    return;

  for (auto &item : m_allItems) {
    if (item.id == assetId) {
      if (item.name != trimmed) {
        item.name = trimmed;
        rebuildVisibleItems();
        emit itemRenamed(item.id);
      }
      return;
    }
  }
}

// void MediaBinModel::moveAssetsById(const QStringList &assetIds,
//                                    const QString &targetBinId) {
//   if (assetIds.isEmpty())
//     return;
//   const QString dest =
//       targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;
//
//   // 1. Move root assets
//   for (const QString &id : assetIds) {
//     if (id == dest)
//       continue;
//     for (auto &item : m_allItems) {
//       if (item.id == id) {
//         item.parentBinId = dest;
//         break;
//       }
//     }
//   }
//
//   if (dest != "root") {
//     m_expandedFolderIds.insert(dest);
//   }
//
//   // 2. Collect all moved asset IDs AND all their recursive descendants
//   QSet<QString> movedAllIds(assetIds.begin(), assetIds.end());
//   bool addedMore = true;
//   while (addedMore) {
//     addedMore = false;
//     for (const auto &item : m_allItems) {
//       if (movedAllIds.contains(item.parentBinId) && !movedAllIds.contains(item.id)) {
//         movedAllIds.insert(item.id);
//         addedMore = true;
//       }
//     }
//   }
//
//   rebuildVisibleItems();
//
//   // 3. Emit notification with all affected IDs
//   emit itemsMoved(QStringList(movedAllIds.begin(), movedAllIds.end()));
// }

// void MediaBinModel::moveAssetsById(const QStringList &assetIds,
//                                    const QString &targetBinId) {
//   if (assetIds.isEmpty())
//     return;
//   const QString dest =
//       targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;
//
//   for (const QString &id : assetIds) {
//     if (id == dest)
//       continue;
//     for (auto &item : m_allItems) {
//       if (item.id == id) {
//         item.parentBinId = dest;
//         break;
//       }
//     }
//   }
//
//   if (dest != "root") {
//     m_expandedFolderIds.insert(dest);
//   }
//
//   rebuildVisibleItems();
// }

QString MediaBinModel::duplicateItemRecursive(const QString &itemId,
                                              const QString &targetBinId) {
  auto it =
      std::find_if(m_allItems.begin(), m_allItems.end(),
                   [&itemId](const BinItem &b) { return b.id == itemId; });
  if (it == m_allItems.end())
    return {};

  BinItem copy = *it;
  copy.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
  copy.parentBinId = targetBinId;
  copy.name = generateUniqueName(it->name, it->isFolder, targetBinId);

  m_allItems.push_back(copy);

  if (it->isFolder) {
    std::vector<QString> childIds;
    for (const auto &item : m_allItems) {
      if (item.parentBinId == itemId) {
        childIds.push_back(item.id);
      }
    }
    for (const auto &cId : childIds) {
      duplicateItemRecursive(cId, copy.id);
    }
  }

  return copy.id;
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
    rebuildVisibleItems();
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
  item.isFolder = false;
  item.parentBinId = binId.isEmpty() ? QStringLiteral("root") : binId;

  if (!asset->metadata().videoStreams.empty()) {
    const auto &vs = asset->metadata().videoStreams[0];
    item.resolution = QString("%1x%2").arg(vs.width).arg(vs.height);
  }

  m_allItems.push_back(item);
  rebuildVisibleItems();

  emit itemsAdded({item.id});

  XYLA_LOG_INFO(
      "MediaBinModel",
      QString("Added item to model: %1").arg(item.name).toStdString().c_str());
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
    parentMask |= (1 << (m_visibleItems[static_cast<size_t>(folderRow)].depth - 1));
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
// void MediaBinModel::collectSubtreeVisibleItems(const QString &folderId, int
// depth, int currentMask, std::vector<VisibleBinItem> &out) const {
//   std::vector<size_t> levelIndices;
//   for (size_t i = 0; i < m_allItems.size(); ++i) {
//     if (m_allItems[i].parentBinId == folderId) {
//       levelIndices.push_back(i);
//     }
//   }
//
//   std::sort(levelIndices.begin(), levelIndices.end(),
//             [this](size_t a, size_t b) { return lessThan(a, b); });
//
//   for (size_t i = 0; i < levelIndices.size(); ++i) {
//     size_t idx = levelIndices[i];
//     const auto &item = m_allItems[idx];
//     bool isLast = (i == levelIndices.size() - 1);
//     bool hasChildren = false;
//
//     if (item.isFolder) {
//       for (const auto &child : m_allItems) {
//         if (child.parentBinId == item.id) {
//           hasChildren = true;
//           break;
//         }
//       }
//     }
//
//     bool isExpanded = item.isFolder && m_expandedFolderIds.contains(item.id);
//     out.push_back({idx, depth, isExpanded, hasChildren, isLast,
//     currentMask});
//
//     if (isExpanded) {
//       int nextMask = currentMask;
//       if (!isLast) {
//         nextMask |= (1 << (depth - 1)); // keep spine open for lower siblings
//       }
//       collectSubtreeVisibleItems(item.id, depth + 1, nextMask, out);
//     }
//   }
// }
// void MediaBinModel::collectSubtreeVisibleItems(const QString &folderId, int
// depth, std::vector<VisibleBinItem> &out) const {
//   std::vector<size_t> levelIndices;
//   for (size_t i = 0; i < m_allItems.size(); ++i) {
//     if (m_allItems[i].parentBinId == folderId) {
//       levelIndices.push_back(i);
//     }
//   }
//
//   std::sort(levelIndices.begin(), levelIndices.end(),
//             [this](size_t a, size_t b) { return lessThan(a, b); });
//
//   for (size_t idx : levelIndices) {
//     const auto &item = m_allItems[idx];
//     bool hasChildren = false;
//     if (item.isFolder) {
//       for (const auto &child : m_allItems) {
//         if (child.parentBinId == item.id) {
//           hasChildren = true;
//           break;
//         }
//       }
//     }
//
//     bool isExpanded = item.isFolder && m_expandedFolderIds.contains(item.id);
//     out.push_back({idx, depth, isExpanded, hasChildren});
//
//     if (isExpanded) {
//       collectSubtreeVisibleItems(item.id, depth + 1, out);
//     }
//   }
// }

// void MediaBinModel::expandFolderIncremental(const QString &folderId) {
//   // Find the folder row in m_visibleItems
//   int folderRow = -1;
//   for (size_t i = 0; i < m_visibleItems.size(); ++i) {
//     if (m_allItems[m_visibleItems[i].allItemIndex].id == folderId) {
//       folderRow = static_cast<int>(i);
//       break;
//     }
//   }
//
//   if (folderRow == -1)
//     return;
//
//   m_expandedFolderIds.insert(folderId);
//   m_visibleItems[static_cast<size_t>(folderRow)].isExpanded = true;
//
//   // 1. Notify the folder delegate so the chevron animates in place without
//   recreating QModelIndex idx = index(folderRow); emit dataChanged(idx, idx,
//   {IsExpandedRole});
//
//   // 2. Collect children to insert right below folderRow
//   std::vector<VisibleBinItem> toInsert;
//   int depth = m_visibleItems[static_cast<size_t>(folderRow)].depth + 1;
//   collectSubtreeVisibleItems(folderId, depth, toInsert);
//
//   if (toInsert.empty())
//     return;
//
//   int insertFirst = folderRow + 1;
//   int insertLast = folderRow + static_cast<int>(toInsert.size());
//
//   beginInsertRows(QModelIndex(), insertFirst, insertLast);
//   m_visibleItems.insert(m_visibleItems.begin() + insertFirst,
//   toInsert.begin(), toInsert.end()); endInsertRows();
// }

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

void MediaBinModel::rebuildVisibleItems() {
  beginResetModel();
  m_visibleItems.clear();

  const QString filter = m_searchFilter.trimmed();
  const bool hasFilter = !filter.isEmpty();

  if (hasFilter) {
    for (size_t i = 0; i < m_allItems.size(); ++i) {
      const auto &item = m_allItems[i];
      if (item.name.contains(filter, Qt::CaseInsensitive) ||
          item.path.contains(filter, Qt::CaseInsensitive)) {
        m_visibleItems.push_back({i, 0, false, false});
      }
    }
    std::sort(m_visibleItems.begin(), m_visibleItems.end(),
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
            m_visibleItems.push_back(
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
    // std::function<void(const QString &, int)> addLevel =
    //     [&](const QString &parentId, int depth) {
    //       std::vector<size_t> levelIndices;
    //       for (size_t i = 0; i < m_allItems.size(); ++i) {
    //         if (m_allItems[i].parentBinId == parentId) {
    //           levelIndices.push_back(i);
    //         }
    //       }
    //
    //       std::sort(levelIndices.begin(), levelIndices.end(),
    //                 [this](size_t a, size_t b) { return lessThan(a, b); });
    //
    //       for (size_t idx : levelIndices) {
    //         const auto &item = m_allItems[idx];
    //         bool hasChildren = false;
    //         if (item.isFolder) {
    //           for (const auto &child : m_allItems) {
    //             if (child.parentBinId == item.id) {
    //               hasChildren = true;
    //               break;
    //             }
    //           }
    //         }
    //
    //         bool isExpanded =
    //             item.isFolder && m_expandedFolderIds.contains(item.id);
    //         m_visibleItems.push_back({idx, depth, isExpanded, hasChildren});
    //
    //         if (isExpanded) {
    //           addLevel(item.id, depth + 1);
    //         }
    //       }
    //     };

    // addLevel(QStringLiteral("root"), 0);
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
      m_visibleItems.push_back({idx, 0, false, false});
    }
  }

  endResetModel();
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

  // 2. Collect all moved asset IDs AND their recursive descendants for animation
  QSet<QString> movedAllIds(validMovedIds.begin(), validMovedIds.end());
  bool addedMore = true;
  while (addedMore) {
    addedMore = false;
    for (const auto &item : m_allItems) {
      if (movedAllIds.contains(item.parentBinId) && !movedAllIds.contains(item.id)) {
        movedAllIds.insert(item.id);
        addedMore = true;
      }
    }
  }

  rebuildVisibleItems();

  // 3. Emit notification with all affected IDs + the destination folder
  QSet<QString> notifyIds = movedAllIds;
  if (dest != "root") {
    notifyIds.insert(dest); // Target folder triggers its pulse animation too
  }

  emit itemsMoved(QStringList(notifyIds.begin(), notifyIds.end()));
}

} // namespace xyla
