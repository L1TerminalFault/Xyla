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

    // Window Title with standard '*' unsaved indicator
    title: "Xyla - " + (typeof projectManager !== "undefined" ? projectManager.activeProjectName + (projectManager.hasUnsavedChanges ? " *" : "") : "Untitled")

    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null

    onClosing: close => {
        if (workspaceRoot.activeProjectManager && workspaceRoot.activeProjectManager.hasUnsavedChanges) {
            close.accepted = false;
            unsavedDialog.show();
        } else {
            if (workspaceRoot.activeProjectManager) {
                workspaceRoot.activeProjectManager.closeProject();
            }
            Qt.quit();
        }
    }

    XylaUnsavedChangesDialog {
        id: unsavedDialog

        onSaveRequested: {
            if (workspaceRoot.activeProjectManager && workspaceRoot.activeProjectManager.saveProject()) {
                workspaceRoot.activeProjectManager.closeProject();
                workspaceRoot.close();
            }
        }

        onDiscardRequested: {
            if (workspaceRoot.activeProjectManager) {
                workspaceRoot.activeProjectManager.closeProject();
            }
            workspaceRoot.close();
        }

        onCancelRequested: {
            // Stay open
        }
    }

    // =========================================================================
    // Main Workspace Layout
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        XylaMenuBar {
            Layout.fillWidth: true
        }

        KDDW.DockingArea {
            id: dockingArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            uniqueName: "MainLayout-1"
            property bool workspaceInitialized: false

            function tryInitWorkspace() {
                if (workspaceInitialized || !workspaceRoot.activeProjectManager?.hasActiveProject)
                    return;
                if (!workspaceRoot.visible)
                    return;

                workspaceInitialized = true;
                Qt.callLater(function () {
                    if (typeof layoutController !== "undefined" && layoutController) {
                        layoutController.restoreOrCreate("Xyla");
                    }
                });
            }

            Component.onCompleted: tryInitWorkspace()

            Connections {
                target: workspaceRoot.activeProjectManager
                function onHasActiveProjectChanged() {
                    dockingArea.tryInitWorkspace();
                }
            }

            Connections {
                target: workspaceRoot
                function onVisibleChanged() {
                    dockingArea.tryInitWorkspace();
                }
            }
        }
    }

    // =========================================================================
    // Global Dialogs & Menu Connections
    // =========================================================================
    Connections {
        target: typeof menuManager !== "undefined" ? menuManager : null
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
            if (workspaceRoot.activeProjectManager) {
                workspaceRoot.activeProjectManager.openProject(path);
            }
        }
    }
}
