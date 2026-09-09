import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import com.kdab.dockwidgets 2.0 as KDDW

ApplicationWindow {
    id: workspaceRoot

    visible: true
    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 600
    color: "#0E0E0E"

    title: "Xyla - " + (typeof projectManager !== "undefined" && projectManager.hasActiveProject ? (projectManager.activeProjectName + (projectManager.hasUnsavedChanges ? " *" : "")) : "Untitled")

    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
    property var activeActionManager: typeof actionManager !== "undefined" ? actionManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
    property bool readyToQuit: false

    flags: Qt.Window | Qt.FramelessWindowHint

    // Helper to prevent global shortcuts from firing when actively typing in an input
    function isEditingText() {
        var item = workspaceRoot.activeFocusItem;
        if (!item)
            return false;
        return (item.hasOwnProperty("text") && item.hasOwnProperty("cursorPosition") && !item.readOnly);
    }

    Rectangle {
        id: windowCanvas
        anchors.fill: parent
        color: "#191919"
        radius: 10
        clip: true

        // Background click to restore global key focus
        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: workspaceRoot.forceActiveFocus()
        }
    }

    header: XylaMenuBar {
        id: mainMenuBar
        onWorkspaceChanged: (newWorkspace, oldWorkspace) => {
            workspaceTransition.startTransition(newWorkspace, oldWorkspace);
        }
    }

    Item {
        id: workspaceContainer
        anchors.fill: parent
        clip: true

        property bool workspaceInitialized: false
        property var workspaceNames: ["Edit", "Cut", "Color", "Audio", "View"]
        property int activeWorkspaceIndex: 0
        property int incomingWorkspaceIndex: -1
        property bool transitioning: false

        function areaForIndex(index) {
            return workspaceAreas.itemAt(index);
        }

        function tryInitWorkspace() {
            if (workspaceInitialized)
                return;

            if (workspaceRoot.activeProjectManager && !workspaceRoot.activeProjectManager.hasActiveProject)
                return;

            workspaceInitialized = true;

            Qt.callLater(function () {
                if (typeof layoutController === "undefined" || !layoutController)
                    return;

                layoutController.initializeWorkspaces();
                layoutController.restoreOrCreate(workspaceNames[activeWorkspaceIndex]);
            });
        }

        Component.onCompleted: {
            tryInitWorkspace();
        }

        Connections {
            target: workspaceRoot.activeProjectManager
            function onHasActiveProjectChanged() {
                workspaceContainer.tryInitWorkspace();
            }
        }

        Connections {
            target: workspaceRoot
            function onVisibleChanged() {
                if (workspaceRoot.visible)
                    workspaceContainer.tryInitWorkspace();
            }
        }

        Repeater {
            id: workspaceAreas
            model: workspaceContainer.workspaceNames

            delegate: Item {
                id: workspaceItem
                width: workspaceContainer.width
                height: workspaceContainer.height
                y: 0
                visible: index === workspaceContainer.activeWorkspaceIndex || index === workspaceContainer.incomingWorkspaceIndex
                z: index === workspaceContainer.incomingWorkspaceIndex ? 2 : (index === workspaceContainer.activeWorkspaceIndex ? 1 : 0)
                x: 0

                Rectangle {
                    id: background
                    anchors.fill: parent
                    radius: 12
                    color: "#0E0E0E"
                    clip: true
                }

                KDDW.DockingArea {
                    id: area
                    anchors.fill: parent
                    anchors.margins: 0
                    uniqueName: "MainLayout-" + modelData
                    affinities: [modelData]
                    clip: true
                }
            }
        }

        property bool movingForward: true
        property string previousWorkspace: ""
    }

    Item {
        id: workspaceTransition
        anchors.fill: parent
        z: 99999

        property string pendingWorkspace: ""
        property string previousWorkspace: ""
        property bool movingForward: true
        property bool transitioning: false

        property var oldArea: null
        property var newArea: null

        function finalizeTransition() {
            if (!transitioning)
                return;

            if (typeof layoutController !== "undefined" && layoutController && previousWorkspace !== "")
                layoutController.saveLayout(previousWorkspace);

            for (var i = 0; i < workspaceContainer.workspaceNames.length; ++i) {
                var area = workspaceContainer.areaForIndex(i);
                if (!area)
                    continue;
                if (i === workspaceContainer.incomingWorkspaceIndex) {
                    area.x = 0;
                    area.visible = true;
                    area.z = 2;
                } else {
                    area.visible = false;
                    area.z = 0;
                }
            }

            if (workspaceContainer.incomingWorkspaceIndex >= 0)
                workspaceContainer.activeWorkspaceIndex = workspaceContainer.incomingWorkspaceIndex;

            workspaceContainer.incomingWorkspaceIndex = -1;
            transitioning = false;
            oldArea = null;
            newArea = null;
        }

        function startTransition(newWorkspace, oldWorkspace) {
            if (newWorkspace === oldWorkspace)
                return;

            var newIndex = workspaceContainer.workspaceNames.indexOf(newWorkspace);
            if (newIndex < 0)
                return;

            if (transitioning) {
                workspaceSlide.stop();
                finalizeTransition();
                oldWorkspace = workspaceContainer.workspaceNames[workspaceContainer.activeWorkspaceIndex];
                if (newWorkspace === oldWorkspace)
                    return;
            }

            var oldIndex = workspaceContainer.workspaceNames.indexOf(oldWorkspace);
            if (oldIndex < 0)
                return;

            var _oldArea = workspaceContainer.areaForIndex(oldIndex);
            var _newArea = workspaceContainer.areaForIndex(newIndex);
            if (!_oldArea || !_newArea)
                return;

            oldArea = _oldArea;
            newArea = _newArea;

            movingForward = newIndex > oldIndex;
            previousWorkspace = oldWorkspace;
            pendingWorkspace = newWorkspace;

            oldArea.visible = true;
            oldArea.z = 1;
            oldArea.x = 0;

            var startOffset = movingForward ? workspaceContainer.width : -workspaceContainer.width;
            newArea.visible = true;
            newArea.z = 2;
            newArea.x = startOffset;

            workspaceContainer.activeWorkspaceIndex = oldIndex;
            workspaceContainer.incomingWorkspaceIndex = newIndex;
            transitioning = true;

            if (typeof layoutController !== "undefined" && layoutController)
                layoutController.restoreOrCreate(newWorkspace);

            workspaceSlide.restart();
        }

        ParallelAnimation {
            id: workspaceSlide

            NumberAnimation {
                target: workspaceTransition.oldArea
                property: "x"
                to: workspaceTransition.movingForward ? -workspaceContainer.width : workspaceContainer.width
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: workspaceTransition.newArea
                property: "x"
                from: workspaceTransition.movingForward ? workspaceContainer.width : -workspaceContainer.width
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }

            onFinished: workspaceTransition.finalizeTransition()
        }
    }

    Instantiator {
        id: shortcutDispatcher
        model: workspaceRoot.activeShortcutManager ? workspaceRoot.activeShortcutManager.allActions : []

        delegate: Shortcut {
            id: keyBinding
            property string actionIdentifier: modelData.id || ""
            sequence: modelData.currentKey || ""
            context: Qt.ApplicationShortcut

            enabled: workspaceRoot.visible && !unsavedDialog.visible && !workspaceTransition.transitioning && sequence !== "" && !workspaceRoot.isEditingText() && (workspaceRoot.activeActionManager ? workspaceRoot.activeActionManager.isEnabled(actionIdentifier) : true)

            onActivated: {
                if (workspaceRoot.activeActionManager) {
                    workspaceRoot.activeActionManager.triggerAction(actionIdentifier);
                }
            }
        }
    }

    onClosing: close => {
        if (readyToQuit) {
            close.accepted = true;
            return;
        }
        if (workspaceRoot.activeProjectManager && workspaceRoot.activeProjectManager.hasUnsavedChanges) {
            close.accepted = false;
            unsavedDialog.centerPopup();
            unsavedDialog.open();
        } else {
            readyToQuit = true;
            close.accepted = true;
            Qt.quit();
        }
    }

    XylaUnsavedChangesDialog {
        id: unsavedDialog
        onSaveRequested: {
            if (workspaceRoot.activeProjectManager && workspaceRoot.activeProjectManager.saveProject()) {
                readyToQuit = true;
                Qt.quit();
            }
        }
        onDiscardRequested: {
            readyToQuit = true;
            Qt.quit();
        }
        onCancelRequested: {}
    }

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
            if (workspaceRoot.activeProjectManager)
                workspaceRoot.activeProjectManager.openProject(path);
        }
    }
}
