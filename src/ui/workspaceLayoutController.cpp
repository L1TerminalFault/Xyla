#include "workspaceLayoutController.hpp"
#include <kddockwidgets/Config.h>
#include <kddockwidgets/LayoutSaver.h>
#include <kddockwidgets/core/DockRegistry.h>
#include <kddockwidgets/core/views/MainWindowViewInterface.h>
#include <kddockwidgets/qtquick/views/DockWidget.h>
#include <qfileinfo.h>

void WorkspaceLayoutController::createDefaultWorkspace() {
  auto registry = KDDockWidgets::DockRegistry::self();
  if (registry->mainDockingAreas().isEmpty()) {
    return;
  }
  auto *mainArea = registry->mainDockingAreas().constFirst();

  auto *mediaDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("MediaPanel"));
  mediaDock->setTitle(QStringLiteral("Media Panel"));
  mediaDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/MediaPanel.qml"));
  mainArea->addDockWidget(mediaDock, KDDockWidgets::Location_OnLeft);

  auto *monitorDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("ProjectMonitor"));
  monitorDock->setTitle(QStringLiteral("Project Monitor"));
  monitorDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));
  mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnRight,
                          mediaDock);

  auto *timelineDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("Timeline"));
  timelineDock->setTitle(QStringLiteral("Timeline"));
  timelineDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));
  mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom,
                          monitorDock);
}

void WorkspaceLayoutController::saveLayout(const QString &profileName) {
  KDDockWidgets::LayoutSaver saver;
  saver.saveToFile(QStringLiteral("%1_layout.json").arg(profileName));
}

void WorkspaceLayoutController::restoreOrCreate(const QString &profileName) {
  createDefaultWorkspace();
  const QString fileName = QStringLiteral("%1_layout.json").arg(profileName);
  if (!QFileInfo::exists(fileName)) {
    return;
  }
  KDDockWidgets::LayoutSaver saver;
  saver.restoreFromFile(fileName);
}
