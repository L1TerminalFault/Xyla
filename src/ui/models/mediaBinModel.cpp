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
  if (m_pool) {
    connect(m_pool, &MediaPool::assetImported, this,
            &MediaBinModel::onAssetImported, Qt::QueuedConnection);
  }
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
          {HasChildrenRole, "hasChildren"}};
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

void MediaBinModel::toggleFolderExpanded(const QString &folderId) {
  if (folderId.isEmpty())
    return;
  if (m_expandedFolderIds.contains(folderId)) {
    m_expandedFolderIds.remove(folderId);
  } else {
    m_expandedFolderIds.insert(folderId);
  }
  rebuildVisibleItems();
}

void MediaBinModel::setFolderExpanded(const QString &folderId, bool expanded) {
  if (folderId.isEmpty())
    return;
  if (expanded) {
    m_expandedFolderIds.insert(folderId);
  } else {
    m_expandedFolderIds.remove(folderId);
  }
  rebuildVisibleItems();
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
  const QString targetBin = parentBin.isEmpty()
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

  if (targetBin != "root") {
    m_expandedFolderIds.insert(targetBin);
  }

  rebuildVisibleItems();

  emit itemsAdded({item.id});

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

  m_allItems.erase(
      std::remove_if(m_allItems.begin(), m_allItems.end(),
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
  if (visualIndex < 0 ||
      visualIndex >= static_cast<int>(m_visibleItems.size()))
    return;

  const QString trimmed = newName.trimmed();
  if (trimmed.isEmpty())
    return;

  size_t actualIdx =
      m_visibleItems[static_cast<size_t>(visualIndex)].allItemIndex;
  if (actualIdx >= m_allItems.size())
    return;

  if (m_allItems[actualIdx].name == trimmed)
    return;

  m_allItems[actualIdx].name = trimmed;
  QString id = m_allItems[actualIdx].id;
  rebuildVisibleItems();

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

void MediaBinModel::moveAssetsById(const QStringList &assetIds,
                                   const QString &targetBinId) {
  if (assetIds.isEmpty())
    return;
  const QString dest =
      targetBinId.isEmpty() ? QStringLiteral("root") : targetBinId;

  for (const QString &id : assetIds) {
    if (id == dest)
      continue;
    for (auto &item : m_allItems) {
      if (item.id == id) {
        item.parentBinId = dest;
        break;
      }
    }
  }

  if (dest != "root") {
    m_expandedFolderIds.insert(dest);
  }

  rebuildVisibleItems();
}

QString MediaBinModel::duplicateItemRecursive(const QString &itemId,
                                              const QString &targetBinId) {
  auto it = std::find_if(m_allItems.begin(), m_allItems.end(),
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

void MediaBinModel::duplicateAssetsById(const QStringList &assetIds,
                                        const QString &targetBinId) {
  if (assetIds.isEmpty())
    return;
  const QString dest = targetBinId.isEmpty()
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

  const QSet<QString> videoExts = {"mp4", "mov", "mkv", "avi", "webm", "m4v",
                                   "flv", "wmv", "m2ts", "ts", "mts"};
  const QSet<QString> audioExts = {"mp3", "wav", "aac", "flac", "ogg", "m4a",
                                   "wma", "aiff", "alac"};
  const QSet<QString> imageExts = {"png", "jpg", "jpeg", "webp", "bmp", "svg",
                                   "gif", "tiff", "tif", "tga"};

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
    std::function<void(const QString &, int)> addLevel =
        [&](const QString &parentId, int depth) {
          std::vector<size_t> levelIndices;
          for (size_t i = 0; i < m_allItems.size(); ++i) {
            if (m_allItems[i].parentBinId == parentId) {
              levelIndices.push_back(i);
            }
          }

          std::sort(levelIndices.begin(), levelIndices.end(),
                    [this](size_t a, size_t b) { return lessThan(a, b); });

          for (size_t idx : levelIndices) {
            const auto &item = m_allItems[idx];
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
                {idx, depth, isExpanded, hasChildren});

            if (isExpanded) {
              addLevel(item.id, depth + 1);
            }
          }
        };

    addLevel(QStringLiteral("root"), 0);
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

  size_t actualIdx =
      m_visibleItems[static_cast<size_t>(index)].allItemIndex;
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

} // namespace xyla
