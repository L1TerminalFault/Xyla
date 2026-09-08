import QtQuick
import "launcher"
import "workspace"

QtObject {
    id: appController

    property bool shuttingDown: false
    property bool hasProject: typeof projectManager !== "undefined" && projectManager !== null && projectManager.hasActiveProject

    property SplashScreen splashWindow: SplashScreen {
        id: splash
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

    onHasProjectChanged: syncWindowVisibility()

    property var projectConnections: Connections {
        target: typeof projectManager !== "undefined" ? projectManager : null

        function onProjectOpenedSuccessfully() {
            appController.hasProject = true;
            appController.syncWindowVisibility();
        }

        function onHasActiveProjectChanged() {
            appController.hasProject = projectManager.hasActiveProject;
            appController.syncWindowVisibility();
        }
    }

    property XylaShortcutEditorDialog shortcutDialog: XylaShortcutEditorDialog {}

    property var menuConnections: Connections {
        target: typeof menuManager !== "undefined" ? menuManager : null

        function onRequestKeyboardShortcuts() {
            appController.shortcutDialog.show();
            appController.shortcutDialog.raise();
            appController.shortcutDialog.requestActivate();
        }
    }

    Component.onCompleted: {
        syncWindowVisibility();
    }
}
