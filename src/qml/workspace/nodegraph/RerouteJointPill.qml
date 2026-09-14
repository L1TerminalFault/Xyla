// import QtQuick
//
// Item {
//     id: rootReroute
//
//     property var nodeData: null
//     property bool isSelected: false
//     property string activeHighlightSocketId: ""
//
//     readonly property string nodeId: nodeData ? nodeData.id : ""
//
//     signal nodeSelected(string id, bool isShift)
//     signal dragMovedDelta(real rawTargetX, real rawTargetY)
//     signal dragFinished()
//     signal pinPositionChanged(string nId, string sId, bool isOut, real px, real py)
//     signal startConnectingWire(string nodeId, string socketId, real pinX, real pinY)
//     signal updateWireDrag(real gx, real gy)
//     signal endConnectingWire(real gx, real gy)
//
//     width: 24
//     height: 24
//
//     // Minimal circle dot
//     Rectangle {
//         id: dotVisual
//         anchors.centerIn: parent
//         width: isHovered.hovered || isSelected ? 18 : 14
//         height: width
//         radius: width / 2
//         color: isSelected ? "#FBBF24" : (isHovered.hovered ? "#60A5FA" : "#94A3B8")
//         border.color: isSelected ? "#F59E0B" : "#475569"
//         border.width: isSelected ? 2 : 1
//
//         Behavior on width { NumberAnimation { duration: 100 } }
//
//         Component.onCompleted: {
//             var pt = mapToItem(rootReroute.parent, width / 2, height / 2);
//             rootReroute.pinPositionChanged(rootReroute.nodeId, "in", false, pt.x, pt.y);
//             rootReroute.pinPositionChanged(rootReroute.nodeId, "out", true, pt.x, pt.y);
//         }
//     }
//
//     HoverHandler { id: isHovered }
//
//     MouseArea {
//         anchors.fill: parent
//         cursorShape: Qt.PointingHandCursor
//         property real dragStartX: 0
//         property real dragStartY: 0
//         property bool isConnecting: false
//
//         onPressed: function(mouse) {
//             var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
//             rootReroute.nodeSelected(rootReroute.nodeId, isMulti);
//
//             var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
//             dragStartX = pt.x;
//             dragStartY = pt.y;
//
//             if (mouse.modifiers & Qt.AltModifier) {
//                 // Alt + Click on reroute starts dragging a new outgoing connection
//                 isConnecting = true;
//                 rootReroute.startConnectingWire(rootReroute.nodeId, "out", pt.x, pt.y);
//             }
//         }
//
//         onPositionChanged: function(mouse) {
//             var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
//             if (isConnecting) {
//                 rootReroute.updateWireDrag(pt.x, pt.y);
//             } else if (pressed) {
//                 rootReroute.dragMovedDelta(pt.x, pt.y);
//             }
//         }
//
//         onReleased: function(mouse) {
//             if (isConnecting) {
//                 var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
//                 rootReroute.endConnectingWire(pt.x, pt.y);
//                 isConnecting = false;
//             } else {
//                 rootReroute.dragFinished();
//             }
//         }
//     }
// }


import QtQuick
import QtQuick.Controls

Item {
    id: rootReroute
    width: 14
    height: 14

    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property bool isSelected: false

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property string typeName: "Reroute"

    signal pinPositionChanged(string nodeId, string socketId, bool isOutput, real wsX, real wsY)
    signal startConnectingWire(string nodeId, string socketId, real globalPinX, real globalPinY)
    signal updateWireDrag(real globalX, real globalY)
    signal endConnectingWire(real globalX, real globalY)
    signal nodeSelected(string nodeId, bool isShift)
    signal dragMovedDelta(real deltaX, real deltaY)
    signal dragFinished()

    function notifyPinWorldPos() {
        if (!rootReroute.parent) return;
        var pt = rootReroute.mapToItem(rootReroute.parent, width / 2, height / 2);
        rootReroute.pinPositionChanged(rootReroute.nodeId, "in", false, pt.x, pt.y);
        rootReroute.pinPositionChanged(rootReroute.nodeId, "out", true, pt.x, pt.y);
    }

    onXChanged: notifyPinWorldPos()
    onYChanged: notifyPinWorldPos()
    Component.onCompleted: notifyPinWorldPos()

    Rectangle {
        id: dotVisual
        anchors.fill: parent
        radius: 7
        color: rootReroute.isSelected ? "#3B82F6" : "#475569"
        border.color: rootReroute.isSelected ? "#60A5FA" : "#1E293B"
        border.width: 1.5

        Rectangle {
            anchors.centerIn: parent
            width: 4; height: 4; radius: 2
            color: "#FFFFFF"
            opacity: rootReroute.isSelected ? 1.0 : 0.6
        }
    }

    MouseArea {
        id: rerouteMouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real dragStartMouseX: 0
        property real dragStartMouseY: 0
        property real dragStartNodeX: 0
        property real dragStartNodeY: 0
        property bool isAltWire: false

        onPressed: function(mouse) {
            var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
            dragStartMouseX = pt.x;
            dragStartMouseY = pt.y;
            dragStartNodeX = rootReroute.x + rootReroute.width / 2;
            dragStartNodeY = rootReroute.y + rootReroute.height / 2;

            if (mouse.modifiers & Qt.AltModifier) {
                isAltWire = true;
                rootReroute.startConnectingWire(rootReroute.nodeId, "out", dragStartNodeX, dragStartNodeY);
            } else {
                isAltWire = false;
                var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                rootReroute.nodeSelected(rootReroute.nodeId, isMulti);
            }
        }

        onPositionChanged: function(mouse) {
            var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
            if (isAltWire) {
                rootReroute.updateWireDrag(pt.x, pt.y);
            } else if (pressed) {
                // Raw delta - intentionally NO grid snapping applied to Reroutes
                var rawTargetX = dragStartNodeX + (pt.x - dragStartMouseX);
                var rawTargetY = dragStartNodeY + (pt.y - dragStartMouseY);
                rootReroute.dragMovedDelta(rawTargetX, rawTargetY);
                rootReroute.notifyPinWorldPos();
            }
        }

        onReleased: function(mouse) {
            if (isAltWire) {
                var pt = mapToItem(rootReroute.parent, mouse.x, mouse.y);
                rootReroute.endConnectingWire(pt.x, pt.y);
                isAltWire = false;
            } else {
                rootReroute.dragFinished();
                rootReroute.notifyPinWorldPos();
            }
        }
    }
}
