#include "workspaceLayoutController.hpp"

#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTimer>

#include <kddockwidgets/Config.h>
#include <kddockwidgets/KDDockWidgets.h>
#include <kddockwidgets/LayoutSaver.h>
#include <kddockwidgets/core/DockRegistry.h>
#include <kddockwidgets/core/DockWidget.h>
#include <kddockwidgets/core/Group.h>
#include <kddockwidgets/core/views/DockWidgetViewInterface.h>
#include <kddockwidgets/core/views/GroupViewInterface.h>
#include <kddockwidgets/core/views/MainWindowViewInterface.h>
#include <kddockwidgets/qtquick/views/DockWidget.h>

// INFO: Logs commented out

namespace {

const QStringList kWorkspaces = {
    QStringLiteral("Edit"), QStringLiteral("Cut"), QStringLiteral("Color"),
    QStringLiteral("Audio"), QStringLiteral("View")};

KDDockWidgets::Core::MainWindowViewInterface *
findDockingArea(const QString &profileName) {
  auto *registry = KDDockWidgets::DockRegistry::self();
  if (!registry) {
    // qWarning() << "[Workspace][findDockingArea] DockRegistry::self() returned "
    //               "NULL for profile:"
    //            << profileName;
    return nullptr;
  }

  const QString wantedName = QStringLiteral("MainLayout-%1").arg(profileName);
  const auto areas = registry->mainDockingAreas();

  // qDebug() << "[Workspace][findDockingArea] Searching for area:" << wantedName
  //          << "among" << areas.size() << "registered areas.";
  //
  for (auto *area : areas) {
    if (!area) {
      // qWarning()
      //     << "[Workspace][findDockingArea] Found NULL area in registry list!";
      continue;
    }

    // qDebug() << "[Workspace][findDockingArea] Found area:"
    //          << area->uniqueName();
    if (area->uniqueName() == wantedName) {
      // qDebug() << "[Workspace][findDockingArea] MATCH FOUND:"
      //          << area->uniqueName() << "pointer:" << area;
      return area;
    }
  }

  // qWarning()
      // << "[Workspace][findDockingArea] FAILED to find docking area for profile:"
      // << profileName << "(wanted:" << wantedName << ")";
  return nullptr;
}

KDDockWidgets::Vector<QString> affinityFor(const QString &profileName) {
  KDDockWidgets::Vector<QString> result;
  result.push_back(profileName);
  // qDebug() << "[Workspace][affinityFor] Generated affinity vector for profile:"
  //          << profileName;
  return result;
}

} // namespace

void WorkspaceLayoutController::initializeWorkspaces() {
  // qInfo() << "[Workspace][initializeWorkspaces] Starting initialization of all "
  //            "workspaces...";
  auto *registry = KDDockWidgets::DockRegistry::self();

  if (!registry) {
    // qCritical() << "[Workspace][initializeWorkspaces] CRITICAL: "
    //                "KDDockWidgets::DockRegistry::self() is NULL! Aborting.";
    return;
  }

  for (const QString &profile : kWorkspaces) {
    // qInfo()
    //     << "[Workspace][initializeWorkspaces] Initializing workspace profile:"
    //     << profile;
    createWorkspace(profile);
  }
  // qInfo() << "[Workspace][initializeWorkspaces] All workspace initializations "
  //            "triggered.";
}

bool WorkspaceLayoutController::workspaceExists(
    const QString &profileName) const {
  bool exists = (findDockingArea(profileName) != nullptr);
  // qDebug() << "[Workspace][workspaceExists] Profile:" << profileName
  //          << "exists:" << exists;
  return exists;
}

void WorkspaceLayoutController::createWorkspace(const QString &profileName) {
  // qInfo()
  //     << "=================================================================";
  // qInfo() << "[Workspace][createWorkspace] BEGIN createWorkspace for profile:"
  //         << profileName;

  auto *registry = KDDockWidgets::DockRegistry::self();
  if (!registry) {
    // qCritical() << "[Workspace][createWorkspace] CRITICAL: "
    //                "DockRegistry::self() is NULL!";
    return;
  }

  auto *mainArea = findDockingArea(profileName);
  if (!mainArea) {
    // qWarning() << "[Workspace][createWorkspace] ABORT: MainWindowViewInterface "
    //               "docking area not found for:"
    //            << profileName;
    return;
  }

  const auto affinity = affinityFor(profileName);
  // qDebug() << "[Workspace][createWorkspace] Setting affinities on mainArea:"
  //          << mainArea->uniqueName();
  mainArea->setAffinities(affinity);

  const QString prefix = QStringLiteral("%1.").arg(profileName);
  for (auto *dock : registry->dockwidgets()) {
    if (!dock)
      continue;
    if (dock->uniqueName().startsWith(prefix)) {
      // qWarning() << "[Workspace][createWorkspace] Docks with prefix" << prefix
      //            << "already exist! Skipping duplicate creation.";
      return;
    }
  }

  auto makeDock = [&](const QString &id, const QString &title,
                      const QString &qmlUrl) {
    const QString uniqueId = QStringLiteral("%1.%2").arg(profileName, id);
    // qDebug() << "[Workspace][makeDock] Instantiating DockWidget:" << uniqueId
    //          << "| Title:" << title << "| QML URL:" << qmlUrl;

    auto *dw = new KDDockWidgets::QtQuick::DockWidget(uniqueId);
    // qDebug() << "[Workspace][makeDock] Created DockWidget instance at:" << dw;

    dw->setAffinities(affinity);
    dw->setTitle(title);

    // qDebug() << "[Workspace][makeDock] Setting guest item URL:" << qmlUrl
    //          << "on dock:" << uniqueId;
    dw->setGuestItem(qmlUrl);
    // qDebug() << "[Workspace][makeDock] Guest item URL assigned for:"
    //          << uniqueId;

    return dw;
  };

  if (profileName == QLatin1String("Edit")) {
    // qInfo() << "[Workspace][createWorkspace] Building 'Edit' profile layout...";

    auto *mediaDock =
        makeDock(QStringLiteral("MediaPanel"), QStringLiteral("Media Panel"),
                 QStringLiteral("qrc:/Xyla/src/qml/workspace/MediaPanel.qml"));
    auto *monitorDock = makeDock(
        QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));
    auto *propsDock = makeDock(
        QStringLiteral("PropertiesPanel"), QStringLiteral("Inspector"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/PropertiesPanel.qml"));
    auto *dopesheetDock = makeDock(
        QStringLiteral("DopesheetPanel"), QStringLiteral("Dopesheet"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/DopesheetPanel.qml"));
    auto *effectDock = makeDock(
        QStringLiteral("ColorGradePanel"), QStringLiteral("Effect Editor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ColorGradePanel.qml"));
    auto *timelineDock =
        makeDock(QStringLiteral("Timeline"), QStringLiteral("Timeline"),
                 QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));
    auto *nodeGraphDock = makeDock(
        QStringLiteral("NodeGraphPanel"), QStringLiteral("Node Graph"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/NodeGraphPanel.qml"));
    auto *mixerDock =
        makeDock(QStringLiteral("MixerPanel"), QStringLiteral("Audio Mixer"),
                 QStringLiteral("qrc:/Xyla/src/qml/workspace/MixerPanel.qml"));

    // qDebug() << "[Workspace][createWorkspace][Edit] Adding Top Section Docks "
    //             "to mainArea...";
    mainArea->addDockWidget(mediaDock, KDDockWidgets::Location_OnLeft);
    // qDebug() << "[Workspace][createWorkspace][Edit] Added mediaDock "
    //             "(Location_OnLeft)";

    mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnRight,
                            mediaDock);
    // qDebug() << "[Workspace][createWorkspace][Edit] Added monitorDock "
    //             "(Location_OnRight of mediaDock)";

    mainArea->addDockWidget(propsDock, KDDockWidgets::Location_OnRight,
                            monitorDock);
    // qDebug() << "[Workspace][createWorkspace][Edit] Added propsDock "
    //             "(Location_OnRight of monitorDock)";

    // qDebug() << "[Workspace][createWorkspace][Edit] Adding timelineDock "
    //             "(Location_OnBottom)...";
    mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom);

    // qDebug() << "[Workspace][createWorkspace][Edit] Adding effectDock "
    //             "(Location_OnRight of timelineDock)...";
    mainArea->addDockWidget(effectDock, KDDockWidgets::Location_OnRight,
                            timelineDock);

    // qDebug() << "[Workspace][createWorkspace][Edit] Scheduling "
    //             "QTimer::singleShot for Tabification...";
    QTimer::singleShot(
        0, timelineDock,
        [timelineDock, nodeGraphDock, mixerDock, dopesheetDock]() {
          // qInfo() << "[Workspace][SingleShot Callback] Starting tabification "
          //            "into timelineDock...";

          if (!timelineDock) {
            // qCritical()
            //     << "[Workspace][SingleShot Callback] timelineDock is NULL!";
            return;
          }
          if (!nodeGraphDock)
            // qCritical()
            //     << "[Workspace][SingleShot Callback] nodeGraphDock is NULL!";
          if (!mixerDock)
            // qCritical()
            //     << "[Workspace][SingleShot Callback] mixerDock is NULL!";
          if (!dopesheetDock)
            // qCritical()
            //     << "[Workspace][SingleShot Callback] dopesheetDock is NULL!";

          if (nodeGraphDock) {
            // qDebug() << "[Workspace][SingleShot Callback] Adding nodeGraphDock "
            //             "as tab...";
            timelineDock->addDockWidgetAsTab(nodeGraphDock);
          }
          if (mixerDock) {
            // qDebug() << "[Workspace][SingleShot Callback] Adding mixerDock as "
            //             "tab...";
            timelineDock->addDockWidgetAsTab(mixerDock);
          }
          if (dopesheetDock) {
            // qDebug() << "[Workspace][SingleShot Callback] Adding dopesheetDock "
            //             "as tab...";
            timelineDock->addDockWidgetAsTab(dopesheetDock);
          }
          // qInfo() << "[Workspace][SingleShot Callback] Tabification completed "
          //            "successfully.";
        });
  } else if (profileName == QLatin1String("Cut")) {
    // qInfo() << "[Workspace][createWorkspace] Building 'Cut' profile layout...";
    auto *monitorDock = makeDock(
        QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

    auto *timelineDock =
        makeDock(QStringLiteral("Timeline"), QStringLiteral("Timeline"),
                 QStringLiteral("qrc:/Xyla/src/qml/workspace/Timeline.qml"));

    mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
    mainArea->addDockWidget(timelineDock, KDDockWidgets::Location_OnBottom,
                            monitorDock);
  } else if (profileName == QLatin1String("Color")) {
    // qInfo()
    //     << "[Workspace][createWorkspace] Building 'Color' profile layout...";
    auto *monitorDock = makeDock(
        QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

    auto *effectDock = makeDock(
        QStringLiteral("ColorGradePanel"), QStringLiteral("Effect Editor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ColorGradePanel.qml"));

    mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
    mainArea->addDockWidget(effectDock, KDDockWidgets::Location_OnBottom,
                            monitorDock);
  } else if (profileName == QLatin1String("Audio")) {
    // qInfo()
    //     << "[Workspace][createWorkspace] Building 'Audio' profile layout...";
    auto *monitorDock = makeDock(
        QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

    auto *mixerDock =
        makeDock(QStringLiteral("MixerPanel"), QStringLiteral("Audio Mixer"),
                 QStringLiteral("qrc:/Xyla/src/qml/workspace/MixerPanel.qml"));

    mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
    mainArea->addDockWidget(mixerDock, KDDockWidgets::Location_OnBottom,
                            monitorDock);
  } else if (profileName == QLatin1String("View")) {
    // qInfo() << "[Workspace][createWorkspace] Building 'View' profile layout...";
    auto *monitorDock = makeDock(
        QStringLiteral("ProjectMonitor"), QStringLiteral("Project Monitor"),
        QStringLiteral("qrc:/Xyla/src/qml/workspace/ProjectMonitor.qml"));

    mainArea->addDockWidget(monitorDock, KDDockWidgets::Location_OnTop);
  }

  // qInfo() << "[Workspace][createWorkspace] END createWorkspace for profile:"
  //         << profileName;
  // qInfo()
  //     << "=================================================================";
}

void WorkspaceLayoutController::saveLayout(const QString &profileName) {
  // qInfo() << "[Workspace][saveLayout] Saving layout for profile:"
  //         << profileName;
  if (profileName.isEmpty()) {
    // qWarning() << "[Workspace][saveLayout] Aborted: profileName is empty.";
    return;
  }

  const QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  QDir().mkpath(configDir);

  const QString fileName = QDir(configDir).filePath(
      QStringLiteral("%1_layout.json").arg(profileName));
  // qDebug() << "[Workspace][saveLayout] Target file path:" << fileName;

  KDDockWidgets::LayoutSaver saver;
  saver.setAffinityNames(affinityFor(profileName));
  bool success = saver.saveToFile(fileName);
  // qInfo() << "[Workspace][saveLayout] Save completed. Success:" << success;
}

void WorkspaceLayoutController::restoreOrCreate(const QString &profileName) {
  // qInfo() << "[Workspace][restoreOrCreate] Request received for profile:"
  //         << profileName;
  if (profileName.isEmpty()) {
    // qWarning() << "[Workspace][restoreOrCreate] Aborted: profileName is empty.";
    return;
  }

  const QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  const QString fileName = QDir(configDir).filePath(
      QStringLiteral("%1_layout.json").arg(profileName));

  // qDebug() << "[Workspace][restoreOrCreate] Checking existence of file:"
           // << fileName;
  if (QFileInfo::exists(fileName)) {
    // qInfo() << "[Workspace][restoreOrCreate] Saved layout file found. "
    //            "Restoring from:"
    //         << fileName;
    KDDockWidgets::LayoutSaver saver(
        KDDockWidgets::RestoreOption_RelativeToMainWindow);
    saver.setAffinityNames(affinityFor(profileName));
    bool restored = saver.restoreFromFile(fileName);
    // qInfo() << "[Workspace][restoreOrCreate] Layout restore status:"
    //         << restored;
    if (restored)
      return;
    // qWarning() << "[Workspace][restoreOrCreate] Restore failed, falling back "
    //               "to createWorkspace().";
  } else {
    // qInfo() << "[Workspace][restoreOrCreate] No saved layout found. Creating "
    //            "default workspace...";
  }

  createWorkspace(profileName);
}

void WorkspaceLayoutController::floatCurrentTab(QObject *viewObj) {
  // qInfo() << "[Workspace][floatCurrentTab] Invoked with object:" << viewObj;
  if (!viewObj) {
    // qWarning() << "[Workspace][floatCurrentTab] NULL viewObj received!";
    return;
  }

  KDDockWidgets::Core::DockWidget *dw = nullptr;

  if (auto *gv =
          dynamic_cast<KDDockWidgets::Core::GroupViewInterface *>(viewObj)) {
    // qDebug() << "[Workspace][floatCurrentTab] Casted to GroupViewInterface";
    if (auto *g = gv->group())
      dw = g->currentDockWidget();
  } else if (auto *g = dynamic_cast<KDDockWidgets::Core::Group *>(viewObj)) {
    // qDebug() << "[Workspace][floatCurrentTab] Casted to Group";
    dw = g->currentDockWidget();
  } else if (auto *dv =
                 dynamic_cast<KDDockWidgets::Core::DockWidgetViewInterface *>(
                     viewObj)) {
    // qDebug()
    //     << "[Workspace][floatCurrentTab] Casted to DockWidgetViewInterface";
    dw = dv->dockWidget();
  }

  if (!dw) {
    // qWarning()
    //     << "[Workspace][floatCurrentTab] FAILED to extract DockWidget from:"
    //     << viewObj << "Class:" << viewObj->metaObject()->className();
    return;
  }

  // qInfo() << "[Workspace][floatCurrentTab] Setting dock to floating:"
  //         << dw->uniqueName();
  dw->setFloating(true);
}

void WorkspaceLayoutController::closeCurrentTab(QObject *groupCpp) {
  // qInfo() << "[Workspace][closeCurrentTab] Invoked with object:" << groupCpp;
  if (!groupCpp) {
    // qWarning() << "[Workspace][closeCurrentTab] NULL groupCpp received!";
    return;
  }

  auto *groupView =
      dynamic_cast<KDDockWidgets::Core::GroupViewInterface *>(groupCpp);
  KDDockWidgets::Core::Group *coreGroup = nullptr;
  if (groupView) {
    // qDebug() << "[Workspace][closeCurrentTab] Found GroupViewInterface";
    coreGroup = groupView->group();
  }

  if (coreGroup) {
    auto *activeDock = coreGroup->currentDockWidget();
    if (activeDock) {
      // qInfo() << "[Workspace][closeCurrentTab] Closing active dock widget:"
      //         << activeDock->uniqueName();
      activeDock->close();
      return;
    } else {
      // qWarning() << "[Workspace][closeCurrentTab] coreGroup had no "
      //               "currentDockWidget()";
    }
  } else {
    // qWarning() << "[Workspace][closeCurrentTab] Could not resolve coreGroup";
  }
}

QString WorkspaceLayoutController::activeDockId() const {
  auto *registry = KDDockWidgets::DockRegistry::self();
  if (!registry)
    return m_activeDockId;

  if (auto *focused = registry->focusedDockWidget()) {
    QString name = focused->uniqueName();
    int dotIdx = name.indexOf('.');
    return dotIdx != -1 ? name.mid(dotIdx + 1) : name;
  }

  for (auto *dock : registry->dockwidgets()) {
    if (dock && dock->isVisible() && dock->isFocused()) {
      QString name = dock->uniqueName();
      int dotIdx = name.indexOf('.');
      return dotIdx != -1 ? name.mid(dotIdx + 1) : name;
    }
  }

  return m_activeDockId;
}

void WorkspaceLayoutController::setActiveDockId(const QString &dockId) {
  QString cleanId = dockId;
  int dotIdx = cleanId.indexOf('.');
  if (dotIdx != -1)
    cleanId = cleanId.mid(dotIdx + 1);

  if (m_activeDockId != cleanId) {
    m_activeDockId = cleanId;
    qDebug() << "[Workspace] Active dock changed to:" << m_activeDockId;
    emit activeDockIdChanged(m_activeDockId);
  }
}
