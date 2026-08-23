#pragma once

#include "projectData.hpp"
#include <QAbstractListModel>
#include <QList>
#include <qabstractitemmodel.h>
#include <qobject.h>

namespace xyla {
class RecentProjectsModel : public QAbstractListModel {
  Q_OBJECT
public:
  enum Roles { NameRole = Qt::UserRole + 1, PathRole, LastModifiedRole };
  explicit RecentProjectsModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  void setProjects(const QList<ProjectInfo> &projects);
  void addProject(const ProjectInfo &project);

private:
  QList<ProjectInfo> m_projects;
};
} // namespace xyla
