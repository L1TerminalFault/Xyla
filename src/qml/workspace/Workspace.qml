import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import com.kdab.dockwidgets 2.0 as KDDW

ApplicationWindow {
    id: workspaceRoot
    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 600
    color: "#141414"
    title: "Xyla - " + projectManager.activeProjectName
    property bool readyToQuit: false

    // this wount work it gets called after docks actually got closed
    // it kept on saving layout with all docs at closed state so this is not likly the right place
    // onClosing: close => {
    //     if (!readyToQuit) {
    //         close.accepted = false;
    //         layoutController.saveLayout("Xyla");
    //         readyToQuit = true;
    //         Qt.quit();
    //     }
    // }

    onClosing: close => {
        if (projectManager.hasUnsavedChanges) {
            close.accepted = false;
            unsavedDialog.show();
        } else {
            projectManager.closeProject();
            Qt.quit(); // Exit entire app instead of showing Splash
        }
    }

    XylaUnsavedChangesDialog {
        id: unsavedDialog

        onSaveRequested: {
            if (projectManager.saveProject()) {
                projectManager.closeProject();
                workspaceRoot.close();
            }
        }

        onDiscardRequested: {
            projectManager.closeProject();
            workspaceRoot.close();
        }

        onCancelRequested: {
            // Event canceled, workspace stays open
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        XylaMenuBar {
            Layout.fillWidth: true
        }

        KDDW.DockingArea {
            id: root
            Layout.fillWidth: true
            Layout.fillHeight: true
            uniqueName: "MainLayout-1"
            property bool workspaceInitialized: false
            function tryInitWorkspace() {
                if (workspaceInitialized || !projectManager.hasActiveProject)
                    return;
                if (!workspaceRoot.visible)   // window not actually mapped/shown yet — wait
                    return;
                workspaceInitialized = true;
                Qt.callLater(function () {
                    layoutController.restoreOrCreate("Xyla");
                });
            }
            Component.onCompleted: tryInitWorkspace()
            Connections {
                target: projectManager
                function onHasActiveProjectChanged() {
                    root.tryInitWorkspace();
                }
            }
            Connections {
                target: workspaceRoot
                function onVisibleChanged() {
                    root.tryInitWorkspace();
                }
            }
        }
    }

    Connections {
        target: menuManager
        function onRequestNewProject() {
            newProjectDialog.open();
        }
        function onRequestOpenProject() {
            customFolderDialog.open();
        }
    }

    NewProjectDialog {
        id: newProjectDialog
    }
    XylaFolderDialog {
        id: customFolderDialog
        returnType: "folder"
        onFolderSelected: path => {
            projectManager.openProject(path);
        }
    }
}
