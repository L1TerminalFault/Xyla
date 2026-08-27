#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QThread>
#include <qfilesystemwatcher.h>
#include <qtmetamacros.h>

namespace xyla {

struct FileItem {
  QString name;
  QString filePath;
  bool isDir{false};
  qint64 size{0};
  int itemCount{0};
  QDateTime lastModified;
  QDateTime createdAt;
  QString extension;
};

// ------------------------------------------------------------------
// Bounded LRU cache of raw (unfiltered, unsorted) directory scans,
// keyed by absolute path. Lets cd-ing back into a directory skip a
// full disk rescan if it hasn't changed since we last read it.
// ------------------------------------------------------------------
struct DirectoryCacheEntry {
  QList<FileItem> items;
  QDateTime dirLastModified;
};

class DirectoryCache {
public:
  explicit DirectoryCache(int capacity = 200) : m_capacity(capacity) {}

  bool get(const QString &path, DirectoryCacheEntry &out);
  void insert(const QString &path, DirectoryCacheEntry entry);
  void remove(const QString &path);
  void clear();

private:
  int m_capacity;
  QHash<QString, DirectoryCacheEntry> m_entries;
  QStringList m_order; // least-recently-used at front, MRU at back
};

// ------------------------------------------------------------------
// Runs on a worker thread. Walks a directory and emits FileItems in
// small batches so the UI can populate incrementally instead of
// blocking on one big scan for the whole directory.
// ------------------------------------------------------------------
class DirectoryScanner : public QObject {
  Q_OBJECT
public:
  explicit DirectoryScanner(QObject *parent = nullptr) : QObject(parent) {}

public slots:
  void scan(const QString &path, quint64 requestId, bool showHidden);

signals:
  void batchReady(quint64 requestId, QList<xyla::FileItem> batch);
  void scanFinished(quint64 requestId, QDateTime dirLastModified);
};

class FileManagerSettings : public QObject {
  Q_OBJECT

  // System
  Q_PROPERTY(QString startupLocation READ startupLocation WRITE
                 setStartupLocation NOTIFY startupLocationChanged) // done
  Q_PROPERTY(QString defaultView READ defaultView WRITE setDefaultView NOTIFY
                 defaultViewChanged) // done
  Q_PROPERTY(bool rememberLastFolder READ rememberLastFolder WRITE
                 setRememberLastFolder NOTIFY rememberLastFolderChanged) // done
  Q_PROPERTY(bool confirmDelete READ confirmDelete WRITE setConfirmDelete NOTIFY
                 confirmDeleteChanged) // done

  // Appearance
  Q_PROPERTY(bool smoothAnimations READ smoothAnimations WRITE
                 setSmoothAnimations NOTIFY smoothAnimationsChanged)

  // Files & Folders
  Q_PROPERTY(bool showHiddenFiles READ showHiddenFiles WRITE setShowHiddenFiles
                 NOTIFY showHiddenFilesChanged) // done
  Q_PROPERTY(bool showFileExtensions READ showFileExtensions WRITE
                 setShowFileExtensions NOTIFY showFileExtensionsChanged) // done
  Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY
                 sortModeChanged) // done

  // Behavior
  Q_PROPERTY(bool openFoldersWithDoubleClick READ openFoldersWithDoubleClick
                 WRITE setOpenFoldersWithDoubleClick NOTIFY
                     openFoldersWithDoubleClickChanged) // done
  Q_PROPERTY(bool showTooltips READ showTooltips WRITE setShowTooltips NOTIFY
                 showTooltipsChanged)

public:
  explicit FileManagerSettings(QObject *parent = nullptr);

  // getters
  QString startupLocation() const { return m_startupLocation; };
  QString defaultView() const { return m_defaultView; };
  bool rememberLastFolder() const { return m_rememberLastFolder; };
  bool confirmDelete() const { return m_confirmDelete; };
  bool smoothAnimations() const { return m_smoothAnimations; };
  bool showHiddenFiles() const { return m_showHiddenFiles; };
  bool showFileExtensions() const { return m_showFileExtensions; };
  QString sortMode() const { return m_sortMode; };
  bool openFoldersWithDoubleClick() const { return m_openFoldersWithDoubleClick; };
  bool showTooltips() const { return m_showTooltips; };

  // setters
  void setStartupLocation(const QString &v);
  void setDefaultView(const QString &v);
  void setRememberLastFolder(bool v);
  void setConfirmDelete(bool v);
  void setSmoothAnimations(bool v);
  void setShowHiddenFiles(bool v);
  void setShowFileExtensions(bool v);
  void setSortMode(const QString &v);
  void setShowTooltips(bool v);
  void setOpenFoldersWithDoubleClick(bool v);

  Q_INVOKABLE void loadSettings();
  Q_INVOKABLE void saveSettings() const;
  Q_INVOKABLE void resetToDefaults();

signals:
  void startupLocationChanged();
  void defaultViewChanged();
  void rememberLastFolderChanged();
  void confirmDeleteChanged();
  void smoothAnimationsChanged();
  void showHiddenFilesChanged();
  void showFileExtensionsChanged();
  void sortModeChanged();
  void showTooltipsChanged();
  void openFoldersWithDoubleClickChanged();

private:
  void applyDefaults();

  QString m_startupLocation;
  QString m_defaultView;
  bool m_rememberLastFolder;
  bool m_confirmDelete;
  bool m_smoothAnimations;
  bool m_showHiddenFiles;
  bool m_showFileExtensions;
  QString m_sortMode;
  bool m_openFoldersWithDoubleClick;
  bool m_showTooltips;
};

class FileSystemModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(FileManagerSettings *fileManagerSettings READ fileManagerSettings
                 CONSTANT)

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
  Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
  Q_PROPERTY(QString createdAtFilter READ createdAtFilter WRITE
                 setCreatedAtFilter NOTIFY createdAtFilterChanged)

  Q_PROPERTY(QString modifiedAtFilter READ modifiedAtFilter WRITE
                 setModifiedAtFilter NOTIFY modifiedAtFilterChanged)

public:
  enum FileRoles {
    NameRole = Qt::UserRole + 1,
    PathRole,
    IsDirRole,
    SizeRole,
    ItemCountRole,
    CreatedAtRole,
    LastModifiedRole,
    ExtensionRole
  };

  Q_ENUM(FileRoles);

  explicit FileSystemModel(QObject *parent = nullptr);
  ~FileSystemModel() override;

  FileManagerSettings *fileManagerSettings() const {
    return m_fileManagerSettings;
  }

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
  QString createdAtFilter() const { return m_createdAtFilter; }
  QString modifiedAtFilter() const { return m_modifiedAtFilter; }
  QString sortBy() const { return m_sortBy; }
  QString sortOrder() const { return m_sortOrder; }
  bool foldersFirst() const { return m_foldersFirst; }
  bool loading() const { return m_loading; }

  void setFoldersFirst(bool first);
  void setTypeFilter(const QString &filter);
  void setSizeFilter(const QString &filter);
  void setSortBy(const QString &sortBy);
  void setSortOrder(const QString &sortOrder);
  void setCreatedAtFilter(const QString &filter);
  void setModifiedAtFilter(const QString &filter);

  Q_INVOKABLE void cd(const QString &path);
  Q_INVOKABLE void cdBack();
  Q_INVOKABLE void cdForward();
  Q_INVOKABLE void cdUp();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE QString makeFolder(const QString &folderName);
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
  Q_INVOKABLE void loadSettings();
  Q_INVOKABLE void saveSettings() const;

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
  void loadingChanged();
  void createdAtFilterChanged();
  void modifiedAtFilterChanged();

  // Internal: crosses to the worker thread via a queued connection.
  void requestScan(const QString &path, quint64 requestId, bool showHidden);

private slots:
  void onScanBatchReady(quint64 requestId, QList<xyla::FileItem> batch);
  void onScanFinished(quint64 requestId, QDateTime dirLastModified);
  void onDirectoryChanged(const QString &path);

private:
  QString m_lastError;
  QString m_currentPath;
  QList<FileItem> m_items;      // filtered + sorted, backs the model
  QList<FileItem> m_rawEntries; // unfiltered scan of m_currentPath
  QFileSystemWatcher m_dirWatcher;
  QStringList m_history;
  int m_historyIndex{-1};
  QString m_bookmarksFile;
  QStringList m_bookmarks;
  QSet<QString> m_bookmarkSet;
  QString m_nameFilter;
  QString m_typeFilter{"All Files"};
  QString m_sizeFilter{"Any Size"};
  QString m_createdAtFilter;
  QString m_modifiedAtFilter;
  QString m_sortBy{"Name"};
  QString m_sortOrder{"ascending"};
  QStringList m_clipboardPaths;
  bool m_clipboardIsCut{false};
  bool m_foldersFirst{true};

  DirectoryCache m_dirCache;
  FileManagerSettings *m_fileManagerSettings{nullptr};
  QThread m_scanThread;
  DirectoryScanner *m_scanner{nullptr};
  quint64 m_scanRequestId{0};
  bool m_loading{false};

  bool copyDirectory(const QString &srcPath, const QString &destPath);
  void scanDirectory();
  void applyFiltersAndSort();
  bool passesFilters(const FileItem &item) const;
  void pushHistory(const QString &path);
  void loadBookmarks();
  void saveBookmarks() const;
};

} // namespace xyla

Q_DECLARE_METATYPE(xyla::FileItem)
