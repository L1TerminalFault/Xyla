import QtQuick
import QtQuick.Controls

Flickable {
    id: root

    property var treeRows: []
    property real zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real canvasContentWidth: 5000

    property var selectedKeyframes: []
    property bool isDraggingKeyframes: false
    property int dragDeltaFrames: 0

    signal keyframeSelectionRequested(string clipId, string propId, int frame, bool toggle)
    signal keyframeSingleSelected(string clipId, string propId, int frame)
    signal clearSelectionRequested
    signal moveKeyframesCommitted(int deltaFrames)
    signal contextMenuRequested(real globalX, real globalY, string clipId, string propId, int frame, bool hasKey)

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function frameToX(f) {
        return (f * zoomFactor) - horizontalOffset;
    }
    function xToFrame(xPx) {
        return Math.max(0, Math.round((xPx + horizontalOffset) / zoomFactor));
    }

    function isSelected(clipId, propId, frame) {
        for (var i = 0; i < selectedKeyframes.length; ++i) {
            var k = selectedKeyframes[i];
            if (k.clipId === clipId && k.propId === propId && k.frame === frame)
                return true;
        }
        return false;
    }

    Item {
        id: canvasContent
        width: root.canvasContentWidth * root.zoomFactor
        height: Math.max(root.height, root.treeRows.length * 24)

        // Background / Marquee
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            property real startX: 0
            property real startY: 0
            property bool isMarquee: false

            onPressed: mouse => {
                if (root.isDraggingKeyframes)
                    return;

                if (mouse.button === Qt.RightButton) {
                    var f = root.xToFrame(mouse.x);
                    var gPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                    root.contextMenuRequested(gPt.x, gPt.y, "", "", f, false);
                    return;
                }

                startX = mouse.x;
                startY = mouse.y;
                isMarquee = false;
            }

            onPositionChanged: mouse => {
                if (root.isDraggingKeyframes || (mouse.buttons & Qt.RightButton))
                    return;

                var dx = mouse.x - startX;
                var dy = mouse.y - startY;

                if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                    isMarquee = true;
                    if (!(mouse.modifiers & Qt.ShiftModifier))
                        root.clearSelectionRequested();
                }

                if (isMarquee) {
                    marqueeBox.x = Math.min(startX, mouse.x);
                    marqueeBox.y = Math.min(startY, mouse.y);
                    marqueeBox.width = Math.abs(dx);
                    marqueeBox.height = Math.abs(dy);
                    marqueeBox.visible = true;
                }
            }

            onReleased: mouse => {
                if (isMarquee) {
                    isMarquee = false;
                    marqueeBox.visible = false;

                    var minF = root.xToFrame(marqueeBox.x);
                    var maxF = root.xToFrame(marqueeBox.x + marqueeBox.width);
                    var minRow = Math.floor(marqueeBox.y / 24);
                    var maxRow = Math.floor((marqueeBox.y + marqueeBox.height) / 24);

                    for (var r = minRow; r <= maxRow && r < root.treeRows.length; ++r) {
                        var row = root.treeRows[r];
                        if (row.type === "channel") {
                            var kfs = row.keyframes || [];
                            for (var k = 0; k < kfs.length; ++k) {
                                var kf = kfs[k];
                                if (kf >= minF && kf <= maxF) {
                                    root.keyframeSelectionRequested(row.clipId, row.propId, kf, true);
                                }
                            }
                        }
                    }
                } else if (mouse.button === Qt.LeftButton) {
                    root.clearSelectionRequested();
                }
            }
        }

        Rectangle {
            id: marqueeBox
            color: "#203B82F6"
            border.color: "#3B82F6"
            border.width: 1
            visible: false
            z: 99
        }

        // Track Lanes & Diamonds
        Column {
            anchors.fill: parent

            Repeater {
                id: laneRepeater
                model: root.treeRows

                delegate: Rectangle {
                    id: lane
                    readonly property var laneData: modelData
                    width: canvasContent.width
                    height: 24
                    color: index % 2 === 0 ? "#141414" : "#121212"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#1c1c1c"
                    }

                    Repeater {
                        model: lane.laneData.keyframes || []

                        delegate: Item {
                            id: kfDelegate
                            readonly property int kfFrame: Math.round(Number(modelData))
                            readonly property bool isKeySelected: root.isSelected(lane.laneData.clipId, lane.laneData.propId, kfFrame)

                            x: root.frameToX(kfFrame + (isKeySelected && root.isDraggingKeyframes ? root.dragDeltaFrames : 0)) - 6
                            y: 6
                            width: 12
                            height: 12

                            Rectangle {
                                anchors.centerIn: parent
                                width: kfDelegate.isKeySelected ? 9 : 8
                                height: kfDelegate.isKeySelected ? 9 : 8
                                rotation: 45
                                color: kfDelegate.isKeySelected ? "#F59E0B" : (lane.laneData.type === "channel" ? (lane.laneData.color || "#3B82F6") : "transparent")
                                border.color: kfDelegate.isKeySelected ? "#FEF08A" : (lane.laneData.type === "channel" ? "#93C5FD" : "#FFFFFF")
                                border.width: lane.laneData.type === "channel" ? 1 : 1.5
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.SizeHorCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: true

                                property real startCanvasX: 0

                                onPressed: mouse => {
                                    mouse.accepted = true;

                                    if (mouse.button === Qt.RightButton) {
                                        var gPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        root.contextMenuRequested(gPt.x, gPt.y, lane.laneData.clipId, lane.laneData.propId, kfDelegate.kfFrame, true);
                                        return;
                                    }

                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        root.keyframeSelectionRequested(lane.laneData.clipId, lane.laneData.propId, kfDelegate.kfFrame, true);
                                    } else if (!kfDelegate.isKeySelected) {
                                        root.keyframeSingleSelected(lane.laneData.clipId, lane.laneData.propId, kfDelegate.kfFrame);
                                    }

                                    root.isDraggingKeyframes = true;
                                    root.dragDeltaFrames = 0;
                                    startCanvasX = kfDelegate.mapToItem(canvasContent, mouse.x, 0).x;
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed || !(mouse.buttons & Qt.LeftButton))
                                        return;
                                    var currentCanvasX = kfDelegate.mapToItem(canvasContent, mouse.x, 0).x;
                                    var delta = Math.round((currentCanvasX - startCanvasX) / root.zoomFactor);
                                    root.dragDeltaFrames = delta;
                                }

                                onReleased: mouse => {
                                    if (root.isDraggingKeyframes) {
                                        var finalDelta = root.dragDeltaFrames;
                                        root.isDraggingKeyframes = false;
                                        root.dragDeltaFrames = 0;
                                        if (finalDelta !== 0)
                                            root.moveKeyframesCommitted(finalDelta);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
