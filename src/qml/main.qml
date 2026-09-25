import QtQuick
import "launcher"
import "workspace"

Item {
    id: appController
    visible: false
    width: 0
    height: 0

    property bool shuttingDown: false
    
    // 1. Fixed syntax: Safe ternary operators to prevent undefined reference errors
    property var activeProjectManager: (typeof projectManager !== "undefined" && projectManager !== null) ? projectManager : null
    property bool hasProject: activeProjectManager && activeProjectManager.hasActiveProject
    
    property var activeSettingsManager: (typeof settingsManager !== "undefined" && settingsManager !== null) ? settingsManager : null
    
    // 2. Mapped directly to reopenLastProjectOnStartup as requested
    property bool showSplash: activeSettingsManager && activeSettingsManager.showSplashOnStartup ? activeSettingsManager.showSplashOnStartup : false
    
    // This will be populated by the hidden Repeater below
    property string lastRecentProjectPath: ""

    property SplashScreen splashWindow: SplashScreen {
        id: splash
        settingsManager: activeSettingsManager
    }

    property Workspace workspaceWindow: Workspace {
        id: workspace
    }

    function syncWindowVisibility() {
        console.log("[AppController] syncWindowVisibility called. hasProject:", hasProject, "shuttingDown:", shuttingDown);
        if (shuttingDown) {
            if (splashWindow) splashWindow.visible = false;
            if (workspaceWindow) workspaceWindow.visible = false;
            return;
        }

        if (hasProject) {
            if (splashWindow) splashWindow.visible = false;
            if (workspaceWindow) {
                workspaceWindow.visible = true;
                workspaceWindow.show();
                workspaceWindow.raise();
                workspaceWindow.requestActivate();
            }
        } else {
            if (workspaceWindow) workspaceWindow.visible = false;
            if (splashWindow) {
                splashWindow.visible = true;
                splashWindow.show();
                splashWindow.raise();
                splashWindow.requestActivate();
            }
        }
    }

    onHasProjectChanged: {
        console.log("[AppController] hasProject changed to:", hasProject);
        syncWindowVisibility();
    }

    function attemptBypassSplash() {
        console.log("=== [AppController] Attempting splash bypass check ===");
        
        if (hasProject) {
            console.log("[AppController] Already has an active project. Bypass not needed.");
            syncWindowVisibility();
            return;
        }

        var shouldShowSplash = showSplash;
        console.log("[AppController] showSplash (reopenLastProjectOnStartup) is:", shouldShowSplash);

        if (!shouldShowSplash) {
            console.log("[AppController] Decision: Bypass splash screen based on settings.");
            
            if (appController.lastRecentProjectPath !== "") {
                console.log("[AppController] ✅ Bypass successful! Opening last project directly:", appController.lastRecentProjectPath);
                activeProjectManager.openProject(appController.lastRecentProjectPath);
                return;
            } else {
                console.log("[AppController] ⚠️ Recent projects model not ready or empty. Retrying in 100ms...");
                bypassRetryTimer.restart();
                return;
            }
        }

        console.log("[AppController] Bypass conditions not met. Showing splash screen.");
        syncWindowVisibility();
    }

    Timer {
        id: bypassRetryTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (appController.lastRecentProjectPath !== "") {
                console.log("[AppController] ✅ Retry successful! Opening last project directly:", appController.lastRecentProjectPath);
                activeProjectManager.openProject(appController.lastRecentProjectPath);
            } else {
                console.log("[AppController] ⚠️ Still no recent projects found after retry. Showing splash screen.");
                syncWindowVisibility();
            }
        }
    }

    property var projectConnections: Connections {
        target: activeProjectManager

        function onProjectOpenedSuccessfully() {
            console.log("[AppController] Project opened successfully.");
            appController.hasProject = true;
            appController.syncWindowVisibility();
        }

        function onHasActiveProjectChanged() {
            console.log("[AppController] HasActiveProject changed.");
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

    // --- QML Hot Reloader Integration ---
    property var hotReloaderConnections: Connections {
        target: (typeof hotReloader !== "undefined") ? hotReloader : null

        function onReloadTriggered() {
            console.log("[QML Hot Reloader] Reload event received in AppController")
            appController.syncWindowVisibility()
        }
    }

    property Shortcut reloadShortcut: Shortcut {
        sequences: ["F5", "Ctrl+R"]
        enabled: (typeof hotReloader !== "undefined") && hotReloader !== null
        onActivated: {
            if ((typeof hotReloader !== "undefined") && hotReloader !== null) {
                console.log("[QML Hot Reloader] Manual reload requested via shortcut")
                hotReloader.clearAndReload()
            }
        }
    }

    Component.onCompleted: {
        console.log("=== [AppController] Component.onCompleted ===");
        Qt.callLater(attemptBypassSplash);
    }

    // ========================================================================
    // HIDDEN EXTRACTOR: MUST be inside the QtObject closing brace!
    // Safely reads the C++ model's first item without guessing .count/.get()
    // ========================================================================
    Item {
        id: modelExtractor
        visible: false
        width: 0
        height: 0
        
        Repeater {
            model: (typeof projectManager !== "undefined" && projectManager !== null) ? projectManager.recentProjects : null
            delegate: Item {
                Component.onCompleted: {
                    // QML natively maps C++ model roles to the delegate scope
                    if (index === 0 && model && model.filePath) {
                        appController.lastRecentProjectPath = model.filePath;
                        console.log("[AppController] Extracted last recent project path via Repeater:", appController.lastRecentProjectPath);
                    }
                }
            }
        }
    }
} // <-- THIS CLOSING BRACE IS CRITICAL. It closes the root QtObject.
