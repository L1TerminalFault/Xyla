#pragma once
#include <QObject>

class WorkspaceLayoutController : public QObject {
  Q_OBJECT
public:
  explicit WorkspaceLayoutController(QObject *parent = nullptr)
      : QObject(parent) {}

  Q_INVOKABLE void createDefaultWorkspace();
  Q_INVOKABLE void saveLayout(const QString &profileName);
  Q_INVOKABLE void restoreOrCreate(const QString &profileName);

private:
  void spawnPanel(const QString &uniqueId, const QString &title,
                  const QString &qmlUrl, int location,
                  void *relativeTo = nullptr);
};
