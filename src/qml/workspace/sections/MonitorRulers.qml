import QtQuick

Item {
    id: rulerRoot

    property real videoOriginX: 0
    property real videoOriginY: 0
    property real videoScale: 1.0
    property real nativeWidth: 1920
    property real nativeHeight: 1080

    property var snapFunction: null

    signal createGuideRequested(string orientation, real nativePos)

    readonly property int rulerThickness: 18

    property bool isDraggingTopGuide: false
    property real livePreviewY: 0
    property real liveNativeY: 0

    property bool isDraggingLeftGuide: false
    property real livePreviewX: 0
    property real liveNativeX: 0

    Rectangle {
        width: rulerRoot.rulerThickness
        height: rulerRoot.rulerThickness
        color: "#18181a"
        border.color: "#26262b"
        border.width: 1
        z: 30

        Text {
            anchors.centerIn: parent
            text: "px"
            color: "#666666"
            font.pixelSize: 9
            font.family: "monospace"
        }
    }

    // --- TOP HORIZONTAL RULER ---
    Rectangle {
        id: topRuler
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: rulerRoot.rulerThickness
        height: rulerRoot.rulerThickness
        color: "#141416"
        border.color: "#242428"
        border.width: 1
        clip: true
        z: 20

        Canvas {
            id: topCanvas
            anchors.fill: parent

            Connections {
                target: rulerRoot
                function onVideoOriginXChanged() {
                    topCanvas.requestPaint();
                }
                function onVideoScaleChanged() {
                    topCanvas.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var step = (rulerRoot.videoScale > 2.0) ? 50 : ((rulerRoot.videoScale > 0.6) ? 100 : 500);
                var subStep = step / 5;

                ctx.strokeStyle = "#404048";
                ctx.fillStyle = "#888890";
                ctx.font = "9px monospace";

                var startNative = Math.floor((-rulerRoot.videoOriginX / rulerRoot.videoScale) / subStep) * subStep;
                var endNative = startNative + (width / rulerRoot.videoScale) + step;

                for (var px = startNative; px <= endNative; px += subStep) {
                    var screenX = rulerRoot.videoOriginX + (px * rulerRoot.videoScale);
                    if (screenX < 0 || screenX > width)
                        continue;
                    var isMajor = (Math.round(px) % step === 0);
                    ctx.beginPath();
                    ctx.moveTo(screenX + 0.5, height - (isMajor ? 10 : 5));
                    ctx.lineTo(screenX + 0.5, height);
                    ctx.stroke();

                    if (isMajor) {
                        ctx.fillText(Math.round(px), screenX + 3, height - 8);
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SplitVCursor

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(rulerRoot, mouse.x, mouse.y);
                    if (pt.y > rulerRoot.rulerThickness) {
                        rulerRoot.isDraggingTopGuide = true;
                        var rawNativeY = (pt.y - rulerRoot.videoOriginY) / rulerRoot.videoScale;
                        var snappedY = rulerRoot.snapFunction ? rulerRoot.snapFunction("horizontal", rawNativeY, -1) : rawNativeY;
                        rulerRoot.liveNativeY = Math.round(snappedY);
                        rulerRoot.livePreviewY = rulerRoot.videoOriginY + (snappedY * rulerRoot.videoScale);
                    }
                }
            }

            onReleased: function (mouse) {
                if (rulerRoot.isDraggingTopGuide) {
                    rulerRoot.createGuideRequested("horizontal", rulerRoot.liveNativeY);
                }
                rulerRoot.isDraggingTopGuide = false;
            }
        }
    }

    // --- LEFT VERTICAL RULER ---
    Rectangle {
        id: leftRuler
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.topMargin: rulerRoot.rulerThickness
        width: rulerRoot.rulerThickness
        color: "#141416"
        border.color: "#242428"
        border.width: 1
        clip: true
        z: 20

        Canvas {
            id: leftCanvas
            anchors.fill: parent

            Connections {
                target: rulerRoot
                function onVideoOriginYChanged() {
                    leftCanvas.requestPaint();
                }
                function onVideoScaleChanged() {
                    leftCanvas.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var step = (rulerRoot.videoScale > 2.0) ? 50 : ((rulerRoot.videoScale > 0.6) ? 100 : 500);
                var subStep = step / 5;

                ctx.strokeStyle = "#404048";
                ctx.fillStyle = "#888890";
                ctx.font = "9px monospace";

                var startNative = Math.floor((-rulerRoot.videoOriginY / rulerRoot.videoScale) / subStep) * subStep;
                var endNative = startNative + (height / rulerRoot.videoScale) + step;

                for (var py = startNative; py <= endNative; py += subStep) {
                    var screenY = rulerRoot.videoOriginY + (py * rulerRoot.videoScale);
                    if (screenY < 0 || screenY > height)
                        continue;
                    var isMajor = (Math.round(py) % step === 0);
                    ctx.beginPath();
                    ctx.moveTo(width - (isMajor ? 10 : 5), screenY + 0.5);
                    ctx.lineTo(width, screenY + 0.5);
                    ctx.stroke();

                    if (isMajor) {
                        ctx.save();
                        ctx.translate(width - 8, screenY + 3);
                        ctx.rotate(-Math.PI / 2);
                        ctx.fillText(Math.round(py), 0, 0);
                        ctx.restore();
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SplitHCursor

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(rulerRoot, mouse.x, mouse.y);
                    if (pt.x > rulerRoot.rulerThickness) {
                        rulerRoot.isDraggingLeftGuide = true;
                        var rawNativeX = (pt.x - rulerRoot.videoOriginX) / rulerRoot.videoScale;
                        var snappedX = rulerRoot.snapFunction ? rulerRoot.snapFunction("vertical", rawNativeX, -1) : rawNativeX;
                        rulerRoot.liveNativeX = Math.round(snappedX);
                        rulerRoot.livePreviewX = rulerRoot.videoOriginX + (snappedX * rulerRoot.videoScale);
                    }
                }
            }

            onReleased: function (mouse) {
                if (rulerRoot.isDraggingLeftGuide) {
                    rulerRoot.createGuideRequested("vertical", rulerRoot.liveNativeX);
                }
                rulerRoot.isDraggingLeftGuide = false;
            }
        }
    }

    // --- LIVE DRAG-OUT HORIZONTAL PREVIEW LINE ---
    Item {
        visible: rulerRoot.isDraggingTopGuide
        x: rulerRoot.rulerThickness
        y: rulerRoot.livePreviewY
        width: rulerRoot.width - rulerRoot.rulerThickness
        height: 1
        z: 100

        Rectangle {
            anchors.fill: parent
            height: 1
            color: "#60a5fa"
        }

        Rectangle {
            x: 10
            y: -18
            width: previewBadgeH.implicitWidth + 8
            height: 16
            radius: 3
            color: "#18181b"
            border.color: "#3b82f6"
            border.width: 1

            Text {
                id: previewBadgeH
                anchors.centerIn: parent
                text: "Y: " + rulerRoot.liveNativeY + "px"
                color: "#ffffff"
                font.pixelSize: 10
                font.family: "Monospace"
            }
        }
    }

    // --- LIVE DRAG-OUT VERTICAL PREVIEW LINE ---
    Item {
        visible: rulerRoot.isDraggingLeftGuide
        x: rulerRoot.livePreviewX
        y: rulerRoot.rulerThickness
        width: 1
        height: rulerRoot.height - rulerRoot.rulerThickness
        z: 100

        Rectangle {
            anchors.fill: parent
            width: 1
            color: "#60a5fa"
        }

        Rectangle {
            x: 4
            y: 10
            width: previewBadgeV.implicitWidth + 8
            height: 16
            radius: 3
            color: "#18181b"
            border.color: "#3b82f6"
            border.width: 1

            Text {
                id: previewBadgeV
                anchors.centerIn: parent
                text: "X: " + rulerRoot.liveNativeX + "px"
                color: "#ffffff"
                font.pixelSize: 10
                font.family: "Monospace"
            }
        }
    }
}
