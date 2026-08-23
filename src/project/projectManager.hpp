#pragma once

#include "project/projectData.hpp"
#include "project/recentProjectModel.hpp"
#include <QObject>
#include <optional>
#include <qhashfunctions.h>
#include <qobject.h>
#include <qtmetamacros.h>

namespace xyla {

constexpr uint32_t MAX_RECENT_PROJECT_COUNT = 20;

class ProjectManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(
      bool hasActiveProject READ hasActiveProject NOTIFY activeProjectChanged)
  Q_PROPERTY(QString activeProjectName READ activeProjectName NOTIFY
                 activeProjectChanged)
  Q_PROPERTY(bool hasUnsavedChanges READ hasUnsavedChanges WRITE
                 setHasUnsavedChanges NOTIFY unsavedChangesChanged)
  Q_PROPERTY(RecentProjectsModel *recentProjects READ recentProjects CONSTANT)

public:
  explicit ProjectManager(QObject *parent = nullptr);
  ~ProjectManager() override = default;

  bool hasActiveProject() { return m_activeProject.has_value(); }

  QString activeProjectName() const {
    return m_activeProject ? m_activeProject->name : "";
  }

  bool hasUnsavedChanges() const { return m_hasUnsavedChanges; }
  void setHasUnsavedChanges(bool dirty);

  RecentProjectsModel *recentProjects() { return &m_recentProjectsModel; }

  Q_INVOKABLE bool createProject(const QString &name, const QString &directory,
                                 int width, int height, int fps,
                                 int videoTracks = 2, int audioTracks = 2);

  Q_INVOKABLE bool openProject(const QString &filePath);
  Q_INVOKABLE bool saveProject();
  Q_INVOKABLE void closeProject();

signals:
  void activeProjectChanged();
  void projectOpenedSuccessfully();
  void unsavedChangesChanged();

private:
  void loadRecentProjects();
  void saveRecentProjects();
  void pushToRecent(const ProjectInfo &info);

  std::optional<ProjectInfo> m_activeProject;
  RecentProjectsModel m_recentProjectsModel;
  QList<ProjectInfo> m_recentList;
  bool m_hasUnsavedChanges = false;
};
} // namespace xyla
