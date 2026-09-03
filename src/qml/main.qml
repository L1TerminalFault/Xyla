import QtQuick
import "launcher"
import "workspace"

QtObject {
    id: appController

    property bool shuttingDown: false
    property bool showSplash: !projectManager.hasActiveProject && !shuttingDown

    property SplashScreen splashWindow: SplashScreen {
        visible: appController.showSplash
    }

    property Workspace workspaceWindow: Workspace {
        visible: projectManager.hasActiveProject
    }

    property var projectConnections: Connections {
        target: projectManager

        function onProjectOpenedSuccessfully() {
            appController.showSplash = false;
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
}
