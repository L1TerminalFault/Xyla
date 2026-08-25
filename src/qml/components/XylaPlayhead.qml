import QtQuick

Item {
    id: root

    property int currentFrame: 0
    property double zoomFactor: 1.0
    property int headerWidth: 350
    property real horizontalOffset: 0.0
    property Item timelineContainer: parent

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    width: 2
    z: 200

    // Vertical Blue Indicator Line
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: "#2555D3"
    }

    // Top Pointer Handle
    Rectangle {
        width: 14
        height: 14
        radius: 3
        color: "#2555D3"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function updateSeek(mouse) {
                if (!root.activePlaybackManager || !root.timelineContainer)
                    return;

                var pt = mapToItem(root.timelineContainer, mouse.x, mouse.y);
                var canvasX = pt.x - root.headerWidth + root.horizontalOffset;
                var targetFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));
                root.activePlaybackManager.seekFrame(targetFrame);
            }

            onPressed: function (mouse) {
                updateSeek(mouse);
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    updateSeek(mouse);
                }
            }
        }
    }
}
