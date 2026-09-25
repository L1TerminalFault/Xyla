import QtQuick
import Xyla.Render 1.0
import "./sections"

Item {
    id: root

    enum Mode {
        Timeline,
        Clip
    }

    property int mode: BaseMonitor.Mode.Timeline
    property bool showFooter: true
    property string activeDockId: mode === BaseMonitor.Mode.Timeline ? "ProjectmonitorPanel" : "ClipmonitorPanel"

    readonly property bool isClipMode: root.mode === BaseMonitor.Mode.Clip

    readonly property bool isCurrentlyPlaying: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController) ? Boolean(clipMonitorController.isPlaying) : false;
        } else {
            return (typeof playbackManager !== "undefined" && playbackManager) ? Boolean(playbackManager.isPlaying) : false;
        }
    }

    readonly property int currentFrame: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.currentFrame !== undefined) ? clipMonitorController.currentFrame : 0;
        } else {
            return (typeof playbackManager !== "undefined" && playbackManager && playbackManager.currentFrame !== undefined) ? playbackManager.currentFrame : 0;
        }
    }

    readonly property int totalFrames: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.totalFrames !== undefined) ? clipMonitorController.totalFrames : 0;
        } else {
            if (typeof timelineModel !== "undefined" && timelineModel && timelineModel.durationFrames !== undefined) {
                return timelineModel.durationFrames;
            } else if (typeof projectManager !== "undefined" && projectManager && projectManager.activeProject) {
                return projectManager.activeProject.durationFrames || 0;
            }
            return 0;
        }
    }

    readonly property real activeFps: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.fps > 0) ? clipMonitorController.fps : 30.0;
        } else {
            return (typeof timelineModel !== "undefined" && timelineModel && timelineModel.fps > 0) ? timelineModel.fps : 30.0;
        }
    }

    // Safe Margins (bound to GuideController)
    property bool actionSafeEnabled: (typeof guideController !== "undefined" && guideController && guideController.actionSafeEnabled !== undefined) ? guideController.actionSafeEnabled : false
    property bool titleSafeEnabled: (typeof guideController !== "undefined" && guideController && guideController.titleSafeEnabled !== undefined) ? guideController.titleSafeEnabled : false
    property real actionSafePercent: (typeof guideController !== "undefined" && guideController && guideController.actionSafePercent !== undefined) ? guideController.actionSafePercent : 90.0
    property real titleSafePercent: (typeof guideController !== "undefined" && guideController && guideController.titleSafePercent !== undefined) ? guideController.titleSafePercent : 80.0

    // Grid properties
    property bool gridEnabled: false
    property int gridRows: 3
    property int gridColumns: 3
    property real gridOpacity: 0.35
    property color gridColor: "#ffffff"

    // Rulers & Guides (bound to GuideController)
    property bool rulersEnabled: (typeof guideController !== "undefined" && guideController && guideController.rulersEnabled !== undefined) ? guideController.rulersEnabled : false
    property bool guidesEnabled: (typeof guideController !== "undefined" && guideController && guideController.guidesEnabled !== undefined) ? guideController.guidesEnabled : true
    property bool guidesLocked: (typeof guideController !== "undefined" && guideController && guideController.guidesLocked !== undefined) ? guideController.guidesLocked : false
    property var horizontalGuides: (typeof guideController !== "undefined" && guideController && guideController.horizontalGuides !== undefined) ? guideController.horizontalGuides : []
    property var verticalGuides: (typeof guideController !== "undefined" && guideController && guideController.verticalGuides !== undefined) ? guideController.verticalGuides : []

    // Overlays
    property bool timecodeOverlayEnabled: false
    property string timecodeOverlayPosition: "bottom-right"

    // Zoom & Pan
    property bool isFitMode: true
    property real currentZoomScale: 1.0
    property string zoomLabelText: "Fit"
    property bool isCustomZoomLevel: false

    property real panOffsetX: 0.0
    property real panOffsetY: 0.0

    readonly property real nativeVideoWidth: (typeof projectManager !== "undefined" && projectManager.activeProject) ? projectManager.activeProject.width : 1920
    readonly property real nativeVideoHeight: (typeof projectManager !== "undefined" && projectManager.activeProject) ? projectManager.activeProject.height : 1080

    function formatSMPTE(frames, fps) {
        var f = (typeof frames === "number" && !isNaN(frames)) ? Math.max(0, Math.floor(frames)) : 0;
        var rate = (typeof fps === "number" && fps > 0) ? Math.round(fps) : 30;

        var frameNum = f % rate;
        var totalSecs = Math.floor(f / rate);
        var sec = totalSecs % 60;
        var min = Math.floor(totalSecs / 60) % 60;
        var hrs = Math.floor(totalSecs / 3600);

        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        return pad(hrs) + ":" + pad(min) + ":" + pad(sec) + ":" + pad(frameNum);
    }

    function snapGuidePosition(orientation, rawVal, excludeIndex) {
        var snapTargets = [];
        var maxCoord = (orientation === "horizontal") ? root.nativeVideoHeight : root.nativeVideoWidth;
        var list = (orientation === "horizontal") ? root.horizontalGuides : root.verticalGuides;

        snapTargets.push(maxCoord / 2);

        var aMargin = maxCoord * (1.0 - root.actionSafePercent / 100.0) / 2;
        snapTargets.push(aMargin);
        snapTargets.push(maxCoord - aMargin);

        var tMargin = maxCoord * (1.0 - root.titleSafePercent / 100.0) / 2;
        snapTargets.push(tMargin);
        snapTargets.push(maxCoord - tMargin);

        for (var i = 0; i < list.length; ++i) {
            if (i !== excludeIndex)
                snapTargets.push(Number(list[i]));
        }

        var effectiveScale = (root.isFitMode ? 1.0 : root.currentZoomScale) * (overlaysContainer.width / root.nativeVideoWidth);
        var threshold = Math.max(2, 8.0 / Math.max(0.01, effectiveScale));

        for (var t = 0; t < snapTargets.length; ++t) {
            if (Math.abs(rawVal - snapTargets[t]) <= threshold) {
                return snapTargets[t];
            }
        }
        return rawVal;
    }

    function addGuide(orientation, pos) {
        if (typeof guideController !== "undefined" && guideController) {
            guideController.addGuide(orientation, pos);
        }
    }

    function updateGuide(orientation, index, pos) {
        if (typeof guideController !== "undefined" && guideController) {
            guideController.updateGuide(orientation, index, pos);
        }
    }

    function removeGuide(orientation, index) {
        if (typeof guideController !== "undefined" && guideController) {
            guideController.removeGuide(orientation, index);
        }
    }

    function clearAllGuides() {
        if (typeof guideController !== "undefined" && guideController) {
            guideController.clearAllGuides();
        }
    }

    function getFitScale() {
        if (viewportContainer.width <= 0 || viewportContainer.height <= 0)
            return 1.0;
        return Math.min(viewportContainer.width / root.nativeVideoWidth, viewportContainer.height / root.nativeVideoHeight);
    }

    function resetToFit() {
        root.isFitMode = true;
        root.isCustomZoomLevel = false;
        root.zoomLabelText = "Fit";
        root.currentZoomScale = 1.0;
        root.panOffsetX = 0.0;
        root.panOffsetY = 0.0;
    }

    function setPresetZoom(scaleRatio, label) {
        if (scaleRatio <= 0.0 || label === "Fit") {
            resetToFit();
            return;
        }

        var fitS = getFitScale();
        root.isFitMode = false;
        root.isCustomZoomLevel = false;
        root.zoomLabelText = label;
        root.currentZoomScale = scaleRatio / fitS;
        root.panOffsetX = 0.0;
        root.panOffsetY = 0.0;
    }

    function applyWheelZoom(delta, cursorX, cursorY) {
        if (viewportContainer.width <= 0 || viewportContainer.height <= 0)
            return;
        var factor = Math.exp(delta * 0.002);
        var currentEffective = root.isFitMode ? 1.0 : root.currentZoomScale;
        var newScale = Math.max(0.1, Math.min(15.0, currentEffective * factor));
        var k = newScale / currentEffective;

        var dx = cursorX - (viewportContainer.width / 2);
        var dy = cursorY - (viewportContainer.height / 2);

        root.isFitMode = false;
        root.isCustomZoomLevel = true;
        root.currentZoomScale = newScale;

        root.panOffsetX = dx * (1.0 - k) + root.panOffsetX * k;
        root.panOffsetY = dy * (1.0 - k) + root.panOffsetY * k;
    }

    function applyPinchZoom(deltaScale, cursorX, cursorY) {
        if (viewportContainer.width <= 0 || viewportContainer.height <= 0)
            return;
        var currentEffective = root.isFitMode ? 1.0 : root.currentZoomScale;
        var newScale = Math.max(0.1, Math.min(15.0, currentEffective * deltaScale));
        var k = newScale / currentEffective;

        var dx = cursorX - (viewportContainer.width / 2);
        var dy = cursorY - (viewportContainer.height / 2);

        root.isFitMode = false;
        root.isCustomZoomLevel = true;
        root.currentZoomScale = newScale;

        root.panOffsetX = dx * (1.0 - k) + root.panOffsetX * k;
        root.panOffsetY = dy * (1.0 - k) + root.panOffsetY * k;
    }

    function doSeek(frame) {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController) {
                clipMonitorController.seekFrame(frame);
            }
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager) {
                playbackManager.scrubToFrame(frame);
            }
        }
    }

    function doStepBackward() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.stepBackward();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.stepBackward();
        }
    }

    function doTogglePlay() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.togglePlay();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.togglePlay();
        }
    }

    function doStepForward() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.stepForward();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.stepForward();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#101012"
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && typeof layoutController !== "undefined" && layoutController) {
                layoutController.setActiveDockId(root.activeDockId);
            }
        }
    }

    Shortcut {
        sequence: "Shift+Z"
        onActivated: root.resetToFit()
    }

    Shortcut {
        sequence: "1"
        onActivated: root.setPresetZoom(1.0, "100%")
    }

    MonitorHeader {
        id: monitorHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        actionSafeEnabled: root.actionSafeEnabled
        titleSafeEnabled: root.titleSafeEnabled
        actionSafePercent: root.actionSafePercent
        titleSafePercent: root.titleSafePercent

        onActionSafeEnabledChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.actionSafeEnabled = monitorHeader.actionSafeEnabled;
            }
        }

        onTitleSafeEnabledChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.titleSafeEnabled = monitorHeader.titleSafeEnabled;
            }
        }

        onActionSafePercentChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.actionSafePercent = monitorHeader.actionSafePercent;
            }
        }

        onTitleSafePercentChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.titleSafePercent = monitorHeader.titleSafePercent;
            }
        }

        gridEnabled: root.gridEnabled
        gridRows: root.gridRows
        gridColumns: root.gridColumns
        gridOpacity: root.gridOpacity
        gridColor: root.gridColor

        onGridEnabledChanged: root.gridEnabled = monitorHeader.gridEnabled
        onGridRowsChanged: root.gridRows = monitorHeader.gridRows
        onGridColumnsChanged: root.gridColumns = monitorHeader.gridColumns
        onGridOpacityChanged: root.gridOpacity = monitorHeader.gridOpacity
        onGridColorChanged: root.gridColor = monitorHeader.gridColor

        rulersEnabled: root.rulersEnabled
        guidesEnabled: root.guidesEnabled
        guidesLocked: root.guidesLocked
        horizontalGuides: root.horizontalGuides
        verticalGuides: root.verticalGuides

        onRulersEnabledChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.rulersEnabled = monitorHeader.rulersEnabled;
            }
        }
        onGuidesEnabledChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.guidesEnabled = monitorHeader.guidesEnabled;
            }
        }
        onGuidesLockedChanged: {
            if (typeof guideController !== "undefined" && guideController) {
                guideController.guidesLocked = monitorHeader.guidesLocked;
            }
        }
        onClearGuidesRequested: root.clearAllGuides()

        timecodeOverlayEnabled: root.timecodeOverlayEnabled
        timecodeOverlayPosition: root.timecodeOverlayPosition

        onTimecodeOverlayEnabledChanged: root.timecodeOverlayEnabled = monitorHeader.timecodeOverlayEnabled
        onTimecodeOverlayPositionChanged: root.timecodeOverlayPosition = monitorHeader.timecodeOverlayPosition

        currentZoomText: root.zoomLabelText
        isCustomZoom: root.isCustomZoomLevel
        customZoomPercent: root.currentZoomScale * root.getFitScale() * 100.0

        onZoomPresetSelected: function (ratio, label) {
            root.setPresetZoom(ratio, label);
        }
        onResetZoomRequested: root.resetToFit()
    }

    Item {
        id: viewportContainer
        anchors.top: monitorHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: monitorFooter.top
        clip: true

        WheelHandler {
            id: zoomWheel
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function (event) {
                if (event.modifiers & Qt.ControlModifier) {
                    var dy = (event.angleDelta.y !== 0) ? event.angleDelta.y : (event.pixelDelta.y * 6);
                    if (dy !== 0) {
                        var pt = zoomWheel.point.position;
                        root.applyWheelZoom(dy, pt.x, pt.y);
                    }
                }
            }
        }

        PinchHandler {
            id: pinchHandler
            target: null

            onScaleChanged: function (delta) {
                var pt = pinchHandler.point.position;
                root.applyPinchZoom(delta, pt.x, pt.y);
            }
        }

        DragHandler {
            target: null
            acceptedButtons: Qt.MiddleButton
            property real startPanX: 0
            property real startPanY: 0

            onActiveChanged: {
                if (active) {
                    startPanX = root.panOffsetX;
                    startPanY = root.panOffsetY;
                }
            }

            onTranslationChanged: {
                if (active) {
                    root.panOffsetX = startPanX + translation.x;
                    root.panOffsetY = startPanY + translation.y;
                }
            }
        }

        Item {
            id: videoTransformWrapper
            width: parent.width
            height: parent.height

            x: Math.round(root.panOffsetX)
            y: Math.round(root.panOffsetY)

            scale: root.isFitMode ? 1.0 : root.currentZoomScale
            transformOrigin: Item.Center

            XylaVideoSurface {
                id: videoSurface
                anchors.fill: parent
                visible: !root.isClipMode || (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.hasVideo)

                surfaceType: root.mode === BaseMonitor.Mode.Timeline ? 0 : 1

                Connections {
                    target: (!root.isClipMode && typeof timelineCompositor !== "undefined") ? timelineCompositor : null
                    function onFrameComposited() {
                        videoSurface.onFrameComposited();
                    }
                }

                Connections {
                    target: (root.isClipMode && typeof clipMonitorController !== "undefined") ? clipMonitorController : null
                    function onFrameComposited() {
                        videoSurface.onFrameComposited();
                    }
                }
            }

            Item {
                id: overlaysContainer
                anchors.centerIn: parent
                z: 200

                readonly property real videoAspect: root.nativeVideoWidth / root.nativeVideoHeight
                readonly property real wrapperAspect: parent.width / Math.max(1, parent.height)

                width: wrapperAspect > videoAspect ? (parent.height * videoAspect) : parent.width
                height: wrapperAspect > videoAspect ? parent.height : (parent.width / videoAspect)

                // 1. Grid
                Item {
                    id: gridOverlay
                    anchors.fill: parent
                    visible: root.gridEnabled

                    Repeater {
                        model: Math.max(0, root.gridRows - 1)
                        Rectangle {
                            width: parent.width
                            height: 1
                            y: Math.round((index + 1) * parent.height / root.gridRows)
                            color: root.gridColor
                            opacity: root.gridOpacity
                        }
                    }

                    Repeater {
                        model: Math.max(0, root.gridColumns - 1)
                        Rectangle {
                            width: 1
                            height: parent.height
                            x: Math.round((index + 1) * parent.width / root.gridColumns)
                            color: root.gridColor
                            opacity: root.gridOpacity
                        }
                    }
                }

                // 2. Action Safe
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (root.actionSafePercent / 100.0)
                    height: parent.height * (root.actionSafePercent / 100.0)
                    color: "transparent"
                    border.color: "#00e5ff"
                    border.width: 1
                    opacity: 0.8
                    visible: root.actionSafeEnabled

                    Rectangle {
                        width: 1
                        height: 8
                        anchors.top: parent.top
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.top: parent.top
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.top: parent.top
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.top: parent.top
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                }

                // 3. Title Safe
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (root.titleSafePercent / 100.0)
                    height: parent.height * (root.titleSafePercent / 100.0)
                    color: "transparent"
                    border.color: "#facc15"
                    border.width: 1
                    opacity: 0.8
                    visible: root.titleSafeEnabled

                    Rectangle {
                        width: 1
                        height: 8
                        anchors.top: parent.top
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.top: parent.top
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.top: parent.top
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.top: parent.top
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 1
                        height: 8
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                    Rectangle {
                        width: 8
                        height: 1
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        color: parent.border.color
                    }
                }

                // 4. Center Crosshair
                Item {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    visible: root.actionSafeEnabled || root.titleSafeEnabled

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 1
                        color: "#ffffff"
                        opacity: 0.5
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: 14
                        color: "#ffffff"
                        opacity: 0.5
                    }
                }

                // 5. Guides Overlay
                MonitorGuidesOverlay {
                    anchors.fill: parent
                    z: 250

                    nativeWidth: root.nativeVideoWidth
                    nativeHeight: root.nativeVideoHeight
                    snapFunction: root.snapGuidePosition

                    horizontalGuides: root.horizontalGuides
                    verticalGuides: root.verticalGuides
                    guidesVisible: root.guidesEnabled
                    guidesLocked: root.guidesLocked

                    onGuideMoved: function (orientation, index, pos) {
                        root.updateGuide(orientation, index, pos);
                    }

                    onGuideDeleted: function (orientation, index) {
                        root.removeGuide(orientation, index);
                    }
                }
            }
        }

        // --- Rulers (Pinned inside viewport) ---
        MonitorRulers {
            anchors.fill: parent
            z: 300
            visible: root.rulersEnabled

            nativeWidth: root.nativeVideoWidth
            nativeHeight: root.nativeVideoHeight
            snapFunction: root.snapGuidePosition
            videoScale: (root.isFitMode ? 1.0 : root.currentZoomScale) * (overlaysContainer.width / root.nativeVideoWidth)

            videoOriginX: (viewportContainer.width / 2) + root.panOffsetX - (overlaysContainer.width * (root.isFitMode ? 1.0 : root.currentZoomScale) / 2)
            videoOriginY: (viewportContainer.height / 2) + root.panOffsetY - (overlaysContainer.height * (root.isFitMode ? 1.0 : root.currentZoomScale) / 2)

            onCreateGuideRequested: function (orientation, pos) {
                root.addGuide(orientation, pos);
            }
        }

        // --- Monitor Window Timecode HUD (Static corner positioning) ---
        Rectangle {
            id: timecodeHud
            visible: root.timecodeOverlayEnabled
            z: 280
            color: "#b8000000"
            border.color: "#30ffffff"
            border.width: 1
            radius: 4

            readonly property int padH: 8
            readonly property int padV: 4
            readonly property int margin: 12
            readonly property int rulerOffset: root.rulersEnabled ? 18 : 0

            width: hudTimeText.implicitWidth + (padH * 2)
            height: hudTimeText.implicitHeight + (padV * 2)

            readonly property bool isLeft: root.timecodeOverlayPosition.indexOf("left") !== -1
            readonly property bool isTop: root.timecodeOverlayPosition.indexOf("top") !== -1

            x: isLeft ? (margin + rulerOffset) : (viewportContainer.width - width - margin)
            y: isTop ? (margin + rulerOffset) : (viewportContainer.height - height - margin)

            Text {
                id: hudTimeText
                anchors.centerIn: parent
                text: root.formatSMPTE(root.currentFrame, root.activeFps)
                color: "#ffffff"
                font.family: "JetBrains Mono, Roboto Mono, monospace"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 0.8
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: root.resetToFit()
        }
    }

    Rectangle {
        anchors.top: monitorHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: monitorFooter.top
        color: "#141416"
        visible: root.isClipMode && typeof clipMonitorController !== "undefined" && clipMonitorController && !clipMonitorController.hasVideo && clipMonitorController.hasAudio

        Text {
            anchors.centerIn: parent
            text: "Audio Clip Preview"
            color: "#666666"
            font.pixelSize: 14
        }
    }

    MonitorFooter {
        id: monitorFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.showFooter

        isCurrentlyPlaying: root.isCurrentlyPlaying
        currentFrame: root.currentFrame
        totalFrames: root.totalFrames
        activeFps: root.activeFps

        onSeekRequested: function (frame) {
            root.doSeek(frame);
        }
        onStepBackward: root.doStepBackward()
        onTogglePlay: root.doTogglePlay()
        onStepForward: root.doStepForward()

        onInsertRequested: {
            if (typeof timelineModel !== "undefined" && timelineModel && typeof clipMonitorController !== "undefined" && clipMonitorController) {
                timelineModel.insertClip(clipMonitorController.currentAssetId, monitorFooter.inPoint, monitorFooter.outPoint);
            }
        }

        onOverwriteRequested: {
            if (typeof timelineModel !== "undefined" && timelineModel && typeof clipMonitorController !== "undefined" && clipMonitorController) {
                timelineModel.overwriteClip(clipMonitorController.currentAssetId, monitorFooter.inPoint, monitorFooter.outPoint);
            }
        }
    }
}
