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
  return static_cast<int>(m_projects.size());
}

QVariant RecentProjectsModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= static_cast<int>(m_projects.size())) {
    return QVariant();
  }
  const auto project = m_projects[index.row()];
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

void RecentProjectsModel::setProjects(const QList<ProjectInfo> &projects) {
  beginResetModel();
  m_projects = projects;
  endResetModel();
}

void RecentProjectsModel::addProject(const ProjectInfo &project) {
  beginInsertRows(QModelIndex(), 0, 0);
  m_projects.prepend(project);
  endInsertRows();
}
} // namespace xyla
