#include "fileSystemManager.hpp"

namespace xyla {

FileSystemModel::FileSystemModel(QObject *parent) : QAbstractListModel(parent) {
  m_currentPath = QDir::homePath();
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

QHash<int, QByteArray> FileSystemModel::roleNames() const {
  return {{NameRole, "fileName"},       {PathRole, "filePath"},
          {IsDirRole, "isDir"},         {SizeRole, "fileSize"},
          {ItemCountRole, "itemCount"}, {LastModifiedRole, "lastModified"},
          {ExtensionRole, "extension"}};
}

QString FileSystemModel::parentPath() const {
  QDir dir(m_currentPath);
  dir.cdUp();
  return dir.absolutePath();
}

void FileSystemModel::setCurrentPath(const QString &path) {
  QDir dir(path);
  if (dir.exists() && m_currentPath != dir.absolutePath()) {
    m_currentPath = dir.absolutePath();
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
  QDir dir(m_currentPath);
  QString name =
      folderName.trimmed().isEmpty() ? "New Folder" : folderName.trimmed();
  int counter = 1;
  QString targetName = name;

  while (dir.exists(targetName)) {
    targetName = QString("%1 (%2)").arg(name).arg(counter++);
  }

  if (dir.mkdir(targetName)) {
    scanDirectory();
    return true;
  }
  return false;
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

void FileSystemModel::scanDirectory() {
  beginResetModel();
  m_items.clear();

  QDir dir(m_currentPath);
  QFileInfoList entries =
      dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot,
                        QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);

  for (const auto &info : entries) {
    FileItem item;
    item.name = info.fileName();
    item.filePath = info.absoluteFilePath();
    item.isDir = info.isDir();
    item.size = info.size();
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

  endResetModel();
}

} // namespace xyla
