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
    property bool isDragging: false

    x: (isDragging ? localStartFrame : ((clipData && clipData.startFrame !== undefined) ? Number(clipData.startFrame) : 0)) * root.zoomFactor
    width: (clipData && clipData.durationFrames !== undefined) ? Math.max(20, Number(clipData.durationFrames) * root.zoomFactor) : 100
    height: parent ? Math.max(30, parent.height - 8) : 40
    y: 4
    z: isDragging ? 250 : 190

    // Clip Card Container
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.114, 0.365, 0.859, 0.3)
        border.color: root.isSelected ? "#ffffff" : Qt.rgba(0.114, 0.365, 0.859, 0.5)
        border.width: root.isSelected ? 2 : 3
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

        // Left 2px Violet Trim Handle
        Rectangle {
            id: leftTrim
            width: 2
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: leftTrimMouse.containsMouse || leftTrimMouse.pressed ? "#A855F7" : "#7C3AED"
            z: 30

            MouseArea {
                id: leftTrimMouse
                anchors.fill: parent
                anchors.leftMargin: -4
                anchors.rightMargin: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property int startMouseCanvasX: 0
                property int startFrame: 0
                property int startDur: 0
                property int startIn: 0

                onPressed: function (mouse) {
                    if (root.clipData && root.parent) {
                        var pt = mapToItem(root.parent, mouse.x, mouse.y);
                        startMouseCanvasX = pt.x;
                        startFrame = Number(root.clipData.startFrame);
                        startDur = Number(root.clipData.durationFrames);
                        startIn = Number(root.clipData.sourceInFrame);
                    }
                }

                onPositionChanged: function (mouse) {
                    if (pressed && root.activeTimelineModel && root.clipData && root.parent) {
                        var pt = mapToItem(root.parent, mouse.x, mouse.y);
                        var deltaPx = pt.x - startMouseCanvasX;
                        var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                        if (deltaFrames !== 0) {
                            var newStart = Math.max(0, startFrame + deltaFrames);
                            var newDur = Math.max(1, startDur - deltaFrames);
                            var newIn = Math.max(0, startIn + deltaFrames);
                            root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, newStart, newDur, newIn, false);
                        }
                    }
                }
            }
        }

        // Right 2px Violet Trim Handle
        Rectangle {
            id: rightTrim
            width: 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: rightTrimMouse.containsMouse || rightTrimMouse.pressed ? "#A855F7" : "#7C3AED"
            z: 30

            MouseArea {
                id: rightTrimMouse
                anchors.fill: parent
                anchors.leftMargin: -4
                anchors.rightMargin: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property int startMouseCanvasX: 0
                property int startDur: 0

                onPressed: function (mouse) {
                    if (root.clipData && root.parent) {
                        var pt = mapToItem(root.parent, mouse.x, mouse.y);
                        startMouseCanvasX = pt.x;
                        startDur = Number(root.clipData.durationFrames);
                    }
                }

                onPositionChanged: function (mouse) {
                    if (pressed && root.activeTimelineModel && root.clipData && root.parent) {
                        var pt = mapToItem(root.parent, mouse.x, mouse.y);
                        var deltaPx = pt.x - startMouseCanvasX;
                        var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                        if (deltaFrames !== 0) {
                            var newDur = Math.max(1, startDur + deltaFrames);
                            root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), newDur, Number(root.clipData.sourceInFrame), false);
                        }
                    }
                }
            }
        }
    }

    // Clip Move Drag Handler
    MouseArea {
        id: moveMouse
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeAllCursor
        preventStealing: true

        property int startMouseCanvasX: 0
        property int startClipFrame: 0

        onPressed: function (mouse) {
            root.isSelected = true;
            root.isDragging = true;
            if (root.clipData && root.parent) {
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                startMouseCanvasX = pt.x;
                startClipFrame = Number(root.clipData.startFrame);
                root.localStartFrame = startClipFrame;
            }
        }

        onPositionChanged: function (mouse) {
            if (pressed && root.clipData && root.parent) {
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startMouseCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                var newStart = Math.max(0, startClipFrame + deltaFrames);
                root.localStartFrame = newStart;
            }
        }

        onReleased: function () {
            root.isDragging = false;
            if (root.activeTimelineModel && root.clipData) {
                root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.trackIndex, Math.round(root.localStartFrame));
            }
        }
    }
}
