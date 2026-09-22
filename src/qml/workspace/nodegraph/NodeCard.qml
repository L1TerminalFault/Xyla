import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Rectangle {
    id: rootNodeCard

    // ============================================================
    // API & Data Properties
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
    signal pinPositionChanged(string nodeId, string socketId, bool isOutput, real wsX, real wsY)

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property string typeName: nodeData ? (nodeData.typeName || "") : ""
    readonly property bool isBypassed: nodeData ? (Boolean(nodeData.isBypassed) || Boolean(nodeData.bypassed)) : false

    // ============================================================
    // Visual Palette
    // ============================================================

    readonly property color normalBackground: "#090909"
    readonly property color selectedBackground: "#272727"
    readonly property color normalBar: "#141414"
    readonly property color hoverBar: "#1B1B1B"
    readonly property color activeBar: "#393939"
    readonly property color primaryText: "#EEEEEE"
    readonly property color secondaryText: "#A1A1A1"

    // Geometry
    width: 180
    height: rootNodeCard.isCollapsed ? 28 : (28 + bodyColumn.implicitHeight + 14)
    radius: 16
    color: rootNodeCard.isSelected ? rootNodeCard.selectedBackground : rootNodeCard.normalBackground
    z: rootNodeCard.isSelected ? 50 : 10
    opacity: isBypassed ? 0.42 : 1.0

    // Animations
    Behavior on height {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }
    Behavior on x {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.InOutQuad
        }
    }

    HoverHandler {
        id: cardHover
    }

    // ============================================================
    // Background & Drop Shadow
    // ============================================================

    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: rootNodeCard.color
        radius: 16

        layer.enabled: true
        layer.samples: 8
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
        }
    }

    MouseArea {
        id: cardSelectArea
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: function (mouse) {
            var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
            rootNodeCard.nodeSelected(rootNodeCard.nodeId, isMulti);
            mouse.accepted = false;
        }
    }

    // ============================================================
    // Node Types & Pin Color Resolvers
    // ============================================================

    function getNodeTypeColor(type) {
        switch (type) {
        case "SourceNode":
            return "#2563EB";
        case "TransformNode":
        case "Transform":
            return "#7C3AED";
        case "ColorGradeNode":
        case "ColorGrade":
            return "#16A34A";
        case "BlurNode":
        case "Blur":
            return "#EA580C";
        case "OutputNode":
            return "#E11D48";
        case "Reroute":
            return "#64748B";
        case "CommentNode":
            return "#F59E0B";
        case "GroupNode":
            return "#0D9488";
        default:
            return "#475569";
        }
    }

    function getPinColor(dataType) {
        switch (dataType) {
        case "Image":
            return "#3B82F6";
        case "Float":
            return "#10B981";
        case "Vec2":
            return "#F59E0B";
        case "Vec4":
        case "Color":
            return "#EC4899";
        case "Audio":
            return "#8B5CF6";
        default:
            return "#06B6D4";
        }
    }

    function notifyPinWorldPos(socketId, isOutput, pinItemObj) {
        if (!pinItemObj || !rootNodeCard.parent)
            return;
        var pt = pinItemObj.mapToItem(rootNodeCard.parent, pinItemObj.width / 2, pinItemObj.height / 2);
        rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, socketId, isOutput, pt.x, pt.y);
    }

    function updateAllPinPositions() {
        if (!rootNodeCard || !rootNodeCard.parent)
            return;
        try {
            for (var i = 0; i < inRepeater.count; ++i) {
                var inRow = inRepeater.itemAt(i);
                if (inRow && inRow.pinItem) {
                    var inPt = inRow.pinItem.mapToItem(rootNodeCard.parent, 4, 4);
                    rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, inRow.socketId, false, inPt.x, inPt.y);
                }
            }
            for (var j = 0; j < outRepeater.count; ++j) {
                var outRow = outRepeater.itemAt(j);
                if (outRow && outRow.pinItem) {
                    var outPt = outRow.pinItem.mapToItem(rootNodeCard.parent, 4, 4);
                    rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, outRow.socketId, true, outPt.x, outPt.y);
                }
            }
        } catch (err) {}
    }

    onXChanged: updateAllPinPositions()
    onYChanged: updateAllPinPositions()
    onWidthChanged: updateAllPinPositions()
    onHeightChanged: updateAllPinPositions()
    onIsCollapsedChanged: updateAllPinPositions()

    Component.onCompleted: {
        updateAllPinPositions();
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
        radius: 16
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6

            // Chevron Collapse Toggle
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
                    sourceSize: Qt.size(58, 58)
                    opacity: rootNodeCard.isSelected ? 1.0 : 0.7
                    rotation: rootNodeCard.isCollapsed ? -90 : 0
                    transformOrigin: Item.Center

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rootNodeCard.isCollapsed = !rootNodeCard.isCollapsed
                }
            }

            // Node Title
            Text {
                Layout.fillWidth: true
                text: rootNodeCard.nodeData ? (rootNodeCard.nodeData.name || "Node") : "Node"
                color: rootNodeCard.primaryText
                font.pixelSize: 11
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Type Indicator Pill
            Rectangle {
                id: typeBadge
                visible: rootNodeCard.typeName !== ""
                implicitWidth: 18
                implicitHeight: 3
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4
                color: rootNodeCard.getNodeTypeColor(rootNodeCard.typeName)
                radius: height / 2
            }
        }

        // Card Drag Controller
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real dragStartMouseX: 0
            property real dragStartMouseY: 0
            property real dragStartNodeX: 0
            property real dragStartNodeY: 0

            onPressed: function (mouse) {
                var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                dragStartMouseX = pt.x;
                dragStartMouseY = pt.y;
                dragStartNodeX = rootNodeCard.x + rootNodeCard.width / 2;
                dragStartNodeY = rootNodeCard.y + rootNodeCard.height / 2;

                var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                rootNodeCard.nodeSelected(rootNodeCard.nodeId, isMulti);
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                    var rawTargetX = dragStartNodeX + (pt.x - dragStartMouseX);
                    var rawTargetY = dragStartNodeY + (pt.y - dragStartMouseY);
                    rootNodeCard.dragMovedDelta(rawTargetX, rawTargetY);
                    rootNodeCard.updateAllPinPositions();
                }
            }

            onReleased: {
                rootNodeCard.dragFinished();
                rootNodeCard.updateAllPinPositions();
            }
        }
    }

    // ============================================================
    // BODY: INPUTS & OUTPUTS
    // ============================================================

    ColumnLayout {
        id: bodyColumn
        anchors.top: nodeHeader.bottom
        anchors.topMargin: rootNodeCard.isCollapsed ? 0 : 6
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        height: !rootNodeCard.isCollapsed ? implicitHeight : 0
        visible: height > 0

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutCubic
            }
        }

        // INPUTS REPEATER
        Repeater {
            id: inRepeater
            model: (rootNodeCard.nodeData && rootNodeCard.nodeData.inputs) ? rootNodeCard.nodeData.inputs : []

            delegate: Item {
                id: inputRow
                Layout.fillWidth: true
                height: 32

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""
                readonly property Item pinItem: inPinContainer
                readonly property bool isTargetHovered: rootNodeCard.activeHighlightSocketId === socketId

                Rectangle {
                    id: inputBar
                    anchors.fill: parent
                    anchors.leftMargin: inputRow.isTargetHovered ? 0 : 7
                    anchors.rightMargin: inputRow.isTargetHovered ? 0 : 7
                    radius: 8
                    color: inputRow.isTargetHovered ? (rootNodeCard.isWireHoverValid ? rootNodeCard.activeBar : "#382323") : (inputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar)
                }

                HoverHandler {
                    id: inputHover
                }

                // Input Pin Diamond
                Item {
                    id: inPinContainer
                    x: -4
                    y: (parent.height - 8) / 2
                    width: 8
                    height: 8
                    z: 20

                    function updatePos() {
                        rootNodeCard.notifyPinWorldPos(inputRow.socketId, false, inPinContainer);
                    }
                    onXChanged: updatePos()
                    onYChanged: updatePos()
                    Component.onCompleted: updatePos()

                    Rectangle {
                        anchors.centerIn: parent
                        width: inputRow.isTargetHovered ? 10 : 8
                        height: inputRow.isTargetHovered ? 10 : 8
                        rotation: 45
                        transformOrigin: Item.Center
                        radius: 1
                        z: 3000
                        color: rootNodeCard.getPinColor(inputRow.typeName)
                    }
                }

                // Input Label
                Text {
                    anchors.left: inputBar.left
                    anchors.leftMargin: 17
                    anchors.verticalCenter: inputBar.verticalCenter
                    width: inputBar.width - 78
                    text: modelData.name || ""
                    color: inputRow.isTargetHovered ? "#FFFFFF" : rootNodeCard.secondaryText
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Input Value Field
                Rectangle {
                    id: valueSurface
                    visible: inputRow.typeName !== "Image"
                    anchors.right: inputBar.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: inputBar.verticalCenter
                    width: 53
                    height: 23
                    radius: 6
                    color: inputRow.isTargetHovered ? rootNodeCard.activeBar : (inputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar)
                    border.width: 0

                    XylaFloatInput {
                        id: floatInput
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        value: (modelData.defaultValue !== undefined && modelData.defaultValue !== null) ? Number(modelData.defaultValue) : 1.0

                        onValueCommitted: function (newVal) {
                            if (rootNodeCard.activeModel && rootNodeCard.activeClipId) {
                                rootNodeCard.activeModel.updateSocketValue(rootNodeCard.activeClipId, rootNodeCard.nodeId, inputRow.socketId, newVal);
                            }
                        }
                    }
                }
            }
        }

        // Section Divider
        Rectangle {
            visible: inRepeater.count > 0 && outRepeater.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            color: "#1C1C1C"
        }

        // OUTPUTS REPEATER
        Repeater {
            id: outRepeater
            model: (rootNodeCard.nodeData && rootNodeCard.nodeData.outputs) ? rootNodeCard.nodeData.outputs : []

            delegate: Item {
                id: outRow
                Layout.fillWidth: true
                height: 32

                readonly property string socketId: modelData.id || ""
                readonly property string typeName: modelData.dataTypeName || ""
                readonly property Item pinItem: outPinContainer

                Rectangle {
                    id: outputBar
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    radius: 8
                    color: outputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar
                }

                HoverHandler {
                    id: outputHover
                }

                Text {
                    anchors.right: outputBar.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: outputBar.verticalCenter
                    width: outputBar.width - 24
                    text: modelData.name || ""
                    color: outputHover.hovered ? "#FFFFFF" : rootNodeCard.secondaryText
                    font.pixelSize: 10
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Output Pin Diamond
                Item {
                    id: outPinContainer
                    x: parent.width - 4
                    y: (parent.height - 8) / 2
                    width: 8
                    height: 8
                    z: 20

                    function updatePos() {
                        rootNodeCard.notifyPinWorldPos(outRow.socketId, true, outPinContainer);
                    }
                    onXChanged: updatePos()
                    onYChanged: updatePos()
                    Component.onCompleted: updatePos()

                    Rectangle {
                        anchors.centerIn: parent
                        width: outPinMouse.containsMouse ? 10 : 8
                        height: outPinMouse.containsMouse ? 10 : 8
                        rotation: 45
                        transformOrigin: Item.Center
                        radius: 1
                        color: outPinMouse.containsMouse ? Qt.lighter(rootNodeCard.getPinColor(outRow.typeName), 1.25) : rootNodeCard.getPinColor(outRow.typeName)
                    }

                    MouseArea {
                        id: outPinMouse
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function (mouse) {
                            var pt = outPinContainer.mapToItem(rootNodeCard.parent, 4, 4);
                            rootNodeCard.startConnectingWire(rootNodeCard.nodeId, outRow.socketId, pt.x, pt.y);
                        }

                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                                rootNodeCard.updateWireDrag(pt.x, pt.y);
                            }
                        }

                        onReleased: function (mouse) {
                            var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                            rootNodeCard.endConnectingWire(pt.x, pt.y);
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: inRepeater
        function onCountChanged() {
            rootNodeCard.updateAllPinPositions();
        }
    }
    Connections {
        target: outRepeater
        function onCountChanged() {
            rootNodeCard.updateAllPinPositions();
        }
    }
}
