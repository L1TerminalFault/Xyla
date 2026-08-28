import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var clipData: null
    property double zoomFactor: 1.0
    property int trackIndex: 0
    property bool isSelected: false

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    // Real-time visual drag tracking
    property real localStartFrame: (clipData && clipData.startFrame !== undefined) ? Number(clipData.startFrame) : 0
    property real localDurationFrames: (clipData && clipData.durationFrames !== undefined) ? Number(clipData.durationFrames) : 30
    property real localSourceInFrame: (clipData && clipData.sourceInFrame !== undefined) ? Number(clipData.sourceInFrame) : 0
    property int localTrackIndex: root.trackIndex
    property int startTrackIndex: 0

    property bool isDragging: false
    property bool isTrimmingLeft: false
    property bool isTrimmingRight: false

    // Smooth continuous vertical pixel offset during drag
    property real dragOffsetY: 0

    // Dynamic X and Width calculation decoupled from layout feedback loops
    x: ((isDragging || isTrimmingLeft) ? localStartFrame : ((clipData && clipData.startFrame !== undefined) ? Number(clipData.startFrame) : 0)) * root.zoomFactor
    width: ((isTrimmingLeft || isTrimmingRight) ? localDurationFrames : ((clipData && clipData.durationFrames !== undefined) ? Math.max(20, Number(clipData.durationFrames)) : 100)) * root.zoomFactor
    height: parent ? Math.max(30, parent.height - 8) : 40

    // Smooth pixel Y positioning when dragging, static 4px offset when dropped
    y: isDragging ? (4 + dragOffsetY) : 4
    z: isDragging ? 9999 : 190

    // Walk up parent tree to locate delegateRow and elevate its Z-index so it floats over ALL tracks (both UP and DOWN)
    onIsDraggingChanged: {
        var p = parent;
        while (p) {
            if (p.trackIdx !== undefined) {
                p.z = isDragging ? 9999 : 0;
                break;
            }
            p = p.parent;
        }
    }

    // Clip Card Container
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.114, 0.365, 0.859, 0.3)

        // Stays thin (1px), brightens to vibrant blue when selected, dragging, or trimming
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? "#3B82F6" : Qt.rgba(0.114, 0.365, 0.859, 0.5)
        border.width: 1
        radius: 0
        clip: true

        // Left Start Frame Thumbnail Preview
        Image {
            id: leftThumbnail
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.min(height * 1.77, (parent.width - 20) / 2)
            fillMode: Image.PreserveAspectCrop
            visible: width > 15
            source: root.clipData ? "image://thumbnails/" + root.clipData.assetId : ""
        }

        // Right End Frame Thumbnail Preview
        Image {
            id: rightThumbnail
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.min(height * 1.77, (parent.width - 20) / 2)
            fillMode: Image.PreserveAspectCrop
            visible: width > 15 && parent.width > (width * 2 + 30)
            source: root.clipData ? "image://thumbnails/" + root.clipData.assetId : ""
        }

        // Top-Left Rounded Name Pill Badge
        Rectangle {
            id: namePill
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 6
            height: 20
            width: Math.min(parent.width - 12, nameText.implicitWidth + 16)
            color: "#1D5DDB"
            radius: 4
            z: 20

            Text {
                id: nameText
                anchors.centerIn: parent
                text: root.clipData ? root.clipData.name : "Clip"
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - 12
            }
        }
    }

    // Body Move Mouse Area (Middle region)
    MouseArea {
        id: moveMouse
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: moveMouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true

        HoverHandler {
            cursorShape: moveMouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        property real startMouseGlobalX: 0
        property real startMouseGlobalY: 0
        property int startClipFrame: 0

        onPressed: function (mouse) {
            root.isSelected = true;
            root.isDragging = true;
            if (root.clipData) {
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                startMouseGlobalX = globalPt.x;
                startMouseGlobalY = globalPt.y;

                startClipFrame = Number(root.clipData.startFrame);
                root.startTrackIndex = root.trackIndex;
                root.localStartFrame = startClipFrame;
                root.localTrackIndex = root.trackIndex;
                root.dragOffsetY = 0;
            }
        }

        onPositionChanged: function (mouse) {
            if (pressed && root.clipData) {
                var globalPt = mapToItem(null, mouse.x, mouse.y);

                // 1. Horizontal frame positioning
                var deltaPx = globalPt.x - startMouseGlobalX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                var newStart = Math.max(0, startClipFrame + deltaFrames);
                root.localStartFrame = newStart;

                // 2. Smooth vertical pixel drag
                var deltaPy = globalPt.y - startMouseGlobalY;
                root.dragOffsetY = deltaPy;

                // 3. Track index targeting based on cursor offset
                var trackHeight = root.parent ? root.parent.height : 48;
                var deltaTracks = Math.round(deltaPy / trackHeight);
                var targetTrack = Math.max(0, root.startTrackIndex + deltaTracks);

                root.localTrackIndex = targetTrack;
            }
        }

        onReleased: function () {
            root.isDragging = false;
            root.dragOffsetY = 0;
            if (root.activeTimelineModel && root.clipData) {
                root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
            }
        }
    }

    // Left Edge Trim Handle (Visual width 2px)
    Rectangle {
        id: leftTrim
        width: 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: leftTrimMouse.containsMouse || leftTrimMouse.pressed ? "#60A5FA" : "#1D5DDB"
        z: 100

        MouseArea {
            id: leftTrimMouse
            anchors.fill: parent
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            HoverHandler {
                cursorShape: Qt.SizeHorCursor
            }

            property real startMouseGlobalX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0

            onPressed: function (mouse) {
                root.isSelected = true;
                root.isTrimmingLeft = true;
                if (root.clipData) {
                    var globalPt = mapToItem(null, mouse.x, mouse.y);
                    startMouseGlobalX = globalPt.x;
                    startFrame = Number(root.clipData.startFrame);
                    startDur = Number(root.clipData.durationFrames);
                    startIn = Number(root.clipData.sourceInFrame);

                    root.localStartFrame = startFrame;
                    root.localDurationFrames = startDur;
                    root.localSourceInFrame = startIn;
                }
            }

            onPositionChanged: function (mouse) {
                if (pressed && root.clipData) {
                    var globalPt = mapToItem(null, mouse.x, mouse.y);
                    var deltaPx = globalPt.x - startMouseGlobalX;
                    var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                    // Clamp delta so startFrame >= 0, duration >= 1, and sourceIn >= 0
                    var maxAllowedDelta = startDur - 1;
                    var minAllowedDelta = -Math.min(startFrame, startIn);
                    var clampedDelta = Math.max(minAllowedDelta, Math.min(maxAllowedDelta, deltaFrames));

                    root.localStartFrame = startFrame + clampedDelta;
                    root.localDurationFrames = startDur - clampedDelta;
                    root.localSourceInFrame = startIn + clampedDelta;
                }
            }

            onReleased: function () {
                root.isTrimmingLeft = false;
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Math.round(root.localStartFrame), Math.round(root.localDurationFrames), Math.round(root.localSourceInFrame), false);
                }
            }
        }
    }

    // Right Edge Trim Handle (Visual width 2px)
    Rectangle {
        id: rightTrim
        width: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: rightTrimMouse.containsMouse || rightTrimMouse.pressed ? "#60A5FA" : "#1D5DDB"
        z: 100

        MouseArea {
            id: rightTrimMouse
            anchors.fill: parent
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            HoverHandler {
                cursorShape: Qt.SizeHorCursor
            }

            property real startMouseGlobalX: 0
            property int startDur: 0

            onPressed: function (mouse) {
                root.isSelected = true;
                root.isTrimmingRight = true;
                if (root.clipData) {
                    var globalPt = mapToItem(null, mouse.x, mouse.y);
                    startMouseGlobalX = globalPt.x;
                    startDur = Number(root.clipData.durationFrames);
                    root.localDurationFrames = startDur;
                }
            }

            onPositionChanged: function (mouse) {
                if (pressed && root.clipData) {
                    var globalPt = mapToItem(null, mouse.x, mouse.y);
                    var deltaPx = globalPt.x - startMouseGlobalX;
                    var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                    var newDur = Math.max(1, startDur + deltaFrames);

                    root.localDurationFrames = newDur;
                }
            }

            onReleased: function () {
                root.isTrimmingRight = false;
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), Math.round(root.localDurationFrames), Number(root.clipData.sourceInFrame), false);
                }
            }
        }
    }
}
