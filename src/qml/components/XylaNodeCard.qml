import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root

    // ============================================================
    // API
    // ============================================================

    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property bool isSelected: false
    property bool isCollapsed: false

    property string activeHighlightSocketId: ""
    property bool isWireHoverValid: true

    signal startConnectingWire(string nodeId, string socketId, real globalPinX, real globalPinY)
    signal updateWireDrag(real globalX, real globalY)
    signal endConnectingWire(real globalX, real globalY)
    signal nodeSelected(string nodeId, bool isShift)
    signal dragMovedDelta(real deltaX, real deltaY)
    signal dragFinished

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property string typeName: nodeData ? (nodeData.typeName || "") : ""

    // ============================================================
    // COLOR PALETTE: SEAMLESS HEADER & BODY TONE
    // ============================================================

    readonly property color normalBackground: "#1B1B1C"
    readonly property color selectedBackground: "#27272A"
    readonly property color normalBar: "#242426"
    readonly property color hoverBar: "#2F2F32"
    readonly property color activeBar: "#3E3E42"
    readonly property color normalBorder: "#333336"
    readonly property color selectedBorder: "#52525B"
    readonly property color barBorder: "#3A3A3D"
    readonly property color primaryText: "#EEEEEE"
    readonly property color secondaryText: "#A1A1AA"

    // Palette color for the vertical bar on the LEFT edge
    function getNodeTypeColor(type) {
        switch (type) {
        case "SourceNode": return "#2563EB"
        case "TransformNode":
        case "Transform": return "#7C3AED"
        case "ColorGradeNode":
        case "ColorGrade": return "#16A34A"
        case "BlurNode":
        case "Blur": return "#EA580C"
        case "OutputNode": return "#E11D48"
        case "Reroute": return "#64748B"
        case "CommentNode": return "#F59E0B"
        case "GroupNode": return "#0D9488"
        default: return "#475569"
        }
    }

    // Socket pin colors
    function getPinColor(dataType) {
        switch (dataType) {
        case "Image": return "#3B82F6"
        case "Float": return "#10B981"
        case "Vec2": return "#F59E0B"
        case "Vec4":
        case "Color": return "#EC4899"
        case "Audio": return "#8B5CF6"
        default: return "#06B6D4"
        }
    }

    // ============================================================
    // PIN COORDINATE LOOKUP — PRESERVED ZERO-DRIFT
    // ============================================================

    function getPinCenterInWorkspace(socketId, isOutput) {
        var repeater = isOutput ? outRepeater : inRepeater

        for (var i = 0; i < repeater.count; ++i) {
            var rowItem = repeater.itemAt(i)
            if (rowItem && rowItem.socketId === socketId) {
                var pinObj = rowItem.pinItem
                // Calculate center precisely from the socket container
                return pinObj.mapToItem(root.parent, 4, 4)
            }
        }

        var yOffset = isCollapsed ? 14 : (36 + (isOutput ? 20 : 0))
        return Qt.point(isOutput ? root.x + root.width : root.x, root.y + yOffset)
    }

    // ============================================================
    // EXACT GEOMETRY
    // ============================================================

    width: 180
    height: root.isCollapsed ? 28 : (28 + bodyColumn.implicitHeight + 14)
    radius: 8

    color: root.isSelected ? root.selectedBackground : root.normalBackground
    border.color: root.isSelected ? root.selectedBorder : (cardHover.hovered ? "#47474A" : root.normalBorder)
    border.width: 1
    z: root.isSelected ? 50 : 10

    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler { id: cardHover }

    // ============================================================
    // PALETTE COLOR TAB ATTACHED TO LEFT EDGE (NOT TOP)
    // ============================================================

    Rectangle {
        id: leftPaletteBar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 5
        width: 3
        height: 18
        radius: 1.5
        color: root.getNodeTypeColor(root.typeName)
        z: 30

        // Subtle bloom
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: parent.color
            opacity: root.isSelected ? 0.6 : 0.25
            scale: 1.4
            z: -1
        }
    }

    // ============================================================
    // HEADER
    // ============================================================

    Rectangle {
        id: nodeHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        radius: 8
        color: root.color

        // Square bottom edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 7
            color: parent.color
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6

            // Chevron Down Icon (Non-deformed with aspect ratio preserved)
            Item {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: chevronIcon
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/assets/icons/chevron-down.svg"
                    sourceSize: Qt.size(10, 10)
                    opacity: root.isSelected ? 1.0 : 0.7

                    // Animate -90 deg when collapsed
                    rotation: root.isCollapsed ? -90 : 0
                    transformOrigin: Item.Center

                    Behavior on rotation {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isCollapsed = !root.isCollapsed
                }
            }

            // Node Name
            Text {
                Layout.fillWidth: true
                text: root.nodeData ? (root.nodeData.name || "Node") : "Node"
                color: root.primaryText
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Type
            Text {
                visible: root.typeName !== ""
                text: root.typeName.replace("Node", "")
                color: root.secondaryText
                font.pixelSize: 8
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.maximumWidth: 48
            }
        }

        // Drag Handler
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real dragStartMouseX: 0
            property real dragStartMouseY: 0
            property real dragStartNodeX: 0
            property real dragStartNodeY: 0

            onPressed: function(mouse) {
                var pt = mapToItem(root.parent, mouse.x, mouse.y)
                dragStartMouseX = pt.x
                dragStartMouseY = pt.y
                dragStartNodeX = root.x + root.width / 2
                dragStartNodeY = root.y + root.height / 2
                root.nodeSelected(root.nodeId, mouse.modifiers & Qt.ShiftModifier)
            }

            onPositionChanged: function(mouse) {
                if (pressed) {
                    var pt = mapToItem(root.parent, mouse.x, mouse.y)
                    var rawTargetX = dragStartNodeX + (pt.x - dragStartMouseX)
                    var rawTargetY = dragStartNodeY + (pt.y - dragStartMouseY)
                    root.dragMovedDelta(rawTargetX, rawTargetY)
                }
            }

            onReleased: root.dragFinished()
        }
    }

    // ============================================================
    // BODY
    // ============================================================

    ColumnLayout {
        id: bodyColumn
        visible: !root.isCollapsed
        anchors.top: nodeHeader.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        // ========================================================
        // INPUTS
        // ========================================================

        Repeater {
            id: inRepeater
            model: (root.nodeData && root.nodeData.inputs) ? root.nodeData.inputs : []

            delegate: Item {
                id: inputRow
                Layout.fillWidth: true
                height: 32

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""
                readonly property Item pinItem: inPinContainer

                readonly property bool isTargetHovered: root.activeHighlightSocketId === socketId

                // Bar
                Rectangle {
                    id: inputBar
                    anchors.fill: parent
                    anchors.leftMargin: inputRow.isTargetHovered ? 0 : 7
                    anchors.rightMargin: inputRow.isTargetHovered ? 0 : 7
                    radius: 8

                    color: inputRow.isTargetHovered
                        ? (root.isWireHoverValid ? root.activeBar : "#382323")
                        : (inputHover.hovered ? root.hoverBar : root.normalBar)

                    border.color: inputRow.isTargetHovered
                        ? (root.isWireHoverValid ? "#60A5FA" : "#EF4444")
                        : root.barBorder
                    border.width: 1
                }

                HoverHandler { id: inputHover }

                // Pin Item Container (Ensures pin center is always at relative (4, 4) with 0 drift)
                Item {
                    id: inPinContainer
                    x: -4
                    y: (parent.height - 8) / 2
                    width: 8
                    height: 8
                    z: 20

                    Rectangle {
                        anchors.centerIn: parent
                        width: inputRow.isTargetHovered ? 10 : 8
                        height: inputRow.isTargetHovered ? 10 : 8
                        rotation: 45
                        transformOrigin: Item.Center

                        color: inputRow.isTargetHovered
                            ? (root.isWireHoverValid ? "#FFFFFF" : "#EF4444")
                            : root.getPinColor(inputRow.typeName)

                        border.color: inputRow.isTargetHovered
                            ? (root.isWireHoverValid ? root.getPinColor(inputRow.typeName) : "#7F1D1D")
                            : "#141415"
                        border.width: inputRow.isTargetHovered ? 2 : 1
                    }
                }

                // Label
                Text {
                    anchors.left: inputBar.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: inputBar.verticalCenter
                    width: inputBar.width - 78
                    text: modelData.name || ""
                    color: inputRow.isTargetHovered ? "#FFFFFF" : root.secondaryText
                    font.pixelSize: 10
                    font.weight: inputRow.isTargetHovered ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Value
                Rectangle {
                    id: valueSurface
                    anchors.right: inputBar.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: inputBar.verticalCenter
                    width: 53
                    height: 23
                    radius: 6
                    color: inputRow.isTargetHovered ? root.activeBar : (inputHover.hovered ? root.hoverBar : root.normalBar)
                    border.width: 0

                    XylaFloatInput {
                        id: floatInput
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        value: (modelData.defaultValue !== undefined && modelData.defaultValue !== null)
                            ? Number(modelData.defaultValue)
                            : 1.0

                        onValueCommitted: function(newVal) {
                            if (root.activeModel && root.activeClipId) {
                                root.activeModel.updateSocketValue(root.activeClipId, root.nodeId, inputRow.socketId, newVal)
                            }
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            visible: inRepeater.count > 0 && outRepeater.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 9
            Layout.rightMargin: 9
            color: "#2C2C2F"
        }

        // ========================================================
        // OUTPUTS
        // ========================================================

        Repeater {
            id: outRepeater
            model: (root.nodeData && root.nodeData.outputs) ? root.nodeData.outputs : []

            delegate: Item {
                id: outRow
                Layout.fillWidth: true
                height: 32

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""
                readonly property Item pinItem: outPinContainer

                // Bar
                Rectangle {
                    id: outputBar
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    radius: 8
                    color: outputHover.hovered ? root.hoverBar : root.normalBar
                    border.color: outputHover.hovered ? "#454549" : root.barBorder
                    border.width: 1
                }

                HoverHandler { id: outputHover }

                // Label
                Text {
                    anchors.right: outputBar.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: outputBar.verticalCenter
                    width: outputBar.width - 24
                    text: modelData.name || ""
                    color: outputHover.hovered ? "#FFFFFF" : root.secondaryText
                    font.pixelSize: 10
                    font.weight: outputHover.hovered ? Font.DemiBold : Font.Normal
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Output Pin Container (Zero Y-drift)
                Item {
                    id: outPinContainer
                    x: parent.width - 4
                    y: (parent.height - 8) / 2
                    width: 8
                    height: 8
                    z: 20

                    Rectangle {
                        anchors.centerIn: parent
                        width: outPinMouse.containsMouse ? 10 : 8
                        height: outPinMouse.containsMouse ? 10 : 8
                        rotation: 45
                        transformOrigin: Item.Center

                        color: outPinMouse.containsMouse
                            ? Qt.lighter(root.getPinColor(outRow.typeName), 1.25)
                            : root.getPinColor(outRow.typeName)

                        border.color: outPinMouse.containsMouse ? "#FFFFFF" : "#141415"
                        border.width: outPinMouse.containsMouse ? 1.5 : 1
                    }

                    MouseArea {
                        id: outPinMouse
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function(mouse) {
                            var pt = outPinContainer.mapToItem(root.parent, 4, 4)
                            root.startConnectingWire(root.nodeId, outRow.socketId, pt.x, pt.y)
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var pt = mapToItem(root.parent, mouse.x, mouse.y)
                                root.updateWireDrag(pt.x, pt.y)
                            }
                        }

                        onReleased: function(mouse) {
                            var pt = mapToItem(root.parent, mouse.x, mouse.y)
                            root.endConnectingWire(pt.x, pt.y)
                        }
                    }
                }
            }
        }
    }
}
