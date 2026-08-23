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
}
