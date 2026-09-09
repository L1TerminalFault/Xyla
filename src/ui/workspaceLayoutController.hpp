#pragma once

#include <QObject>
#include <QString>

class WorkspaceLayoutController : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString activeDockId READ activeDockId WRITE setActiveDockId NOTIFY
                 activeDockIdChanged)

public:
  explicit WorkspaceLayoutController(QObject *parent = nullptr)
      : QObject(parent) {}
  ~WorkspaceLayoutController() override = default;

  [[nodiscard]] QString activeDockId() const;
  Q_INVOKABLE void setActiveDockId(const QString &dockId);

  Q_INVOKABLE void initializeWorkspaces();
  Q_INVOKABLE void saveLayout(const QString &profileName);
  Q_INVOKABLE void restoreOrCreate(const QString &profileName);

  Q_INVOKABLE void floatCurrentTab(QObject *groupCpp);
  Q_INVOKABLE void closeCurrentTab(QObject *groupCpp);

signals:
  void activeDockIdChanged(const QString &dockId);

private:
  void createWorkspace(const QString &profileName);
  bool workspaceExists(const QString &profileName) const;

  QString m_activeDockId{"Timeline"};
};
