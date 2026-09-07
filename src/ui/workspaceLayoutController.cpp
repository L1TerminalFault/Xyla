#include "workspaceLayoutController.hpp"
#include <QFileInfo>
#include <QTimer>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/KDDockWidgets.h>
#include <kddockwidgets/LayoutSaver.h>
#include <kddockwidgets/core/DockRegistry.h>
#include <kddockwidgets/core/views/MainWindowViewInterface.h>
#include <kddockwidgets/qtquick/views/DockWidget.h>

void WorkspaceLayoutController::createDefaultWorkspace() {
  auto registry = KDDockWidgets::DockRegistry::self();
  if (registry->mainDockingAreas().isEmpty()) {
    return;
  }
  auto *mainArea = registry->mainDockingAreas().constFirst();

  auto *mediaDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("MediaPanel"));
  mediaDock->setTitle(QStringLiteral("Media Pool"));
  mediaDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/MediaPanel.qml"));
  mainArea->addDockWidget(mediaDock, KDDockWidgets::Location_OnLeft);

  auto *monitorDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("ProjectMonitor"));
  monitorDock->setTitle(QStringLiteral("Viewer"));
  monitorDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));
  mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnRight,
                          mediaDock);

  auto *propsDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("PropertiesPanel"));
  propsDock->setTitle(QStringLiteral("Inspector"));
  propsDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/PropertiesPanel.qml"));
  mainArea->addDockWidget(propsDock, KDDockWidgets::Location_OnRight,
                          monitorDock);

  auto *timelineDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("Timeline"));
  timelineDock->setTitle(QStringLiteral("Timeline"));
  timelineDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));
  mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom);

  auto *colorDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("ColorGradePanel"));
  colorDock->setTitle(QStringLiteral("Color Wheels"));
  colorDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/ColorGradePanel.qml"));
  mainArea->addDockWidget(colorDock, KDDockWidgets::Location_OnRight,
                          timelineDock);

  auto *nodeGraphDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("NodeGraphPanel"));
  nodeGraphDock->setTitle(QStringLiteral("Node Graph"));
  nodeGraphDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/NodeGraphPanel.qml"));

  auto *mixerDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("MixerPanel"));
  mixerDock->setTitle(QStringLiteral("Audio Mixer"));
  mixerDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/MixerPanel.qml"));

  QTimer::singleShot(0, [timelineDock, nodeGraphDock, mixerDock]() {
    timelineDock->addDockWidgetAsTab(nodeGraphDock);
    timelineDock->addDockWidgetAsTab(mixerDock);
  });
}

void WorkspaceLayoutController::saveLayout(const QString &profileName) {
  KDDockWidgets::LayoutSaver saver;
  saver.saveToFile(QStringLiteral("%1_layout.json").arg(profileName));
}

void WorkspaceLayoutController::restoreOrCreate(const QString &profileName) {
  const QString fileName = QStringLiteral("%1_layout.json").arg(profileName);

  if (QFileInfo::exists(fileName)) {
    KDDockWidgets::LayoutSaver saver;
    if (saver.restoreFromFile(fileName)) {
      return;
    }
  }

  createDefaultWorkspace();
}
