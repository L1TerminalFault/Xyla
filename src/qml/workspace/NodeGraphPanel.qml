import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"

Item {
    id: root

    readonly property color bgDark: "#151515"
    readonly property color gridColor: "#222222"
    readonly property color gridAxisColor: "#2e2e2e"

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property string activeSelectedClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""

    property var selectedClipData: {
        if (!activeTimelineModel || !activeSelectedClipId)
            return null;
        if (typeof activeTimelineModel.getClipById === "function") {
            return activeTimelineModel.getClipById(activeSelectedClipId);
        }
        if (activeTimelineModel.selectedClip) {
            return activeTimelineModel.selectedClip;
        }
        return null;
    }

    property var nodeList: (selectedClipData && selectedClipData.nodes) ? selectedClipData.nodes : []
    property var linkList: (selectedClipData && selectedClipData.links) ? selectedClipData.links : []

    property real zoomLevel: 1.0
    property real panX: 0.0
    property real panY: 0.0

    // Local node position cache
    property var nodePositions: ({})

    // Interactive connection creation state
    property bool isConnectingWire: false
    property string wireFromNodeId: ""
    property string wireFromSocketId: ""
    property real wireMouseX: 0
    property real wireMouseY: 0

    function getNodePos(nodeId, defaultX, defaultY) {
        if (nodePositions[nodeId] !== undefined) {
            return nodePositions[nodeId];
        }
        return {
            x: Number(defaultX),
            y: Number(defaultY)
        };
    }

    function setNodePos(nodeId, newX, newY) {
        var temp = Object.assign({}, nodePositions);
        temp[nodeId] = {
            x: newX,
            y: newY
        };
        nodePositions = temp;
    }

    function findNodeData(nodeId) {
        if (!nodeList)
            return null;
        for (var i = 0; i < nodeList.length; ++i) {
            if (nodeList[i].id === nodeId) {
                return nodeList[i];
            }
        }
        return null;
    }

    function getSocketPinColor(dataTypeName) {
        switch (dataTypeName) {
        case "Image":
            return "#38BDF8"; // Cyan
        case "Float":
            return "#34D399"; // Emerald Green
        case "Vec2":
            return "#C084FC"; // Magenta / Purple
        case "Color":
            return "#FBBF24"; // Yellow
        case "Int":
            return "#FB923C"; // Orange
        case "Bool":
            return "#60A5FA"; // Blue
        default:
            return "#A1A1AA";
        }
    }

    // Exact Pin X position calculator (left edge for input, right edge for output)
    function calculatePinX(nodeId, isOutput, fallbackX) {
        var pos = getNodePos(nodeId, fallbackX, 0);
        var nData = findNodeData(nodeId);
        var nodeWidth = 180;
        if (nData) {
            var bodyW = (nData.inputs ? nData.inputs.length * 40 : 100);
            nodeWidth = Math.max(170, Math.max(120, bodyW));
        }
        return pos.x + (isOutput ? (nodeWidth / 2 - 4) : (-nodeWidth / 2 + 4));
    }

    // Exact Pin Y position calculator matching QML layout geometry
    function calculatePinY(nodeId, socketId, isOutput, fallbackY) {
        var pos = getNodePos(nodeId, 0, fallbackY);
        var nData = findNodeData(nodeId);
        if (!nData)
            return pos.y;

        var inputCount = nData.inputs ? nData.inputs.length : 0;
        var outputCount = nData.outputs ? nData.outputs.length : 0;
        var totalSockets = inputCount + outputCount;
        var nodeHeight = 32 + (totalSockets * 30) + 8;
        var topY = pos.y - nodeHeight / 2;

        var socketIndex = 0;
        if (isOutput) {
            // Output sockets are positioned after input sockets in layout
            var outIdx = 0;
            if (nData.outputs) {
                for (var i = 0; i < nData.outputs.length; ++i) {
                    if (nData.outputs[i].id === socketId) {
                        outIdx = i;
                        break;
                    }
                }
            }
            socketIndex = inputCount + outIdx;
        } else {
            // Input sockets
            if (nData.inputs) {
                for (var j = 0; j < nData.inputs.length; ++j) {
                    if (nData.inputs[j].id === socketId) {
                        socketIndex = j;
                        break;
                    }
                }
            }
        }

        // Top margin 36px + 11px row center offset = 47px base
        return topY + 47 + (socketIndex * 30);
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Node Graph Top Header Bar
        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: "#181818"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#2b2b2b"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: root.selectedClipData ? ("NODE GRAPH — " + root.selectedClipData.name) : "NODE GRAPH (No Clip Selected)"
                    color: root.selectedClipData ? "#3B82F6" : "#666666"
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Math.round(root.zoomLevel * 100) + "%"
                    color: "#666666"
                    font.pixelSize: 11
                    font.family: "Monospace"
                }

                Button {
                    text: "Reset View"
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

        // Custom Infinite DAG Canvas Area
        Item {
            id: canvasContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Canvas Grid Background
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

                    var gridSize = 32;
                    var startX = -width / (2 * root.zoomLevel) - root.panX;
                    var endX = width / (2 * root.zoomLevel) - root.panX;
                    var startY = -height / (2 * root.zoomLevel) - root.panY;
                    var endY = height / (2 * root.zoomLevel) - root.panY;

                    ctx.lineWidth = 1 / root.zoomLevel;
                    ctx.strokeStyle = root.gridColor;

                    ctx.beginPath();
                    for (var x = Math.floor(startX / gridSize) * gridSize; x < endX; x += gridSize) {
                        ctx.moveTo(x, startY);
                        ctx.lineTo(x, endY);
                    }
                    for (var y = Math.floor(startY / gridSize) * gridSize; y < endY; y += gridSize) {
                        ctx.moveTo(startX, y);
                        ctx.lineTo(endX, y);
                    }
                    ctx.stroke();

                    ctx.strokeStyle = root.gridAxisColor;
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

            // Interactive Pan & Zoom Canvas Mouse Handler
            MouseArea {
                id: canvasPanArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: true

                property real startX: 0
                property real startY: 0

                onPressed: function (mouse) {
                    startX = mouse.x - root.panX;
                    startY = mouse.y - root.panY;
                }

                onPositionChanged: function (mouse) {
                    if (pressed) {
                        root.panX = mouse.x - startX;
                        root.panY = mouse.y - startY;
                        dagCanvas.requestPaint();
                    }

                    if (root.isConnectingWire) {
                        var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.wireMouseX = pt.x;
                        root.wireMouseY = pt.y;
                    }
                }

                onReleased: function () {
                    if (root.isConnectingWire) {
                        root.isConnectingWire = false;
                    }
                }

                onWheel: function (wheel) {
                    var zoomFactor = wheel.angleDelta.y > 0 ? 1.1 : 0.9;
                    root.zoomLevel = Math.max(0.2, Math.min(3.0, root.zoomLevel * zoomFactor));
                    dagCanvas.requestPaint();
                }
            }

            // DAG Node & Wire Graph Workspace
            Item {
                id: graphWorkspace
                x: canvasContainer.width / 2 + root.panX
                y: canvasContainer.height / 2 + root.panY
                scale: root.zoomLevel

                // --- EXISTING LINK WIRES ---
                Repeater {
                    model: root.linkList

                    delegate: Item {
                        id: wireLink

                        // Exact Pin-to-Pin coordinates
                        property real fromX: root.calculatePinX(modelData.fromNodeId, true, -220)
                        property real fromY: root.calculatePinY(modelData.fromNodeId, modelData.fromSocketId, true, 0)
                        property real toX: root.calculatePinX(modelData.toNodeId, false, 220)
                        property real toY: root.calculatePinY(modelData.toNodeId, modelData.toSocketId, false, 0)

                        Shape {
                            anchors.fill: parent

                            ShapePath {
                                strokeColor: "#3B82F6"
                                strokeWidth: 2
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                startX: wireLink.fromX
                                startY: wireLink.fromY

                                PathCubic {
                                    x: wireLink.toX
                                    y: wireLink.toY
                                    control1X: wireLink.fromX + Math.max(40, Math.abs(wireLink.toX - wireLink.fromX) * 0.5)
                                    control1Y: wireLink.fromY
                                    control2X: wireLink.toX - Math.max(40, Math.abs(wireLink.toX - wireLink.fromX) * 0.5)
                                    control2Y: wireLink.toY
                                }
                            }
                        }
                    }
                }

                // --- DYNAMIC PENDING WIRE BEING DRAGGED ---
                Shape {
                    anchors.fill: parent
                    visible: root.isConnectingWire

                    ShapePath {
                        strokeColor: "#60A5FA"
                        strokeWidth: 2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [4, 4]
                        fillColor: "transparent"

                        startX: root.calculatePinX(root.wireFromNodeId, true, 0)
                        startY: root.calculatePinY(root.wireFromNodeId, root.wireFromSocketId, true, 0)

                        PathCubic {
                            x: root.wireMouseX
                            y: root.wireMouseY
                            control1X: parent.startX + Math.max(40, Math.abs(root.wireMouseX - parent.startX) * 0.5)
                            control1Y: parent.startY
                            control2X: root.wireMouseX - Math.max(40, Math.abs(root.wireMouseX - parent.startX) * 0.5)
                            control2Y: root.wireMouseY
                        }
                    }
                }

                // --- RESPONSIVE DRAGGABLE NODE CARDS ---
                Repeater {
                    model: root.nodeList

                    delegate: Rectangle {
                        id: nodeBox

                        readonly property string nodeId: modelData.id || ""

                        property var currentPos: root.getNodePos(nodeBox.nodeId, modelData.x, modelData.y)
                        x: currentPos.x - width / 2
                        y: currentPos.y - height / 2

                        width: Math.max(170, Math.max(headerText.implicitWidth + 30, bodyColumn.implicitWidth + 24))
                        height: 32 + bodyColumn.implicitHeight + 12

                        color: "#18181c"
                        border.color: nodeDrag.pressed ? "#60A5FA" : (root.selectedClipData ? "#2c2c34" : "#222226")
                        border.width: 1
                        radius: 6
                        z: nodeDrag.pressed ? 100 : 10

                        // Sleek Dark Gray Header Bar
                        Rectangle {
                            id: nodeHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            color: "#24242a"
                            radius: 6

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 6
                                color: "#24242a"
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: "#33333b"
                            }

                            Text {
                                id: headerText
                                anchors.centerIn: parent
                                text: modelData.name || "Node"
                                color: "#eeeeee"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width - 16
                            }

                            // Vibration-Free Smooth Movement Handler
                            MouseArea {
                                id: nodeDrag
                                anchors.fill: parent
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                property real startWorkspaceX: 0
                                property real startWorkspaceY: 0
                                property real startNodeX: 0
                                property real startNodeY: 0

                                onPressed: function (mouse) {
                                    var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                                    startWorkspaceX = pt.x;
                                    startWorkspaceY = pt.y;
                                    startNodeX = nodeBox.currentPos.x;
                                    startNodeY = nodeBox.currentPos.y;
                                }

                                onPositionChanged: function (mouse) {
                                    if (pressed) {
                                        var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                                        var deltaX = pt.x - startWorkspaceX;
                                        var deltaY = pt.y - startWorkspaceY;
                                        root.setNodePos(nodeBox.nodeId, startNodeX + deltaX, startNodeY + deltaY);
                                    }
                                }
                            }
                        }

                        // Node Content Layout
                        ColumnLayout {
                            id: bodyColumn
                            anchors.top: nodeHeader.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            spacing: 8

                            // --- INPUT SOCKETS ---
                            Repeater {
                                model: modelData.inputs || []

                                delegate: RowLayout {
                                    id: inRow
                                    Layout.fillWidth: true
                                    spacing: 6

                                    readonly property string socketId: modelData.id || ""
                                    readonly property string typeName: modelData.dataTypeName || ""

                                    // Diamond Pin ($\diamond$)
                                    Rectangle {
                                        id: inPin
                                        width: 8
                                        height: 8
                                        rotation: 45
                                        color: root.getSocketPinColor(inRow.typeName)
                                        border.color: "#ffffff"
                                        border.width: inPinMouse.containsMouse ? 1.5 : 0
                                        Layout.alignment: Qt.AlignVCenter

                                        MouseArea {
                                            id: inPinMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true

                                            onReleased: {
                                                if (root.isConnectingWire) {
                                                    if (root.activeTimelineModel && root.activeTimelineModel.connectSockets) {
                                                        root.activeTimelineModel.connectSockets(root.activeSelectedClipId, root.wireFromNodeId, root.wireFromSocketId, nodeBox.nodeId, inRow.socketId);
                                                    }
                                                    root.isConnectingWire = false;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.name || ""
                                        color: "#cccccc"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    // --- INPUT CONTROLS BY EXPLICIT SOCKET DATA TYPE NAME ---

                                    // 1. Float DataType (Single Control)
                                    XylaFloatInput {
                                        visible: inRow.typeName === "Float"
                                        value: modelData.defaultValue !== undefined ? Number(modelData.defaultValue) : 0.0
                                        stepSize: 0.05
                                        Layout.alignment: Qt.AlignVCenter

                                        onValueCommitted: function (newVal) {
                                            if (root.activeTimelineModel && root.activeTimelineModel.updateSocketValue) {
                                                root.activeTimelineModel.updateSocketValue(root.activeSelectedClipId, nodeBox.nodeId, inRow.socketId, newVal);
                                            }
                                        }
                                    }

                                    // 2. Vec2 DataType (X and Y Controls Side-by-Side)
                                    Row {
                                        visible: inRow.typeName === "Vec2"
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        XylaFloatInput {
                                            label: "X"
                                            value: (modelData.defaultValue && modelData.defaultValue.length >= 2) ? Number(modelData.defaultValue[0]) : 0.0
                                            stepSize: 0.05
                                            onValueCommitted: function (newVal) {
                                                if (root.activeTimelineModel && root.activeTimelineModel.updateSocketValue) {
                                                    var currentY = (modelData.defaultValue && modelData.defaultValue.length >= 2) ? Number(modelData.defaultValue[1]) : 0.0;
                                                    root.activeTimelineModel.updateSocketValue(root.activeSelectedClipId, nodeBox.nodeId, inRow.socketId, [newVal, currentY]);
                                                }
                                            }
                                        }
                                        XylaFloatInput {
                                            label: "Y"
                                            value: (modelData.defaultValue && modelData.defaultValue.length >= 2) ? Number(modelData.defaultValue[1]) : 0.0
                                            stepSize: 0.05
                                            onValueCommitted: function (newVal) {
                                                if (root.activeTimelineModel && root.activeTimelineModel.updateSocketValue) {
                                                    var currentX = (modelData.defaultValue && modelData.defaultValue.length >= 2) ? Number(modelData.defaultValue[0]) : 0.0;
                                                    root.activeTimelineModel.updateSocketValue(root.activeSelectedClipId, nodeBox.nodeId, inRow.socketId, [currentX, newVal]);
                                                }
                                            }
                                        }
                                    }

                                    // 3. Int DataType / Custom XylaSelect Blend Mode Component
                                    XylaSelect {
                                        visible: inRow.typeName === "Int"
                                        implicitWidth: 92
                                        implicitHeight: 22
                                        model: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Add", "Difference"]
                                        currentIndex: modelData.defaultValue !== undefined ? Number(modelData.defaultValue) : 0
                                        Layout.alignment: Qt.AlignVCenter

                                        onCurrentIndexChanged: {
                                            if (root.activeTimelineModel && root.activeTimelineModel.updateSocketValue) {
                                                root.activeTimelineModel.updateSocketValue(root.activeSelectedClipId, nodeBox.nodeId, inRow.socketId, currentIndex);
                                            }
                                        }
                                    }
                                }
                            }

                            // --- OUTPUT SOCKETS ---
                            Repeater {
                                model: modelData.outputs || []

                                delegate: RowLayout {
                                    id: outRow
                                    Layout.fillWidth: true
                                    spacing: 6

                                    readonly property string socketId: modelData.id || ""
                                    readonly property string typeName: modelData.dataTypeName || ""

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.name || ""
                                        color: "#cccccc"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Diamond Pin ($\diamond$)
                                    Rectangle {
                                        id: outPin
                                        width: 8
                                        height: 8
                                        rotation: 45
                                        color: root.getSocketPinColor(outRow.typeName)
                                        border.color: "#ffffff"
                                        border.width: outPinMouse.containsMouse ? 1.5 : 0
                                        Layout.alignment: Qt.AlignVCenter

                                        MouseArea {
                                            id: outPinMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onPressed: function (mouse) {
                                                root.isConnectingWire = true;
                                                root.wireFromNodeId = nodeBox.nodeId;
                                                root.wireFromSocketId = outRow.socketId;

                                                var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                                                root.wireMouseX = pt.x;
                                                root.wireMouseY = pt.y;
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
    }
}
