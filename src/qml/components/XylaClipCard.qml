import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var clipData: null
    property double zoomFactor: 1.0
    property int trackIndex: 0
    property bool isSelected: false

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    // Safe numeric conversion (prevents NaN)
    x: (clipData && clipData.startFrame !== undefined) ? Number(clipData.startFrame) * root.zoomFactor : 0
    width: (clipData && clipData.durationFrames !== undefined) ? Math.max(20, Number(clipData.durationFrames) * root.zoomFactor) : 100
    height: parent ? Math.max(30, parent.height - 8) : 40
    y: 4
    z: 190

    Component.onCompleted: {
        console.log("[XylaClipCard] Rendered! Name:", clipData ? clipData.name : "null", "x:", x, "width:", width, "height:", height);
    }

    // Background Card
    Rectangle {
        anchors.fill: parent
        color: root.clipData && root.clipData.trackKind === 1 ? "#107C41" : "#2555D3" // Green Audio / Blue Video
        border.color: root.isSelected ? "#ffffff" : "#2d2d2d"
        border.width: root.isSelected ? 2 : 1
        radius: 4
        clip: true

        // Clip Title
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.clipData ? root.clipData.name : "Clip"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
        }

        // Left Trim Handle
        Rectangle {
            id: leftTrim
            width: 6
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: leftTrimMouse.containsMouse ? "#ffffff" : "#33ffffff"

            MouseArea {
                id: leftTrimMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property int startX: 0
                onPressed: function (mouse) {
                    startX = mouse.x;
                }
                onPositionChanged: function (mouse) {
                    if (pressed && root.activeTimelineModel && root.clipData) {
                        var deltaPx = mouse.x - startX;
                        var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                        if (deltaFrames !== 0) {
                            var newStart = Math.max(0, Number(root.clipData.startFrame) + deltaFrames);
                            var newDur = Math.max(1, Number(root.clipData.durationFrames) - deltaFrames);
                            var newIn = Math.max(0, Number(root.clipData.sourceInFrame) + deltaFrames);
                            root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, newStart, newDur, newIn, false);
                        }
                    }
                }
            }
        }

        // Right Trim Handle
        Rectangle {
            id: rightTrim
            width: 6
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: rightTrimMouse.containsMouse ? "#ffffff" : "#33ffffff"

            MouseArea {
                id: rightTrimMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property int startX: 0
                onPressed: function (mouse) {
                    startX = mouse.x;
                }
                onPositionChanged: function (mouse) {
                    if (pressed && root.activeTimelineModel && root.clipData) {
                        var deltaPx = mouse.x - startX;
                        var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                        if (deltaFrames !== 0) {
                            var newDur = Math.max(1, Number(root.clipData.durationFrames) + deltaFrames);
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

        property int startX: 0
        onPressed: function (mouse) {
            startX = mouse.x;
            root.isSelected = true;
        }

        onPositionChanged: function (mouse) {
            if (pressed && root.activeTimelineModel && root.clipData) {
                var deltaPx = mouse.x - startX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);
                if (deltaFrames !== 0) {
                    var newStart = Math.max(0, Number(root.clipData.startFrame) + deltaFrames);
                    root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.trackIndex, newStart);
                }
            }
        }
    }
}
