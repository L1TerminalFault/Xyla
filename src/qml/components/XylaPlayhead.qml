import QtQuick

Item {
    id: root

    property int currentFrame: 0
    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real rulerHeight: 28.0

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    // Track dragging state explicitly
    property bool isDragging: false
    property real dragPixelX: 0.0

    width: 2
    z: 200

    // Force position to track drag state accurately
    onCurrentFrameChanged: {
        if (!isDragging) {
            dragPixelX = (currentFrame * zoomFactor) - horizontalOffset;
        }
    }

    Rectangle {
        id: line
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.rulerHeight
        anchors.bottom: parent.bottom
        width: 2
        color: "#2555D3"
    }

    Rectangle {
        id: handle
        width: 14
        height: 14
        radius: 3
        color: "#2555D3"
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.rulerHeight - height

        MouseArea {
            id: playheadMouse
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            function updateSeek(mouse, isRelease) {
                if (!root.parent)
                    return;

                var pt = mapToItem(root.parent, mouse.x, mouse.y);

                // Calculate exact canvas offset & frame snap point
                var canvasX = pt.x + root.horizontalOffset;
                var targetFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));

                // Align drag position to nearest frame pixel to prevent release jumps
                root.dragPixelX = (targetFrame * root.zoomFactor) - root.horizontalOffset;

                if (root.activePlaybackManager) {
                    if (isRelease) {
                        root.activePlaybackManager.scrubToFrame(targetFrame);
                        root.activePlaybackManager.stopScrubbing();
                    } else {
                        root.activePlaybackManager.scrubToFrame(targetFrame);
                    }
                }
            }

            onPressed: function (mouse) {
                root.isDragging = true;
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

            onReleased: function (mouse) {
                updateSeek(mouse, true);
                root.isDragging = false;
            }
        }
    }
}
