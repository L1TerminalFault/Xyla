import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Rectangle {
    id: rootNodeCard

    // ============================================================
    // API
    // ============================================================

    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: rootNodeCard.isSelected ? rootNodeCard.selectedBackground : rootNodeCard.normalBackground
        // color: "#181818"
        // radius: 8
        radius: 16
        // border.color: rootNodeCard.isSelected ? "#2555D3" : "#2d2d2d"
        // border.width: rootNodeCard.isSelected ? 2 : 1

        layer.enabled: true
        layer.samples: 8 // Valid MSAA sample count (2, 4, 8, or 16)
        
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
        }
    }

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
    signal enterGroupRequested(string groupId, string groupName)

    readonly property string nodeId: nodeData ? (nodeData.id || "") : ""
    readonly property string typeName: nodeData ? (nodeData.typeName || "") : ""

    // function updateAllPinPositions() {
    //     // Update all input pins
    //     for (var i = 0; i < inRepeater.count; ++i) {
    //         var inRow = inRepeater.itemAt(i);
    //         if (inRow) {
    //             rootNodeCard.notifyPinWorldPos(inRow.socketId, false, inRow.pinItem);
    //         }
    //     }
    //     // Update all output pins
    //     for (var j = 0; j < outRepeater.count; ++j) {
    //         var outRow = outRepeater.itemAt(j);
    //         if (outRow) {
    //             rootNodeCard.notifyPinWorldPos(outRow.socketId, true, outRow.pinItem);
    //         }
    //     }
    // }
    //
    // ------------------------------------------------------------
    // PIN POSITION IN WORKSPACE (Called by NodeGraphPanel)
    // ------------------------------------------------------------
    function getPinCenterInWorkspace(socketId, isOutput) {
        if (rootNodeCard.isCollapsed) {
            var cw = rootNodeCard.width;
            return Qt.point(isOutput ? (rootNodeCard.x + cw) : rootNodeCard.x, rootNodeCard.y + 14);
        }

        var repeater = isOutput ? outRepeater : inRepeater;
        if (repeater && repeater.count > 0) {
            for (var i = 0; i < repeater.count; ++i) {
                var row = repeater.itemAt(i);
                if (row && row.socketId === socketId && row.pinItem) {
                    if (rootNodeCard.parent) {
                        return row.pinItem.mapToItem(rootNodeCard.parent, 4, 4);
                    }
                }
            }
        }

        // Fallback if repeaters haven't completed loading delegates yet:
        var cardW = rootNodeCard.width > 0 ? rootNodeCard.width : 180;
        var pX = isOutput ? (rootNodeCard.x + cardW) : rootNodeCard.x;
        var pY = rootNodeCard.y + (rootNodeCard.isCollapsed ? 14 : 36);
        return Qt.point(pX, pY);
    }
    // function getPinCenterInWorkspace(socketId, isOutput) {
    //     var repeater = isOutput ? outRepeater : inRepeater;
    //     for (var i = 0; i < repeater.count; ++i) {
    //         var row = repeater.itemAt(i);
    //         if (row && row.socketId === socketId) {
    //             var pin = row.pinItem;
    //             if (pin && rootNodeCard.parent) {
    //                 // mapToItem on graphWorkspace directly uses the live current card geometry
    //                 return pin.mapToItem(rootNodeCard.parent, 4, 4);
    //             }
    //         }
    //     }
    //     // Fail-safe calculation
    //     return Qt.point(isOutput ? (rootNodeCard.x + rootNodeCard.width) : rootNodeCard.x, rootNodeCard.y + 40);
    // }

    // Call updateAllPinPositions whenever the card moves or size changes
    // onXChanged: updateAllPinPositions()
    // onYChanged: updateAllPinPositions()
    // onHeightChanged: updateAllPinPositions()

    // ============================================================
    // COLOR PALETTE: SEAMLESS HEADER & BODY TONE
    // ============================================================

    readonly property color normalBackground: "#090909"
    readonly property color selectedBackground: "#272727"
    readonly property color normalBar: "#141414"
    readonly property color hoverBar: "#1B1B1B"
    readonly property color activeBar: "#393939"
    // readonly property color normalBorder: "#333333"
    // readonly property color selectedBorder: "#525252"
    // readonly property color barBorder: "#3A3A3A"
    readonly property color primaryText: "#EEEEEE"
    readonly property color secondaryText: "#A1A1A1"

    readonly property bool isBypassed: nodeData ? (Boolean(nodeData.isBypassed) || Boolean(nodeData.bypassed)) : false
    opacity: isBypassed ? 0.42 : 1.0

// Smooth transition animations on ANY position change
    Behavior on x {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    // Start invisible until layout completes and true size is measured
    opacity: 0.0
    // 2. Bump up with recoil scale animation on creation
    scale: 0.85
    transformOrigin: Item.Center
    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.4 // Distinct tactile bump & recoil
        }
    }

    // Component lifecycle
    Component.onCompleted: {
        // Wait one event loop turn so bodyColumn and repeaters complete layout
        // Qt.callLater(function() {
            if (!rootNodeCard || !rootNodeCard.parent) return;

            // Read the TRUE component dimensions (no fallback, strictly real size)
            var realW = rootNodeCard.width;
            var realH = rootNodeCard.height;

            // Request collision check from parent canvas with exact size
            // if (root.resolveNewNodePlacement) {
            //     root.resolveNewNodePlacement(rootNodeCard.nodeId, realW, realH);
            // }

            // Reveal the card
            rootNodeCard.opacity = 1.0;
            rootNodeCard.scale = 1.0;
            rootNodeCard.updateAllPinPositions();
        // });
    }
// As soon as the card component completes loading and has its real height:
    // Component.onCompleted: {
    //     // Only run on fresh instantiation
    //     if (rootNodeCard.parent && rootNodeCard.parent.parent && rootNodeCard.parent.parent.resolveNodePlacement) {
    //         Qt.callLater(function() {
    //             // Passes real component.width and component.height directly:
    //             rootNodeCard.parent.parent.resolveNodePlacement(rootNodeCard.nodeId, rootNodeCard.width, rootNodeCard.height);
    //         });
    //     }
    // }

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
    //
// In NodeCard.qml under signals:
    signal pinPositionChanged(string nodeId, string socketId, bool isOutput, real wsX, real wsY)

    function notifyPinWorldPos(socketId, isOutput, pinItemObj) {
        if (!pinItemObj || !rootNodeCard.parent) return;
        var pt = pinItemObj.mapToItem(rootNodeCard.parent, pinItemObj.width / 2, pinItemObj.height / 2);
        rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, socketId, isOutput, pt.x, pt.y);
    }

// -------------------------------------------------------------------------
    // Bulletproof Pin Workspace Coordinate Calculator
    // Directly queries the item inside graphWorkspace
    // -------------------------------------------------------------------------
    function getSocketWorkspacePos(socketId, isOutput) {
        var repeater = isOutput ? outRepeater : inRepeater;
        for (var i = 0; i < repeater.count; ++i) {
            var row = repeater.itemAt(i);
            if (row && row.socketId === socketId) {
                var pin = row.pinItem; // inPinContainer or outPinContainer
                if (pin && rootNodeCard.parent) {
                    // Map the exact 4x4 center of the pin directly into graphWorkspace coordinates
                    return pin.mapToItem(rootNodeCard.parent, 4, 4);
                }
            }
        }
        // Analytic fallback if repeater has not loaded yet
        var cardW = rootNodeCard.width;
        var cardH = rootNodeCard.height;
        var pX = isOutput ? (rootNodeCard.x + cardW) : rootNodeCard.x;
        var pY = rootNodeCard.y + (rootNodeCard.isCollapsed ? 14 : 42);
        return Qt.point(pX, pY);
    }

// Safe pin update guard that never executes during delegate destruction
    function updateAllPinPositions() {
        if (!rootNodeCard || !rootNodeCard.parent) return;
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
        } catch (err) {
            // Context being destroyed by Qt Quick engine; ignore safely
        }
    }
    // function updateAllPinPositions() {
    //     if (!rootNodeCard.parent) return;
    //     if (rootNodeCard.isCollapsed) {
    //         // Collapse all sockets to two merged header pins
    //         for (var i = 0; i < inRepeater.count; ++i) {
    //             var r = inRepeater.itemAt(i);
    //             if (r) rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, r.socketId, false,
    //                 rootNodeCard.x, rootNodeCard.y + 14);
    //         }
    //         for (var j = 0; j < outRepeater.count; ++j) {
    //             var r2 = outRepeater.itemAt(j);
    //             if (r2) rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, r2.socketId, true,
    //                 rootNodeCard.x + rootNodeCard.width, rootNodeCard.y + 14);
    //         }
    //         return;
    //     }
    //
    //     if (!rootNodeCard.parent) return;
    //     for (var i = 0; i < inRepeater.count; ++i) {
    //         var inRow = inRepeater.itemAt(i);
    //         if (inRow && inRow.pinItem) {
    //             var inPt = inRow.pinItem.mapToItem(rootNodeCard.parent, 4, 4);
    //             rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, inRow.socketId, false, inPt.x, inPt.y);
    //         }
    //     }
    //     for (var j = 0; j < outRepeater.count; ++j) {
    //         var outRow = outRepeater.itemAt(j);
    //         if (outRow && outRow.pinItem) {
    //             var outPt = outRow.pinItem.mapToItem(rootNodeCard.parent, 4, 4);
    //             rootNodeCard.pinPositionChanged(rootNodeCard.nodeId, outRow.socketId, true, outPt.x, outPt.y);
    //         }
    //     }
    // }

    // Call whenever card moves, drags, collapses, or finishes loading
    // onXChanged: updateAllPinPositions()
    // onYChanged: updateAllPinPositions()
    // onHeightChanged: updateAllPinPositions()
    // onIsCollapsedChanged: Qt.callLater(updateAllPinPositions)
// Broadcast immediately on ANY physical position or dimension change
    onXChanged: {
        updateAllPinPositions();
        if (root && root.notifyGraphStateChanged) {
            root.pinRevision++;
        }
    }
    onYChanged: {
        updateAllPinPositions();
        if (root && root.notifyGraphStateChanged) {
            root.pinRevision++;
        }
    }
    onHeightChanged: updateAllPinPositions()
    onIsCollapsedChanged: updateAllPinPositions() // Qt.callLater(updateAllPinPositions)

    // ============================================================
    // EXACT GEOMETRY
    // ============================================================

    width: 180
    height: rootNodeCard.isCollapsed ? 28 : (28 + bodyColumn.implicitHeight + 14)
    radius: 16

    color: rootNodeCard.isSelected ? rootNodeCard.selectedBackground : rootNodeCard.normalBackground
    // border.color: rootNodeCard.isSelected ? rootNodeCard.selectedBorder : (cardHover.hovered ? "#47474A" : rootNodeCard.normalBorder)
    // border.width: 1
    z: rootNodeCard.isSelected ? 50 : 10

    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 120 } }
    // Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler { id: cardHover }

    // ============================================================
    // PALETTE COLOR TAB ATTACHED TO LEFT EDGE (NOT TOP)
    // ============================================================

    // Rectangle {
    //     id: leftPaletteBar
    //     anchors.left: parent.left
    //     anchors.top: parent.top
    //     anchors.topMargin: 5
    //     width: 3
    //     height: 18
    //     radius: 1.5
    //     color: rootNodeCard.getNodeTypeColor(rootNodeCard.typeName)
    //     z: 30
    //
    //     // Subtle bloom
    //     Rectangle {
    //         anchors.fill: parent
    //         radius: parent.radius
    //         color: parent.color
    //         opacity: rootNodeCard.isSelected ? 0.6 : 0.25
    //         scale: 1.4
    //         z: -1
    //     }
    // }
// Place this right inside 'Rectangle { id: rootNodeCard ... }' before children:
MouseArea {
        id: cardSelectArea
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: function(mouse) {
            var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
            rootNodeCard.nodeSelected(rootNodeCard.nodeId, isMulti);
            mouse.accepted = false;
        }
    }
//     MouseArea {
//         id: cardSelectArea
//         anchors.fill: parent
//         z: -2 // Behind header drag and socket controls
//         acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//         onPressed: function(mouse) {
//             rootNodeCard.nodeSelected(rootNodeCard.nodeId, mouse.modifiers & Qt.ShiftModifier);
//             mouse.accepted = false; // Allow click through to controls inside
//         }
// onPositionChanged: function(mouse) {
//                 if (pressed) {
//                     var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
//                     var rawTargetX = dragStartNodeX + (pt.x - dragStartMouseX);
//                     var rawTargetY = dragStartNodeY + (pt.y - dragStartMouseY);
//                     rootNodeCard.dragMovedDelta(rawTargetX, rawTargetY);
//                 }
//             }
//     }

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
        color: rootNodeCard.color

        // Square bottom edge
        // Rectangle {
        //     anchors.left: parent.left
        //     anchors.right: parent.right
        //     anchors.bottom: parent.bottom
        //     height: 7
        //     color: parent.color
        // }

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
                    sourceSize: Qt.size(58, 58)
                    opacity: rootNodeCard.isSelected ? 1.0 : 0.7

                    // Animate -90 deg when collapsed
                    rotation: rootNodeCard.isCollapsed ? -90 : 0
                    transformOrigin: Item.Center

                    Behavior on rotation {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rootNodeCard.isCollapsed = !rootNodeCard.isCollapsed
                }
            }

            // Node Name
            Text {
                Layout.fillWidth: true
                text: rootNodeCard.nodeData ? (rootNodeCard.nodeData.name || "Node") : "Node"
                color: rootNodeCard.primaryText
                font.pixelSize: 11
                // font.weight: Font.DemiBold
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Type
Rectangle {
    id: typeBadge
    visible: rootNodeCard.typeName !== ""

    // Layout Sizing & Bottom Alignment
    implicitWidth: 18 // Math.min(badgeText.implicitWidth + 10, 48)
    implicitHeight: 3
    Layout.alignment: Qt.AlignVCenter
    Layout.rightMargin: 4

    // Fully Rounded Pill & Type Color
    color: rootNodeCard.getNodeTypeColor(rootNodeCard.typeName)
    radius: height / 2

    // Text {
    //     id: badgeText
    //     anchors.centerIn: parent
    //     width: parent.width - 10
    //     text: rootNodeCard.typeName.replace("Node", "")
    //     color: rootNodeCard.secondaryText // or "#FFFFFF" for contrast
    //     font.pixelSize: 3
    //     font.weight: Font.Medium
    //     elide: Text.ElideRight
    //     horizontalAlignment: Text.AlignHCenter
    //     verticalAlignment: Text.AlignVCenter
    // }
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
                var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                dragStartMouseX = pt.x;
                dragStartMouseY = pt.y;
                dragStartNodeX = rootNodeCard.x + rootNodeCard.width / 2;
                dragStartNodeY = rootNodeCard.y + rootNodeCard.height / 2;
                
                var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                rootNodeCard.nodeSelected(rootNodeCard.nodeId, isMulti);
            }
            // onPressed: function(mouse) {
            //     var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y)
            //     dragStartMouseX = pt.x
            //     dragStartMouseY = pt.y
            //     dragStartNodeX = rootNodeCard.x + rootNodeCard.width / 2
            //     dragStartNodeY = rootNodeCard.y + rootNodeCard.height / 2
            //     rootNodeCard.nodeSelected(rootNodeCard.nodeId, mouse.modifiers & Qt.ShiftModifier)
            // }

onPositionChanged: function(mouse) {
                if (pressed) {
                    var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                    var rawTargetX = dragStartNodeX + (pt.x - dragStartMouseX);
                    var rawTargetY = dragStartNodeY + (pt.y - dragStartMouseY);
                    rootNodeCard.dragMovedDelta(rawTargetX, rawTargetY);
                    
                    // Force synchronous update of wire endpoints during drag:
                    rootNodeCard.updateAllPinPositions();
                }
            }

            onReleased: {
                rootNodeCard.dragFinished()
                rootNodeCard.updateAllPinPositions()
            }
        }
    }

    // ============================================================
    // BODY
    // ============================================================

    ColumnLayout {
id: bodyColumn

    anchors.top: nodeHeader.bottom
    anchors.topMargin: rootNodeCard.isCollapsed ? 0 : 6
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 4

    // 1. Prevents child elements from spilling out while collapsing
    // clip: true

    // 2. Drive target height between 0 and the layout's full content height
    height: !rootNodeCard.isCollapsed ? implicitHeight : 0

    // 3. Keep item visible while expanding/collapsing, hide when fully closed
    visible: height > 0

    // 4. Animate height transitions smoothly
    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutCubic
        }
    }

        // ========================================================
        // INPUTS
        // ========================================================

// ========================================================
        // DRILL-DOWN SUBGRAPH BUTTON
        // ========================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 7
            Layout.rightMargin: 7
            radius: 8
            color: groupEnterHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar

            HoverHandler { id: groupEnterHover }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: "Enter Subgraph"
                    color: groupEnterHover.hovered ? rootNodeCard.primaryText : rootNodeCard.secondaryText
                    font.pixelSize: 10
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "↗"
                    color: rootNodeCard.getNodeTypeColor("GroupNode")
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root && root.enterGroupView) {
                        root.enterGroupView(rootNodeCard.nodeId, rootNodeCard.nodeData ? rootNodeCard.nodeData.name : "");
                    }
                }
            }
        }

        // ========================================================
        // USER-DEFINED INTERFACE INPUTS
        // ========================================================
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
                    anchors.fill: parent
                    anchors.leftMargin: inputRow.isTargetHovered ? 0 : 7
                    anchors.rightMargin: inputRow.isTargetHovered ? 0 : 7
                    radius: 8
                    color: inputRow.isTargetHovered
                        ? (rootNodeCard.isWireHoverValid ? rootNodeCard.activeBar : "#382323")
                        : (inputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar)
                }

                HoverHandler { id: inputHover }

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
                    Connections {
                        target: rootNodeCard
                        function onXChanged() { inPinContainer.updatePos(); }
                        function onYChanged() { inPinContainer.updatePos(); }
                        function onHeightChanged() { inPinContainer.updatePos(); }
                    }

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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || "Input"
                    color: inputRow.isTargetHovered ? "#FFFFFF" : rootNodeCard.secondaryText
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                // Remove Socket Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 4
                    color: removeInHover.hovered ? "#3A1A1A" : "transparent"
                    HoverHandler { id: removeInHover }
                    Text { anchors.centerIn: parent; text: "×"; color: removeInHover.hovered ? "#EF4444" : "#666666"; font.pixelSize: 12 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootNodeCard.activeModel && rootNodeCard.activeModel.removeGroupInterfaceSocket) {
                                rootNodeCard.activeModel.removeGroupInterfaceSocket(rootNodeCard.activeClipId, rootNodeCard.nodeId, true, inputRow.socketId);
                            }
                        }
                    }
                }
            }
        }

        // + Add Input Socket
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Layout.leftMargin: 7
            Layout.rightMargin: 7
            radius: 6
            color: addInHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar

            HoverHandler { id: addInHover }
            Text {
                anchors.centerIn: parent
                text: "+ Add Input Socket"
                color: addInHover.hovered ? rootNodeCard.primaryText : rootNodeCard.secondaryText
                font.pixelSize: 9
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rootNodeCard.activeModel && rootNodeCard.activeModel.addGroupInterfaceSocket) {
                        rootNodeCard.activeModel.addGroupInterfaceSocket(rootNodeCard.activeClipId, rootNodeCard.nodeId, true, "In", 0);
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            color: "#1C1C1C"
        }

        // ========================================================
        // USER-DEFINED INTERFACE OUTPUTS
        // ========================================================
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
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    radius: 8
                    color: outputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar
                }

                HoverHandler { id: outputHover }

                // Remove Socket Button
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 4
                    color: removeOutHover.hovered ? "#3A1A1A" : "transparent"
                    HoverHandler { id: removeOutHover }
                    Text { anchors.centerIn: parent; text: "×"; color: removeOutHover.hovered ? "#EF4444" : "#666666"; font.pixelSize: 12 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootNodeCard.activeModel && rootNodeCard.activeModel.removeGroupInterfaceSocket) {
                                rootNodeCard.activeModel.removeGroupInterfaceSocket(rootNodeCard.activeClipId, rootNodeCard.nodeId, false, outRow.socketId);
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || "Output"
                    color: outputHover.hovered ? "#FFFFFF" : rootNodeCard.secondaryText
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                }

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
                    Connections {
                        target: rootNodeCard
                        function onXChanged() { outPinContainer.updatePos(); }
                        function onYChanged() { outPinContainer.updatePos(); }
                        function onHeightChanged() { outPinContainer.updatePos(); }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: outPinMouse.containsMouse ? 10 : 8
                        height: outPinMouse.containsMouse ? 10 : 8
                        rotation: 45
                        transformOrigin: Item.Center
                        radius: 1
                        color: outPinMouse.containsMouse
                            ? Qt.lighter(rootNodeCard.getPinColor(outRow.typeName), 1.25)
                            : rootNodeCard.getPinColor(outRow.typeName)
                    }

                    MouseArea {
                        id: outPinMouse
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function(mouse) {
                            var pt = outPinContainer.mapToItem(rootNodeCard.parent, 4, 4);
                            rootNodeCard.startConnectingWire(rootNodeCard.nodeId, outRow.socketId, pt.x, pt.y);
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                                rootNodeCard.updateWireDrag(pt.x, pt.y);
                            }
                        }
                        onReleased: function(mouse) {
                            var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y);
                            rootNodeCard.endConnectingWire(pt.x, pt.y);
                        }
                    }
                }
            }
        }

        // + Add Output Socket
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Layout.leftMargin: 7
            Layout.rightMargin: 7
            radius: 6
            color: addOutHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar

            HoverHandler { id: addOutHover }
            Text {
                anchors.centerIn: parent
                text: "+ Add Output Socket"
                color: addOutHover.hovered ? rootNodeCard.primaryText : rootNodeCard.secondaryText
                font.pixelSize: 9
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rootNodeCard.activeModel && rootNodeCard.activeModel.addGroupInterfaceSocket) {
                        rootNodeCard.activeModel.addGroupInterfaceSocket(rootNodeCard.activeClipId, rootNodeCard.nodeId, false, "Out", 0);
                    }
                }
            }
        }
    }

    // Report pin positions as soon as repeater delegates are actually created
    Connections {
        target: inRepeater
        function onCountChanged() {
            // Qt.callLater(function() {
                if (rootNodeCard && rootNodeCard.updateAllPinPositions) {
                    rootNodeCard.updateAllPinPositions();
                }
            // });
        }
    }
    Connections {
        target: outRepeater
        function onCountChanged() {
          // Qt.callLater(
          rootNodeCard.updateAllPinPositions();
        // );
        }
    }
}







// // ============================================================
//     // BODY
//     // ============================================================
//
//     ColumnLayout {
//         id: bodyColumn
//
//         anchors.top: nodeHeader.bottom
//         anchors.topMargin: rootNodeCard.isCollapsed ? 0 : 6
//         anchors.left: parent.left
//         anchors.right: parent.right
//         spacing: 4
//
//         height: !rootNodeCard.isCollapsed ? implicitHeight : 0
//         visible: height > 0
//
//         Behavior on height {
//             NumberAnimation {
//                 duration: 200
//                 easing.type: Easing.InOutCubic
//             }
//         }
//
//         // ========================================================
//         // 1. COMMENT NODE BODY (Notes / Markdown text box)
//         // ========================================================
//         Item {
//             id: commentBodyItem
//             visible: rootNodeCard.typeName === "CommentNode"
//             Layout.fillWidth: true
//             Layout.preferredHeight: Math.max(90, (rootNodeCard.nodeData && rootNodeCard.nodeData.boxHeight) ? rootNodeCard.nodeData.boxHeight - 42 : 120)
//             Layout.leftMargin: 7
//             Layout.rightMargin: 7
//
//             Rectangle {
//                 anchors.fill: parent
//                 radius: 8
//                 color: rootNodeCard.normalBar
//
//                 TextArea {
//                     id: commentTextArea
//                     anchors.fill: parent
//                     anchors.margins: 8
//                     text: rootNodeCard.nodeData ? (rootNodeCard.nodeData.commentText || rootNodeCard.nodeData.description || "") : ""
//                     color: rootNodeCard.primaryText
//                     font.pixelSize: 11
//                     placeholderText: "Enter notes or comments..."
//                     placeholderTextColor: "#555555"
//                     wrapMode: TextEdit.Wrap
//                     selectByMouse: true
//                     background: null
//
//                     onEditingFinished: {
//                         if (rootNodeCard.activeModel && rootNodeCard.activeClipId && rootNodeCard.activeModel.updateCommentText) {
//                             rootNodeCard.activeModel.updateCommentText(rootNodeCard.activeClipId, rootNodeCard.nodeId, text);
//                         }
//                     }
//                 }
//             }
//         }
//
//         // ========================================================
//         // 2. GROUP NODE BODY (Sub-graph navigation & interface info)
//         // ========================================================
//         ColumnLayout {
//             id: groupBodyItem
//             visible: rootNodeCard.typeName === "GroupNode"
//             Layout.fillWidth: true
//             spacing: 6
//
//             // Enter Sub-Graph Action Button
//             Rectangle {
//                 Layout.fillWidth: true
//                 Layout.preferredHeight: 28
//                 Layout.leftMargin: 7
//                 Layout.rightMargin: 7
//                 radius: 8
//                 color: groupBtnHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar
//
//                 HoverHandler { id: groupBtnHover }
//
//                 RowLayout {
//                     anchors.centerIn: parent
//                     spacing: 6
//                     Text {
//                         text: "↗"
//                         color: "#60A5FA"
//                         font.pixelSize: 12
//                         font.bold: true
//                     }
//                     Text {
//                         text: "Enter Subgraph"
//                         color: groupBtnHover.hovered ? "#FFFFFF" : rootNodeCard.secondaryText
//                         font.pixelSize: 10
//                         font.weight: Font.Medium
//                     }
//                 }
//
//                 MouseArea {
//                     anchors.fill: parent
//                     cursorShape: Qt.PointingHandCursor
//                     onClicked: {
//                         if (root && root.enterGroupView) {
//                             root.enterGroupView(rootNodeCard.nodeId, rootNodeCard.nodeData ? rootNodeCard.nodeData.name : "");
//                         }
//                     }
//                 }
//             }
//
//             // Member Node Count Badge
//             Rectangle {
//                 Layout.fillWidth: true
//                 Layout.preferredHeight: 22
//                 Layout.leftMargin: 7
//                 Layout.rightMargin: 7
//                 radius: 6
//                 color: "#101010"
//
//                 Text {
//                     anchors.centerIn: parent
//                     text: {
//                         var count = (rootNodeCard.nodeData && rootNodeCard.nodeData.memberNodeIds) ? rootNodeCard.nodeData.memberNodeIds.length : 0;
//                         return count + (count === 1 ? " Node inside" : " Nodes inside");
//                     }
//                     color: "#777777"
//                     font.pixelSize: 9
//                 }
//             }
//         }
//
//         // ========================================================
//         // 3. STANDARD NODE BODY: INPUTS
//         // ========================================================
//         Repeater {
//             id: inRepeater
//             model: (rootNodeCard.typeName !== "CommentNode" && rootNodeCard.nodeData && rootNodeCard.nodeData.inputs) ? rootNodeCard.nodeData.inputs : []
//
//             delegate: Item {
//                 id: inputRow
//                 Layout.fillWidth: true
//                 height: 32
//
//                 readonly property string socketId: modelData.id || ""
//                 readonly property string typeName: modelData.dataTypeName || ""
//                 readonly property Item pinItem: inPinContainer
//                 readonly property bool isTargetHovered: rootNodeCard.activeHighlightSocketId === socketId
//
//                 Rectangle {
//                     id: inputBar
//                     anchors.fill: parent
//                     anchors.leftMargin: inputRow.isTargetHovered ? 0 : 7
//                     anchors.rightMargin: inputRow.isTargetHovered ? 0 : 7
//                     radius: 8
//
//                     color: inputRow.isTargetHovered
//                         ? (rootNodeCard.isWireHoverValid ? rootNodeCard.activeBar : "#382323")
//                         : (inputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar)
//                 }
//
//                 HoverHandler { id: inputHover }
//
//                 Item {
//                     id: inPinContainer
//                     x: -4
//                     y: (parent.height - 8) / 2
//                     width: 8
//                     height: 8
//                     z: 20
//
//                     function updatePos() {
//                         rootNodeCard.notifyPinWorldPos(inputRow.socketId, false, inPinContainer);
//                     }
//                     onXChanged: updatePos()
//                     onYChanged: updatePos()
//                     Component.onCompleted: updatePos()
//                     Connections {
//                         target: rootNodeCard
//                         function onXChanged() { inPinContainer.updatePos(); }
//                         function onYChanged() { inPinContainer.updatePos(); }
//                         function onHeightChanged() { inPinContainer.updatePos(); }
//                     }
//
//                     Rectangle {
//                         anchors.centerIn: parent
//                         width: inputRow.isTargetHovered ? 10 : 8
//                         height: inputRow.isTargetHovered ? 10 : 8
//                         rotation: 45
//                         transformOrigin: Item.Center
//                         radius: 1
//                         z: 3000
//                         color: rootNodeCard.getPinColor(inputRow.typeName)
//                     }
//                 }
//
//                 Text {
//                     anchors.left: inputBar.left
//                     anchors.leftMargin: 17
//                     anchors.verticalCenter: inputBar.verticalCenter
//                     width: inputBar.width - 78
//                     text: modelData.name || ""
//                     color: inputRow.isTargetHovered ? "#FFFFFF" : rootNodeCard.secondaryText
//                     font.pixelSize: 10
//                     elide: Text.ElideRight
//                     verticalAlignment: Text.AlignVCenter
//                 }
//
//                 Rectangle {
//                     id: valueSurface
//                     anchors.right: inputBar.right
//                     anchors.rightMargin: 6
//                     anchors.verticalCenter: inputBar.verticalCenter
//                     width: 53
//                     height: 23
//                     radius: 6
//                     color: inputRow.isTargetHovered ? rootNodeCard.activeBar : (inputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar)
//                     border.width: 0
//
//                     XylaFloatInput {
//                         id: floatInput
//                         anchors.fill: parent
//                         anchors.leftMargin: 2
//                         anchors.rightMargin: 2
//                         anchors.topMargin: 1
//                         anchors.bottomMargin: 1
//                         theme: "sleek"
//                         value: (modelData.defaultValue !== undefined && modelData.defaultValue !== null)
//                             ? Number(modelData.defaultValue)
//                             : 1.0
//
//                         onValueCommitted: function(newVal) {
//                             if (rootNodeCard.activeModel && rootNodeCard.activeClipId) {
//                                 rootNodeCard.activeModel.updateSocketValue(rootNodeCard.activeClipId, rootNodeCard.nodeId, inputRow.socketId, newVal)
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//
//         // Divider
//         Rectangle {
//             visible: inRepeater.count > 0 && outRepeater.count > 0 && rootNodeCard.typeName !== "CommentNode"
//             Layout.fillWidth: true
//             Layout.preferredHeight: 1
//             Layout.leftMargin: 14
//             Layout.rightMargin: 14
//             Layout.topMargin: 4
//             Layout.bottomMargin: 4
//             color: "#1C1C1C"
//         }
//
//         // ========================================================
//         // 4. STANDARD & GROUP OUTPUTS
//         // ========================================================
//         Repeater {
//             id: outRepeater
//             model: (rootNodeCard.typeName !== "CommentNode" && rootNodeCard.nodeData && rootNodeCard.nodeData.outputs) ? rootNodeCard.nodeData.outputs : []
//
//             delegate: Item {
//                 id: outRow
//                 Layout.fillWidth: true
//                 height: 32
//
//                 readonly property string socketId: modelData.id || ""
//                 readonly property string typeName: modelData.dataTypeName || ""
//                 readonly property Item pinItem: outPinContainer
//
//                 Rectangle {
//                     id: outputBar
//                     anchors.fill: parent
//                     anchors.leftMargin: 7
//                     anchors.rightMargin: 7
//                     radius: 8
//                     color: outputHover.hovered ? rootNodeCard.hoverBar : rootNodeCard.normalBar
//                 }
//
//                 HoverHandler { id: outputHover }
//
//                 Text {
//                     anchors.right: outputBar.right
//                     anchors.rightMargin: 11
//                     anchors.verticalCenter: outputBar.verticalCenter
//                     width: outputBar.width - 24
//                     text: modelData.name || ""
//                     color: outputHover.hovered ? "#FFFFFF" : rootNodeCard.secondaryText
//                     font.pixelSize: 10
//                     elide: Text.ElideLeft
//                     horizontalAlignment: Text.AlignRight
//                     verticalAlignment: Text.AlignVCenter
//                 }
//
//                 Item {
//                     id: outPinContainer
//                     x: parent.width - 4
//                     y: (parent.height - 8) / 2
//                     width: 8
//                     height: 8
//                     z: 20
//
//                     function updatePos() {
//                         rootNodeCard.notifyPinWorldPos(outRow.socketId, true, outPinContainer);
//                     }
//                     onXChanged: updatePos()
//                     onYChanged: updatePos()
//                     Component.onCompleted: updatePos()
//                     Connections {
//                         target: rootNodeCard
//                         function onXChanged() { outPinContainer.updatePos(); }
//                         function onYChanged() { outPinContainer.updatePos(); }
//                         function onHeightChanged() { outPinContainer.updatePos(); }
//                     }
//
//                     Rectangle {
//                         anchors.centerIn: parent
//                         width: outPinMouse.containsMouse ? 10 : 8
//                         height: outPinMouse.containsMouse ? 10 : 8
//                         rotation: 45
//                         transformOrigin: Item.Center
//                         radius: 1
//
//                         color: outPinMouse.containsMouse
//                             ? Qt.lighter(rootNodeCard.getPinColor(outRow.typeName), 1.25)
//                             : rootNodeCard.getPinColor(outRow.typeName)
//                     }
//
//                     MouseArea {
//                         id: outPinMouse
//                         anchors.centerIn: parent
//                         width: 20
//                         height: 20
//                         hoverEnabled: true
//                         cursorShape: Qt.PointingHandCursor
//
//                         onPressed: function(mouse) {
//                             var pt = outPinContainer.mapToItem(rootNodeCard.parent, 4, 4)
//                             rootNodeCard.startConnectingWire(rootNodeCard.nodeId, outRow.socketId, pt.x, pt.y)
//                         }
//
//                         onPositionChanged: function(mouse) {
//                             if (pressed) {
//                                 var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y)
//                                 rootNodeCard.updateWireDrag(pt.x, pt.y)
//                             }
//                         }
//
//                         onReleased: function(mouse) {
//                             var pt = mapToItem(rootNodeCard.parent, mouse.x, mouse.y)
//                             rootNodeCard.endConnectingWire(pt.x, pt.y)
//                         }
//                     }
//                 }
//             }
//         }
//     }
