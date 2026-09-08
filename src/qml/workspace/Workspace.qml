import QtQuick
import Qt5Compat.GraphicalEffects   // Qt 6
import QtQuick.Controls
import com.kdab.dockwidgets 2.0 as KDDW

ApplicationWindow {
    id: workspaceRoot

    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 600
    // Top background
    color: "#0E0E0E"

    title: "Xyla - " + (typeof projectManager !== "undefined" && projectManager.hasActiveProject ? (projectManager.activeProjectName + (projectManager.hasUnsavedChanges ? " *" : "")) : "Untitled")

    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
    property var activeActionManager: typeof actionManager !== "undefined" ? actionManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
    property bool readyToQuit: false

    // 2. Hide the operating system's default title bar and frame boundaries
    flags: Qt.Window | Qt.FramelessWindowHint

    // 3. This internal Rectangle becomes your true, rounded window surface
    Rectangle {
        id: windowCanvas
        anchors.fill: parent
        // Main background
        color: "#191919" // "#141414" // This replaces your old window color
        radius: 10       // Adjust this value for your window roundedness
        clip: true       // Forces all children inside the window to clip to the corners

        // Place all of your window contents (menu bar, workspace controller, layouts) inside here
        // ... rest of your code ...
    }

    // Menu Bar at the top
    header: XylaMenuBar {
        id: mainMenuBar
        onWorkspaceChanged: (newWorkspace, oldWorkspace) => {
            workspaceTransition.startTransition(newWorkspace, oldWorkspace);
        }
    }

    // Direct KDDockWidgets docking area
// -------------------------------------------------------------------------
// REAL MULTI-WORKSPACE DOCKING CONTAINER
// -------------------------------------------------------------------------

Item {
    id: workspaceContainer

    anchors.fill: parent
    // anchors.margins: 4

    clip: true

    property bool workspaceInitialized: false

    property var workspaceNames: [
        "Edit",
        "Cut",
        "Color",
        "Audio",
        "View"
    ]

    property int activeWorkspaceIndex: 0
    property int incomingWorkspaceIndex: -1

    property bool transitioning: false

    // ---------------------------------------------------------------------
    // Returns the DockingArea for a workspace.
    // ---------------------------------------------------------------------

    function areaForIndex(index) {
        return workspaceAreas.itemAt(index);
    }

    // ---------------------------------------------------------------------
    // Initialize all REAL docking areas and all REAL dock widgets.
    // ---------------------------------------------------------------------

    function tryInitWorkspace() {

        if (workspaceInitialized)
            return;

        if (!workspaceRoot.activeProjectManager?.hasActiveProject)
            return;

        if (!workspaceRoot.visible)
            return;

        workspaceInitialized = true;

        Qt.callLater(function() {

            if (typeof layoutController === "undefined" ||
                !layoutController) {
                return;
            }

            // Create all five actual docking layouts.
            layoutController.initializeWorkspaces();

            // Restore the initial workspace.
            layoutController.restoreOrCreate(
                workspaceNames[activeWorkspaceIndex]
            );
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
            workspaceContainer.tryInitWorkspace();
        }
    }

    // ---------------------------------------------------------------------
    // FIVE REAL KDDockWidgets MAIN WINDOWS
    // ---------------------------------------------------------------------

Repeater {
    id: workspaceAreas

    model: workspaceContainer.workspaceNames

// or: import QtGraphicalEffects 1.15   // Qt 5

delegate: Item {
    id: workspaceItem
    width: workspaceContainer.width
    height: workspaceContainer.height
    y: 0
    visible: index === workspaceContainer.activeWorkspaceIndex ||
             index === workspaceContainer.incomingWorkspaceIndex
    z: index === workspaceContainer.incomingWorkspaceIndex ? 2 :
      (index === workspaceContainer.activeWorkspaceIndex ? 1 : 0)
    x: 0

    // Rounded background that also acts as the clip boundary
    Rectangle {
        id: background
        anchors.fill: parent
        radius: 12
        color: "#0E0E0E" // "red" // Theme.background          // or "red" for testing
        clip: true                       // ← this is what actually clips the children
    }

    // Docking area sits on top of the rounded rect and is clipped by it
    KDDW.DockingArea {
        id: area
        anchors.fill: parent
        anchors.margins: 0               // keep 0 for now
        uniqueName: "MainLayout-" + modelData
        affinities: [ modelData ]

        // Make sure the docking area itself doesn't paint over the rounded corners
        // (some versions need this)
        clip: true
    }
}
}
    // ---------------------------------------------------------------------
    // TRANSITION STATE
    // ---------------------------------------------------------------------

    property bool movingForward: true
    property string previousWorkspace: ""

}

    // -------------------------------------------------------------------------
    // HORIZONTAL SWIPE TRANSITION OVERLAY
    // -------------------------------------------------------------------------
Item {
    id: workspaceTransition
    anchors.fill: parent
    z: 99999

    property string pendingWorkspace: ""
    property string previousWorkspace: ""
    property bool movingForward: true
    property bool transitioning: false

    // Stable references for the animations
    property var oldArea: null
    property var newArea: null

    function startTransition(newWorkspace, oldWorkspace) {
        if (transitioning)
            return
        if (newWorkspace === oldWorkspace)
            return

        var newIndex = workspaceContainer.workspaceNames.indexOf(newWorkspace)
        var oldIndex = workspaceContainer.workspaceNames.indexOf(oldWorkspace)
        if (newIndex < 0 || oldIndex < 0)
            return

        var _oldArea = workspaceContainer.areaForIndex(oldIndex)
        var _newArea = workspaceContainer.areaForIndex(newIndex)
        if (!_oldArea || !_newArea)
            return

        // Keep stable references
        oldArea = _oldArea
        newArea = _newArea

        movingForward = newIndex > oldIndex
        previousWorkspace = oldWorkspace
        pendingWorkspace = newWorkspace

        // Normalize both areas
        oldArea.visible = true
        oldArea.z = 1
        oldArea.x = 0
        oldArea.scale = 1.0
        oldArea.opacity = 1.0

        newArea.visible = false
        newArea.z = 2
        newArea.x = movingForward ? workspaceContainer.width
                                  : -workspaceContainer.width
        newArea.scale = 0.88
        newArea.opacity = 1.0

        workspaceContainer.activeWorkspaceIndex = oldIndex
        workspaceContainer.incomingWorkspaceIndex = newIndex
        transitioning = true

        if (typeof layoutController !== "undefined" && layoutController)
            layoutController.restoreOrCreate(newWorkspace)

        Qt.callLater(function() {
            if (!workspaceTransition.transitioning)
                return

            // Re-assert after possible KDDW geometry changes
            oldArea.x = 0
            oldArea.scale = 1.0
            newArea.x = workspaceTransition.movingForward
                        ? workspaceContainer.width
                        : -workspaceContainer.width
            newArea.scale = 0.88
            newArea.visible = true

            workspaceSlide.restart()
        })
    }

    SequentialAnimation {
        id: workspaceSlide

        // Phase 1 – zoom previous out
        ParallelAnimation {
            NumberAnimation {
                target: workspaceTransition.oldArea
                property: "scale"
                to: 0.96
                duration: 200
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation { duration: 80 }
                NumberAnimation {
                    target: workspaceTransition.oldArea
                    property: "x"
                    to: workspaceTransition.movingForward
                            ? -workspaceContainer.width
                            : workspaceContainer.width
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Phase 2 – bring new in + zoom in
        SequentialAnimation {
            PauseAnimation { duration: 0 }   // can keep or remove
            NumberAnimation {
                target: workspaceTransition.newArea
                property: "x"
                from: workspaceTransition.movingForward
                        ? workspaceContainer.width
                        : -workspaceContainer.width
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: workspaceTransition.newArea
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

onFinished: {
    if (typeof layoutController !== "undefined" && layoutController)
        layoutController.saveLayout(workspaceTransition.previousWorkspace)

    if (workspaceTransition.oldArea) {
        workspaceTransition.oldArea.visible = false
        workspaceTransition.oldArea.z = 0
        workspaceTransition.oldArea.scale = 1.0
        workspaceTransition.oldArea.opacity = 1.0
        workspaceTransition.oldArea.x = workspaceTransition.movingForward
                    ? workspaceContainer.width
                    : -workspaceContainer.width
    }

    if (workspaceTransition.newArea) {
        workspaceTransition.newArea.x = 0
        workspaceTransition.newArea.scale = 1.0
        workspaceTransition.newArea.opacity = 1.0
        workspaceTransition.newArea.visible = true
        workspaceTransition.newArea.z = 2
    }

    // Belt-and-suspenders: normalize every area
    for (var i = 0; i < workspaceContainer.workspaceNames.length; ++i) {
        var area = workspaceContainer.areaForIndex(i)
        if (!area)
            continue
        if (i === workspaceContainer.incomingWorkspaceIndex) {
            area.x = 0
            area.scale = 1.0
            area.visible = true
            area.z = 2
        } else {
            area.scale = 1.0
            area.visible = false
            area.z = 0
        }
    }

    workspaceContainer.activeWorkspaceIndex =
            workspaceContainer.incomingWorkspaceIndex
    workspaceContainer.incomingWorkspaceIndex = -1
    workspaceTransition.transitioning = false
    workspaceTransition.oldArea = null
    workspaceTransition.newArea = null
}
// onFinished: {
//     if (typeof layoutController !== "undefined" && layoutController)
//         layoutController.saveLayout(workspaceTransition.previousWorkspace)
//
//     if (workspaceTransition.oldArea) {
//         workspaceTransition.oldArea.visible = false
//         workspaceTransition.oldArea.z = 0
//         workspaceTransition.oldArea.scale = 1.0
//         workspaceTransition.oldArea.opacity = 1.0
//         workspaceTransition.oldArea.x = workspaceTransition.movingForward
//                     ? workspaceContainer.width
//                     : -workspaceContainer.width
//     }
//
//     if (workspaceTransition.newArea) {
//         workspaceTransition.newArea.x = 0
//         workspaceTransition.newArea.scale = 1.0
//         workspaceTransition.newArea.opacity = 1.0
//         workspaceTransition.newArea.visible = true
//         workspaceTransition.newArea.z = 2
//     }
//
//     workspaceContainer.activeWorkspaceIndex =
//             workspaceContainer.incomingWorkspaceIndex
//     workspaceContainer.incomingWorkspaceIndex = -1
//     workspaceTransition.transitioning = false
//
//     workspaceTransition.oldArea = null
//     workspaceTransition.newArea = null
// }
    }
}

    // -------------------------------------------------------------------------
    // HOTKEY SHORTCUT DISPATCHER (Guard against firing while clicking tabs)
    // -------------------------------------------------------------------------
    Instantiator {
        id: shortcutDispatcher
        model: workspaceRoot.activeShortcutManager ? workspaceRoot.activeShortcutManager.allActions : []

        delegate: Shortcut {
            id: keyBinding
            property string actionIdentifier: modelData.id || ""
            sequence: modelData.currentKey || ""
            context: Qt.WindowShortcut

            // Disabled during transition or when dialog is open
            enabled: workspaceRoot.visible 
                     && !unsavedDialog.visible 
                     && !workspaceTransition.visible 
                     && sequence !== "" 
                     && (workspaceRoot.activeActionManager ? workspaceRoot.activeActionManager.isEnabled(actionIdentifier) : true)

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
