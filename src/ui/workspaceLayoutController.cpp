#include "workspaceLayoutController.hpp"
#include <QFileInfo>
#include <QTimer>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/KDDockWidgets.h>
#include <kddockwidgets/LayoutSaver.h>
#include <kddockwidgets/core/DockRegistry.h>
#include <kddockwidgets/core/views/MainWindowViewInterface.h>
#include <kddockwidgets/qtquick/views/DockWidget.h>

#include "kddockwidgets/KDDockWidgets.h"
#include "kddockwidgets/LayoutSaver.h"
#include "kddockwidgets/core/DockRegistry.h"
#include "kddockwidgets/core/views/MainWindowViewInterface.h"
#include "kddockwidgets/qtquick/views/DockWidget.h"

#include <kddockwidgets/core/Group.h>
#include <kddockwidgets/core/DockWidget.h>
#include <kddockwidgets/core/views/GroupViewInterface.h>
#include <kddockwidgets/core/views/DockWidgetViewInterface.h>

#include <QFileInfo>
#include <QStandardPaths>
#include <QDir>
#include <QTimer>

namespace
{

const QStringList kWorkspaces = {
    QStringLiteral("Edit"),
    QStringLiteral("Cut"),
    QStringLiteral("Color"),
    QStringLiteral("Audio"),
    QStringLiteral("View")
};

KDDockWidgets::Core::MainWindowViewInterface *
findDockingArea(const QString &profileName)
{
    auto *registry = KDDockWidgets::DockRegistry::self();

    const QString wantedName =
        QStringLiteral("MainLayout-%1").arg(profileName);

    const auto areas = registry->mainDockingAreas();

    for (auto *area : areas) {
        if (!area)
            continue;

        if (area->uniqueName() == wantedName)
            return area;
    }

    return nullptr;
}

KDDockWidgets::Vector<QString>
affinityFor(const QString &profileName)
{
    KDDockWidgets::Vector<QString> result;
    result.push_back(profileName);
    return result;
}

} // namespace

// -----------------------------------------------------------------------------
// Create ALL five real workspace layouts.
//
// Each workspace gets:
//     - its own KDDW.DockingArea
//     - its own set of DockWidgets
//     - its own affinity
//
// This is what makes it possible to have two completely real layouts visible
// during the transition.
// -----------------------------------------------------------------------------

void WorkspaceLayoutController::initializeWorkspaces()
{
    auto *registry = KDDockWidgets::DockRegistry::self();

    if (!registry)
        return;

    for (const QString &profile : kWorkspaces) {
        createWorkspace(profile);
    }
}

// -----------------------------------------------------------------------------
// Check whether the workspace's DockingArea already exists.
// -----------------------------------------------------------------------------

bool WorkspaceLayoutController::workspaceExists(
    const QString &profileName) const
{
    return findDockingArea(profileName) != nullptr;
}

// -----------------------------------------------------------------------------
// Create one complete workspace with profile-specific layouts.
//
// IMPORTANT:
// The QML DockingArea must already exist before this function is called.
// -----------------------------------------------------------------------------

void WorkspaceLayoutController::createWorkspace(const QString &profileName)
{
    auto *registry = KDDockWidgets::DockRegistry::self();
    if (!registry)
        return;

    auto *mainArea = findDockingArea(profileName);
    if (!mainArea)
        return;

    // Set the affinity on the docking area itself so drops are accepted!
    const auto affinity = affinityFor(profileName);
    mainArea->setAffinities(affinity);

    // Don't create the same workspace twice:
    const QString prefix = QStringLiteral("%1.").arg(profileName);
    for (auto *dock : registry->dockwidgets()) {
        if (!dock)
            continue;
        if (dock->uniqueName().startsWith(prefix))
            return;
    }

    auto makeDock = [&](const QString &id, const QString &title, const QString &qmlUrl) {
        auto *dw = new KDDockWidgets::QtQuick::DockWidget(
            QStringLiteral("%1.%2").arg(profileName, id));
        dw->setAffinities(affinity);
        dw->setTitle(title);
        dw->setGuestItem(qmlUrl);
    
    // if (auto *coreController = dw->controller()) {
    //     if (auto *coreDW = dynamic_cast<KDDockWidgets::Core::DockWidget*>(coreController)) {
    //         coreDW->setFloatingGeometry({100, 100, 640, 480});
    //     }
    // }
    
        return dw;
    };

    // ... (rest of your profile layouts: Edit, Cut, Color, Audio, View)

    // =========================================================================
    // 1. EDIT (All panels)
    // =========================================================================
    if (profileName == QLatin1String("Edit")) {
        auto *mediaDock = makeDock(
            QStringLiteral("MediaPanel"), QStringLiteral("Media Panel"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/MediaPanel.qml"));

        auto *monitorDock = makeDock(
            QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

        auto *timelineDock = makeDock(
            QStringLiteral("Timeline"), QStringLiteral("Timeline"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));

        auto *dopesheetDock = makeDock(
            QStringLiteral("DopesheetPanel"), QStringLiteral("Dopesheet"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/DopesheetPanel.qml"));

        auto *effectDock = makeDock(
            QStringLiteral("ColorGradePanel"), QStringLiteral("Effect Editor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ColorGradePanel.qml"));

        auto *nodeGraphDock = makeDock(
            QStringLiteral("NodeGraphPanel"), QStringLiteral("Node Graph"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/NodeGraphPanel.qml"));

        auto *mixerDock = makeDock(
            QStringLiteral("MixerPanel"), QStringLiteral("Audio Mixer"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/MixerPanel.qml"));

        mainArea->addDockWidget(mediaDock, KDDockWidgets::Location_OnLeft);
        mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnRight, mediaDock);
        mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom);
        mainArea->addDockWidget(effectDock, KDDockWidgets::Location_OnRight, timelineDock);
        // mediaDock->setFloating(true);  // temporary test after addDockWidget

        QTimer::singleShot(
            0,
            [timelineDock, nodeGraphDock, mixerDock, dopesheetDock]() {
                if (!timelineDock || !nodeGraphDock || !mixerDock || !dopesheetDock)
                    return;

                timelineDock->addDockWidgetAsTab(nodeGraphDock);
                timelineDock->addDockWidgetAsTab(mixerDock);
                timelineDock->addDockWidgetAsTab(dopesheetDock);
            });




  // // Dopesheet Dock
  // auto *dopesheetDock =
  //     new KDDockWidgets::QtQuick::DockWidget(QStringLiteral("DopesheetPanel"));
  // dopesheetDock->setTitle(QStringLiteral("Dopesheet"));
  // dopesheetDock->setGuestItem(
  //     QStringLiteral("qrc:/Xyla/src/qml/workspace/DopesheetPanel.qml"));









    }

    // =========================================================================
    // 2. CUT (Timeline at bottom and Project Monitor at top)
    // =========================================================================
    else if (profileName == QLatin1String("Cut")) {
        auto *monitorDock = makeDock(
            QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

        auto *timelineDock = makeDock(
            QStringLiteral("Timeline"), QStringLiteral("Timeline"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));

        mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
        mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom, monitorDock);
    }

    // =========================================================================
    // 3. COLOR (Project Monitor at top, Effect Panel at bottom)
    // =========================================================================
    else if (profileName == QLatin1String("Color")) {
        auto *monitorDock = makeDock(
            QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

        auto *effectDock = makeDock(
            QStringLiteral("ColorGradePanel"), QStringLiteral("Effect Editor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ColorGradePanel.qml"));

        mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
        mainArea->addDockWidget(effectDock, KDDockWidgets::Location_OnBottom, monitorDock);
    }

    // =========================================================================
    // 4. AUDIO (Project Monitor at top, Audio Mixer at bottom)
    // =========================================================================
    else if (profileName == QLatin1String("Audio")) {
        auto *monitorDock = makeDock(
            QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

        auto *mixerDock = makeDock(
            QStringLiteral("MixerPanel"), QStringLiteral("Audio Mixer"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/MixerPanel.qml"));

        mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
        mainArea->addDockWidget(mixerDock, KDDockWidgets::Location_OnBottom, monitorDock);
    }

    // =========================================================================
    // 5. VIEW (Just Project Monitor)
    // =========================================================================
    else if (profileName == QLatin1String("View")) {
        auto *monitorDock = makeDock(
            QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
            QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

        mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
    }
}
// Create one complete workspace.
//
// IMPORTANT:
// The QML DockingArea must already exist before this function is called.
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Save ONLY this workspace.
//
// Because every workspace has a different affinity, this JSON contains only
// the requested workspace's docking layout.
// -----------------------------------------------------------------------------

void WorkspaceLayoutController::saveLayout(const QString &profileName)
{
    if (profileName.isEmpty())
        return;

    const QString configDir =
        QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);

    QDir().mkpath(configDir);

    const QString fileName =
        QDir(configDir).filePath(
            QStringLiteral("%1_layout.json").arg(profileName));

    KDDockWidgets::LayoutSaver saver;

    saver.setAffinityNames(
        affinityFor(profileName));

    saver.saveToFile(fileName);
}

// -----------------------------------------------------------------------------
// Restore ONLY this workspace.
// -----------------------------------------------------------------------------

void WorkspaceLayoutController::restoreOrCreate(
    const QString &profileName)
{
    if (profileName.isEmpty())
        return;

    createWorkspace(profileName);

    const QString configDir =
        QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);

    const QString fileName =
        QDir(configDir).filePath(
            QStringLiteral("%1_layout.json").arg(profileName));

    if (!QFileInfo::exists(fileName))
        return;

    KDDockWidgets::LayoutSaver saver(
        KDDockWidgets::RestoreOption_RelativeToMainWindow);

    saver.setAffinityNames(
        affinityFor(profileName));

    saver.restoreFromFile(fileName);
}

void WorkspaceLayoutController::floatCurrentTab(QObject *viewObj)
{
    if (!viewObj) {
        qWarning() << "[Workspace] floatCurrentTab: null";
        return;
    }

    KDDockWidgets::Core::DockWidget *dw = nullptr;

    if (auto *gv = dynamic_cast<KDDockWidgets::Core::GroupViewInterface *>(viewObj)) {
        if (auto *g = gv->group())
            dw = g->currentDockWidget();
    } else if (auto *g = dynamic_cast<KDDockWidgets::Core::Group *>(viewObj)) {
        dw = g->currentDockWidget();
    } else if (auto *dv = dynamic_cast<KDDockWidgets::Core::DockWidgetViewInterface *>(viewObj)) {
        dw = dv->dockWidget();
    }

    if (!dw) {
        qWarning() << "[Workspace] floatCurrentTab: no dock widget from" << viewObj
                   << viewObj->metaObject()->className();
        return;
    }

    dw->setFloating(true);
}

void WorkspaceLayoutController::closeCurrentTab(QObject *groupCpp) {
  if (!groupCpp) {
    qWarning() << "[Workspace] closeCurrentTab called with null group";
    return;
  }

  auto *groupView = dynamic_cast<KDDockWidgets::Core::GroupViewInterface *>(groupCpp);
  KDDockWidgets::Core::Group *coreGroup = nullptr;
  if (groupView) {
    coreGroup = groupView->group();
  }

  if (coreGroup) {
    auto *activeDock = coreGroup->currentDockWidget();
    if (activeDock) {
      qDebug() << "[Workspace] Closing dock widget:" << activeDock->uniqueName();
      activeDock->close();
      return;
    }
  }
}
