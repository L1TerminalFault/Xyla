// src/ui/models/mediaBinModel.cpp
#include "ui/models/mediaBinModel.hpp"
#include "core/log/logger.hpp"

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
  return static_cast<int>(m_items.size());
}

QVariant MediaBinModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= static_cast<int>(m_items.size())) {
    return {};
  }

  const auto &item = m_items[static_cast<size_t>(index.row())];

  switch (role) {
  case IdRole:
    return item.id;
  case NameRole:
    return item.name;
  case PathRole:
    return item.path;
  case DurationRole:
    return QString::number(item.durationSec, 'f', 1) + "s";
  case ResolutionRole:
    return item.resolution;
  default:
    return {};
  }
}

QHash<int, QByteArray> MediaBinModel::roleNames() const {
  return {{IdRole, "id"},
          {NameRole, "name"},
          {PathRole, "path"},
          {DurationRole, "duration"},
          {ResolutionRole, "resolution"}};
}

void MediaBinModel::onAssetImported(const QString &binId,
                                    std::shared_ptr<MediaAsset> asset) {
  Q_UNUSED(binId);
  if (!asset)
    return;

  const int newRow = static_cast<int>(m_items.size());
  beginInsertRows(QModelIndex(), newRow, newRow);

  BinItem item;
  item.id = asset->id();
  item.name = asset->name();
  item.path = asset->metadata().filePath;
  item.durationSec = asset->metadata().durationSeconds;

  if (!asset->metadata().videoStreams.empty()) {
    const auto &vs = asset->metadata().videoStreams[0];
    item.resolution = QString("%1x%2").arg(vs.width).arg(vs.height);
  }

  m_items.push_back(std::move(item));
  endInsertRows();

  XYLA_LOG_INFO(
      "MediaBinModel",
      QString("Added item to model: %1").arg(item.name).toStdString().c_str());
}

} // namespace xyla
