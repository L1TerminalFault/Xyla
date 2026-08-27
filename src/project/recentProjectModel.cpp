#include "recentProjectModel.hpp"
#include <qabstractitemmodel.h>
#include <qobject.h>
#include <qvariant.h>

namespace xyla {
RecentProjectsModel::RecentProjectsModel(QObject *parent)
    : QAbstractListModel(parent) {}

int RecentProjectsModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return static_cast<int>(m_sourceList->size());
}

QVariant RecentProjectsModel::data(const QModelIndex &index, int role) const {
  if (!m_sourceList || !index.isValid() || index.row() < 0 ||
      index.row() >= m_sourceList->size())
    return QVariant();

  const auto project = (*m_sourceList)[index.row()];
  switch (role) {
  case NameRole:
    return project.name;
  case PathRole:
    return project.filePath;
  case LastModifiedRole:
    return project.lastModified.toString("yyyy-MM-dd hh:mm");
  default:
    return QVariant();
  };
}

QHash<int, QByteArray> RecentProjectsModel::roleNames() const {
  return {{NameRole, "name"},
          {PathRole, "filePath"},
          {LastModifiedRole, "lastModified"}};
}

void RecentProjectsModel::setSourceList(const QList<ProjectInfo> *sourceList) {
  if (!sourceList)
    return;
  beginResetModel();
  m_sourceList = sourceList;
  endResetModel();
}

} // namespace xyla
