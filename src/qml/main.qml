import QtQuick
import "launcher"
import "workspace"

QtObject {
    id: appController

    property SplashScreen splashWindow: SplashScreen {
        visible: !projectManager.hasActiveProject
    }

    property Workspace workspaceWindow: Workspace {
        visible: projectManager.hasActiveProject
    }

    property XylaShortcutEditorDialog shortcutDialog: XylaShortcutEditorDialog {}

    property var menuConnections: Connections {
        target: typeof menuManager !== "undefined" ? menuManager : null // Use your C++ MenuManager context property name

        function onRequestKeyboardShortcuts() {
            appController.shortcutDialog.show();
            appController.shortcutDialog.raise();
            appController.shortcutDialog.requestActivate();
        }
    }
}
