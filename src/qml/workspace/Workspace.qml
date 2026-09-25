import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import com.kdab.dockwidgets 2.0 as KDDW

ApplicationWindow {
    id: workspaceRoot
    objectName: "workspaceWindow"  // <--- Add this line

    readonly property Item grabRoot: workspaceContainer

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

    function handleUnsavedCloseRequest() {
        unsavedDialog.centerPopup();
        unsavedDialog.open();
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
                // Clear the dirty flag so C++ filter doesn't re-block the close event
                workspaceRoot.activeProjectManager.hasUnsavedChanges = false; 
                Qt.quit();
            }
        }
        onDiscardRequested: {
            readyToQuit = true;
            // Clear the dirty flag so C++ filter doesn't re-block the close event
            if (workspaceRoot.activeProjectManager) {
                workspaceRoot.activeProjectManager.hasUnsavedChanges = false;
            }
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
        function onRequestProjectSettings() {
            preferencesWindowId.show();
        }
    }

    XylaPreferencesWindow {
        id: preferencesWindowId
        width: 1300
        height: 900
        title: "Xyla Preferences"
        settingsList: [
        {
            name: "General",
            icon: "clear-all.svg",
            sections: [
                {
                    title: "Application Behavior & Lifecycle",
                    items: [
                        { type: "select", label: "Application Language", description: "Select the display language for the application interface.", value: "System Default", options: ["System Default", "English", "Spanish", "Japanese", "German"], callback: function(val) { console.log("Language changed to:", val) } },
                        { type: "select", label: "Startup Behavior", description: "Choose what action to take immediately when launching the application.", value: "Open Last Project", options: ["Open Project Manager", "Open Last Project", "Create New Project"], callback: function(val) { console.log("Startup behavior set to:", val) } },
                        { type: "toggle", label: "Show Splash on Startup", description: "Toggle the visibility of splash screen on startup", value: settingsManager.showSplashOnStartup, callback: function(val) { settingsManager.showSplashOnStartup = val } },
                        { type: "input", label: "Default Project Location", description: "Directory path where new projects will be created by default.", value: "/home/user/XylaProjects", callback: function(val) { console.log("Default project location set to:", val) } },
                        { type: "select", label: "Auto-Save Frequency", description: "Interval at which project progress snapshots are automatically saved to disk.", value: "5 minutes", options: ["Disabled", "1 minute", "5 minutes", "15 minutes", "30 minutes", "60 minutes"], callback: function(val) { console.log("Auto-save frequency set to:", val) } },
                        { type: "select", label: "Auto-Save History Limit", description: "Maximum number of retained auto-save backup files per project.", value: "20 snapshots", options: ["5 snapshots", "10 snapshots", "20 snapshots", "50 snapshots", "100 snapshots"], callback: function(val) { console.log("Auto-save limit set to:", val) } },
                        { type: "input", label: "Auto-Save Backup Location", description: "Storage location for auto-save files relative to project or system.", value: "Default Project Folder", callback: function(val) { console.log("Auto-save backup location set to:", val) } },
                        { type: "select", label: "Maximum Undo Levels", description: "Number of previous actions retained in the undo stack history.", value: "100 steps", options: ["10 steps", "50 steps", "100 steps", "250 steps", "500 steps"], callback: function(val) { console.log("Max undo levels set to:", val) } },
                        { type: "select", label: "Undo Memory Cache Limit", description: "Maximum RAM allocated to storing edit undo states.", value: "2048 MB", options: ["512 MB", "1024 MB", "2048 MB", "4096 MB", "8192 MB"], callback: function(val) { console.log("Undo cache limit set to:", val) } },
                        { type: "select", label: "Timecode Display Format", description: "Primary timecode representation system across monitors and timelines.", value: "Timecode (HH:MM:SS:FF)", options: ["Timecode (HH:MM:SS:FF)", "Frames", "Feet + Frames (35mm/16mm)"], callback: function(val) { console.log("Timecode format set to:", val) } },
                        { type: "toggle", label: "Drop-Frame Timecode Support", description: "Enable drop-frame adjustments for standard NTSC frame rates (29.97 / 59.94 fps).", value: false, callback: function(val) { console.log("Drop-frame support set to:", val) } },
                        { type: "select", label: "Double-Click Project Item Action", description: "Action triggered when double-clicking assets in the project bin.", value: "Open in Source Monitor", options: ["Open in Source Monitor", "Open in Timeline", "Open in New Window"], callback: function(val) { console.log("Double-click action set to:", val) } },
                        { type: "select", label: "Timeline Clip Selection Rule", description: "Determines whether video and linked audio clips are selected together.", value: "Select Audio/Video Linked", options: ["Select Track Independently"], callback: function(val) { console.log("Clip selection rule set to:", val) } },
                        { type: "select", label: "Mouse Wheel Zoom Anchor", description: "Focal point reference used when zooming in or out on the timeline.", value: "Mouse Pointer Position", options: ["Playhead Position", "Mouse Pointer Position", "Timeline Center"], callback: function(val) { console.log("Zoom anchor set to:", val) } },
                        { type: "select", label: "Background Rendering Throttle", description: "Resource priority reserved for background rendering tasks.", value: "Normal", options: ["Low (Background)", "Normal", "High (Aggressive)", "Unlimited"], callback: function(val) { console.log("Background rendering throttle set to:", val) } },
                        { type: "toggle", label: "Telemetry & Crash Reporting", description: "Send anonymous crash reports and operational usage metrics to help improve stability.", value: false, callback: function(val) { console.log("Telemetry enabled:", val) } },
                        { type: "toggle", label: "Check for Updates on Startup", description: "Automatically verify if a new version of the application is available on launch.", value: true, callback: function(val) { console.log("Check for updates enabled:", val) } },
                        { type: "toggle", label: "Clear Cache on Exit", description: "Automatically purge temporary render and thumbnail caches upon application close.", value: false, callback: function(val) { console.log("Clear cache on exit enabled:", val) } }
                    ]
                }
            ]
        },
        {
            name: "User Interface",
            icon: "palette.svg",
            sections: [
                {
                    title: "Appearance & Layout",
                    items: [
                        { type: "select", label: "Global Theme / Skin", description: "Visual color palette and component styling scheme.", value: "Dark Modern", options: ["Dark Modern", "Classic Gray", "Midnight Blue", "High Contrast"], callback: function(val) { console.log("Theme changed to:", val) } },
                        { type: "input", label: "Accent & Highlight Color", description: "Primary visual color used for selection states, playheads, and active controls.", value: "#007ACC", callback: function(val) { console.log("Accent color changed to:", val) } },
                        { type: "select", label: "Interface Scaling / DPI", description: "Global scale factor multiplier for high-density display displays.", value: "Auto-detect", options: ["100%", "125%", "150%", "200%", "Auto-detect"], callback: function(val) { console.log("Interface scaling set to:", val) } },
                        { type: "select", label: "Panel Snapping Distance", description: "Proximity threshold in pixels for docking panels to align.", value: "10px", options: ["5px", "10px", "15px", "20px", "30px"], callback: function(val) { console.log("Panel snapping distance set to:", val) } },
                        { type: "toggle", label: "Lock Workspace Layout", description: "Prevent accidental dragging, floating, or closing of dockable ui panels.", value: false, callback: function(val) { console.log("Lock workspace set to:", val) } },
                        { type: "input", label: "Tooltip Hover Delay", description: "Hover time before displaying operational button tooltips.", value: "500ms", callback: function(val) { console.log("Tooltip hover delay set to:", val) } },
                        { type: "select", label: "Timeline Waveform Style", description: "Rendering style for audio track waveforms on timeline clips.", value: "Standard Filled", options: ["Standard Filled", "Rectified", "Logarithmic", "Solid Line"], callback: function(val) { console.log("Waveform style set to:", val) } }
                    ]
                },
                {
                    title: "Monitors & Overlays",
                    items: [
                        { type: "select", label: "Viewport Background Color", description: "Canvas background behind letterboxed video footage in monitors.", value: "Dark Gray", options: ["Black", "Dark Gray", "Checkerboard Transparency", "Custom"], callback: function(val) { console.log("Viewport background color set to:", val) } },
                        { type: "toggle", label: "Show Dropped Frame Indicator", description: "Display a visual warning when real-time video playback drops frames.", value: true, callback: function(val) { console.log("Show dropped frame indicator set to:", val) } },
                        { type: "select", label: "Title Safe Area Guide", description: "Overlay margin guides to ensure text remains inside TV display bounds.", value: "80% / 90%", options: ["Disabled", "80% / 90%", "85% / 93%", "Custom Ratio"], callback: function(val) { console.log("Title safe guide set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Media & Cache",
            icon: "folder.svg",
            sections: [
                {
                    title: "Storage & Ingestion",
                    items: [
                        { type: "input", label: "Primary Cache / Scratch Disk", description: "Storage location for rendered timeline previews, peak files, and conform data.", value: "/home/user/.cache/xyla", callback: function(val) { console.log("Primary cache path set to:", val) } },
                        { type: "toggle", label: "Auto-Proxy Generation Rule", description: "Automatically create low-resolution lightweight proxies upon media import.", value: false, callback: function(val) { console.log("Auto-proxy generation set to:", val) } },
                        { type: "select", label: "Media Cache Size Threshold", description: "Storage limit for cache directory before triggering cleanup warnings.", value: "100 GB", options: ["10 GB", "50 GB", "100 GB", "500 GB", "1000 GB"], callback: function(val) { console.log("Cache size threshold set to:", val) } },
                        { type: "select", label: "Auto-Purge Cache Age Limit", description: "Unused cache files older than this duration are automatically deleted.", value: "30 days", options: ["Never", "1 day", "7 days", "30 days", "90 days", "365 days"], callback: function(val) { console.log("Auto-purge age limit set to:", val) } },
                        { type: "input", label: "Still Image Default Duration", description: "Default timeline clip length applied when importing still graphics.", value: "5.0s", callback: function(val) { console.log("Still image default duration set to:", val) } },
                        { type: "select", label: "Relink Search Depth", description: "Search directory recursion level when attempting to locate missing media files.", value: "Subfolders Only", options: ["Exact Match Only", "Subfolders Only", "Deep Recursive Search"], callback: function(val) { console.log("Relink search depth set to:", val) } }
                    ]
                },
                {
                    title: "Proxy Defaults",
                    items: [
                        { type: "select", label: "Proxy Resolution Format", description: "Scaling target for automatically generated proxy media.", value: "1080p ProRes Proxy", options: ["720p H.264", "1080p H.264", "1080p ProRes Proxy", "Half Resolution Native"], callback: function(val) { console.log("Proxy resolution format set to:", val) } },
                        { type: "input", label: "Proxy Cache Directory", description: "Folder destination reserved specifically for generated proxy media files.", value: "/home/user/.cache/xyla/proxies", callback: function(val) { console.log("Proxy cache directory set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Hardware & Performance",
            icon: "cpu.svg",
            sections: [
                {
                    title: "GPU & Playback",
                    items: [
                        { type: "select", label: "Hardware Acceleration Engine", description: "Graphics API used for timeline effects processing, transitions, and scaling.", value: "Auto", options: ["Auto", "CUDA", "Metal", "Vulkan", "OpenCL", "Software Only"], callback: function(val) { console.log("Hardware acceleration engine set to:", val) } },
                        { type: "select", label: "GPU Device Selection", description: "Select specific graphics hardware for intensive node rendering.", value: "Auto-select", options: ["GPU 0", "GPU 1", "All Available", "Auto-select"], callback: function(val) { console.log("GPU device selection set to:", val) } },
                        { type: "input", label: "RAM Allocation Reserve", description: "Amount of system RAM strictly reserved for background OS services.", value: "4 GB", callback: function(val) { console.log("RAM allocation reserve set to:", val) } },
                        { type: "toggle", label: "Dynamic Playback Resolution", description: "Lower real-time playback resolution automatically if frames begin dropping.", value: true, callback: function(val) { console.log("Dynamic playback resolution set to:", val) } },
                        { type: "select", label: "External Video Monitoring", description: "Route video preview output to a dedicated hardware display adapter.", value: "Disabled", options: ["Disabled", "Primary Screen", "Blackmagic/AJA DeckLink"], callback: function(val) { console.log("External video monitoring set to:", val) } },
                        { type: "toggle", label: "Audio Scrubbing During Drag", description: "Play short audio fragments while dragging the timeline playhead.", value: true, callback: function(val) { console.log("Audio scrubbing set to:", val) } },
                        { type: "input", label: "Pre-roll / Post-roll Duration", description: "Playback padding added before and after loop ranges or cut points.", value: "2.0s", callback: function(val) { console.log("Pre/post roll duration set to:", val) } }
                    ]
                },
                {
                    title: "Hardware Codecs & Decoding",
                    items: [
                        { type: "toggle", label: "Hardware Accelerated H.264/HEVC Decoding", description: "Utilize dedicated GPU media engines to decode compressed video formats.", value: true, callback: function(val) { console.log("Hardware decoding enabled:", val) } },
                        { type: "select", label: "Max Render Worker Threads", description: "Limit max CPU processing threads assigned to active tasks.", value: "Auto", options: ["Auto", "2 Threads", "4 Threads", "8 Threads", "16 Threads"], callback: function(val) { console.log("Max render worker threads set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Timeline & Editing",
            icon: "timeline.svg",
            sections: [
                {
                    title: "Sequence Defaults",
                    items: [
                        { type: "select", label: "Default Sequence Frame Rate", description: "Standard frame rate assigned to newly created empty sequences.", value: "24", options: ["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"], callback: function(val) { console.log("Default frame rate set to:", val) } },
                        { type: "select", label: "Default Sequence Resolution", description: "Canvas dimensions assigned to newly created empty sequences.", value: "1080p", options: ["720p", "1080p", "4K UHD", "4K DCI", "8K"], callback: function(val) { console.log("Default sequence resolution set to:", val) } },
                        { type: "select", label: "Timeline Snapping Magnetism", description: "Pixel distance threshold where edit points magnetize and snap.", value: "10px", options: ["5px", "10px", "15px", "20px", "25px"], callback: function(val) { console.log("Timeline snapping distance set to:", val) } },
                        { type: "input", label: "Default Transition Durations", description: "Length applied when adding standard video/audio crossfades.", value: "1.0s", callback: function(val) { console.log("Default transition duration set to:", val) } },
                        { type: "input", label: "Default Track Layout", description: "Track structure automatically populated in new timelines.", value: "V1-V3, A1-A6", callback: function(val) { console.log("Default track layout set to:", val) } },
                        { type: "toggle", label: "Ripple Edit Behavior", description: "Shift downstream clips automatically when trimming or deleting media.", value: true, callback: function(val) { console.log("Ripple edit behavior set to:", val) } }
                    ]
                },
                {
                    title: "Editing Operations",
                    items: [
                        { type: "select", label: "J-K-L Shuttle Speed Multiplier", description: "Speed stepping scale when using shuttle playback keybindings.", value: "2x / 4x / 8x / 16x", options: ["1.5x / 3x / 6x", "2x / 4x / 8x / 16x", "2x / 5x / 10x"], callback: function(val) { console.log("Shuttle speed multiplier set to:", val) } },
                        { type: "toggle", label: "Maintain Pitch During Fast Scrubbing", description: "Correct audio pitch shift when shuttling at accelerated speeds.", value: true, callback: function(val) { console.log("Maintain pitch set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Color Management",
            icon: "color-filter.svg",
            sections: [
                {
                    title: "Color Workspaces & LUTs",
                    items: [
                        { type: "select", label: "Working Color Space", description: "Internal working color space for node tree calculations and composite operations.", value: "Rec.709", options: ["Rec.709", "Rec.2020", "ACEScg", "DaVinci Wide Gamut"], callback: function(val) { console.log("Working color space set to:", val) } },
                        { type: "select", label: "Display Color Profile", description: "Monitored display transform applied to software viewport windows.", value: "sRGB", options: ["sRGB", "Display P3", "Rec.709", "System ICC Profile"], callback: function(val) { console.log("Display color profile set to:", val) } },
                        { type: "input", label: "Custom 3D LUT Folder Location", description: "Search path directory for user-imported 3D LUT look-up table files.", value: "/home/user/.local/share/xyla/luts", callback: function(val) { console.log("Custom LUT directory set to:", val) } },
                        { type: "select", label: "Color Scope Precision", description: "Sampling rate precision for Video Scopes (Histogram, Vectorscope, Waveform).", value: "Medium", options: ["Low (Fast)", "Medium", "High (Accurate)", "Realtime Maximum"], callback: function(val) { console.log("Color scope precision set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Audio",
            icon: "volume.svg",
            sections: [
                {
                    title: "Audio Routing & Engine",
                    items: [
                        { type: "select", label: "Audio Device Driver API", description: "Low-level audio platform subsystem layer for sound input and output.", value: "System Default", options: ["System Default", "CoreAudio (macOS)", "WASAPI/ASIO (Windows)", "PipeWire/ALSA"], callback: function(val) { console.log("Audio driver API set to:", val) } },
                        { type: "select", label: "Master Output Routing", description: "Primary hardware audio channel destination for timeline monitoring.", value: "System Default", options: ["System Default", "Headphone Jack", "Audio Interface 1/2"], callback: function(val) { console.log("Master output routing set to:", val) } },
                        { type: "select", label: "Microphone Input Routing", description: "Default input device assigned for voiceover track recordings.", value: "None", options: ["None", "Built-in Mic", "USB Interface Input"], callback: function(val) { console.log("Microphone input routing set to:", val) } },
                        { type: "select", label: "Sample Rate", description: "Audio engine operating frequency for mix processing and sampling.", value: "48 kHz", options: ["44.1 kHz", "48 kHz", "96 kHz"], callback: function(val) { console.log("Sample rate set to:", val) } },
                        { type: "select", label: "Audio Buffer Size / Latency", description: "Buffer frame size balancing hardware latency against processing stability.", value: "512", options: ["128", "256", "512", "1024", "2048"], callback: function(val) { console.log("Audio buffer size set to:", val) } }
                    ]
                },
                {
                    title: "Plugins & Processing",
                    items: [
                        { type: "input", label: "VST3 Plugin Search Path", description: "Directory location scanned for third-party audio processing plugins.", value: "/usr/lib/vst3", callback: function(val) { console.log("VST3 search path set to:", val) } },
                        { type: "button", label: "Rescan Audio Plugins", description: "Trigger an immediate scan to identify newly installed VST3/AudioUnit modules.", buttonText: "Run Plugin Scan", callback: function() { console.log("Triggering audio plugin scan...") } },
                        { type: "select", label: "Default Pan Law", description: "Attenuation compensation profile applied to center-panned mono channels.", value: "-3 dB Center", options: ["0 dB Flat", "-3 dB Center", "-4.5 dB Center", "-6 dB Center"], callback: function(val) { console.log("Default pan law set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "AI & Speech",
            icon: "sparkles.svg",
            sections: [
                {
                    title: "Transcription & Models",
                    items: [
                        { type: "select", label: "Speech-to-Text Model Precision", description: "Select neural network model complexity for offline automated subtitles.", value: "Base", options: ["Tiny (Fastest)", "Base", "Small", "Medium", "Large-v3 (Most Accurate)"], callback: function(val) { console.log("Speech-to-Text model precision set to:", val) } },
                        { type: "input", label: "ONNX / Whisper Model Directory", description: "Path where speech transcription model weights are saved.", value: "/home/user/.local/share/xyla/models", callback: function(val) { console.log("Whisper model directory set to:", val) } },
                        { type: "select", label: "AI Acceleration Execution Provider", description: "Hardware device driver utilized for local AI model inference.", value: "Auto", options: ["Auto", "CPU (OpenVINO)", "GPU (CUDA/TensorRT)", "DirectML"], callback: function(val) { console.log("AI execution provider set to:", val) } },
                        { type: "toggle", label: "Auto-Generate Speaker Markers", description: "Automatically classify and label distinct voices during text transcription.", value: true, callback: function(val) { console.log("Auto-generate speaker markers set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Shortcuts",
            icon: "keyboard.svg",
            sections: [
                {
                    title: "Keybindings",
                    items: [
                        { type: "select", label: "Active Keymap Schema", description: "Preset keyboard layout mimicking common editing suites.", value: "Default Xyla", options: ["Default Xyla", "Premiere Pro Style", "DaVinci Resolve Style", "Final Cut Pro Style"], callback: function(val) { console.log("Active keymap schema set to:", val) } },
                        { type: "input", label: "Command Search Filter", description: "Type action names or keys to filter active application bindings.", value: "", callback: function(val) { console.log("Command search filter set to:", val) } },
                        { type: "button", label: "Custom Shortcut Import/Export", description: "Save or load customized keyboard shortcut configuration files.", buttonText: "Export JSON/XML", callback: function() { console.log("Triggering shortcut configuration export...") } }
                    ]
                }
            ]
        },
        {
            name: "Export",
            icon: "file-export.svg",
            sections: [
                {
                    title: "Rendering & Delivery",
                    items: [
                        { type: "input", label: "Default Export Destination", description: "Fallback output directory selected when opening export workflows.", value: "/home/user/Videos", callback: function(val) { console.log("Default export destination set to:", val) } },
                        { type: "select", label: "Default Render Format / Codec", description: "Preferred default file container and compression video format.", value: "MP4 (H.264)", options: ["MP4 (H.264)", "QuickTime (ProRes)", "WebM (VP9/AV1)"], callback: function(val) { console.log("Default render format set to:", val) } },
                        { type: "select", label: "Bitrate Encoding Strategy", description: "Default rate control strategy used during final render jobs.", value: "VBR 2-Pass", options: ["CBR (Constant)", "VBR 1-Pass", "VBR 2-Pass", "Constant Quality (CQ/CRF)"], callback: function(val) { console.log("Bitrate encoding strategy set to:", val) } },
                        { type: "select", label: "Post-Render Action", description: "Automatic action triggered upon finishing queued render exports.", value: "None", options: ["None", "Play File", "Open File Location", "Shut Down Computer"], callback: function(val) { console.log("Post-render action set to:", val) } },
                        { type: "select", label: "Render Conflict Behavior", description: "Action taken if an output file with the same name already exists.", value: "Auto-increment filename", options: ["Overwrite", "Auto-increment filename", "Prompt User"], callback: function(val) { console.log("Render conflict behavior set to:", val) } }
                    ]
                }
            ]
        }
    ]
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
