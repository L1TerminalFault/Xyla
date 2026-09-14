import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// NOTE: Component Finalized (Not Refactored)

/*
 *
 *
 *
 *
 */

Rectangle {
    id: minimapHUD

    property var root: null
    property var canvasContainer: null
    property var dagCanvas: null

    property real minWidth: 140
    property real maxWidth: 450
    property real minHeight: 90
    property real maxHeight: 300

    visible: root ? root.showMinimap : false

    property string dockedCorner: "bottom-right"
    property bool isDraggingHUD: false
    property bool isResizingHUD: false

    width: 190
    height: 130

    y: parent ? (parent.height - height - 8) : 0

    x: parent ? ((dockedCorner === "bottom-left") ? 8 : (parent.width - width - 8)) : 0

    Behavior on x {
        enabled: !(minimapHUD.isDraggingHUD || minimapHUD.isResizingHUD)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    radius: 8
    color: "#181818"
    border.color: hudHoverHandler.hovered ? "#454545" : "#303030"
    border.width: 0.5
    z: 105
    clip: true

    opacity: (hudHoverHandler.hovered || resizeMouseArea.pressed || panMouseArea.pressed) ? 1.0 : 0.45

    Behavior on opacity {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    HoverHandler {
        id: hudHoverHandler
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#90000000"
        shadowBlur: 0.6
        shadowVerticalOffset: 4
    }

    Item {
        id: minimapScene
        anchors.fill: parent
        clip: true

        // Active Camera Frustum in World Space
        readonly property real camLeft: canvasContainer ? (-canvasContainer.width / 2 - (root ? root.panX : 0)) / (root ? root.zoomLevel : 1) : 0
        readonly property real camRight: canvasContainer ? (canvasContainer.width / 2 - (root ? root.panX : 0)) / (root ? root.zoomLevel : 1) : 0
        readonly property real camTop: canvasContainer ? (-canvasContainer.height / 2 - (root ? root.panY : 0)) / (root ? root.zoomLevel : 1) : 0
        readonly property real camBottom: canvasContainer ? (canvasContainer.height / 2 - (root ? root.panY : 0)) / (root ? root.zoomLevel : 1) : 0

        // Dynamic Combined Bounds (Encloses all nodes + current camera view)
        property real minX: camLeft
        property real maxX: camRight
        property real minY: camTop
        property real maxY: camBottom

        function updateBounds() {
            var bMinX = camLeft, bMaxX = camRight;
            var bMinY = camTop, bMaxY = camBottom;
            if (root && root.nodeList) {
                for (var i = 0; i < root.nodeList.length; ++i) {
                    var nId = root.nodeList[i].id;
                    var pos = root.getNodeCenterPos(nId, root.nodeList[i].x, root.nodeList[i].y);
                    var exactH = root.getNodeRealHeight(nId);
                    var exactW = 180;

                    bMinX = Math.min(bMinX, pos.x - exactW / 2);
                    bMaxX = Math.max(bMaxX, pos.x + exactW / 2);
                    bMinY = Math.min(bMinY, pos.y - exactH / 2);
                    bMaxY = Math.max(bMaxY, pos.y + exactH / 2);
                }
            }
            var spanX = Math.max(400, bMaxX - bMinX);
            var spanY = Math.max(300, bMaxY - bMinY);
            minX = bMinX - spanX * 0.04;
            maxX = bMaxX + spanX * 0.04;
            minY = bMinY - spanY * 0.04;
            maxY = bMaxY + spanY * 0.04;
        }

        onCamLeftChanged: updateBounds()
        onCamTopChanged: updateBounds()
        onCamRightChanged: updateBounds()
        onCamBottomChanged: updateBounds()

        // World-to-Minimap coordinate converters
        function mapWsToMinimapX(wsX) {
            var rangeX = maxX - minX;
            if (rangeX <= 0)
                return 0;
            return (wsX - minX) / rangeX * minimapScene.width;
        }

        function mapWsToMinimapY(wsY) {
            var rangeY = maxY - minY;
            if (rangeY <= 0)
                return 0;
            return (wsY - minY) / rangeY * minimapScene.height;
        }

        // Central Origin Axes in Minimap (Dotted)
        Shape {
            anchors.fill: parent
            z: 1
            ShapePath {
                strokeColor: "#2a2a2a"
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]
                startX: minimapScene.mapWsToMinimapX(0)
                startY: 0
                PathLine {
                    x: minimapScene.mapWsToMinimapX(0)
                    y: minimapScene.height
                }
            }
            ShapePath {
                strokeColor: "#2a2a2a"
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]
                startX: 0
                startY: minimapScene.mapWsToMinimapY(0)
                PathLine {
                    x: minimapScene.width
                    y: minimapScene.mapWsToMinimapY(0)
                }
            }
        }

        // Node Cards in Minimap
        Repeater {
            model: root ? root.nodeList : null
            delegate: Rectangle {
                property var pos: root ? root.getNodeCenterPos(modelData.id, modelData.x, modelData.y) : { x: 0, y: 0 }
                readonly property real realNodeH: root.getNodeRealHeight(modelData.id)

                readonly property real scaleFactorX: minimapScene.width / Math.max(1, minimapScene.maxX - minimapScene.minX)
                readonly property real scaleFactorY: minimapScene.height / Math.max(1, minimapScene.maxY - minimapScene.minY)

                readonly property real cardMiniW: Math.max(4, 180 * scaleFactorX)
                readonly property real cardMiniH: Math.max(3, realNodeH * scaleFactorY)

                x: minimapScene.mapWsToMinimapX(pos.x) - cardMiniW / 2
                y: minimapScene.mapWsToMinimapY(pos.y) - cardMiniH / 2
                width: cardMiniW
                height: cardMiniH
                radius: 1.5
                color: root && root.selectedNodeIds.indexOf(modelData.id) !== -1 ? "#3B82F6" : "#444444"
                border.color: "#181818"
                border.width: 0.5
                z: 2
            }
        }

        // Viewport Frustum Box Frame
        Rectangle {
            z: 3
            x: minimapScene.mapWsToMinimapX(minimapScene.camLeft)
            y: minimapScene.mapWsToMinimapY(minimapScene.camTop)
            width: Math.max(8, (minimapScene.camRight - minimapScene.camLeft) / Math.max(1, minimapScene.maxX - minimapScene.minX) * minimapScene.width)
            height: Math.max(8, (minimapScene.camBottom - minimapScene.camTop) / Math.max(1, minimapScene.maxY - minimapScene.minY) * minimapScene.height)
            radius: 2
            color: "#15ffffff"
            border.color: "#A560A5FA"
            border.width: 0.5
        }

        // Mouse interaction: Node-centering & Free Space camera dragging
        MouseArea {
            id: panMouseArea
            anchors.fill: parent
            z: 4
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property bool hitNodePressed: false

            function getNodeAt(mx, my) {
                if (!root || !root.nodeList)
                    return null;
                var scaleX = minimapScene.width / Math.max(1, minimapScene.maxX - minimapScene.minX);
                var scaleY = minimapScene.height / Math.max(1, minimapScene.maxY - minimapScene.minY);

                for (var i = root.nodeList.length - 1; i >= 0; --i) {
                    var node = root.nodeList[i];
                    var pos = root.getNodeCenterPos(node.id, node.x, node.y);
                    var realH = root.getNodeRealHeight(node.id);

                    var nx = minimapScene.mapWsToMinimapX(pos.x);
                    var ny = minimapScene.mapWsToMinimapY(pos.y);

                    var hitW = Math.max(8, 180 * scaleX);
                    var hitH = Math.max(8, realH * scaleY);

                    if (mx >= nx - hitW / 2 && mx <= nx + hitW / 2 &&
                        my >= ny - hitH / 2 && my <= ny + hitH / 2) {
                        return { item: node, pos: pos };
                    }
                }
                return null;
            }

            function centerOnWorldPos(wsX, wsY) {
                if (root) {
                    root.panX = -wsX * root.zoomLevel;
                    root.panY = -wsY * root.zoomLevel;
                }
                if (dagCanvas) {
                    dagCanvas.requestPaint();
                }
            }

            onPressed: function (mouse) {
                var clampedX = Math.max(0, Math.min(mouse.x, minimapScene.width));
                var clampedY = Math.max(0, Math.min(mouse.y, minimapScene.height));

                var hit = getNodeAt(clampedX, clampedY);

                if (hit) {
                    hitNodePressed = true;
                    centerOnWorldPos(hit.pos.x, hit.pos.y);
                    if (root && root.selectedNodeIds !== undefined) {
                        root.selectedNodeIds = [hit.item.id];
                    }
                } else {
                    hitNodePressed = false;
                    var clickWsX = minimapScene.minX + (clampedX / minimapScene.width) * (minimapScene.maxX - minimapScene.minX);
                    var clickWsY = minimapScene.minY + (clampedY / minimapScene.height) * (minimapScene.maxY - minimapScene.minY);
                    centerOnWorldPos(clickWsX, clickWsY);
                }
                mouse.accepted = true;
            }

            onPositionChanged: function (mouse) {
                if (pressed && !hitNodePressed) {
                    var clampedX = Math.max(0, Math.min(mouse.x, minimapScene.width));
                    var clampedY = Math.max(0, Math.min(mouse.y, minimapScene.height));
                    var clickWsX = minimapScene.minX + (clampedX / minimapScene.width) * (minimapScene.maxX - minimapScene.minX);
                    var clickWsY = minimapScene.minY + (clampedY / minimapScene.height) * (minimapScene.maxY - minimapScene.minY);
                    centerOnWorldPos(clickWsX, clickWsY);
                }
                mouse.accepted = true;
            }

            onReleased: function (mouse) {
                hitNodePressed = false;
                mouse.accepted = true;
            }
        }
    }

    // --- Interactive Top-Left Resize Handle ---
    Item {
        id: resizeHandle
        width: 16
        height: 16
        y: 0

        x: minimapHUD.dockedCorner === "bottom-right" ? 0 : (minimapHUD.width - width)
        z: 10

        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: resizeMouseArea.containsMouse || resizeMouseArea.pressed ? "#60A5FA" : "#555555"
                strokeWidth: 1.2
                startX: minimapHUD.dockedCorner === "bottom-right" ? 3 : 13
                startY: 11
                PathLine {
                    x: minimapHUD.dockedCorner === "bottom-right" ? 11 : 5
                    y: 3
                }
            }
            ShapePath {
                strokeColor: resizeMouseArea.containsMouse || resizeMouseArea.pressed ? "#60A5FA" : "#555555"
                strokeWidth: 1.2
                startX: minimapHUD.dockedCorner === "bottom-right" ? 3 : 13
                startY: 7
                PathLine {
                    x: minimapHUD.dockedCorner === "bottom-right" ? 7 : 9
                    y: 3
                }
            }
        }

        MouseArea {
            id: resizeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: minimapHUD.dockedCorner === "bottom-right" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

            property real startGlobalX: 0
            property real startGlobalY: 0
            property real startW: 0
            property real startH: 0

            onPressed: function (mouse) {
                isResizingHUD = true;
                var g = mapToItem(minimapHUD.parent, mouse.x, mouse.y);
                startGlobalX = g.x;
                startGlobalY = g.y;
                startW = minimapHUD.width;
                startH = minimapHUD.height;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var g = mapToItem(minimapHUD.parent, mouse.x, mouse.y);
                    var deltaX = g.x - startGlobalX;
                    var deltaY = g.y - startGlobalY;

                    // When docked on right, dragging left (negative deltaX) expands width
                    // When docked on left, dragging right (positive deltaX) expands width
                    var newW = (minimapHUD.dockedCorner === "bottom-right")
                        ? (startW - deltaX)
                        : (startW + deltaX);
                    var newH = startH - deltaY; // Dragging up (negative deltaY) expands height

                    minimapHUD.width = Math.max(minimapHUD.minWidth, Math.min(minimapHUD.maxWidth, newW));
                    minimapHUD.height = Math.max(minimapHUD.minHeight, Math.min(minimapHUD.maxHeight, newH));
                }
            }

            onReleased: {
              isResizingHUD = false;
            }
        }
    }

    // --- Interactive Move / Reposition Pill (3 Horizontal Dots) ---
    Item {
        id: moveHandle
        width: 36
        height: 10
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20

        // 3 Horizontal Dots Indicator
        Row {
            anchors.centerIn: parent
            spacing: 3.5

            Repeater {
                model: 4
                delegate: Rectangle {
                    width: 1.5
                    height: 1.5
                    radius: 0.5
                    color: moveMouseArea.containsMouse || moveMouseArea.pressed ? "#60A5FA" : "#666666"
                }
            }
        }

        MouseArea {
            id: moveMouseArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real startMouseGlobalX: 0
            property real startHUDX: 0

            onPressed: function(mouse) {
                var gPt = mapToItem(minimapHUD.parent, mouse.x, mouse.y);
                startMouseGlobalX = gPt.x;
                startHUDX = minimapHUD.x;
                minimapHUD.isDraggingHUD = true;
            }

            onPositionChanged: function(mouse) {
                if (pressed) {
                    var gPt = mapToItem(minimapHUD.parent, mouse.x, mouse.y);
                    var deltaX = gPt.x - startMouseGlobalX;
                    var newX = startHUDX + deltaX;
                    // Clamp inside parent
                    minimapHUD.x = Math.max(8, Math.min(minimapHUD.parent.width - minimapHUD.width - 8, newX));
                }
            }

            onReleased: function(mouse) {
                minimapHUD.isDraggingHUD = false;

                // Determine closer side
                var parentMid = minimapHUD.parent.width / 2;
                var hudMid = minimapHUD.x + (minimapHUD.width / 2);
                var isLeft = (hudMid < parentMid);

                minimapHUD.dockedCorner = isLeft ? "bottom-left" : "bottom-right";

                // Direct assignment triggers Behavior on x to glide smoothly to corner!
                if (isLeft) {
                    minimapHUD.x = 8;
                } else {
                    minimapHUD.x = minimapHUD.parent.width - minimapHUD.width - 8;
                }
            }
        }
    }
}
