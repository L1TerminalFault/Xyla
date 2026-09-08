import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "./timeline"

Item {
    id: dopesheetRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
    property string activeClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var activeClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    readonly property int currentPlayheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    property real zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 5000
    property var channelsData: []
    property int headerWidth: 180
    readonly property real playheadMargin: 0.0

    property var selectedKeyframes: []
    property bool isDraggingKeyframes: false
    property int dragDeltaFrames: 0          // <-- live visual offset while dragging

    function isKeyframeSelected(propId, frame) {
        for (var i = 0; i < selectedKeyframes.length; ++i) {
            if (selectedKeyframes[i].propId === propId && selectedKeyframes[i].frame === frame)
                return true;
        }
        return false;
    }

    function selectSingleKeyframe(propId, frame) {
        selectedKeyframes = [
            {
                clipId: activeClipId,
                propId: propId,
                frame: frame
            }
        ];
    }

    function toggleKeyframeSelection(propId, frame) {
        var copy = selectedKeyframes.slice();
        for (var i = 0; i < copy.length; ++i) {
            if (copy[i].propId === propId && copy[i].frame === frame) {
                copy.splice(i, 1);
                selectedKeyframes = copy;
                return;
            }
        }
        copy.push({
            clipId: activeClipId,
            propId: propId,
            frame: frame
        });
        selectedKeyframes = copy;
    }

    function clearKeyframeSelection() {
        selectedKeyframes = [];
    }

    function refreshChannels() {
        if (isDraggingKeyframes)
            return;
        if (!activeTimelineModel || activeClipId === "") {
            channelsData = [];
            return;
        }
        channelsData = activeTimelineModel.getClipAnimChannels(activeClipId, currentPlayheadFrame);
    }

    Connections {
        target: activeTimelineModel
        function onClipPropertiesChanged(clipId) {
            if (clipId === dopesheetRoot.activeClipId)
                dopesheetRoot.refreshChannels();
        }
        function onSelectedClipIdChanged() {
            dopesheetRoot.clearKeyframeSelection();
            dopesheetRoot.refreshChannels();
        }
    }

    Connections {
        target: activePlaybackManager
        function onFrameChanged() {
            dopesheetRoot.refreshChannels();
        }
    }

    onActiveClipIdChanged: refreshChannels()
    Component.onCompleted: refreshChannels()

    function frameToX(f) {
        return (f * zoomFactor) - horizontalOffset;
    }
    function xToFrame(xPx) {
        return Math.max(0, Math.round((xPx + horizontalOffset) / zoomFactor));
    }

    Rectangle {
        anchors.fill: parent
        color: "#141414"
    }

    // Marquee Selection Box
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

        // =========================================================
        // 1. TOOLBAR STRIP
        // =========================================================
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: "#181818"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#242424"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Image {
                    source: "qrc:/assets/icons/chart-line.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    opacity: 0.6
                }

                Item {
                    Layout.fillWidth: true
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/zoom-in.svg"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    tooltip: "Zoom In"
                    onClicked: dopesheetRoot.zoomFactor = Math.min(10.0, dopesheetRoot.zoomFactor * 1.25)
                }
                XylaIconButton {
                    iconSource: "qrc:/assets/icons/zoom-out.svg"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    tooltip: "Zoom Out"
                    onClicked: dopesheetRoot.zoomFactor = Math.max(0.1, dopesheetRoot.zoomFactor * 0.8)
                }
            }
        }

        // =========================================================
        // 2. TIMELINE RULER
        // =========================================================
        XylaTimelineRuler {
            id: dopesheetRuler
            Layout.fillWidth: true
            headerWidth: dopesheetRoot.headerWidth
            zoomFactor: dopesheetRoot.zoomFactor
            horizontalOffset: dopesheetRoot.horizontalOffset
            contentWidth: dopesheetRoot.contentWidth
            activePlaybackManager: dopesheetRoot.activePlaybackManager
            z: 250
        }

        // =========================================================
        // 3. MAIN BODY (Channels & Keyframe Canvas)
        // =========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // LEFT: Channel Tree Hierarchy
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: dopesheetRoot.headerWidth
                color: "#161616"

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: "#242424"
                }

                Column {
                    anchors.fill: parent
                    Repeater {
                        model: dopesheetRoot.channelsData
                        delegate: Rectangle {
                            width: dopesheetRoot.headerWidth
                            height: 24
                            color: rowMouse.containsMouse ? "#202020" : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#3b82f6"
                                    opacity: modelData.isAnimated ? 1.0 : 0.35
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: modelData.isAnimated ? "#dddddd" : "#666666"
                                    font.pixelSize: 11
                                    font.bold: modelData.isAnimated
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.keyframes && modelData.keyframes.length > 0
                                    text: "" + modelData.keyframes.length
                                    color: "#555555"
                                    font.pixelSize: 9
                                    font.family: "Monospace"
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }

            // RIGHT: Canvas with Horizontal Scrolling
            Flickable {
                id: canvasFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: null
                    onWheel: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            var factor = event.angleDelta.y > 0 ? 1.25 : 0.8;
                            dopesheetRoot.zoomFactor = Math.max(0.1, Math.min(10.0, dopesheetRoot.zoomFactor * factor));
                        } else {
                            var delta = event.pixelDelta.x !== 0 ? -event.pixelDelta.x : -event.angleDelta.x;
                            dopesheetRoot.horizontalOffset = Math.max(0, dopesheetRoot.horizontalOffset + delta);
                        }
                    }
                }

                Item {
                    id: canvasContent
                    width: dopesheetRoot.contentWidth * dopesheetRoot.zoomFactor
                    height: canvasFlick.height

                    // =========================================================
                    // 1. MARQUEE SELECTION BACKGROUND AREA (BEHIND TRACKS)
                    // =========================================================
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        property real startGlobalX: 0
                        property real startGlobalY: 0
                        property real startCanvasX: 0
                        property real startCanvasY: 0
                        property bool isMarquee: false

                        onPressed: mouse => {
                            if (dopesheetRoot.isDraggingKeyframes)
                                return;

                            if (mouse.button === Qt.RightButton) {
                                var targetF = dopesheetRoot.xToFrame(mouse.x);
                                var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                dopesheetContextMenu.openAt(overlayPt.x, overlayPt.y, dopesheetRoot.activeClipId, "", targetF, false);
                                return;
                            }

                            var globalPt = mapToItem(dopesheetRoot, mouse.x, mouse.y);
                            startGlobalX = globalPt.x;
                            startGlobalY = globalPt.y;
                            startCanvasX = mouse.x;
                            startCanvasY = mouse.y;
                            isMarquee = false;
                        }

                        onPositionChanged: mouse => {
                            if (dopesheetRoot.isDraggingKeyframes || (mouse.buttons & Qt.RightButton))
                                return;

                            var globalPt = mapToItem(dopesheetRoot, mouse.x, mouse.y);
                            var dx = globalPt.x - startGlobalX;
                            var dy = globalPt.y - startGlobalY;

                            if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                                isMarquee = true;
                                if (!(mouse.modifiers & Qt.ShiftModifier)) {
                                    dopesheetRoot.clearKeyframeSelection();
                                }
                            }

                            if (isMarquee) {
                                marqueeRect.x = Math.min(startGlobalX, globalPt.x);
                                marqueeRect.y = Math.min(startGlobalY, globalPt.y);
                                marqueeRect.width = Math.abs(dx);
                                marqueeRect.height = Math.abs(dy);
                                marqueeRect.visible = true;

                                var minX = Math.min(startCanvasX, mouse.x);
                                var maxX = Math.max(startCanvasX, mouse.x);
                                var startF = dopesheetRoot.xToFrame(minX);
                                var endF = dopesheetRoot.xToFrame(maxX);
                                var minY = Math.min(startCanvasY, mouse.y);
                                var maxY = Math.max(startCanvasY, mouse.y);

                                var newSelection = [];
                                for (var c = 0; c < dopesheetRoot.channelsData.length; ++c) {
                                    var ch = dopesheetRoot.channelsData[c];
                                    var trackTop = c * 24;
                                    var trackBottom = trackTop + 24;
                                    if (trackBottom >= minY && trackTop <= maxY) {
                                        var kfs = ch.keyframes || [];
                                        for (var k = 0; k < kfs.length; ++k) {
                                            var f = Math.round(Number(kfs[k]));
                                            if (f >= startF && f <= endF) {
                                                newSelection.push({
                                                    clipId: dopesheetRoot.activeClipId,
                                                    propId: ch.id,
                                                    frame: f
                                                });
                                            }
                                        }
                                    }
                                }
                                dopesheetRoot.selectedKeyframes = newSelection;
                            }
                        }

                        onReleased: mouse => {
                            if (isMarquee) {
                                isMarquee = false;
                                marqueeRect.visible = false;
                            } else if (mouse.button === Qt.LeftButton) {
                                dopesheetRoot.clearKeyframeSelection();
                            }
                        }
                    }

                    // =========================================================
                    // 2. CHANNEL TRACKS & KEYFRAME DIAMONDS (FOREGROUND)
                    // =========================================================
                    Column {
                        id: channelColumn
                        width: parent.width

                        Repeater {
                            id: channelRepeater
                            model: dopesheetRoot.channelsData

                            delegate: Rectangle {
                                id: channelTrack
                                property var channelItem: modelData
                                property int trackRowIndex: index

                                width: canvasContent.width
                                height: 24
                                color: index % 2 === 0 ? "#141414" : "#121212"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: "#1c1c1c"
                                }

                                // Keyframe Diamonds
                                Repeater {
                                    model: channelItem.keyframes || []

                                    delegate: Item {
                                        id: kfItem

                                        readonly property int kfFrame: Math.round(Number(modelData))
                                        readonly property bool isSelected: dopesheetRoot.isKeyframeSelected(channelItem.id, kfFrame)

                                        // Live visual offset while dragging selected keyframes
                                        x: dopesheetRoot.frameToX(kfFrame + (isSelected && dopesheetRoot.isDraggingKeyframes ? dopesheetRoot.dragDeltaFrames : 0)) - 7
                                        y: 5
                                        width: 14
                                        height: 14

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: kfItem.isSelected ? 9 : 8
                                            height: kfItem.isSelected ? 9 : 8
                                            rotation: 45
                                            color: kfItem.isSelected ? "#F59E0B" : "#2563EB"
                                            border.color: kfItem.isSelected ? "#FEF08A" : "#60A5FA"
                                            border.width: kfItem.isSelected ? 2 : 1
                                            scale: kfItem.isSelected ? 1.15 : 1.0

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 60
                                                }
                                            }
                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 60
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: kfDragMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.SizeHorCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            preventStealing: true

                                            property real startCanvasMouseX: 0
                                            property var dragSelectionSnapshots: []

                                            onPressed: mouse => {
                                                mouse.accepted = true;

                                                if (mouse.button === Qt.RightButton) {
                                                    dopesheetRoot.selectSingleKeyframe(channelItem.id, kfItem.kfFrame);
                                                    var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                                    dopesheetContextMenu.openAt(overlayPt.x, overlayPt.y, dopesheetRoot.activeClipId, channelItem.id, kfItem.kfFrame, true);
                                                    return;
                                                }

                                                if (mouse.modifiers & Qt.ShiftModifier) {
                                                    dopesheetRoot.toggleKeyframeSelection(channelItem.id, kfItem.kfFrame);
                                                } else if (!kfItem.isSelected) {
                                                    dopesheetRoot.selectSingleKeyframe(channelItem.id, kfItem.kfFrame);
                                                }

                                                // Begin drag
                                                dopesheetRoot.isDraggingKeyframes = true;
                                                dopesheetRoot.dragDeltaFrames = 0;

                                                // Capture absolute canvas X of the mouse
                                                startCanvasMouseX = mapToItem(canvasContent, mouse.x, 0).x;

                                                // Snapshot original frames (we only move on release)
                                                dragSelectionSnapshots = [];
                                                for (var i = 0; i < dopesheetRoot.selectedKeyframes.length; ++i) {
                                                    dragSelectionSnapshots.push({
                                                        propId: dopesheetRoot.selectedKeyframes[i].propId,
                                                        origFrame: dopesheetRoot.selectedKeyframes[i].frame
                                                    });
                                                }
                                            }

                                            onPositionChanged: mouse => {
                                                mouse.accepted = true;
                                                if (!pressed || !(mouse.buttons & Qt.LeftButton))
                                                    return;

                                                var currentCanvasX = mapToItem(canvasContent, mouse.x, 0).x;
                                                var deltaPixels = currentCanvasX - startCanvasMouseX;
                                                var deltaFrames = Math.round(deltaPixels / dopesheetRoot.zoomFactor);

                                                // Only update the visual offset – no model calls yet
                                                dopesheetRoot.dragDeltaFrames = deltaFrames;
                                            }

                                            onReleased: mouse => {
                                                mouse.accepted = true;

                                                var delta = dopesheetRoot.dragDeltaFrames;

                                                if (delta !== 0 && dopesheetRoot.activeTimelineModel) {
                                                    for (var i = 0; i < dragSelectionSnapshots.length; ++i) {
                                                        var snap = dragSelectionSnapshots[i];
                                                        var targetFrame = Math.max(0, snap.origFrame + delta);
                                                        if (targetFrame !== snap.origFrame) {
                                                            dopesheetRoot.activeTimelineModel.moveKeyframe(dopesheetRoot.activeClipId, snap.propId, snap.origFrame, targetFrame);
                                                        }
                                                    }
                                                }

                                                // Update selection to the final frames
                                                var updatedSelection = [];
                                                for (var j = 0; j < dragSelectionSnapshots.length; ++j) {
                                                    var s = dragSelectionSnapshots[j];
                                                    updatedSelection.push({
                                                        clipId: dopesheetRoot.activeClipId,
                                                        propId: s.propId,
                                                        frame: Math.max(0, s.origFrame + delta)
                                                    });
                                                }
                                                dopesheetRoot.selectedKeyframes = updatedSelection;

                                                // End drag
                                                dopesheetRoot.isDraggingKeyframes = false;
                                                dopesheetRoot.dragDeltaFrames = 0;
                                                dopesheetRoot.refreshChannels();
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
    }

    // =========================================================
    // 4. PRODUCTION PLAYHEAD COMPONENT
    // =========================================================
    XylaPlayhead {
        id: mainPlayhead
        timelineRoot: dopesheetRoot
        activeTimelineModel: dopesheetRoot.activeTimelineModel
        currentFrame: dopesheetRoot.currentPlayheadFrame
        zoomFactor: dopesheetRoot.zoomFactor
        horizontalOffset: dopesheetRoot.horizontalOffset
        rulerHeight: 32 + 28
        playheadMargin: dopesheetRoot.headerWidth
        headerWidth: dopesheetRoot.headerWidth
        height: parent.height
        visible: dopesheetRoot.activeClipData !== null
        z: 300
    }

    // =========================================================
    // 5. CONTEXT MENU
    // =========================================================
    XylaDopesheetContextMenu {
        id: dopesheetContextMenu
        dopesheetRoot: dopesheetRoot
        timelineModel: dopesheetRoot.activeTimelineModel

        onDeleteKeyframeRequested: {
            if (activeTimelineModel && activeClipId !== "" && activePropertyId !== "") {
                activeTimelineModel.removeKeyframe(activeClipId, activePropertyId, clickedFrame);
            }
        }

        onClearAllKeyframesRequested: {
            if (activeTimelineModel && activeClipId !== "") {
                var channels = ["positionX", "positionY", "scaleX", "scaleY", "rotation", "opacity", "volume", "pan"];
                for (var i = 0; i < channels.length; ++i) {
                    var chInfo = activeTimelineModel.getClipAnimChannels(activeClipId, 0);
                    for (var c = 0; c < chInfo.length; ++c) {
                        var kfs = chInfo[c].keyframes || [];
                        for (var k = 0; k < kfs.length; ++k) {
                            activeTimelineModel.removeKeyframe(activeClipId, chInfo[c].id, kfs[k]);
                        }
                    }
                }
            }
        }
    }
}
