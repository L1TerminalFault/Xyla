#pragma once

#include "core/media/mediaAsset.hpp"
#include "core/media/mediaPool.hpp"
#include <QAbstractListModel>
#include <QSet>
#include <QStringList>
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

struct VisibleBinItem {
  size_t allItemIndex;
  int depth{0};
  bool isExpanded{false};
  bool hasChildren{false};
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
  Q_PROPERTY(QString currentBinName READ currentBinName NOTIFY
                 currentBinIdChanged)
  Q_PROPERTY(QString parentBinId READ parentBinId NOTIFY currentBinIdChanged)
  Q_PROPERTY(bool treeMode READ treeMode WRITE setTreeMode NOTIFY treeModeChanged)

public:
  enum Roles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    PathRole,
    DurationRole,
    ResolutionRole,
    IsFolderRole,
    ParentBinIdRole,
    DepthRole,
    IsExpandedRole,
    HasChildrenRole
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
  [[nodiscard]] QString currentBinName() const;
  [[nodiscard]] QString parentBinId() const;
  [[nodiscard]] bool treeMode() const { return m_treeMode; }

  [[nodiscard]] QString generateUniqueName(const QString &originalName,
                                           bool isFolder,
                                           const QString &targetBinId) const;

public slots:
  void setSearchFilter(const QString &filter);
  void setSortRole(int role);
  void setSortAscending(bool ascending);
  void setCurrentBinId(const QString &binId);
  void setTreeMode(bool enabled);
  void toggleFolderExpanded(const QString &folderId);
  void setFolderExpanded(const QString &folderId, bool expanded);
  bool isFolderExpanded(const QString &folderId) const;
  void expandAll();
  void collapseAll();

  int createFolder(const QString &folderName = QStringLiteral("New Folder"),
                   const QString &parentBin = QString());
  void removeAsset(int index);
  void removeAssetsById(const QStringList &assetIds);
  void onAssetImported(const QString &binId,
                       std::shared_ptr<xyla::MediaAsset> asset);
  void renameAsset(int visualIndex, const QString &newName);
  void renameAssetById(const QString &assetId, const QString &newName);
  void moveAssetsById(const QStringList &assetIds, const QString &targetBinId);
  void duplicateAssetsById(const QStringList &assetIds,
                           const QString &targetBinId);
  void goToParentBin();
  void groupByMediaType();
  QVariantMap get(int index) const;

signals:
  void searchFilterChanged();
  void sortRoleChanged();
  void sortAscendingChanged();
  void currentBinIdChanged();
  void treeModeChanged();
  void itemsAdded(const QStringList &ids);
  void itemRenamed(const QString &id);

private:
  void rebuildVisibleItems();
  bool lessThan(size_t a, size_t b) const;
  QString duplicateItemRecursive(const QString &itemId,
                                 const QString &targetBinId);

  MediaPool *m_pool{nullptr};
  std::vector<BinItem> m_allItems;
  std::vector<VisibleBinItem> m_visibleItems;
  QSet<QString> m_expandedFolderIds;

  QString m_searchFilter;
  int m_sortRole{NameRole};
  bool m_sortAscending{true};
  QString m_currentBinId{"root"};
  bool m_treeMode{false};
};

} // namespace xyla
