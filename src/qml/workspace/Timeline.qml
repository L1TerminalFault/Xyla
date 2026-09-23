import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Xyla 1.0
import "../components"
import "./timeline"

Item {
    id: root

    HoverHandler {
        onHoveredChanged: if (hovered && typeof layoutController !== "undefined" && layoutController)
            layoutController.setActiveDockId("TimelinePanel")
    }

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
    property var activeProject: activeProjectManager?.activeProject ?? null
    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
    property var activeMixerModel: typeof mixerModel !== "undefined" ? mixerModel : null

    readonly property int trackCount: activeTimelineModel ? activeTimelineModel.trackCount : 0
    readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    property double zoomFactor: activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0
    property real horizontalOffset: activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0
    property real contentWidth: 3600
    property int cachedMaxFrame: 0

    property bool showAudioWaveforms: true
    property int thumbnailMode: 1

    readonly property real projectFps: {
        if (!activeProject)
            return 30.0;
        if (typeof activeProject.fps === "number" && activeProject.fps > 0)
            return activeProject.fps;
        if (activeProject.fpsNumerator && activeProject.fpsDenominator)
            return activeProject.fpsNumerator / activeProject.fpsDenominator;
        return 30.0;
    }

    property int headerWidth: 220
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600
    property int paletteStripWidth: 8

    readonly property color bgDark: "#141414"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"
    readonly property real playheadMargin: 0.0

    readonly property color videoTrackBg: "#141414"
    readonly property color audioTrackBg: "#222222"

    property var trackHeights: []
    property var trackOffsets: []
    property real totalTracksHeight: 200

    property real snapGuideFrame: -1
    property bool isSnapLineVisible: false
    property var activeSpacingGaps: []
    property bool isMiddlePanning: false

    function getTrackBgColor(trackIdx) {
        if (!root.activeTimelineModel)
            return root.videoTrackBg;
        var kind = root.activeTimelineModel.getTrackKind(trackIdx);
        return (kind === 1) ? root.audioTrackBg : root.videoTrackBg;
    }

    function isPlayheadOnClipInTrack(trackIdx) {
        if (!root.activeTimelineModel)
            return false;
        var clips = root.activeTimelineModel.getClipsForTrack(trackIdx);
        var pf = root.playheadFrame;
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            var startF = Number(c.startFrame);
            var endF = startF + Number(c.durationFrames);
            if (pf >= startF && pf < endF)
                return true;
        }
        return false;
    }

    // 100% Robust metric calculation with safe fallback of 68px
    function updateTrackMetrics() {
        var count = root.trackCount > 0 ? root.trackCount : (root.activeTimelineModel ? root.activeTimelineModel.trackCount : 0);
        var heights = [];
        var offsets = [];
        var cumY = 0;

        for (var i = 0; i < count; ++i) {
            var h = 68;
            if (trackHeights && i < trackHeights.length && typeof trackHeights[i] === "number" && trackHeights[i] > 0) {
                h = trackHeights[i];
            } else if (typeof trackHeaderColumn !== "undefined" && trackHeaderColumn && trackHeaderColumn.children && i < trackHeaderColumn.children.length) {
                var item = trackHeaderColumn.children[i];
                if (item && item.implicitHeight && item.implicitHeight > 0) {
                    h = item.implicitHeight;
                }
            }
            heights.push(h);
            offsets.push(cumY);
            cumY += h;
        }
        trackHeights = heights;
        trackOffsets = offsets;
        totalTracksHeight = Math.max(cumY, count * 68);
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
        var requiredPx = (root.cachedMaxFrame * root.zoomFactor) + 1500;
        root.contentWidth = Math.max(3600, requiredPx);
    }

    function findClipDelegate(clipId) {
        if (!clipId)
            return null;
        for (var i = 0; i < clipRepeater.count; ++i) {
            var item = clipRepeater.itemAt(i);
            if (item && item.clipData && item.clipData.clipId === clipId)
                return item;
        }
        return null;
    }

    // Force the clip snapshot + track metrics to resync with the model.
    // Call this after any operation that mutates clip/track data but where
    // you can't be 100% sure the model will emit onTrackDataChanged /
    // onClipPropertiesChanged (e.g. right after moveClip/moveClips/
    // rippleMoveClip completes). Relying solely on those signals firing is
    // what causes a clip to visually snap back to its pre-drag position
    // even though the move succeeded in the model — clipRepeater's `model`
    // array is a manual snapshot (getAllClips()), not a live binding, so if
    // nothing tells it to refresh, the delegate keeps using stale startFrame
    // data once isDragging flips back to false.
    function refreshClips() {
        updateTrackMetrics();
        clipRepeater.refreshAllClips();
        updateContentWidth();
    }

    function applyZoom(factor, cursorScreenX) {
        var visibleTimelineX = cursorScreenX - (root.headerWidth + root.paletteStripWidth) - root.playheadMargin;
        var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
        var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
        var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
        var clampedOffset = Math.max(0, Math.min(maxOffset, newOffset));

        if (root.activeTimelineModel) {
            root.activeTimelineModel.zoomFactor = newZoom;
            root.activeTimelineModel.horizontalOffset = clampedOffset;
        }
        root.updateContentWidth();
    }

    function frameToPx(frame) {
        return root.playheadMargin + (frame * root.zoomFactor);
    }
    function pxToFrame(px) {
        return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
    }

    function showSnapLine(frame) {
        var f = (typeof frame === "number" && !isNaN(frame)) ? Number(frame) : -1;
        snapGuideFrame = f;
        isSnapLineVisible = (f >= 0);
        activeSpacingGaps = [];
    }

    function showSpacingGuides(gapsList) {
        activeSpacingGaps = (gapsList && gapsList.length > 0) ? gapsList : [];
    }

    function hideSnapGuides() {
        isSnapLineVisible = false;
        snapGuideFrame = -1;
        activeSpacingGaps = [];
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

    // =========================================================================
    // ROOT LAYOUT: Left Timeline Column | Right Full-Height MixerStrip
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------------
        // LEFT: ToolBar, Ruler, and Tracks (pushed to the left of the mixer)
        // ---------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TimelineToolBar {
                id: topToolBar
                Layout.fillWidth: true
                playbackManager: root.activePlaybackManager
                timelineModel: root.activeTimelineModel
                projectFps: root.projectFps
                showAudioWaveforms: root.showAudioWaveforms
                onShowAudioWaveformsChanged: root.showAudioWaveforms = showAudioWaveforms
                thumbnailMode: root.thumbnailMode
                onThumbnailModeChanged: root.thumbnailMode = thumbnailMode
                onAddVideoTrackRequested: {
                    addTrackModal.pendingKind = 0;
                    addTrackModal.open();
                }
                onAddAudioTrackRequested: {
                    addTrackModal.pendingKind = 1;
                    addTrackModal.open();
                }
            }

            XylaTimelineRuler {
                id: timelineRuler
                Layout.fillWidth: true
                headerWidth: root.headerWidth + root.paletteStripWidth + root.playheadMargin
                zoomFactor: root.zoomFactor
                horizontalOffset: root.horizontalOffset
                contentWidth: root.contentWidth
                fps: root.projectFps
                z: 250
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // State A: Tracks Exist
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: root.trackCount > 0

                    // Track Headers Column
                    Item {
                        Layout.preferredWidth: root.headerWidth
                        Layout.fillHeight: true
                        clip: true

                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                                var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                                trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY - pDeltaY));
                            }
                        }

                        Item {
                            id: headerContentItem
                            width: parent.width
                            y: -trackScrollArea.contentY
                            height: root.totalTracksHeight

                            Column {
                                id: trackHeaderColumn
                                width: parent.width
                                y: 0

                                Repeater {
                                    model: root.activeTimelineModel

                                    TimelineTrackHeader {
                                        width: root.headerWidth
                                        trackIndex: index
                                        trackId: model.trackId || ""
                                        trackName: model.trackName || ""
                                        trackKind: model.trackKind !== undefined ? model.trackKind : 0
                                        isSelected: model.isTrackSelected !== undefined ? model.isTrackSelected : false

                                        onLockToggled: root.activeTimelineModel ? root.activeTimelineModel.toggleTrackLock(trackIndex) : undefined
                                        onImplicitHeightChanged: root.updateTrackMetrics()
                                        onTrackHeightChanged: root.updateTrackMetrics()
                                        Component.onCompleted: root.updateTrackMetrics()
                                    }
                                }
                            }
                        }
                    }

                    // Intermediate Palette Strip
                    Item {
                        id: paletteStripContainer
                        Layout.preferredWidth: root.paletteStripWidth
                        Layout.fillHeight: true
                        clip: true
                        z: 5

                        Item {
                            id: paletteContentItem
                            width: parent.width
                            y: -trackScrollArea.contentY
                            height: root.totalTracksHeight

                            Rectangle {
                                width: parent.width
                                height: 0
                                color: "#181818"
                            }

                            Column {
                                y: 0
                                width: parent.width

                                Repeater {
                                    model: root.trackCount

                                    Rectangle {
                                        width: paletteStripContainer.width
                                        height: root.getTrackHeight(index)
                                        color: "#181818"

                                        Rectangle {
                                            id: paletteIndicator
                                            property bool isHighlighted: root.isPlayheadOnClipInTrack(index)
                                            anchors.centerIn: parent
                                            width: 4
                                            height: parent.height - 8
                                            radius: 2
                                            color: isHighlighted ? "#3b82f6" : "#2d2d2d"

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 120
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: "#3b82f6"
                                                opacity: paletteIndicator.isHighlighted ? 0.6 : 0.0
                                                z: -1
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 120
                                                    }
                                                }
                                            }
                                        }

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

                            Rectangle {
                                width: parent.width
                                height: 0
                                y: 0
                                color: "#181818"
                            }
                        }
                    }

                    // Main Timeline 2D Scroll Canvas
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: clipContainerLeftBorder
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: root.borderDark
                            z: 100
                        }

                        Flickable {
                            id: trackScrollArea
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: root.contentWidth + root.playheadMargin
                            contentHeight: root.totalTracksHeight
                            interactive: false

                            Rectangle {
                                anchors.fill: parent
                                color: "#121212"
                                z: 0
                            }

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
                                        var newOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));
                                        if (root.activeTimelineModel)
                                            root.activeTimelineModel.horizontalOffset = newOffset;

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
                                        var delta = event.angleDelta.y;
                                        if (delta !== 0) {
                                            var zoomMultiplier = Math.pow(1.001, delta);
                                            root.applyZoom(zoomMultiplier, cursorX + root.headerWidth + root.paletteStripWidth);
                                        }
                                        return;
                                    }

                                    var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
                                    var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                                    var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);

                                    if (isHorizontal) {
                                        var deltaX = (pDeltaX !== 0) ? -pDeltaX : -pDeltaY;
                                        var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
                                        var newOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                                        if (root.activeTimelineModel)
                                            root.activeTimelineModel.horizontalOffset = newOffset;
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
                                    y: 0
                                    width: timelineCanvasViewport.width

                                    Repeater {
                                        model: root.trackCount
                                        Rectangle {
                                            width: timelineCanvasViewport.width
                                            height: root.getTrackHeight(index)
                                            color: root.getTrackBgColor(index)
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

                                // Marquee Area
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
                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel.startSelectionBatch();
                                        }

                                        if (isMarquee) {
                                            marqueeRect.x = Math.min(startGlobalX, globalPt.x);
                                            marqueeRect.y = Math.min(startGlobalY, globalPt.y);
                                            marqueeRect.width = Math.max(startGlobalX, globalPt.x) - marqueeRect.x;
                                            marqueeRect.height = Math.max(startGlobalY, globalPt.y) - marqueeRect.y;
                                            marqueeRect.visible = true;

                                            var startF = root.pxToFrame(Math.min(startCanvasX, mouse.x));
                                            var endF = root.pxToFrame(Math.max(startCanvasX, mouse.x));
                                            var startT = root.getTrackAtY(Math.min(startCanvasY, mouse.y));
                                            var endT = root.getTrackAtY(Math.max(startCanvasY, mouse.y));
                                            var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));

                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
                                        }
                                    }

                                    onReleased: function (mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                            timelineContextMenu.openAt(overlayPt.x, overlayPt.y, root.pxToFrame(mouse.x), root.getTrackAtY(mouse.y), null);
                                            return;
                                        }
                                        if (isMarquee) {
                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel.commitSelectionBatch();
                                            isMarquee = false;
                                            marqueeRect.visible = false;
                                        } else if (root.activeTimelineModel) {
                                            root.activeTimelineModel.clearSelection();
                                        }
                                    }
                                }

                                // Asset Drop Area
                                DropArea {
                                    anchors.fill: parent
                                    keys: ["xyla/media-asset", "text/uri-list", "text/plain"]
                                    z: 2

                                    onEntered: drag => drag.accept(Qt.CopyAction)
                                    onPositionChanged: drag => drag.accept(Qt.CopyAction)
                                    onDropped: function (drop) {
                                        drop.accept(Qt.CopyAction);
                                        if (!root.activeTimelineModel)
                                            return;

                                        var rawPayload = "";
                                        if (drop.formats && drop.formats.indexOf("xyla/media-asset") !== -1) {
                                            rawPayload = drop.getDataAsString("xyla/media-asset").trim();
                                        } else if (drop.hasText && drop.text && drop.text.length > 0) {
                                            rawPayload = drop.text.trim();
                                        } else if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
                                            rawPayload = drop.urls[0].toString();
                                        }

                                        if (!rawPayload)
                                            return;

                                        var assetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawPayload) : "";
                                        if (!assetId)
                                            assetId = rawPayload;

                                        var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(assetId, root.projectFps) : 0;
                                        var assetName = rawPayload.substring(rawPayload.lastIndexOf('/') + 1) || "Clip";
                                        var dropFrame = root.pxToFrame(drop.x);
                                        var dropTrack = root.getTrackAtY(drop.y);

                                        var newId = root.activeTimelineModel.addClip(assetId, assetName, dropTrack, dropFrame, assetDuration, 0);
                                        if (newId && newId.length > 0) {
                                            root.updateContentWidth();
                                        }
                                    }
                                }

                                // Clips Layer
                                Item {
                                    id: unifiedClipsLayer
                                    anchors.fill: parent
                                    z: 10

                                    Connections {
                                        target: root.activeTimelineModel ? root.activeTimelineModel : null
                                        function onTrackDataChanged(trackIndex) {
                                            root.updateTrackMetrics();
                                            clipRepeater.refreshAllClips();
                                            root.updateContentWidth();
                                        }
                                        function onTrackCountChanged() {
                                            root.updateTrackMetrics();
                                            clipRepeater.refreshAllClips();
                                            root.updateContentWidth();
                                        }
                                        function onClipPropertiesChanged(clipId) {
                                            clipRepeater.refreshAllClips();
                                        }
                                    }

                                    Repeater {
                                        id: clipRepeater
                                        model: []
                                        function refreshAllClips() {
                                            // model = [];
                                            model = root.activeTimelineModel ? root.activeTimelineModel.getAllClips() : [];
                                        }
                                        Component.onCompleted: refreshAllClips()

                                        TimelineClipCard {
                                            timelineRoot: root
                                            clipData: modelData
                                            zoomFactor: root.zoomFactor
                                        }
                                    }
                                }

                                // Snapping & Spacing Guides
                                Item {
                                    id: snapGuideLayer
                                    anchors.fill: parent
                                    z: 500

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

                    // Rectangle {
                    //     x: root.headerWidth + root.paletteStripWidth
                    //     y: 0
                    //     width: 1
                    //     height: parent.height
                    //     color: root.borderDark
                    //     z: 100
                    // }
                }

                // State B: 0 Tracks Exist
                Item {
                    anchors.fill: parent
                    visible: root.trackCount === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: "qrc:/assets/icons/layers.svg"
                            sourceSize: Qt.size(42, 42)
                            opacity: 0.35
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No Tracks in Timeline"
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Initialize video and audio tracks to begin editing"
                                color: "#888888"
                                font.pixelSize: 12
                            }
                        }

                        XylaTextButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Create Tracks..."
                            primary: true
                            onClicked: createTracksModal.open()
                        }
                    }
                }

    //     MixerStrip {
    //         id: rootMasterMixerStrip
    //         anchors.right: parent.right
    //         anchors.top: parent.top
    //         anchors.bottom: parent.bottom
    //
    //     // component MixerStrip: Rectangle {
    //
    //         property bool isMaster: true
    //         property bool isDummy: false
    //         property int trackIndex: -1
    //         property string trackTitle: ""
    //         property real volumeVal: root.activeMixerModel ? root.activeMixerModel.masterVolume : 1.0
    //         property real panVal: 0.0
    //         property real peakL: root.activeMixerModel ? root.activeMixerModel.masterPeakL : 0.0 
    //         property real peakR: root.activeMixerModel ? root.activeMixerModel.masterPeakR : 0.0 
    //         property bool isMuted: false
    //         property bool isSolo: false
    //
    //         // DYNAMICALLY CALCULATED WIDTH — no hardcoded values
    //         implicitWidth: contentCol.implicitWidth + 12
    //         width: implicitWidth
    //         height: parent ? parent.height : 0
    //
    //         color: isMaster ? "#181818" : (isDummy ? "#111111" : "#151515")
    //         // border.color: isMaster ? "#333333" : "#242424"
    //         // border.width: 1
    //
    //         ColumnLayout {
    //             id: contentCol
    //             anchors.fill: parent
    //             anchors.margins: 4
    //             spacing: 6
    //
    //             // 1. Header (No index numbers)
    //             Rectangle {
    //                 Layout.fillWidth: true
    //                 Layout.preferredHeight: 24
    //                 color: rootMasterMixerStrip.isMaster ? "#222222" : "#1e1e1e"
    //                 border.color: "#333333"
    //                 border.width: 1
    //                 radius: 2
    //
    //                 Text {
    //                     anchors.centerIn: parent
    //                     text: rootMasterMixerStrip.isMaster ? "Master" : rootMasterMixerStrip.trackTitle
    //                     color: rootMasterMixerStrip.isDummy ? "#555555" : "#ffffff"
    //                     font.pixelSize: 11
    //                     font.bold: true
    //                     elide: Text.ElideRight
    //                     width: parent.width - 6
    //                     horizontalAlignment: Text.AlignHCenter
    //                 }
    //             }
    //
    //             // 2. Mute / Solo (Hidden on Master)
    //             RowLayout {
    //                 Layout.alignment: Qt.AlignHCenter
    //                 spacing: 3
    //                 visible: !rootMasterMixerStrip.isMaster
    //
    //                 Button {
    //                     text: "M"
    //                     implicitWidth: 26
    //                     implicitHeight: 20
    //                     enabled: !rootMasterMixerStrip.isDummy
    //                     background: Rectangle {
    //                         color: rootMasterMixerStrip.isMuted ? "#dc2626" : "#222222"
    //                         radius: 2
    //                         border.color: "#333333"
    //                     }
    //                     contentItem: Text {
    //                         text: parent.text
    //                         color: rootMasterMixerStrip.isDummy ? "#444444" : "#ffffff"
    //                         horizontalAlignment: Text.AlignHCenter
    //                         verticalAlignment: Text.AlignVCenter
    //                         font.pixelSize: 9
    //                         font.bold: true
    //                     }
    //                     onClicked: {
    //                         if (root.activeMixerModel && !rootMasterMixerStrip.isDummy)
    //                             root.activeMixerModel.setMuted(rootMasterMixerStrip.trackIndex, !rootMasterMixerStrip.isMuted);
    //                     }
    //                 }
    //
    //                 Button {
    //                     text: "S"
    //                     implicitWidth: 26
    //                     implicitHeight: 20
    //                     enabled: !rootMasterMixerStrip.isDummy
    //                     background: Rectangle {
    //                         color: rootMasterMixerStrip.isSolo ? "#d97706" : "#222222"
    //                         radius: 2
    //                         border.color: "#333333"
    //                     }
    //                     contentItem: Text {
    //                         text: parent.text
    //                         color: rootMasterMixerStrip.isDummy ? "#444444" : "#ffffff"
    //                         horizontalAlignment: Text.AlignHCenter
    //                         verticalAlignment: Text.AlignVCenter
    //                         font.pixelSize: 9
    //                         font.bold: true
    //                     }
    //                     onClicked: {
    //                         if (root.activeMixerModel && !rootMasterMixerStrip.isDummy)
    //                             root.activeMixerModel.setSolo(rootMasterMixerStrip.trackIndex, !rootMasterMixerStrip.isSolo);
    //                     }
    //                 }
    //             }
    //
    //             // 3. Peak Meter & Fader
    //             RowLayout {
    //                 Layout.alignment: Qt.AlignHCenter
    //                 Layout.fillHeight: true
    //                 spacing: 2
    //
    //                 XylaPeakMeter {
    //                     Layout.fillHeight: true
    //                     itemWidth: 10
    //                     peakLeft: rootMasterMixerStrip.isDummy ? 0.0 : rootMasterMixerStrip.peakL
    //                     peakRight: rootMasterMixerStrip.isDummy ? 0.0 : rootMasterMixerStrip.peakR
    //                 }
    //
    //                 XylaFader {
    //                     id: volumeFader
    //                     Layout.fillHeight: true
    //                     Layout.preferredWidth: 32
    //                     value: rootMasterMixerStrip.volumeVal
    //                     minValue: 0.0
    //                     maxValue: 2.0
    //                     enabled: !rootMasterMixerStrip.isDummy
    //                     onValueChanged: {
    //                         if (root.activeMixerModel && !rootMasterMixerStrip.isDummy)
    //                             root.activeMixerModel.setVolume(rootMasterMixerStrip.trackIndex, value);
    //                     }
    //                 }
    //             }
    //
    //             // 4. Pan Knob
    //             Item {
    //                 Layout.alignment: Qt.AlignHCenter
    //                 Layout.preferredWidth: 40
    //                 Layout.preferredHeight: 40
    //                 opacity: rootMasterMixerStrip.isMaster ? 0.3 : 1.0
    //
    //                 ColumnLayout {
    //                     anchors.centerIn: parent
    //                     spacing: 1
    //
    //                     Text {
    //                         Layout.alignment: Qt.AlignHCenter
    //                         text: "PAN"
    //                         color: "#666666"
    //                         font.pixelSize: 8
    //                         font.bold: true
    //                     }
    //
    //                     XylaKnob {
    //                         id: panKnob
    //                         Layout.alignment: Qt.AlignHCenter
    //                         Layout.preferredWidth: 28
    //                         Layout.preferredHeight: 28
    //                         value: rootMasterMixerStrip.isMaster ? 0.0 : rootMasterMixerStrip.panVal
    //                         minValue: -1.0
    //                         maxValue: 1.0
    //                         enabled: !rootMasterMixerStrip.isMaster && !rootMasterMixerStrip.isDummy
    //                         onValueChanged: {
    //                             if (root.activeMixerModel && !rootMasterMixerStrip.isMaster && !rootMasterMixerStrip.isDummy)
    //                                 root.activeMixerModel.setPan(rootMasterMixerStrip.trackIndex, value);
    //                         }
    //                     }
    //                 }
    //             }
    //
    //             // 5. Float dB Input
    //             XylaFloatInput {
    //                 id: dbInput
    //                 Layout.alignment: Qt.AlignHCenter
    //                 Layout.preferredWidth: 64
    //                 Layout.preferredHeight: 20
    //                 enabled: !rootMasterMixerStrip.isDummy
    //                 value: volumeFader.value <= 0.0001 ? -60.0 : (20.0 * Math.log10(volumeFader.value))
    //                 minValue: -60.0
    //                 maxValue: 6.0
    //                 stepSize: 0.1
    //                 decimals: 1
    //                 onValueCommitted: function (newValue) {
    //                     if (rootMasterMixerStrip.isDummy)
    //                         return;
    //                     var linearVal = Math.pow(10.0, newValue / 20.0);
    //                     if (newValue <= -60.0)
    //                         linearVal = 0.0;
    //                     if (root.activeMixerModel)
    //                         root.activeMixerModel.setVolume(rootMasterMixerStrip.trackIndex, linearVal);
    //                 }
    //             }
    //         }
    //
    //         // Overlay for empty/unused default tracks
    //         Rectangle {
    //             anchors.fill: parent
    //             color: "#000000"
    //             opacity: 0.5
    //             visible: rootMasterMixerStrip.isDummy
    //             z: 99
    //         }
    // // }
    //     }
            }
        }
// Rectangle {
//             Layout.fillHeight: true
//             Layout.preferredWidth: 1
//             Layout.fillWidth: false
//             width: 1
//             color: root.borderDark
//             z: 100
//         }
 // ---------------------------------------------------------------------
        // 3. RIGHT: Master Peak Meter (LOCKED TO STRICT 50px — CANNOT EXPAND)
        // ---------------------------------------------------------------------
        Item {
            id: timelineMeterContainer
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.preferredWidth: 80
            Layout.minimumWidth: 80
            Layout.maximumWidth: 80
            width: 80
            z: 50

Rectangle {
        anchors.fill: parent
        color: "#181818" // Change this to your preferred background color (e.g., "#0d0d0d")
        z: -1
    }
Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 10    // Top padding
                anchors.rightMargin: 10
                anchors.bottomMargin: 10 // Bottom padding
            // Bind master peaks from activeMixerModel's Master row
            Repeater {
                model: root.activeMixerModel
                delegate: Item {
                    visible: false
                    Component.onCompleted: {
                        if (model.isMaster === true) {
                            masterPeakMeter.peakLeft = Qt.binding(function () {
                                return model.peakL !== undefined ? model.peakL : 0.0;
                            });
                            masterPeakMeter.peakRight = Qt.binding(function () {
                                return model.peakR !== undefined ? model.peakR : 0.0;
                            });
                        }
                    }
                }
            }
          

            XylaPeakMeter {
                id: masterPeakMeter
                anchors.fill: parent
                itemWidth: 12
                // Fallbacks in case activeMixerModel has top-level master properties:
                peakLeft: (root.activeMixerModel && typeof root.activeMixerModel.masterPeakL === "number")
                          ? root.activeMixerModel.masterPeakL : 0.0
                peakRight: (root.activeMixerModel && typeof root.activeMixerModel.masterPeakR === "number")
                           ? root.activeMixerModel.masterPeakR : 0.0
            }
          }
        }
    }

    // Playhead Overlay
// Playhead Overlay
    Item {
        x: root.headerWidth + root.paletteStripWidth
        y: topToolBar.height
        width: parent.width - (root.headerWidth + root.paletteStripWidth) - (timelineMeterContainer ? timelineMeterContainer.width + 1 : 0)
        height: parent.height - y
        clip: true
        z: 200
        visible: root.trackCount > 0

        XylaPlayhead {
            id: mainPlayhead
            timelineRoot: root
            topToolBar: topToolBar
            activeTimelineModel: root.activeTimelineModel
            currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            playheadMargin: root.playheadMargin
            headerWidth: root.headerWidth + root.paletteStripWidth
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
        visible: root.trackCount > 0

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
                    root.headerWidth = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
                }
            }
        }
    }

    // Context Menu
    TimelineContextMenu {
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
                for (var i = 0; i < all.length; ++i)
                    ids.push(all[i].clipId);
                root.activeTimelineModel.applyDirectSelection(ids);
            }
        }
    }

    // Modals
    TimelineAddTrackModal {
        id: addTrackModal
        onConfirmed: function (kind) {
            if (root.activeTimelineModel) {
                if (kind === 0 && root.activeTimelineModel.addVideoTrack)
                    root.activeTimelineModel.addVideoTrack();
                else if (kind === 1 && root.activeTimelineModel.addAudioTrack)
                    root.activeTimelineModel.addAudioTrack();
                root.updateTrackMetrics();
                clipRepeater.refreshAllClips();
                root.updateContentWidth();
            }
        }
    }

    TimelineCreateTracksModal {
        id: createTracksModal
        onConfirmed: function (vCount, aCount) {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.createDefaultTracks(vCount, aCount);
                root.updateTrackMetrics();
                clipRepeater.refreshAllClips();
                root.updateContentWidth();
            }
        }
    }

    // ==========================================
    // Inline Mixer Strip Component
    // ==========================================
    component MixerStrip: Rectangle {
        id: stripRoot

        property bool isMaster: false
        property bool isDummy: false
        property int trackIndex: -1
        property string trackTitle: ""
        property real volumeVal: 1.0
        property real panVal: 0.0
        property real peakL: 0.0
        property real peakR: 0.0
        property bool isMuted: false
        property bool isSolo: false

        implicitWidth: contentCol.implicitWidth + 12
        width: implicitWidth
        height: parent ? parent.height : 0

        color: isMaster ? "#181818" : (isDummy ? "#111111" : "#151515")
        border.color: isMaster ? "#333333" : "#242424"
        border.width: 1

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6

            // 1. Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: stripRoot.isMaster ? "#222222" : "#1e1e1e"
                border.color: "#333333"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: stripRoot.isMaster ? "Master" : stripRoot.trackTitle
                    color: stripRoot.isDummy ? "#555555" : "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // 2. Mute / Solo (Hidden on Master)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                visible: !stripRoot.isMaster

                Button {
                    text: "M"
                    implicitWidth: 26
                    implicitHeight: 20
                    enabled: !stripRoot.isDummy
                    background: Rectangle {
                        color: stripRoot.isMuted ? "#dc2626" : "#222222"
                        radius: 2
                        border.color: "#333333"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: stripRoot.isDummy ? "#444444" : "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 9
                        font.bold: true
                    }
                    onClicked: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setMuted(stripRoot.trackIndex, !stripRoot.isMuted);
                    }
                }

                Button {
                    text: "S"
                    implicitWidth: 26
                    implicitHeight: 20
                    enabled: !stripRoot.isDummy
                    background: Rectangle {
                        color: stripRoot.isSolo ? "#d97706" : "#222222"
                        radius: 2
                        border.color: "#333333"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: stripRoot.isDummy ? "#444444" : "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 9
                        font.bold: true
                    }
                    onClicked: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setSolo(stripRoot.trackIndex, !stripRoot.isSolo);
                    }
                }
            }

            // 3. Peak Meter & Fader
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                spacing: 2

                XylaPeakMeter {
                    Layout.fillHeight: true
                    itemWidth: 10
                    peakLeft: stripRoot.isDummy ? 0.0 : stripRoot.peakL
                    peakRight: stripRoot.isDummy ? 0.0 : stripRoot.peakR
                }

                XylaFader {
                    id: volumeFader
                    Layout.fillHeight: true
                    Layout.preferredWidth: 32
                    value: stripRoot.volumeVal
                    minValue: 0.0
                    maxValue: 2.0
                    enabled: !stripRoot.isDummy
                    onValueChanged: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setVolume(stripRoot.trackIndex, value);
                    }
                }
            }

            // 4. Pan Knob
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                opacity: stripRoot.isMaster ? 0.3 : 1.0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "PAN"
                        color: "#666666"
                        font.pixelSize: 8
                        font.bold: true
                    }

                    XylaKnob {
                        id: panKnob
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        value: stripRoot.isMaster ? 0.0 : stripRoot.panVal
                        minValue: -1.0
                        maxValue: 1.0
                        enabled: !stripRoot.isMaster && !stripRoot.isDummy
                        onValueChanged: {
                            if (root.activeMixerModel && !stripRoot.isMaster && !stripRoot.isDummy)
                                root.activeMixerModel.setPan(stripRoot.trackIndex, value);
                        }
                    }
                }
            }

            // 5. Float dB Input
            XylaFloatInput {
                id: dbInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 20
                enabled: !stripRoot.isDummy
                value: volumeFader.value <= 0.0001 ? -60.0 : (20.0 * Math.log10(volumeFader.value))
                minValue: -60.0
                maxValue: 6.0
                stepSize: 0.1
                decimals: 1
                onValueCommitted: function (newValue) {
                    if (stripRoot.isDummy)
                        return;
                    var linearVal = Math.pow(10.0, newValue / 20.0);
                    if (newValue <= -60.0)
                        linearVal = 0.0;
                    if (root.activeMixerModel)
                        root.activeMixerModel.setVolume(stripRoot.trackIndex, linearVal);
                }
            }
        }

        // Overlay for empty/unused default tracks
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            visible: stripRoot.isDummy
            z: 99
        }
    }
}
