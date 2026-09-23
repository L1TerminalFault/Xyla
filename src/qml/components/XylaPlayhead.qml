import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property var timelineRoot: null
    property var activeTimelineModel: null
    property var topToolBar: null

    property int currentFrame: 0
    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real rulerHeight: 28.0
    property real playheadMargin: 10.0
    property int headerWidth: 0

    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    property bool isDragging: false
    property real dragPixelX: 0.0

    readonly property color playheadColor: "#ff3030"
    readonly property bool isPlayingReverse: activePlaybackManager && activePlaybackManager.isPlaying && activePlaybackManager.isPlayingReverse

    // Only visible when within the active canvas area (never over the header sidebar)
    readonly property bool isPlayheadVisible: dragPixelX >= (playheadMargin - 1) && (!parent || dragPixelX <= parent.width + 10)

    // =========================================================================
    // FEATURE 2: Configurable Time Display Mode ("hover" | "always" | "never")
    // =========================================================================
    // readonly property string timeDisplayMode: topToolBar ? topToolBar.playheadTimeMode : "never"


    // =========================================================================
    // FEATURE 3: Palette Left Edge Clamping & Corner Blending
    // =========================================================================
    // Exact screen position where frame 0:0 points
    readonly property real zeroLimitX: root.playheadMargin - root.horizontalOffset

    // When centered on line, handle's left edge is at (root.dragPixelX - handle.width / 2).
    // If that goes to the left of zeroLimitX, shift handle right so it clamps at zeroLimitX:
    readonly property real handleClampOffset: Math.max(0, zeroLimitX - (root.dragPixelX - (handle.width / 2)))
    readonly property bool isClampedToLeft: handleClampOffset > 0.5

    x: dragPixelX
    width: 1
    z: 200

    onCurrentFrameChanged: updateIdlePosition()
    onZoomFactorChanged: updateIdlePosition()
    onHorizontalOffsetChanged: updateIdlePosition()
    onPlayheadMarginChanged: updateIdlePosition()
    Component.onCompleted: updateIdlePosition()

    function updateIdlePosition() {
        if (!isDragging) {
            dragPixelX = playheadMargin + (currentFrame * zoomFactor) - horizontalOffset;
        }
    }

    // Motion Trail Gradient
    Rectangle {
        id: trail
        anchors.top: parent.top
        anchors.topMargin: root.rulerHeight
        anchors.bottom: parent.bottom
        width: 20
        x: isPlayingReverse ? 1 : -width + 1
        opacity: (activePlaybackManager && activePlaybackManager.isPlaying && root.isPlayheadVisible) ? 1.0 : 0.0
        visible: root.isPlayheadVisible && opacity > 0.0

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
                color: "#00ff3030"
            }
            GradientStop {
                position: isPlayingReverse ? 0.0 : 1.0
                color: "#40ff3030"
            }
        }
    }

    // Vertical Playhead Line (Hidden when scrolled behind the header)
    Rectangle {
        id: line
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.rulerHeight
        anchors.bottom: parent.bottom
        width: 1
        color: root.playheadColor
        visible: root.isPlayheadVisible
    }

    // Downward Triangle Handle (Palette Bubble)
    Rectangle {
        id: handle

        property bool hovered: handleMouse.containsMouse

        readonly property bool showTime: {
            if (root.topToolBar.playheadTimeMode === "always") return true;
            if (root.topToolBar.playheadTimeMode === "never") return false;
            return hovered;
        }

        width: showTime ? 54 : 16
        height: showTime ? 18 : 16

        // Clamped at left edge so it never goes out of view or under sidebar
        anchors.horizontalCenter: line.horizontalCenter
        anchors.horizontalCenterOffset: root.handleClampOffset

        // Keep the bottom point anchored at the exact position
        y: root.rulerHeight - (height + pointer.height - 1)

        color: root.playheadColor
        bottomRightRadius: showTime ? height / 2 : 3.5
        topRightRadius: showTime ? height / 2 : 3.5

        topLeftRadius: root.isClampedToLeft ? 0 : showTime ? height / 2 : 3.5
        bottomLeftRadius: root.isClampedToLeft ? 0 : showTime ? height / 2 : 3.5

        Behavior on topLeftRadius {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on topRightRadius {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Behavior on bottomLeftRadius {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            ParallelAnimation {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                // NumberAnimation { target: handle; property: "radius"; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        // Left Edge Flat Blend: Removes left radius when clamped to the left edge of timeline
        // Rectangle {
        //     id: leftEdgeBlend
        //     anchors.left: parent.left
        //     anchors.top: parent.top
        //     anchors.bottom: parent.bottom
        //     width: root.isClampedToLeft ? parent.radius : 0
        //     color: parent.color
        //     visible: width > 0
        //
        //     Behavior on width {
        //         NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        //     }
        // }

        // =====================================================================
        // Tiny outward-curved pointer (Triangle under handle - 100% UNTOUCHED)
        // =====================================================================
        Shape {
            id: pointer

            width: 10
            height: 5

anchors.horizontalCenter: parent.horizontalCenter
anchors.horizontalCenterOffset: -root.handleClampOffset
            anchors.top: parent.bottom

            ShapePath {
                fillColor: root.playheadColor
                strokeColor: "transparent"
                strokeWidth: 0

                startX: 0
                startY: 0

                // Line down to the bottom-center point
                PathLine {
                    x: pointer.width / 2
                    y: pointer.height
                }

                // Line up to the top-right corner
                PathLine {
                    x: pointer.width
                    y: 0
                }

                // Line back to the top-left starting point to close the triangle
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

        // Time Text Inside Palette Bubble
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            clip: true

            Text {
                anchors.centerIn: parent

                opacity: handle.showTime ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                text: {
                    var totalSeconds = Math.max(0, root.currentFrame) / 30.0;
                    var minutes = Math.floor(totalSeconds / 60);
                    var seconds = Math.floor(totalSeconds % 60);
                    var frames = Math.floor(root.currentFrame % 30);

                    return minutes.toString().padStart(2, "0")
                        + ":"
                        + seconds.toString().padStart(2, "0")
                        + ":"
                        + frames.toString().padStart(2, "0");
                }

                color: "white"
                font.pixelSize: 9
                font.bold: true

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // =====================================================================
        // MouseArea for the Palette Bubble (Handle) with CLAMPING TO LEFT EDGE
        // =====================================================================
        MouseArea {
            id: handleMouse

            anchors.fill: parent
            anchors.margins: -7

            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            property real startMouseX: 0
            property real startDragPixelX: 0

            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) return;

                root.isDragging = true;
                if (root.activePlaybackManager)
                    root.activePlaybackManager.startScrubbing();

                var pt = handleMouse.mapToItem(root.parent, mouse.x - (handle.width / 2), mouse.y);
                startMouseX = pt.x;
                startDragPixelX = root.dragPixelX;
            }

            onPositionChanged: function(mouse) {
                if (pressed && (mouse.buttons & Qt.LeftButton)) {
                    var pt = handleMouse.mapToItem(root.parent, mouse.x - (handle.width / 2), mouse.y);
                    var deltaX = pt.x - startMouseX;
                    var rawPixelX = startDragPixelX + deltaX;

                    // STRICTLY CLAMP dragPixelX to the left limit (frame 0:0 position)
                    var minPixelX = root.playheadMargin - root.horizontalOffset;
                    root.dragPixelX = Math.max(minPixelX, rawPixelX);

                    var targetFrame = Math.max(0, Math.round((root.dragPixelX - playheadMargin + root.horizontalOffset) / root.zoomFactor));
                    if (root.activePlaybackManager) {
                        root.activePlaybackManager.scrubToFrame(targetFrame);
                    }
                }
            }

            onReleased: function(mouse) {
                if (root.activePlaybackManager) {
                    root.activePlaybackManager.stopScrubbing();
                    if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                        root.timelineRoot.hideSnapGuides();
                    }
                }
                Qt.callLater(function () {
                    root.isDragging = false;
                });
            }

            // Right-click to toggle: hover -> always -> never

    // Inside handleMouse:
    onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && root.topToolBar) {
            var current = root.topToolBar.playheadTimeMode;
            var next = (current === "hover") ? "always" : (current === "always" ? "never" : "hover");
            root.topToolBar.playheadTimeMode = next;

            if (root.activeTimelineModel && root.activeTimelineModel.setPlayheadTimeMode) {
                root.activeTimelineModel.setPlayheadTimeMode(next);
            }
        }
    }
            // onClicked: function(mouse) {
            //     if (mouse.button === Qt.RightButton) {
            //         if (root.timeDisplayMode === "hover")
            //             root.timeDisplayMode = "always";
            //         else if (root.timeDisplayMode === "always")
            //             root.timeDisplayMode = "never";
            //         else
            //             root.timeDisplayMode = "hover";
            //
            //         if (root.activeTimelineModel && root.activeTimelineModel.setPlayheadTimeMode) {
            //             // root.activeTimelineModel.setPlayheadTimeMode(root.timeDisplayMode);
            //             root.topToolBar.playheadTimeMode = root.timeDisplayMode;
            //         }
            //     }
            // }
        }
    }

    // Playhead Line Hover Detection Area
    MouseArea {
        id: playheadHoverArea

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        width: 20

        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onEntered: handle.hovered = true
        onExited: handle.hovered = false
    }
}
