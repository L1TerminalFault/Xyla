#include "workspaceLayoutController.hpp"
#include "kddockwidgets/KDDockWidgets.h"
#include <QFileInfo>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/LayoutSaver.h>
#include <kddockwidgets/core/DockRegistry.h>
#include <kddockwidgets/core/views/MainWindowViewInterface.h>
#include <kddockwidgets/qtquick/views/DockWidget.h>
#include <qtimer.h>

void WorkspaceLayoutController::createDefaultWorkspace() {
  auto registry = KDDockWidgets::DockRegistry::self();
  if (registry->mainDockingAreas().isEmpty()) {
    return;
  }
  auto *mainArea = registry->mainDockingAreas().constFirst();

  // 1. Media Panel on the Left
  auto *mediaDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("MediaPanel"));
  mediaDock->setTitle(QStringLiteral("Media Panel"));
  mediaDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/MediaPanel.qml"));
  mainArea->addDockWidget(mediaDock, KDDockWidgets::Location_OnLeft);

  // 2. Project Monitor on the Right of Media Panel
  auto *monitorDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("ProjectMonitor"));
  monitorDock->setTitle(QStringLiteral("Project Monitor"));
  monitorDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));
  mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnRight,
                          mediaDock);

  // 3. Timeline taking 100% of the Bottom width
  auto *timelineDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("Timeline"));
  timelineDock->setTitle(QStringLiteral("Timeline"));
  timelineDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));
  mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom);

  // 4. Node Graph Panel - defer tabification until main window is shown
  auto *nodeGraphDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("NodeGraphPanel"));
  nodeGraphDock->setTitle(QStringLiteral("Node Graph"));
  nodeGraphDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/NodeGraphPanel.qml"));

  // Use a deferred connection to avoid layout issues during initialization
  QTimer::singleShot(0, [timelineDock, nodeGraphDock]() {
    timelineDock->addDockWidgetAsTab(nodeGraphDock);
  });
}

void WorkspaceLayoutController::saveLayout(const QString &profileName) {
  KDDockWidgets::LayoutSaver saver;
  saver.saveToFile(QStringLiteral("%1_layout.json").arg(profileName));
}

void WorkspaceLayoutController::restoreOrCreate(const QString &profileName) {
  const QString fileName = QStringLiteral("%1_layout.json").arg(profileName);

  // Try restoring from saved layout file first
  if (QFileInfo::exists(fileName)) {
    KDDockWidgets::LayoutSaver saver;
    if (saver.restoreFromFile(fileName)) {
      return;
    }
  }

  // Fallback to default layout if no saved file exists
  createDefaultWorkspace();
}
