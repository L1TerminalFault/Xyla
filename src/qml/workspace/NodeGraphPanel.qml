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
    property var activeTimelineModel: timelineModel
    property string activeSelectedClipId: activeTimelineModel ? activeTimelineModel.selectedClipId : ""

    // Cursor tracking for popup placement & mouse spawning
    property real currentMouseScreenX: 0
    property real currentMouseScreenY: 0
    property real currentMouseWorkspaceX: 0
    property real currentMouseWorkspaceY: 0

    // The single authoritative viewed graph ID
    property string activeGraphId: {
        if (!activeTimelineModel)
            return "default_io_graph";

        // 1. If a clip is selected on launch, check its attached graphs for the last user graph
        if (activeSelectedClipId !== "") {
            var attached = activeTimelineModel.getClipAttachedGraphs(activeSelectedClipId);
            for (var i = attached.length - 1; i >= 0; --i) {
                if (attached[i].id !== "default_io_graph" && !attached[i].isDefault) {
                    return attached[i].id;
                }
            }
        }

        // 2. Otherwise find the last available user graph in the whole project
        var allG = activeTimelineModel.getAllProjectGraphs();
        for (var j = allG.length - 1; j >= 0; --j) {
            if (allG[j].id !== "default_io_graph" && !allG[j].isDefault) {
                return allG[j].id;
            }
        }

        // 3. Fallback only if no custom graph exists anywhere
        return "default_io_graph";
    }

    // Subgraph / Group Drill-Down Navigation Stack
    property var navStack: [
        {
            id: currentGraphId,
            name: currentGraphName
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
                // At main graph: hide children that belong to groups
                if (!parentGroupId) {
                    list.push(node);
                }
            } else {
                // Inside a group: ONLY show members of that group
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
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || selectedNodeIds.length < 2)
            return;

        // 1. Snapshot the selected nodes
        var membersToGroup = selectedNodeIds.slice();

        // 2. Calculate center of selected nodes
        var avgX = 0, avgY = 0;
        for (var i = 0; i < membersToGroup.length; ++i) {
            var p = getNodeCenterPos(membersToGroup[i], 0, 0);
            avgX += p.x;
            avgY += p.y;
        }
        avgX = Math.round((avgX / membersToGroup.length) / 24) * 24;
        avgY = Math.round((avgY / membersToGroup.length) / 24) * 24;

        // 3. Create the GroupNode
        var newGroupId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, "GroupNode", avgX, avgY);
        if (newGroupId && newGroupId !== "") {
            root.nodePositions[newGroupId] = {
                x: avgX,
                y: avgY
            };

            // 4. CRITICAL: Register the members to the Group in C++ model
            if (root.activeTimelineModel.setGroupMemberNodeIds) {
                root.activeTimelineModel.setGroupMemberNodeIds(root.currentGraphId, newGroupId, membersToGroup);
            }

            selectedNodeIds = [newGroupId];
        }

        root.notifyGraphStateChanged();
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    function handleDropCardOnContainers(droppedNodeId, centerX, centerY) {
        // 1. Check Comment containers
        for (var c = 0; c < commentRepeater.count; ++c) {
            var commentItem = commentRepeater.itemAt(c);
            if (commentItem && commentItem.checkNodeDropIntersection(droppedNodeId, centerX, centerY)) {
                commentItem.acceptDroppedNode(droppedNodeId);
                return;
            }
        }

        // 2. Check Group containers
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
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || clipboardNodes.length === 0)
            return;

        var newSelected = [];
        var offsetX = 40;
        var offsetY = 40;

        for (var i = 0; i < clipboardNodes.length; ++i) {
            var item = clipboardNodes[i];
            var posX = item.x + offsetX;
            var posY = item.y + offsetY;

            var newId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, item.typeName, posX, posY);
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
    // Dynamic Placement Resolver using STRICTLY the real component dimensions
    // =========================================================================
    function resolveNewNodePlacement(nId, realW, realH) {
        var cur = getNodeCenterPos(nId, 0, 0);
        var gutter = 28;

        // Check collision using the exact reported component width & height
        if (!isPositionColliding(nId, cur.x, cur.y, realW, realH, root.nodePositions, gutter)) {
            // No collision: stays at exact requested mouse position!
            return;
        }

        // If colliding, expand outward in 24px increments until finding a spot
        // that completely fits this card's exact dimensions
        var bestX = Math.round(cur.x / 24) * 24;
        var bestY = Math.round(cur.y / 24) * 24;
        var found = false;

        for (var step = 1; step <= 60; ++step) {
            var r = step * 24;
            var candidates = [
                {
                    x: bestX + r,
                    y: bestY
                }                  // Right
                ,
                {
                    x: bestX,
                    y: bestY + r
                }                  // Down
                ,
                {
                    x: bestX + r,
                    y: bestY + r
                }              // Down-Right
                ,
                {
                    x: bestX - r,
                    y: bestY
                }                  // Left
                ,
                {
                    x: bestX,
                    y: bestY - r
                }                  // Up
                ,
                {
                    x: bestX - r,
                    y: bestY + r
                }              // Down-Left
                ,
                {
                    x: bestX + r,
                    y: bestY - r
                }              // Up-Right
                ,
                {
                    x: bestX - r,
                    y: bestY - r
                }               // Up-Left
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

        // Apply repositioning and update backend
        var temp = Object.assign({}, root.nodePositions);
        temp[nId] = {
            x: bestX,
            y: bestY
        };
        root.nodePositions = temp;

        if (root.activeTimelineModel) {
            root.activeTimelineModel.setNodePosition(root.currentGraphId, nId, bestX, bestY);
        }

        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // =========================================================================
    // FIX DELETION WITH INSTANT UI REFRESH
    // =========================================================================
    function deleteSelectedNodes() {
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var idToDelete = selectedNodeIds[i];
            // Remove node from C++ backend
            if (root.activeTimelineModel.removeNodeFromGraph) {
                root.activeTimelineModel.removeNodeFromGraph(root.currentGraphId, idToDelete);
            } else if (root.activeTimelineModel.removeNode) {
                root.activeTimelineModel.removeNode(root.currentGraphId, idToDelete);
            }
            delete root.nodePositions[idToDelete];
        }

        selectedNodeIds = [];
        root.notifyGraphStateChanged(); // <--- CRITICAL: Refreshes nodeList & linkList immediately!
        root.pinRevision++;
    }

    // =========================================================================
    // FIX SNAP & ALIGNMENT TO REFRESH WIRES SYNCHRONOUSLY
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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, sx, sy);
            }
        }
        root.nodePositions = temp;
        root.pinRevision++;
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

        // PASS THROUGH COLLISION SOLVER:
        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);

        // Commit to backend
        for (var k = 0; k < selectedNodeIds.length; ++k) {
            var nId = selectedNodeIds[k];
            var p = root.getNodeCenterPos(nId, 0, 0);
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, nId, p.x, p.y);
            }
        }
        root.pinRevision++;
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

        // PASS THROUGH COLLISION SOLVER:
        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);

        for (var k = 0; k < selectedNodeIds.length; ++k) {
            var nId = selectedNodeIds[k];
            var p = root.getNodeCenterPos(nId, 0, 0);
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, nId, p.x, p.y);
            }
        }
        root.pinRevision++;
        dagCanvas.requestPaint();
    }
    // function alignSelectedLeft() {
    //     if (selectedNodeIds.length < 2) return;
    //     var minX = Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         minX = Math.min(minX, getNodeCenterPos(selectedNodeIds[i], 0, 0).x);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         var curY = getNodeCenterPos(id, 0, 0).y;
    //         temp[id] = { x: minX, y: curY };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, minX, curY);
    //         }
    //     }
    //     root.nodePositions = temp;
    //     root.pinRevision++;
    //     dagCanvas.requestPaint();
    // }
    //
    // function alignSelectedTop() {
    //     if (selectedNodeIds.length < 2) return;
    //     var minY = Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         minY = Math.min(minY, getNodeCenterPos(selectedNodeIds[i], 0, 0).y);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         var curX = getNodeCenterPos(id, 0, 0).x;
    //         temp[id] = { x: curX, y: minY };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, curX, minY);
    //         }
    //     }
    //     root.nodePositions = temp;
    //     root.pinRevision++;
    //     dagCanvas.requestPaint();
    // }

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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, newX, curY);
            }
        }
        root.nodePositions = temp;
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // In NodeGraphPanel.qml under 'id: root':
    property var pinRegistry: ({})
    property int pinRevision: 0

    function registerPinPosition(nodeId, socketId, isOutput, wsX, wsY) {
        if (isNaN(wsX) || isNaN(wsY))
            return;
        var key = nodeId + ":" + socketId + ":" + (isOutput ? "out" : "in");
        pinRegistry[key] = Qt.point(wsX, wsY);
        pinRevision++;
    }

    // function getRegisteredPinPos(nodeId, socketId, isOutput) {
    //     var _ = pinRevision;
    //     var _np = root.nodePositions; // <--- CRITICAL: Triggers re-evaluation when ANY card moves!
    //     var key = nodeId + ":" + socketId + ":" + (isOutput ? "out" : "in");
    //     if (pinRegistry[key] !== undefined && pinRegistry[key] !== null) {
    //         return pinRegistry[key];
    //     }
    //
    //     for (var i = 0; i < cardRepeater.count; ++i) {
    //         var c = cardRepeater.itemAt(i);
    //         if (c && c.nodeId === nodeId) {
    //             var directPt = c.getSocketWorkspacePos(socketId, isOutput);
    //             if (directPt && !isNaN(directPt.x) && !isNaN(directPt.y)) {
    //                 pinRegistry[key] = directPt;
    //                 return directPt;
    //             }
    //         }
    //     }
    //
    //     return calculatePinGlobalPos(nodeId, socketId, isOutput);
    // }
    //
    //
    function getRegisteredPinPos(nodeId, socketId, isOutput) {
        if (!nodeId || !socketId)
            return Qt.point(0, 0);

        // 1. Check live card delegates safely
        if (typeof cardRepeater !== "undefined" && cardRepeater) {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var card = cardRepeater.itemAt(i);
                // Check if card exists, matches nodeId, AND the function is valid in the current context
                if (card && card.nodeId === nodeId && typeof card.getPinCenterInWorkspace === "function") {
                    try {
                        var pt = card.getPinCenterInWorkspace(socketId, isOutput);
                        if (pt && !isNaN(pt.x) && !isNaN(pt.y)) {
                            return pt;
                        }
                    } catch (e) {
                        // Context not ready, fall through to analytic calculation
                    }
                }
            }
        }

        // 2. Analytic fallback (zero-drift mathematical pin calculation)
        return calculatePinGlobalPos(nodeId, socketId, isOutput);
    }
    // function getRegisteredPinPos(nodeId, socketId, isOutput) {
    //     // Find the live Card in cardRepeater
    //     for (var i = 0; i < cardRepeater.count; ++i) {
    //         var card = cardRepeater.itemAt(i);
    //         if (card && card.nodeId === nodeId) {
    //             // Query live world position directly from the card
    //             return card.getPinCenterInWorkspace(socketId, isOutput);
    //         }
    //     }
    //
    //     // Fallback if card is not yet created
    //     return calculatePinGlobalPos(nodeId, socketId, isOutput);
    // }

    // function registerPinPosition(nodeId, socketId, isOutput, wsPt) {
    //     var key = nodeId + ":" + socketId + ":" + (isOutput ? "out" : "in");
    //     pinRegistry[key] = wsPt;
    //     // Trigger links repaint
    //     if (dagCanvas && dagCanvas.requestPaint) {
    //         dagCanvas.requestPaint();
    //     }
    // }
    //
    // function getRegisteredPinPos(nodeId, socketId, isOutput) {
    //     var key = nodeId + ":" + socketId + ":" + (isOutput ? "out" : "in");
    //     if (pinRegistry[key] !== undefined) {
    //         return pinRegistry[key];
    //     }
    //     // Fallback calculation
    //     return calculatePinGlobalPos(nodeId, socketId, isOutput);
    // }

    readonly property string currentGraphId: activeGraphId
    readonly property bool isCurrentGraphReadOnly: currentGraphId === "default_io_graph"
    readonly property string currentGraphName: {
        if (!activeTimelineModel || isCurrentGraphReadOnly)
            return "Default";
        var n = activeTimelineModel.getGraphName(activeGraphId);
        return (n && n !== "") ? n : "Untitled Graph";
    }

    // EXPLICIT boolean for link button — zero dependency on opaque JS binding
    property bool isCurrentGraphLinked: false

    function refreshLinkState() {
        if (!activeTimelineModel || activeSelectedClipId === "" || isCurrentGraphReadOnly) {
            isCurrentGraphLinked = false;
            return;
        }
        var attached = activeTimelineModel.getClipAttachedGraphs(activeSelectedClipId);
        var found = false;
        for (var i = 0; i < attached.length; ++i) {
            if (attached[i].id === activeGraphId) {
                found = true;
                break;
            }
        }
        isCurrentGraphLinked = found;
    }

    // Central function to select and display ANY graph
    function selectGraph(targetId) {
        if (!targetId || targetId === "")
            return;
        activeGraphId = targetId;
        if (activeTimelineModel) {
            activeTimelineModel.setStandaloneActiveGraphId(targetId);
        }
        refreshLinkState();
        tabBar.graphSelectWrapper.refreshGraphs();
    }

    // React to clip selection changes on timeline
    onActiveSelectedClipIdChanged: {
        if (activeTimelineModel && activeSelectedClipId !== "") {
            var attached = activeTimelineModel.getClipAttachedGraphs(activeSelectedClipId);
            var lastUserGraphId = "";

            // Find the last non-default graph attached to the clip
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

        // If clip has no custom graphs or in standalone mode, pick the last project graph
        var allG = activeTimelineModel ? activeTimelineModel.getAllProjectGraphs() : [];
        for (var j = allG.length - 1; j >= 0; --j) {
            if (allG[j].id !== "default_io_graph" && !allG[j].isDefault) {
                selectGraph(allG[j].id);
                return;
            }
        }

        // Only fallback to default if literally zero custom graphs exist in the project
        selectGraph("default_io_graph");
    }

    // Revision counter incremented on every single graph action
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
        target: activeTimelineModel ? activeTimelineModel : null
        function onSelectedClipIdChanged() {
            root.notifyGraphStateChanged();
        }
        function onProjectGraphsChanged() {
            root.notifyGraphStateChanged();
            tabBar.graphSelectWrapper.refreshGraphs();
            refreshLinkState();
        }
        function onActiveGraphChanged() {
            refreshLinkState();
        }
    }

    // Check if the currently viewed graph is bound to the selected clip
    readonly property bool isCurrentGraphAttachedToClip: {
        if (!activeTimelineModel || activeSelectedClipId === "")
            return false;
        var attached = activeTimelineModel.getClipAttachedGraphs(activeSelectedClipId);
        for (var i = 0; i < attached.length; ++i) {
            if (attached[i].id === currentGraphId)
                return true;
        }
        return false;
    }

    // Nodes and links from the active graph
    // BEFORE:
    // readonly property var nodeList: activeTimelineModel ? activeTimelineModel.getGraphNodes(currentGraphId) : []
    // readonly property var linkList: activeTimelineModel ? activeTimelineModel.getGraphLinks(currentGraphId) : []

    // AFTER: Explicitly bind to graphRevision so any C++ addition forces an instant refresh
    readonly property var nodeList: {
        var _ = root.graphRevision;
        return activeTimelineModel ? activeTimelineModel.getGraphNodes(currentGraphId) : [];
    }
    readonly property var linkList: {
        var _ = root.graphRevision;
        return activeTimelineModel ? activeTimelineModel.getGraphLinks(currentGraphId) : [];
    }

    property var selectedClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    property real zoomLevel: 1.0
    property real panX: 0.0
    property real panY: 0.0

    // --- Smooth View Navigation Engine ---
    property real targetZoom: 1.0
    property real targetPanX: 0.0
    property real targetPanY: 0.0
    // 0.0 = True Straight Line, 1.0 = Organic Curved Wire
    property real wireCurvatureFactor: wireStyle === "straight" ? 0.0 : 1.0

    // Calculates a clearance detour if wire passes through an intervening node card
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

    // Get card bounding box with padding
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

    // Precise segment-to-box intersection test
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

    // Comprehensive Multi-Node Obstacle Solver (Handles 1, 2, or N nodes + connectees)
    // Precise Segment-to-Box Intersection (Tests if segment intersects rectangle)
    function lineHitsCardBox(p1x, p1y, p2x, p2y, left, top, right, bottom) {
        // Fast bounding box rejection
        if ((p1x < left && p2x < left) || (p1x > right && p2x > right) || (p1y < top && p2y < top) || (p1y > bottom && p2y > bottom)) {
            return false;
        }
        // Segment cross test against 4 edges
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, right, top))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, bottom, right, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, left, bottom))
            return true;
        if (segmentsIntersect(p1x, p1y, p2x, p2y, right, top, right, bottom))
            return true;

        // Check if segment midpoint is inside the box
        var midX = (p1x + p2x) / 2;
        var midY = (p1y + p2y) / 2;
        if (midX >= left && midX <= right && midY >= top && midY <= bottom)
            return true;

        return false;
    }

    // Clean Wire Path Solver: Zero false dodging, handles multiple obstacles, perfect curves
    function solveWirePath(p1, p2, fromId, toId) {
        // Direct main span between the pin tips
        var spanX1 = p1.x + 8;
        var spanY1 = p1.y;
        var spanX2 = p2.x - 8;
        var spanY2 = p2.y;

        var obstacles = [];
        var pad = 12;

        // ONLY examine nodes that are NEITHER the source nor the target!
        for (var i = 0; i < nodeList.length; ++i) {
            var n = nodeList[i];
            if (n.id === fromId || n.id === toId)
                continue;

            var pos = getNodeCenterPos(n.id, n.x, n.y);
            var w = 180;
            var h = getNodeRealHeight(n.id);

            var bL = pos.x - w / 2 - pad;
            var bR = pos.x + w / 2 + pad;
            var bT = pos.y - h / 2 - pad;
            var bB = pos.y + h / 2 + pad;

            if (lineHitsCardBox(spanX1, spanY1, spanX2, spanY2, bL, bT, bR, bB)) {
                obstacles.push({
                    left: bL,
                    right: bR,
                    top: bT,
                    bottom: bB,
                    centerY: pos.y
                });
            }
        }

        // --- CASE 0: NO OBSTACLES (Normal direct flow) ---
        if (obstacles.length === 0) {
            var dx = p2.x - p1.x;
            var tension = Math.max(40, Math.min(180, Math.abs(dx) * 0.5));
            if (dx < 0) {
                // Reverse flow (node B is to the left of node A):
                // Push curves horizontally outward from pins so it loops back naturally
                tension = Math.max(60, Math.abs(dx) * 0.4 + 40);
            }
            return {
                isBlocked: false,
                // Straight line: single segment from p1 to p2
                straightPts: [Qt.point(p1.x, p1.y), Qt.point(p2.x, p2.y)],
                // Cubic Bezier control points
                c1x: p1.x + tension,
                c1y: p1.y,
                c2x: p2.x - tension,
                c2y: p2.y
            };
        }

        // --- CASE 1: OBSTACLE(S) IN DIRECT PATH ---
        // Compute the combined bounding envelope of ALL obstructing nodes
        var envL = Infinity, envR = -Infinity, envT = Infinity, envB = -Infinity;
        for (var o = 0; o < obstacles.length; ++o) {
            envL = Math.min(envL, obstacles[o].left);
            envR = Math.max(envR, obstacles[o].right);
            envT = Math.min(envT, obstacles[o].top);
            envB = Math.max(envB, obstacles[o].bottom);
        }

        // Decide whether routing above or below the obstacles gives the shorter detour
        var distAbove = Math.abs(p1.y - envT) + Math.abs(p2.y - envT);
        var distBelow = Math.abs(p1.y - envB) + Math.abs(p2.y - envB);
        var detourY = (distAbove <= distBelow) ? (envT - 16) : (envB + 16);

        var corner1X = Math.min(spanX1 + 10, envL - 10);
        var corner2X = Math.max(spanX2 - 10, envR + 10);

        // Control point Y elevation for the curve so it clears the obstacles
        var spanMidY = (p1.y + p2.y) / 2;
        var pushY = detourY - spanMidY;
        var curveApexY = spanMidY + (pushY * 1.5);

        return {
            isBlocked: true,
            straightPts: [Qt.point(p1.x, p1.y), Qt.point(corner1X, detourY), Qt.point(corner2X, detourY), Qt.point(p2.x, p2.y)],
            c1x: p1.x + Math.max(45, Math.abs(p2.x - p1.x) * 0.35),
            c1y: curveApexY,
            c2x: p2.x - Math.max(45, Math.abs(p2.x - p1.x) * 0.35),
            c2y: curveApexY
        };
    }

    // Returns true if a card of size (w, h) placed at (cx, cy) overlaps ANY other node
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

            // AABB overlap test including clearance gutter
            if (myL < oR + gutter && myR > oL - gutter && myT < oB + gutter && myB > oT - gutter) {
                return true;
            }
        }
        return false;
    }

    // Unbreakable spatial resolver: guaranteed to never allow any card to sit on any other card
    // Resolves overlaps for ALL selected nodes that were moved during the drag operation
    function resolveAllSelectedNodesOverlap(primaryMovedId) {
        var movedIds = [];
        if (selectedNodeIds && selectedNodeIds.length > 0) {
            movedIds = selectedNodeIds.slice();
        } else if (primaryMovedId && primaryMovedId !== "") {
            movedIds = [primaryMovedId];
        } else {
            return;
        }

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 28;

        for (var m = 0; m < movedIds.length; ++m) {
            var mId = movedIds[m];
            var cur = root.getNodeCenterPos(mId, 0, 0);
            var cardW = 180;
            var cardH = root.getNodeRealHeight(mId);

            var bestX = cur.x; // Math.round(cur.x / 24) * 24;
            var bestY = cur.y; // Math.round(cur.y / 24) * 24;

            if (isPositionColliding(mId, bestX, bestY, cardW, cardH, temp, gutter)) {
                var found = false;
                // Search in 24px increments outward
                for (var step = 1; step <= 25; ++step) {
                    var r = step * 24;
                    var candidates = [
                        {
                            x: bestX,
                            y: bestY + r
                        },
                        {
                            x: bestX + r,
                            y: bestY
                        },
                        {
                            x: bestX,
                            y: bestY - r
                        },
                        {
                            x: bestX - r,
                            y: bestY
                        },
                        {
                            x: bestX + r,
                            y: bestY + r
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

                    for (var i = 0; i < candidates.length; ++i) {
                        if (!isPositionColliding(mId, candidates[i].x, candidates[i].y, cardW, cardH, temp, gutter)) {
                            bestX = candidates[i].x;
                            bestY = candidates[i].y;
                            found = true;
                            break;
                        }
                    }
                    if (found)
                        break;
                }
            }

            temp[mId] = {
                x: bestX,
                y: bestY
            };

            // Synchronize each resolved position immediately to C++ backend
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, mId, bestX, bestY);
            }
        }

        root.nodePositions = temp;
        root.pinRevision++;
    }
    // function resolveAllSelectedNodesOverlap(primaryMovedId) {
    //     var movedIds = [];
    //     if (selectedNodeIds && selectedNodeIds.length > 0) {
    //         movedIds = selectedNodeIds.slice();
    //     } else {
    //         movedIds = [primaryMovedId];
    //     }
    //
    //     var temp = Object.assign({}, root.nodePositions);
    //     var gutter = 24;
    //
    //     // Resolve each moved node in sequence against stationary nodes AND already-placed moved nodes
    //     for (var m = 0; m < movedIds.length; ++m) {
    //         var mId = movedIds[m];
    //         var cur = root.getNodeCenterPos(mId, 0, 0);
    //         var cardW = 180;
    //         var cardH = root.getNodeRealHeight(mId);
    //
    //         var bestX = cur.x;
    //         var bestY = cur.y;
    //
    //         // Check if (bestX, bestY) collides with ANY other node on the canvas
    //         if (isPositionColliding(mId, bestX, bestY, cardW, cardH, temp, gutter)) {
    //             // Search outward in 24px steps for nearest collision-free position
    //             var found = false;
    //             for (var r = 24; r <= 1200; r += 24) {
    //                 var candidates = [
    //                     {
    //                         x: cur.x,
    //                         y: cur.y + r
    //                     },
    //                     {
    //                         x: cur.x,
    //                         y: cur.y - r
    //                     },
    //                     {
    //                         x: cur.x + r,
    //                         y: cur.y
    //                     },
    //                     {
    //                         x: cur.x - r,
    //                         y: cur.y
    //                     },
    //                     {
    //                         x: cur.x + r,
    //                         y: cur.y + r
    //                     },
    //                     {
    //                         x: cur.x - r,
    //                         y: cur.y + r
    //                     },
    //                     {
    //                         x: cur.x + r,
    //                         y: cur.y - r
    //                     },
    //                     {
    //                         x: cur.x - r,
    //                         y: cur.y - r
    //                     }
    //                 ];
    //                 for (var c = 0; c < candidates.length; ++c) {
    //                     if (!isPositionColliding(mId, candidates[c].x, candidates[c].y, cardW, cardH, temp, gutter)) {
    //                         bestX = candidates[c].x;
    //                         bestY = candidates[c].y;
    //                         found = true;
    //                         break;
    //                     }
    //                 }
    //                 if (found)
    //                     break;
    //             }
    //         }
    //
    //         temp[mId] = {
    //             x: bestX,
    //             y: bestY
    //         };
    //     }
    //
    //     root.nodePositions = temp;
    // }

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

    property var groupList: [] // Array of { id: string, name: string, nodeIds: [] }

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

            // Does segment (p1, p2) intersect this box?
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
        // 1. If card is instantiated in canvas, read its actual dynamic height
        for (var i = 0; i < cardRepeater.count; ++i) {
            var c = cardRepeater.itemAt(i);
            if (c && c.nodeId === nodeId) {
                return c.height;
            }
        }
        // 2. Otherwise calculate analytically from socket count
        for (var j = 0; j < nodeList.length; ++j) {
            if (nodeList[j].id === nodeId) {
                var n = nodeList[j];
                var inCount = (n.inputs ? n.inputs.length : 0);
                var outCount = (n.outputs ? n.outputs.length : 0);
                // Header (28) + topMargin (8) + (rows * 28) + bottomPadding (14)
                return Math.max(42, 28 + 8 + ((inCount + outCount) * 28) + 14);
            }
        }
        return 90;
    }

    // function createGroupFromSelected() {
    //     if (selectedNodeIds.length === 0)
    //         return;
    //     var gId = "group_" + Date.now();
    //     var newGroup = {
    //         id: gId,
    //         name: "Node Group",
    //         nodeIds: selectedNodeIds.slice()
    //     };
    //     var copy = root.groupList.slice();
    //     copy.push(newGroup);
    //     root.groupList = copy;
    // }

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
    // Spatial Collision & Free Space Discovery Solver
    // =========================================================================
    // =========================================================================
    // Deterministic, Orderly Free Space Discovery (No Random Scatter)
    // =========================================================================
    // =========================================================================
    // Nearest-Free-Space Solver (Tightly Clustered Around Mouse Cursor)
    // =========================================================================
    function findFreeSpaceAround(targetX, targetY, excludeId) {
        var cardW = 180;
        var cardH = 110;
        var gutter = 24;

        // Snap target position to 24px grid
        var startX = Math.round(targetX / 24) * 24;
        var startY = Math.round(targetY / 24) * 24;

        // 1. If cursor position is already completely collision-free, place it right there!
        if (!isPositionColliding(excludeId, startX, startY, cardW, cardH, root.nodePositions, gutter)) {
            return Qt.point(startX, startY);
        }

        // 2. Expand outward in tight 24px rings to guarantee minimum distance from mouse cursor
        for (var step = 1; step <= 35; ++step) {
            var rX = step * 24;
            var rY = step * 24;

            // Prioritize right and below (natural DAG flow), then left and above
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
    // function findFreeSpaceAround(targetX, targetY, excludeId) {
    //     var nodeW = 190, nodeH = 110, padding = 32;
    //     var checkX = targetX, checkY = targetY;
    //     var angle = 0, radius = 0, step = 30;
    //
    //     while (isSpaceOccupied(checkX, checkY, nodeW, nodeH, excludeId)) {
    //         radius += 18;
    //         angle += 45;
    //         var rad = angle * (Math.PI / 180);
    //         checkX = targetX + Math.cos(rad) * radius;
    //         checkY = targetY + Math.sin(rad) * radius;
    //         // Align search to grid
    //         checkX = Math.round(checkX / 24) * 24;
    //         checkY = Math.round(checkY / 24) * 24;
    //     }
    //     return {
    //         x: checkX,
    //         y: checkY
    //     };
    // }

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

    onZoomLevelChanged: dagCanvas.requestPaint()
    onPanXChanged: dagCanvas.requestPaint()
    onPanYChanged: dagCanvas.requestPaint()

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

    // Multi-Selection State
    // View State Flags
    property bool showGrid: true
    property bool isSnappingEnabled: true

    // Wire style toggle: "curve" or "straight"
    property string wireStyle: "curve"

    property var selectedNodeIds: []
    property bool isBoxSelecting: false
    property real boxStartX: 0
    property real boxStartY: 0
    property real boxCurrentX: 0
    property real boxCurrentY: 0

    // Interactive Wire Drag State
    property bool isConnectingWire: false
    property string wireFromNodeId: ""
    property string wireFromSocketId: ""
    property real wireMouseX: 0
    property real wireMouseY: 0

    // Alt-Key Scissor Line Cutting State
    property bool isAltPressed: false
    property bool isCuttingScissor: false
    property real scissorStartX: 0
    property real scissorStartY: 0
    property real scissorCurrentX: 0
    property real scissorCurrentY: 0

    // Cursor tracking for popup placement
    // property real currentMouseScreenX: 0
    // property real currentMouseScreenY: 0

    // Red Dotted Alignment Snap Lines
    property bool snapGuideXVisible: false
    property bool snapGuideYVisible: false
    property real snapGuideXPos: 0
    property real snapGuideYPos: 0

    function computeSnappedPosition(movingNodeId, rawCenterX, rawCenterY) {
        if (!root.isSnappingEnabled) {
            snapGuideXVisible = false;
            snapGuideYVisible = false;
            return {
                x: rawCenterX,
                y: rawCenterY
            };
        }

        var snapDist = 9.0;
        var myW = 180;
        // TRUE dynamic height of the moving card
        var myH = getNodeRealHeight(movingNodeId);

        var myL = rawCenterX - myW / 2;
        var myR = rawCenterX + myW / 2;
        var myT = rawCenterY - myH / 2;
        var myB = rawCenterY + myH / 2;

        var bestDiffX = snapDist + 1;
        var bestSnappedCenterX = rawCenterX;
        var guideX = 0;
        var foundX = false;

        var bestDiffY = snapDist + 1;
        var bestSnappedCenterY = rawCenterY;
        var guideY = 0;
        var foundY = false;

        // -------------------------------------------------------------
        // A. SIBLING SNAPPING (True 4-Edges and True Centers)
        // -------------------------------------------------------------
        for (var i = 0; i < nodeList.length; ++i) {
            var sib = nodeList[i];
            if (sib.id === movingNodeId || selectedNodeIds.indexOf(sib.id) !== -1)
                continue;

            var sPos = getNodeCenterPos(sib.id, sib.x, sib.y);
            var sW = 180;
            // TRUE dynamic height of this sibling
            var sH = getNodeRealHeight(sib.id);

            var sL = sPos.x - sW / 2;
            var sR = sPos.x + sW / 2;
            var sT = sPos.y - sH / 2;
            var sB = sPos.y + sH / 2;

            // X-Alignments (Left-to-Left, Right-to-Right, Left-to-Right, Right-to-Left, Centers)
            var xPairs = [
                {
                    test: myL - sL,
                    snapCenter: sL + myW / 2,
                    guide: sL
                },
                {
                    test: myR - sR,
                    snapCenter: sR - myW / 2,
                    guide: sR
                },
                {
                    test: myL - sR,
                    snapCenter: sR + myW / 2,
                    guide: sR
                },
                {
                    test: myR - sL,
                    snapCenter: sL - myW / 2,
                    guide: sL
                },
                {
                    test: rawCenterX - sPos.x,
                    snapCenter: sPos.x,
                    guide: sPos.x
                }
            ];

            for (var xi = 0; xi < xPairs.length; ++xi) {
                var dX = Math.abs(xPairs[xi].test);
                if (dX <= snapDist && dX < bestDiffX) {
                    bestDiffX = dX;
                    bestSnappedCenterX = xPairs[xi].snapCenter;
                    guideX = xPairs[xi].guide;
                    foundX = true;
                }
            }

            // Y-Alignments (Top-to-Top, Bottom-to-Bottom, Top-to-Bottom, Bottom-to-Top, Centers)
            var yPairs = [
                {
                    test: myT - sT,
                    snapCenter: sT + myH / 2,
                    guide: sT
                },
                {
                    test: myB - sB,
                    snapCenter: sB - myH / 2,
                    guide: sB
                },
                {
                    test: myT - sB,
                    snapCenter: sB + myH / 2,
                    guide: sB
                },
                {
                    test: myB - sT,
                    snapCenter: sT - myH / 2,
                    guide: sT
                },
                {
                    test: rawCenterY - sPos.y,
                    snapCenter: sPos.y,
                    guide: sPos.y
                }
            ];

            for (var yi = 0; yi < yPairs.length; ++yi) {
                var dY = Math.abs(yPairs[yi].test);
                if (dY <= snapDist && dY < bestDiffY) {
                    bestDiffY = dY;
                    bestSnappedCenterY = yPairs[yi].snapCenter;
                    guideY = yPairs[yi].guide;
                    foundY = true;
                }
            }
        }

        // -------------------------------------------------------------
        // B. SUBGRID SNAPPING (Every 24px Subgrid)
        // -------------------------------------------------------------
        var step = 24;

        if (!foundX) {
            var gridSnapCandidatesX = [
                {
                    val: rawCenterX,
                    offset: 0,
                    guideOffset: 0
                },
                {
                    val: myL,
                    offset: myW / 2,
                    guideOffset: -myW / 2
                },
                {
                    val: myR,
                    offset: -myW / 2,
                    guideOffset: myW / 2
                }
            ];
            for (var giX = 0; giX < gridSnapCandidatesX.length; ++giX) {
                var targetX = gridSnapCandidatesX[giX].val;
                var nearestGridX = Math.round(targetX / step) * step;
                var diffGridX = Math.abs(targetX - nearestGridX);
                if (diffGridX <= snapDist && diffGridX < bestDiffX) {
                    bestDiffX = diffGridX;
                    bestSnappedCenterX = nearestGridX + gridSnapCandidatesX[giX].offset;
                    guideX = nearestGridX;
                    foundX = true;
                }
            }
        }

        if (!foundY) {
            var gridSnapCandidatesY = [
                {
                    val: rawCenterY,
                    offset: 0,
                    guideOffset: 0
                },
                {
                    val: myT,
                    offset: myH / 2,
                    guideOffset: -myH / 2
                },
                {
                    val: myB,
                    offset: -myH / 2,
                    guideOffset: myH / 2
                }
            ];
            for (var giY = 0; giY < gridSnapCandidatesY.length; ++giY) {
                var targetY = gridSnapCandidatesY[giY].val;
                var nearestGridY = Math.round(targetY / step) * step;
                var diffGridY = Math.abs(targetY - nearestGridY);
                if (diffGridY <= snapDist && diffGridY < bestDiffY) {
                    bestDiffY = diffGridY;
                    bestSnappedCenterY = nearestGridY + gridSnapCandidatesY[giY].offset;
                    guideY = nearestGridY;
                    foundY = true;
                }
            }
        }

        snapGuideXVisible = foundX;
        snapGuideYVisible = foundY;
        snapGuideXPos = guideX;
        snapGuideYPos = guideY;

        return {
            x: bestSnappedCenterX,
            y: bestSnappedCenterY
        };
    }

    property string selectionMode: "box" // "box" | "circle" | "lasso"
    property real circleRadius: 0
    property var lassoPoints: [] // Array of {x, y}

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

    // Segment-to-segment intersection
    // Checks if segment (p1->p2) intersects segment (p3->p4)
    function segmentsIntersect(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y) {
        var d = (p2x - p1x) * (p4y - p3y) - (p2y - p1y) * (p4x - p3x);
        if (Math.abs(d) < 1e-9)
            return false;
        var u = ((p3x - p1x) * (p4y - p3y) - (p3y - p1y) * (p4x - p3x)) / d;
        var v = ((p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x)) / d;
        return (u >= 0.0 && u <= 1.0 && v >= 0.0 && v <= 1.0);
    }

    // Checks if point (px, py) is inside polygon poly = [{x, y}, ...]
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

    // 1-Pixel Touch / Intersection Test for a Card against the Lasso Polygon
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

        // 1. Any of the 4 card corners inside lasso?
        if (isPointInPoly(cL, cT, poly) || isPointInPoly(cR, cT, poly) || isPointInPoly(cL, cB, poly) || isPointInPoly(cR, cB, poly)) {
            return true;
        }

        // 2. Any lasso path point inside the card rectangle?
        for (var p = 0; p < poly.length; ++p) {
            var pt = poly[p];
            if (pt.x >= cL && pt.x <= cR && pt.y >= cT && pt.y <= cB) {
                return true;
            }
        }

        // 3. Does any edge of the card intersect any edge of the lasso polygon?
        var cardEdges = [
            {
                x1: cL,
                y1: cT,
                x2: cR,
                y2: cT
            } // Top
            ,
            {
                x1: cR,
                y1: cT,
                x2: cR,
                y2: cB
            } // Right
            ,
            {
                x1: cR,
                y1: cB,
                x2: cL,
                y2: cB
            } // Bottom
            ,
            {
                x1: cL,
                y1: cB,
                x2: cL,
                y2: cT
            }  // Left
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

    // Comprehensive 1px Lasso-to-Node-Box Intersection Test
    function nodeIntersectsLasso(nodeBox, poly) {
        if (!poly || poly.length < 3)
            return false;
        var left = nodeBox.x, right = nodeBox.x + nodeBox.w;
        var top = nodeBox.y, bottom = nodeBox.y + nodeBox.h;

        // 1. Check if any node corner or center is inside the lasso
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
            if (isPointInPolygon(testPoints[p].x, testPoints[p].y, poly))
                return true;
        }

        // 2. Check if any lasso vertex is inside the node rectangle
        for (var v = 0; v < poly.length; ++v) {
            if (poly[v].x >= left && poly[v].x <= right && poly[v].y >= top && poly[v].y <= bottom) {
                return true;
            }
        }

        // 3. Check if any lasso line segment crosses any of the 4 bounding box edges
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

    // Align all selected nodes along their average/mean horizontal center (Average X)
    // Align all selected nodes along their average/mean horizontal center (Average X)
    // =========================================================================
    // Align strictly on Average X axis, resolving collisions ONLY along Y
    // =========================================================================
    function alignSelectedToAverageHorizontal() {
        if (selectedNodeIds.length < 2)
            return;

        // 1. Calculate Average X
        var sumX = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumX += getNodeCenterPos(selectedNodeIds[i], 0, 0).x;
        }
        var targetX = Math.round((sumX / selectedNodeIds.length) / 24) * 24;

        // 2. Sort nodes by current Y so their vertical order is preserved
        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).y - getNodeCenterPos(b, 0, 0).y;
        });

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 28;

        // 3. Place each node at targetX, resolving collisions ONLY along Y (staying locked to targetX)
        for (var j = 0; j < sorted.length; ++j) {
            var id = sorted[j];
            var curY = Math.round(getNodeCenterPos(id, 0, 0).y / 24) * 24;
            var cardW = 180;
            var cardH = root.getNodeRealHeight(id);

            var bestY = curY;
            if (isPositionColliding(id, targetX, bestY, cardW, cardH, temp, gutter)) {
                // Search ONLY along Y axis (above and below) to strictly preserve the X column
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

            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, targetX, bestY);
            }
        }

        root.nodePositions = temp;
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // =========================================================================
    // Align strictly on Average Y axis, resolving collisions ONLY along X
    // =========================================================================
    function alignSelectedToAverageVertical() {
        if (selectedNodeIds.length < 2)
            return;

        // 1. Calculate Average Y
        var sumY = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumY += getNodeCenterPos(selectedNodeIds[i], 0, 0).y;
        }
        var targetY = Math.round((sumY / selectedNodeIds.length) / 24) * 24;

        // 2. Sort nodes by current X so their horizontal order is preserved
        var sorted = selectedNodeIds.slice().sort(function (a, b) {
            return getNodeCenterPos(a, 0, 0).x - getNodeCenterPos(b, 0, 0).x;
        });

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 28;

        // 3. Place each node at targetY, resolving collisions ONLY along X (staying locked to targetY)
        for (var j = 0; j < sorted.length; ++j) {
            var id = sorted[j];
            var curX = Math.round(getNodeCenterPos(id, 0, 0).x / 24) * 24;
            var cardW = 180;
            var cardH = root.getNodeRealHeight(id);

            var bestX = curX;
            if (isPositionColliding(id, bestX, targetY, cardW, cardH, temp, gutter)) {
                // Search ONLY along X axis (left and right) to strictly preserve the Y row
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

            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, bestX, targetY);
            }
        }

        root.nodePositions = temp;
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // Align all selected nodes along their average/mean vertical center (Average Y)
    // function alignSelectedToAverageVertical() {
    //     if (selectedNodeIds.length < 2)
    //         return;
    //     var sumY = 0;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         sumY += getNodeCenterPos(selectedNodeIds[i], 0, 0).y;
    //     }
    //     var avgY = Math.round(sumY / selectedNodeIds.length);
    //
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         var curX = getNodeCenterPos(id, 0, 0).x;
    //         temp[id] = {
    //             x: curX,
    //             y: avgY
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, curX, avgY);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

    // Robust, zero-delegate-dependency pin calculator
    function calculatePinGlobalPos(nodeId, socketId, isOutput) {
        var nData = null;
        for (var j = 0; j < root.nodeList.length; ++j) {
            if (root.nodeList[j].id === nodeId) {
                nData = root.nodeList[j];
                break;
            }
        }
        var center = root.getNodeCenterPos(nodeId, nData ? nData.x : 0, nData ? nData.y : 0);
        var cardW = 180;
        var px = center.x + (isOutput ? (cardW / 2) : (-cardW / 2));
        var cardH = root.getNodeRealHeight(nodeId);
        var topY = center.y - cardH / 2;

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
            return Qt.point(px, topY + 28 + 8 + (sIdx * 24) + 12);
        } else {
            if (nData && nData.inputs) {
                for (var k = 0; k < nData.inputs.length; ++k) {
                    if (nData.inputs[k].id === socketId) {
                        sIdx = k;
                        break;
                    }
                }
            }
            return Qt.point(px, topY + 28 + 8 + (sIdx * 24) + 12);
        }
    }

    // Inserts a Reroute dot on an existing wire connection
    function insertRerouteOnLink(link, clickWsX, clickWsY) {
        if (!root.activeTimelineModel || root.currentGraphId === "")
            return;

        // 1. Add the "Reroute" node at the click position
        var newRerouteId = "";
        if (root.activeTimelineModel.addNodeToGraph) {
            newRerouteId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, "Reroute", clickWsX, clickWsY);
        }

        if (!newRerouteId || newRerouteId === "") {
            console.warn("[NodeGraphPanel] Failed to create Reroute node on link");
            return;
        }

        // 2. Disconnect the original wire
        root.activeTimelineModel.disconnectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);

        // 3. Connect: fromNode -> reroute.in, and reroute.out -> toNode
        root.activeTimelineModel.connectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, newRerouteId, "in");

        root.activeTimelineModel.connectSockets(root.currentGraphId, newRerouteId, "out", link.toNodeId, link.toSocketId);
    }

    function clearAllPinHighlights() {
        root.activeHoveredTargetNodeId = "";
        root.activeHoveredTargetSocketId = "";
        if (typeof cardRepeater !== "undefined") {
            for (var i = 0; i < cardRepeater.count; ++i) {
                var c = cardRepeater.itemAt(i);
                if (c && c.activeHighlightSocketId !== undefined) {
                    c.activeHighlightSocketId = "";
                }
            }
        }
    }

    // 2. Nearest Input Pin Detector with Hover Notification & Magnetic Snapping
    property string activeHoveredTargetNodeId: ""
    property string activeHoveredTargetSocketId: ""

    /// NOTE: REVERSION ENDS NOW

    function findTargetInputPinAt(wsX, wsY) {
        // Generous detection: 36px radius around the pin, or anywhere on the input row
        for (var i = 0; i < cardRepeater.count; ++i) {
            var card = cardRepeater.itemAt(i);
            if (!card || card.nodeId === root.wireFromNodeId)
                continue;

            // Check if mouse is near this card's bounding box
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

                    // If released within 36px of the pin, or within the horizontal input row
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
    // function findTargetInputPinAt(wsX, wsY) {
    //     var threshold = 28.0; // In world space pixels
    //     for (var i = 0; i < cardRepeater.count; ++i) {
    //         var card = cardRepeater.itemAt(i);
    //         if (!card || card.nodeId === root.wireFromNodeId)
    //             continue;
    //
    //         if (card.nodeData && card.nodeData.inputs) {
    //             for (var s = 0; s < card.nodeData.inputs.length; ++s) {
    //                 var sock = card.nodeData.inputs[s];
    //                 var pinPos = card.getSocketWorkspacePos(sock.id, false);
    //                 var dx = wsX - pinPos.x;
    //                 var dy = wsY - pinPos.y;
    //                 if (Math.sqrt(dx * dx + dy * dy) <= threshold) {
    //                     return {
    //                         nodeId: card.nodeId,
    //                         socketId: sock.id,
    //                         cardItem: card,
    //                         pinX: pinPos.x,
    //                         pinY: pinPos.y
    //                     };
    //                 }
    //             }
    //         }
    //     }
    //     return null;
    // }

    function linesIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y) {
        var denom = (b2y - b1y) * (a2x - a1x) - (b2x - b1x) * (a2y - a1y);
        if (denom === 0)
            return false;
        var ua = ((b2x - b1x) * (a1y - b1y) - (b2y - b1y) * (a1x - b1x)) / denom;
        var ub = ((a2x - a1x) * (a1y - b1y) - (a2y - a1y) * (a1x - b1x)) / denom;
        return (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1);
    }

    // =========================================================================
    // EXECUTE SCISSOR CUT (Reliable Segment Intersection Across Curve Samples)
    // =========================================================================
    function executeScissorCut() {
        if (!root.activeTimelineModel || root.linkList.length === 0)
            return;

        var cutOccurred = false;
        var x1 = root.scissorStartX;
        var y1 = root.scissorStartY;
        var x2 = root.scissorCurrentX;
        var y2 = root.scissorCurrentY;

        // Ensure minimum stroke length to avoid accidental single clicks
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
                    // Exact cubic Bezier point formula
                    curPx = Math.pow(1 - t, 3) * p1.x + 3 * Math.pow(1 - t, 2) * t * path.c1x + 3 * (1 - t) * Math.pow(t, 2) * path.c2x + Math.pow(t, 3) * p2.x;
                    curPy = Math.pow(1 - t, 3) * p1.y + 3 * Math.pow(1 - t, 2) * t * path.c1y + 3 * (1 - t) * Math.pow(t, 2) * path.c2y + Math.pow(t, 3) * p2.y;
                }

                // Call global segmentsIntersect directly (NOT root.segmentsIntersect!)
                if (segmentsIntersect(x1, y1, x2, y2, lastPx, lastPy, curPx, curPy)) {
                    cutThisLink = true;
                    break;
                }
                lastPx = curPx;
                lastPy = curPy;
            }

            if (cutThisLink) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);
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
        onRunningChanged: if (!running)
            dagCanvas.requestPaint()
    }

    function zoomIn() {
        root.zoomLevel = Math.min(3.0, root.zoomLevel * 1.25);
        dagCanvas.requestPaint();
    }

    function zoomOut() {
        root.zoomLevel = Math.max(0.2, root.zoomLevel * 0.8);
        dagCanvas.requestPaint();
    }

    function resetView() {
        root.zoomLevel = 1.0;
        root.panX = 0.0;
        root.panY = 0.0;
        dagCanvas.requestPaint();
    }

    function viewCenter() {
        root.panX = 0.0;
        root.panY = 0.0;
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

    // =========================================================================
    // NODE MENU ACTIONS
    // =========================================================================
    // function snapSelectedToGrid() {
    //     var gridSize = 24;
    //     var temp = Object.assign({}, root.nodePositions);
    //     var targetIds = selectedNodeIds.length > 0 ? selectedNodeIds : nodeList.map(function (n) {
    //         return n.id;
    //     });
    //     for (var i = 0; i < targetIds.length; ++i) {
    //         var id = targetIds[i];
    //         var cur = getNodeCenterPos(id, 0, 0);
    //         temp[id] = {
    //             x: Math.round(cur.x / gridSize) * gridSize,
    //             y: Math.round(cur.y / gridSize) * gridSize
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, temp[id].y);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

    // function alignSelectedLeft() {
    //     if (selectedNodeIds.length < 2)
    //         return;
    //     var minX = Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         minX = Math.min(minX, getNodeCenterPos(selectedNodeIds[i], 0, 0).x);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         temp[id] = {
    //             x: minX,
    //             y: getNodeCenterPos(id, 0, 0).y
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, minX, temp[id].y);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

    // function alignSelectedRight() {
    //     if (selectedNodeIds.length < 2)
    //         return;
    //     var maxX = -Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         maxX = Math.max(maxX, getNodeCenterPos(selectedNodeIds[i], 0, 0).x);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         temp[id] = {
    //             x: maxX,
    //             y: getNodeCenterPos(id, 0, 0).y
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, maxX, temp[id].y);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

    // function alignSelectedTop() {
    //     if (selectedNodeIds.length < 2)
    //         return;
    //     var minY = Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         minY = Math.min(minY, getNodeCenterPos(selectedNodeIds[i], 0, 0).y);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         temp[id] = {
    //             x: getNodeCenterPos(id, 0, 0).x,
    //             y: minY
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, minY);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

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

        // Pass through collision resolver
        root.resolveAllSelectedNodesOverlap(selectedNodeIds[0]);
        dagCanvas.requestPaint();
    }
    // function alignSelectedBottom() {
    //     if (selectedNodeIds.length < 2)
    //         return;
    //     var maxY = -Infinity;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         maxY = Math.max(maxY, getNodeCenterPos(selectedNodeIds[i], 0, 0).y);
    //     }
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var j = 0; j < selectedNodeIds.length; ++j) {
    //         var id = selectedNodeIds[j];
    //         temp[id] = {
    //             x: getNodeCenterPos(id, 0, 0).x,
    //             y: maxY
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, maxY);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

    // function distributeSelectedHorizontally() {
    //     if (selectedNodeIds.length < 3)
    //         return;
    //     var sorted = selectedNodeIds.slice().sort(function (a, b) {
    //         return getNodeCenterPos(a, 0, 0).x - getNodeCenterPos(b, 0, 0).x;
    //     });
    //     var startX = getNodeCenterPos(sorted[0], 0, 0).x;
    //     var endX = getNodeCenterPos(sorted[sorted.length - 1], 0, 0).x;
    //     var step = (endX - startX) / (sorted.length - 1);
    //     var temp = Object.assign({}, root.nodePositions);
    //     for (var i = 0; i < sorted.length; ++i) {
    //         var id = sorted[i];
    //         var newX = startX + (i * step);
    //         temp[id] = {
    //             x: newX,
    //             y: getNodeCenterPos(id, 0, 0).y
    //         };
    //         if (root.activeTimelineModel) {
    //             root.activeTimelineModel.setNodePosition(root.currentGraphId, id, newX, temp[id].y);
    //         }
    //     }
    //     root.nodePositions = temp;
    // }

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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, newY);
            }
        }
        root.nodePositions = temp;
    }

    // =========================================================================
    // 1. DUPLICATE WITH CONNECTED WIRES (Duplicate Linked)
    // =========================================================================
    // =========================================================================
    // 1. DUPLICATE WITH CONNECTED WIRES (Passes through collision detector)
    // =========================================================================
    function duplicateLinkedNodes() {
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        var idMap = {}; // oldNodeId -> newNodeId
        var newSelection = [];
        var offsetStep = 48; // Initial offset

        // 1. Duplicate the nodes into backend
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

            var newId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, typeName, targetX, targetY);
            if (newId && newId !== "") {
                idMap[origId] = newId;
                newSelection.push(newId);
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
            }
        }

        // 2. Duplicate internal links between the duplicated nodes
        for (var l = 0; l < linkList.length; ++l) {
            var link = linkList[l];
            if (idMap[link.fromNodeId] && idMap[link.toNodeId]) {
                root.activeTimelineModel.connectSockets(root.currentGraphId, idMap[link.fromNodeId], link.fromSocketId, idMap[link.toNodeId], link.toSocketId);
            }
        }

        // 3. Update selection to newly duplicated nodes
        selectedNodeIds = newSelection;

        // 4. CRITICAL: PASS THROUGH COLLISION DETECTOR!
        // Guarantees none of the duplicated nodes collide with existing nodes or each other
        if (newSelection.length > 0) {
            root.resolveAllSelectedNodesOverlap(newSelection[0]);
        }

        root.notifyGraphStateChanged();
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // =========================================================================
    // DUPLICATE SELECTED NODES (Passes through collision detector)
    // =========================================================================
    // function duplicateSelectedNodes() {
    //     duplicateLinkedNodes(); // Use linked duplicate so internal wires stay intact!
    // }

    // =========================================================================
    // 2. INSERT REROUTE ON SELECTED (OR ADJACENT) LINK
    // =========================================================================
    function insertRerouteOnSelectedWire() {
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        // Find the first link connected to any currently selected node
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

    // =========================================================================
    // 3. COLLAPSE / EXPAND SELECTED NODES
    // =========================================================================
    function collapseSelectedNodes() {
        if (selectedNodeIds.length === 0)
            return;

        // Determine if majority are collapsed to toggle collectively
        var anyExpanded = false;
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
                card.isCollapsed = anyExpanded; // Collapse all if any are expanded, else expand
            }
        }
        root.pinRevision++;
    }

    // =========================================================================
    // 4. TOGGLE PREVIEW (VIEW NODE ON PROGRAM MONITOR)
    // =========================================================================
    function togglePreviewForSelected() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        var activeId = selectedNodeIds[0];
        if (root.activeTimelineModel.setPreviewNodeId) {
            root.activeTimelineModel.setPreviewNodeId(root.currentGraphId, activeId);
        }
        root.notifyGraphStateChanged();
    }

    // =========================================================================
    // 5. UNGROUP SELECTED NODES
    // =========================================================================
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

    // =========================================================================
    // 6. CUT CONNECTED LINKS FOR SELECTED NODES
    // =========================================================================
    function cutSelectedNodeLinks() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;

        var cutOccurred = false;
        for (var i = linkList.length - 1; i >= 0; --i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.fromNodeId) !== -1 || selectedNodeIds.indexOf(l.toNodeId) !== -1) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, l.fromNodeId, l.fromSocketId, l.toNodeId, l.toSocketId);
                cutOccurred = true;
            }
        }
        if (cutOccurred) {
            root.notifyGraphStateChanged();
            root.pinRevision++;
        }
    }

    // =========================================================================
    // 7. TOGGLE MUTE (BYPASS)
    // =========================================================================
    function toggleMuteSelectedNodes() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (root.activeTimelineModel.setNodeBypassed) {
                root.activeTimelineModel.setNodeBypassed(root.currentGraphId, selectedNodeIds[i]);
            }
        }
        root.notifyGraphStateChanged();
    }

    // =========================================================================
    // 8. RESET NODE VALUES
    // =========================================================================
    function clearSelectedNodeValues() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (root.activeTimelineModel.resetNodeValues) {
                root.activeTimelineModel.resetNodeValues(root.currentGraphId, selectedNodeIds[i]);
            }
        }
        root.notifyGraphStateChanged();
    }

    // =========================================================================
    // Duplicate Selected Nodes (WITHOUT CONNECTIONS)
    // =========================================================================
    function duplicateSelectedNodes() {
        if (!root.activeTimelineModel || root.isCurrentGraphReadOnly || selectedNodeIds.length === 0)
            return;

        var newSelection = [];
        var offset = 48; // Initial slight shift

        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var origId = selectedNodeIds[i];
            var pos = getNodeCenterPos(origId, 0, 0);

            // Find the node's type name
            var typeName = "Transform";
            for (var j = 0; j < nodeList.length; ++j) {
                if (nodeList[j].id === origId) {
                    typeName = nodeList[j].typeName;
                    break;
                }
            }

            var targetX = pos.x + offset;
            var targetY = pos.y + offset;

            // Add node WITHOUT any socket connections!
            var newId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, typeName, targetX, targetY);
            if (newId && newId !== "") {
                newSelection.push(newId);
                // Initial placement, card will auto-measure its own size and resolve any collision!
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
            }
        }

        selectedNodeIds = newSelection;
        root.notifyGraphStateChanged();
        root.pinRevision++;
        dagCanvas.requestPaint();
    }

    // function cutSelectedNodeLinks() {
    //     if (!root.activeTimelineModel || selectedNodeIds.length === 0)
    //         return;
    //     for (var i = linkList.length - 1; i >= 0; --i) {
    //         var l = linkList[i];
    //         if (selectedNodeIds.indexOf(l.fromNodeId) !== -1 || selectedNodeIds.indexOf(l.toNodeId) !== -1) {
    //             root.activeTimelineModel.disconnectSockets(root.currentGraphId, l.fromNodeId, l.fromSocketId, l.toNodeId, l.toSocketId);
    //         }
    //     }
    // }

    // function deleteSelectedNodes() {
    //     if (!root.activeTimelineModel || selectedNodeIds.length === 0)
    //         return;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         root.activeTimelineModel.removeNode(root.currentGraphId, selectedNodeIds[i]);
    //     }
    //     selectedNodeIds = [];
    // }

    // function toggleMuteSelectedNodes() {
    //     if (!root.activeTimelineModel || selectedNodeIds.length === 0)
    //         return;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         if (root.activeTimelineModel.setNodeBypassed) {
    //             root.activeTimelineModel.setNodeBypassed(root.currentGraphId, selectedNodeIds[i]);
    //         }
    //     }
    // }

    function openSearchPopupAtWorkspace(wsX, wsY, fromNode, fromSocket) {
        var targetWsX = wsX;
        var targetWsY = wsY;

        // Robust fallback if coordinates are undefined or NaN
        if (targetWsX === undefined || isNaN(targetWsX) || targetWsY === undefined || isNaN(targetWsY)) {
            if (!isNaN(root.currentMouseWorkspaceX) && (root.currentMouseScreenX > 0 || root.currentMouseScreenY > 0)) {
                targetWsX = root.currentMouseWorkspaceX;
                targetWsY = root.currentMouseWorkspaceY;
            } else {
                // Viewport center fallback
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

    // --- View State Toggles ---
    property bool showWireColors: true
    property bool showMinimap: true
    property bool showBackdropPreview: false
    property bool isFullscreen: false

    function toggleAllNodeCollapse(collapse) {
        // Broadcast collapse/expand to all instantiated card items
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
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var nId = selectedNodeIds[i];
            // Find upstream and downstream links through this node
            var inLink = null, outLink = null;
            for (var j = 0; j < linkList.length; ++j) {
                if (linkList[j].toNodeId === nId)
                    inLink = linkList[j];
                if (linkList[j].fromNodeId === nId)
                    outLink = linkList[j];
            }
            // Reconnect upstream directly to downstream (Dissolve)
            if (inLink && outLink) {
                root.activeTimelineModel.connectSockets(root.currentGraphId, inLink.fromNodeId, inLink.fromSocketId, outLink.toNodeId, outLink.toSocketId);
            }
            root.activeTimelineModel.removeNode(root.currentGraphId, nId);
        }
        selectedNodeIds = [];
    }

    function connectSelectedToActive() {
        if (!root.activeTimelineModel || selectedNodeIds.length < 2)
            return;
        var activeId = selectedNodeIds[selectedNodeIds.length - 1];
        var otherId = selectedNodeIds[0];
        root.activeTimelineModel.connectSockets(root.currentGraphId, otherId, "output", activeId, "input");
    }

    function swapSelectedLinks() {
        if (!root.activeTimelineModel || selectedNodeIds.length !== 2)
            return;
        var a = selectedNodeIds[0], b = selectedNodeIds[1];
        // Swaps outgoing targets between node A and node B
        for (var i = 0; i < linkList.length; ++i) {
            var l = linkList[i];
            if (l.fromNodeId === a) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, a, l.fromSocketId, l.toNodeId, l.toSocketId);
                root.activeTimelineModel.connectSockets(root.currentGraphId, b, l.fromSocketId, l.toNodeId, l.toSocketId);
            } else if (l.fromNodeId === b) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, b, l.fromSocketId, l.toNodeId, l.toSocketId);
                root.activeTimelineModel.connectSockets(root.currentGraphId, a, l.fromSocketId, l.toNodeId, l.toSocketId);
            }
        }
    }

    // function clearSelectedNodeValues() {
    //     if (!root.activeTimelineModel || selectedNodeIds.length === 0)
    //         return;
    //     for (var i = 0; i < selectedNodeIds.length; ++i) {
    //         if (root.activeTimelineModel.resetNodeValues) {
    //             root.activeTimelineModel.resetNodeValues(root.currentGraphId, selectedNodeIds[i]);
    //         }
    //     }
    // }

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
                // Viewport center fallback
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

        // =====================================================================
        // 1. Solid Top Bar (No text on right, buttons on left)
        // =====================================================================
        TopBar {
            id: tabBar
            root: root
            Layout.fillWidth: true
        }

        // -------------------------------------------------------------------------
        // CANVAS CONTAINER (Direct child of layout, or anchored to root)
        // -------------------------------------------------------------------------
        Item {
            id: canvasAreaContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // 2. THE EMPTY STATE / DEFAULT GRAPH INDICATOR
            EmptyState {
                anchors.centerIn: parent
                visible: root.isCurrentGraphReadOnly

                onCreateRequested: {
                    if (!root.activeTimelineModel)
                        return;
                    var allG = root.activeTimelineModel.getAllProjectGraphs();
                    var newName = "Graph " + (allG.length);
                    var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
                    if (newGId !== "") {
                        if (root.activeSelectedClipId !== "") {
                            root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
                            root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newGId);
                        }
                        root.selectGraph(newGId);
                    }
                }
            }

            // 1. THE EDITABLE CANVAS (Shown ONLY when viewing an editable user graph)
            Item {
                id: canvasContainer
                // id: graphCanvasArea
                anchors.fill: parent
                visible: !root.isCurrentGraphReadOnly

                // Non-blocking full container hover tracker
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
                        // Infinite view boundary projection without clamp cut-offs
                        var viewLeft = (-width / 2 - root.panX) / root.zoomLevel;
                        var viewRight = (width / 2 - root.panX) / root.zoomLevel;
                        var viewTop = (-height / 2 - root.panY) / root.zoomLevel;
                        var viewBottom = (height / 2 - root.panY) / root.zoomLevel;

                        var minX = Math.floor(viewLeft / step) * step;
                        var maxX = Math.ceil(viewRight / step) * step;
                        var minY = Math.floor(viewTop / step) * step;
                        var maxY = Math.ceil(viewBottom / step) * step;

                        var pixelGridSize = step * root.zoomLevel;

                        // 1. Sub-grid lines (Hidden when cluttered / zoomed out)
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

                        // 2. Major 5th Milestone Grid lines
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

                        // 3. Central Origin Axes (Exactly 2px width)
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

                // Always-Visible Screen Space Lasso Overlay
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
                        // Project world points to screen points
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

                // Normal mouse drag canvas handler
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
                            contextMenu.openAt(overlayPt.x, overlayPt.y, root.currentGraphId, "", 0, root.selectedNodeIds.length > 0);
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

                                    // Nearest point on node rectangle to circle center
                                    var closestX = Math.max(nLeft, Math.min(root.boxStartX, nRight));
                                    var closestY = Math.max(nTop, Math.min(root.boxStartY, nBottom));

                                    var distSq = Math.pow(root.boxStartX - closestX, 2) + Math.pow(root.boxStartY - closestY, 2);
                                    if (distSq <= Math.pow(root.circleRadius, 2)) {
                                        newlySelected.push(cn.id);
                                    }
                                }
                            } else if (root.selectionMode === "lasso") {
                                // 1px Touch / Intersection test for lasso against all node cards
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
                            // root.selectedNodeIds = newlySelected;
                            // root.isBoxSelecting = false;
                        }
                    }

                    onWheel: function (wheel) {
                        if (wheel.modifiers & Qt.ControlModifier) {
                            // Zoom centered on MOUSE CURSOR
                            var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87;
                            var nextZoom = Math.max(0.15, Math.min(3.5, root.zoomLevel * factor));

                            // World position under cursor prior to zoom
                            var mouseWsX = (wheel.x - canvasContainer.width / 2 - root.panX) / root.zoomLevel;
                            var mouseWsY = (wheel.y - canvasContainer.height / 2 - root.panY) / root.zoomLevel;

                            // New pan keeping mouseWsX, mouseWsY fixed under wheel.x, wheel.y
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
                        dagCanvas.requestPaint();
                    }
                }

                // Dedicated Native Touchpad & Touch Screen Pinch-To-Zoom Handler
                PinchHandler {
                    id: canvasPinchHandler
                    target: null // Do not let Qt transform canvas directly; we manage zoomLevel & pan

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
                        // scale is relative to the start of the pinch gesture (e.g. 1.05 = zoomed in 5%)
                        var nextZoom = Math.max(0.15, Math.min(3.5, startZoom * scale));

                        // Workspace point under the pinch center at gesture start
                        var cWsX = (startCenter.x - canvasContainer.width / 2 - startPanX) / startZoom;
                        var cWsY = (startCenter.y - canvasContainer.height / 2 - startPanY) / startZoom;

                        // Pan keeping that center point fixed under the fingers + track two-finger movement
                        var currentCenterX = centroid.position.x;
                        var currentCenterY = centroid.position.y;

                        root.panX = currentCenterX - canvasContainer.width / 2 - (cWsX * nextZoom);
                        root.panY = currentCenterY - canvasContainer.height / 2 - (cWsY * nextZoom);
                        root.zoomLevel = nextZoom;

                        dagCanvas.requestPaint();
                    }
                }

                // =================================================================
                // 1. Auto-Fitting Minimap (Camera frustum never overflows)
                // =================================================================
                Minimap {
                    root: root
                    canvasContainer: canvasContainer
                    dagCanvas: dagCanvas
                }

                // =========================================================================
                // 2. UTILITY BAR CONTROLS
                // =========================================================================
                UtilityBar {
                    id: graphUtilityBar
                    root: root
                }

                // =================================================================
                // Red Dotted Alignment Snap Lines (GPU-Safe, Screen-Bounded)
                // =================================================================
                Canvas {
                    id: snapGuideCanvas
                    anchors.fill: parent
                    visible: root.snapGuideXVisible || root.snapGuideYVisible
                    z: 98

                    // Repaint when coordinates or visibility changes
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
                        // Standard canvas dashed pattern: 4px dash, 4px gap
                        if (ctx.setLineDash) {
                            ctx.setLineDash([4, 4]);
                        }

                        // Vertical Dotted Red Line
                        if (root.snapGuideXVisible) {
                            var screenX = canvasContainer.width / 2 + root.panX + (root.snapGuideXPos * root.zoomLevel);
                            ctx.beginPath();
                            ctx.moveTo(screenX, 0);
                            ctx.lineTo(screenX, canvasContainer.height);
                            ctx.stroke();
                        }

                        // Horizontal Dotted Red Line
                        if (root.snapGuideYVisible) {
                            var screenY = canvasContainer.height / 2 + root.panY + (root.snapGuideYPos * root.zoomLevel);
                            ctx.beginPath();
                            ctx.moveTo(0, screenY);
                            ctx.lineTo(canvasContainer.width, screenY);
                            ctx.stroke();
                        }
                    }
                }

                // Graph Workspace
                Item {
                    id: graphWorkspace
                    x: canvasContainer.width / 2 + root.panX
                    y: canvasContainer.height / 2 + root.panY
                    scale: root.zoomLevel

                    // 1. Box Selection Visual
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

                    // 2. Circle Selection Visual
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

                    // Alt Scissor Cutting Line
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

                    // =============================================================
                    // Connected Wires Repeater
                    // =============================================================
                    Repeater {
                        id: linkRepeater
                        model: root.visibleLinkList

                        delegate: Item {
                            id: linkDelegate
                            z: 20
                            anchors.fill: parent

                            // BIND DIRECTLY TO pinRevision: Forces recalculation on EVERY pixel of card drag
                            readonly property int rev: root.pinRevision

                            readonly property var p1: {
                                var _ = rev; // Dependency on rev
                                return root.getRegisteredPinPos(modelData.fromNodeId, modelData.fromSocketId, true);
                            }

                            readonly property var p2: {
                                var _ = rev; // Dependency on rev
                                return root.getRegisteredPinPos(modelData.toNodeId, modelData.toSocketId, false);
                            }

                            readonly property var path: {
                                var _ = rev;
                                return root.solveWirePath(p1, p2, modelData.fromNodeId, modelData.toNodeId);
                            }

                            property bool isWireHovered: false

                            // 1. STRAIGHT WIRE
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

                            // 2. CURVED BEZIER WIRE
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

                            // Mathematical curve hit-tester (Only within 7px of curve)
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

                    // =============================================================
                    // 2. Interactive Dragging Wire (Only visible when isConnectingWire)
                    // =============================================================
                    Item {
                        id: pendingWireContainer
                        anchors.fill: parent
                        visible: root.isConnectingWire
                        z: 75 // Above cards so the pending line is always crystal clear

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

                    // =============================================================
                    // Node Group Box Containers
                    // =============================================================
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

                            // Header Bar with Editable Title
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

                            // Drag Group Box to Move All Member Nodes
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

                    // Render Node Cards
                    //                     Repeater {
                    //                         id: cardRepeater
                    //                         model: root.visibleNodeList
                    //
                    //                         delegate: NodeCard {
                    //                             id: cardItem
                    //                             nodeData: modelData
                    //                             activeModel: root.activeTimelineModel
                    //                             activeClipId: root.currentGraphId
                    //                             isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1
                    //
                    //                             // Store initial position into nodePositions immediately so click never defaults to 0,0
                    //                             Component.onCompleted: {
                    //                                 if (root.nodePositions[modelData.id] === undefined) {
                    //                                     root.nodePositions[modelData.id] = { x: modelData.x, y: modelData.y };
                    //                                 }
                    //                             }
                    //
                    //                             x: {
                    //                                 var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                    //                                 return p.x - width / 2;
                    //                             }
                    //                             y: {
                    //                                 var p = root.getNodeCenterPos(modelData.id, modelData.x, modelData.y);
                    //                                 return p.y - height / 2;
                    //                             }
                    //
                    //                             onPinPositionChanged: function(nId, sId, isOut, px, py) {
                    //                                 root.registerPinPosition(nId, sId, isOut, Qt.point(px, py));
                    //                             }
                    //
                    //                             onStartConnectingWire: function (nodeId, socketId, pinX, pinY) {
                    //                                 root.isConnectingWire = true;
                    //                                 root.wireFromNodeId = nodeId;
                    //                                 root.wireFromSocketId = socketId;
                    //                                 pendingPath.startX = pinX;
                    //                                 pendingPath.startY = pinY;
                    //                                 root.wireMouseX = pinX;
                    //                                 root.wireMouseY = pinY;
                    //                             }
                    //
                    //                             onUpdateWireDrag: function (gx, gy) {
                    //                                 if (!root.isConnectingWire)
                    //                                     return;
                    //                                 var target = root.findTargetInputPinAt(gx, gy);
                    //                                 if (target) {
                    //                                     // Magnetic snap wire tip directly onto the socket
                    //                                     root.wireMouseX = target.pinX;
                    //                                     root.wireMouseY = target.pinY;
                    //
                    //                                     // Turn on hover feedback ring on target card
                    //                                     if (root.activeHoveredTargetNodeId !== target.nodeId || root.activeHoveredTargetSocketId !== target.socketId) {
                    //                                         root.clearAllPinHighlights();
                    //                                         root.activeHoveredTargetNodeId = target.nodeId;
                    //                                         root.activeHoveredTargetSocketId = target.socketId;
                    //                                         target.cardItem.activeHighlightSocketId = target.socketId;
                    //                                     }
                    //                                 } else {
                    //                                     root.wireMouseX = gx;
                    //                                     root.wireMouseY = gy;
                    //                                     root.clearAllPinHighlights();
                    //                                 }
                    //                             }
                    //
                    // onEndConnectingWire: function (gx, gy) {
                    //                                 if (!root.isConnectingWire)
                    //                                     return;
                    //
                    //                                 var target = root.findTargetInputPinAt(gx, gy);
                    //                                 if (target && root.activeTimelineModel) {
                    //                                     var ok = root.activeTimelineModel.connectSockets(
                    //                                         root.currentGraphId,
                    //                                         root.wireFromNodeId,
                    //                                         root.wireFromSocketId,
                    //                                         target.nodeId,
                    //                                         target.socketId
                    //                                     );
                    //                                     if (ok) {
                    //                                         root.notifyGraphStateChanged(); // <--- Refreshes linkList!
                    //                                         root.pinRevision++;
                    //                                     }
                    //                                 }
                    //
                    //                                 root.clearAllPinHighlights();
                    //                                 root.isConnectingWire = false;
                    //                                 root.wireFromNodeId = "";
                    //                                 root.wireFromSocketId = "";
                    //                             }
                    //                             // onEndConnectingWire: function (gx, gy) {
                    //                             //     if (!root.isConnectingWire)
                    //                             //         return;
                    //                             //     var target = root.findTargetInputPinAt(gx, gy);
                    //                             //     if (target && root.activeTimelineModel) {
                    //                             //         root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                    //                             //         root.notifyGraphStateChanged();
                    //                             //         root.pinRevision++;
                    //                             //     }
                    //                             //     // Clean up dragging state immediately so it never gets stuck
                    //                             //     root.clearAllPinHighlights();
                    //                             //     root.isConnectingWire = false;
                    //                             //     root.wireFromNodeId = "";
                    //                             //     root.wireFromSocketId = "";
                    //                             // }
                    //
                    //                             property var initialDragMap: ({})
                    //
                    //                             onNodeSelected: function (nodeId, isShift) {
                    //                                 if (isShift) {
                    //                                     var idx = root.selectedNodeIds.indexOf(nodeId);
                    //                                     var copy = root.selectedNodeIds.slice();
                    //                                     if (idx === -1)
                    //                                         copy.push(nodeId);
                    //                                     else
                    //                                         copy.splice(idx, 1);
                    //                                     root.selectedNodeIds = copy;
                    //                                 } else {
                    //                                     if (root.selectedNodeIds.indexOf(nodeId) === -1) {
                    //                                         root.selectedNodeIds = [nodeId];
                    //                                     }
                    //                                 }
                    //
                    //                                 // Snapshot current positions of all selected nodes at start of drag
                    //                                 var map = {};
                    //                                 for (var s = 0; s < root.selectedNodeIds.length; ++s) {
                    //                                     var sId = root.selectedNodeIds[s];
                    //                                     map[sId] = root.getNodeCenterPos(sId, 0, 0);
                    //                                 }
                    //                                 cardItem.initialDragMap = map;
                    //                             }
                    //
                    //                             onDragMovedDelta: function (rawTargetX, rawTargetY) {
                    //                                 var primaryId = modelData.id;
                    //                                 var startPos = cardItem.initialDragMap[primaryId];
                    //                                 if (!startPos) {
                    //                                     startPos = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);
                    //                                     cardItem.initialDragMap[primaryId] = startPos;
                    //                                 }
                    //
                    //                                 // Snap the primary card
                    //                                 var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                    //                                 var moveDx = snappedP.x - startPos.x;
                    //                                 var moveDy = snappedP.y - startPos.y;
                    //
                    //                                 var temp = Object.assign({}, root.nodePositions);
                    //                                 var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [primaryId];
                    //
                    //                                 for (var i = 0; i < ids.length; ++i) {
                    //                                     var sId = ids[i];
                    //                                     var orig = cardItem.initialDragMap[sId];
                    //                                     if (!orig) {
                    //                                         orig = root.getNodeCenterPos(sId, 0, 0);
                    //                                         cardItem.initialDragMap[sId] = orig;
                    //                                     }
                    //                                     temp[sId] = {
                    //                                         x: orig.x + moveDx,
                    //                                         y: orig.y + moveDy
                    //                                     };
                    //                                 }
                    //
                    //                                 root.nodePositions = temp;
                    //                                 root.pinRevision++;
                    //                             }
                    //
                    //                             onDragFinished: {
                    //                                 root.snapGuideXVisible = false;
                    //                                 root.snapGuideYVisible = false;
                    //                                 cardItem.initialDragMap = {};
                    //
                    //                                 root.resolveAllSelectedNodesOverlap(modelData.id);
                    //
                    //                                 if (root.activeTimelineModel) {
                    //                                     var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                    //                                     for (var i = 0; i < ids.length; ++i) {
                    //                                         var sId = ids[i];
                    //                                         var pos = root.getNodeCenterPos(sId, 0, 0);
                    //                                         root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                    //                                     }
                    //                                 }
                    //                             }
                    //                         }
                    //                     }

                    // =============================================================
                    // 1. STANDARD NODES (YOUR EXACT UNTOUCHED DELEGATE)
                    // =============================================================
                    Repeater {
                        id: cardRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName !== "GroupNode" && n.typeName !== "Reroute" && n.typeName !== "CommentNode";
                        })

                        delegate: NodeCard {
                            id: cardItem
                            nodeData: modelData
                            activeModel: root.activeTimelineModel
                            activeClipId: root.currentGraphId
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
                                if (target && root.activeTimelineModel) {
                                    var ok = root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                                    if (ok) {
                                        root.notifyGraphStateChanged();
                                        root.pinRevision++;
                                    }
                                } else if (!target) {
                                    // Empty canvas drop: spawn node near drop cursor and link
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

                                if (root.activeTimelineModel) {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // =============================================================
                    // 2. GROUP NODES (Direct GroupNodeCard Delegate)
                    // =============================================================
                    Repeater {
                        id: groupRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName === "GroupNode";
                        })

                        delegate: GroupNodeCard {
                            id: groupCardItem
                            nodeData: modelData
                            activeModel: root.activeTimelineModel
                            activeClipId: root.currentGraphId
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

                                if (root.activeTimelineModel) {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // =============================================================
                    // 3. REROUTE NODES (Direct RerouteNodeCard Delegate)
                    // =============================================================
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
                                if (target && root.activeTimelineModel) {
                                    var ok = root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
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

                                if (root.activeTimelineModel) {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }

                    // =============================================================
                    // 4. COMMENT NODES (Direct CommentNodeCard Delegate)
                    // =============================================================
                    Repeater {
                        id: commentRepeater
                        model: root.visibleNodeList.filter(function (n) {
                            return n.typeName === "CommentNode";
                        })

                        delegate: CommentNodeCard {
                            id: commentCardItem
                            nodeData: modelData
                            activeModel: root.activeTimelineModel
                            activeClipId: root.currentGraphId
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

                                if (root.activeTimelineModel) {
                                    var ids = root.selectedNodeIds.length > 0 ? root.selectedNodeIds : [modelData.id];
                                    for (var i = 0; i < ids.length; ++i) {
                                        var sId = ids[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // INFO: CONTEXT UP TO HERE

    SearchPopup {
        id: searchPopup

        availableNodeTypes: root.activeTimelineModel ? root.activeTimelineModel.getAvailableNodeTypes() : []
        isReadOnly: root.isCurrentGraphReadOnly

        onAddNodeRequested: function (typeName, sX, sY) {
            if (!root.activeTimelineModel || root.isCurrentGraphReadOnly)
                return;

            // Resolve exact mouse coordinate with hierarchical fallback
            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));

            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;

            // Use free space solver so it stays immediately next to cursor if exact cell is occupied
            var freePt = root.findFreeSpaceAround(targetX, targetY, "");
            if (freePt && !isNaN(freePt.x) && !isNaN(freePt.y)) {
                targetX = freePt.x;
                targetY = freePt.y;
            }

            var newId = root.activeTimelineModel.addNodeToGraph(root.currentGraphId, typeName, targetX, targetY);
            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];

                // If spawned from wire drag, auto-connect to first input
                if (searchPopup.linkFromNodeId && searchPopup.linkFromNodeId !== "") {
                    var fromNId = searchPopup.linkFromNodeId;
                    var fromSId = searchPopup.linkFromSocketId;
                    Qt.callLater(function () {
                        var nodes = root.activeTimelineModel.getGraphNodes(root.currentGraphId);
                        for (var n = 0; n < nodes.length; ++n) {
                            if (nodes[n].id === newId && nodes[n].inputs && nodes[n].inputs.length > 0) {
                                root.activeTimelineModel.connectSockets(root.currentGraphId, fromNId, fromSId, newId, nodes[n].inputs[0].id);
                                root.notifyGraphStateChanged();
                                root.pinRevision++;
                                break;
                            }
                        }
                    });
                }
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            dagCanvas.requestPaint();
        }

        onAddRerouteRequested: function (sX, sY) {
            if (!root.activeTimelineModel || root.isCurrentGraphReadOnly)
                return;
            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));
            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;
            var newId = root.activeTimelineModel.addRerouteToGraph(root.currentGraphId, targetX, targetY);
            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            dagCanvas.requestPaint();
        }

        onAddCommentRequested: function (sX, sY) {
            if (!root.activeTimelineModel || root.isCurrentGraphReadOnly)
                return;
            var rawX = (sX !== undefined && !isNaN(sX)) ? Number(sX) : ((searchPopup.spawnX !== undefined && !isNaN(searchPopup.spawnX)) ? Number(searchPopup.spawnX) : ((!isNaN(root.currentMouseWorkspaceX)) ? Number(root.currentMouseWorkspaceX) : (-root.panX / root.zoomLevel)));
            var rawY = (sY !== undefined && !isNaN(sY)) ? Number(sY) : ((searchPopup.spawnY !== undefined && !isNaN(searchPopup.spawnY)) ? Number(searchPopup.spawnY) : ((!isNaN(root.currentMouseWorkspaceY)) ? Number(root.currentMouseWorkspaceY) : (-root.panY / root.zoomLevel)));

            var targetX = Math.round(rawX / 24) * 24;
            var targetY = Math.round(rawY / 24) * 24;
            var newId = root.activeTimelineModel.addCommentToGraph(root.currentGraphId, "Notes", targetX, targetY, 300, 200);
            if (newId && newId !== "") {
                root.nodePositions[newId] = {
                    x: targetX,
                    y: targetY
                };
                root.selectedNodeIds = [newId];
            }
            root.notifyGraphStateChanged();
            root.pinRevision++;
            dagCanvas.requestPaint();
        }
    }

    ContextMenuPopup {
        id: contextMenu

        selectedNodeIds: root.selectedNodeIds
        isCurrentGraphReadOnly: root.isCurrentGraphReadOnly
        currentGraphId: root.currentGraphId

        // Clipboard Actions
        onCutRequested: root.cutSelectedNodes()
        onCopyRequested: root.copySelectedNodes()
        onPasteRequested: root.pasteNodes()
        onDuplicateRequested: root.duplicateSelectedNodes()

        // Grouping
        onGroupSelectedRequested: {
            if (root.activeTimelineModel && !root.isCurrentGraphReadOnly) {
                root.activeTimelineModel.createGroupInGraph(root.currentGraphId, "New Group", root.selectedNodeIds);
                root.notifyGraphStateChanged();
            }
        }

        // Deletion (Calls root.deleteSelectedNodes() which handles iteration and refresh)
        onDeleteSelectedRequested: root.deleteSelectedNodes()

        // Layout & Alignment
        onSnapToGridRequested: root.snapSelectedToGrid()
        onAlignLeftRequested: root.alignSelectedLeft()
        onAlignTopRequested: root.alignSelectedTop()
        onDistributeHorizontallyRequested: root.distributeSelectedHorizontally()

        // Navigation (Fixed function names)
        onFrameAllNodesRequested: root.frameAll()
        onResetZoomAndPanRequested: root.resetView()
    }
}
