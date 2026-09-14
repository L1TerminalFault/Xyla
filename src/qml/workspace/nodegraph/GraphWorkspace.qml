import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

Item {
    id: graphWorkspace

    // =========================================================================
    // External Dependencies / Root Bindings Expose
    // =========================================================================
    property var root: null
    property alias cardRepeater: cardRepeater

    // Canvas Container reference for positioning math
    property var canvasContainer: null

    x: canvasContainer ? canvasContainer.width / 2 + root.panX : root.panX
    y: canvasContainer ? canvasContainer.height / 2 + root.panY : root.panY
    scale: root.zoomLevel

    // 1. Box Selection Visual
    Rectangle {
        visible: root && root.isBoxSelecting && root.selectionMode === "box"
        x: root ? Math.min(root.boxStartX, root.boxCurrentX) : 0
        y: root ? Math.min(root.boxStartY, root.boxCurrentY) : 0
        width: root ? Math.abs(root.boxCurrentX - root.boxStartX) : 0
        height: root ? Math.abs(root.boxCurrentY - root.boxStartY) : 0
        color: "#153B82F6"
        border.color: "#3B82F6"
        border.width: 1
        z: 90
    }

    // 2. Circle Selection Visual
    Rectangle {
        visible: root && root.isBoxSelecting && root.selectionMode === "circle"
        x: root ? root.boxStartX - root.circleRadius : 0
        y: root ? root.boxStartY - root.circleRadius : 0
        width: root ? root.circleRadius * 2 : 0
        height: root ? root.circleRadius * 2 : 0
        radius: root ? root.circleRadius : 0
        color: "#153B82F6"
        border.color: "#3B82F6"
        border.width: 1
        z: 90
    }

    // Alt Scissor Cutting Line
    Shape {
        anchors.fill: parent
        visible: root ? root.isCuttingScissor : false
        z: 95
        ShapePath {
            strokeColor: "#EF4444"
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [6, 4]
            fillColor: "transparent"
            startX: root ? root.scissorStartX : 0
            startY: root ? root.scissorStartY : 0
            PathLine {
                x: root ? root.scissorCurrentX : 0
                y: root ? root.scissorCurrentY : 0
            }
        }
    }

    // =============================================================================
    // Connected Wires Repeater
    // =============================================================================
    Repeater {
        id: linkRepeater
        model: root ? root.linkList : []

        delegate: Item {
            id: linkDelegate
            z: 25

            property var p1: root ? root.calculatePinGlobalPos(modelData.fromNodeId, modelData.fromSocketId, true) : {x:0, y:0}
            property var p2: root ? root.calculatePinGlobalPos(modelData.toNodeId, modelData.toSocketId, false) : {x:0, y:0}

            readonly property var path: root ? root.solveWirePath(p1, p2, modelData.fromNodeId, modelData.toNodeId) : {isBlocked: false, c1x:0, c1y:0, c2x:0, c2y:0, straightPts:[{x:0,y:0},{x:0,y:0},{x:0,y:0},{x:0,y:0}]}

            x: {
                var minX = Math.min(p1.x, p2.x, path.c1x, path.c2x);
                if (path.isBlocked && path.straightPts && path.straightPts.length > 2) {
                    minX = Math.min(minX, path.straightPts[1].x, path.straightPts[2].x);
                }
                return minX - 40;
            }
            y: {
                var minY = Math.min(p1.y, p2.y, path.c1y, path.c2y);
                if (path.isBlocked && path.straightPts && path.straightPts.length > 2) {
                    minY = Math.min(minY, path.straightPts[1].y, path.straightPts[2].y);
                }
                return minY - 40;
            }
            width: {
                var maxX = Math.max(p1.x, p2.x, path.c1x, path.c2x);
                if (path.isBlocked && path.straightPts && path.straightPts.length > 2) {
                    maxX = Math.max(maxX, path.straightPts[1].x, path.straightPts[2].x);
                }
                return Math.max(60, maxX - x + 40);
            }
            height: {
                var maxY = Math.max(p1.y, p2.y, path.c1y, path.c2y);
                if (path.isBlocked && path.straightPts && path.straightPts.length > 2) {
                    maxY = Math.max(maxY, path.straightPts[1].y, path.straightPts[2].y);
                }
                return Math.max(60, maxY - y + 40);
            }

            readonly property real sX: p1.x - x
            readonly property real sY: p1.y - y
            readonly property real eX: p2.x - x
            readonly property real eY: p2.y - y

            // 1. STRAIGHT LINE
            Shape {
                anchors.fill: parent
                visible: root ? root.wireStyle === "straight" : false

                ShapePath {
                    strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root && root.showWireColors ? "#3B82F6" : "#71717A")
                    strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.MiterJoin

                    startX: linkDelegate.sX
                    startY: linkDelegate.sY

                    PathLine {
                        x: linkDelegate.path.isBlocked && linkDelegate.path.straightPts ? (linkDelegate.path.straightPts[1].x - linkDelegate.x) : linkDelegate.eX
                        y: linkDelegate.path.isBlocked && linkDelegate.path.straightPts ? (linkDelegate.path.straightPts[1].y - linkDelegate.y) : linkDelegate.eY
                    }

                    PathLine {
                        x: linkDelegate.path.isBlocked && linkDelegate.path.straightPts ? (linkDelegate.path.straightPts[2].x - linkDelegate.x) : linkDelegate.eX
                        y: linkDelegate.path.isBlocked && linkDelegate.path.straightPts ? (linkDelegate.path.straightPts[2].y - linkDelegate.y) : linkDelegate.eY
                    }

                    PathLine {
                        x: linkDelegate.eX
                        y: linkDelegate.eY
                    }
                }
            }

            // 2. CURVED BEZIER LINE
            Shape {
                anchors.fill: parent
                visible: root ? root.wireStyle === "curve" : true

                ShapePath {
                    strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root && root.showWireColors ? "#3B82F6" : "#71717A")
                    strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: linkDelegate.sX
                    startY: linkDelegate.sY

                    PathCubic {
                        x: linkDelegate.eX
                        y: linkDelegate.eY
                        control1X: linkDelegate.path.c1x - linkDelegate.x
                        control1Y: linkDelegate.path.c1y - linkDelegate.y
                        control2X: linkDelegate.path.c2x - linkDelegate.x
                        control2Y: linkDelegate.path.c2y - linkDelegate.y
                    }
                }
            }

            MouseArea {
                id: wireHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onDoubleClicked: function (mouse) {
                    var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                    if (root) root.insertRerouteOnLink(modelData, wsPt.x, wsPt.y);
                }
            }
        }
    }

    // =============================================================================
    // 2. Interactive Dragging Wire
    // =============================================================================
    Item {
        id: pendingWireContainer
        anchors.fill: parent
        visible: root ? root.isConnectingWire : false
        z: 75

        Shape {
            anchors.fill: parent

            ShapePath {
                id: pendingPath
                strokeColor: "#60A5FA"
                strokeWidth: 2.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [5, 4]
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 0
                startY: 0

                PathCubic {
                    x: root ? root.wireMouseX : 0
                    y: root ? root.wireMouseY : 0

                    readonly property real pdx: Math.abs((root ? root.wireMouseX : 0) - pendingPath.startX)

                    control1X: root && root.wireStyle === "straight" ? (pendingPath.startX + ((root.wireMouseX - pendingPath.startX) * 0.33)) : (pendingPath.startX + Math.max(45, pdx * 0.45))
                    control1Y: pendingPath.startY

                    control2X: root && root.wireStyle === "straight" ? (pendingPath.startX + ((root.wireMouseX - pendingPath.startX) * 0.66)) : ((root ? root.wireMouseX : 0) - Math.max(45, pdx * 0.45))
                    control2Y: root ? root.wireMouseY : 0
                }
            }
        }
    }

    // =============================================================================
    // Node Group Box Containers
    // =============================================================================
    Repeater {
        model: root ? root.groupList : []

        delegate: Rectangle {
            id: groupCard
            property var b: root ? root.calculateGroupBounds(modelData) : {minX:0, minY:0, maxX:100, maxY:100}
            x: b.minX
            y: b.minY
            width: Math.max(220, b.maxX - b.minX)
            height: Math.max(160, b.maxY - b.minY)
            color: "#0c0c0c"
            border.color: groupHover.hovered ? "#404040" : "#242424"
            border.width: 1
            radius: 10
            z: 5

            HoverHandler {
                id: groupHover
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                radius: 10
                color: "#161616"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    TextInput {
                        id: groupTitleInput
                        text: modelData.name
                        color: "#e0e0e0"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        selectByMouse: true
                        Layout.fillWidth: true
                        onEditingFinished: {
                            modelData.name = text;
                        }
                    }

                    Text {
                        text: "✕"
                        color: "#777777"
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root) return;
                                var gCopy = root.groupList.slice();
                                gCopy.splice(index, 1);
                                root.groupList = gCopy;
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                property real lastX: 0
                property real lastY: 0
                onPressed: function (mouse) {
                    var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                    lastX = pt.x;
                    lastY = pt.y;
                }
                onPositionChanged: function (mouse) {
                    if (pressed && root) {
                        var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        var dx = pt.x - lastX;
                        var dy = pt.y - lastY;
                        lastX = pt.x;
                        lastY = pt.y;
                        var temp = Object.assign({}, root.nodePositions);
                        for (var m = 0; m < modelData.nodeIds.length; ++m) {
                            var mId = modelData.nodeIds[m];
                            var cur = root.getNodeCenterPos(mId, 0, 0);
                            temp[mId] = {
                                x: cur.x + dx,
                                y: cur.y + dy
                            };
                        }
                        root.nodePositions = temp;
                    }
                }
            }
        }
    }

    // Render Node Cards
    Repeater {
        id: cardRepeater
        model: root ? root.nodeList : []

        delegate: NodeCard {
            nodeData: modelData
            activeModel: root ? root.activeTimelineModel : null
            activeClipId: root ? root.currentGraphId : ""
            isSelected: root ? root.selectedNodeIds.indexOf(modelData.id) !== -1 : false

            property var initialPos: root ? root.getNodeCenterPos(modelData.id, modelData.x, modelData.y) : {x: modelData.x, y: modelData.y}
            x: initialPos.x - width / 2
            y: initialPos.y - height / 2

            onNodeSelected: function (nodeId, isShift) {
                if (!root) return;
                if (isShift) {
                    var idx = root.selectedNodeIds.indexOf(nodeId);
                    var copy = root.selectedNodeIds.slice();
                    if (idx === -1)
                        copy.push(nodeId);
                    else
                        copy.splice(idx, 1);
                    root.selectedNodeIds = copy;
                } else {
                    if (root.selectedNodeIds.indexOf(nodeId) === -1) {
                        root.selectedNodeIds = [nodeId];
                    }
                }
            }

            onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                if (!root) return;
                root.isConnectingWire = true;
                root.wireFromNodeId = nodeId;
                root.wireFromSocketId = socketId;
                pendingPath.startX = pinX;
                pendingPath.startY = pinY;
                root.wireMouseX = pinX;
                root.wireMouseY = pinY;
            }

            onUpdateWireDrag: function (gx, gy) {
                if (!root || !root.isConnectingWire)
                    return;
                var target = root.findTargetInputPinAt(gx, gy);
                if (target) {
                    root.wireMouseX = target.pinX;
                    root.wireMouseY = target.pinY;

                    if (root.activeHoveredTargetNodeId !== target.nodeId || root.activeHoveredTargetSocketId !== target.socketId) {
                        root.clearAllPinHighlights();
                        root.activeHoveredTargetNodeId = target.nodeId;
                        root.activeHoveredTargetSocketId = target.socketId;
                        if (target.cardItem) target.cardItem.activeHighlightSocketId = target.socketId;
                    }
                } else {
                    root.wireMouseX = gx;
                    root.wireMouseY = gy;
                    root.clearAllPinHighlights();
                }
            }

            onEndConnectingWire: function (gx, gy) {
                if (!root || !root.isConnectingWire)
                    return;
                var target = root.findTargetInputPinAt(gx, gy);
                if (target && root.activeTimelineModel) {
                    root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                }
                root.clearAllPinHighlights();
                root.isConnectingWire = false;
                root.wireFromNodeId = "";
                root.wireFromSocketId = "";
            }

            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                if (!root) return;
                var primaryId = modelData.id;
                var curOriginal = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);

                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                var temp = Object.assign({}, root.nodePositions);

                for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                    var sId = root.selectedNodeIds[i];
                    if (sId === primaryId) {
                        temp[sId] = {
                            x: snappedP.x,
                            y: snappedP.y
                        };
                    } else {
                        var orig = root.getNodeCenterPos(sId, 0, 0);
                        temp[sId] = {
                            x: orig.x + (snappedP.x - rawTargetX),
                            y: orig.y + (snappedP.y - rawTargetY)
                        };
                    }
                }
                root.nodePositions = temp;
            }

            onDragFinished: {
                if (!root) return;
                root.snapGuideXVisible = false;
                root.snapGuideYVisible = false;
                root.resolveAllSelectedNodesOverlap(modelData.id);

                if (root.activeTimelineModel) {
                    for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                        var sId = root.selectedNodeIds[i];
                        var pos = root.getNodeCenterPos(sId, 0, 0);
                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                    }
                }
            }
        }
    }
}




                // // Graph Workspace
                // Item {
                //     id: graphWorkspace
                //     x: canvasContainer.width / 2 + root.panX
                //     y: canvasContainer.height / 2 + root.panY
                //     scale: root.zoomLevel
                //
                //     // 1. Box Selection Visual
                //     Rectangle {
                //         visible: root.isBoxSelecting && root.selectionMode === "box"
                //         x: Math.min(root.boxStartX, root.boxCurrentX)
                //         y: Math.min(root.boxStartY, root.boxCurrentY)
                //         width: Math.abs(root.boxCurrentX - root.boxStartX)
                //         height: Math.abs(root.boxCurrentY - root.boxStartY)
                //         color: "#153B82F6"
                //         border.color: "#3B82F6"
                //         border.width: 1
                //         z: 90
                //     }
                //
                //     // 2. Circle Selection Visual
                //     Rectangle {
                //         visible: root.isBoxSelecting && root.selectionMode === "circle"
                //         x: root.boxStartX - root.circleRadius
                //         y: root.boxStartY - root.circleRadius
                //         width: root.circleRadius * 2
                //         height: root.circleRadius * 2
                //         radius: root.circleRadius
                //         color: "#153B82F6"
                //         border.color: "#3B82F6"
                //         border.width: 1
                //         z: 90
                //     }
                //
                //     // Alt Scissor Cutting Line
                //     Shape {
                //         anchors.fill: parent
                //         visible: root.isCuttingScissor
                //         z: 95
                //         ShapePath {
                //             strokeColor: "#EF4444"
                //             strokeWidth: 2
                //             strokeStyle: ShapePath.DashLine
                //             dashPattern: [6, 4]
                //             fillColor: "transparent"
                //             startX: root.scissorStartX
                //             startY: root.scissorStartY
                //             PathLine {
                //                 x: root.scissorCurrentX
                //                 y: root.scissorCurrentY
                //             }
                //         }
                //     }
                //
                //     // =============================================================
                //     // Connected Wires Repeater
                //     // =============================================================
                //     Repeater {
                //         id: linkRepeater
                //         model: root.linkList
                //
                //         delegate: Item {
                //             id: linkDelegate
                //             z: 25
                //
                //             property var p1: root.calculatePinGlobalPos(modelData.fromNodeId, modelData.fromSocketId, true)
                //             property var p2: root.calculatePinGlobalPos(modelData.toNodeId, modelData.toSocketId, false)
                //
                //             readonly property var path: root.solveWirePath(p1, p2, modelData.fromNodeId, modelData.toNodeId)
                //
                //             // Bounding box covering pins, straight corners, and bezier control points
                //             x: {
                //                 var minX = Math.min(p1.x, p2.x, path.c1x, path.c2x);
                //                 if (path.isBlocked) {
                //                     minX = Math.min(minX, path.straightPts[1].x, path.straightPts[2].x);
                //                 }
                //                 return minX - 40;
                //             }
                //             y: {
                //                 var minY = Math.min(p1.y, p2.y, path.c1y, path.c2y);
                //                 if (path.isBlocked) {
                //                     minY = Math.min(minY, path.straightPts[1].y, path.straightPts[2].y);
                //                 }
                //                 return minY - 40;
                //             }
                //             width: {
                //                 var maxX = Math.max(p1.x, p2.x, path.c1x, path.c2x);
                //                 if (path.isBlocked) {
                //                     maxX = Math.max(maxX, path.straightPts[1].x, path.straightPts[2].x);
                //                 }
                //                 return Math.max(60, maxX - x + 40);
                //             }
                //             height: {
                //                 var maxY = Math.max(p1.y, p2.y, path.c1y, path.c2y);
                //                 if (path.isBlocked) {
                //                     maxY = Math.max(maxY, path.straightPts[1].y, path.straightPts[2].y);
                //                 }
                //                 return Math.max(60, maxY - y + 40);
                //             }
                //
                //             // Local coordinates
                //             readonly property real sX: p1.x - x
                //             readonly property real sY: p1.y - y
                //             readonly property real eX: p2.x - x
                //             readonly property real eY: p2.y - y
                //
                //             // 1. STRAIGHT LINE (Direct when clear, 2-turn box detour when blocked)
                //             Shape {
                //                 anchors.fill: parent
                //                 visible: root.wireStyle === "straight"
                //
                //                 ShapePath {
                //                     strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                //                     strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                //                     fillColor: "transparent"
                //                     capStyle: ShapePath.RoundCap
                //                     joinStyle: ShapePath.MiterJoin
                //
                //                     startX: linkDelegate.sX
                //                     startY: linkDelegate.sY
                //
                //                     PathLine {
                //                         x: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[1].x - linkDelegate.x) : linkDelegate.eX
                //                         y: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[1].y - linkDelegate.y) : linkDelegate.eY
                //                     }
                //
                //                     PathLine {
                //                         x: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[2].x - linkDelegate.x) : linkDelegate.eX
                //                         y: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[2].y - linkDelegate.y) : linkDelegate.eY
                //                     }
                //
                //                     PathLine {
                //                         x: linkDelegate.eX
                //                         y: linkDelegate.eY
                //                     }
                //                 }
                //             }
                //
                //             // 2. CURVED BEZIER LINE
                //             Shape {
                //                 anchors.fill: parent
                //                 visible: root.wireStyle === "curve"
                //
                //                 ShapePath {
                //                     strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                //                     strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                //                     fillColor: "transparent"
                //                     capStyle: ShapePath.RoundCap
                //
                //                     startX: linkDelegate.sX
                //                     startY: linkDelegate.sY
                //
                //                     PathCubic {
                //                         x: linkDelegate.eX
                //                         y: linkDelegate.eY
                //                         control1X: linkDelegate.path.c1x - linkDelegate.x
                //                         control1Y: linkDelegate.path.c1y - linkDelegate.y
                //                         control2X: linkDelegate.path.c2x - linkDelegate.x
                //                         control2Y: linkDelegate.path.c2y - linkDelegate.y
                //                     }
                //                 }
                //             }
                //
                //             MouseArea {
                //                 id: wireHoverArea
                //                 anchors.fill: parent
                //                 hoverEnabled: true
                //                 cursorShape: Qt.PointingHandCursor
                //
                //                 onDoubleClicked: function (mouse) {
                //                     var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                //                     root.insertRerouteOnLink(modelData, wsPt.x, wsPt.y);
                //                 }
                //             }
                //         }
                //     }
                //
                //     // =============================================================
                //     // 2. Interactive Dragging Wire (Only visible when isConnectingWire)
                //     // =============================================================
                //     Item {
                //         id: pendingWireContainer
                //         anchors.fill: parent
                //         visible: root.isConnectingWire
                //         z: 75 // Above cards so the pending line is always crystal clear
                //
                //         Shape {
                //             anchors.fill: parent
                //
                //             ShapePath {
                //                 id: pendingPath
                //                 strokeColor: "#60A5FA"
                //                 strokeWidth: 2.5
                //                 strokeStyle: ShapePath.DashLine
                //                 dashPattern: [5, 4]
                //                 fillColor: "transparent"
                //                 capStyle: ShapePath.RoundCap
                //                 startX: 0
                //                 startY: 0
                //
                //                 PathCubic {
                //                     x: root.wireMouseX
                //                     y: root.wireMouseY
                //
                //                     readonly property real pdx: Math.abs(root.wireMouseX - pendingPath.startX)
                //
                //                     control1X: root.wireStyle === "straight" ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.33) : (pendingPath.startX + Math.max(45, pdx * 0.45))
                //                     control1Y: pendingPath.startY
                //
                //                     control2X: root.wireStyle === "straight" ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.66) : (root.wireMouseX - Math.max(45, pdx * 0.45))
                //                     control2Y: root.wireMouseY
                //                 }
                //             }
                //         }
                //     }
                //
                //     // =============================================================
                //     // Node Group Box Containers
                //     // =============================================================
                //     Repeater {
                //         model: root.groupList
                //
                //         delegate: Rectangle {
                //             id: groupCard
                //             property var b: root.calculateGroupBounds(modelData)
                //             x: b.minX
                //             y: b.minY
                //             width: Math.max(220, b.maxX - b.minX)
                //             height: Math.max(160, b.maxY - b.minY)
                //             color: "#0c0c0c"
                //             border.color: groupHover.hovered ? "#404040" : "#242424"
                //             border.width: 1
                //             radius: 10
                //             z: 5
                //
                //             HoverHandler {
                //                 id: groupHover
                //             }
                //
                //             // Header Bar with Editable Title
                //             Rectangle {
                //                 anchors.top: parent.top
                //                 anchors.left: parent.left
                //                 anchors.right: parent.right
                //                 height: 28
                //                 radius: 10
                //                 color: "#161616"
                //
                //                 RowLayout {
                //                     anchors.fill: parent
                //                     anchors.leftMargin: 10
                //                     anchors.rightMargin: 10
                //
                //                     TextInput {
                //                         id: groupTitleInput
                //                         text: modelData.name
                //                         color: "#e0e0e0"
                //                         font.pixelSize: 11
                //                         font.weight: Font.DemiBold
                //                         selectByMouse: true
                //                         Layout.fillWidth: true
                //                         onEditingFinished: {
                //                             modelData.name = text;
                //                         }
                //                     }
                //
                //                     Text {
                //                         text: "✕"
                //                         color: "#777777"
                //                         font.pixelSize: 11
                //                         MouseArea {
                //                             anchors.fill: parent
                //                             anchors.margins: -4
                //                             cursorShape: Qt.PointingHandCursor
                //                             onClicked: {
                //                                 var gCopy = root.groupList.slice();
                //                                 gCopy.splice(index, 1);
                //                                 root.groupList = gCopy;
                //                             }
                //                         }
                //                     }
                //                 }
                //             }
                //
                //             // Drag Group Box to Move All Member Nodes
                //             MouseArea {
                //                 anchors.fill: parent
                //                 z: -1
                //                 property real lastX: 0
                //                 property real lastY: 0
                //                 onPressed: function (mouse) {
                //                     var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                //                     lastX = pt.x;
                //                     lastY = pt.y;
                //                 }
                //                 onPositionChanged: function (mouse) {
                //                     if (pressed) {
                //                         var pt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                //                         var dx = pt.x - lastX;
                //                         var dy = pt.y - lastY;
                //                         lastX = pt.x;
                //                         lastY = pt.y;
                //                         var temp = Object.assign({}, root.nodePositions);
                //                         for (var m = 0; m < modelData.nodeIds.length; ++m) {
                //                             var mId = modelData.nodeIds[m];
                //                             var cur = root.getNodeCenterPos(mId, 0, 0);
                //                             temp[mId] = {
                //                                 x: cur.x + dx,
                //                                 y: cur.y + dy
                //                             };
                //                         }
                //                         root.nodePositions = temp;
                //                     }
                //                 }
                //             }
                //         }
                //     }
                //
                //     // Render Node Cards
                //     Repeater {
                //         id: cardRepeater
                //         model: root.nodeList
                //
                //         delegate: NodeCard {
                //             nodeData: modelData
                //             activeModel: root.activeTimelineModel
                //             activeClipId: root.currentGraphId
                //             isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1
                //
                //             property var initialPos: root.getNodeCenterPos(modelData.id, modelData.x, modelData.y)
                //             x: initialPos.x - width / 2
                //             y: initialPos.y - height / 2
                //
                //             onNodeSelected: function (nodeId, isShift) {
                //                 if (isShift) {
                //                     var idx = root.selectedNodeIds.indexOf(nodeId);
                //                     var copy = root.selectedNodeIds.slice();
                //                     if (idx === -1)
                //                         copy.push(nodeId);
                //                     else
                //                         copy.splice(idx, 1);
                //                     root.selectedNodeIds = copy;
                //                 } else {
                //                     if (root.selectedNodeIds.indexOf(nodeId) === -1) {
                //                         root.selectedNodeIds = [nodeId];
                //                     }
                //                 }
                //             }
                //
                //             onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                //                 root.isConnectingWire = true;
                //                 root.wireFromNodeId = nodeId;
                //                 root.wireFromSocketId = socketId;
                //                 pendingPath.startX = pinX;
                //                 pendingPath.startY = pinY;
                //                 root.wireMouseX = pinX;
                //                 root.wireMouseY = pinY;
                //             }
                //
                //             onUpdateWireDrag: function (gx, gy) {
                //                 if (!root.isConnectingWire)
                //                     return;
                //                 var target = root.findTargetInputPinAt(gx, gy);
                //                 if (target) {
                //                     // Magnetic snap wire tip directly onto the socket
                //                     root.wireMouseX = target.pinX;
                //                     root.wireMouseY = target.pinY;
                //
                //                     // Turn on hover feedback ring on target card
                //                     if (root.activeHoveredTargetNodeId !== target.nodeId || root.activeHoveredTargetSocketId !== target.socketId) {
                //                         root.clearAllPinHighlights();
                //                         root.activeHoveredTargetNodeId = target.nodeId;
                //                         root.activeHoveredTargetSocketId = target.socketId;
                //                         target.cardItem.activeHighlightSocketId = target.socketId;
                //                     }
                //                 } else {
                //                     root.wireMouseX = gx;
                //                     root.wireMouseY = gy;
                //                     root.clearAllPinHighlights();
                //                 }
                //             }
                //
                //             onEndConnectingWire: function (gx, gy) {
                //                 if (!root.isConnectingWire)
                //                     return;
                //                 var target = root.findTargetInputPinAt(gx, gy);
                //                 if (target && root.activeTimelineModel) {
                //                     root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                //                 }
                //                 // Clean up dragging state immediately so it never gets stuck
                //                 root.clearAllPinHighlights();
                //                 root.isConnectingWire = false;
                //                 root.wireFromNodeId = "";
                //                 root.wireFromSocketId = "";
                //             }
                //
                //             // Signals: rawTargetX, rawTargetY of the dragged card
                //             onDragMovedDelta: function (rawTargetX, rawTargetY) {
                //                 var primaryId = modelData.id;
                //                 var curOriginal = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                //
                //                 // Apply snap calculation with zero drag offset buildup
                //                 var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                //                 var effectiveDx = snappedP.x - curOriginal.x;
                //                 var effectiveDy = snappedP.y - curOriginal.y;
                //
                //                 var temp = Object.assign({}, root.nodePositions);
                //
                //                 // Move all selected nodes together maintaining exact relative spacing
                //                 for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                //                     var sId = root.selectedNodeIds[i];
                //                     var initialPos = root.getNodeCenterPos(sId, 0, 0);
                //                     if (sId === primaryId) {
                //                         temp[sId] = {
                //                             x: snappedP.x,
                //                             y: snappedP.y
                //                         };
                //                     } else {
                //                         var orig = root.getNodeCenterPos(sId, 0, 0);
                //                         temp[sId] = {
                //                             x: orig.x + (snappedP.x - rawTargetX),
                //                             y: orig.y + (snappedP.y - rawTargetY)
                //                         };
                //                     }
                //                 }
                //                 root.nodePositions = temp;
                //             }
                //
                //             onDragFinished: {
                //                 root.snapGuideXVisible = false;
                //                 root.snapGuideYVisible = false;
                //                 root.resolveAllSelectedNodesOverlap(modelData.id);
                //
                //                 if (root.activeTimelineModel) {
                //                     for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                //                         var sId = root.selectedNodeIds[i];
                //                         var pos = root.getNodeCenterPos(sId, 0, 0);
                //                         root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                //                     }
                //                 }
                //             }
                //         }
                //     }
                // }
