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

    function formatRulerTime(frame) {
        var totalSec = frame / root.fps;
        var mins = Math.floor(totalSec / 60);
        var secs = Math.floor(totalSec % 60);
        function pad(n) {
            return n < 10 ? "0" + n : n;
        }
        return pad(mins) + ":" + pad(secs);
    }

    // Fixed Left Ruler Header
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

    // Scrolled Timeline Ruler Bar
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

            function seekRuler(mouse) {
                if (!root.activePlaybackManager)
                    return;

                var canvasX = mouse.x + root.horizontalOffset;
                var targetFrame = Math.max(0, Math.round(canvasX / root.zoomFactor));
                root.activePlaybackManager.seekFrame(targetFrame);
            }

            onPressed: function (mouse) {
                seekRuler(mouse);
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    seekRuler(mouse);
                }
            }
        }

        // Native Vector-Sharp Ruler Container
        Item {
            x: -root.horizontalOffset
            width: root.contentWidth
            height: parent.height

            // True C++ VRAM Cache Indicator Rectangles (#2555D3 Accent)
            // Renders disjoint cache bars with gap support
            Repeater {
                model: root.activeCompositor ? root.activeCompositor.cachedRanges : []

                delegate: Rectangle {
                    required property var modelData

                    readonly property real startFrame: modelData ? modelData.start : 0
                    readonly property real endFrame: modelData ? modelData.end : 0

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

            // Bottom Border Line
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.borderDark
                z: 1
            }

            // Lightweight Visible Ticks Repeater
            Repeater {
                model: {
                    var stepFrames = Math.max(1, Math.round(80 / root.zoomFactor));
                    if (stepFrames < 5)
                        stepFrames = 5;
                    if (stepFrames > 5 && stepFrames < 15)
                        stepFrames = 15;
                    if (stepFrames > 15 && stepFrames < 30)
                        stepFrames = 30;

                    var startFrame = Math.max(0, Math.floor(root.horizontalOffset / root.zoomFactor));
                    var visibleWidth = parent.width > 0 ? parent.width : 2000;
                    var endFrame = Math.ceil((root.horizontalOffset + visibleWidth) / root.zoomFactor);

                    var alignStart = Math.floor(startFrame / stepFrames) * stepFrames;
                    var count = Math.ceil((endFrame - alignStart) / stepFrames) + 1;

                    var frames = [];
                    for (var i = 0; i < count; ++i) {
                        frames.push(alignStart + (i * stepFrames));
                    }
                    return frames;
                }

                delegate: Item {
                    required property var modelData
                    readonly property real posX: Math.round(modelData * root.zoomFactor)

                    x: posX
                    y: 0
                    width: 60
                    height: parent.height

                    // Tick Mark
                    Rectangle {
                        width: 1
                        height: 8
                        color: "#444444"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                    }

                    // Vector Sharp Text
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        text: root.formatRulerTime(modelData)
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
