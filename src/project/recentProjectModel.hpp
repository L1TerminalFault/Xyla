#pragma once

#include "projectData.hpp"
#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QList>
#include <QVariant>

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

  void setSourceList(const QList<ProjectInfo> *sourceList);

  void notifyProjectPrepended() {
    beginInsertRows(QModelIndex(), 0, 0);
    endInsertRows();
  }

  void notifyProjectRemoved(int index) {
    beginRemoveRows(QModelIndex(), index, index);
    endRemoveRows();
  }

  void refresh() {
    beginResetModel();
    endResetModel();
  }

private:
  const QList<ProjectInfo> *m_sourceList = nullptr;
};

} // namespace xyla
