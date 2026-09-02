import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    property var timelineRoot: null
    property var activeTimelineModel: null

    property int currentFrame: 0
    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real rulerHeight: 28.0
    property real playheadMargin: 10.0
    property int headerWidth: 0

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    property bool isDragging: false
    property real dragPixelX: 0.0

    readonly property color playheadColor: "#70f250"
    readonly property bool isPlayingReverse: activePlaybackManager && activePlaybackManager.isPlaying && activePlaybackManager.isPlayingReverse

    x: dragPixelX
    width: 1
    z: 200

    onCurrentFrameChanged: updateIdlePosition()
    onZoomFactorChanged: updateIdlePosition()
    onHorizontalOffsetChanged: updateIdlePosition()
    Component.onCompleted: updateIdlePosition()

    function updateIdlePosition() {
        if (!isDragging) {
            dragPixelX = playheadMargin + (currentFrame * zoomFactor) - horizontalOffset;
        }
    }

    // Motion Trail Gradient (Appears only during playback)
    Rectangle {
        id: trail
        anchors.top: parent.top
        anchors.topMargin: root.rulerHeight
        anchors.bottom: parent.bottom
        width: 20
        x: isPlayingReverse ? 1 : -width + 1
        opacity: (activePlaybackManager && activePlaybackManager.isPlaying) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: isPlayingReverse ? 0.7 : 0.3
                color: "#0070f250"
            }
            GradientStop {
                position: isPlayingReverse ? 0.0 : 1.0
                color: "#4070f250"
            }
        }
    }

    Rectangle {
        id: line
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.rulerHeight
        anchors.bottom: parent.bottom
        width: 1
        color: root.playheadColor
    }

    // Downward Triangle Handle
    Shape {
        id: handle
        width: 12
        height: 10
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.rulerHeight - height
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: root.playheadColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: 0

            PathLine {
                x: handle.width
                y: 0
            }
            PathLine {
                x: handle.width / 2
                y: handle.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }

        MouseArea {
            id: playheadMouse
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            function updateSeek(mouse, isRelease) {
                if (!root.parent)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var canvasX = pt.x + root.horizontalOffset - root.playheadMargin;
                var rawFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));
                var targetFrame = rawFrame;

                // Snapping with Shift key temporary inversion
                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                if (isSnappingActive && root.activeTimelineModel) {
                    var snapRes = root.activeTimelineModel.querySnap(rawFrame, 0, -1, -1, root.zoomFactor, [], 8.0);
                    if (snapRes && snapRes.isSnapped) {
                        targetFrame = Math.round(snapRes.snappedStart);
                        if (root.timelineRoot && root.timelineRoot.showSnapLine) {
                            root.timelineRoot.showSnapLine(targetFrame);
                        }
                    } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                        root.timelineRoot.hideSnapGuides();
                    }
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }

                root.dragPixelX = playheadMargin + (targetFrame * root.zoomFactor) - root.horizontalOffset;

                if (root.activePlaybackManager) {
                    root.activePlaybackManager.scrubToFrame(targetFrame);
                    if (isRelease) {
                        root.activePlaybackManager.stopScrubbing();
                        if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                            root.timelineRoot.hideSnapGuides();
                        }
                    }
                }
            }

            onPressed: function (mouse) {
                root.isDragging = true;
                if (root.activePlaybackManager)
                    root.activePlaybackManager.startScrubbing();
                updateSeek(mouse, false);
            }

            onPositionChanged: function (mouse) {
                if (pressed)
                    updateSeek(mouse, false);
            }

            onReleased: function (mouse) {
                updateSeek(mouse, true);
                Qt.callLater(function () {
                    root.isDragging = false;
                });
            }
        }
    }
}
