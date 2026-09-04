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

  // ==========================================
  // TOP SECTION
  // ==========================================

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

  // ==========================================
  // BOTTOM SECTION
  // ==========================================

  // 3. Timeline docked at the Bottom
  auto *timelineDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("Timeline"));
  timelineDock->setTitle(QStringLiteral("Timeline"));
  timelineDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));
  mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom);

  // 4. Effect Panel docked to the Right of the Timeline area
  auto *effectDock =
      new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("EffectPanel"));
  effectDock->setTitle(QStringLiteral("Effect Editor"));
  effectDock->setGuestItem(
      QStringLiteral("qrc:/Xyla/src/qml/workspace/EffectPanel.qml"));
  mainArea->addDockWidget(effectDock, KDDockWidgets::Location_OnRight,
                          timelineDock);

  // 5. Node Graph Panel and Audio Mixer tabbed on top of Timeline
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

  // Defer tabification so KDDockWidgets lays out the horizontal split first
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
