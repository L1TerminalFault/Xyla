import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root

    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property real currentPosX: 0
    property real currentPosY: 0
    property bool isSelected: false
    property bool isCollapsed: false

    signal startConnectingWire(string nodeId, string socketId, real globalPinX, real globalPinY)
    signal updateWireDrag(real globalX, real globalY)
    signal endConnectingWire(real globalX, real globalY)
    signal openInEffectEditor(string nodeId, string qmlUrl)
    signal nodeSelected(string nodeId, bool isShift)
    signal dragMovedDelta(real deltaX, real deltaY)
    signal dragFinished
    signal requestDelete(string nodeId)

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property bool hasEditor: nodeData ? Boolean(nodeData.hasCustomEditor) : false
    readonly property string typeName: nodeData ? (nodeData.typeName || "") : ""

    function getHeaderColor(type) {
        switch (type) {
        case "SourceNode":
            return "#1D5DDB"; // Blue (Source)
        case "TransformNode":
            return "#5C3D7A"; // Purple (Spatial / Transform)
        case "ColorGradeNode":
            return "#2D6A4F"; // Green (Color / Shading)
        case "OutputNode":
            return "#8B263E"; // Crimson (Output)
        default:
            return "#334155";
        }
    }

    function getPinColor(dataType) {
        switch (dataType) {
        case "Image":
            return "#38BDF8"; // Cyan
        case "Float":
            return "#A1A1AA"; // Gray/Silver
        case "Vec2":
            return "#C084FC"; // Purple/Violet
        case "Color":
            return "#FBBF24"; // Yellow
        case "Int":
            return "#34D399"; // Emerald Green
        case "Bool":
            return "#FB923C"; // Orange
        default:
            return "#71717A";
        }
    }

    width: 170
    height: root.isCollapsed ? 28 : (28 + bodyColumn.implicitHeight + 12)

    color: "#202020"
    border.color: root.isSelected ? "#ffffff" : "#111111"
    border.width: root.isSelected ? 1.5 : 1
    radius: 6
    z: root.isSelected ? 50 : 10

    // Header (Blender Category Color Header)
    Rectangle {
        id: nodeHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26
        color: root.getHeaderColor(root.typeName)
        radius: 6

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            color: nodeHeader.color
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 4

            // Blender-style collapse arrow
            Text {
                text: root.isCollapsed ? "▶" : "▼"
                color: "#ffffff"
                font.pixelSize: 8
                opacity: 0.8

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: root.isCollapsed = !root.isCollapsed
                }
            }

            Text {
                text: root.nodeData ? root.nodeData.name : "Node"
                color: "#ffffff"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Effect Editor Redirect Button
            XylaIconButton {
                visible: root.hasEditor
                iconSource: "qrc:/assets/icons/link.svg"
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                onClicked: {
                    if (root.nodeData && root.nodeData.customEditorQmlUrl) {
                        root.openInEffectEditor(root.nodeId, root.nodeData.customEditorQmlUrl);
                    }
                }
            }
        }

        MouseArea {
            id: nodeDrag
            anchors.fill: parent
            z: -1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real lastX: 0
            property real lastY: 0

            onPressed: function (mouse) {
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                lastX = pt.x;
                lastY = pt.y;
                root.nodeSelected(root.nodeId, mouse.modifiers & Qt.ShiftModifier);
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(root.parent, mouse.x, mouse.y);
                    var dx = pt.x - lastX;
                    var dy = pt.y - lastY;
                    lastX = pt.x;
                    lastY = pt.y;
                    root.dragMovedDelta(dx, dy);
                }
            }

            onReleased: root.dragFinished()
        }
    }

    // Node Sockets and Stacked Inputs Body
    ColumnLayout {
        id: bodyColumn
        visible: !root.isCollapsed
        anchors.top: nodeHeader.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        // Sockets Repeater
        Repeater {
            model: (root.nodeData && root.nodeData.inputs) ? root.nodeData.inputs : []

            delegate: Item {
                id: inputRow
                Layout.fillWidth: true
                height: isVec2 ? 58 : (isFloat ? 22 : (isInt ? 22 : 18))

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""
                readonly property bool isVec2: typeName === "Vec2"
                readonly property bool isFloat: typeName === "Float"
                readonly property bool isInt: typeName === "Int"
                readonly property bool isColor: typeName === "Color"

                // Socket Pin (Diamond protruding on the left edge)
                Rectangle {
                    id: inPin
                    x: -4
                    y: (inputRow.isVec2 ? 14 : inputRow.height / 2) - 4
                    width: 8
                    height: 8
                    rotation: 45
                    color: root.getPinColor(inputRow.typeName)
                    border.color: inPinHover.containsMouse ? "#ffffff" : "#111111"
                    border.width: 1
                    z: 20

                    MouseArea {
                        id: inPinHover
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                    }
                }

                // Label
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: inputRow.isVec2 ? 0 : 3
                    text: modelData.name || ""
                    color: "#b0b0b0"
                    font.pixelSize: 10
                }

                // 1. Stacked Blender Vector (X / Y in a tight vertical stack)
                Column {
                    visible: inputRow.isVec2
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    width: parent.width - 24
                    spacing: 1

                    readonly property bool isScale: inputRow.socketId.toLowerCase().indexOf("scale") !== -1
                    readonly property real fallbackVal: isScale ? 1.0 : 0.0

                    property real curX: (modelData.defaultValue && modelData.defaultValue.length >= 2 && !isNaN(modelData.defaultValue[0])) ? Number(modelData.defaultValue[0]) : fallbackVal
                    property real curY: (modelData.defaultValue && modelData.defaultValue.length >= 2 && !isNaN(modelData.defaultValue[1])) ? Number(modelData.defaultValue[1]) : fallbackVal

                    XylaFloatInput {
                        width: parent.width
                        label: "X"
                        value: parent.curX
                        stepSize: 0.05
                        onValueCommitted: function (newVal) {
                            parent.curX = newVal;
                            if (root.activeModel && root.activeClipId) {
                                root.activeModel.updateSocketValue(root.activeClipId, root.nodeId, inputRow.socketId, [newVal, parent.curY]);
                            }
                        }
                    }

                    XylaFloatInput {
                        width: parent.width
                        label: "Y"
                        value: parent.curY
                        stepSize: 0.05
                        onValueCommitted: function (newVal) {
                            parent.curY = newVal;
                            if (root.activeModel && root.activeClipId) {
                                root.activeModel.updateSocketValue(root.activeClipId, root.nodeId, inputRow.socketId, [parent.curX, newVal]);
                            }
                        }
                    }
                }

                // 2. Single Float Input
                XylaFloatInput {
                    visible: inputRow.isFloat
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    value: (modelData.defaultValue !== undefined && modelData.defaultValue !== null) ? Number(modelData.defaultValue) : 1.0
                    stepSize: 0.05
                    onValueCommitted: function (newVal) {
                        if (root.activeModel && root.activeClipId) {
                            root.activeModel.updateSocketValue(root.activeClipId, root.nodeId, inputRow.socketId, newVal);
                        }
                    }
                }

                // 3. Dropdown Enum / Blend Mode
                XylaSelect {
                    visible: inputRow.isInt
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 84
                    implicitHeight: 18
                    model: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Add", "Difference"]
                    currentIndex: (modelData.defaultValue !== undefined && modelData.defaultValue !== null) ? Number(modelData.defaultValue) : 0
                    onActivated: function (index) {
                        if (root.activeModel && root.activeClipId) {
                            root.activeModel.updateSocketValue(root.activeClipId, root.nodeId, inputRow.socketId, index);
                        }
                    }
                }
            }
        }

        // Outputs
        Repeater {
            model: (root.nodeData && root.nodeData.outputs) ? root.nodeData.outputs : []

            delegate: Item {
                id: outRow
                Layout.fillWidth: true
                height: 18

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || ""
                    color: "#b0b0b0"
                    font.pixelSize: 10
                }

                // Socket Output Pin (Diamond protruding on the right edge)
                Rectangle {
                    id: outPin
                    x: parent.width - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    rotation: 45
                    color: outPinMouse.containsMouse ? "#ffffff" : root.getPinColor(outRow.typeName)
                    border.color: "#111111"
                    border.width: 1
                    z: 20

                    MouseArea {
                        id: outPinMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function (mouse) {
                            var pt = mapToItem(root.parent, 4, 4);
                            root.startConnectingWire(root.nodeId, outRow.socketId, pt.x, pt.y);
                        }

                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                                root.updateWireDrag(pt.x, pt.y);
                            }
                        }

                        onReleased: function (mouse) {
                            var pt = mapToItem(root.parent, mouse.x, mouse.y);
                            root.endConnectingWire(pt.x, pt.y);
                        }
                    }
                }
            }
        }
    }
}
