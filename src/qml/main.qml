import QtQuick
import "launcher"
import "workspace"

Item {
    id: appController
    visible: false
    width: 0
    height: 0

    property bool shuttingDown: false

    property var activeProjectManager: (typeof projectManager !== "undefined" && projectManager !== null) ? projectManager : null
    property bool hasProject: activeProjectManager && activeProjectManager.hasActiveProject

    property var activeSettingsManager: (typeof settingsManager !== "undefined" && settingsManager !== null) ? settingsManager : null

    property bool showSplash: activeSettingsManager && activeSettingsManager.showSplashOnStartup ? activeSettingsManager.showSplashOnStartup : false

    property string lastRecentProjectPath: ""

    property SplashScreen splashWindow: SplashScreen {
        id: splash
        settingsManager: activeSettingsManager
    }

    property Workspace workspaceWindow: Workspace {
        id: workspace
    }

    function syncWindowVisibility() {
        if (shuttingDown) {
            if (splashWindow)
                splashWindow.visible = false;
            if (workspaceWindow)
                workspaceWindow.visible = false;
            return;
        }

        if (hasProject) {
            if (splashWindow)
                splashWindow.visible = false;
            if (workspaceWindow) {
                workspaceWindow.visible = true;
                workspaceWindow.show();
                workspaceWindow.raise();
                workspaceWindow.requestActivate();
            }
        } else {
            if (workspaceWindow)
                workspaceWindow.visible = false;
            if (splashWindow) {
                splashWindow.visible = true;
                splashWindow.show();
                splashWindow.raise();
                splashWindow.requestActivate();
            }
        }
    }

    onHasProjectChanged: {
        syncWindowVisibility();
    }

    function attemptBypassSplash() {
        if (hasProject) {
            syncWindowVisibility();
            return;
        }

        var shouldShowSplash = showSplash;

        if (!shouldShowSplash) {
            if (appController.lastRecentProjectPath !== "") {
                activeProjectManager.openProject(appController.lastRecentProjectPath);
                return;
            } else {
                bypassRetryTimer.restart();
                return;
            }
        }

        syncWindowVisibility();
    }

    Timer {
        id: bypassRetryTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (appController.lastRecentProjectPath !== "") {
                activeProjectManager.openProject(appController.lastRecentProjectPath);
            } else {
                syncWindowVisibility();
            }
        }
    }

    property var projectConnections: Connections {
        target: activeProjectManager

        function onProjectOpenedSuccessfully() {
            appController.hasProject = true;
            appController.syncWindowVisibility();
        }

        function onHasActiveProjectChanged() {
            appController.hasProject = activeProjectManager.hasActiveProject;
            appController.syncWindowVisibility();
        }
    }

    property XylaShortcutEditorDialog shortcutDialog: XylaShortcutEditorDialog {}

    property var menuConnections: Connections {
        target: (typeof menuManager !== "undefined") ? menuManager : null

        function onRequestKeyboardShortcuts() {
            appController.shortcutDialog.show();
            appController.shortcutDialog.raise();
            appController.shortcutDialog.requestActivate();
        }
    }

    property var hotReloaderConnections: Connections {
        target: (typeof hotReloader !== "undefined") ? hotReloader : null

        function onReloadTriggered() {
            appController.syncWindowVisibility();
        }
    }

    property Shortcut reloadShortcut: Shortcut {
        sequences: ["F5", "Ctrl+R"]
        enabled: (typeof hotReloader !== "undefined") && hotReloader !== null
        onActivated: {
            if ((typeof hotReloader !== "undefined") && hotReloader !== null) {
                hotReloader.clearAndReload();
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(attemptBypassSplash);
    }

    Item {
        id: modelExtractor
        visible: false
        width: 0
        height: 0

        Repeater {
            model: (typeof projectManager !== "undefined" && projectManager !== null) ? projectManager.recentProjects : null
            delegate: Item {
                Component.onCompleted: {
                    if (index === 0 && model && model.filePath) {
                        appController.lastRecentProjectPath = model.filePath;
                    }
                }
            }
        }
    }
}
