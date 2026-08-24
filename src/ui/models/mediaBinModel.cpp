#include "ui/models/mediaBinModel.hpp"
#include "core/log/logger.hpp"
#include <QUuid>
#include <algorithm>

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
  return static_cast<int>(m_visibleIndices.size());
}

QVariant MediaBinModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= static_cast<int>(m_visibleIndices.size())) {
    return {};
  }

  size_t actualIdx = m_visibleIndices[static_cast<size_t>(index.row())];
  if (actualIdx >= m_allItems.size()) {
    return {};
  }

  const auto &item = m_allItems[actualIdx];

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
          {ParentBinIdRole, "parentBinId"}};
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
  if (m_currentBinId == binId)
    return;
  m_currentBinId = binId;
  emit currentBinIdChanged();
  rebuildVisibleItems();
}

void MediaBinModel::createFolder(const QString &folderName) {
  if (folderName.trimmed().isEmpty())
    return;

  BinItem item;
  item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
  item.name = folderName.trimmed();
  item.isFolder = true;
  item.parentBinId = m_currentBinId;

  m_allItems.push_back(std::move(item));
  rebuildVisibleItems();
}

void MediaBinModel::removeAsset(int index) {
  if (index < 0 || index >= static_cast<int>(m_visibleIndices.size()))
    return;

  size_t actualIdx = m_visibleIndices[static_cast<size_t>(index)];
  if (actualIdx < m_allItems.size()) {
    m_allItems.erase(m_allItems.begin() + actualIdx);
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
  item.parentBinId = binId.isEmpty() ? "root" : binId;

  if (!asset->metadata().videoStreams.empty()) {
    const auto &vs = asset->metadata().videoStreams[0];
    item.resolution = QString("%1x%2").arg(vs.width).arg(vs.height);
  }

  m_allItems.push_back(std::move(item));
  rebuildVisibleItems();

  XYLA_LOG_INFO(
      "MediaBinModel",
      QString("Added item to model: %1").arg(item.name).toStdString().c_str());
}

void MediaBinModel::rebuildVisibleItems() {
  beginResetModel();
  m_visibleIndices.clear();

  const QString filter = m_searchFilter.trimmed();
  const bool hasFilter = !filter.isEmpty();

  for (size_t i = 0; i < m_allItems.size(); ++i) {
    const auto &item = m_allItems[i];

    // Check bin parent ID match (unless searching across all bins)
    if (!hasFilter && item.parentBinId != m_currentBinId) {
      continue;
    }

    // Check search filter
    if (hasFilter) {
      bool matches = item.name.contains(filter, Qt::CaseInsensitive) ||
                     item.path.contains(filter, Qt::CaseInsensitive);
      if (!matches)
        continue;
    }

    m_visibleIndices.push_back(i);
  }

  // Sort visible indices
  std::sort(m_visibleIndices.begin(), m_visibleIndices.end(),
            [this](size_t a, size_t b) {
              const auto &itemA = m_allItems[a];
              const auto &itemB = m_allItems[b];

              // Always keep folders at top
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
            });

  endResetModel();
}

} // namespace xyla
