#pragma once

#include "core/media/mediaAsset.hpp"
#include "core/media/mediaPool.hpp"
#include <QAbstractListModel>
#include <vector>

namespace xyla {

struct BinItem {
  QString id;
  QString name;
  QString path;
  double durationSec{0.0};
  QString resolution;
  bool isFolder{false};
  QString parentBinId{"root"};
};

class MediaBinModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(QString searchFilter READ searchFilter WRITE setSearchFilter NOTIFY
                 searchFilterChanged)
  Q_PROPERTY(
      int sortRole READ sortRole WRITE setSortRole NOTIFY sortRoleChanged)
  Q_PROPERTY(bool sortAscending READ sortAscending WRITE setSortAscending NOTIFY
                 sortAscendingChanged)
  Q_PROPERTY(QString currentBinId READ currentBinId WRITE setCurrentBinId NOTIFY
                 currentBinIdChanged)

public:
  enum Roles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    PathRole,
    DurationRole,
    ResolutionRole,
    IsFolderRole,
    ParentBinIdRole
  };
  Q_ENUM(Roles)

  explicit MediaBinModel(MediaPool *pool, QObject *parent = nullptr);
  ~MediaBinModel() override = default;

  [[nodiscard]] int
  rowCount(const QModelIndex &parent = QModelIndex()) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index,
                              int role = Qt::DisplayRole) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

  [[nodiscard]] QString searchFilter() const { return m_searchFilter; }
  [[nodiscard]] int sortRole() const { return m_sortRole; }
  [[nodiscard]] bool sortAscending() const { return m_sortAscending; }
  [[nodiscard]] QString currentBinId() const { return m_currentBinId; }

public slots:
  void setSearchFilter(const QString &filter);
  void setSortRole(int role);
  void setSortAscending(bool ascending);
  void setCurrentBinId(const QString &binId);
  void createFolder(const QString &folderName);
  void removeAsset(int index);
  void onAssetImported(const QString &binId,
                       std::shared_ptr<xyla::MediaAsset> asset);

signals:
  void searchFilterChanged();
  void sortRoleChanged();
  void sortAscendingChanged();
  void currentBinIdChanged();

private:
  void rebuildVisibleItems();

  MediaPool *m_pool{nullptr};
  std::vector<BinItem> m_allItems;
  std::vector<size_t> m_visibleIndices;

  QString m_searchFilter;
  int m_sortRole{NameRole};
  bool m_sortAscending{true};
  QString m_currentBinId{"root"};
};

} // namespace xyla
