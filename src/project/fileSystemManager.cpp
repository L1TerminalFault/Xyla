#include "fileSystemManager.hpp"

#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QStandardPaths>
#include <QStorageInfo>
#include <qhashfunctions.h>

namespace xyla {

FileSystemModel::FileSystemModel(QObject *parent) : QAbstractListModel(parent) {

  m_currentPath = QDir::homePath();

  const QString appData =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

  QDir().mkpath(appData);

  // WARN: Breaking change here, previous bookmark file was "bookmarks.json"
  m_bookmarksFile = QDir(appData).filePath("XylaBookmarks.json");

  loadBookmarks();

  pushHistory(m_currentPath);
  scanDirectory();
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
  case NameRole:
    return item.name;
  case PathRole:
    return item.filePath;
  case IsDirRole:
    return item.isDir;
  case SizeRole:
    return item.size;
  case ItemCountRole:
    return item.itemCount;
  case LastModifiedRole:
    return item.lastModified;
  case ExtensionRole:
    return item.extension;
  default:
    return QVariant();
  }
}

void FileSystemModel::loadBookmarks() {
  m_bookmarks.clear();

  QFile file(m_bookmarksFile);

  if (!file.open(QIODevice::ReadOnly))
    return;

  const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());

  if (!doc.isArray())
    return;

  for (const auto &value : doc.array()) {
    const QString path = value.toString();

    if (QDir(path).exists())
      m_bookmarks.append(QDir(path).absolutePath());
  }
}

void FileSystemModel::saveBookmarks() const {
  QJsonArray array;

  for (const QVariant &item : m_bookmarks.toList()) {
    QString path = item.toString();
    array.append(path);
  }

  QFile file(m_bookmarksFile);

  if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
}

bool FileSystemModel::isBookmarked(const QString &path) const {
  return m_bookmarks.contains(QDir::cleanPath(QDir(path).absolutePath()));
}

bool FileSystemModel::toggleBookmark(const QString &path) {
  const QString absolutePath = QDir::cleanPath(QDir(path).absolutePath());

  if (!QFileInfo::exists(absolutePath))
    return false;

  if (m_bookmarks.contains(absolutePath))
    m_bookmarks.removeAll(absolutePath);
  else
    m_bookmarks.append(absolutePath);

  saveBookmarks();
  emit bookmarksChanged();
  return true;
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

void FileSystemModel::setNameFilter(const QString &filter) {
  if (m_nameFilter == filter)
    return;

  m_nameFilter = filter;
  emit nameFilterChanged();

  scanDirectory();
}

QHash<int, QByteArray> FileSystemModel::roleNames() const {
  return {{NameRole, "fileName"},       {PathRole, "filePath"},
          {IsDirRole, "isDir"},         {SizeRole, "fileSize"},
          {ItemCountRole, "itemCount"}, {LastModifiedRole, "lastModified"},
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
    m_currentPath = cleanTarget;
    m_currentPath = QDir::cleanPath(dir.absolutePath());
    pushHistory(m_currentPath);
    scanDirectory();
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

void FileSystemModel::refresh() { scanDirectory(); }

bool FileSystemModel::makeFolder(const QString &folderName) {
  const QString name = folderName.trimmed();
  m_lastError.clear();

  if (name.isEmpty()) {
    m_lastError = "Folder name cannot be empty.";
    emit lastErrorChanged();
    return false;
  }

  if (name == "." || name == "..") {
    m_lastError = "Invalid folder name.";
    emit lastErrorChanged();
    return false;
  }

  QDir dir(m_currentPath);

  if (dir.exists(name)) {
    m_lastError = QString("A folder named \"%1\" already exists.").arg(name);

    emit lastErrorChanged();
    return false;
  }

  if (!dir.mkdir(name)) {
    m_lastError = QString("Could not create folder \"%1\".").arg(name);

    emit lastErrorChanged();
    return false;
  }

  scanDirectory();
  emit lastErrorChanged();

  return true;
}

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

void FileSystemModel::setTypeFilter(const QString &filter) {
  if (m_typeFilter == filter)
    return;

  m_typeFilter = filter;

  emit typeFilterChanged();
  scanDirectory();
}

void FileSystemModel::setSizeFilter(const QString &filter) {
  if (m_sizeFilter == filter)
    return;

  m_sizeFilter = filter;

  emit sizeFilterChanged();
  scanDirectory();
}

void FileSystemModel::setSortBy(const QString &sortBy) {
  if (m_sortBy == sortBy)
    return;

  m_sortBy = sortBy;

  emit sortByChanged();
  scanDirectory();
}

void FileSystemModel::setSortOrder(const QString &sortOrder) {
  if (m_sortOrder == sortOrder)
    return;

  m_sortOrder = sortOrder;

  emit sortOrderChanged();
  scanDirectory();
}

void FileSystemModel::setFoldersFirst(bool first) {
  if (m_foldersFirst == first)
    return;
  m_foldersFirst = first;
  emit foldersFirstChanged();
  scanDirectory();
}

void FileSystemModel::scanDirectory() {
  beginResetModel();
  m_items.clear();

  QDir dir(m_currentPath);

  QFileInfoList entries = dir.entryInfoList(
      QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::NoSort);

  for (const auto &info : entries) {

    // ============================================================
    // NAME FILTER
    // ============================================================

    if (!m_nameFilter.isEmpty() &&
        !info.fileName().contains(m_nameFilter, Qt::CaseInsensitive)) {
      continue;
    }

    // ============================================================
    // TYPE FILTER (supports "All Files", single value, or comma list)
    // ============================================================

    if (m_typeFilter == "__NONE__") {
      continue;
    }

    if (!m_typeFilter.isEmpty() && m_typeFilter != "All Files") {
      const QStringList allowed = m_typeFilter.split(',', Qt::SkipEmptyParts);
      bool match = false;

      for (QString raw : allowed) {
        const QString t = raw.trimmed();

        if (t == "Folders") {
          if (info.isDir()) {
            match = true;
            break;
          }
        } else if (t == "Files") {
          if (info.isFile()) {
            match = true;
            break;
          }
        } else if (t == "Images") {
          static const QStringList img = {"jpg",  "jpeg", "png", "gif", "bmp",
                                          "webp", "svg",  "tif", "tiff"};
          if (info.isFile() && img.contains(info.suffix().toLower())) {
            match = true;
            break;
          }
        } else if (t == "Videos") {
          static const QStringList vid = {"mp4",  "mkv", "avi", "mov",
                                          "webm", "wmv", "m4v", "flv"};
          if (info.isFile() && vid.contains(info.suffix().toLower())) {
            match = true;
            break;
          }
        } else if (t == "Audio") {
          static const QStringList aud = {"mp3", "wav", "flac", "ogg",
                                          "aac", "m4a", "opus", "wma"};
          if (info.isFile() && aud.contains(info.suffix().toLower())) {
            match = true;
            break;
          }
        } else if (t == "Documents") {
          static const QStringList doc = {"pdf", "doc", "docx", "txt",
                                          "rtf", "odt", "xls",  "xlsx",
                                          "csv", "ppt", "pptx", "odp"};
          if (info.isFile() && doc.contains(info.suffix().toLower())) {
            match = true;
            break;
          }
        }
      }

      if (!match)
        continue;
    }

    // ============================================================
    // SIZE FILTER
    // ============================================================

    const qint64 size = info.size();

    if (m_sizeFilter == "Empty" && size != 0)
      continue;

    if (m_sizeFilter == "Under 1 MB" && size >= 1024 * 1024)
      continue;

    if (m_sizeFilter == "1–10 MB" &&
        (size < 1024 * 1024 || size >= 10 * 1024 * 1024)) {
      continue;
    }

    if (m_sizeFilter == "10–100 MB" &&
        (size < 10 * 1024 * 1024 || size >= 100 * 1024 * 1024)) {
      continue;
    }

    if (m_sizeFilter == "Over 100 MB" && size <= 100 * 1024 * 1024) {
      continue;
    }

    // ============================================================
    // CREATE ITEM
    // ============================================================

    FileItem item;

    item.name = info.fileName();
    item.filePath = QDir::cleanPath(info.absoluteFilePath());
    item.isDir = info.isDir();
    item.size = size;
    item.lastModified = info.lastModified();
    item.extension = info.suffix().toLower();

    if (item.isDir) {
      QDir subDir(item.filePath);

      item.itemCount = static_cast<int>(
          subDir.entryList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot)
              .size());
    }

    m_items.append(item);
  }

  // ============================================================
  // SORT
  // ============================================================

  std::sort(
      m_items.begin(), m_items.end(),
      [this](const FileItem &a, const FileItem &b) {
        // Directories order decider
        if (a.isDir != b.isDir)
          return m_foldersFirst ? (a.isDir > b.isDir) : (a.isDir < b.isDir);

        bool result = false;

        if (m_sortBy == "Name") {
          result = QString::localeAwareCompare(a.name, b.name) < 0;
        } else if (m_sortBy == "Date Modified") {
          result = a.lastModified < b.lastModified;
        } else if (m_sortBy == "Size") {
          result = a.size < b.size;
        } else if (m_sortBy == "Type") {
          result = QString::localeAwareCompare(a.extension, b.extension) < 0;
        } else {
          result = QString::localeAwareCompare(a.name, b.name) < 0;
        }

        return m_sortOrder == "ascending" ? result : !result;
      });

  endResetModel();
}

} // namespace xyla
