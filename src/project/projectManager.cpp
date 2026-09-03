#include "projectManager.hpp"
#include "core/timeline/timelineTrack.hpp"
#include "core/timeline/timelineTypes.hpp"
#include "project/projectData.hpp"
#include <QDir>
#include <QJsonObject>
#include <QSettings>
#include <qcoreapplication.h>
#include <qdir.h>
#include <qjsonobject.h>
#include <qlogging.h>
#include <ranges>

namespace xyla {
ProjectManager::ProjectManager(QObject *parent) : QObject(parent) {
  m_recentProjectsModel.setSourceList(&m_recentList);
  loadRecentProjects();
}

void ProjectManager::pushToRecent(const ProjectInfo &info) {
  if (!info.isValid())
    return;

  m_recentList.removeIf([&info](const ProjectInfo &proj) {
    return proj.filePath == info.filePath;
  });
  m_recentList.prepend(info);

  if (m_recentList.size() > MAX_RECENT_PROJECT_COUNT) {
    m_recentList.removeLast();
  }

  m_recentProjectsModel.refresh();
  saveRecentProjects();
}

void ProjectManager::saveRecentProjects() {
  QSettings settings("Xyla", "RecentProjects");
  settings.beginWriteArray("recentFiles");

  for (auto [i, proj] : std::views::enumerate(m_recentList)) {
    settings.setArrayIndex(static_cast<int>(i));
    settings.setValue("name", proj.name);
    settings.setValue("path", proj.filePath);
    settings.setValue("lastModified", proj.lastModified);
  }
  settings.endArray();
  settings.sync();
}

void ProjectManager::loadRecentProjects() {
  QSettings settings("Xyla", "RecentProjects");
  const int size = settings.beginReadArray("recentFiles");

  m_recentList.clear();
  m_recentList.reserve(size);

  bool missingEntriesFound = false;

  for (int i = 0; i < size; ++i) {
    settings.setArrayIndex(i);

    ProjectInfo info;
    info.name = settings.value("name").toString();
    info.filePath = settings.value("path").toString();
    info.lastModified = settings.value("lastModified").toDateTime();

    if (info.isValid()) {
      m_recentList.append(std::move(info));
    } else {
      qWarning() << "[ProjectManager] Purging missing or invalid recent "
                    "project from storage:"
                 << info.filePath;
      missingEntriesFound = true;
    }
  }
  settings.endArray();

  // sync
  if (missingEntriesFound) {
    saveRecentProjects();
  }

  m_recentProjectsModel.refresh();
}

Q_INVOKABLE bool ProjectManager::createProject(const QString &name,
                                               const QString &directory,
                                               int width, int height, int fps,
                                               int videoTracks,
                                               int audioTracks) {
  if (name.trimmed().isEmpty() || directory.trimmed().isEmpty()) {
    qWarning()
        << "[ProjectManager] Failed to create project: Blank name or path.";
    return false;
  }

  QDir targetDir(directory);
  if (!targetDir.exists()) {
    if (!targetDir.mkpath(".")) {
      qWarning() << "[ProjectManager] Failed to create project directory:"
                 << directory;
      return false;
    }
  }

  const QString projectFolderPath = targetDir.filePath(name);
  QDir projectDir(projectFolderPath);

  if (projectDir.exists()) {
    qWarning() << "[ProjectManager] Project directory already exists:"
               << projectFolderPath;
    return false;
  }

  if (!projectDir.mkpath(".")) {
    qWarning() << "[ProjectManager] Failed to create project folder:"
               << projectFolderPath;
    return false;
  }

  projectDir.mkdir("assets");
  projectDir.mkdir("cache");
  projectDir.mkdir("auto_saves");

  QString filePath = projectDir.filePath("project.xyla");
  QJsonObject rootObj;
  rootObj["name"] = name;
  rootObj["version"] = "1.0";
  rootObj["width"] = width;
  rootObj["height"] = height;
  rootObj["fpsNumerator"] = fps;
  rootObj["fpsDenominator"] = 1;
  rootObj["videoTracks"] = videoTracks;
  rootObj["audioTracks"] = audioTracks;

  QJsonDocument doc(rootObj);

  if (m_timelineModel) {
    m_timelineModel->clearTimeline();

    for (int v = 0; v < videoTracks; ++v) {
      m_timelineModel->addTrack(std::make_shared<xyla::TimelineTrack>(
          QUuid::createUuid().toString(QUuid::WithoutBraces),
          QString("Video %1").arg(v + 1), TrackKind::Video));
    }

    for (int a = 0; a < audioTracks; ++a) {
      m_timelineModel->addTrack(std::make_shared<TimelineTrack>(
          QUuid::createUuid().toString(QUuid::WithoutBraces),
          QString("Audio %1").arg(a + 1), TrackKind::Audio));
    }
  }
  QFile file(filePath);
  if (!file.open(QIODevice::WriteOnly)) {
    qWarning() << "[ProjectManager] Failed to write project file:" << filePath;
    // we cleanup
    projectDir.removeRecursively();
    return false;
  }
  file.write(doc.toJson());
  file.close();

  ProjectInfo info;
  info.name = name;
  info.filePath = filePath;
  info.lastModified = QDateTime::currentDateTime();
  info.width = width;
  info.height = height;
  info.fpsNumerator = fps;
  info.fpsDenominator = 1;

  m_activeProject = info;
  setHasUnsavedChanges(false);
  pushToRecent(info);

  emit activeProjectChanged();
  emit projectOpenedSuccessfully();

  return true;
}

bool ProjectManager::openProject(const QString &inputPath) {
  QString filePath = inputPath.trimmed();
  if (filePath.isEmpty())
    return false;

  QFileInfo checkInfo(filePath);
  if (checkInfo.isDir()) {
    filePath = QDir(filePath).filePath("project.xyla");
    checkInfo.setFile(filePath);
  }

  if (!checkInfo.exists()) {
    qWarning() << "[ProjectManager] File does not exist on disk:" << filePath;
    removeFromRecent(inputPath);
    return false;
  }

  QFile file(filePath);
  if (!file.open(QIODevice::ReadOnly)) {
    qWarning() << "[ProjectManager] Failed to open project file:" << filePath;
    return false;
  }

  QByteArray fileData = file.readAll();
  file.close();

  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(fileData, &parseError);
  if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
    qWarning() << "[ProjectManager] JSON parse error in:" << filePath
               << "Error:" << parseError.errorString();
    return false;
  }

  QJsonObject rootObj = doc.object();

  QDir projectDir = checkInfo.dir();
  if (!projectDir.exists("assets"))
    projectDir.mkdir("assets");
  if (!projectDir.exists("cache"))
    projectDir.mkdir("cache");
  if (!projectDir.exists("auto_saves"))
    projectDir.mkdir("auto_saves");

  ProjectInfo info;
  info.name = rootObj.value("name").toString();
  info.filePath = filePath;
  info.lastModified = checkInfo.lastModified();
  info.width = rootObj.value("width").toInt(1920);
  info.height = rootObj.value("height").toInt(1080);
  info.fpsNumerator = rootObj.value("fpsNumerator").toInt(30);
  info.fpsDenominator = rootObj.value("fpsDenominator").toInt(1);
  // deserialize media pool
  if (m_mediaPool) {
    if (rootObj.contains("mediaPool") && rootObj["mediaPool"].isObject()) {
      m_mediaPool->deserialize(rootObj["mediaPool"].toObject(), projectDir);
    } else {
      m_mediaPool->deserialize(QJsonObject{}, projectDir);
    }
  }

  // Deserialize Timeline
  if (m_timelineModel) {
    if (rootObj.contains("timeline") && rootObj["timeline"].isObject()) {
      m_timelineModel->deserialize(rootObj["timeline"].toObject());
    } else {
      m_timelineModel->deserialize(QJsonObject{});
    }
  }

  if (!info.isValid()) {
    qWarning() << "[ProjectManager] Parsed project info is invalid:"
               << filePath;
    return false;
  }

  m_activeProject = info;
  setHasUnsavedChanges(false);
  pushToRecent(info);

  emit activeProjectChanged();
  emit projectOpenedSuccessfully();

  return true;
}

void ProjectManager::removeFromRecent(const QString &filePath) {
  if (filePath.isEmpty() || m_recentList.isEmpty())
    return;

  int foundIndex = -1;
  for (int i = 0; i < m_recentList.size(); ++i) {
    if (m_recentList[i].filePath == filePath) {
      foundIndex = i;
      break;
    }
  }

  if (foundIndex != -1) {
    m_recentProjectsModel.notifyProjectRemoved(foundIndex);
    m_recentList.removeAt(foundIndex);
    saveRecentProjects();
  }
}

void ProjectManager::closeProject() {
  if (!m_activeProject.has_value()) {
    return;
  }

  // saveProject();
  m_activeProject.reset();
  emit activeProjectChanged();
}

bool ProjectManager::saveProject() {
  if (!m_activeProject.has_value()) {
    qWarning() << "[ProjectManager] Cannot save: No active project.";
    return false;
  }

  QFile file(m_activeProject->filePath);
  if (!file.open(QIODevice::WriteOnly)) {
    qWarning() << "[ProjectManager] Failed to open file for writing:"
               << m_activeProject->filePath;
    return false;
  }

  QJsonObject rootObj;
  rootObj["name"] = m_activeProject->name;
  rootObj["version"] = "1.0";
  rootObj["width"] = m_activeProject->width;
  rootObj["height"] = m_activeProject->height;
  rootObj["fpsNumerator"] = m_activeProject->fpsNumerator;
  rootObj["fpsDenominator"] = m_activeProject->fpsDenominator;

  if (m_mediaPool) {
    rootObj["mediaPool"] = m_mediaPool->serialize();
  }

  if (m_timelineModel) {
    rootObj["timeline"] = m_timelineModel->serialize();
  }

  QJsonDocument doc(rootObj);
  file.write(doc.toJson());
  file.close();

  m_activeProject->lastModified = QDateTime::currentDateTime();
  pushToRecent(*m_activeProject);

  setHasUnsavedChanges(false);
  return true;
}

void ProjectManager::setHasUnsavedChanges(bool dirty) {
  if (m_hasUnsavedChanges == dirty) {
    return;
  }
  m_hasUnsavedChanges = dirty;
  emit unsavedChangesChanged();
}

} // namespace xyla
