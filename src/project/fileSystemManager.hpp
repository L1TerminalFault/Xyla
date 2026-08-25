#pragma once

#include <QAbstractListModel>
#include <QDateTime>

namespace xyla {

struct FileItem {
  QString name;
  QString filePath;
  bool isDir{false};
  qint64 size{0};
  int itemCount{0};
  QDateTime lastModified;
  QString extension;
};

class FileSystemModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY
                 currentPathChanged)
  Q_PROPERTY(QString parentPath READ parentPath NOTIFY currentPathChanged)
  Q_PROPERTY(bool canCdBack READ canCdBack NOTIFY canCdBackChanged)
  Q_PROPERTY(bool canCdForward READ canCdForward NOTIFY canCdForwardChanged)
  Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
  Q_PROPERTY(QString nameFilter READ nameFilter WRITE setNameFilter NOTIFY
                 nameFilterChanged)
  Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY
                 typeFilterChanged)
  Q_PROPERTY(QString sizeFilter READ sizeFilter WRITE setSizeFilter NOTIFY
                 sizeFilterChanged)
  Q_PROPERTY(QString sortBy READ sortBy WRITE setSortBy NOTIFY sortByChanged)
  Q_PROPERTY(QString sortOrder READ sortOrder WRITE setSortOrder NOTIFY
                 sortOrderChanged)
  Q_PROPERTY(bool canPaste READ canPaste NOTIFY clipboardChanged)
  Q_PROPERTY(bool foldersFirst READ foldersFirst WRITE setFoldersFirst NOTIFY
                 foldersFirstChanged)

public:
  enum FileRoles {
    NameRole = Qt::UserRole + 1,
    PathRole,
    IsDirRole,
    SizeRole,
    ItemCountRole,
    LastModifiedRole,
    ExtensionRole
  };

  Q_ENUM(FileRoles);

  explicit FileSystemModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  QString currentPath() const { return m_currentPath; }
  QString parentPath() const;
  bool canCdBack() const { return m_historyIndex > 0; }
  bool canCdForward() const {
    return m_historyIndex < (int)m_history.size() - 1;
  }
  QString nameFilter() const { return m_nameFilter; }
  void setNameFilter(const QString &filter);

  void setCurrentPath(const QString &path);
  QString lastError() const { return m_lastError; }
  QString typeFilter() const { return m_typeFilter; }
  QString sizeFilter() const { return m_sizeFilter; }
  QString sortBy() const { return m_sortBy; }
  QString sortOrder() const { return m_sortOrder; }
  bool foldersFirst() const { return m_foldersFirst; }

  void setFoldersFirst(bool first);
  void setTypeFilter(const QString &filter);
  void setSizeFilter(const QString &filter);
  void setSortBy(const QString &sortBy);
  void setSortOrder(const QString &sortOrder);

  Q_INVOKABLE void cd(const QString &path);
  Q_INVOKABLE void cdBack();
  Q_INVOKABLE void cdForward();
  Q_INVOKABLE void cdUp();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE bool makeFolder(const QString &folderName);
  Q_INVOKABLE QVariantList quickAccessItems() const;
  Q_INVOKABLE bool toggleBookmark(const QString &path);
  Q_INVOKABLE bool isBookmarked(const QString &path) const;
  Q_INVOKABLE QVariantList pathCompletions(const QString &path) const;
  Q_INVOKABLE QVariantMap get(int index) const;
  Q_INVOKABLE void cut(const QStringList &paths);
  Q_INVOKABLE void copy(const QStringList &paths);
  Q_INVOKABLE bool paste(const QString &targetDir = QString());
  Q_INVOKABLE bool rename(const QString &oldPath, const QString &newName);
  Q_INVOKABLE bool moveToTrash(const QStringList &paths);
  Q_INVOKABLE bool canPaste() const;
  Q_INVOKABLE void copyToClipboard(const QString &text);

signals:
  void currentPathChanged();
  void canCdBackChanged();
  void canCdForwardChanged();
  void lastErrorChanged();
  void bookmarksChanged();
  void nameFilterChanged();
  void typeFilterChanged();
  void sizeFilterChanged();
  void sortByChanged();
  void sortOrderChanged();
  void clipboardChanged();
  void foldersFirstChanged();

private:
  QString m_lastError;
  QString m_currentPath;
  QList<FileItem> m_items;
  QStringList m_history;
  int m_historyIndex{-1};
  QString m_bookmarksFile;
  QStringList m_bookmarks;
  QString m_nameFilter;
  QString m_typeFilter{"All Files"};
  QString m_sizeFilter{"Any Size"};
  QString m_sortBy{"Name"};
  QString m_sortOrder{"ascending"};
  QStringList m_clipboardPaths;
  bool m_clipboardIsCut{false};
  bool m_foldersFirst{true};

  bool copyDirectory(const QString &srcPath, const QString &destPath);
  void scanDirectory();
  void pushHistory(const QString &path);
  void loadBookmarks();
  void saveBookmarks() const;
};

} // namespace xyla
