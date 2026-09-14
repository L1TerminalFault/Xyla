// import QtQuick
// import QtQuick.Layouts
//
// Rectangle {
//     id: rootProxyCard
//
//     property var nodeData: null
//     property var activeModel: null
//     property string activeClipId: ""
//     property bool isSelected: false
//     property string activeHighlightSocketId: ""
//
//     readonly property string nodeId: nodeData ? nodeData.id : ""
//     readonly property bool isInputProxy: nodeData && nodeData.typeName === "GroupInputNode"
//
//     signal nodeSelected(string id, bool isShift)
//     signal dragMovedDelta(real rawTargetX, real rawTargetY)
//     signal dragFinished()
//     signal pinPositionChanged(string nId, string sId, bool isOut, real px, real py)
//     signal startConnectingWire(string nodeId, string socketId, real pinX, real pinY)
//     signal updateWireDrag(real gx, real gy)
//     signal endConnectingWire(real gx, real gy)
//
//     width: 170
//     height: Math.max(90, headerRect.height + socketColumn.implicitHeight + 16)
//     radius: 8
//     color: isSelected ? "#1F2E3D" : "#141C24"
//     border.color: isSelected ? "#60A5FA" : "#25384D"
//     border.width: isSelected ? 2 : 1
//
//     Rectangle {
//         id: headerRect
//         anchors.top: parent.top
//         anchors.left: parent.left
//         anchors.right: parent.right
//         height: 26
//         radius: 7
//         color: isInputProxy ? "#1E3A5F" : "#3B2D54"
//
//         RowLayout {
//             anchors.fill: parent
//             anchors.leftMargin: 8
//             anchors.rightMargin: 8
//             Text {
//                 text: isInputProxy ? "📥 Group Inputs" : "📤 Group Outputs"
//                 color: "#E2E8F0"
//                 font.bold: true
//                 font.pixelSize: 11
//                 Layout.fillWidth: true
//             }
//         }
//
//         MouseArea {
//             anchors.fill: parent
//             cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
//             property real dragStartX: 0
//             property real dragStartY: 0
//
//             onPressed: function(mouse) {
//                 var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
//                 rootProxyCard.nodeSelected(rootProxyCard.nodeId, isMulti);
//                 var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
//                 dragStartX = pt.x;
//                 dragStartY = pt.y;
//             }
//             onPositionChanged: function(mouse) {
//                 if (pressed) {
//                     var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
//                     rootProxyCard.dragMovedDelta(pt.x, pt.y);
//                 }
//             }
//             onReleased: rootProxyCard.dragFinished()
//         }
//     }
//
//     ColumnLayout {
//         id: socketColumn
//         anchors.top: headerRect.bottom
//         anchors.left: parent.left
//         anchors.right: parent.right
//         anchors.topMargin: 8
//         spacing: 6
//
//         // Renders either inputs (for GroupOutputNode) or outputs (for GroupInputNode)
//         Repeater {
//             model: isInputProxy ? (nodeData.outputs || []) : (nodeData.inputs || [])
//             delegate: RowLayout {
//                 Layout.fillWidth: true
//                 Layout.leftMargin: isInputProxy ? 8 : 6
//                 Layout.rightMargin: isInputProxy ? 6 : 8
//
//                 // Input socket pin
//                 Rectangle {
//                     visible: !isInputProxy
//                     width: 10; height: 10; radius: 5
//                     color: "#A78BFA"
//                     Component.onCompleted: {
//                         var pt = mapToItem(rootProxyCard.parent, 5, 5);
//                         rootProxyCard.pinPositionChanged(rootProxyCard.nodeId, modelData.id, false, pt.x, pt.y);
//                     }
//                 }
//
//                 Text {
//                     text: modelData.name
//                     color: "#D1D5DB"
//                     font.pixelSize: 11
//                     Layout.fillWidth: true
//                     horizontalAlignment: isInputProxy ? Text.AlignRight : Text.AlignLeft
//                 }
//
//                 // Output socket pin
//                 Rectangle {
//                     visible: isInputProxy
//                     width: 10; height: 10; radius: 5
//                     color: "#60A5FA"
//                     Component.onCompleted: {
//                         var pt = mapToItem(rootProxyCard.parent, 5, 5);
//                         rootProxyCard.pinPositionChanged(rootProxyCard.nodeId, modelData.id, true, pt.x, pt.y);
//                     }
//                     MouseArea {
//                         anchors.fill: parent
//                         cursorShape: Qt.CrossCursor
//                         onPressed: function(mouse) {
//                             var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
//                             rootProxyCard.startConnectingWire(rootProxyCard.nodeId, modelData.id, pt.x, pt.y);
//                         }
//                         onPositionChanged: function(mouse) {
//                             var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
//                             rootProxyCard.updateWireDrag(pt.x, pt.y);
//                         }
//                         onReleased: function(mouse) {
//                             var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
//                             rootProxyCard.endConnectingWire(pt.x, pt.y);
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }
//
//
//
//
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: rootProxyCard
    width: 170
    height: 28 + bodyLayout.implicitHeight + 12
    radius: 14
    color: "#0F1A15"
    border.color: isInputProxy ? "#059669" : "#D97706"
    border.width: 1.5
    z: 15

    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property bool isSelected: false
    property string activeHighlightSocketId: ""

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property string typeName: nodeData ? (nodeData.typeName || "") : ""
    readonly property bool isInputProxy: typeName === "GroupInputNode"

    signal pinPositionChanged(string nodeId, string socketId, bool isOutput, real wsX, real wsY)
    signal startConnectingWire(string nodeId, string socketId, real globalPinX, real globalPinY)
    signal updateWireDrag(real globalX, real globalY)
    signal endConnectingWire(real globalX, real globalY)
    signal nodeSelected(string nodeId, bool isShift)
    signal dragMovedDelta(real deltaX, real deltaY)
    signal dragFinished()

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#80000000"
        shadowBlur: 0.5
        shadowVerticalOffset: 3
    }

    function updateAllPinPositions() {
        if (!rootProxyCard.parent) return;
        var rep = isInputProxy ? proxyOutputs : proxyInputs;
        for (var i = 0; i < rep.count; ++i) {
            var row = rep.itemAt(i);
            if (row && row.pinItem) {
                var pt = row.pinItem.mapToItem(rootProxyCard.parent, 4, 4);
                rootProxyCard.pinPositionChanged(rootProxyCard.nodeId, row.socketId, isInputProxy, pt.x, pt.y);
            }
        }
    }

    onXChanged: updateAllPinPositions()
    onYChanged: updateAllPinPositions()
    onHeightChanged: updateAllPinPositions()

    // Header
    Rectangle {
        id: proxyHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26
        radius: 14
        color: isInputProxy ? "#064E3B" : "#78350F"

        Text {
            anchors.centerIn: parent
            text: isInputProxy ? "📥 Group Inputs" : "📤 Group Outputs"
            color: "#FFFFFF"
            font.pixelSize: 10
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real dragStartMouseX: 0
            property real dragStartMouseY: 0
            property real dragStartNodeX: 0
            property real dragStartNodeY: 0

            onPressed: function(mouse) {
                var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
                dragStartMouseX = pt.x;
                dragStartMouseY = pt.y;
                dragStartNodeX = rootProxyCard.x + rootProxyCard.width / 2;
                dragStartNodeY = rootProxyCard.y + rootProxyCard.height / 2;
                rootProxyCard.nodeSelected(rootProxyCard.nodeId, mouse.modifiers & Qt.ShiftModifier);
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var pt = mapToItem(rootProxyCard.parent, mouse.x, mouse.y);
                    rootProxyCard.dragMovedDelta(dragStartNodeX + (pt.x - dragStartMouseX), dragStartNodeY + (pt.y - dragStartMouseY));
                    rootProxyCard.updateAllPinPositions();
                }
            }
            onReleased: {
                rootProxyCard.dragFinished();
                rootProxyCard.updateAllPinPositions();
            }
        }
    }

    ColumnLayout {
        id: bodyLayout
        anchors.top: proxyHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        spacing: 3

        // When GroupInputNode: exposes OUTPUT pins for internal nodes to read
        Repeater {
            id: proxyOutputs
            visible: isInputProxy
            model: (isInputProxy && rootProxyCard.nodeData && rootProxyCard.nodeData.outputs) ? rootProxyCard.nodeData.outputs : []

            delegate: Item {
                id: outRow
                Layout.fillWidth: true
                height: 26
                readonly property string socketId: modelData.id || ""
                readonly property Item pinItem: outPin

                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || "Param"
                    color: "#D1FAE5"
                    font.pixelSize: 10
                }

                Item {
                    id: outPin
                    x: parent.width - 4; y: (parent.height - 8) / 2
                    width: 8; height: 8; z: 10
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; rotation: 45; color: "#10B981" }
                    MouseArea {
                        anchors.centerIn: parent; width: 16; height: 16
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(mouse) {
                            var pt = outPin.mapToItem(rootProxyCard.parent, 4, 4);
                            rootProxyCard.startConnectingWire(rootProxyCard.nodeId, outRow.socketId, pt.x, pt.y);
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) rootProxyCard.updateWireDrag(mapToItem(rootProxyCard.parent, mouse.x, mouse.y).x, mapToItem(rootProxyCard.parent, mouse.x, mouse.y).y);
                        }
                        onReleased: function(mouse) {
                            rootProxyCard.endConnectingWire(mapToItem(rootProxyCard.parent, mouse.x, mouse.y).x, mapToItem(rootProxyCard.parent, mouse.x, mouse.y).y);
                        }
                    }
                }
            }
        }

        // When GroupOutputNode: exposes INPUT pins for internal child nodes to connect their final results
        Repeater {
            id: proxyInputs
            visible: !isInputProxy
            model: (!isInputProxy && rootProxyCard.nodeData && rootProxyCard.nodeData.inputs) ? rootProxyCard.nodeData.inputs : []

            delegate: Item {
                id: inRow
                Layout.fillWidth: true
                height: 26
                readonly property string socketId: modelData.id || ""
                readonly property Item pinItem: inPin

                Item {
                    id: inPin
                    x: -4; y: (parent.height - 8) / 2
                    width: 8; height: 8; z: 10
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; rotation: 45; color: "#F59E0B" }
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || "Result"
                    color: "#FEF3C7"
                    font.pixelSize: 10
                }
            }
        }
    }
}
