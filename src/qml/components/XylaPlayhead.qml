import QtQuick

Item {
    id: root

    property int currentFrame: 0
    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    readonly property bool isDragging: playheadMouse.pressed
    property real dragPixelX: 0.0

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
        id: handle
        width: 14
        height: 14
        radius: 3
        color: "#2555D3"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        MouseArea {
            id: playheadMouse
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            function updateSeek(mouse, isRelease) {
                if (!root.parent)
                    return;

                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                root.dragPixelX = pt.x;

                var canvasX = pt.x + root.horizontalOffset;
                var targetFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));

                if (root.activePlaybackManager) {
                    if (isRelease) {
                        root.activePlaybackManager.stopScrubbing();
                    } else {
                        root.activePlaybackManager.scrubToFrame(targetFrame);
                    }
                }
            }

            onPressed: function (mouse) {
                if (root.activePlaybackManager) {
                    root.activePlaybackManager.startScrubbing();
                }
                updateSeek(mouse, false);
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    updateSeek(mouse, false);
                }
            }

            // Seek on Release: Locks in the exact B/P-frame when mouse is released
            onReleased: function (mouse) {
                updateSeek(mouse, true);
            }
        }
    }
}
