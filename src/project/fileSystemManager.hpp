#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QObject>
#include <QVector>

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

  explicit FileSystemModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  QString currentPath() const { return m_currentPath; }
  QString parentPath() const;
  bool canCdBack() const { return m_historyIndex > 0; }
  bool canCdForward() const { return m_historyIndex < m_history.size() - 1; }

  void setCurrentPath(const QString &path);

  Q_INVOKABLE void cd(const QString &path);
  Q_INVOKABLE void cdBack();
  Q_INVOKABLE void cdForward();
  Q_INVOKABLE void cdUp();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE bool makeFolder(const QString &folderName = "New Folder");

signals:
  void currentPathChanged();
  void canCdBackChanged();
  void canCdForwardChanged();

private:
  QString m_currentPath;
  QVector<FileItem> m_items;
  QVector<QString> m_history;
  int m_historyIndex{-1};

  void scanDirectory();
  void pushHistory(const QString &path);
};

} // namespace xyla
