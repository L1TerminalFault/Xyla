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

    // Unified style palette color matching the rod and badge fill
    readonly property color themeAccent: "#444444"

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

        return pad(mins) + ":" + pad(secs) + ":" + pad(f);
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
                    id: milestoneItem
                    required property var modelData
                    readonly property real currentStep: root.calculateStepFrames()
                    readonly property real stepPixelWidth: currentStep * root.zoomFactor

                    x: Math.round(modelData * root.zoomFactor)
                    y: 0
                    width: Math.round(stepPixelWidth)
                    height: parent.height

                    // 1. FIXED/RESTORED: Milestone rod line is taller, now sharing color with the palette back
                    Rectangle {
                        id: milestoneRod
                        width: 1
                        height: 13
                        color: root.themeAccent
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        z: 5
                    }

                    // 2. FIXED STYLES: Floating palette container in its original text position
                    Rectangle {
                        id: textPalette
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9.5
                        anchors.leftMargin: 0

                        // FIX 1: Add your explicit left/right padding (e.g., 2px + 2px = 4px total padding) directly into the dynamic text width boundary
                        width: Math.min(textLabel.implicitWidth + 12, milestoneItem.stepPixelWidth - 4)
                        height: 14

                        color: "#292929"
                        topLeftRadius: 6
                        topRightRadius: 6
                        bottomRightRadius: 6
                        bottomLeftRadius: 0
                        z: 6

                        visible: milestoneItem.stepPixelWidth > 24

                        Text {
                            id: textLabel

                            // FIX 2: Restoring centerIn natively satisfies flawless vertical and horizontal centering inside the fixed palette box
                            anchors.centerIn: parent

                            text: root.formatRulerTime(modelData, currentStep)
                            color: "#ffffff"
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                            // visible: textPalette.width >= 56
                        }
                    }

                    // 3. Inner submarkers between milestone intervals
                    // 3. CORRECTED 7-TICK HIERARCHY: 7 ticks (8 perfect fractions)
                    Repeater {
                        model: milestoneItem.stepPixelWidth > 110 ? 7 : 0

                        delegate: Rectangle {
                            required property int index

                            // Divide step width into 8 perfect partitions
                            x: Math.round((index + 1) * (milestoneItem.stepPixelWidth / 8))
                            anchors.bottom: parent.bottom
                            width: 1

                            // 7-Tick Math Breakdown (index 0 to 6):
                            // Center line: index 3 (the 4th tick) -> Tallest (height 8)
                            // Quarters:    index 1 & 5 (the 25% and 75% marks) -> Medium (height 6)
                            // Smallest:    index 0, 2, 4, 6 -> Shorter but highly visible (height 4.5)
                            height: (index === 3) ? 8 : ((index === 1 || index === 5) ? 6 : 4)

                            color: (index === 3) ? "#666666" : ((index === 1 || index === 5) ? "#555555" : "#444444")
                        }
                    }
                }
            }
        }
    }
}
