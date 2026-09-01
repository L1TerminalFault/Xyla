import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"

Item {
    id: root

    readonly property color bgDark: "#1a1a1a"

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property string activeSelectedClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var selectedClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    property var nodeList: (selectedClipData && selectedClipData.nodes) ? selectedClipData.nodes : []
    property var linkList: (selectedClipData && selectedClipData.links) ? selectedClipData.links : []

    property real zoomLevel: 1.0
    property real panX: 0.0
    property real panY: 0.0
    property var nodePositions: ({})

    // Multi-Selection State
    property var selectedNodeIds: []
    property bool isBoxSelecting: false
    property real boxStartX: 0
    property real boxStartY: 0
    property real boxCurrentX: 0
    property real boxCurrentY: 0

    // Interactive Wire State
    property bool isConnectingWire: false
    property string wireFromNodeId: ""
    property string wireFromSocketId: ""
    property real wireMouseX: 0
    property real wireMouseY: 0

    // Cursor tracking for Tab/Space popup
    property real currentMouseScreenX: 0
    property real currentMouseScreenY: 0

    // Alt-Key Wire Break State
    property bool isAltPressed: false

    function getNodeCenterPos(nodeId, defaultX, defaultY) {
        if (nodePositions[nodeId] !== undefined) {
            return nodePositions[nodeId];
        }
        return {
            x: Number(defaultX || 0),
            y: Number(defaultY || 0)
        };
    }

    function calculatePinGlobalPos(nodeId, socketId, isOutput) {
        var nData = null;
        for (var i = 0; i < nodeList.length; ++i) {
            if (nodeList[i].id === nodeId) {
                nData = nodeList[i];
                break;
            }
        }
        var center = getNodeCenterPos(nodeId, nData ? nData.x : 0, nData ? nData.y : 0);
        var w = 184;
        var inputCount = (nData && nData.inputs) ? nData.inputs.length : 0;
        var outputCount = (nData && nData.outputs) ? nData.outputs.length : 0;
        var total = inputCount + outputCount;
        var h = 32 + (total * 30) + 12;

        var px = center.x + (isOutput ? (w / 2) : (-w / 2));
        var topY = center.y - h / 2;

        var sIndex = 0;
        if (isOutput) {
            var outIdx = 0;
            if (nData && nData.outputs) {
                for (var j = 0; j < nData.outputs.length; ++j) {
                    if (nData.outputs[j].id === socketId) {
                        outIdx = j;
                        break;
                    }
                }
            }
            sIndex = inputCount + outIdx;
        } else {
            if (nData && nData.inputs) {
                for (var k = 0; k < nData.inputs.length; ++k) {
                    if (nData.inputs[k].id === socketId) {
                        sIndex = k;
                        break;
                    }
                }
            }
        }

        var py = topY + 44 + (sIndex * 28);
        return {
            x: px,
            y: py
        };
    }

    function findTargetInputPinAt(wsX, wsY) {
        var threshold = 32.0 / Math.max(0.1, root.zoomLevel);
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.id === root.wireFromNodeId)
                continue;
            if (!n.inputs)
                continue;
            for (var j = 0; j < n.inputs.length; ++j) {
                var inSock = n.inputs[j];
                var pinPos = calculatePinGlobalPos(n.id, inSock.id, false);
                var dx = wsX - pinPos.x;
                var dy = wsY - pinPos.y;
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist <= threshold) {
                    return {
                        nodeId: n.id,
                        socketId: inSock.id,
                        typeName: inSock.dataTypeName
                    };
                }
            }
        }
        return null;
    }

    function openSearchPopupAtWorkspace(wsX, wsY, fromNode, fromSocket) {
        var canvasPt = graphWorkspace.mapToItem(canvasContainer, wsX, wsY);
        searchPopup.x = Math.max(8, Math.min(canvasContainer.width - searchPopup.width - 8, canvasPt.x));
        searchPopup.y = Math.max(8, Math.min(canvasContainer.height - searchPopup.height - 8, canvasPt.y));
        searchPopup.spawnX = wsX;
        searchPopup.spawnY = wsY;
        searchPopup.linkFromNodeId = fromNode;
        searchPopup.linkFromSocketId = fromSocket;
        searchPopup.open();
    }

    function isNodeSelected(nodeId) {
        return selectedNodeIds.indexOf(nodeId) !== -1;
    }

    function selectSingleNode(nodeId) {
        selectedNodeIds = [nodeId];
    }

    function toggleNodeSelection(nodeId) {
        var idx = selectedNodeIds.indexOf(nodeId);
        var copy = selectedNodeIds.slice();
        if (idx === -1) {
            copy.push(nodeId);
        } else {
            copy.splice(idx, 1);
        }
        selectedNodeIds = copy;
    }

    function deleteSelectedNodes() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            root.activeTimelineModel.removeNode(root.activeSelectedClipId, selectedNodeIds[i]);
        }
        selectedNodeIds = [];
    }

    focus: true
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Alt) {
            root.isAltPressed = true;
        } else if (event.key === Qt.Key_Escape) {
            root.isConnectingWire = false;
            searchPopup.close();
            selectedNodeIds = [];
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.deleteSelectedNodes();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Space) {
            var wsPt = mapToItem(graphWorkspace, currentMouseScreenX, currentMouseScreenY);
            root.openSearchPopupAtWorkspace(wsPt.x, wsPt.y, "", "");
            event.accepted = true;
        }
    }

    Keys.onReleased: function (event) {
        if (event.key === Qt.Key_Alt) {
            root.isAltPressed = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar Header
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: root.bgDark

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#2d2d2d"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                // Centered Clean Clip Name Pill Badge
                Rectangle {
                    Layout.preferredWidth: Math.min(240, Math.max(120, clipNameText.implicitWidth + 24))
                    Layout.preferredHeight: 24
                    color: "#121212"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 4

                    Text {
                        id: clipNameText
                        anchors.centerIn: parent
                        text: root.selectedClipData ? root.selectedClipData.name : "No Clip Selected"
                        color: root.selectedClipData ? "#ffffff" : "#666666"
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideMiddle
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.isAltPressed ? "Alt: Click wire to cut" : "Tab: Add Node | Alt+Click: Cut | Shift+Drag: Box Select"
                    color: root.isAltPressed ? "#EF4444" : "#555555"
                    font.pixelSize: 11
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/plus.svg"
                    primary: true
                    onClicked: {
                        var pt = mapToItem(graphWorkspace, canvasContainer.width / 2, canvasContainer.height / 2);
                        root.openSearchPopupAtWorkspace(pt.x, pt.y, "", "");
                    }
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/rotate.svg"
                    onClicked: {
                        root.zoomLevel = 1.0;
                        root.panX = 0.0;
                        root.panY = 0.0;
                        root.nodePositions = ({});
                        dagCanvas.requestPaint();
                    }
                }
            }
        }

        // Workspace Canvas Area
        Item {
            id: canvasContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Professional Two-Tier Hierarchical Grid
            Canvas {
                id: dagCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.bgDark;
                    ctx.fillRect(0, 0, width, height);

                    ctx.save();
                    ctx.translate(width / 2 + root.panX, height / 2 + root.panY);
                    ctx.scale(root.zoomLevel, root.zoomLevel);

                    var minorStep = 24;
                    var majorStep = 120;

                    var startX = -width / (2 * root.zoomLevel) - root.panX;
                    var endX = width / (2 * root.zoomLevel) - root.panX;
                    var startY = -height / (2 * root.zoomLevel) - root.panY;
                    var endY = height / (2 * root.zoomLevel) - root.panY;

                    // 1. Minor Sub-Grid
                    ctx.lineWidth = 1 / root.zoomLevel;
                    ctx.strokeStyle = "#1a1a20";
                    ctx.beginPath();
                    for (var x = Math.floor(startX / minorStep) * minorStep; x < endX; x += minorStep) {
                        ctx.moveTo(x, startY);
                        ctx.lineTo(x, endY);
                    }
                    for (var y = Math.floor(startY / minorStep) * minorStep; y < endY; y += minorStep) {
                        ctx.moveTo(startX, y);
                        ctx.lineTo(endX, y);
                    }
                    ctx.stroke();

                    // 2. Major Grid
                    ctx.lineWidth = 1.2 / root.zoomLevel;
                    ctx.strokeStyle = "#252530";
                    ctx.beginPath();
                    for (var mx = Math.floor(startX / majorStep) * majorStep; mx < endX; mx += majorStep) {
                        ctx.moveTo(mx, startY);
                        ctx.lineTo(mx, endY);
                    }
                    for (var my = Math.floor(startY / majorStep) * majorStep; my < endY; my += majorStep) {
                        ctx.moveTo(startX, my);
                        ctx.lineTo(endX, my);
                    }
                    ctx.stroke();

                    // 3. Center Origin Axes
                    ctx.strokeStyle = "#383848";
                    ctx.lineWidth = 1.5 / root.zoomLevel;
                    ctx.beginPath();
                    ctx.moveTo(startX, 0);
                    ctx.lineTo(endX, 0);
                    ctx.moveTo(0, startY);
                    ctx.lineTo(0, endY);
                    ctx.stroke();

                    ctx.restore();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            MouseArea {
                id: canvasPanArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: root.isAltPressed ? Qt.CrossCursor : (pressed ? (root.isBoxSelecting ? Qt.CrossCursor : Qt.ClosedHandCursor) : Qt.ArrowCursor)

                property real startX: 0
                property real startY: 0

                onPressed: function (mouse) {
                    root.forceActiveFocus();
                    startX = mouse.x - root.panX;
                    startY = mouse.y - root.panY;

                    if (mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.ShiftModifier)) {
                        // Start Rubber-Band Marquee Selection
                        root.isBoxSelecting = true;
                        var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.boxStartX = wsPt.x;
                        root.boxStartY = wsPt.y;
                        root.boxCurrentX = wsPt.x;
                        root.boxCurrentY = wsPt.y;
                    } else if (mouse.button === Qt.LeftButton) {
                        // Deselect on empty click
                        root.selectedNodeIds = [];
                    }
                }

                onPositionChanged: function (mouse) {
                    root.currentMouseScreenX = mouse.x;
                    root.currentMouseScreenY = mouse.y;

                    if (root.isBoxSelecting) {
                        var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.boxCurrentX = wsPt.x;
                        root.boxCurrentY = wsPt.y;
                    } else if (pressed && !root.isConnectingWire && mouse.buttons !== Qt.RightButton) {
                        root.panX = mouse.x - startX;
                        root.panY = mouse.y - startY;
                        dagCanvas.requestPaint();
                    }
                }

                onReleased: function (mouse) {
                    if (root.isBoxSelecting) {
                        // Select nodes intersecting marquee box
                        var minX = Math.min(root.boxStartX, root.boxCurrentX);
                        var maxX = Math.max(root.boxStartX, root.boxCurrentX);
                        var minY = Math.min(root.boxStartY, root.boxCurrentY);
                        var maxY = Math.max(root.boxStartY, root.boxCurrentY);

                        var newlySelected = [];
                        for (var i = 0; i < root.nodeList.length; ++i) {
                            var n = root.nodeList[i];
                            var pos = root.getNodeCenterPos(n.id, n.x, n.y);
                            if (pos.x >= minX - 90 && pos.x <= maxX + 90 && pos.y >= minY - 60 && pos.y <= maxY + 60) {
                                newlySelected.push(n.id);
                            }
                        }
                        root.selectedNodeIds = newlySelected;
                        root.isBoxSelecting = false;
                        return;
                    }

                    if (mouse.button === Qt.RightButton) {
                        var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.openSearchPopupAtWorkspace(wsPt.x, wsPt.y, "", "");
                    }
                }

                onWheel: function (wheel) {
                    var factor = wheel.angleDelta.y > 0 ? 1.1 : 0.9;
                    root.zoomLevel = Math.max(0.2, Math.min(3.0, root.zoomLevel * factor));
                    dagCanvas.requestPaint();
                }
            }

            Item {
                id: graphWorkspace
                x: canvasContainer.width / 2 + root.panX
                y: canvasContainer.height / 2 + root.panY
                scale: root.zoomLevel

                // Rubber-Band Marquee Selection Box
                Rectangle {
                    visible: root.isBoxSelecting
                    x: Math.min(root.boxStartX, root.boxCurrentX)
                    y: Math.min(root.boxStartY, root.boxCurrentY)
                    width: Math.abs(root.boxCurrentX - root.boxStartX)
                    height: Math.abs(root.boxCurrentY - root.boxStartY)
                    color: "#153B82F6"
                    border.color: "#3B82F6"
                    border.width: 1
                    z: 90
                }

                // Render Connected Wires
                Repeater {
                    model: root.linkList

                    delegate: Item {
                        id: linkDelegate

                        property var p1: root.calculatePinGlobalPos(modelData.fromNodeId, modelData.fromSocketId, true)
                        property var p2: root.calculatePinGlobalPos(modelData.toNodeId, modelData.toSocketId, false)

                        x: Math.min(p1.x, p2.x) - 14
                        y: Math.min(p1.y, p2.y) - 14
                        width: Math.abs(p2.x - p1.x) + 28
                        height: Math.abs(p2.y - p1.y) + 28

                        readonly property real localStartX: p1.x - x
                        readonly property real localStartY: p1.y - y
                        readonly property real localEndX: p2.x - x
                        readonly property real localEndY: p2.y - y

                        Shape {
                            anchors.fill: parent

                            // Hitbox Stroke
                            ShapePath {
                                strokeColor: "transparent"
                                strokeWidth: 28
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                startX: linkDelegate.localStartX
                                startY: linkDelegate.localStartY

                                PathCubic {
                                    x: linkDelegate.localEndX
                                    y: linkDelegate.localEndY
                                    control1X: linkDelegate.localStartX + Math.max(40, Math.abs(linkDelegate.localEndX - linkDelegate.localStartX) * 0.5)
                                    control1Y: linkDelegate.localStartY
                                    control2X: linkDelegate.localEndX - Math.max(40, Math.abs(linkDelegate.localEndX - linkDelegate.localStartX) * 0.5)
                                    control2Y: linkDelegate.localEndY
                                }
                            }

                            // Visible Wire
                            ShapePath {
                                strokeColor: (wireHoverArea.containsMouse && root.isAltPressed) ? "#EF4444" : (wireHoverArea.containsMouse ? "#60A5FA" : "#3B82F6")
                                strokeWidth: wireHoverArea.containsMouse ? 3 : 2
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                startX: linkDelegate.localStartX
                                startY: linkDelegate.localStartY

                                PathCubic {
                                    x: linkDelegate.localEndX
                                    y: linkDelegate.localEndY
                                    control1X: linkDelegate.localStartX + Math.max(40, Math.abs(linkDelegate.localEndX - linkDelegate.localStartX) * 0.5)
                                    control1Y: linkDelegate.localStartY
                                    control2X: linkDelegate.localEndX - Math.max(40, Math.abs(linkDelegate.localEndX - linkDelegate.localStartX) * 0.5)
                                    control2Y: linkDelegate.localEndY
                                }
                            }
                        }

                        MouseArea {
                            id: wireHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.isAltPressed ? Qt.CrossCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: {
                                if (root.isAltPressed && root.activeTimelineModel) {
                                    root.activeTimelineModel.disconnectSockets(root.activeSelectedClipId, modelData.fromNodeId, modelData.fromSocketId, modelData.toNodeId, modelData.toSocketId);
                                }
                            }
                        }
                    }
                }

                // Interactive Dragging Wire
                Shape {
                    anchors.fill: parent
                    visible: root.isConnectingWire

                    ShapePath {
                        id: pendingPath
                        strokeColor: "#60A5FA"
                        strokeWidth: 2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [4, 4]
                        fillColor: "transparent"

                        startX: 0
                        startY: 0

                        PathCubic {
                            x: root.wireMouseX
                            y: root.wireMouseY
                            control1X: pendingPath.startX + Math.max(40, Math.abs(root.wireMouseX - pendingPath.startX) * 0.5)
                            control1Y: pendingPath.startY
                            control2X: root.wireMouseX - Math.max(40, Math.abs(root.wireMouseX - pendingPath.startX) * 0.5)
                            control2Y: root.wireMouseY
                        }
                    }
                }

                // Render Node Cards
                Repeater {
                    model: root.nodeList

                    delegate: XylaNodeCard {
                        id: card
                        nodeData: modelData
                        activeModel: root.activeTimelineModel
                        activeClipId: root.activeSelectedClipId
                        isSelected: root.isNodeSelected(modelData.id)

                        property var initialPos: root.getNodeCenterPos(modelData.id, modelData.x, modelData.y)
                        x: initialPos.x - width / 2
                        y: initialPos.y - height / 2

                        onNodeSelected: function (nodeId, isShift) {
                            if (isShift) {
                                root.toggleNodeSelection(nodeId);
                            } else {
                                if (!root.isNodeSelected(nodeId)) {
                                    root.selectSingleNode(nodeId);
                                }
                            }
                        }

                        onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                            root.isConnectingWire = true;
                            root.wireFromNodeId = nodeId;
                            root.wireFromSocketId = socketId;
                            pendingPath.startX = pinX;
                            pendingPath.startY = pinY;
                            root.wireMouseX = pinX;
                            root.wireMouseY = pinY;
                        }

                        onUpdateWireDrag: function (globalX, globalY) {
                            if (root.isConnectingWire) {
                                root.wireMouseX = globalX;
                                root.wireMouseY = globalY;
                            }
                        }

                        onEndConnectingWire: function (globalX, globalY) {
                            if (!root.isConnectingWire)
                                return;
                            var targetPin = root.findTargetInputPinAt(globalX, globalY);
                            if (targetPin && root.activeTimelineModel) {
                                root.activeTimelineModel.connectSockets(root.activeSelectedClipId, root.wireFromNodeId, root.wireFromSocketId, targetPin.nodeId, targetPin.socketId);
                            } else {
                                root.openSearchPopupAtWorkspace(globalX, globalY, root.wireFromNodeId, root.wireFromSocketId);
                            }
                            root.isConnectingWire = false;
                        }

                        onDragMovedDelta: function (dx, dy) {
                            // Move all selected nodes together
                            var temp = Object.assign({}, root.nodePositions);
                            for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                                var sId = root.selectedNodeIds[i];
                                var cur = root.getNodeCenterPos(sId, 0, 0);
                                temp[sId] = {
                                    x: cur.x + dx,
                                    y: cur.y + dy
                                };
                            }
                            root.nodePositions = temp;
                        }

                        onDragFinished: {
                            if (root.activeTimelineModel) {
                                for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                                    var sId = root.selectedNodeIds[i];
                                    var pos = root.getNodeCenterPos(sId, 0, 0);
                                    root.activeTimelineModel.setNodePosition(root.activeSelectedClipId, sId, pos.x, pos.y);
                                }
                            }
                        }

                        onRequestDelete: function (nodeId) {
                            if (root.activeTimelineModel) {
                                root.activeTimelineModel.removeNode(root.activeSelectedClipId, nodeId);
                            }
                        }
                    }
                }
            }

            // Search Palette (Anchored to canvasContainer)
            XylaNodeSearchPopup {
                id: searchPopup
                parent: canvasContainer

                onNodeSelected: function (typeName, spawnX, spawnY, fromNode, fromSocket) {
                    if (root.activeTimelineModel) {
                        var newNodeId = root.activeTimelineModel.addNode(root.activeSelectedClipId, typeName, spawnX, spawnY);
                        if (fromNode !== "" && fromSocket !== "" && newNodeId !== "") {
                            root.activeTimelineModel.connectSockets(root.activeSelectedClipId, fromNode, fromSocket, newNodeId, "video_in");
                        }
                    }
                    root.isConnectingWire = false;
                }

                onClosed: {
                    root.isConnectingWire = false;
                }
            }
        }
    }
}
