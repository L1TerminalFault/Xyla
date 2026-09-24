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

    readonly property color bgDark: "#121212"
    readonly property color borderDark: "#2d2d2d"
    readonly property color themeAccent: "#444444"

    height: 28

    function formatRulerTime(frame, safeFps) {
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
        color: "transparent" // root.bgDark
        z: 10

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "transparent" // root.borderDark
        }
    }

    Item {
        id: rulerTrackViewport
        anchors.left: rulerHeader.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        // ── High-Performance Canvas Ruler (0 allocations, 120 FPS) ──
        Canvas {
            id: rulerCanvas
            anchors.fill: parent
            renderTarget: Canvas.Image

            onPaint: {
                var ctx = getContext("2d");
                var viewW = width;
                var viewH = height;
                ctx.clearRect(0, 0, viewW, viewH);

                if (viewW <= 0 || viewH <= 0)
                    return;

                // 1. Dark Void for time < 0
                ctx.fillStyle = "#090909";
                ctx.fillRect(0, 0, viewW, viewH);

                // 2. Active Timeline Area (X >= 0)
                var zeroX = -root.horizontalOffset;
                if (zeroX < viewW) {
                    var activeLeft = Math.max(0, zeroX);
                    ctx.fillStyle = root.bgDark;
                    ctx.fillRect(activeLeft, 0, viewW - activeLeft, viewH);
                }

                // 3. Frame 0 Boundary Line
                // if (zeroX >= 0 && zeroX <= viewW) {
                //     ctx.fillStyle = "#383838";
                //     ctx.fillRect(zeroX, 0, 1, viewH);
                // }

                // 4. Compositor Cached Ranges (Blue Accent Bar)
                if (root.activeCompositor && root.activeCompositor.cachedRanges) {
                    var ranges = root.activeCompositor.cachedRanges;
                    ctx.fillStyle = "#2555D3";
                    ctx.strokeStyle = "#3B82F6";
                    ctx.lineWidth = 1;
                    for (var r = 0; r < ranges.length; ++r) {
                        var cr = ranges[r];
                        var rStart = (cr.start * root.zoomFactor) - root.horizontalOffset;
                        var rEnd = ((cr.end + 1) * root.zoomFactor) - root.horizontalOffset;
                        var rW = Math.max(3, rEnd - rStart);
                        if (rEnd >= 0 && rStart <= viewW) {
                            ctx.fillRect(Math.round(rStart), viewH - 4, Math.round(rW), 3);
                            ctx.strokeRect(Math.round(rStart) + 0.5, viewH - 4 + 0.5, Math.round(rW), 3);
                        }
                    }
                }

                // 5. Calculate visible step & tick range (ONLY FOR THE SCREEN VIEWPORT)
                var safeFps = root.fps > 0 ? root.fps : 30.0;
                var step = root.calculateStepFrames();
                var stepPixels = step * root.zoomFactor;

                var startFrame = Math.max(0, Math.floor(root.horizontalOffset / root.zoomFactor));
                var endFrame = Math.ceil((root.horizontalOffset + viewW) / root.zoomFactor);
                var alignStart = Math.floor(startFrame / step) * step;

                // Setup typography once
                ctx.font = "bold 9px monospace, sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";

                // Iterate only through the ~15-25 marks on screen
                for (var f = alignStart; f <= endFrame + step; f += step) {
                    var screenX = Math.round((f * root.zoomFactor) - root.horizontalOffset);

                    // Subdivisions (7 ticks if zoomed in enough)
                    if (stepPixels > 110) {
                        var subStep = stepPixels / 8;
                        for (var s = 1; s < 8; ++s) {
                            var sx = Math.round(screenX + s * subStep);
                            if (sx >= 0 && sx <= viewW) {
                                var subH = (s === 4) ? 8 : ((s === 2 || s === 6) ? 6 : 4);
                                ctx.fillStyle = (s === 4) ? "#666666" : ((s === 2 || s === 6) ? "#555555" : "#444444");
                                ctx.fillRect(sx, viewH - subH, 1, subH);
                            }
                        }
                    }

                    if (screenX < -50 || screenX > viewW + 100)
                        continue;

                    // Milestone Rod
                    ctx.fillStyle = root.themeAccent;
                    ctx.fillRect(screenX, viewH - 13, 1, 13);

                    // Time Text Badge
                    if (stepPixels > 24) {
                        var timeStr = root.formatRulerTime(f, safeFps);
                        var textMetrics = ctx.measureText(timeStr);
                        var textW = textMetrics.width;
                        var badgeW = Math.min(textW + 12, stepPixels - 4);
                        var badgeH = 14;
                        var badgeX = screenX;
                        var badgeY = viewH - 13 - badgeH + 3.5;

                        // Draw Badge Surface with rounded corners (top-left, top-right, bottom-right radius 6)
                        ctx.fillStyle = "#292929";
                        ctx.beginPath();
                        ctx.moveTo(badgeX, badgeY + badgeH);
                        ctx.lineTo(badgeX, badgeY + 6);
                        ctx.arcTo(badgeX, badgeY, badgeX + 6, badgeY, 6);
                        ctx.lineTo(badgeX + badgeW - 6, badgeY);
                        ctx.arcTo(badgeX + badgeW, badgeY, badgeX + badgeW, badgeY + 6, 6);
                        ctx.lineTo(badgeX + badgeW, badgeY + badgeH - 6);
                        ctx.arcTo(badgeX + badgeW, badgeY + badgeH, badgeX + badgeW - 6, badgeY + badgeH, 6);
                        ctx.lineTo(badgeX, badgeY + badgeH);
                        ctx.closePath();
                        ctx.fill();

                        // Centered Badge Text
                        ctx.fillStyle = "#ffffff";
                        ctx.fillText(timeStr, badgeX + (badgeW / 2), badgeY + (badgeH / 2));
                    }
                }

                // 6. Bottom Separator Line
                ctx.fillStyle = root.borderDark;
                ctx.fillRect(0, viewH - 1, viewW, 1);
            }

            Connections {
                target: root
                function onHorizontalOffsetChanged() {
                    rulerCanvas.requestPaint();
                }
                function onZoomFactorChanged() {
                    rulerCanvas.requestPaint();
                }
                function onFpsChanged() {
                    rulerCanvas.requestPaint();
                }
                function onHeaderWidthChanged() {
                    rulerCanvas.requestPaint();
                }
            }

            Connections {
                target: root.activeCompositor ? root.activeCompositor : null
                function onCachedRangesChanged() {
                    rulerCanvas.requestPaint();
                }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            property real lastPanX: 0

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
                if (mouse.button === Qt.MiddleButton) {
                    lastPanX = mouse.x;
                    return;
                }
                if (root.activePlaybackManager)
                    root.activePlaybackManager.startScrubbing();
                seekRuler(mouse, false);
            }

            onPositionChanged: function (mouse) {
                if (mouse.buttons & Qt.MiddleButton) {
                    var dx = mouse.x - lastPanX;
                    root.horizontalOffset -= dx;
                    lastPanX = mouse.x;
                    return;
                }
                if (pressed)
                    seekRuler(mouse, false);
            }

            onReleased: function (mouse) {
                if (mouse.button === Qt.LeftButton)
                    seekRuler(mouse, true);
            }

            // onWheel: wheel => {
            //     // Ctrl + Wheel: Smooth Zoom centered on mouse
            //     if ((wheel.modifiers & Qt.ControlModifier) && !(wheel.modifiers & Qt.ShiftModifier)) {
            //         var delta = wheel.angleDelta.y;
            //         if (delta !== 0) {
            //             var mouseCanvasX = wheel.x + root.horizontalOffset;
            //             var frameAtMouse = mouseCanvasX / root.zoomFactor;
            //             var zoomMultiplier = Math.pow(1.001, delta);
            //             var newZoom = Math.max(0.1, Math.min(50.0, root.zoomFactor * zoomMultiplier));
            //
            //             if (newZoom !== root.zoomFactor) {
            //                 root.zoomFactor = newZoom;
            //                 root.horizontalOffset = (frameAtMouse * newZoom) - wheel.x;
            //             }
            //         }
            //         wheel.accepted = true;
            //         return;
            //     }
            //
            //     // Shift + Wheel: Horizontal Pan
            //     if (wheel.modifiers & Qt.ShiftModifier) {
            //         var deltaH = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            //         root.horizontalOffset -= deltaH;
            //         wheel.accepted = true;
            //         return;
            //     }
            // }
        }
    }
}
