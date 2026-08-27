#include "fileSystemManager.hpp"

#include <QClipboard>
#include <QDirIterator>
#include <QGuiApplication>
#include <QJsonArray>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>

namespace xyla {

bool DirectoryCache::get(const QString &path, DirectoryCacheEntry &out) {
  auto it = m_entries.find(path);
  if (it == m_entries.end())
    return false;

  out = it.value();
  m_order.removeAll(path);
  m_order.append(path); // mark as most recently used
  return true;
}

void DirectoryCache::insert(const QString &path, DirectoryCacheEntry entry) {
  if (!m_entries.contains(path) && m_entries.size() >= m_capacity) {
    const QString evict = m_order.takeFirst();
    m_entries.remove(evict);
  }
  m_entries.insert(path, std::move(entry));
  m_order.removeAll(path);
  m_order.append(path);
}

void DirectoryCache::remove(const QString &path) {
  m_entries.remove(path);
  m_order.removeAll(path);
}

void DirectoryCache::clear() {
  m_entries.clear();
  m_order.clear();
}

void DirectoryScanner::scan(const QString &path, quint64 requestId, bool showHidden) {
  QList<FileItem> batch;
  batch.reserve(32);

  QDir::Filters filters = QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot;
  if (showHidden)
    filters |= QDir::Hidden | QDir::System;

  // Use the filters variable
  QDirIterator it(path, filters);

  while (it.hasNext()) {
    it.next();
    const QFileInfo info = it.fileInfo();

    FileItem item;
    item.name = info.fileName();
    item.filePath = QDir::cleanPath(info.absoluteFilePath());
    item.isDir = info.isDir();
    item.size = info.size();
    item.lastModified = info.lastModified();
    item.createdAt = info.birthTime();
    item.extension = info.suffix().toLower();

    if (item.isDir) {
      QDir subDir(item.filePath);
      QDir::Filters countFilters = QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot;
      if (showHidden)
        countFilters |= QDir::Hidden | QDir::System;
      item.itemCount = static_cast<int>(subDir.entryList(countFilters).size());
    }

    batch.append(item);
    if (batch.size() >= 32) {
      emit batchReady(requestId, batch);
      batch.clear();
    }
  }

  if (!batch.isEmpty())
    emit batchReady(requestId, batch);

  emit scanFinished(requestId, QFileInfo(path).lastModified());
}

void FileSystemModel::onDirectoryChanged(const QString &path) {
  if (path != m_currentPath)
    return;

  // Evict old cache and scan directory again
  m_dirCache.remove(m_currentPath);
  scanDirectory();
}

FileSystemModel::FileSystemModel(QObject *parent) : QAbstractListModel(parent) {
  // ── Settings (owned by the model) ──────────────────────────────────────
  m_fileManagerSettings =
      new FileManagerSettings(this); // parented → automatic cleanup

  connect(m_fileManagerSettings, &FileManagerSettings::sortModeChanged, this,
          [this]() { setSortBy(m_fileManagerSettings->sortMode()); });

  connect(m_fileManagerSettings, &FileManagerSettings::showHiddenFilesChanged,
          this, [this]() {
            m_dirCache.remove(m_currentPath);
            scanDirectory();
          });

  setSortBy(m_fileManagerSettings->sortMode());

  QString startPath;

  if (m_fileManagerSettings->rememberLastFolder()) {
    QSettings s(QStringLiteral("xyla"), QStringLiteral("AppSettings"));
    startPath = s.value(QStringLiteral("lastPath")).toString();
  }

  if (startPath.isEmpty() || !QDir(startPath).exists()) {
    // Map the friendly name to a real path
    const QString loc = m_fileManagerSettings->startupLocation();
    if (loc == QLatin1String("Desktop"))
      startPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    else if (loc == QLatin1String("Documents"))
      startPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    else if (loc == QLatin1String("Downloads"))
      startPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    else // "Home" or anything else
      startPath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
  }

  m_currentPath = QDir::cleanPath(startPath);
  // done settings setup

  qRegisterMetaType<QList<xyla::FileItem>>("QList<xyla::FileItem>");

  // m_currentPath = QDir::homePath();

  const QString appData =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  QDir().mkpath(appData);
  m_bookmarksFile = QDir(appData).filePath("XylaBookmarks.json");
  loadBookmarks();

  m_scanner = new DirectoryScanner();
  m_scanner->moveToThread(&m_scanThread);

  connect(&m_scanThread, &QThread::finished, m_scanner, &QObject::deleteLater);
  connect(this, &FileSystemModel::requestScan, m_scanner,
          &DirectoryScanner::scan);
  connect(m_scanner, &DirectoryScanner::batchReady, this,
          &FileSystemModel::onScanBatchReady);
  connect(m_scanner, &DirectoryScanner::scanFinished, this,
          &FileSystemModel::onScanFinished);
  connect(&m_dirWatcher, &QFileSystemWatcher::directoryChanged, this,
          &FileSystemModel::onDirectoryChanged);

  m_scanThread.start();

  pushHistory(m_currentPath);

  m_dirWatcher.addPath(m_currentPath);
  scanDirectory();
}

FileSystemModel::~FileSystemModel() {
  m_scanThread.quit();
  m_scanThread.wait();
}

int FileSystemModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return static_cast<int>(m_items.size());
}

QVariant FileSystemModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
    return QVariant();

  const auto &item = m_items[index.row()];

  switch (role) {
  case NameRole: {
    if (item.isDir || !m_fileManagerSettings || m_fileManagerSettings->showFileExtensions())
      return item.name;

    // Strip the extension for files
    const int dot = item.name.lastIndexOf(QLatin1Char('.'));
    if (dot > 0)   // keep names that start with a dot (hidden files)
      return item.name.left(dot);
    return item.name;
  }
  case PathRole:
    return item.filePath;
  case IsDirRole:
    return item.isDir;
  case SizeRole:
    return item.size;
  case ItemCountRole:
    return item.itemCount;
  case CreatedAtRole:
    return item.createdAt;
  case LastModifiedRole:
    return item.lastModified;
  case ExtensionRole:
    return item.extension;
  default:
    return QVariant();
  }
}

QVariantList FileSystemModel::pathCompletions(const QString &path) const {
  QVariantList result;

  const int slash = std::max(path.lastIndexOf('/'), path.lastIndexOf('\\'));

  QString dirPath;
  QString partial;

  if (slash >= 0) {
    dirPath = (slash == 0) ? QDir::rootPath() : path.left(slash);
    partial = path.mid(slash + 1);
  } else {
    dirPath = QDir::homePath();
    partial = path;
  }

  QDir dir(dirPath);

  if (!dir.exists())
    return result;

  const QFileInfoList entries =
      dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot,
                        QDir::Name | QDir::IgnoreCase);

  for (const QFileInfo &info : entries) {
    if (!info.fileName().startsWith(partial, Qt::CaseInsensitive))
      continue;

    QVariantMap item;
    item["name"] = info.fileName();
    item["path"] = QDir::fromNativeSeparators(info.absoluteFilePath());
    item["isFolder"] = info.isDir();

    result.append(item);
  }

  return result;
}

QVariantList FileSystemModel::quickAccessItems() const {
  QVariantList result;

  // ------------------------------------------------------------
  // Devices
  // ------------------------------------------------------------

  for (const QStorageInfo &storage : QStorageInfo::mountedVolumes()) {
    if (!storage.isValid() || !storage.isReady())
      continue;

    const QString path = storage.rootPath();

    QVariantMap item;
    item["section"] = "Devices";
    item["name"] =
        storage.displayName().isEmpty() ? path : storage.displayName();
    item["path"] = path;
    item["bookmarked"] = isBookmarked(path);

    result.append(item);
  }

  // ------------------------------------------------------------
  // Common folders
  // ------------------------------------------------------------

  const QList<QPair<QString, QString>> commonFolders = {
      {"Home", QStandardPaths::writableLocation(QStandardPaths::HomeLocation)},
      {"Desktop",
       QStandardPaths::writableLocation(QStandardPaths::DesktopLocation)},
      {"Documents",
       QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)},
      {"Downloads",
       QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)},
      {"Pictures",
       QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)},
      {"Music",
       QStandardPaths::writableLocation(QStandardPaths::MusicLocation)},
      {"Videos",
       QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)}};

  for (const auto &[name, path] : commonFolders) {
    if (path.isEmpty() || !QDir(path).exists())
      continue;

    QVariantMap item;
    item["section"] = "Common";
    item["name"] = name;
    item["path"] = QDir(path).absolutePath();
    item["bookmarked"] = isBookmarked(path);

    result.append(item);
  }

  // ------------------------------------------------------------
  // Bookmarks
  // ------------------------------------------------------------

  for (const QVariant &path : m_bookmarks) {
    if (!QDir(path.toString()).exists())
      continue;

    QVariantMap item;
    item["section"] = "Bookmarks";
    item["name"] = QFileInfo(path.toString()).fileName();
    item["path"] = path;
    item["bookmarked"] = true;

    result.append(item);
  }

  return result;
}

QHash<int, QByteArray> FileSystemModel::roleNames() const {
  return {{NameRole, "fileName"},
          {PathRole, "filePath"},
          {IsDirRole, "isDir"},
          {SizeRole, "fileSize"},
          {ItemCountRole, "itemCount"},
          {CreatedAtRole, "createdAt"},
          {LastModifiedRole, "lastModified"},
          {ExtensionRole, "extension"}};
}

QString FileSystemModel::parentPath() const {
  QDir dir(m_currentPath);
  dir.cdUp();
  return QDir::cleanPath(dir.absolutePath());
}

void FileSystemModel::setCurrentPath(const QString &path) {
  QDir dir(path);
  const QString cleanTarget = QDir::cleanPath(dir.absolutePath());
  if (dir.exists() && m_currentPath != cleanTarget) {
    // Unwatch old path and watch new path
    if (!m_currentPath.isEmpty()) {
      m_dirWatcher.removePath(m_currentPath);
    }

    m_currentPath = cleanTarget;
    m_dirWatcher.addPath(m_currentPath);

    pushHistory(m_currentPath);
    scanDirectory();

    if (m_fileManagerSettings && m_fileManagerSettings->rememberLastFolder()) {
      QSettings s(QStringLiteral("xyla"), QStringLiteral("AppSettings"));
      s.setValue(QStringLiteral("lastPath"), m_currentPath);
    }

    emit currentPathChanged();
  }
}

void FileSystemModel::cd(const QString &path) { setCurrentPath(path); }

void FileSystemModel::cdBack() {
  if (canCdBack()) {
    m_historyIndex--;
    m_currentPath = m_history[m_historyIndex];
    scanDirectory();
    emit currentPathChanged();
    emit canCdBackChanged();
    emit canCdForwardChanged();
  }
}

void FileSystemModel::cdForward() {
  if (canCdForward()) {
    m_historyIndex++;
    m_currentPath = m_history[m_historyIndex];
    scanDirectory();
    emit currentPathChanged();
    emit canCdBackChanged();
    emit canCdForwardChanged();
  }
}

void FileSystemModel::cdUp() { setCurrentPath(parentPath()); }

void FileSystemModel::refresh() {
  m_dirCache.remove(m_currentPath);

  // Ensure watcher is active for current directory
  if (!m_dirWatcher.directories().contains(m_currentPath) &&
      QDir(m_currentPath).exists()) {
    m_dirWatcher.addPath(m_currentPath);
  }

  scanDirectory();
}

void FileSystemModel::setNameFilter(const QString &filter) {
  if (m_nameFilter == filter)
    return;
  m_nameFilter = filter;
  emit nameFilterChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setTypeFilter(const QString &filter) {
  if (m_typeFilter == filter)
    return;
  m_typeFilter = filter;
  emit typeFilterChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setSizeFilter(const QString &filter) {
  if (m_sizeFilter == filter)
    return;
  m_sizeFilter = filter;
  emit sizeFilterChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setSortBy(const QString &sortBy) {
  if (m_sortBy == sortBy)
    return;
  m_sortBy = sortBy;
  emit sortByChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setSortOrder(const QString &sortOrder) {
  if (m_sortOrder == sortOrder)
    return;
  m_sortOrder = sortOrder;
  emit sortOrderChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setFoldersFirst(bool first) {
  if (m_foldersFirst == first)
    return;
  m_foldersFirst = first;
  emit foldersFirstChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setCreatedAtFilter(const QString &filter) {
  if (m_createdAtFilter == filter)
    return;

  m_createdAtFilter = filter;
  emit createdAtFilterChanged();
  applyFiltersAndSort();
}

void FileSystemModel::setModifiedAtFilter(const QString &filter) {
  if (m_modifiedAtFilter == filter)
    return;

  m_modifiedAtFilter = filter;
  emit modifiedAtFilterChanged();
  applyFiltersAndSort();
}

QString FileSystemModel::makeFolder(const QString &folderName) {
  m_lastError.clear();

  if (m_currentPath.isEmpty()) {
    m_lastError = "Invalid path.";
    emit lastErrorChanged();
    return QString();
  }

  QString baseName = folderName.trimmed();
  if (baseName.isEmpty()) {
    baseName = "New folder";
  }

  if (baseName == "." || baseName == "..") {
    m_lastError = "Invalid folder name.";
    emit lastErrorChanged();
    return QString();
  }

  QDir dir(m_currentPath);
  QString targetName = baseName;
  int counter = 1;

  // Auto-increment name if collisions exist ("New folder", "New folder (1)",
  // etc.)
  while (dir.exists(targetName)) {
    targetName = QString("%1 (%2)").arg(baseName).arg(counter++);
  }

  if (!dir.mkdir(targetName)) {
    m_lastError = QString("Could not create folder \"%1\".").arg(targetName);
    emit lastErrorChanged();
    return QString();
  }

  scanDirectory();
  emit lastErrorChanged();

  // Return created folder name so QML can locate and highlight it
  return targetName;
}
// bool FileSystemModel::makeFolder(const QString &folderName) {
//   const QString name = folderName.trimmed();
//   m_lastError.clear();
//
//   if (name.isEmpty()) {
//     m_lastError = "Folder name cannot be empty.";
//     emit lastErrorChanged();
//     return false;
//   }
//
//   if (name == "." || name == "..") {
//     m_lastError = "Invalid folder name.";
//     emit lastErrorChanged();
//     return false;
//   }
//
//   QDir dir(m_currentPath);
//
//   if (dir.exists(name)) {
//     m_lastError = QString("A folder named \"%1\" already exists.").arg(name);
//
//     emit lastErrorChanged();
//     return false;
//   }
//
//   if (!dir.mkdir(name)) {
//     m_lastError = QString("Could not create folder \"%1\".").arg(name);
//
//     emit lastErrorChanged();
//     return false;
//   }
//
//   scanDirectory();
//   emit lastErrorChanged();
//
//   return true;
// }

void FileSystemModel::pushHistory(const QString &path) {
  if (m_historyIndex < m_history.size() - 1) {
    m_history.erase(m_history.begin() + m_historyIndex + 1, m_history.end());
  }
  m_history.append(path);
  m_historyIndex = m_history.size() - 1;

  emit canCdBackChanged();
  emit canCdForwardChanged();
}

// ---------------------------------------------------------------
QVariantMap FileSystemModel::get(int index) const {
  QVariantMap map;
  if (index < 0 || index >= m_items.size())
    return map;

  const FileItem &item = m_items[index];
  map["fileName"] = item.name;
  map["filePath"] = QDir::fromNativeSeparators(item.filePath);
  map["isDir"] = item.isDir;
  map["fileSize"] = item.size;
  map["itemCount"] = item.itemCount;
  map["extension"] = item.extension;
  map["lastModified"] = item.lastModified;
  return map;
}

// ---------------------------------------------------------------
void FileSystemModel::cut(const QStringList &paths) {
  m_clipboardPaths = paths;
  m_clipboardIsCut = true;
  emit clipboardChanged();
}

void FileSystemModel::copy(const QStringList &paths) {
  m_clipboardPaths = paths;
  m_clipboardIsCut = false;
  emit clipboardChanged();
}

bool FileSystemModel::canPaste() const { return !m_clipboardPaths.isEmpty(); }

Q_INVOKABLE void FileSystemModel::copyToClipboard(const QString &text) {
  QGuiApplication::clipboard()->setText(text);
}

// ---------------------------------------------------------------
bool FileSystemModel::paste(const QString &targetDir) {
  m_lastError.clear();
  const QString destDir = targetDir.isEmpty() ? m_currentPath : targetDir;

  if (m_clipboardPaths.isEmpty()) {
    m_lastError = "Clipboard is empty.";
    emit lastErrorChanged();
    return false;
  }

  for (const QString &src : m_clipboardPaths) {
    QFileInfo srcInfo(src);
    if (!srcInfo.exists())
      continue;

    QString destPath = QDir(destDir).filePath(srcInfo.fileName());

    // Avoid overwriting – add suffix if needed
    int counter = 1;
    while (QFileInfo::exists(destPath)) {
      QString base = srcInfo.completeBaseName();
      QString ext = srcInfo.suffix();
      QString filename =
          ext.isEmpty()
              ? QString("%1 (%2)").arg(base).arg(counter++)
              : QString("%1 (%2).%3").arg(base).arg(counter++).arg(ext);
      destPath = QDir(destDir).filePath(filename);
    }

    bool ok = false;
    if (m_clipboardIsCut) {
      ok = QFile::rename(src, destPath);
    } else {
      if (srcInfo.isDir()) {
        // Simple recursive copy for directories
        ok = copyDirectory(src, destPath);
      } else {
        ok = QFile::copy(src, destPath);
      }
    }

    if (!ok) {
      m_lastError = QString("Failed to paste \"%1\"").arg(srcInfo.fileName());
      emit lastErrorChanged();
      scanDirectory();
      return false;
    }
  }

  if (m_clipboardIsCut) {
    m_clipboardPaths.clear();
    emit clipboardChanged();
  }

  scanDirectory();
  emit lastErrorChanged();
  return true;
}

// Helper (put in private section of the class)
bool FileSystemModel::copyDirectory(const QString &srcPath,
                                    const QString &destPath) {
  QDir srcDir(srcPath);
  if (!srcDir.exists())
    return false;

  QDir().mkpath(destPath);

  const auto entries =
      srcDir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
  for (const QFileInfo &info : entries) {
    const QString src = info.absoluteFilePath();
    const QString dest = QDir(destPath).filePath(info.fileName());

    if (info.isDir()) {
      if (!copyDirectory(src, dest))
        return false;
    } else {
      if (!QFile::copy(src, dest))
        return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------
bool FileSystemModel::rename(const QString &oldPath, const QString &newName) {
  m_lastError.clear();
  const QString name = newName.trimmed();

  if (name.isEmpty()) {
    m_lastError = "Name cannot be empty.";
    emit lastErrorChanged();
    return false;
  }

  QFileInfo info(oldPath);
  QString newPath = QDir(info.absolutePath()).filePath(name);

  if (QFileInfo::exists(newPath)) {
    m_lastError = QString("\"%1\" already exists.").arg(name);
    emit lastErrorChanged();
    return false;
  }

  if (!QFile::rename(oldPath, newPath)) {
    m_lastError = QString("Could not rename to \"%1\".").arg(name);
    emit lastErrorChanged();
    return false;
  }

  scanDirectory();
  emit lastErrorChanged();
  return true;
}

// ---------------------------------------------------------------
bool FileSystemModel::moveToTrash(const QStringList &paths) {
  m_lastError.clear();

  for (const QString &path : paths) {
    if (!QFile::moveToTrash(path)) { // Qt 5.15+ / Qt 6
      m_lastError = QString("Could not move \"%1\" to trash.")
                        .arg(QFileInfo(path).fileName());
      emit lastErrorChanged();
      scanDirectory();
      return false;
    }
  }

  scanDirectory();
  emit lastErrorChanged();
  return true;
}

void FileSystemModel::scanDirectory() {
  DirectoryCacheEntry cached;
  const QDateTime currentMtime = QFileInfo(m_currentPath).lastModified();

  if (m_dirCache.get(m_currentPath, cached) &&
      cached.dirLastModified == currentMtime) {
    // Unchanged on disk since last visit — skip the async scan entirely.
    m_rawEntries = cached.items;
    applyFiltersAndSort();
    return;
  }

  ++m_scanRequestId; // invalidates any scan still in flight for the old path

  m_rawEntries.clear();
  applyFiltersAndSort(); // clears the visible list immediately

  m_loading = true;
  emit loadingChanged();

  emit requestScan(m_currentPath, m_scanRequestId, m_fileManagerSettings ? m_fileManagerSettings->showHiddenFiles() : false);
}

void FileSystemModel::onScanBatchReady(quint64 requestId,
                                       QList<xyla::FileItem> batch) {
  if (requestId != m_scanRequestId)
    return;

  m_rawEntries.append(batch);

  QList<FileItem> visibleBatch;
  visibleBatch.reserve(batch.size());

  for (const FileItem &item : batch) {
    if (passesFilters(item))
      visibleBatch.append(item);
  }

  if (visibleBatch.isEmpty())
    return;

  const int first = m_items.size();
  const int last = first + visibleBatch.size() - 1;

  beginInsertRows(QModelIndex(), first, last);

  for (const FileItem &item : visibleBatch)
    m_items.append(item);

  endInsertRows();
}

// void FileSystemModel::onScanBatchReady(quint64 requestId,
//                                        QList<xyla::FileItem> batch) {
//   if (requestId != m_scanRequestId)
//     return; // stale — user has since navigated elsewhere
//
//   m_rawEntries.append(batch);
//
//   // Insert just this batch as it arrives, so items pop in live.
//   for (const FileItem &item : batch) {
//     if (!passesFilters(item))
//       continue;
//
//     beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
//     m_items.append(item);
//     endInsertRows();
//   }
// }

void FileSystemModel::onScanFinished(quint64 requestId,
                                     QDateTime dirLastModified) {
  if (requestId != m_scanRequestId)
    return;

  m_dirCache.insert(m_currentPath, {m_rawEntries, dirLastModified});

  // Batches arrive in filesystem order, not sorted order — snap into the
  // requested sort now that the scan is complete.
  applyFiltersAndSort();

  m_loading = false;
  emit loadingChanged();
}

bool FileSystemModel::passesFilters(const FileItem &item) const {
  if (!m_nameFilter.isEmpty() &&
      !item.name.contains(m_nameFilter, Qt::CaseInsensitive))
    return false;

  if (m_typeFilter == "__NONE__")
    return false;

  if (!m_typeFilter.isEmpty() && m_typeFilter != "All Files") {
    const QStringList allowed = m_typeFilter.split(',', Qt::SkipEmptyParts);

    bool match = false;

    for (QString raw : allowed) {
      const QString t = raw.trimmed();

      if (t == "Folders") {
        if (item.isDir) {
          match = true;
          break;
        }
      } else if (t == "Files") {
        if (!item.isDir) {
          match = true;
          break;
        }
      } else if (t == "Images") {
        static const QStringList img = {"jpg",  "jpeg", "png", "gif", "bmp",
                                        "webp", "svg",  "tif", "tiff"};

        if (!item.isDir && img.contains(item.extension)) {
          match = true;
          break;
        }
      } else if (t == "Videos") {
        static const QStringList vid = {"mp4",  "mkv", "avi", "mov",
                                        "webm", "wmv", "m4v", "flv"};

        if (!item.isDir && vid.contains(item.extension)) {
          match = true;
          break;
        }
      } else if (t == "Audio") {
        static const QStringList aud = {"mp3", "wav", "flac", "ogg",
                                        "aac", "m4a", "opus", "wma"};

        if (!item.isDir && aud.contains(item.extension)) {
          match = true;
          break;
        }
      } else if (t == "Documents") {
        static const QStringList doc = {"pdf", "doc", "docx", "txt",
                                        "rtf", "odt", "xls",  "xlsx",
                                        "csv", "ppt", "pptx", "odp"};

        if (!item.isDir && doc.contains(item.extension)) {
          match = true;
          break;
        }
      }
    }

    if (!match)
      return false;
  }

  // ------------------------------------------------------------
  // SIZE
  // ------------------------------------------------------------

  const qint64 size = item.size;

  if (m_sizeFilter == "Empty" && size != 0)
    return false;

  if (m_sizeFilter == "Under 1 MB" && size >= 1024 * 1024)
    return false;

  if (m_sizeFilter == "1–10 MB" &&
      (size < 1024 * 1024 || size >= 10 * 1024 * 1024))
    return false;

  if (m_sizeFilter == "10–100 MB" &&
      (size < 10 * 1024 * 1024 || size >= 100 * 1024 * 1024))
    return false;

  if (m_sizeFilter == "Over 100 MB" && size <= 100 * 1024 * 1024)
    return false;

  // ------------------------------------------------------------
  // CREATED AT / MODIFIED AT
  // ------------------------------------------------------------

  const QDateTime now = QDateTime::currentDateTime();
  const QDate today = now.date();

  auto matchesDateFilter = [&](const QDateTime &date,
                               const QString &filter) -> bool {
    if (filter.isEmpty() || filter == "Any Time")
      return true;

    if (!date.isValid())
      return false;

    const QDate fileDate = date.date();

    if (filter == "Today") {
      return fileDate == today;
    }

    if (filter == "Yesterday") {
      return fileDate == today.addDays(-1);
    }

    if (filter == "Last 7 Days") {
      return date >= now.addDays(-7);
    }

    if (filter == "Last 30 Days") {
      return date >= now.addDays(-30);
    }

    if (filter == "This Year") {
      return fileDate.year() == today.year();
    }

    return true;
  };

  if (!matchesDateFilter(item.createdAt, m_createdAtFilter))
    return false;

  if (!matchesDateFilter(item.lastModified, m_modifiedAtFilter))
    return false;

  return true;
}
// bool FileSystemModel::passesFilters(const FileItem &item) const {
//   if (!m_nameFilter.isEmpty() &&
//       !item.name.contains(m_nameFilter, Qt::CaseInsensitive))
//     return false;
//
//   if (m_typeFilter == "__NONE__")
//     return false;
//
//   if (!m_typeFilter.isEmpty() && m_typeFilter != "All Files") {
//     const QStringList allowed = m_typeFilter.split(',', Qt::SkipEmptyParts);
//     bool match = false;
//
//     for (QString raw : allowed) {
//       const QString t = raw.trimmed();
//
//       if (t == "Folders") {
//         if (item.isDir) {
//           match = true;
//           break;
//         }
//       } else if (t == "Files") {
//         if (!item.isDir) {
//           match = true;
//           break;
//         }
//       } else if (t == "Images") {
//         static const QStringList img = {"jpg",  "jpeg", "png", "gif", "bmp",
//                                         "webp", "svg",  "tif", "tiff"};
//         if (!item.isDir && img.contains(item.extension)) {
//           match = true;
//           break;
//         }
//       } else if (t == "Videos") {
//         static const QStringList vid = {"mp4",  "mkv", "avi", "mov",
//                                         "webm", "wmv", "m4v", "flv"};
//         if (!item.isDir && vid.contains(item.extension)) {
//           match = true;
//           break;
//         }
//       } else if (t == "Audio") {
//         static const QStringList aud = {"mp3", "wav", "flac", "ogg",
//                                         "aac", "m4a", "opus", "wma"};
//         if (!item.isDir && aud.contains(item.extension)) {
//           match = true;
//           break;
//         }
//       } else if (t == "Documents") {
//         static const QStringList doc = {"pdf", "doc", "docx", "txt",
//                                         "rtf", "odt", "xls",  "xlsx",
//                                         "csv", "ppt", "pptx", "odp"};
//         if (!item.isDir && doc.contains(item.extension)) {
//           match = true;
//           break;
//         }
//       }
//     }
//
//     if (!match)
//       return false;
//   }
//
//   const qint64 size = item.size;
//   if (m_sizeFilter == "Empty" && size != 0)
//     return false;
//   if (m_sizeFilter == "Under 1 MB" && size >= 1024 * 1024)
//     return false;
//   if (m_sizeFilter == "1–10 MB" &&
//       (size < 1024 * 1024 || size >= 10 * 1024 * 1024))
//     return false;
//   if (m_sizeFilter == "10–100 MB" &&
//       (size < 10 * 1024 * 1024 || size >= 100 * 1024 * 1024))
//     return false;
//   if (m_sizeFilter == "Over 100 MB" && size <= 100 * 1024 * 1024)
//     return false;
//
//   return true;
// }

void FileSystemModel::applyFiltersAndSort() {
  beginResetModel();
  m_items.clear();

  for (const FileItem &item : m_rawEntries)
    if (passesFilters(item))
      m_items.append(item);

  std::sort(
      m_items.begin(), m_items.end(),
      [this](const FileItem &a, const FileItem &b) {
        if (a.isDir != b.isDir)
          return m_foldersFirst ? (a.isDir > b.isDir) : (a.isDir < b.isDir);

        bool result = false;
        if (m_sortBy == "Name")
          result = QString::localeAwareCompare(a.name, b.name) < 0;
        else if (m_sortBy == "Date Modified")
          result = a.lastModified < b.lastModified;
        else if (m_sortBy == "Size")
          result = a.size < b.size;
        else if (m_sortBy == "Type")
          result = QString::localeAwareCompare(a.extension, b.extension) < 0;
        else
          result = QString::localeAwareCompare(a.name, b.name) < 0;

        return m_sortOrder == "ascending" ? result : !result;
      });

  endResetModel();
}

void FileSystemModel::loadBookmarks() {
  m_bookmarks.clear();
  m_bookmarkSet.clear();

  QFile file(m_bookmarksFile);
  if (!file.open(QIODevice::ReadOnly))
    return;

  const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
  if (!doc.isArray())
    return;

  for (const auto &value : doc.array()) {
    const QString path = value.toString();
    if (QDir(path).exists()) {
      const QString abs = QDir(path).absolutePath();
      m_bookmarks.append(abs);
      m_bookmarkSet.insert(abs);
    }
  }
}

void FileSystemModel::saveBookmarks() const {
  QJsonArray array;
  for (const QString &path : m_bookmarks)
    array.append(path);

  QFile file(m_bookmarksFile);
  if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
}

bool FileSystemModel::isBookmarked(const QString &path) const {
  return m_bookmarkSet.contains(QDir::cleanPath(QDir(path).absolutePath()));
}

bool FileSystemModel::toggleBookmark(const QString &path) {
  const QString absolutePath = QDir::cleanPath(QDir(path).absolutePath());
  if (!QFileInfo::exists(absolutePath))
    return false;

  if (m_bookmarkSet.contains(absolutePath)) {
    m_bookmarks.removeAll(absolutePath);
    m_bookmarkSet.remove(absolutePath);
  } else {
    m_bookmarks.append(absolutePath);
    m_bookmarkSet.insert(absolutePath);
  }

  saveBookmarks();
  emit bookmarksChanged();
  return true;
}

void FileSystemModel::loadSettings() {
  QSettings settings("xyla", "FileSystemModel");

  // Retrieve settings with fallback defaults if keys don't exist yet
  setSortBy(settings.value("sortBy", "Name").toString());
  setSortOrder(settings.value("sortOrder", "ascending").toString());
  setFoldersFirst(settings.value("foldersFirst", true).toBool());
  setTypeFilter(settings.value("typeFilter", "All Files").toString());
  setSizeFilter(settings.value("sizeFilter", "Any Size").toString());

  // Optional: restore filter strings if saved
  setNameFilter(settings.value("nameFilter", "").toString());
}

void FileSystemModel::saveSettings() const {
  QSettings settings("xyla", "FileSystemModel");

  // Write persistent configuration properties to disk
  settings.setValue("sortBy", m_sortBy);
  settings.setValue("sortOrder", m_sortOrder);
  settings.setValue("foldersFirst", m_foldersFirst);
  settings.setValue("typeFilter", m_typeFilter);
  settings.setValue("sizeFilter", m_sizeFilter);
  settings.setValue("nameFilter", m_nameFilter);

  // Force write to disk immediately (QSettings also syncs automatically on
  // destruction)
  settings.sync();
}

} // namespace xyla
//

#include <QSettings>
#include <QStandardPaths>

namespace xyla {

FileManagerSettings::FileManagerSettings(QObject *parent) : QObject(parent) {
  applyDefaults();
  loadSettings(); // load immediately so values are ready
}

void FileManagerSettings::applyDefaults() {
  m_startupLocation = QStringLiteral("Home");
  m_defaultView = QStringLiteral("Grid");
  m_rememberLastFolder = true;
  m_confirmDelete = true;
  m_smoothAnimations = true;
  m_showHiddenFiles = false;
  m_showFileExtensions = true;
  m_sortMode = QStringLiteral("Name");
  m_openFoldersWithDoubleClick = true;
  m_showTooltips = true;
}

void FileManagerSettings::loadSettings() {
  QSettings s(QStringLiteral("xyla"), QStringLiteral("AppSettings"));

  m_startupLocation =
      s.value(QStringLiteral("startupLocation"), m_startupLocation).toString();
  m_defaultView =
      s.value(QStringLiteral("defaultView"), m_defaultView).toString();
  m_rememberLastFolder =
      s.value(QStringLiteral("rememberLastFolder"), m_rememberLastFolder)
          .toBool();
  m_confirmDelete =
      s.value(QStringLiteral("confirmDelete"), m_confirmDelete).toBool();
  m_smoothAnimations =
      s.value(QStringLiteral("smoothAnimations"), m_smoothAnimations).toBool();
  m_showHiddenFiles =
      s.value(QStringLiteral("showHiddenFiles"), m_showHiddenFiles).toBool();
  m_showFileExtensions =
      s.value(QStringLiteral("showFileExtensions"), m_showFileExtensions)
          .toBool();
  m_sortMode = s.value(QStringLiteral("sortMode"), m_sortMode).toString();
  m_openFoldersWithDoubleClick =
      s.value(QStringLiteral("openFoldersWithDoubleClick"),
              m_openFoldersWithDoubleClick)
          .toBool();
  m_showTooltips =
      s.value(QStringLiteral("showTooltips"), m_showTooltips).toBool();

  // Notify QML that everything is ready (optional but useful)
  emit startupLocationChanged();
  emit defaultViewChanged();
  emit rememberLastFolderChanged();
  emit confirmDeleteChanged();
  emit smoothAnimationsChanged();
  emit showHiddenFilesChanged();
  emit showFileExtensionsChanged();
  emit sortModeChanged();
  emit openFoldersWithDoubleClickChanged();
  emit showTooltipsChanged();
}

void FileManagerSettings::saveSettings() const {
  QSettings s(QStringLiteral("xyla"), QStringLiteral("AppSettings"));

  s.setValue(QStringLiteral("startupLocation"), m_startupLocation);
  s.setValue(QStringLiteral("defaultView"), m_defaultView);
  s.setValue(QStringLiteral("rememberLastFolder"), m_rememberLastFolder);
  s.setValue(QStringLiteral("confirmDelete"), m_confirmDelete);
  s.setValue(QStringLiteral("smoothAnimations"), m_smoothAnimations);
  s.setValue(QStringLiteral("showHiddenFiles"), m_showHiddenFiles);
  s.setValue(QStringLiteral("showFileExtensions"), m_showFileExtensions);
  s.setValue(QStringLiteral("sortMode"), m_sortMode);
  s.setValue(QStringLiteral("openFoldersWithDoubleClick"),
             m_openFoldersWithDoubleClick);
  s.setValue(QStringLiteral("showTooltips"), m_showTooltips);

  s.sync();
}

void FileManagerSettings::resetToDefaults() {
  applyDefaults();
  saveSettings();

  emit startupLocationChanged();
  emit defaultViewChanged();
  emit rememberLastFolderChanged();
  emit confirmDeleteChanged();
  emit smoothAnimationsChanged();
  emit showHiddenFilesChanged();
  emit showFileExtensionsChanged();
  emit sortModeChanged();
  emit openFoldersWithDoubleClickChanged();
  emit showTooltipsChanged();
}

// ── Setters (auto-save on every change) ──────────────────────────────────

void FileManagerSettings::setStartupLocation(const QString &v) {
  if (m_startupLocation == v)
    return;
  m_startupLocation = v;
  emit startupLocationChanged();
  saveSettings();
}

void FileManagerSettings::setDefaultView(const QString &v) {
  if (m_defaultView == v)
    return;
  m_defaultView = v;
  emit defaultViewChanged();
  saveSettings();
}

void FileManagerSettings::setRememberLastFolder(bool v) {
  if (m_rememberLastFolder == v)
    return;
  m_rememberLastFolder = v;
  emit rememberLastFolderChanged();
  saveSettings();
}

void FileManagerSettings::setConfirmDelete(bool v) {
  if (m_confirmDelete == v)
    return;
  m_confirmDelete = v;
  emit confirmDeleteChanged();
  saveSettings();
}

void FileManagerSettings::setSmoothAnimations(bool v) {
  if (m_smoothAnimations == v)
    return;
  m_smoothAnimations = v;
  emit smoothAnimationsChanged();
  saveSettings();
}

void FileManagerSettings::setShowHiddenFiles(bool v) {
  if (m_showHiddenFiles == v)
    return;
  m_showHiddenFiles = v;
  emit showHiddenFilesChanged();
  saveSettings();
}

void FileManagerSettings::setShowFileExtensions(bool v) {
  if (m_showFileExtensions == v)
    return;
  m_showFileExtensions = v;
  emit showFileExtensionsChanged();
  saveSettings();
}

void FileManagerSettings::setSortMode(const QString &v) {
  if (m_sortMode == v)
    return;
  m_sortMode = v;
  emit sortModeChanged();
  saveSettings();
}

void FileManagerSettings::setOpenFoldersWithDoubleClick(bool v) {
  if (m_openFoldersWithDoubleClick == v)
    return;
  m_openFoldersWithDoubleClick = v;
  emit openFoldersWithDoubleClickChanged();
  saveSettings();
}

void FileManagerSettings::setShowTooltips(bool v) {
  if (m_showTooltips == v)
    return;
  m_showTooltips = v;
  emit showTooltipsChanged();
  saveSettings();
}

} // namespace xyla
