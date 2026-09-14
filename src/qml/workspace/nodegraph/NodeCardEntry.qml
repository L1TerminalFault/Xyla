import QtQuick

Item {
    id: rootCardEntry

    // Properties expected by NodeGraphPanel
    property var nodeData: null
    property var activeModel: null
    property string activeClipId: ""
    property bool isSelected: false
    property string activeHighlightSocketId: ""

    // Quick helpers
    readonly property string nodeId: nodeData ? nodeData.id : ""
    readonly property string typeName: nodeData ? nodeData.typeName : ""

    // Signals expected by NodeGraphPanel
    signal pinPositionChanged(string nId, string sId, bool isOut, real px, real py)
    signal startConnectingWire(string nodeId, string socketId, real pinX, real pinY)
    signal updateWireDrag(real gx, real gy)
    signal endConnectingWire(real gx, real gy)
    signal nodeSelected(string nodeId, bool isShift)
    signal dragMovedDelta(real rawTargetX, real rawTargetY)
    signal dragFinished()

    // Sizing matches the active child component
    width: activeChild ? activeChild.width : 180
    height: activeChild ? activeChild.height : 120

    readonly property Item activeChild: {
        if (typeName === "GroupNode") return groupNodeItem;
        if (typeName === "GroupInputNode" || typeName === "GroupOutputNode") return groupProxyItem;
        if (typeName === "Reroute") return rerouteItem;
        if (typeName === "CommentNode") return commentItem;
        return standardNodeItem;
    }

    // Smooth position animations
    Behavior on x {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    opacity: 0.0

    Component.onCompleted: {
        Qt.callLater(function() {
            if (!rootCardEntry || !rootCardEntry.parent) return;
            if (root.resolveNewNodePlacement) {
                root.resolveNewNodePlacement(rootCardEntry.nodeId, rootCardEntry.width, rootCardEntry.height);
            }
            rootCardEntry.opacity = 1.0;
        });
    }

    // =========================================================================
    // 1. Group Node
    // =========================================================================
    GroupNodeCard {
        id: groupNodeItem
        visible: rootCardEntry.typeName === "GroupNode"
        // anchors.fill: parent
        nodeData: rootCardEntry.nodeData
        activeModel: rootCardEntry.activeModel
        activeClipId: rootCardEntry.activeClipId
        isSelected: rootCardEntry.isSelected

        onNodeSelected: function(nId, isShift) { rootCardEntry.nodeSelected(nId, isShift); }
        onDragMovedDelta: function(rx, ry) { rootCardEntry.dragMovedDelta(rx, ry); }
        onDragFinished: { rootCardEntry.dragFinished(); }
        onEnterGroupRequested: function(gId, gName) {
            // Direct call to enter group using the group's own nodeId
            root.enterGroupView(gId, gName);
        }
    }

    // =========================================================================
    // 2. Group Proxy Node (Inputs / Outputs inside Subgraph)
    // =========================================================================
    GroupProxyNodeCard {
        id: groupProxyItem
        visible: rootCardEntry.typeName === "GroupInputNode" || rootCardEntry.typeName === "GroupOutputNode"
        // anchors.fill: parent
        nodeData: rootCardEntry.nodeData
        activeModel: rootCardEntry.activeModel
        activeClipId: rootCardEntry.activeClipId
        isSelected: rootCardEntry.isSelected

        onNodeSelected: function(nId, isShift) { rootCardEntry.nodeSelected(nId, isShift); }
        onDragMovedDelta: function(rx, ry) { rootCardEntry.dragMovedDelta(rx, ry); }
        onDragFinished: { rootCardEntry.dragFinished(); }
        onPinPositionChanged: function(nId, sId, isOut, px, py) {
            rootCardEntry.pinPositionChanged(nId, sId, isOut, px, py);
        }
        onStartConnectingWire: function(nId, sId, px, py) {
            rootCardEntry.startConnectingWire(nId, sId, px, py);
        }
        onUpdateWireDrag: function(gx, gy) { rootCardEntry.updateWireDrag(gx, gy); }
        onEndConnectingWire: function(gx, gy) { rootCardEntry.endConnectingWire(gx, gy); }
    }

    // =========================================================================
    // 3. Reroute Dot Node
    // =========================================================================
    RerouteJointPill {
        id: rerouteItem
        visible: rootCardEntry.typeName === "Reroute"
        // anchors.fill: parent
        nodeData: rootCardEntry.nodeData
        isSelected: rootCardEntry.isSelected

        onNodeSelected: function(nId, isShift) { rootCardEntry.nodeSelected(nId, isShift); }
        onDragMovedDelta: function(rx, ry) { rootCardEntry.dragMovedDelta(rx, ry); }
        onDragFinished: { rootCardEntry.dragFinished(); }
        onPinPositionChanged: function(nId, sId, isOut, px, py) {
            rootCardEntry.pinPositionChanged(nId, sId, isOut, px, py);
        }
        onStartConnectingWire: function(nId, sId, px, py) {
            rootCardEntry.startConnectingWire(nId, sId, px, py);
        }
        onUpdateWireDrag: function(gx, gy) { rootCardEntry.updateWireDrag(gx, gy); }
        onEndConnectingWire: function(gx, gy) { rootCardEntry.endConnectingWire(gx, gy); }
    }

    // =========================================================================
    // 4. Comment Box Node
    // =========================================================================
    CommentNodeCard {
        id: commentItem
        visible: rootCardEntry.typeName === "CommentNode"
        // anchors.fill: parent
        nodeData: rootCardEntry.nodeData
        activeModel: rootCardEntry.activeModel
        activeClipId: rootCardEntry.activeClipId
        isSelected: rootCardEntry.isSelected

        onNodeSelected: function(nId, isShift) { rootCardEntry.nodeSelected(nId, isShift); }
        onDragMovedDelta: function(rx, ry) { rootCardEntry.dragMovedDelta(rx, ry); }
        onDragFinished: { rootCardEntry.dragFinished(); }
    }

    // =========================================================================
    // 5. Standard Node (Transform, ColorGrade, Blur, SourceNode, OutputNode)
    // =========================================================================
    NodeCard {
        id: standardNodeItem
        visible: rootCardEntry.typeName !== "GroupNode" &&
                 rootCardEntry.typeName !== "GroupInputNode" &&
                 rootCardEntry.typeName !== "GroupOutputNode" &&
                 rootCardEntry.typeName !== "Reroute" &&
                 rootCardEntry.typeName !== "CommentNode"
        // anchors.fill: parent
        nodeData: rootCardEntry.nodeData
        activeModel: rootCardEntry.activeModel
        activeClipId: rootCardEntry.activeClipId
        isSelected: rootCardEntry.isSelected

        onNodeSelected: function(nId, isShift) { rootCardEntry.nodeSelected(nId, isShift); }
        onDragMovedDelta: function(rx, ry) { rootCardEntry.dragMovedDelta(rx, ry); }
        onDragFinished: { rootCardEntry.dragFinished(); }
        onPinPositionChanged: function(nId, sId, isOut, px, py) {
            rootCardEntry.pinPositionChanged(nId, sId, isOut, px, py);
        }
        onStartConnectingWire: function(nId, sId, px, py) {
            rootCardEntry.startConnectingWire(nId, sId, px, py);
        }
        onUpdateWireDrag: function(gx, gy) { rootCardEntry.updateWireDrag(gx, gy); }
        onEndConnectingWire: function(gx, gy) { rootCardEntry.endConnectingWire(gx, gy); }
    }
}
