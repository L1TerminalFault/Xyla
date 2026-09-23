import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "./nodegraph"

Item {
    id: root

    readonly property color bgDark: "#1a1a1a"
    readonly property color canvasBg: "#121212"

    // -------------------------------------------------------------------------
    // Single Source of Truth for What Graph Is Being Viewed & Edited
    // -------------------------------------------------------------------------
    property var activeGraphController: typeof nodeGraphController !== "undefined" ? nodeGraphController : null
    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    // Unified helper: queries nodeGraphController with safe fallback
    readonly property var graphEngine: activeGraphController || activeTimelineModel

    property string activeSelectedClipId: activeTimelineModel ? (activeTimelineModel.selectedClipId || "") : ""

    // Cursor tracking for popup placement & mouse spawning
    property real currentMouseScreenX: 0
    property real currentMouseScreenY: 0
    property real currentMouseWorkspaceX: 0
    property real currentMouseWorkspaceY: 0

    // The single authoritative viewed graph ID
    property string activeGraphId: {
        if (!graphEngine)
            return "default_io_graph";

        if (activeSelectedClipId !== "" && typeof graphEngine.getClipActiveGraphId === "function") {
            return graphEngine.getClipActiveGraphId(activeSelectedClipId);
        }

        if (typeof graphEngine.getStandaloneActiveGraphId === "function") {
            return graphEngine.getStandaloneActiveGraphId();
        }

        return "default_io_graph";
    }

    // Subgraph / Group Drill-Down Navigation Stack
    property var navStack: [
        {
            id: activeGraphId,
            name: "Main Graph"
        }
    ]
    property string activeViewingGroupId: "" // Empty means viewing main graph level

    function enterGroupView(groupId, groupName) {
        if (!groupId || groupId === "")
            return;
        activeViewingGroupId = groupId;
        var copy = navStack.slice();
        copy.push({
            id: groupId,
            name: groupName ? groupName : "Group"
        });
        navStack = copy;
        deselectAllNodes();
        notifyGraphStateChanged();
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function jumpOutOfGroup() {
        if (navStack.length <= 1)
            return;
        var copy = navStack.slice();
        copy.pop();
        navStack = copy;
        activeViewingGroupId = (navStack.length > 1) ? navStack[navStack.length - 1].id : "";
        deselectAllNodes();
        notifyGraphStateChanged();
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    // Compute map of which nodes belong to which group
    readonly property var groupMembershipMap: {
        var _ = root.graphRevision;
        var map = {};
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.typeName === "GroupNode" && n.memberNodeIds) {
                for (var m = 0; m < n.memberNodeIds.length; ++m) {
                    map[n.memberNodeIds[m]] = n.id;
                }
            }
        }
        return map;
    }

    // Nodes visible in the current viewing scope
    readonly property var visibleNodeList: {
        var list = [];
        for (var i = 0; i < nodeList.length; ++i) {
            var node = nodeList[i];
            var parentGroupId = groupMembershipMap[node.id];

            if (root.activeViewingGroupId === "") {
                if (!parentGroupId) {
                    list.push(node);
                }
            } else {
                if (parentGroupId === root.activeViewingGroupId) {
                    list.push(node);
                }
            }
        }
        return list;
    }

    // Links visible in the current viewing scope
    readonly property var visibleLinkList: {
        var visibleIds = visibleNodeList.map(function (n) {
            return n.id;
        });
        var links = [];
        for (var j = 0; j < linkList.length; ++j) {
            var l = linkList[j];
            if (visibleIds.indexOf(l.fromNodeId) !== -1 && visibleIds.indexOf(l.toNodeId) !== -1) {
                links.push(l);
            }
        }
        return links;
    }

    function createGroupFromSelected() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || selectedNodeIds.length < 2)
            return;

        var membersToGroup = selectedNodeIds.slice();

        var avgX = 0, avgY = 0;
        for (var i = 0; i < membersToGroup.length; ++i) {
            var p = getNodeCenterPos(membersToGroup[i], 0, 0);
            avgX += p.x;
            avgY += p.y;
        }
        avgX = Math.round((avgX / membersToGroup.length) / 24) * 24;
        avgY = Math.round((avgY / membersToGroup.length) / 24) * 24;

        var newGroupId = "";
        if (typeof root.graphEngine.addNodeToGraph === "function") {
            newGroupId = root.graphEngine.addNodeToGraph(root.activeGraphId, "GroupNode", avgX, avgY);
        }

        if (newGroupId && newGroupId !== "") {
            root.nodePositions[newGroupId] = {
                x: avgX,
                y: avgY
            };

            if (typeof root.graphEngine.setGroupMemberNodeIds === "function") {
                root.graphEngine.setGroupMemberNodeIds(root.activeGraphId, newGroupId, membersToGroup);
            }

            selectedNodeIds = [newGroupId];
        }

        root.notifyGraphStateChanged();
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function handleDropCardOnContainers(droppedNodeId, centerX, centerY) {
        for (var c = 0; c < commentRepeater.count; ++c) {
            var commentItem = commentRepeater.itemAt(c);
            if (commentItem && commentItem.checkNodeDropIntersection(droppedNodeId, centerX, centerY)) {
                commentItem.acceptDroppedNode(droppedNodeId);
                return;
            }
        }

        for (var g = 0; g < groupRepeater.count; ++g) {
            var groupItem = groupRepeater.itemAt(g);
            if (groupItem && groupItem.checkNodeDropIntersection(droppedNodeId, centerX, centerY)) {
                groupItem.acceptDroppedNode(droppedNodeId);
                return;
            }
        }
    }

    // =========================================================================
    // CLIPBOARD ENGINE (Copy, Cut, Paste)
    // =========================================================================
    property var clipboardNodes: []

    function copySelectedNodes() {
        if (selectedNodeIds.length === 0)
            return;
        var copied = [];
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var nId = selectedNodeIds[i];
            for (var j = 0; j < nodeList.length; ++j) {
                if (nodeList[j].id === nId) {
                    var curPos = getNodeCenterPos(nId, nodeList[j].x, nodeList[j].y);
                    copied.push({
                        typeName: nodeList[j].typeName,
                        name: nodeList[j].name,
                        x: curPos.x,
                        y: curPos.y
                    });
                    break;
                }
            }
        }
        clipboardNodes = copied;
    }

    function cutSelectedNodes() {
        copySelectedNodes();
        deleteSelectedNodes();
    }

    function pasteNodes() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || clipboardNodes.length === 0)
            return;

        var newSelected = [];
        var offsetX = 40;
        var offsetY = 40;

        for (var i = 0; i < clipboardNodes.length; ++i) {
            var item = clipboardNodes[i];
            var posX = item.x + offsetX;
            var posY = item.y + offsetY;

            var newId = "";
            if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, item.typeName, posX, posY);
            }
            if (newId && newId !== "") {
                newSelected.push(newId);
                root.nodePositions[newId] = {
                    x: posX,
                    y: posY
                };
            }
        }

        selectedNodeIds = newSelected;
        root.notifyGraphStateChanged();
        root.pinRevision++;
    }

    // =========================================================================
    // Dynamic Placement Resolver
    // =========================================================================
    function resolveNewNodePlacement(nId, realW, realH) {
        var cur = getNodeCenterPos(nId, 0, 0);
        var gutter = 28;

        if (!isPositionColliding(nId, cur.x, cur.y, realW, realH, root.nodePositions, gutter)) {
            return;
        }

        var bestX = Math.round(cur.x / 24) * 24;
        var bestY = Math.round(cur.y / 24) * 24;
        var found = false;

        for (var step = 1; step <= 60; ++step) {
            var r = step * 24;
            var candidates = [
                {
                    x: bestX + r,
                    y: bestY
                },
                {
                    x: bestX,
                    y: bestY + r
                },
                {
                    x: bestX + r,
                    y: bestY + r
                },
                {
                    x: bestX - r,
                    y: bestY
                },
                {
                    x: bestX,
                    y: bestY - r
                },
                {
                    x: bestX - r,
                    y: bestY + r
                },
                {
                    x: bestX + r,
                    y: bestY - r
                },
                {
                    x: bestX - r,
                    y: bestY - r
                }
            ];

            for (var c = 0; c < candidates.length; ++c) {
                if (!isPositionColliding(nId, candidates[c].x, candidates[c].y, realW, realH, root.nodePositions, gutter)) {
                    bestX = candidates[c].x;
                    bestY = candidates[c].y;
                    found = true;
                    break;
                }
            }
            if (found)
                break;
        }

        var temp = Object.assign({}, root.nodePositions);
        temp[nId] = {
            x: bestX,
            y: bestY
        };
        root.nodePositions = temp;

        if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
            root.graphEngine.setNodePosition(root.activeGraphId, nId, bestX, bestY);
        }

        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    // =========================================================================
    // Deletion with Instant UI Refresh
    // =========================================================================
    function deleteSelectedNodes() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var idToDelete = selectedNodeIds[i];
            if (typeof root.graphEngine.removeNodeFromGraph === "function") {
                root.graphEngine.removeNodeFromGraph(root.activeGraphId, idToDelete);
            } else if (typeof root.graphEngine.removeNode === "function") {
                root.graphEngine.removeNode(root.activeGraphId, idToDelete);
            }
            delete root.nodePositions[idToDelete];
        }

        selectedNodeIds = [];
        root.notifyGraphStateChanged();
        root.pinRevision++;
    }

    // =========================================================================
    // Grid Snap & Alignment Operations
    // =========================================================================
    function snapSelectedToGrid() {
        var gridSize = 24;
        var temp = Object.assign({}, root.nodePositions);
        var targetIds = selectedNodeIds.length > 0 ? selectedNodeIds : nodeList.map(function (n) {
            return n.id;
        });

        for (var i = 0; i < targetIds.length; ++i) {
            var id = targetIds[i];
            var cur = getNodeCenterPos(id, 0, 0);
            var sx = Math.round(cur.x / gridSize) * gridSize;
            var sy = Math.round(cur.y / gridSize) * gridSize;
            temp[id] = {
                x: sx,
                y: sy
            };
            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, id, sx, sy);
            }
        }
        root.nodePositions = temp;
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function alignSelectedLeft() {
        if (selectedNodeIds.length < 2)
            return;
        var minX = Infinity;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            minX = Math.min(minX, getNodeCenterPos(selectedNodeIds[i], 0, 0).x);
        }
        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            temp[id] = {
                x: minX,
                y: getNodeCenterPos(id, 0, 0).y
            };
        }
        root.nodePositions = temp;

        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);

        for (var k = 0; k < selectedNodeIds.length; ++k) {
            var nId = selectedNodeIds[k];
            var p = root.getNodeCenterPos(nId, 0, 0);
            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, nId, p.x, p.y);
            }
        }
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function alignSelectedTop() {
        if (selectedNodeIds.length < 2)
            return;
        var minY = Infinity;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            minY = Math.min(minY, getNodeCenterPos(selectedNodeIds[i], 0, 0).y);
        }
        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            temp[id] = {
                x: getNodeCenterPos(id, 0, 0).x,
                y: minY
            };
        }
        root.nodePositions = temp;

        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);

        for (var k = 0; k < selectedNodeIds.length; ++k) {
            var nId = selectedNodeIds[k];
            var p = root.getNodeCenterPos(nId, 0, 0);
            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, nId, p.x, p.y);
            }
        }
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function distributeSelectedHorizontally() {
        if (selectedNodeIds.length < 3)
            return;
        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).x - getNodeCenterPos(b, 0, 0).x;
        });
        var startX = getNodeCenterPos(sorted[0], 0, 0).x;
        var endX = getNodeCenterPos(sorted[sorted.length - 1], 0, 0).x;
        var step = (endX - startX) / (sorted.length - 1);
        var temp = Object.assign({}, root.nodePositions);
        for (var i = 0; i < sorted.length; ++i) {
            var id = sorted[i];
            var newX = Math.round(startX + (i * step));
            var curY = getNodeCenterPos(id, 0, 0).y;
            temp[id] = {
                x: newX,
                y: curY
            };
            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, id, newX, curY);
            }
        }
        root.nodePositions = temp;
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    property var pinRegistry: ({})
    property int pinRevision: 0

    function registerPinPosition(nodeId, socketId, isOutput, wsX, wsY) {
        if (isNaN(wsX) || isNaN(wsY))
            return;
        var key = nodeId + ":" + socketId + ":" + (isOutput ? "out" : "in");
        pinRegistry[key] = Qt.point(wsX, wsY);
        pinRevision++;
    }

    function getRegisteredPinPos(nodeId, socketId, isOutput) {
        if (!nodeId || !socketId)
            return Qt.point(0, 0);

        if (typeof cardRepeater !== "undefined" && cardRepeater) {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var card = cardRepeater.itemAt(i);
                if (card && card.nodeId === nodeId && typeof card.getPinCenterInWorkspace === "function") {
                    var pt = card.getPinCenterInWorkspace(socketId, isOutput);
                    if (pt && !isNaN(pt.x) && !isNaN(pt.y)) {
                        return pt;
                    }
                }
            }
        }

        return calculatePinGlobalPos(nodeId, socketId, isOutput);
    }

    readonly property string currentGraphId: activeGraphId
    readonly property bool isCurrentGraphReadOnly: currentGraphId === "default_io_graph"
    readonly property string currentGraphName: {
        if (!graphEngine || isCurrentGraphReadOnly || typeof graphEngine.getGraphName !== "function")
            return "Default";
        var n = graphEngine.getGraphName(activeGraphId);
        return (n && n !== "") ? n : "Untitled Graph";
    }

    property bool isCurrentGraphLinked: false

    function refreshLinkState() {
        if (!graphEngine || activeSelectedClipId === "" || isCurrentGraphReadOnly) {
            isCurrentGraphLinked = false;
            return;
        }
        if (typeof graphEngine.getClipAttachedGraphs !== "function") {
            isCurrentGraphLinked = false;
            return;
        }
        var attached = graphEngine.getClipAttachedGraphs(activeSelectedClipId) || [];
        var found = false;
        for (var i = 0; i < attached.length; ++i) {
            if (attached[i].id === activeGraphId) {
                found = true;
                break;
            }
        }
        isCurrentGraphLinked = found;
    }

    function selectGraph(targetId) {
        if (!targetId || targetId === "")
            return;
        activeGraphId = targetId;
        if (graphEngine && typeof graphEngine.setStandaloneActiveGraphId === "function") {
            graphEngine.setStandaloneActiveGraphId(targetId);
        }
        refreshLinkState();
        if (typeof tabBar !== "undefined" && tabBar && tabBar.graphSelectWrapper && tabBar.graphSelectWrapper.refreshGraphs) {
            tabBar.graphSelectWrapper.refreshGraphs();
        }
    }

    onActiveSelectedClipIdChanged: {
        if (graphEngine && activeSelectedClipId !== "" && typeof graphEngine.getClipAttachedGraphs === "function") {
            var attached = graphEngine.getClipAttachedGraphs(activeSelectedClipId) || [];
            var lastUserGraphId = "";

            for (var i = attached.length - 1; i >= 0; --i) {
                if (attached[i].id !== "default_io_graph" && !attached[i].isDefault) {
                    lastUserGraphId = attached[i].id;
                    break;
                }
            }

            if (lastUserGraphId !== "") {
                selectGraph(lastUserGraphId);
                return;
            }
        }

        var allG = (graphEngine && typeof graphEngine.getAllProjectGraphs === "function") ? (graphEngine.getAllProjectGraphs() || []) : [];

        for (var j = allG.length - 1; j >= 0; --j) {
            if (allG[j].id !== "default_io_graph" && !allG[j].isDefault) {
                selectGraph(allG[j].id);
                return;
            }
        }

        selectGraph("default_io_graph");
    }

    property int graphRevision: 0
    function notifyGraphStateChanged() {
        Qt.callLater(function () {
            root.graphRevision++;
            if (dagCanvas && dagCanvas.requestPaint) {
                dagCanvas.requestPaint();
            }
        });
    }

    Connections {
        target: root.graphEngine

        function onProjectGraphsChanged() {
            root.notifyGraphStateChanged();
            if (typeof tabBar !== "undefined" && tabBar && tabBar.graphSelectWrapper && tabBar.graphSelectWrapper.refreshGraphs) {
                tabBar.graphSelectWrapper.refreshGraphs();
            }
            refreshLinkState();
        }

        function onActiveGraphChanged() {
            refreshLinkState();
        }
    }

    readonly property bool isCurrentGraphAttachedToClip: {
        if (!graphEngine || activeSelectedClipId === "" || typeof graphEngine.getClipAttachedGraphs !== "function")
            return false;
        var attached = graphEngine.getClipAttachedGraphs(activeSelectedClipId) || [];
        for (var i = 0; i < attached.length; ++i) {
            if (attached[i].id === activeGraphId)
                return true;
        }
        return false;
    }

    readonly property var nodeList: {
        var _ = root.graphRevision;
        if (graphEngine && typeof graphEngine.getGraphNodes === "function") {
            return graphEngine.getGraphNodes(activeGraphId) || [];
        }
        return [];
    }

    readonly property var linkList: {
        var _ = root.graphRevision;
        if (graphEngine && typeof graphEngine.getGraphLinks === "function") {
            return graphEngine.getGraphLinks(activeGraphId) || [];
        }
        return [];
    }

    property var selectedClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    property real zoomLevel: 1.0
    property real panX: 0.0
    property real panY: 0.0

    property real targetZoom: 1.0
    property real targetPanX: 0.0
    property real targetPanY: 0.0
    property real wireCurvatureFactor: (typeof wireStyle !== "undefined" && wireStyle === "straight") ? 0.0 : 1.0

    function computeWireDetourOffset(p1, p2, fromId, toId) {
        if (!p1 || !p2 || isNaN(p1.x) || isNaN(p2.x))
            return 0;
        var midX = (p1.x + p2.x) / 2;
        var midY = (p1.y + p2.y) / 2;

        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.id === fromId || n.id === toId)
                continue;
            var pos = getNodeCenterPos(n.id, n.x, n.y);
            var w = 180;
            var h = getNodeRealHeight(n.id);

            var boxLeft = pos.x - w / 2 - 16;
            var boxRight = pos.x + w / 2 + 16;
            var boxTop = pos.y - h / 2 - 16;
            var boxBottom = pos.y + h / 2 + 16;

            if (midX >= boxLeft && midX <= boxRight && midY >= boxTop && midY <= boxBottom) {
                var pushAbove = boxTop - midY;
                var pushBelow = boxBottom - midY;
                return (Math.abs(pushAbove) < Math.abs(pushBelow)) ? pushAbove : pushBelow;
            }
        }
        return 0;
    }

    function getNodeBoundingBox(nodeId, pad) {
        var pos = getNodeCenterPos(nodeId, 0, 0);
        var w = 180;
        var h = getNodeRealHeight(nodeId);
        var p = (pad !== undefined) ? pad : 12;
        return {
            left: pos.x - w / 2 - p,
            right: pos.x + w / 2 + p,
            top: pos.y - h / 2 - p,
            bottom: pos.y + h / 2 + p,
            centerX: pos.x,
            centerY: pos.y,
            width: w,
            height: h
        };
    }

    function lineIntersectsBox(p1x, p1y, p2x, p2y, left, top, right, bottom) {
        if ((p1x < left && p2x < left) || (p1x > right && p2x > right) || (p1y < top && p2y < top) || (p1y > bottom && p2y > bottom)) {
            return false;
        }
        if (p1x >= left && p1x <= right && p1y >= top && p1y <= bottom)
            return true;
        if (p2x >= left && p2x <= right && p2y >= top && p2y <= bottom)
            return true;

        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, right, top))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, bottom, right, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, left, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, right, top, right, bottom))
            return true;

        return false;
    }

    function lineHitsCardBox(p1x, p1y, p2x, p2y, left, top, right, bottom) {
        if ((p1x < left && p2x < left) || (p1x > right && p2x > right) || (p1y < top && p2y < top) || (p1y > bottom && p2y > bottom)) {
            return false;
        }
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, right, top))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, bottom, right, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, left, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, right, top, right, bottom))
            return true;

        var midX = (p1x + p2x) / 2;
        var midY = (p1y + p2y) / 2;
        if (midX >= left && midX <= right && midY >= top && midY <= bottom)
            return true;

        return false;
    }

    function solveWirePath(p1, p2, fromId, toId) {
        var dx = Math.abs(p2.x - p1.x);
        var tension = Math.max(40, Math.min(180, dx * 0.5));
        if (p2.x < p1.x) {
            tension = Math.max(60, dx * 0.4 + 40);
        }
        return {
            isBlocked: false,
            straightPts: [Qt.point(p1.x, p1.y), Qt.point(p2.x, p2.y)],
            c1x: p1.x + tension,
            c1y: p1.y,
            c2x: p2.x - tension,
            c2y: p2.y
        };
    }

    function testCardCollisionAt(cx, cy, w, h, excludeNodeId) {
        var gutter = 24;
        var myL = cx - w / 2;
        var myR = cx + w / 2;
        var myT = cy - h / 2;
        var myB = cy + h / 2;

        for (var i = 0; i < nodeList.length; ++i) {
            var other = nodeList[i];
            if (other.id === excludeNodeId)
                continue;

            var oPos = getNodeCenterPos(other.id, other.x, other.y);
            var oW = 180;
            var oH = getNodeRealHeight(other.id);

            var oL = oPos.x - oW / 2;
            var oR = oPos.x + oW / 2;
            var oT = oPos.y - oH / 2;
            var oB = oPos.y + oH / 2;

            if (myL < oR + gutter && myR > oL - gutter && myT < oB + gutter && myB > oT - gutter) {
                return true;
            }
        }
        return false;
    }

    function resolveAllSelectedNodesOverlap(primaryMovedId) {
    }
    // Helper: checks collision of a candidate rectangle against all other nodes
    function isPositionColliding(testId, cx, cy, w, h, positionsMap, gutter) {
        var myL = cx - w / 2;
        var myR = cx + w / 2;
        var myT = cy - h / 2;
        var myB = cy + h / 2;

        for (var i = 0; i < nodeList.length; ++i) {
            var o = nodeList[i];
            if (o.id === testId)
                continue;

            var oPos = (positionsMap[o.id] !== undefined) ? positionsMap[o.id] : root.getNodeCenterPos(o.id, o.x, o.y);
            var oW = 180;
            var oH = root.getNodeRealHeight(o.id);

            var oL = oPos.x - oW / 2;
            var oR = oPos.x + oW / 2;
            var oT = oPos.y - oH / 2;
            var oB = oPos.y + oH / 2;

            if (myL < oR + gutter && myR > oL - gutter && myT < oB + gutter && myB > oT - gutter) {
                return true;
            }
        }
        return false;
    }

    Behavior on wireCurvatureFactor {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Behavior on zoomLevel {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
    Behavior on panX {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
    Behavior on panY {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    property var groupList: []

    // Check if line (p1 -> p2) passes through a node card box
    function findInterveningObstacle(p1, p2, fromId, toId) {
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.id === fromId || n.id === toId)
                continue;
            var pos = getNodeCenterPos(n.id, n.x, n.y);
            var w = 180;
            var h = getNodeRealHeight(n.id);
            var left = pos.x - w / 2 - 16;
            var right = pos.x + w / 2 + 16;
            var top = pos.y - h / 2 - 16;
            var bottom = pos.y + h / 2 + 16;

            if (linesIntersect(p1.x, p1.y, p2.x, p2.y, left, top, right, top) || linesIntersect(p1.x, p1.y, p2.x, p2.y, left, bottom, right, bottom) || linesIntersect(p1.x, p1.y, p2.x, p2.y, left, top, left, bottom) || linesIntersect(p1.x, p1.y, p2.x, p2.y, right, top, right, bottom)) {
                return {
                    x: pos.x,
                    y: pos.y,
                    top: top,
                    bottom: bottom,
                    left: left,
                    right: right
                };
            }
        }
        return null;
    }

    // Returns the exact real height of any node (whether collapsed or expanded)
    function getNodeRealHeight(nodeId) {
        if (typeof cardRepeater !== "undefined" && cardRepeater) {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var c = cardRepeater.itemAt(i);
                if (c && c.nodeId === nodeId) {
                    return c.height;
                }
            }
        }
        for (var j = 0; j < nodeList.length; ++j) {
            if (nodeList[j].id === nodeId) {
                var n = nodeList[j];
                var inCount = (n.inputs ? n.inputs.length : 0);
                var outCount = (n.outputs ? n.outputs.length : 0);
                return Math.max(42, 28 + 8 + ((inCount + outCount) * 28) + 14);
            }
        }
        return 90;
    }

    function calculateGroupBounds(groupData) {
        var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
        for (var i = 0; i < groupData.nodeIds.length; ++i) {
            var pos = getNodeCenterPos(groupData.nodeIds[i], 0, 0);
            minX = Math.min(minX, pos.x - 105);
            maxX = Math.max(maxX, pos.x + 105);
            minY = Math.min(minY, pos.y - 65);
            maxY = Math.max(maxY, pos.y + 65);
        }
        if (minX === Infinity)
            return {
                minX: 0,
                maxX: 200,
                minY: 0,
                maxY: 150
            };
        return {
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY
        };
    }

    // =========================================================================
    // Nearest-Free-Space Solver
    // =========================================================================
    function findFreeSpaceAround(targetX, targetY, excludeId) {
        var cardW = 180;
        var cardH = 110;
        var gutter = 24;

        var startX = Math.round(targetX / 24) * 24;
        var startY = Math.round(targetY / 24) * 24;

        if (!isPositionColliding(excludeId, startX, startY, cardW, cardH, root.nodePositions, gutter)) {
            return Qt.point(startX, startY);
        }

        for (var step = 1; step <= 35; ++step) {
            var rX = step * 24;
            var rY = step * 24;

            var offsets = [
                {
                    x: rX,
                    y: 0
                },
                {
                    x: 0,
                    y: rY
                },
                {
                    x: rX,
                    y: rY
                },
                {
                    x: -rX,
                    y: 0
                },
                {
                    x: 0,
                    y: -rY
                },
                {
                    x: rX,
                    y: -rY
                },
                {
                    x: -rX,
                    y: rY
                },
                {
                    x: -rX,
                    y: -rY
                }
            ];

            for (var i = 0; i < offsets.length; ++i) {
                var testX = startX + offsets[i].x;
                var testY = startY + offsets[i].y;

                if (!isPositionColliding(excludeId, testX, testY, cardW, cardH, root.nodePositions, gutter)) {
                    return Qt.point(testX, testY);
                }
            }
        }

        return Qt.point(startX + 200, startY);
    }

    function isSpaceOccupied(x, y, w, h, excludeId) {
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.id === excludeId)
                continue;
            var pos = getNodeCenterPos(n.id, n.x, n.y);
            var actualH = getNodeRealHeight(n.id);
            var dx = Math.abs(pos.x - x);
            var dy = Math.abs(pos.y - y);
            if (dx < (w + 24) && dy < (Math.max(h, actualH) + 24)) {
                return true;
            }
        }
        return false;
    }

    onZoomLevelChanged: if (dagCanvas && dagCanvas.requestPaint)
        dagCanvas.requestPaint()
    onPanXChanged: if (dagCanvas && dagCanvas.requestPaint)
        dagCanvas.requestPaint()
    onPanYChanged: if (dagCanvas && dagCanvas.requestPaint)
        dagCanvas.requestPaint()

    function smoothNavigateTo(newPanX, newPanY, newZoom) {
        root.zoomLevel = newZoom;
        root.panX = newPanX;
        root.panY = newPanY;
    }

    property var nodePositions: ({})

    HoverHandler {
        onHoveredChanged: if (hovered && typeof layoutController !== "undefined" && layoutController)
            layoutController.setActiveDockId("NodegraphPanel")
    }

    property bool showGrid: true
    property bool isSnappingEnabled: true
    property string wireStyle: "curve"

    property var selectedNodeIds: []
    property bool isBoxSelecting: false
    property real boxStartX: 0
    property real boxStartY: 0
    property real boxCurrentX: 0
    property real boxCurrentY: 0

    property bool isConnectingWire: false
    property string wireFromNodeId: ""
    property string wireFromSocketId: ""
    property real wireMouseX: 0
    property real wireMouseY: 0

    property bool isAltPressed: false
    property bool isCuttingScissor: false
    property real scissorStartX: 0
    property real scissorStartY: 0
    property real scissorCurrentX: 0
    property real scissorCurrentY: 0

    property bool snapGuideXVisible: false
    property bool snapGuideYVisible: false
    property real snapGuideXPos: 0
    property real snapGuideYPos: 0

    function computeSnappedPosition(movingNodeId, rawCenterX, rawCenterY) {
        snapGuideXVisible = false;
        snapGuideYVisible = false;
        return {
            x: rawCenterX,
            y: rawCenterY
        };
    }

    property string selectionMode: "box"
    property real circleRadius: 0
    property var lassoPoints: []

    function getNodeCenterPos(nodeId, defaultX, defaultY) {
        if (nodePositions[nodeId] !== undefined && nodePositions[nodeId] !== null) {
            return nodePositions[nodeId];
        }
        var defX = (defaultX !== undefined && defaultX !== null) ? Number(defaultX) : 0;
        var defY = (defaultY !== undefined && defaultY !== null) ? Number(defaultY) : 0;
        return {
            x: defX,
            y: defY
        };
    }

    function segmentsIntersect(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y) {
        var d = (p2x - p1x) * (p4y - p3y) - (p2y - p1y) * (p4x - p3x);
        if (Math.abs(d) < 1e-9)
            return false;
        var u = ((p3x - p1x) * (p4y - p3y) - (p3y - p1y) * (p4x - p3x)) / d;
        var v = ((p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x)) / d;
        return (u >= 0.0 && u <= 1.0 && v >= 0.0 && v <= 1.0);
    }

    function isPointInPoly(px, py, poly) {
        var inside = false;
        for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            var xi = poly[i].x, yi = poly[i].y;
            var xj = poly[j].x, yj = poly[j].y;
            var intersect = ((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi);
            if (intersect)
                inside = !inside;
        }
        return inside;
    }

    function isCardIntersectingLasso(nodeId, poly) {
        if (!poly || poly.length < 3)
            return false;

        var center = getNodeCenterPos(nodeId, 0, 0);
        var w = 180;
        var h = getNodeRealHeight(nodeId);
        var cL = center.x - w / 2;
        var cR = center.x + w / 2;
        var cT = center.y - h / 2;
        var cB = center.y + h / 2;

        if (isPointInPoly(cL, cT, poly) || isPointInPoly(cR, cT, poly) || isPointInPoly(cL, cB, poly) || isPointInPoly(cR, cB, poly)) {
            return true;
        }

        for (var p = 0; p < poly.length; ++p) {
            var pt = poly[p];
            if (pt.x >= cL && pt.x <= cR && pt.y >= cT && pt.y <= cB) {
                return true;
            }
        }

        var cardEdges = [
            {
                x1: cL,
                y1: cT,
                x2: cR,
                y2: cT
            },
            {
                x1: cR,
                y1: cT,
                x2: cR,
                y2: cB
            },
            {
                x1: cR,
                y1: cB,
                x2: cL,
                y2: cB
            },
            {
                x1: cL,
                y1: cB,
                x2: cL,
                y2: cT
            }
        ];

        for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            var lx1 = poly[j].x, ly1 = poly[j].y;
            var lx2 = poly[i].x, ly2 = poly[i].y;

            for (var e = 0; e < 4; ++e) {
                var ce = cardEdges[e];
                if (segmentsIntersect(lx1, ly1, lx2, ly2, ce.x1, ce.y1, ce.x2, ce.y2)) {
                    return true;
                }
            }
        }

        return false;
    }

    function nodeIntersectsLasso(nodeBox, poly) {
        if (!poly || poly.length < 3)
            return false;
        var left = nodeBox.x, right = nodeBox.x + nodeBox.w;
        var top = nodeBox.y, bottom = nodeBox.y + nodeBox.h;

        var testPoints = [
            {
                x: left,
                y: top
            },
            {
                x: right,
                y: top
            },
            {
                x: left,
                y: bottom
            },
            {
                x: right,
                y: bottom
            },
            {
                x: (left + right) / 2,
                y: (top + bottom) / 2
            }
        ];
        for (var p = 0; p < testPoints.length; ++p) {
            if (isPointInPoly(testPoints[p].x, testPoints[p].y, poly))
                return true;
        }

        for (var v = 0; v < poly.length; ++v) {
            if (poly[v].x >= left && poly[v].x <= right && poly[v].y >= top && poly[v].y <= bottom) {
                return true;
            }
        }

        var edges = [[left, top, right, top], [right, top, right, bottom], [right, bottom, left, bottom], [left, bottom, left, top]];
        for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            for (var e = 0; e < 4; ++e) {
                if (segmentsIntersect(poly[j].x, poly[j].y, poly[i].x, poly[i].y, edges[e][0], edges[e][1], edges[e][2], edges[e][3])) {
                    return true;
                }
            }
        }
        return false;
    }

    function alignSelectedToAverageHorizontal() {
        if (selectedNodeIds.length < 2)
            return;

        var sumX = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumX += getNodeCenterPos(selectedNodeIds[i], 0, 0).x;
        }
        var targetX = Math.round((sumX / selectedNodeIds.length) / 24) * 24;

        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).y - getNodeCenterPos(b, 0, 0).y;
        });

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 28;

        for (var j = 0; j < sorted.length; ++j) {
            var id = sorted[j];
            var curY = Math.round(getNodeCenterPos(id, 0, 0).y / 24) * 24;
            var cardW = 180;
            var cardH = root.getNodeRealHeight(id);

            var bestY = curY;
            if (isPositionColliding(id, targetX, bestY, cardW, cardH, temp, gutter)) {
                for (var step = 1; step <= 80; ++step) {
                    var candYDown = curY + (step * 24);
                    if (!isPositionColliding(id, targetX, candYDown, cardW, cardH, temp, gutter)) {
                        bestY = candYDown;
                        break;
                    }
                    var candYUp = curY - (step * 24);
                    if (!isPositionColliding(id, targetX, candYUp, cardW, cardH, temp, gutter)) {
                        bestY = candYUp;
                        break;
                    }
                }
            }

            temp[id] = {
                x: targetX,
                y: bestY
            };

            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, id, targetX, bestY);
            }
        }

        root.nodePositions = temp;
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function alignSelectedToAverageVertical() {
        if (selectedNodeIds.length < 2)
            return;

        var sumY = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumY += getNodeCenterPos(selectedNodeIds[i], 0, 0).y;
        }
        var targetY = Math.round((sumY / selectedNodeIds.length) / 24) * 24;

        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).x - getNodeCenterPos(b, 0, 0).x;
        });

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 28;

        for (var j = 0; j < sorted.length; ++j) {
            var id = sorted[j];
            var curX = Math.round(getNodeCenterPos(id, 0, 0).x / 24) * 24;
            var cardW = 180;
            var cardH = root.getNodeRealHeight(id);

            var bestX = curX;
            if (isPositionColliding(id, bestX, targetY, cardW, cardH, temp, gutter)) {
                for (var step = 1; step <= 80; ++step) {
                    var candXRight = curX + (step * 24);
                    if (!isPositionColliding(id, candXRight, targetY, cardW, cardH, temp, gutter)) {
                        bestX = candXRight;
                        break;
                    }
                    var candXLeft = curX - (step * 24);
                    if (!isPositionColliding(id, candXLeft, targetY, cardW, cardH, temp, gutter)) {
                        bestX = candXLeft;
                        break;
                    }
                }
            }

            temp[id] = {
                x: bestX,
                y: targetY
            };

            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, id, bestX, targetY);
            }
        }

        root.nodePositions = temp;
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function calculatePinGlobalPos(nodeId, socketId, isOutput) {
        var nData = null;
        for (var j = 0; j < root.nodeList.length; ++j) {
            if (root.nodeList[j].id === nodeId) {
                nData = root.nodeList[j];
                break;
            }
        }

        var cardW = (nData && nData.width) ? nData.width : 190;
        var center = root.getNodeCenterPos(nodeId, nData ? nData.x : 0, nData ? nData.y : 0);
        var px = center.x + (isOutput ? (cardW / 2) : (-cardW / 2));
        var cardH = root.getNodeRealHeight(nodeId);
        var topY = center.y - (cardH / 2);

        var headerH = 28;
        var topMargin = 6;
        var rowH = 32;
        var rowSpacing = 4;
        var rowStride = rowH + rowSpacing;

        var sIdx = 0;

        if (isOutput) {
            if (nData && nData.outputs) {
                for (var o = 0; o < nData.outputs.length; ++o) {
                    if (nData.outputs[o].id === socketId) {
                        sIdx = o;
                        break;
                    }
                }
            }
            var inputCount = (nData && nData.inputs) ? nData.inputs.length : 0;
            var separatorH = inputCount > 0 ? (1 + 8) : 0;
            var inputsTotalHeight = inputCount * rowStride;

            return Qt.point(px, topY + headerH + topMargin + inputsTotalHeight + separatorH + (sIdx * rowStride) + (rowH / 2));
        } else {
            if (nData && nData.inputs) {
                for (var k = 0; k < nData.inputs.length; ++k) {
                    if (nData.inputs[k].id === socketId) {
                        sIdx = k;
                        break;
                    }
                }
            }
            return Qt.point(px, topY + headerH + topMargin + (sIdx * rowStride) + (rowH / 2));
        }
    }

    function insertRerouteOnLink(link, clickWsX, clickWsY) {
        if (!root.graphEngine || root.activeGraphId === "")
            return;

        var newRerouteId = "";
        if (typeof root.graphEngine.addNodeToGraph === "function") {
            newRerouteId = root.graphEngine.addNodeToGraph(root.activeGraphId, "Reroute", clickWsX, clickWsY);
        }

        if (!newRerouteId || newRerouteId === "") {
            console.warn("[NodeGraphPanel] Failed to create Reroute node on link");
            return;
        }

        if (typeof root.graphEngine.disconnectSockets === "function") {
            root.graphEngine.disconnectSockets(root.activeGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);
        }

        if (typeof root.graphEngine.connectSockets === "function") {
            root.graphEngine.connectSockets(root.activeGraphId, link.fromNodeId, link.fromSocketId, newRerouteId, "in");
            root.graphEngine.connectSockets(root.activeGraphId, newRerouteId, "out", link.toNodeId, link.toSocketId);
        }
    }

    function clearAllPinHighlights() {
        root.activeHoveredTargetNodeId = "";
        root.activeHoveredTargetSocketId = "";
        if (typeof cardRepeater !== "undefined" && cardRepeater) {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var c = cardRepeater.itemAt(i);
                if (c && c.activeHighlightSocketId !== undefined) {
                    c.activeHighlightSocketId = "";
                }
            }
        }
    }

    property string activeHoveredTargetNodeId: ""
    property string activeHoveredTargetSocketId: ""

    function findTargetInputPinAt(wsX, wsY) {
        if (typeof cardRepeater === "undefined" || !cardRepeater)
            return null;

        for (var i = 0; i < cardRepeater.count; ++i) {
            var card = cardRepeater.itemAt(i);
            if (!card || card.nodeId === root.wireFromNodeId)
                continue;

            var cPos = root.getNodeCenterPos(card.nodeId, 0, 0);
            var cardW = card.width > 0 ? card.width : 180;
            var cardH = card.height > 0 ? card.height : 120;
            var cardLeft = cPos.x - cardW / 2;
            var cardRight = cPos.x + cardW / 2;
            var cardTop = cPos.y - cardH / 2;
            var cardBottom = cPos.y + cardH / 2;

            if (wsX < cardLeft - 30 || wsX > cardRight + 10 || wsY < cardTop - 20 || wsY > cardBottom + 20) {
                continue;
            }

            if (card.nodeData && card.nodeData.inputs) {
                for (var s = 0; s < card.nodeData.inputs.length; ++s) {
                    var sock = card.nodeData.inputs[s];
                    var pinPos = root.getRegisteredPinPos(card.nodeId, sock.id, false);
                    var dx = wsX - pinPos.x;
                    var dy = wsY - pinPos.y;
                    var dist = Math.sqrt(dx * dx + dy * dy);

                    if (dist <= 36.0 || (Math.abs(dy) <= 16.0 && wsX >= cardLeft - 20 && wsX <= cardLeft + 80)) {
                        return {
                            nodeId: card.nodeId,
                            socketId: sock.id,
                            cardItem: card,
                            pinX: pinPos.x,
                            pinY: pinPos.y
                        };
                    }
                }
            }
        }
        return null;
    }

    function linesIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y) {
        var denom = (b2y - b1y) * (a2x - a1x) - (b2x - b1x) * (a2y - a1y);
        if (denom === 0)
            return false;
        var ua = ((b2x - b1x) * (a1y - b1y) - (b2y - b1y) * (a1x - b1x)) / denom;
        var ub = ((a2x - a1x) * (a1y - b1y) - (b2y - b1y) * (a1x - b1x)) / denom;
        return (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1);
    }

    function executeScissorCut() {
        if (!root.graphEngine || root.linkList.length === 0)
            return;

        var cutOccurred = false;
        var x1 = root.scissorStartX;
        var y1 = root.scissorStartY;
        var x2 = root.scissorCurrentX;
        var y2 = root.scissorCurrentY;

        var strokeLen = Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
        if (strokeLen < 6.0)
            return;

        for (var i = root.linkList.length - 1; i >= 0; --i) {
            var link = root.linkList[i];
            var p1 = root.getRegisteredPinPos(link.fromNodeId, link.fromSocketId, true);
            var p2 = root.getRegisteredPinPos(link.toNodeId, link.toSocketId, false);

            var path = root.solveWirePath(p1, p2, link.fromNodeId, link.toNodeId);
            var cutThisLink = false;
            var steps = 16;
            var lastPx = p1.x;
            var lastPy = p1.y;

            for (var s = 1; s <= steps; ++s) {
                var t = s / steps;
                var curPx = 0, curPy = 0;

                if (root.wireStyle === "straight" && !path.isBlocked) {
                    curPx = p1.x + (p2.x - p1.x) * t;
                    curPy = p1.y + (p2.y - p1.y) * t;
                } else {
                    curPx = Math.pow(1 - t, 3) * p1.x + 3 * Math.pow(1 - t, 2) * t * path.c1x + 3 * (1 - t) * Math.pow(t, 2) * path.c2x + Math.pow(t, 3) * p2.x;
                    curPy = Math.pow(1 - t, 3) * p1.y + 3 * Math.pow(1 - t, 2) * t * path.c1y + 3 * (1 - t) * Math.pow(t, 2) * path.c2y + Math.pow(t, 3) * p2.y;
                }

                if (segmentsIntersect(x1, y1, x2, y2, lastPx, lastPy, curPx, curPy)) {
                    cutThisLink = true;
                    break;
                }
                lastPx = curPx;
                lastPy = curPy;
            }

            if (cutThisLink && typeof root.graphEngine.disconnectSockets === "function") {
                root.graphEngine.disconnectSockets(root.activeGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);
                cutOccurred = true;
            }
        }

        if (cutOccurred) {
            root.notifyGraphStateChanged();
        }
    }
    // =========================================================================
    // VIEW MENU ACTIONS
    // =========================================================================
    function frameSelected() {
        if (selectedNodeIds.length === 0) {
            frameAll();
            return;
        }
        var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var pos = getNodeCenterPos(selectedNodeIds[i], 0, 0);
            minX = Math.min(minX, pos.x - 90);
            maxX = Math.max(maxX, pos.x + 90);
            minY = Math.min(minY, pos.y - 60);
            maxY = Math.max(maxY, pos.y + 60);
        }
        animateViewportToBox(minX, maxX, minY, maxY);
    }

    function frameAll() {
        if (nodeList.length === 0) {
            resetView();
            return;
        }
        var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            var pos = getNodeCenterPos(n.id, n.x, n.y);
            minX = Math.min(minX, pos.x - 90);
            maxX = Math.max(maxX, pos.x + 90);
            minY = Math.min(minY, pos.y - 60);
            maxY = Math.max(maxY, pos.y + 60);
        }
        animateViewportToBox(minX, maxX, minY, maxY);
    }

    function animateViewportToBox(minX, maxX, minY, maxY) {
        var boxW = Math.max(100, maxX - minX);
        var boxH = Math.max(100, maxY - minY);
        var midX = (minX + maxX) / 2;
        var midY = (minY + maxY) / 2;
        var availableW = Math.max(200, canvasContainer.width - 100);
        var availableH = Math.max(200, canvasContainer.height - 100);
        var targetZoom = Math.max(0.2, Math.min(1.8, Math.min(availableW / boxW, availableH / boxH)));

        panAnimation.stop();
        panXAnim.to = -midX * targetZoom;
        panYAnim.to = -midY * targetZoom;
        zoomAnim.to = targetZoom;
        panAnimation.start();
    }

    ParallelAnimation {
        id: panAnimation
        NumberAnimation {
            id: panXAnim
            target: root
            property: "panX"
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: panYAnim
            target: root
            property: "panY"
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: zoomAnim
            target: root
            property: "zoomLevel"
            duration: 250
            easing.type: Easing.OutCubic
        }
        onRunningChanged: if (!running && dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint()
    }

    function zoomIn() {
        root.zoomLevel = Math.min(3.0, root.zoomLevel * 1.25);
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function zoomOut() {
        root.zoomLevel = Math.max(0.2, root.zoomLevel * 0.8);
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function resetView() {
        root.zoomLevel = 1.0;
        root.panX = 0.0;
        root.panY = 0.0;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function viewCenter() {
        root.panX = 0.0;
        root.panY = 0.0;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    // =========================================================================
    // SELECT MENU ACTIONS
    // =========================================================================
    function selectAllNodes() {
        var all = [];
        for (var i = 0; i < nodeList.length; ++i) {
            all.push(nodeList[i].id);
        }
        selectedNodeIds = all;
    }

    function deselectAllNodes() {
        selectedNodeIds = [];
    }

    function invertNodeSelection() {
        var inverted = [];
        for (var i = 0; i < nodeList.length; ++i) {
            if (selectedNodeIds.indexOf(nodeList[i].id) === -1) {
                inverted.push(nodeList[i].id);
            }
        }
        selectedNodeIds = inverted;
    }

    function selectLinkedFrom() {
        var upstream = selectedNodeIds.slice();
        for (var i = 0; i < linkList.length; ++i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.toNodeId) !== -1) {
                if (upstream.indexOf(l.fromNodeId) === -1) {
                    upstream.push(l.fromNodeId);
                }
            }
        }
        selectedNodeIds = upstream;
    }

    function selectLinkedTo() {
        var downstream = selectedNodeIds.slice();
        for (var i = 0; i < linkList.length; ++i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.fromNodeId) !== -1) {
                if (downstream.indexOf(l.toNodeId) === -1) {
                    downstream.push(l.toNodeId);
                }
            }
        }
        selectedNodeIds = downstream;
    }

    function selectGroupedByType() {
        if (selectedNodeIds.length === 0)
            return;
        var activeId = selectedNodeIds[0];
        var targetType = "";
        for (var i = 0; i < nodeList.length; ++i) {
            if (nodeList[i].id === activeId) {
                targetType = nodeList[i].typeName;
                break;
            }
        }
        if (!targetType)
            return;
        var matching = [];
        for (var j = 0; j < nodeList.length; ++j) {
            if (nodeList[j].typeName === targetType) {
                matching.push(nodeList[j].id);
            }
        }
        selectedNodeIds = matching;
    }

    function alignSelectedBottom() {
        if (selectedNodeIds.length < 2)
            return;
        var maxY = -Infinity;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            maxY = Math.max(maxY, getNodeCenterPos(selectedNodeIds[i], 0, 0).y);
        }
        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            temp[id] = {
                x: getNodeCenterPos(id, 0, 0).x,
                y: maxY
            };
        }
        root.nodePositions = temp;

        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function distributeSelectedVertically() {
        if (selectedNodeIds.length < 3)
            return;
        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).y - getNodeCenterPos(b, 0, 0).y;
        });
        var startY = getNodeCenterPos(sorted[0], 0, 0).y;
        var endY = getNodeCenterPos(sorted[sorted.length - 1], 0, 0).y;
        var step = (endY - startY) / (sorted.length - 1);
        var temp = Object.assign({}, root.nodePositions);
        for (var i = 0; i < sorted.length; ++i) {
            var id = sorted[i];
            var newY = startY + (i * step);
            temp[id] = {
                x: getNodeCenterPos(id, 0, 0).x,
                y: newY
            };
            if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                root.graphEngine.setNodePosition(root.activeGraphId, id, temp[id].x, newY);
            }
        }
        root.nodePositions = temp;
    }

    function duplicateLinkedNodes() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        var idMap = {};
        var newSelection = [];
        var offsetStep = 48;

        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var origId = selectedNodeIds[i];
            var pos = getNodeCenterPos(origId, 0, 0);
            var typeName = "Transform";
            for (var j = 0; j < nodeList.length; ++j) {
                if (nodeList[j].id === origId) {
                    typeName = nodeList[j].typeName;
                    break;
                }
            }

            var targetX = Math.round((pos.x + offsetStep) / 24) * 24;
            var targetY = Math.round((pos.y + offsetStep) / 24) * 24;

            var newId = "";
            if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, typeName, targetX, targetY);
            }
            if (newId && newId !== "") {
                idMap[origId] = newId;
                newSelection.push(newId);
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
            }
        }

        for (var l = 0; l < linkList.length; ++l) {
            var link = linkList[l];
            if (idMap[link.fromNodeId] && idMap[link.toNodeId]) {
                if (typeof root.graphEngine.connectSockets === "function") {
                    root.graphEngine.connectSockets(root.activeGraphId, idMap[link.fromNodeId], link.fromSocketId, idMap[link.toNodeId], link.toSocketId);
                }
            }
        }

        selectedNodeIds = newSelection;

        if (newSelection.length > 0) {
            root.resolveAllSelectedNodesOverlap(newSelection[0]);
        }

        root.notifyGraphStateChanged();
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function insertRerouteOnSelectedWire() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        var targetLink = null;
        for (var i = 0; i < linkList.length; ++i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.fromNodeId) !== -1 || selectedNodeIds.indexOf(l.toNodeId) !== -1) {
                targetLink = l;
                break;
            }
        }

        if (targetLink) {
            var p1 = getRegisteredPinPos(targetLink.fromNodeId, targetLink.fromSocketId, true);
            var p2 = getRegisteredPinPos(targetLink.toNodeId, targetLink.toSocketId, false);
            var midX = (p1.x + p2.x) / 2;
            var midY = (p1.y + p2.y) / 2;
            insertRerouteOnLink(targetLink, midX, midY);
        }
    }

    function collapseSelectedNodes() {
        if (selectedNodeIds.length === 0)
            return;

        var anyExpanded = false;
        if (typeof cardRepeater !== "undefined" && cardRepeater) {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var item = cardRepeater.itemAt(i);
                if (item && selectedNodeIds.indexOf(item.nodeId) !== -1) {
                    if (!item.isCollapsed) {
                        anyExpanded = true;
                        break;
                    }
                }
            }

            for (var j = 0; j < cardRepeater.count; ++j) {
                var card = cardRepeater.itemAt(j);
                if (card && selectedNodeIds.indexOf(card.nodeId) !== -1) {
                    card.isCollapsed = anyExpanded;
                }
            }
        }
        root.pinRevision++;
    }

    function togglePreviewForSelected() {
        if (!root.graphEngine || selectedNodeIds.length === 0)
            return;
        var activeId = selectedNodeIds[0];
        if (typeof root.graphEngine.setPreviewNodeId === "function") {
            root.graphEngine.setPreviewNodeId(root.activeGraphId, activeId);
        }
        root.notifyGraphStateChanged();
    }

    function ungroupSelectedNodes() {
        if (selectedNodeIds.length === 0)
            return;

        var updatedGroups = [];
        for (var i = 0; i < root.groupList.length; ++i) {
            var grp = root.groupList[i];
            var newMembers = [];
            for (var m = 0; m < grp.nodeIds.length; ++m) {
                if (selectedNodeIds.indexOf(grp.nodeIds[m]) === -1) {
                    newMembers.push(grp.nodeIds[m]);
                }
            }
            if (newMembers.length > 0) {
                grp.nodeIds = newMembers;
                updatedGroups.push(grp);
            }
        }
        root.groupList = updatedGroups;
        root.notifyGraphStateChanged();
    }

    function cutSelectedNodeLinks() {
        if (!root.graphEngine || selectedNodeIds.length === 0)
            return;

        var cutOccurred = false;
        for (var i = linkList.length - 1; i >= 0; --i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.fromNodeId) !== -1 || selectedNodeIds.indexOf(l.toNodeId) !== -1) {
                if (typeof root.graphEngine.disconnectSockets === "function") {
                    root.graphEngine.disconnectSockets(root.activeGraphId, l.fromNodeId, l.fromSocketId, l.toNodeId, l.toSocketId);
                    cutOccurred = true;
                }
            }
        }
        if (cutOccurred) {
            root.notifyGraphStateChanged();
            root.pinRevision++;
        }
    }

    function toggleMuteSelectedNodes() {
        if (!root.graphEngine || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (typeof root.graphEngine.setNodeBypassed === "function") {
                root.graphEngine.setNodeBypassed(root.activeGraphId, selectedNodeIds[i]);
            }
        }
        root.notifyGraphStateChanged();
    }

    function clearSelectedNodeValues() {
        if (!root.graphEngine || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (typeof root.graphEngine.resetNodeValues === "function") {
                root.graphEngine.resetNodeValues(root.activeGraphId, selectedNodeIds[i]);
            }
        }
        root.notifyGraphStateChanged();
    }

    function duplicateSelectedNodes() {
        if (!root.graphEngine || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        var newSelection = [];
        var offset = 48;

        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var origId = selectedNodeIds[i];
            var pos = getNodeCenterPos(origId, 0, 0);

            var typeName = "Transform";
            for (var j = 0; j < nodeList.length; ++j) {
                if (nodeList[j].id === origId) {
                    typeName = nodeList[j].typeName;
                    break;
                }
            }

            var targetX = pos.x + offset;
            var targetY = pos.y + offset;

            var newId = "";
            if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, typeName, targetX, targetY);
            }
            if (newId && newId !== "") {
                newSelection.push(newId);
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
            }
        }

        selectedNodeIds = newSelection;
        root.notifyGraphStateChanged();
        root.pinRevision++;
        if (dagCanvas && dagCanvas.requestPaint)
            dagCanvas.requestPaint();
    }

    function openSearchPopupAtWorkspace(wsX, wsY, fromNode, fromSocket) {
        var targetWsX = wsX;
        var targetWsY = wsY;

        if (targetWsX === undefined || isNaN(targetWsX) || targetWsY === undefined || isNaN(targetWsY)) {
            if (!isNaN(root.currentMouseWorkspaceX) && (root.currentMouseScreenX > 0 || root.currentMouseScreenY > 0)) {
                targetWsX = root.currentMouseWorkspaceX;
                targetWsY = root.currentMouseWorkspaceY;
            } else {
                targetWsX = (-root.panX) / root.zoomLevel;
                targetWsY = (-root.panY) / root.zoomLevel;
            }
        }

        var canvasPt = graphWorkspace.mapToItem(Overlay.overlay, targetWsX, targetWsY);
        searchPopup.spawnX = targetWsX;
        searchPopup.spawnY = targetWsY;
        searchPopup.linkFromNodeId = fromNode ? fromNode : "";
        searchPopup.linkFromSocketId = fromSocket ? fromSocket : "";
        searchPopup.openAt(canvasPt.x, canvasPt.y);
    }

    property bool showWireColors: true
    property bool showMinimap: true
    property bool showBackdropPreview: false
    property bool isFullscreen: false

    function toggleAllNodeCollapse(collapse) {
        for (var i = 0; i < graphWorkspace.children.length; ++i) {
            var item = graphWorkspace.children[i];
            if (item && item.isCollapsed !== undefined) {
                item.isCollapsed = collapse;
            }
        }
    }

    function selectNodesByFilter(filterFn) {
        var matched = [];
        for (var i = 0; i < nodeList.length; ++i) {
            if (filterFn(nodeList[i])) {
                matched.push(nodeList[i].id);
            }
        }
        selectedNodeIds = matched;
    }

    function deleteWithReconnect() {
        if (!root.graphEngine || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var nId = selectedNodeIds[i];
            var inLink = null, outLink = null;
            for (var j = 0; j < linkList.length; ++j) {
                if (linkList[j].toNodeId === nId)
                    inLink = linkList[j];
                if (linkList[j].fromNodeId === nId)
                    outLink = linkList[j];
            }
            if (inLink && outLink && typeof root.graphEngine.connectSockets === "function") {
                root.graphEngine.connectSockets(root.activeGraphId, inLink.fromNodeId, inLink.fromSocketId, outLink.toNodeId, outLink.toSocketId);
            }
            if (typeof root.graphEngine.removeNode === "function") {
                root.graphEngine.removeNode(root.activeGraphId, nId);
            }
        }
        selectedNodeIds = [];
    }

    function connectSelectedToActive() {
        if (!root.graphEngine || selectedNodeIds.length < 2)
            return;
        var activeId = selectedNodeIds[selectedNodeIds.length - 1];
        var otherId = selectedNodeIds[0];
        if (typeof root.graphEngine.connectSockets === "function") {
            root.graphEngine.connectSockets(root.activeGraphId, otherId, "output", activeId, "input");
        }
    }

    function swapSelectedLinks() {
        if (!root.graphEngine || selectedNodeIds.length !== 2)
            return;
        var a = selectedNodeIds[0], b = selectedNodeIds[1];
        for (var i = 0; i < linkList.length; ++i) {
            var l = linkList[i];
            if (l.fromNodeId === a) {
                if (typeof root.graphEngine.disconnectSockets === "function")
                    root.graphEngine.disconnectSockets(root.activeGraphId, a, l.fromSocketId, l.toNodeId, l.toSocketId);
                if (typeof root.graphEngine.connectSockets === "function")
                    root.graphEngine.connectSockets(root.activeGraphId, b, l.fromSocketId, l.toNodeId, l.toSocketId);
            } else if (l.fromNodeId === b) {
                if (typeof root.graphEngine.disconnectSockets === "function")
                    root.graphEngine.disconnectSockets(root.activeGraphId, b, l.fromSocketId, l.toNodeId, l.toSocketId);
                if (typeof root.graphEngine.connectSockets === "function")
                    root.graphEngine.connectSockets(root.activeGraphId, a, l.fromSocketId, l.toNodeId, l.toSocketId);
            }
        }
    }

    focus: true
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Alt) {
            root.isAltPressed = true;
        } else if (event.key === Qt.Key_Escape) {
            root.isConnectingWire = false;
            root.isCuttingScissor = false;
            searchPopup.close();
            contextMenu.close();
            viewMenu.close();
            selectMenu.close();
            nodeMenu.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.deleteSelectedNodes();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_A)) {
            var targetWsX = 0;
            var targetWsY = 0;

            if (root.currentMouseScreenX > 0 || root.currentMouseScreenY > 0) {
                var wsPt = canvasContainer.mapToItem(graphWorkspace, root.currentMouseScreenX, root.currentMouseScreenY);
                targetWsX = wsPt.x;
                targetWsY = wsPt.y;
            } else {
                targetWsX = (-root.panX) / root.zoomLevel;
                targetWsY = (-root.panY) / root.zoomLevel;
            }

            root.openSearchPopupAtWorkspace(targetWsX, targetWsY, "", "");
            event.accepted = true;
        }
    }

    Keys.onReleased: function (event) {
        if (event.key === Qt.Key_Alt) {
            root.isAltPressed = false;
            root.isCuttingScissor = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: tabBar
            root: root
            Layout.fillWidth: true
        }

        Item {
            id: canvasAreaContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            EmptyState {
                anchors.centerIn: parent
                visible: root.isCurrentGraphReadOnly

                onCreateRequested: {
                    if (!root.graphEngine)
                        return;

                    var allG = (typeof root.graphEngine.getAllProjectGraphs === "function") ? (root.graphEngine.getAllProjectGraphs() || []) : [];
                    var newName = "Graph " + (allG.length + 1);
                    var newGId = (typeof root.graphEngine.createNewProjectGraph === "function") ? root.graphEngine.createNewProjectGraph(newName) : "";

                    if (newGId !== "") {
                        if (root.activeSelectedClipId !== "") {
                            if (typeof root.graphEngine.attachGraphToClip === "function") {
                                root.graphEngine.attachGraphToClip(root.activeSelectedClipId, newGId);
                            }
                            if (typeof root.graphEngine.setClipActiveGraphId === "function") {
                                root.graphEngine.setClipActiveGraphId(root.activeSelectedClipId, newGId);
                            }
                        }
                        root.selectGraph(newGId);
                    }
                }
            }

            Item {
                id: canvasContainer
                anchors.fill: parent
                visible: !root.isCurrentGraphReadOnly

                HoverHandler {
                    id: canvasHoverTracker
                    onPointChanged: {
                        root.currentMouseScreenX = point.position.x;
                        root.currentMouseScreenY = point.position.y;
                        var pt = canvasContainer.mapToItem(graphWorkspace, point.position.x, point.position.y);
                        root.currentMouseWorkspaceX = pt.x;
                        root.currentMouseWorkspaceY = pt.y;
                    }
                }

                Canvas {
                    id: dagCanvas
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = root.canvasBg;
                        ctx.fillRect(0, 0, width, height);

                        if (!root.showGrid)
                            return;

                        ctx.save();
                        ctx.translate(width / 2 + root.panX, height / 2 + root.panY);
                        ctx.scale(root.zoomLevel, root.zoomLevel);

                        var step = 24;
                        var viewLeft = (-width / 2 - root.panX) / root.zoomLevel;
                        var viewRight = (width / 2 - root.panX) / root.zoomLevel;
                        var viewTop = (-height / 2 - root.panY) / root.zoomLevel;
                        var viewBottom = (height / 2 - root.panY) / root.zoomLevel;

                        var minX = Math.floor(viewLeft / step) * step;
                        var maxX = Math.ceil(viewRight / step) * step;
                        var minY = Math.floor(viewTop / step) * step;
                        var maxY = Math.ceil(viewBottom / step) * step;

                        var pixelGridSize = step * root.zoomLevel;

                        if (pixelGridSize >= 12) {
                            ctx.lineWidth = 1 / root.zoomLevel;
                            ctx.strokeStyle = "#1a1a1a";
                            ctx.beginPath();
                            for (var x = minX; x <= maxX; x += step) {
                                if (Math.round(x) % (step * 5) !== 0 && Math.round(x) !== 0) {
                                    ctx.moveTo(x, viewTop);
                                    ctx.lineTo(x, viewBottom);
                                }
                            }
                            for (var y = minY; y <= maxY; y += step) {
                                if (Math.round(y) % (step * 5) !== 0 && Math.round(y) !== 0) {
                                    ctx.moveTo(viewLeft, y);
                                    ctx.lineTo(viewRight, y);
                                }
                            }
                            ctx.stroke();
                        }

                        ctx.lineWidth = 1 / root.zoomLevel;
                        ctx.strokeStyle = "#272727";
                        ctx.beginPath();
                        var majorStep = step * 5;
                        var majorMinX = Math.floor(viewLeft / majorStep) * majorStep;
                        var majorMaxX = Math.ceil(viewRight / majorStep) * majorStep;
                        var majorMinY = Math.floor(viewTop / majorStep) * majorStep;
                        var majorMaxY = Math.ceil(viewBottom / majorStep) * majorStep;

                        for (var mx = majorMinX; mx <= majorMaxX; mx += majorStep) {
                            if (Math.round(mx) !== 0) {
                                ctx.moveTo(mx, viewTop);
                                ctx.lineTo(mx, viewBottom);
                            }
                        }
                        for (var my = majorMinY; my <= majorMaxY; my += majorStep) {
                            if (Math.round(my) !== 0) {
                                ctx.moveTo(viewLeft, my);
                                ctx.lineTo(viewRight, my);
                            }
                        }
                        ctx.stroke();

                        ctx.lineWidth = 2 / root.zoomLevel;
                        ctx.strokeStyle = "#3e3e3e";
                        ctx.beginPath();
                        ctx.moveTo(viewLeft, 0);
                        ctx.lineTo(viewRight, 0);
                        ctx.moveTo(0, viewTop);
                        ctx.lineTo(0, viewBottom);
                        ctx.stroke();

                        ctx.restore();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Canvas {
                    id: lassoCanvas
                    anchors.fill: parent
                    visible: root.isBoxSelecting && root.selectionMode === "lasso"
                    z: 85
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (root.lassoPoints.length < 2)
                            return;
                        ctx.strokeStyle = "#3B82F6";
                        ctx.fillStyle = "#253B82F6";
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        var p0 = graphWorkspace.mapToItem(canvasContainer, root.lassoPoints[0].x, root.lassoPoints[0].y);
                        ctx.moveTo(p0.x, p0.y);
                        for (var i = 1; i < root.lassoPoints.length; ++i) {
                            var pt = graphWorkspace.mapToItem(canvasContainer, root.lassoPoints[i].x, root.lassoPoints[i].y);
                            ctx.lineTo(pt.x, pt.y);
                        }
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();
                    }
                }

                MouseArea {
                    id: canvasPanArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: root.isAltPressed ? Qt.CrossCursor : (pressed ? (root.isBoxSelecting ? Qt.CrossCursor : Qt.ClosedHandCursor) : Qt.ArrowCursor)

                    property real startX: 0
                    property real startY: 0

                    onPressed: function (mouse) {
                        root.forceActiveFocus();
                        root.currentMouseScreenX = mouse.x;
                        root.currentMouseScreenY = mouse.y;
                        var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.currentMouseWorkspaceX = wsPt.x;
                        root.currentMouseWorkspaceY = wsPt.y;

                        startX = mouse.x - root.panX;
                        startY = mouse.y - root.panY;

                        if (mouse.button === Qt.LeftButton) {
                            if (root.isAltPressed) {
                                root.isCuttingScissor = true;
                                var sPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                                root.scissorStartX = sPt.x;
                                root.scissorStartY = sPt.y;
                                root.scissorCurrentX = sPt.x;
                                root.scissorCurrentY = sPt.y;
                            } else {
                                root.isBoxSelecting = true;
                                root.boxStartX = wsPt.x;
                                root.boxStartY = wsPt.y;
                                root.boxCurrentX = wsPt.x;
                                root.boxCurrentY = wsPt.y;
                                root.circleRadius = 0;
                                root.lassoPoints = [
                                    {
                                        x: wsPt.x,
                                        y: wsPt.y
                                    }
                                ];
                                var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                                if (!isMulti) {
                                    root.selectedNodeIds = [];
                                }
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            var rWsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                            root.currentMouseScreenX = mouse.x;
                            root.currentMouseScreenY = mouse.y;
                            root.currentMouseWorkspaceX = rWsPt.x;
                            root.currentMouseWorkspaceY = rWsPt.y;
                            searchPopup.spawnX = rWsPt.x;
                            searchPopup.spawnY = rWsPt.y;
                            var overlayPt = canvasPanArea.mapToItem(Overlay.overlay, mouse.x, mouse.y);
                            contextMenu.openAt(overlayPt.x, overlayPt.y, root.activeGraphId, "", 0, root.selectedNodeIds.length > 0);
                        }
                    }

                    onPositionChanged: function (mouse) {
                        root.currentMouseScreenX = mouse.x;
                        root.currentMouseScreenY = mouse.y;
                        var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                        root.currentMouseWorkspaceX = wsPt.x;
                        root.currentMouseWorkspaceY = wsPt.y;

                        if (root.isCuttingScissor) {
                            var scPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                            root.scissorCurrentX = scPt.x;
                            root.scissorCurrentY = scPt.y;
                        } else if (root.isBoxSelecting) {
                            var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                            root.boxCurrentX = wsPt.x;
                            root.boxCurrentY = wsPt.y;

                            if (root.selectionMode === "circle") {
                                var dx = wsPt.x - root.boxStartX;
                                var dy = wsPt.y - root.boxStartY;
                                root.circleRadius = Math.sqrt(dx * dx + dy * dy);
                            } else if (root.selectionMode === "lasso") {
                                root.lassoPoints.push({
                                    x: wsPt.x,
                                    y: wsPt.y
                                });
                                lassoCanvas.requestPaint();
                            }
                        } else if (pressed && mouse.buttons === Qt.MiddleButton) {
                            root.panX = mouse.x - startX;
                            root.panY = mouse.y - startY;
                            if (dagCanvas && dagCanvas.requestPaint)
                                dagCanvas.requestPaint();
                        }
                    }

                    onReleased: function (mouse) {
                        if (root.isCuttingScissor) {
                            root.executeScissorCut();
                            root.isCuttingScissor = false;
                            return;
                        }

                        if (root.isBoxSelecting) {
                            var newlySelected = [];

                            if (root.selectionMode === "box") {
                                var minX = Math.min(root.boxStartX, root.boxCurrentX);
                                var maxX = Math.max(root.boxStartX, root.boxCurrentX);
                                var minY = Math.min(root.boxStartY, root.boxCurrentY);
                                var maxY = Math.max(root.boxStartY, root.boxCurrentY);
                                for (var i = 0; i < root.nodeList.length; ++i) {
                                    var n = root.nodeList[i];
                                    var pos = root.getNodeCenterPos(n.id, n.x, n.y);
                                    if (pos.x >= minX - 90 && pos.x <= maxX + 90 && pos.y >= minY - 60 && pos.y <= maxY + 60) {
                                        newlySelected.push(n.id);
                                    }
                                }
                            } else if (root.selectionMode === "circle") {
                                for (var c = 0; c < root.nodeList.length; ++c) {
                                    var cn = root.nodeList[c];
                                    var cpos = root.getNodeCenterPos(cn.id, cn.x, cn.y);
                                    var nLeft = cpos.x - 90, nRight = cpos.x + 90;
                                    var nTop = cpos.y - 40, nBottom = cpos.y + 40;

                                    var closestX = Math.max(nLeft, Math.min(root.boxStartX, nRight));
                                    var closestY = Math.max(nTop, Math.min(root.boxStartY, nBottom));

                                    var distSq = Math.pow(root.boxStartX - closestX, 2) + Math.pow(root.boxStartY - closestY, 2);
                                    if (distSq <= Math.pow(root.circleRadius, 2)) {
                                        newlySelected.push(cn.id);
                                    }
                                }
                            } else if (root.selectionMode === "lasso") {
                                for (var l = 0; l < root.nodeList.length; ++l) {
                                    var ln = root.nodeList[l];
                                    if (root.isCardIntersectingLasso(ln.id, root.lassoPoints)) {
                                        newlySelected.push(ln.id);
                                    }
                                }
                                root.lassoPoints = [];
                                lassoCanvas.requestPaint();
                            }

                            var isMulti = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                            if (isMulti) {
                                var merged = root.selectedNodeIds.slice();
                                for (var m = 0; m < newlySelected.length; ++m) {
                                    if (merged.indexOf(newlySelected[m]) === -1) {
                                        merged.push(newlySelected[m]);
                                    }
                                }
                                root.selectedNodeIds = merged;
                            } else {
                                root.selectedNodeIds = newlySelected;
                            }
                            root.isBoxSelecting = false;
                        }
                    }

                    onWheel: function (wheel) {
                        if (wheel.modifiers & Qt.ControlModifier) {
                            var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87;
                            var nextZoom = Math.max(0.15, Math.min(3.5, root.zoomLevel * factor));

                            var mouseWsX = (wheel.x - canvasContainer.width / 2 - root.panX) / root.zoomLevel;
                            var mouseWsY = (wheel.y - canvasContainer.height / 2 - root.panY) / root.zoomLevel;

                            root.panX = wheel.x - canvasContainer.width / 2 - (mouseWsX * nextZoom);
                            root.panY = wheel.y - canvasContainer.height / 2 - (mouseWsY * nextZoom);
                            root.zoomLevel = nextZoom;
                        } else if (wheel.modifiers & Qt.ShiftModifier) {
                            root.panX += (wheel.angleDelta.y || wheel.angleDelta.x);
                        } else {
                            root.panY += wheel.angleDelta.y;
                            if (wheel.angleDelta.x !== 0) {
                                root.panX += wheel.angleDelta.x;
                            }
                        }
                        if (dagCanvas && dagCanvas.requestPaint)
                            dagCanvas.requestPaint();
                    }
                }

                PinchHandler {
                    id: canvasPinchHandler
                    target: null

                    property real startZoom: 1.0
                    property real startPanX: 0.0
                    property real startPanY: 0.0
                    property point startCenter: Qt.point(0, 0)

                    onActiveChanged: {
                        if (active) {
                            startZoom = root.zoomLevel;
                            startPanX = root.panX;
                            startPanY = root.panY;
                            startCenter = centroid.position;
                        }
                    }

                    onScaleChanged: function (delta) {
                        var nextZoom = Math.max(0.15, Math.min(3.5, startZoom * scale));
                        var cWsX = (startCenter.x - canvasContainer.width / 2 - startPanX) / startZoom;
                        var cWsY = (startCenter.y - canvasContainer.height / 2 - startPanY) / startZoom;

                        var currentCenterX = centroid.position.x;
                        var currentCenterY = centroid.position.y;

                        root.panX = currentCenterX - canvasContainer.width / 2 - (cWsX * nextZoom);
                        root.panY = currentCenterY - canvasContainer.height / 2 - (cWsY * nextZoom);
                        root.zoomLevel = nextZoom;

                        if (dagCanvas && dagCanvas.requestPaint)
                            dagCanvas.requestPaint();
                    }
                }

                Minimap {
                    root: root
                    canvasContainer: canvasContainer
                    dagCanvas: dagCanvas
                }

                UtilityBar {
                    id: graphUtilityBar
                    root: root
                }

                Canvas {
                    id: snapGuideCanvas
                    anchors.fill: parent
                    visible: root.snapGuideXVisible || root.snapGuideYVisible
                    z: 98

                    Connections {
                        target: root
                        function onSnapGuideXVisibleChanged() {
                            snapGuideCanvas.requestPaint();
                        }
                        function onSnapGuideYVisibleChanged() {
                            snapGuideCanvas.requestPaint();
                        }
                        function onSnapGuideXPosChanged() {
                            snapGuideCanvas.requestPaint();
                        }
                        function onSnapGuideYPosChanged() {
                            snapGuideCanvas.requestPaint();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        if (!root.snapGuideXVisible && !root.snapGuideYVisible)
                            return;

                        ctx.strokeStyle = "#AF0044";
                        ctx.lineWidth = 1;
                        if (ctx.setLineDash) {
                            ctx.setLineDash([4, 4]);
                        }

                        if (root.snapGuideXVisible) {
                            var screenX = canvasContainer.width / 2 + root.panX + (root.snapGuideXPos * root.zoomLevel);
                            ctx.beginPath();
                            ctx.moveTo(screenX, 0);
                            ctx.lineTo(screenX, canvasContainer.height);
                            ctx.stroke();
                        }

                        if (root.snapGuideYVisible) {
                            var screenY = canvasContainer.height / 2 + root.panY + (root.snapGuideYPos * root.zoomLevel);
                            ctx.beginPath();
                            ctx.moveTo(0, screenY);
                            ctx.lineTo(canvasContainer.width, screenY);
                            ctx.stroke();
                        }
                    }
                }

                Item {
                    id: graphWorkspace
                    x: canvasContainer.width / 2 + root.panX
                    y: canvasContainer.height / 2 + root.panY
                    scale: root.zoomLevel

                    Rectangle {
                        visible: root.isBoxSelecting && root.selectionMode === "box"
                        x: Math.min(root.boxStartX, root.boxCurrentX)
                        y: Math.min(root.boxStartY, root.boxCurrentY)
                        width: Math.abs(root.boxCurrentX - root.boxStartX)
                        height: Math.abs(root.boxCurrentY - root.boxStartY)
                        color: "#153B82F6"
                        border.color: "#3B82F6"
                        border.width: 1
                        z: 90
                    }

                    Rectangle {
                        visible: root.isBoxSelecting && root.selectionMode === "circle"
                        x: root.boxStartX - root.circleRadius
                        y: root.boxStartY - root.circleRadius
                        width: root.circleRadius * 2
                        height: root.circleRadius * 2
                        radius: root.circleRadius
                        color: "#153B82F6"
                        border.color: "#3B82F6"
                        border.width: 1
                        z: 90
                    }

                    Shape {
                        anchors.fill: parent
                        visible: root.isCuttingScissor
                        z: 95
                        ShapePath {
                            strokeColor: "#EF4444"
                            strokeWidth: 2
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [6, 4]
                            fillColor: "transparent"
                            startX: root.scissorStartX
                            startY: root.scissorStartY
                            PathLine {
                                x: root.scissorCurrentX
                                y: root.scissorCurrentY
                            }
                        }
                    }

                    Repeater {
                        id: linkRepeater
                        model: root.visibleLinkList

                        delegate: Item {
                            id: linkDelegate
                            z: 20
                            anchors.fill: parent

                            readonly property int rev: root.pinRevision

                            readonly property var p1: {
                                var _ = rev;
                                return root.getRegisteredPinPos(modelData.fromNodeId, modelData.fromSocketId, true);
                            }

                            readonly property var p2: {
                                var _ = rev;
                                return root.getRegisteredPinPos(modelData.toNodeId, modelData.toSocketId, false);
                            }

                            readonly property var path: {
                                var _ = rev;
                                return root.solveWirePath(p1, p2, modelData.fromNodeId, modelData.toNodeId);
                            }

                            property bool isWireHovered: false

                            Shape {
                                anchors.fill: parent
                                visible: root.wireStyle === "straight"

                                ShapePath {
                                    strokeColor: linkDelegate.isWireHovered ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                                    strokeWidth: linkDelegate.isWireHovered ? 3.0 : 2.0
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.MiterJoin

                                    startX: linkDelegate.p1.x
                                    startY: linkDelegate.p1.y

                                    PathLine {
                                        x: linkDelegate.path.isBlocked ? linkDelegate.path.straightPts[1].x : linkDelegate.p2.x
                                        y: linkDelegate.path.isBlocked ? linkDelegate.path.straightPts[1].y : linkDelegate.p2.y
                                    }
                                    PathLine {
                                        x: linkDelegate.path.isBlocked ? linkDelegate.path.straightPts[2].x : linkDelegate.p2.x
                                        y: linkDelegate.path.isBlocked ? linkDelegate.path.straightPts[2].y : linkDelegate.p2.y
                                    }
                                    PathLine {
                                        x: linkDelegate.p2.x
                                        y: linkDelegate.p2.y
                                    }
                                }
                            }

                            Shape {
                                anchors.fill: parent
                                visible: root.wireStyle === "curve"

                                ShapePath {
                                    strokeColor: linkDelegate.isWireHovered ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                                    strokeWidth: linkDelegate.isWireHovered ? 3.0 : 2.0
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap

                                    startX: linkDelegate.p1.x
                                    startY: linkDelegate.p1.y

                                    PathCubic {
                                        x: linkDelegate.p2.x
                                        y: linkDelegate.p2.y
                                        control1X: linkDelegate.path.c1x
                                        control1Y: linkDelegate.path.c1y
                                        control2X: linkDelegate.path.c2x
                                        control2Y: linkDelegate.path.c2y
                                    }
                                }
                            }

                            function distanceToWire(px, py) {
                                var minD = 999999;
                                var steps = 14;
                                for (var s = 0; s <= steps; ++s) {
                                    var t = s / steps;
                                    var bx = 0, by = 0;
                                    if (root.wireStyle === "straight" && !path.isBlocked) {
                                        bx = p1.x + (p2.x - p1.x) * t;
                                        by = p1.y + (p2.y - p1.y) * t;
                                    } else {
                                        bx = Math.pow(1 - t, 3) * p1.x + 3 * Math.pow(1 - t, 2) * t * path.c1x + 3 * (1 - t) * Math.pow(t, 2) * path.c2x + Math.pow(t, 3) * p2.x;
                                        by = Math.pow(1 - t, 3) * p1.y + 3 * Math.pow(1 - t, 2) * t * path.c1y + 3 * (1 - t) * Math.pow(t, 2) * path.c2y + Math.pow(t, 3) * p2.y;
                                    }
                                    var d = Math.sqrt(Math.pow(px - bx, 2) + Math.pow(py - by, 2));
                                    if (d < minD)
                                        minD = d;
                                }
                                return minD;
                            }

                            MouseArea {
                                id: wireMouseArea
                                x: Math.min(linkDelegate.p1.x, linkDelegate.p2.x) - 60
                                y: Math.min(linkDelegate.p1.y, linkDelegate.p2.y) - 60
                                width: Math.abs(linkDelegate.p2.x - linkDelegate.p1.x) + 120
                                height: Math.abs(linkDelegate.p2.y - linkDelegate.p1.y) + 120

                                hoverEnabled: true
                                enabled: !root.isAltPressed
                                cursorShape: linkDelegate.isWireHovered ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onPositionChanged: function (mouse) {
                                    var pt = mapToItem(linkDelegate, mouse.x, mouse.y);
                                    var d = linkDelegate.distanceToWire(pt.x, pt.y);
                                    linkDelegate.isWireHovered = (d <= 9.0);
                                }
                                onExited: linkDelegate.isWireHovered = false

                                onPressed: function (mouse) {
                                    var pt = mapToItem(linkDelegate, mouse.x, mouse.y);
                                    var d = linkDelegate.distanceToWire(pt.x, pt.y);
                                    if (d <= 9.0) {
                                        linkDelegate.isWireHovered = true;
                                        mouse.accepted = true;
                                    } else {
                                        mouse.accepted = false;
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    var pt = mapToItem(linkDelegate, mouse.x, mouse.y);
                                    var d = linkDelegate.distanceToWire(pt.x, pt.y);
                                    if (d <= 9.0)
                                        root.insertRerouteOnLink(modelData, pt.x, pt.y);
                                    else
                                        mouse.accepted = false;
                                }
                            }
                        }
                    }

                    Item {
                        id: pendingWireContainer
                        anchors.fill: parent
                        visible: root.isConnectingWire
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
                                    x: root.wireMouseX
                                    y: root.wireMouseY

                                    readonly property real pdx: Math.abs(root.wireMouseX - pendingPath.startX)

                                    control1X: root.wireStyle === "straight" ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.33) : (pendingPath.startX + Math.max(45, pdx * 0.45))
                                    control1Y: pendingPath.startY

                                    control2X: root.wireStyle === "straight" ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.66) : (root.wireMouseX - Math.max(45, pdx * 0.45))
                                    control2Y: root.wireMouseY
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.groupList

                        delegate: Rectangle {
                            id: groupCard
                            property var b: root.calculateGroupBounds(modelData)
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
                                    if (pressed) {
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

                    // 1. STANDARD NODES
                    Repeater {
                        id: cardRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName !== "GroupNode" && n.typeName !== "Reroute" && n.typeName !== "CommentNode";
                        })

                        delegate: NodeCard {
                            id: cardItem
                            nodeData: modelData
                            activeModel: root.graphEngine
                            activeClipId: root.activeGraphId
                            isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1

                            Component.onCompleted: {
                                if (root.nodePositions[modelData.id] === undefined) {
                                    root.nodePositions[modelData.id] = {
                                        x: modelData.x,
                                        y: modelData.y
                                    };
                                }
                            }

                            x: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.x - width / 2;
                            }
                            y: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.y - height / 2;
                            }

                            onPinPositionChanged: function (nId, sId, isOut, px, py) {
                                root.registerPinPosition(nId, sId, isOut, Qt.point(px, py));
                            }

                            onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                                root.isConnectingWire = true;
                                root.wireFromNodeId = nodeId;
                                root.wireFromSocketId = socketId;
                                pendingPath.startX = pinX;
                                pendingPath.startY = pinY;
                                root.wireMouseX = pinX;
                                root.wireMouseY = pinY;
                            }

                            onUpdateWireDrag: function (gx, gy) {
                                if (!root.isConnectingWire)
                                    return;
                                var target = root.findTargetInputPinAt(gx, gy);
                                if (target) {
                                    root.wireMouseX = target.pinX;
                                    root.wireMouseY = target.pinY;

                                    if (root.activeHoveredTargetNodeId !== target.nodeId || root.activeHoveredTargetSocketId !== target.socketId) {
                                        root.clearAllPinHighlights();
                                        root.activeHoveredTargetNodeId = target.nodeId;
                                        root.activeHoveredTargetSocketId = target.socketId;
                                        target.cardItem.activeHighlightSocketId = target.socketId;
                                    }
                                } else {
                                    root.wireMouseX = gx;
                                    root.wireMouseY = gy;
                                    root.clearAllPinHighlights();
                                }
                            }

                            onEndConnectingWire: function (gx, gy) {
                                if (!root.isConnectingWire)
                                    return;

                                var target = root.findTargetInputPinAt(gx, gy);
                                if (target && root.graphEngine && typeof root.graphEngine.connectSockets === "function") {
                                    var ok = root.graphEngine.connectSockets(root.activeGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                                    if (ok) {
                                        root.notifyGraphStateChanged();
                                        root.pinRevision++;
                                    }
                                } else if (!target) {
                                    var fromN = root.wireFromNodeId;
                                    var fromS = root.wireFromSocketId;
                                    root.openSearchPopupAtWorkspace(gx, gy, fromN, fromS);
                                }

                                root.clearAllPinHighlights();
                                root.isConnectingWire = false;
                                root.wireFromNodeId = "";
                                root.wireFromSocketId = "";
                            }

                            property var initialDragMap: ({})

                            onNodeSelected: function (nodeId, isShift) {
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

                                var map = {};
                                for (var s = 0; s < root.selectedNodeIds.length; ++s) {
                                    var sId = root.selectedNodeIds[s];
                                    map[sId] = root.getNodeCenterPos(sId, 0, 0);
                                }
                                cardItem.initialDragMap = map;
                            }

                            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                                var primaryId = modelData.id;
                                var startPos = cardItem.initialDragMap[primaryId];
                                if (!startPos) {
                                    startPos = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                                    cardItem.initialDragMap[primaryId] = startPos;
                                }

                                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);

                                var moveDx = snappedP.x - startPos.x;
                                var moveDy = snappedP.y - startPos.y;

                                var temp = Object.assign({}, root.nodePositions);
                                var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [primaryId];

                                for (var i = 0; i < ids.length; ++i) {
                                    var sId = ids[i];
                                    var orig = cardItem.initialDragMap[sId];
                                    if (!orig) {
                                        orig = root.getNodeCenterPos(sId, 0, 0);
                                        cardItem.initialDragMap[sId] = orig;
                                    }
                                    temp[sId] = {
                                        x: orig.x + moveDx,
                                        y: orig.y + moveDy
                                    };
                                }

                                root.nodePositions = temp;
                                root.pinRevision++;
                            }

                            onDragFinished: {
                                root.snapGuideXVisible = false;
                                root.snapGuideYVisible = false;
                                cardItem.initialDragMap = {};

                                root.resolveAllSelectedNodesOverlap(modelData.id);

                                if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.graphEngine.setNodePosition(root.activeGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // 2. GROUP NODES
                    Repeater {
                        id: groupRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName === "GroupNode";
                        })

                        delegate: GroupNodeCard {
                            id: groupCardItem
                            nodeData: modelData
                            activeModel: root.graphEngine
                            activeClipId: root.activeGraphId
                            isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1

                            Component.onCompleted: {
                                if (root.nodePositions[modelData.id] === undefined) {
                                    root.nodePositions[modelData.id] = {
                                        x: modelData.x,
                                        y: modelData.y
                                    };
                                }
                            }

                            x: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.x - width / 2;
                            }
                            y: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.y - height / 2;
                            }

                            onPinPositionChanged: function (nId, sId, isOut, px, py) {
                                root.registerPinPosition(nId, sId, isOut, Qt.point(px, py));
                            }

                            onEnterGroupRequested: function (gId, gName) {
                                root.enterGroupView(gId, gName);
                            }

                            property var initialDragMap: ({})

                            onNodeSelected: function (nodeId, isShift) {
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
                                var map = {};
                                for (var s = 0; s < root.selectedNodeIds.length; ++s) {
                                    var sId = root.selectedNodeIds[s];
                                    map[sId] = root.getNodeCenterPos(sId, 0, 0);
                                }
                                groupCardItem.initialDragMap = map;
                            }

                            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                                var primaryId = modelData.id;
                                var startPos = groupCardItem.initialDragMap[primaryId];
                                if (!startPos) {
                                    startPos = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                                    groupCardItem.initialDragMap[primaryId] = startPos;
                                }

                                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                                var moveDx = snappedP.x - startPos.x;
                                var moveDy = snappedP.y - startPos.y;

                                var temp = Object.assign({}, root.nodePositions);
                                var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [primaryId];

                                for (var i = 0; i < ids.length; ++i) {
                                    var sId = ids[i];
                                    var orig = groupCardItem.initialDragMap[sId];
                                    if (!orig) {
                                        orig = root.getNodeCenterPos(sId, 0, 0);
                                        groupCardItem.initialDragMap[sId] = orig;
                                    }
                                    temp[sId] = {
                                        x: orig.x + moveDx,
                                        y: orig.y + moveDy
                                    };
                                }
                                root.nodePositions = temp;
                                root.pinRevision++;
                            }

                            onDragFinished: {
                                var centerPos = root.getNodeCenterPos(modelData.id, 0, 0);
                                root.handleDropCardOnContainers(modelData.id, centerPos.x, centerPos.y);

                                root.snapGuideXVisible = false;
                                root.snapGuideYVisible = false;
                                groupCardItem.initialDragMap = {};
                                root.resolveAllSelectedNodesOverlap(modelData.id);

                                if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.graphEngine.setNodePosition(root.activeGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // 3. REROUTE NODES
                    Repeater {
                        id: rerouteRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName === "Reroute";
                        })

                        delegate: RerouteJointPill {
                            id: rerouteCardItem
                            nodeData: modelData
                            isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1

                            Component.onCompleted: {
                                if (root.nodePositions[modelData.id] === undefined) {
                                    root.nodePositions[modelData.id] = {
                                        x: modelData.x,
                                        y: modelData.y
                                    };
                                }
                            }

                            x: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.x - width / 2;
                            }
                            y: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.y - height / 2;
                            }

                            onPinPositionChanged: function (nId, sId, isOut, px, py) {
                                root.registerPinPosition(nId, sId, isOut, Qt.point(px, py));
                            }

                            onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                                root.isConnectingWire = true;
                                root.wireFromNodeId = nodeId;
                                root.wireFromSocketId = socketId;
                                pendingPath.startX = pinX;
                                pendingPath.startY = pinY;
                                root.wireMouseX = pinX;
                                root.wireMouseY = pinY;
                            }

                            onUpdateWireDrag: function (gx, gy) {
                                if (!root.isConnectingWire)
                                    return;
                                var target = root.findTargetInputPinAt(gx, gy);
                                if (target) {
                                    root.wireMouseX = target.pinX;
                                    root.wireMouseY = target.pinY;
                                } else {
                                    root.wireMouseX = gx;
                                    root.wireMouseY = gy;
                                }
                            }

                            onEndConnectingWire: function (gx, gy) {
                                if (!root.isConnectingWire)
                                    return;
                                var target = root.findTargetInputPinAt(gx, gy);
                                if (target && root.graphEngine && typeof root.graphEngine.connectSockets === "function") {
                                    var ok = root.graphEngine.connectSockets(root.activeGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                                    if (ok) {
                                        root.notifyGraphStateChanged();
                                        root.pinRevision++;
                                    }
                                }
                                root.isConnectingWire = false;
                                root.wireFromNodeId = "";
                                root.wireFromSocketId = "";
                            }

                            property var initialDragMap: ({})

                            onNodeSelected: function (nodeId, isShift) {
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
                                var map = {};
                                for (var s = 0; s < root.selectedNodeIds.length; ++s) {
                                    var sId = root.selectedNodeIds[s];
                                    map[sId] = root.getNodeCenterPos(sId, 0, 0);
                                }
                                rerouteCardItem.initialDragMap = map;
                            }

                            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                                var primaryId = modelData.id;
                                var startPos = rerouteCardItem.initialDragMap[primaryId];
                                if (!startPos) {
                                    startPos = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                                    rerouteCardItem.initialDragMap[primaryId] = startPos;
                                }

                                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                                var moveDx = snappedP.x - startPos.x;
                                var moveDy = snappedP.y - startPos.y;

                                var temp = Object.assign({}, root.nodePositions);
                                var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [primaryId];

                                for (var i = 0; i < ids.length; ++i) {
                                    var sId = ids[i];
                                    var orig = rerouteCardItem.initialDragMap[sId];
                                    if (!orig) {
                                        orig = root.getNodeCenterPos(sId, 0, 0);
                                        rerouteCardItem.initialDragMap[sId] = orig;
                                    }
                                    temp[sId] = {
                                        x: orig.x + moveDx,
                                        y: orig.y + moveDy
                                    };
                                }
                                root.nodePositions = temp;
                                root.pinRevision++;
                            }

                            onDragFinished: {
                                root.snapGuideXVisible = false;
                                root.snapGuideYVisible = false;
                                rerouteCardItem.initialDragMap = {};
                                root.resolveAllSelectedNodesOverlap(modelData.id);

                                if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.graphEngine.setNodePosition(root.activeGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // 4. COMMENT NODES
                    Repeater {
                        id: commentRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName === "CommentNode";
                        })

                        delegate: CommentNodeCard {
                            id: commentCardItem
                            nodeData: modelData
                            activeModel: root.graphEngine
                            activeClipId: root.activeGraphId
                            isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1

                            Component.onCompleted: {
                                if (root.nodePositions[modelData.id] === undefined) {
                                    root.nodePositions[modelData.id] = {
                                        x: modelData.x,
                                        y: modelData.y
                                    };
                                }
                            }

                            x: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.x - width / 2;
                            }
                            y: {
                                var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                                return p.y - height / 2;
                            }

                            property var initialDragMap: ({})

                            onNodeSelected: function (nodeId, isShift) {
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
                                var map = {};
                                for (var s = 0; s < root.selectedNodeIds.length; ++s) {
                                    var sId = root.selectedNodeIds[s];
                                    map[sId] = root.getNodeCenterPos(sId, 0, 0);
                                }
                                commentCardItem.initialDragMap = map;
                            }

                            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                                var primaryId = modelData.id;
                                var startPos = commentCardItem.initialDragMap[primaryId];
                                if (!startPos) {
                                    startPos = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                                    commentCardItem.initialDragMap[primaryId] = startPos;
                                }

                                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                                var moveDx = snappedP.x - startPos.x;
                                var moveDy = snappedP.y - startPos.y;

                                var temp = Object.assign({}, root.nodePositions);
                                var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [primaryId];

                                for (var i = 0; i < ids.length; ++i) {
                                    var sId = ids[i];
                                    var orig = commentCardItem.initialDragMap[sId];
                                    if (!orig) {
                                        orig = root.getNodeCenterPos(sId, 0, 0);
                                        commentCardItem.initialDragMap[sId] = orig;
                                    }
                                    temp[sId] = {
                                        x: orig.x + moveDx,
                                        y: orig.y + moveDy
                                    };
                                }
                                root.nodePositions = temp;
                                root.pinRevision++;
                            }

                            onDragFinished: {
                                var centerPos = root.getNodeCenterPos(modelData.id, 0, 0);
                                root.handleDropCardOnContainers(modelData.id, centerPos.x, centerPos.y);

                                root.snapGuideXVisible = false;
                                root.snapGuideYVisible = false;
                                commentCardItem.initialDragMap = {};
                                root.resolveAllSelectedNodesOverlap(modelData.id);

                                if (root.graphEngine && typeof root.graphEngine.setNodePosition === "function") {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.graphEngine.setNodePosition(root.activeGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SearchPopup {
        id: searchPopup

        availableNodeTypes: (root.graphEngine && typeof root.graphEngine.getAvailableNodeTypes === "function") ? (root.graphEngine.getAvailableNodeTypes() || []) : []
        isReadOnly: root.isCurrentGraphReadOnly

        onAddNodeRequested: function (typeName, sX, sY) {
            if (!root.graphEngine || root.isCurrentGraphReadOnly)
                return;

            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));
            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;

            var freePt = root.findFreeSpaceAround(targetX, targetY, "");
            if (freePt && !isNaN(freePt.x) && !isNaN(freePt.y)) {
                targetX = freePt.x;
                targetY = freePt.y;
            }

            var newId = "";
            if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, typeName, targetX, targetY);
            }

            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];

                if (searchPopup.linkFromNodeId && searchPopup.linkFromNodeId !== "") {
                    var fromNId = searchPopup.linkFromNodeId;
                    var fromSId = searchPopup.linkFromSocketId;
                    Qt.callLater(function () {
                        if (typeof root.graphEngine.getGraphNodes === "function") {
                            var nodes = root.graphEngine.getGraphNodes(root.activeGraphId) || [];
                            for (var n = 0; n < nodes.length; ++n) {
                                if (nodes[n].id === newId && nodes[n].inputs && nodes[n].inputs.length > 0) {
                                    if (typeof root.graphEngine.connectSockets === "function") {
                                        root.graphEngine.connectSockets(root.activeGraphId, fromNId, fromSId, newId, nodes[n].inputs[0].id);
                                    }
                                    root.notifyGraphStateChanged();
                                    root.pinRevision++;
                                    break;
                                }
                            }
                        }
                    });
                }
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            if (dagCanvas && dagCanvas.requestPaint)
                dagCanvas.requestPaint();
        }

        onAddRerouteRequested: function (sX, sY) {
            if (!root.graphEngine || root.isCurrentGraphReadOnly)
                return;
            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));
            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;
            var newId = "";
            if (typeof root.graphEngine.addRerouteToGraph === "function") {
                newId = root.graphEngine.addRerouteToGraph(root.activeGraphId, targetX, targetY);
            } else if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, "Reroute", targetX, targetY);
            }

            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            if (dagCanvas && dagCanvas.requestPaint)
                dagCanvas.requestPaint();
        }

        onAddCommentRequested: function (sX, sY) {
            if (!root.graphEngine || root.isCurrentGraphReadOnly)
                return;
            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));
            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;
            var newId = "";
            if (typeof root.graphEngine.addCommentToGraph === "function") {
                newId = root.graphEngine.addCommentToGraph(root.activeGraphId, "Notes", targetX, targetY, 300, 200);
            } else if (typeof root.graphEngine.addNodeToGraph === "function") {
                newId = root.graphEngine.addNodeToGraph(root.activeGraphId, "CommentNode", targetX, targetY);
            }

            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            if (dagCanvas && dagCanvas.requestPaint)
                dagCanvas.requestPaint();
        }
    }

    ContextMenuPopup {
        id: contextMenu

        selectedNodeIds: root.selectedNodeIds
        isCurrentGraphReadOnly: root.isCurrentGraphReadOnly
        currentGraphId: root.activeGraphId

        onCutRequested: root.cutSelectedNodes()
        onCopyRequested: root.copySelectedNodes()
        onPasteRequested: root.pasteNodes()
        onDuplicateRequested: root.duplicateSelectedNodes()

        onGroupSelectedRequested: {
            if (root.graphEngine && !root.isCurrentGraphReadOnly) {
                if (typeof root.graphEngine.createGroupInGraph === "function") {
                    root.graphEngine.createGroupInGraph(root.activeGraphId, "New Group", root.selectedNodeIds);
                } else {
                    root.createGroupFromSelected();
                }
                root.notifyGraphStateChanged();
            }
        }

        onDeleteSelectedRequested: root.deleteSelectedNodes()
        onSnapToGridRequested: root.snapSelectedToGrid()
        onAlignLeftRequested: root.alignSelectedLeft()
        onAlignTopRequested: root.alignSelectedTop()
        onDistributeHorizontallyRequested: root.distributeSelectedHorizontally()
        onFrameAllNodesRequested: root.frameAll()
        onResetZoomAndPanRequested: root.resetView()
    }
}
