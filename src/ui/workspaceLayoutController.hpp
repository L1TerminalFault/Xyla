#pragma once

#include <QObject>
#include <QString>

class WorkspaceLayoutController : public QObject
{
    Q_OBJECT

public:
    explicit WorkspaceLayoutController(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    Q_INVOKABLE void initializeWorkspaces();

    Q_INVOKABLE void saveLayout(const QString &profileName);

    Q_INVOKABLE void restoreOrCreate(const QString &profileName);

    Q_INVOKABLE void floatCurrentTab(QObject *groupCpp);
    Q_INVOKABLE void closeCurrentTab(QObject *groupCpp);

private:
    void createWorkspace(const QString &profileName);

    bool workspaceExists(const QString &profileName) const;
};
