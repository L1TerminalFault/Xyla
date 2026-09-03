import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Xyla 1.0
import "../components"
import "./timeline"

Item {
    id: root

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
    property var activeProject: activeProjectManager?.activeProject ?? null
    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null

    readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    readonly property real projectFps: {
        if (!activeProject)
            return 30.0;
        if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
            return activeProject.fps;
        }
        if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
            return activeProject.fpsNumerator / activeProject.fpsDenominator;
        }
        return 30.0;
    }

    property int headerWidth: 220
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 3600

    readonly property color bgDark: "#1a1a1a"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"
    readonly property real playheadMargin: 10.0

    property bool isMiddlePanning: false

    property var trackHeights: []
    property var trackOffsets: []
    property real totalTracksHeight: 200

    property real snapGuideFrame: -1
    property bool isSnapLineVisible: false
    property var activeSpacingGaps: []

    function openContextMenu(screenX, screenY, frame, trackIdx, clipData) {
        timelineContextMenu.openAt(screenX, screenY, frame, trackIdx, clipData);
    }

    XylaTimelineContextMenu {
        id: timelineContextMenu
        timelineRoot: root
        timelineModel: root.activeTimelineModel
        playbackManager: root.activePlaybackManager

        onDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips();
                root.updateContentWidth();
            }
        }

        onRippleDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips();
                root.updateContentWidth();
            }
        }

        onSplitRequested: function (frame, track) {
            if (root.activeTimelineModel && root.activePlaybackManager) {
                root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
                root.updateContentWidth();
            }
        }

        onSelectAllRequested: {
            if (root.activeTimelineModel) {
                var all = root.activeTimelineModel.getAllClips();
                var ids = [];
                for (var i = 0; i < all.length; ++i) {
                    ids.push(all[i].clipId);
                }
                root.activeTimelineModel.applyDirectSelection(ids);
            }
        }
    }

    function showSnapLine(frame) {
        snapGuideFrame = frame;
        isSnapLineVisible = (frame >= 0);
        activeSpacingGaps = [];
    }

    function showSpacingGuides(gapsList) {
        if (gapsList && gapsList.length > 0) {
            activeSpacingGaps = gapsList;
        } else {
            activeSpacingGaps = [];
        }
    }

    function hideSnapGuides() {
        isSnapLineVisible = false;
        snapGuideFrame = -1;
        activeSpacingGaps = [];
    }
    function updateTrackMetrics() {
        var count = activeTimelineModel ? activeTimelineModel.rowCount() : 0;
        var heights = [];
        var offsets = [];
        var cumY = 0;

        for (var i = 0; i < count; ++i) {
            var item = trackHeaderList.itemAtIndex ? trackHeaderList.itemAtIndex(i) : null;
            var h = item ? item.implicitHeight : (trackHeights[i] ?? 68);
            heights.push(h);
            offsets.push(cumY);
            cumY += h;
        }
        trackHeights = heights;
        trackOffsets = offsets;
        totalTracksHeight = Math.max(200, cumY);
    }

    function getTrackY(t) {
        if (t < 0 || !trackOffsets || t >= trackOffsets.length)
            return (t * 68);
        return trackOffsets[t];
    }

    function getTrackHeight(t) {
        if (t < 0 || !trackHeights || t >= trackHeights.length)
            return 68;
        return trackHeights[t];
    }

    function getTrackAtY(canvasY) {
        if (!trackOffsets || trackOffsets.length === 0)
            return 0;
        for (var i = trackOffsets.length - 1; i >= 0; --i) {
            if (canvasY >= trackOffsets[i])
                return i;
        }
        return 0;
    }

    function updateContentWidth() {
        if (!root.activeTimelineModel)
            return;
        var maxFrame = 0;
        var all = root.activeTimelineModel.getAllClips();
        for (var i = 0; i < all.length; ++i) {
            var endF = Number(all[i].startFrame) + Number(all[i].durationFrames);
            if (endF > maxFrame)
                maxFrame = endF;
        }
        var requiredPx = (maxFrame * root.zoomFactor) + 1000;
        root.contentWidth = Math.max(3600, requiredPx);
    }

    function applyZoom(factor, cursorScreenX) {
        var visibleTimelineX = cursorScreenX - root.headerWidth - root.playheadMargin;
        var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
        root.zoomFactor = newZoom;

        var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
        var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
        root.horizontalOffset = Math.max(0, Math.min(maxOffset, newOffset));
        root.updateContentWidth();
    }

    function frameToPx(frame) {
        return root.playheadMargin + (frame * root.zoomFactor);
    }

    function pxToFrame(px) {
        return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
    }

    function formatTimecode(frame) {
        var fps = root.projectFps;
        var totalSec = frame / fps;
        var hrs = Math.floor(totalSec / 3600);
        var mins = Math.floor((totalSec % 3600) / 60);
        var secs = Math.floor(totalSec % 60);
        var frames = Math.floor(frame % fps);

        function pad(n) {
            return n < 10 ? "0" + n : n;
        }
        return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames);
    }

    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomIn"] ?? "="
        onActivated: root.applyZoom(1.25, timelineCanvasViewport.width / 2)
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomOut"] ?? "-"
        onActivated: root.applyZoom(0.8, timelineCanvasViewport.width / 2)
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["playback.togglePlay"] ?? "Space"
        onActivated: root.activePlaybackManager?.togglePlay()
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomFit"] ?? "Shift+Z"
        onActivated: {
            root.horizontalOffset = 0.0;
            root.zoomFactor = 1.0;
            root.updateContentWidth();
        }
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.splitClip"] ?? "Ctrl+K"
        enabled: root.activeTimelineModel && root.activePlaybackManager
        onActivated: {
            if (root.activeTimelineModel && root.activePlaybackManager) {
                root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
                root.updateContentWidth();
            }
        }
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.delete"] ?? "Delete"
        enabled: root.activeTimelineModel && (root.activeTimelineModel.selectedClipIds?.length > 0 || (root.activeTimelineModel.selectedClipId ?? "") !== "")
        onActivated: {
            root.activeTimelineModel.deleteSelectedClips();
            root.updateContentWidth();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    Rectangle {
        id: marqueeRect
        color: "#253B82F6"
        border.color: "#3B82F6"
        border.width: 1
        visible: false
        z: 400
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar
        Rectangle {
            id: topToolBar
            color: root.bgDark
            Layout.fillWidth: true
            height: 40

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.borderDark
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: centerControls.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6
            }

            Row {
                id: centerControls
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    height: 32
                    width: transportRow.implicitWidth
                    color: "transparent"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 6

                    Row {
                        id: transportRow
                        anchors.verticalCenter: parent.verticalCenter

                        XylaIconButton {
                            roundLeft: true
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-track-prev.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.playFromStart()
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-back.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.jumpBackwardSeconds(5.0)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-left.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.stepBackward(1)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingForward
                            primary: isPlayingForward
                            iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.togglePlay()
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingReverse
                            primary: isPlayingReverse
                            iconSource: "qrc:/assets/icons/player-play-reverse.svg"
                            onClicked: {
                                if (!root.activePlaybackManager)
                                    return;
                                if (isPlayingReverse)
                                    root.activePlaybackManager.pause();
                                else
                                    root.activePlaybackManager.playReverse();
                            }
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-right.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.stepForward(1)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: true
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-forward.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.jumpForwardSeconds(5.0)
                        }
                    }
                }

                Rectangle {
                    width: 100
                    height: 32
                    color: "transparent"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                    }
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.left: centerControls.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                layoutDirection: Qt.RightToLeft
                spacing: 6

                XylaIconButton {
                    id: rippleSettingsBtn
                    ghost: true
                    iconSource: "qrc:/assets/icons/settings.svg"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Ripple Move Settings"
                    onClicked: ripplePopup.open()

                    XylaTimelineRippleSettingsPopup {
                        id: ripplePopup
                        x: rippleSettingsBtn.width - width
                        y: rippleSettingsBtn.height + 6
                        timelineModel: root.activeTimelineModel
                    }
                }
            }
        }

        XylaTimelineRuler {
            id: timelineRuler
            Layout.fillWidth: true
            headerWidth: root.headerWidth + root.playheadMargin
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            contentWidth: root.contentWidth
            fps: root.projectFps
            z: 250
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Left Side: Resizable Track Headers
            ListView {
                id: trackHeaderList
                Layout.preferredWidth: root.headerWidth
                Layout.fillHeight: true
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.activeTimelineModel
                interactive: false
                contentY: trackScrollArea.contentY

                delegate: XylaTrackHeader {
                    width: root.headerWidth
                    trackId: model.trackId || ""
                    trackName: model.trackName || ""
                    trackKind: model.trackKind !== undefined ? model.trackKind : 0

                    onImplicitHeightChanged: root.updateTrackMetrics()
                    onTrackHeightChanged: root.updateTrackMetrics()
                    Component.onCompleted: root.updateTrackMetrics()
                }
            }

            // Right Side: Unified 2D Timeline Canvas
            Flickable {
                id: trackScrollArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: root.contentWidth + root.playheadMargin
                contentHeight: root.totalTracksHeight
                interactive: false

                DragHandler {
                    id: middleDragHandler
                    target: null
                    acceptedButtons: Qt.MiddleButton
                    property real startHorizOffset: 0
                    property real startContentY: 0

                    onActiveChanged: {
                        root.isMiddlePanning = active;
                        if (active) {
                            startHorizOffset = root.horizontalOffset;
                            startContentY = trackScrollArea.contentY;
                        }
                    }

                    onTranslationChanged: {
                        if (active) {
                            var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
                            root.horizontalOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));

                            var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                            trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, startContentY - translation.y));
                        }
                    }
                }

                WheelHandler {
                    id: wheelHandler
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var cursorX = event.point?.position?.x ?? wheelHandler.point?.position?.x ?? (trackScrollArea.width / 2);

                        if (event.modifiers & Qt.ControlModifier) {
                            var factor = event.angleDelta.y > 0 ? 1.15 : 0.85;
                            root.applyZoom(factor, cursorX + root.headerWidth);
                            return;
                        }

                        var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
                        var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;

                        var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);

                        if (isHorizontal) {
                            var deltaX = pDeltaX !== 0 ? -pDeltaX : -pDeltaY;
                            var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
                            root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                        } else {
                            var deltaY = -pDeltaY;
                            var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                            trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY + deltaY));
                        }
                    }
                }

                Item {
                    id: timelineCanvasViewport
                    x: root.playheadMargin - root.horizontalOffset
                    width: root.contentWidth
                    height: trackScrollArea.contentHeight

                    Column {
                        anchors.fill: parent
                        Repeater {
                            model: root.activeTimelineModel ? root.activeTimelineModel.rowCount() : 0
                            Rectangle {
                                width: timelineCanvasViewport.width
                                height: root.getTrackHeight(index)
                                color: "#151515"
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: root.borderDark
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        property real startGlobalX: 0
                        property real startGlobalY: 0
                        property real startCanvasX: 0
                        property real startCanvasY: 0
                        property bool isMarquee: false

                        onPressed: function (mouse) {
                            if (mouse.button === Qt.RightButton)
                                return;

                            var globalPt = mapToItem(root, mouse.x, mouse.y);
                            startGlobalX = globalPt.x;
                            startGlobalY = globalPt.y;
                            startCanvasX = mouse.x;
                            startCanvasY = mouse.y;
                            isMarquee = false;
                        }

                        onPositionChanged: function (mouse) {
                            if (mouse.buttons & Qt.RightButton)
                                return;

                            var globalPt = mapToItem(root, mouse.x, mouse.y);
                            var dx = globalPt.x - startGlobalX;
                            var dy = globalPt.y - startGlobalY;

                            if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                                isMarquee = true;
                                if (!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier))) {
                                    if (root.activeTimelineModel)
                                        root.activeTimelineModel.clearSelection();
                                }
                            }

                            if (isMarquee) {
                                var x1 = Math.min(startGlobalX, globalPt.x);
                                var x2 = Math.max(startGlobalX, globalPt.x);
                                var y1 = Math.min(startGlobalY, globalPt.y);
                                var y2 = Math.max(startGlobalY, globalPt.y);

                                marqueeRect.x = x1;
                                marqueeRect.y = y1;
                                marqueeRect.width = x2 - x1;
                                marqueeRect.height = y2 - y1;
                                marqueeRect.visible = true;

                                var canvasX1 = Math.min(startCanvasX, mouse.x);
                                var canvasX2 = Math.max(startCanvasX, mouse.x);
                                var canvasY1 = Math.min(startCanvasY, mouse.y);
                                var canvasY2 = Math.max(startCanvasY, mouse.y);

                                var startF = root.pxToFrame(canvasX1);
                                var endF = root.pxToFrame(canvasX2);
                                var startT = root.getTrackAtY(canvasY1);
                                var endT = root.getTrackAtY(canvasY2);

                                var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
                                if (root.activeTimelineModel) {
                                    root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
                                }
                            }
                        }

                        onReleased: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                var targetF = root.pxToFrame(mouse.x);
                                var targetT = root.getTrackAtY(mouse.y);
                                root.openContextMenu(overlayPt.x, overlayPt.y, targetF, targetT, null);
                                return;
                            }

                            if (!isMarquee && root.activeTimelineModel) {
                                root.activeTimelineModel.clearSelection();
                            }
                            isMarquee = false;
                            marqueeRect.visible = false;
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["xyla/media-asset", "text/uri-list"]
                        z: 2

                        onEntered: drag => drag.accept(Qt.CopyAction)
                        onPositionChanged: drag => drag.accept(Qt.CopyAction)

                        onDropped: function (drop) {
                            drop.accept(Qt.CopyAction);
                            if (!root.activeTimelineModel)
                                return;
                            var rawUrl = "";
                            if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
                                rawUrl = drop.urls[0].toString();
                            } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
                                rawUrl = drop.getDataAsString("text/uri-list").trim();
                            }

                            if (!rawUrl || rawUrl.length === 0)
                                return;
                            var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
                            if (assetName.length === 0)
                                assetName = "Clip";

                            var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl;
                            var dropFrame = root.pxToFrame(drop.x);
                            var dropTrack = root.getTrackAtY(drop.y);
                            var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150;

                            root.activeTimelineModel.addClip(realAssetId, assetName, dropTrack, dropFrame, assetDuration, 0);
                            root.updateContentWidth();
                        }
                    }

                    Item {
                        id: unifiedClipsLayer
                        anchors.fill: parent
                        z: 10

                        Connections {
                            target: root.activeTimelineModel ? root.activeTimelineModel : null
                            function onTrackDataChanged(trackIndex) {
                                clipRepeater.refreshAllClips();
                                root.updateContentWidth();
                                root.updateTrackMetrics();
                            }
                            function onTrackCountChanged() {
                                clipRepeater.refreshAllClips();
                                root.updateContentWidth();
                                root.updateTrackMetrics();
                            }
                            function onClipPropertiesChanged(clipId) {
                                clipRepeater.refreshAllClips();
                            }
                            function onDataChanged(topLeft, bottomRight, roles) {
                                clipRepeater.refreshAllClips();
                            }
                        }

                        Repeater {
                            id: clipRepeater
                            model: []

                            function refreshAllClips() {
                                if (root.activeTimelineModel) {
                                    model = root.activeTimelineModel.getAllClips();
                                } else {
                                    model = [];
                                }
                            }

                            Component.onCompleted: refreshAllClips()

                            XylaClipCard {
                                timelineRoot: root
                                clipData: modelData
                                zoomFactor: root.zoomFactor
                            }
                        }
                    }

                    Item {
                        id: snapGuideLayer
                        anchors.fill: parent
                        z: 500

                        // Vertical Snap Line
                        Rectangle {
                            id: snapLine
                            visible: root.isSnapLineVisible && root.snapGuideFrame >= 0
                            x: Math.round(root.snapGuideFrame * root.zoomFactor)
                            width: 1
                            height: parent.height
                            color: "#2563eb"
                            opacity: 0.8
                            z: 150

                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: "#3b82f6"
                            }
                        }

                        Item {
                            id: spacingGuide
                            visible: root.activeSpacingGaps.length > 0
                            anchors.fill: parent
                            z: 140

                            Repeater {
                                model: root.activeSpacingGaps

                                Rectangle {
                                    id: gapRect
                                    readonly property bool isActive: modelData.isActive === true
                                    x: Math.round(Number(modelData.start) * root.zoomFactor)
                                    width: Math.max(1, Math.round((Number(modelData.end) - Number(modelData.start)) * root.zoomFactor))
                                    height: parent.height
                                    color: isActive ? Qt.rgba(0.145, 0.388, 0.922, 0.18) : Qt.rgba(0.145, 0.388, 0.922, 0.10)
                                    border.color: isActive ? "#3b82f6" : "#2563eb"
                                    border.width: 1

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: gapBadgeText.implicitWidth + 10
                                        height: 18
                                        color: gapRect.isActive ? "#2563eb" : "#1d4ed8"
                                        radius: 4
                                        border.color: gapRect.isActive ? "#60a5fa" : "#3b82f6"
                                        border.width: 1

                                        Text {
                                            id: gapBadgeText
                                            anchors.centerIn: parent
                                            text: (modelData.gapFrames !== undefined ? modelData.gapFrames : "") + "f"
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Playhead
    Item {
        x: root.headerWidth
        y: topToolBar.height
        width: parent.width - root.headerWidth
        height: parent.height - y
        clip: true
        z: 200

        XylaPlayhead {
            id: mainPlayhead
            timelineRoot: root
            activeTimelineModel: root.activeTimelineModel
            currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            playheadMargin: root.playheadMargin
            headerWidth: root.headerWidth
            height: parent.height
        }
    }

    // Sidebar Resizer
    Item {
        id: sidebarResizer
        width: 8
        x: root.headerWidth - 4
        y: topToolBar.height
        height: parent.height - y
        z: 350

        Rectangle {
            anchors.centerIn: parent
            width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
            height: parent.height
            color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"

            Behavior on width {
                NumberAnimation {
                    duration: 80
                }
            }
        }

        MouseArea {
            id: resizerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property int startMouseX: 0
            property int startWidth: 0

            onPressed: function (mouse) {
                var pt = mapToItem(root, mouse.x, mouse.y);
                startMouseX = pt.x;
                startWidth = root.headerWidth;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(root, mouse.x, mouse.y);
                    var deltaX = pt.x - startMouseX;
                    var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
                    root.headerWidth = newW;
                }
            }
        }
    }
}
