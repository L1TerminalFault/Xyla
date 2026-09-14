import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rootCollection

    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property bool isSelected: false

    readonly property string nodeId: nodeData ? nodeData.id : ""

    signal nodeSelected(string id, bool isShift)
    signal dragMovedDelta(real rawTargetX, real rawTargetY)
    signal dragFinished()

    width: nodeData && nodeData.boxWidth ? nodeData.boxWidth : 360
    height: nodeData && nodeData.boxHeight ? nodeData.boxHeight : 240
    radius: 12
    color: "#0F172A40" // Semi-transparent backdrop framing the nodes inside
    border.color: isSelected ? "#38BDF8" : "#334155"
    border.width: isSelected ? 2 : 1
    z: -10 // Renders behind internal nodes

    // Title Bar
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        radius: 11
        color: isSelected ? "#1E293B" : "#111827"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            Text {
                text: "🏷️"
                font.pixelSize: 11
            }

            TextInput {
                id: collectionTitle
                text: nodeData && nodeData.name ? nodeData.name : "Collection"
                color: "#93C5FD"
                font.bold: true
                font.pixelSize: 12
                Layout.fillWidth: true
                selectByMouse: true
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real dragStartX: 0
            property real dragStartY: 0

            onPressed: function(mouse) {
                var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                rootCollection.nodeSelected(rootCollection.nodeId, isMulti);
                var pt = mapToItem(rootCollection.parent, mouse.x, mouse.y);
                dragStartX = pt.x;
                dragStartY = pt.y;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var pt = mapToItem(rootCollection.parent, mouse.x, mouse.y);
                    rootCollection.dragMovedDelta(pt.x, pt.y);
                }
            }
            onReleased: rootCollection.dragFinished()
        }
    }

    // Resize Handle
    Rectangle {
        width: 14; height: 14
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "⌟"
            color: "#475569"
            font.bold: true
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real startW: 0
            property real startH: 0
            property real mouseStartX: 0
            property real mouseStartY: 0

            onPressed: function(mouse) {
                startW = rootCollection.width;
                startH = rootCollection.height;
                var pt = mapToItem(rootCollection.parent, mouse.x, mouse.y);
                mouseStartX = pt.x;
                mouseStartY = pt.y;
            }

            onPositionChanged: function(mouse) {
                if (pressed) {
                    var pt = mapToItem(rootCollection.parent, mouse.x, mouse.y);
                    rootCollection.width = Math.max(200, startW + (pt.x - mouseStartX));
                    rootCollection.height = Math.max(140, startH + (pt.y - mouseStartY));
                }
            }
        }
    }
}
