import QtQuick
import QtQuick.Controls

Item {
    id: root

    property int headerWidth: 350
    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 3600
    property double fps: 30.0

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
    property var activeCompositor: typeof timelineCompositor !== "undefined" ? timelineCompositor : null

    readonly property color bgDark: "#181818"
    readonly property color borderDark: "#2d2d2d"

    height: 28

    function formatRulerTime(frame, stepFrames) {
        var safeFps = root.fps > 0 ? root.fps : 30.0;
        var totalSec = frame / safeFps;
        var mins = Math.floor(totalSec / 60);
        var secs = Math.floor(totalSec % 60);
        var f = Math.floor(frame % safeFps);

        function pad(n) {
            return n < 10 ? "0" + n : n;
        }

        if (stepFrames < safeFps) {
            return pad(mins) + ":" + pad(secs) + ":" + pad(f);
        }
        return pad(mins) + ":" + pad(secs);
    }

    function calculateStepFrames() {
        var safeFps = root.fps > 0 ? root.fps : 30.0;
        var targetFrames = Math.max(1, Math.round(80 / root.zoomFactor));

        var candidates = [1, 2, 5, Math.round(safeFps / 4), Math.round(safeFps / 2), safeFps, safeFps * 2, safeFps * 5, safeFps * 10, safeFps * 30, safeFps * 60, safeFps * 300];

        for (var i = 0; i < candidates.length; ++i) {
            if (candidates[i] >= targetFrames) {
                return candidates[i];
            }
        }
        return safeFps * 600;
    }

    Rectangle {
        id: rulerHeader
        width: root.headerWidth
        height: parent.height
        color: root.bgDark
        z: 10

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: root.borderDark
        }

        Text {
            anchors.centerIn: parent
            text: "TIMELINE RULER"
            color: "#555555"
            font.pixelSize: 10
            font.bold: true
            renderType: Text.NativeRendering
        }
    }

    Item {
        anchors.left: rulerHeader.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function seekRuler(mouse, isRelease) {
                if (!root.activePlaybackManager)
                    return;
                var canvasX = mouse.x + root.horizontalOffset;
                var targetFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));

                root.activePlaybackManager.scrubToFrame(targetFrame);
                if (isRelease) {
                    root.activePlaybackManager.stopScrubbing();
                }
            }

            onPressed: function (mouse) {
                if (root.activePlaybackManager)
                    root.activePlaybackManager.startScrubbing();
                seekRuler(mouse, false);
            }

            onPositionChanged: function (mouse) {
                if (pressed)
                    seekRuler(mouse, false);
            }

            onReleased: function (mouse) {
                seekRuler(mouse, true);
            }
        }

        Item {
            x: -root.horizontalOffset
            width: root.contentWidth
            height: parent.height

            Repeater {
                model: root.activeCompositor?.cachedRanges ?? []

                delegate: Rectangle {
                    required property var modelData

                    readonly property real startFrame: modelData?.start ?? 0
                    readonly property real endFrame: modelData?.end ?? 0

                    y: parent.height - 4
                    height: 3
                    color: "#2555D3"
                    border.color: "#3B82F6"
                    border.width: 1
                    radius: 1
                    z: 2
                    visible: startFrame >= 0 && endFrame >= startFrame

                    x: Math.round(startFrame * root.zoomFactor)
                    width: Math.max(3, Math.round((endFrame - startFrame + 1) * root.zoomFactor))
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.borderDark
                z: 1
            }

            Repeater {
                model: {
                    var step = root.calculateStepFrames();
                    var startFrame = Math.max(0, Math.floor(root.horizontalOffset / root.zoomFactor));
                    var visibleWidth = parent.width > 0 ? parent.width : 2000;
                    var endFrame = Math.ceil((root.horizontalOffset + visibleWidth) / root.zoomFactor);

                    var alignStart = Math.floor(startFrame / step) * step;
                    var count = Math.ceil((endFrame - alignStart) / step) + 1;

                    var frames = [];
                    for (var i = 0; i < count; ++i) {
                        frames.push(alignStart + (i * step));
                    }
                    return frames;
                }

                delegate: Item {
                    required property var modelData
                    readonly property real currentStep: root.calculateStepFrames()

                    x: Math.round(modelData * root.zoomFactor)
                    y: 0
                    width: 70
                    height: parent.height

                    Rectangle {
                        width: 1
                        height: 8
                        color: "#444444"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: root.formatRulerTime(modelData, currentStep)
                        color: "#aaaaaa"
                        font.pixelSize: 10
                        font.bold: true
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
