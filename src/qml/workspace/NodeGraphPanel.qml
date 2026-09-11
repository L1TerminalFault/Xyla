import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    readonly property color bgDark: "#1a1a1a"
    readonly property color canvasBg: "#121212"

    // -------------------------------------------------------------------------
    // Core Reactive Graph Tracking
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Single Source of Truth for What Graph Is Being Viewed & Edited
    // -------------------------------------------------------------------------
    property var activeTimelineModel: timelineModel
    property string activeSelectedClipId: activeTimelineModel ? activeTimelineModel.selectedClipId : ""

    readonly property bool isCurrentGraphReadOnly: currentGraphId === "default_io_graph"

    // Revision counter incremented on every single graph action
    property int graphRevision: 0
    function notifyGraphStateChanged() {
        graphRevision++;
        if (dagCanvas && dagCanvas.requestPaint) {
            dagCanvas.requestPaint();
        }
    }

    Connections {
        target: activeTimelineModel ? activeTimelineModel : null
        function onProjectGraphsChanged() {
            root.notifyGraphStateChanged();
        }
        function onActiveGraphChanged() {
            root.notifyGraphStateChanged();
        }
        function onSelectedClipIdChanged() {
            root.notifyGraphStateChanged();
        }
    }

    // REACTIVE activeGraphId that updates whenever graphRevision changes:
    property string activeGraphId: {
        var _ = graphRevision; // Force dependency
        if (!activeTimelineModel)
            return "default_io_graph";
        if (activeSelectedClipId !== "") {
            var cGId = activeTimelineModel.getClipActiveGraphId(activeSelectedClipId);
            if (cGId && cGId !== "")
                return cGId;
        }
        var sGId = activeTimelineModel.standaloneActiveGraphId();
        return (sGId && sGId !== "") ? sGId : "default_io_graph";
    }

    function selectGraph(graphId) {
        if (!graphId || graphId === "")
            return;
        activeGraphId = graphId;
        if (activeTimelineModel) {
            activeTimelineModel.setStandaloneActiveGraphId(graphId);
        }
        notifyGraphStateChanged();
    }
    // The currently viewed graph in this editor panel
    // property string activeGraphId: {
    //     if (!activeTimelineModel) return "default_io_graph";
    //     // If a clip is selected, start with the clip's active graph, or fallback to standalone
    //     if (activeSelectedClipId !== "") {
    //         var cGId = activeTimelineModel.getClipActiveGraphId(activeSelectedClipId);
    //         if (cGId && cGId !== "") return cGId;
    //     }
    //     var sGId = activeTimelineModel.standaloneActiveGraphId();
    //     return (sGId && sGId !== "") ? sGId : "default_io_graph";
    // }
    //
    // // Function to explicitly select what graph to view (from XylaSelect OR Breadcrumb)
    // function selectGraph(graphId) {
    //     if (!graphId || graphId === "") return;
    //     activeGraphId = graphId;
    //     if (activeTimelineModel) {
    //         activeTimelineModel.setStandaloneActiveGraphId(graphId);
    //     }
    // }

    // When the user clicks a different clip on the timeline, switch activeGraphId to that clip's active graph
    onActiveSelectedClipIdChanged: {
        if (activeSelectedClipId !== "" && activeTimelineModel) {
            var clipGId = activeTimelineModel.getClipActiveGraphId(activeSelectedClipId);
            if (clipGId && clipGId !== "") {
                activeGraphId = clipGId;
            }
        }
    }

    // property int graphRevision: 0
    // function notifyGraphStateChanged() {
    //     graphRevision++;
    //     if (activeTimelineModel) {
    //         // Trigger property re-evaluation
    //         activeTimelineModel.visualFrameInvalidated();
    //     }
    // }

    // Aliases
    readonly property string currentGraphId: activeGraphId
    readonly property string currentGraphName: activeTimelineModel ? activeTimelineModel.getGraphName(currentGraphId) : "Default"

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
    readonly property var nodeList: activeTimelineModel ? activeTimelineModel.getGraphNodes(currentGraphId) : []
    readonly property var linkList: activeTimelineModel ? activeTimelineModel.getGraphLinks(currentGraphId) : []

    // property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    // property string activeSelectedClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var selectedClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    // WARNING:
    // If a clip is selected, get its active graph; otherwise view the standalone graph!
    // readonly property string currentGraphId: activeSelectedClipId !== ""
    //     ? activeTimelineModel.getClipActiveGraphId(activeSelectedClipId)
    //     : activeTimelineModel.standaloneActiveGraphId()
    //
    // // Title to show in UI
    // readonly property string currentGraphTitle: activeTimelineModel
    //     ? activeTimelineModel.getGraphName(currentGraphId)
    //     : "No Graph"
    //
    // // Load nodes and links directly from the active graph ID
    // readonly property var nodeList: activeTimelineModel ? activeTimelineModel.getGraphNodes(currentGraphId) : []
    // readonly property var linkList: activeTimelineModel ? activeTimelineModel.getGraphLinks(currentGraphId) : []
    // WARNING:

    // property var availableGraphs: (activeTimelineModel && activeTimelineModel.availableNodeGraphs !== undefined)
    //     ? activeTimelineModel.availableNodeGraphs
    //     : ["Default Base Graph", "Color Grade Layer", "VFX Composite"]
    // property string activeGraphId: (selectedClipData && selectedClipData.activeGraphId) ? selectedClipData.activeGraphId : "graph_default_base"

    // property var nodeList: (selectedClipData && selectedClipData.nodes) ? selectedClipData.nodes : []
    // property var linkList: (selectedClipData && selectedClipData.links) ? selectedClipData.links : []

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
    // Ray-to-Box Intersection (Tests if segment from p1 to p2 cuts through an obstacle box)
    // Obstacle Detector: returns detour waypoints if any node sits between p1 and p2
    // Returns true only if segment (p1 -> p2) strictly intersects the rectangle (left, top, right, bottom)
    // function segmentHitsBox(p1x, p1y, p2x, p2y, left, top, right, bottom) {
    //     // If both endpoints are on the same side outside the box, no collision
    //     if ((p1x < left && p2x < left) || (p1x > right && p2x > right) ||
    //         (p1y < top && p2y < top) || (p1y > bottom && p2y > bottom)) {
    //         return false;
    //     }
    //
    //     // Test intersection with all 4 box edges
    //     if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, right, top)) return true; // Top edge
    //     if (segmentsIntersect(p1x, p1y, p2x, p2y, left, bottom, right, bottom)) return true; // Bottom edge
    //     if (segmentsIntersect(p1x, p1y, p2x, p2y, left, top, left, bottom)) return true; // Left edge
    //     if (segmentsIntersect(p1x, p1y, p2x, p2y, right, top, right, bottom)) return true; // Right edge
    //
    //     // Check if either point is inside the box
    //     if (p1x >= left && p1x <= right && p1y >= top && p1y <= bottom) return true;
    //     if (p2x >= left && p2x <= right && p2y >= top && p2y <= bottom) return true;
    //
    //     return false;
    // }

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

    // Tests if segment intersects ANY node card on the canvas
    // function isSegmentBlockedByAnyNode(p1x, p1y, p2x, p2y, ignoreFromId, ignoreToId) {
    //     for (var i = 0; i < nodeList.length; ++i) {
    //         var nId = nodeList[i].id;
    //         // Ignore start node at exit pin and end node at entry pin
    //         if (nId === ignoreFromId || nId === ignoreToId) continue;
    //         var b = getNodeBoundingBox(nId, 8);
    //         if (segmentHitsBox(p1x, p1y, p2x, p2y, b.left, b.top, b.right, b.bottom)) {
    //             return { blocked: true, box: b, nodeId: nId };
    //         }
    //     }
    //     return { blocked: false, box: null, nodeId: "" };
    // }

    // Comprehensive Path Solver: returns exact waypoints for straight lines and control points for curves
    // function solveWirePath(p1, p2, fromId, toId) {
    //     var directHit = isSegmentBlockedByAnyNode(p1.x, p1.y, p2.x, p2.y, fromId, toId);
    //
    //     // CASE 0: DIRECT LINE IS COMPLETELY CLEAR (0 turns needed!)
    //     if (!directHit.blocked) {
    //         return {
    //             isDetoured: false,
    //             turnCount: 0,
    //             // Waypoints relative to world space
    //             points: [Qt.point(p1.x, p1.y), Qt.point(p2.x, p2.y)],
    //             curveDetourY: 0
    //         };
    //     }
    //
    //     // The line is blocked by an obstacle card!
    //     var obs = directHit.box;
    //
    //     // Try 1-turn L-routes around the obstacle
    //     // L-Route A: Horizontal then Vertical (p1.x, p1.y) -> (p2.x, p1.y) -> (p2.x, p2.y)
    //     var lRouteA_seg1 = isSegmentBlockedByAnyNode(p1.x, p1.y, p2.x, p1.y, fromId, toId);
    //     var lRouteA_seg2 = isSegmentBlockedByAnyNode(p2.x, p1.y, p2.x, p2.y, fromId, toId);
    //     if (!lRouteA_seg1.blocked && !lRouteA_seg2.blocked) {
    //         return {
    //             isDetoured: true,
    //             turnCount: 1,
    //             points: [Qt.point(p1.x, p1.y), Qt.point(p2.x, p1.y), Qt.point(p2.x, p2.y)],
    //             curveDetourY: p1.y
    //         };
    //     }
    //
    //     // L-Route B: Vertical then Horizontal (p1.x, p1.y) -> (p1.x, p2.y) -> (p2.x, p2.y)
    //     var lRouteB_seg1 = isSegmentBlockedByAnyNode(p1.x, p1.y, p1.x, p2.y, fromId, toId);
    //     var lRouteB_seg2 = isSegmentBlockedByAnyNode(p1.x, p2.y, p2.x, p2.y, fromId, toId);
    //     if (!lRouteB_seg1.blocked && !lRouteB_seg2.blocked) {
    //         return {
    //             isDetoured: true,
    //             turnCount: 1,
    //             points: [Qt.point(p1.x, p1.y), Qt.point(p1.x, p2.y), Qt.point(p2.x, p2.y)],
    //             curveDetourY: p2.y
    //         };
    //     }
    //
    //     // Obstacle directly in the way: Route around the shortest unobstructed perimeter edge
    //     // Choose routing over top or below bottom
    //     var detourTop = obs.top - 16;
    //     var detourBottom = obs.bottom + 16;
    //     var distTop = Math.abs(p1.y - detourTop) + Math.abs(p2.y - detourTop);
    //     var distBottom = Math.abs(p1.y - detourBottom) + Math.abs(p2.y - detourBottom);
    //     var detourY = (distTop <= distBottom) ? detourTop : detourBottom;
    //
    //     // Check horizontal span of obstacle with clearance
    //     var detourLeft = Math.min(p1.x, obs.left - 16);
    //     var detourRight = Math.max(p2.x, obs.right + 16);
    //
    //     return {
    //         isDetoured: true,
    //         turnCount: 2,
    //         points: [
    //             Qt.point(p1.x, p1.y),
    //             Qt.point(obs.left - 16, detourY),
    //             Qt.point(obs.right + 16, detourY),
    //             Qt.point(p2.x, p2.y)
    //         ],
    //         curveDetourY: detourY
    //     };
    // }
    // function getWireObstacleDetour(p1, p2, fromId, toId) {
    //     for (var i = 0; i < nodeList.length; ++i) {
    //         var n = nodeList[i];
    //         if (n.id === fromId || n.id === toId) continue;
    //
    //         var pos = getNodeCenterPos(n.id, n.x, n.y);
    //         var w = 180;
    //         var h = getNodeRealHeight(n.id);
    //         var pad = 24;
    //
    //         var bL = pos.x - w / 2 - pad;
    //         var bR = pos.x + w / 2 + pad;
    //         var bT = pos.y - h / 2 - pad;
    //         var bB = pos.y + h / 2 + pad;
    //
    //         // Check if segment (p1 -> p2) intersects card box or passes through it
    //         var segMinX = Math.min(p1.x, p2.x);
    //         var segMaxX = Math.max(p1.x, p2.x);
    //         var segMinY = Math.min(p1.y, p2.y);
    //         var segMaxY = Math.max(p1.y, p2.y);
    //
    //         // Coarse AABB overlap check
    //         if (segMaxX < bL || segMinX > bR || segMaxY < bT || segMinY > bB) {
    //             continue;
    //         }
    //
    //         // Test line segment intersection with card's 4 outer boundaries
    //         var hitTop    = segmentsIntersect(p1.x, p1.y, p2.x, p2.y, bL, bT, bR, bT);
    //         var hitBottom = segmentsIntersect(p1.x, p1.y, p2.x, p2.y, bL, bB, bR, bB);
    //         var hitLeft   = segmentsIntersect(p1.x, p1.y, p2.x, p2.y, bL, bT, bL, bB);
    //         var hitRight  = segmentsIntersect(p1.x, p1.y, p2.x, p2.y, bR, bT, bR, bB);
    //
    //         // Also check if p1 or p2 starts inside or segment traverses straight across
    //         var passesThrough = (p1.x <= bL && p2.x >= bR && ((p1.y >= bT && p1.y <= bB) || (p2.y >= bT && p2.y <= bB)));
    //
    //         if (hitTop || hitBottom || hitLeft || hitRight || passesThrough) {
    //             // Route above or below depending on which is closer
    //             var distTop = Math.abs(p1.y - bT) + Math.abs(p2.y - bT);
    //             var distBottom = Math.abs(p1.y - bB) + Math.abs(p2.y - bB);
    //             var detourY = (distTop <= distBottom) ? bT : bB;
    //
    //             return {
    //                 blocked: true,
    //                 corner1X: bL,
    //                 corner2X: bR,
    //                 detourY: detourY
    //             };
    //         }
    //     }
    //     return { blocked: false, corner1X: 0, corner2X: 0, detourY: 0 };
    // }
    // function getWireObstacleData(p1, p2, fromId, toId) {
    //     for (var i = 0; i < nodeList.length; ++i) {
    //         var n = nodeList[i];
    //         if (n.id === fromId || n.id === toId) continue;
    //
    //         var pos = getNodeCenterPos(n.id, n.x, n.y);
    //         var w = 180;
    //         var h = getNodeRealHeight(n.id);
    //         var margin = 20;
    //
    //         var bL = pos.x - w / 2 - margin;
    //         var bR = pos.x + w / 2 + margin;
    //         var bT = pos.y - h / 2 - margin;
    //         var bB = pos.y + h / 2 + margin;
    //
    //         // Bounding box of the segment itself
    //         var segMinX = Math.min(p1.x, p2.x);
    //         var segMaxX = Math.max(p1.x, p2.x);
    //         var segMinY = Math.min(p1.y, p2.y);
    //         var segMaxY = Math.max(p1.y, p2.y);
    //
    //         if (segMaxX < bL || segMinX > bR || segMaxY < bT || segMinY > bB) {
    //             continue;
    //         }
    //
    //         // Decide whether routing above or below gives the shortest path
    //         var detourY = (Math.abs(p1.y - bT) < Math.abs(p1.y - bB)) ? bT : bB;
    //
    //         return {
    //             detected: true,
    //             leftX: bL,
    //             rightX: bR,
    //             detourY: detourY
    //         };
    //     }
    //     return { detected: false, leftX: 0, rightX: 0, detourY: 0 };
    // }

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
        } else {
            movedIds = [primaryMovedId];
        }

        var temp = Object.assign({}, root.nodePositions);
        var gutter = 24;

        // Resolve each moved node in sequence against stationary nodes AND already-placed moved nodes
        for (var m = 0; m < movedIds.length; ++m) {
            var mId = movedIds[m];
            var cur = root.getNodeCenterPos(mId, 0, 0);
            var cardW = 180;
            var cardH = root.getNodeRealHeight(mId);

            var bestX = cur.x;
            var bestY = cur.y;

            // Check if (bestX, bestY) collides with ANY other node on the canvas
            if (isPositionColliding(mId, bestX, bestY, cardW, cardH, temp, gutter)) {
                // Search outward in 24px steps for nearest collision-free position
                var found = false;
                for (var r = 24; r <= 1200; r += 24) {
                    var candidates = [
                        {
                            x: cur.x,
                            y: cur.y + r
                        },
                        {
                            x: cur.x,
                            y: cur.y - r
                        },
                        {
                            x: cur.x + r,
                            y: cur.y
                        },
                        {
                            x: cur.x - r,
                            y: cur.y
                        },
                        {
                            x: cur.x + r,
                            y: cur.y + r
                        },
                        {
                            x: cur.x - r,
                            y: cur.y + r
                        },
                        {
                            x: cur.x + r,
                            y: cur.y - r
                        },
                        {
                            x: cur.x - r,
                            y: cur.y - r
                        }
                    ];
                    for (var c = 0; c < candidates.length; ++c) {
                        if (!isPositionColliding(mId, candidates[c].x, candidates[c].y, cardW, cardH, temp, gutter)) {
                            bestX = candidates[c].x;
                            bestY = candidates[c].y;
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
        }

        root.nodePositions = temp;
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
    // function resolveDraggedNodeOverlap(movingId) {
    //     var cardW = 180;
    //     var cardH = getNodeRealHeight(movingId);
    //     var cur = getNodeCenterPos(movingId, 0, 0);
    //
    //     // If current location does not overlap anything, keep it
    //     if (!testCardCollisionAt(cur.x, cur.y, cardW, cardH, movingId)) {
    //         return;
    //     }
    //
    //     // Search outward in expanding rings (step of 24px) for the nearest collision-free position
    //     var step = 24;
    //     var maxRadius = 1200;
    //     var foundFree = false;
    //     var bestX = cur.x;
    //     var bestY = cur.y;
    //
    //     for (var r = step; r <= maxRadius; r += step) {
    //         // Check cardinal and diagonal directions around current position
    //         var candidates = [
    //             { x: cur.x, y: cur.y + r },
    //             { x: cur.x, y: cur.y - r },
    //             { x: cur.x + r, y: cur.y },
    //             { x: cur.x - r, y: cur.y },
    //             { x: cur.x + r, y: cur.y + r },
    //             { x: cur.x - r, y: cur.y + r },
    //             { x: cur.x + r, y: cur.y - r },
    //             { x: cur.x - r, y: cur.y - r }
    //         ];
    //
    //         for (var c = 0; c < candidates.length; ++c) {
    //             if (!testCardCollisionAt(candidates[c].x, candidates[c].y, cardW, cardH, movingId)) {
    //                 bestX = candidates[c].x;
    //                 bestY = candidates[c].y;
    //                 foundFree = true;
    //                 break;
    //             }
    //         }
    //         if (foundFree) break;
    //     }
    //
    //     var temp = Object.assign({}, root.nodePositions);
    //     temp[movingId] = { x: bestX, y: bestY };
    //     root.nodePositions = temp;
    // }

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

    // function clearAllPinHighlights() {
    //     root.activeHoveredTargetNodeId = "";
    //     root.activeHoveredTargetSocketId = "";
    //     for (var i = 0; i < cardRepeater.count; ++i) {
    //         var c = cardRepeater.itemAt(i);
    //         if (c && c.activeHighlightSocketId !== undefined) {
    //             c.activeHighlightSocketId = "";
    //         }
    //     }
    // }

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

    function createGroupFromSelected() {
        if (selectedNodeIds.length === 0)
            return;
        var gId = "group_" + Date.now();
        var newGroup = {
            id: gId,
            name: "Node Group",
            nodeIds: selectedNodeIds.slice()
        };
        var copy = root.groupList.slice();
        copy.push(newGroup);
        root.groupList = copy;
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
    // Spatial Collision & Free Space Discovery Solver
    // =========================================================================
    function findFreeSpaceAround(targetX, targetY, excludeId) {
        var nodeW = 190, nodeH = 110, padding = 32;
        var checkX = targetX, checkY = targetY;
        var angle = 0, radius = 0, step = 30;

        while (isSpaceOccupied(checkX, checkY, nodeW, nodeH, excludeId)) {
            radius += 18;
            angle += 45;
            var rad = angle * (Math.PI / 180);
            checkX = targetX + Math.cos(rad) * radius;
            checkY = targetY + Math.sin(rad) * radius;
            // Align search to grid
            checkX = Math.round(checkX / 24) * 24;
            checkY = Math.round(checkY / 24) * 24;
        }
        return {
            x: checkX,
            y: checkY
        };
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

    // Runs a relaxation pass separating any intersecting nodes
    // Automatically offsets ONLY the node being dragged when it collides with an existing node
    // function resolveDraggedNodeOverlap(movingId) {
    //         var cardW = 180;
    //         var cardH = getNodeRealHeight(movingId);
    //         var gutter = 28;
    //
    //         var temp = Object.assign({}, root.nodePositions);
    //         var cur = getNodeCenterPos(movingId, 0, 0);
    //         var currentX = cur.x;
    //         var currentY = cur.y;
    //
    //         // Iterative relaxation loop: checks and resolves up to 8 chained collisions
    //         var maxPasses = 8;
    //         for (var pass = 0; pass < maxPasses; ++pass) {
    //             var collisionFound = false;
    //
    //             var myLeft = currentX - cardW / 2;
    //             var myRight = currentX + cardW / 2;
    //             var myTop = currentY - cardH / 2;
    //             var myBottom = currentY + cardH / 2;
    //
    //             for (var i = 0; i < nodeList.length; ++i) {
    //                 var other = nodeList[i];
    //                 if (other.id === movingId) continue;
    //
    //                 var oPos = (temp[other.id] !== undefined) ? temp[other.id] : getNodeCenterPos(other.id, other.x, other.y);
    //                 var oW = 180;
    //                 var oH = getNodeRealHeight(other.id);
    //
    //                 var oLeft = oPos.x - oW / 2;
    //                 var oRight = oPos.x + oW / 2;
    //                 var oTop = oPos.y - oH / 2;
    //                 var oBottom = oPos.y + oH / 2;
    //
    //                 // AABB Overlap test including gutter
    //                 if (myLeft < oRight + gutter && myRight > oLeft - gutter &&
    //                     myTop < oBottom + gutter && myBottom > oTop - gutter) {
    //
    //                     collisionFound = true;
    //
    //                     // Calculate escape vectors in all 4 cardinal directions
    //                     var pushRight = (oRight + gutter + cardW / 2) - currentX;
    //                     var pushLeft = (oLeft - gutter - cardW / 2) - currentX;
    //                     var pushDown = (oBottom + gutter + cardH / 2) - currentY;
    //                     var pushUp = (oTop - gutter - cardH / 2) - currentY;
    //
    //                     // Find minimum distance escape
    //                     var minPushX = Math.abs(pushRight) < Math.abs(pushLeft) ? pushRight : pushLeft;
    //                     var minPushY = Math.abs(pushDown) < Math.abs(pushUp) ? pushDown : pushUp;
    //
    //                     if (Math.abs(minPushX) < Math.abs(minPushY)) {
    //                         currentX += minPushX;
    //                     } else {
    //                         currentY += minPushY;
    //                     }
    //                     break; // Restart check with new coordinates
    //                 }
    //             }
    //
    //             if (!collisionFound) {
    //                 break; // Fully free of all nodes!
    //             }
    //         }
    //
    //         temp[movingId] = { x: currentX, y: currentY };
    //         root.nodePositions = temp;
    //     }

    onZoomLevelChanged: dagCanvas.requestPaint()
    onPanXChanged: dagCanvas.requestPaint()
    onPanYChanged: dagCanvas.requestPaint()

    function smoothNavigateTo(newPanX, newPanY, newZoom) {
        root.zoomLevel = newZoom;
        root.panX = newPanX;
        root.panY = newPanY;
    }

    property var nodePositions: ({})

    // View State Flags
    property bool showGrid: true
    property bool isSnappingEnabled: true

    // Wire style toggle: "curve" or "straight"
    property string wireStyle: "curve"

    // Multi-Selection State (Normal mouse drag marquee)
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
    property real currentMouseScreenX: 0
    property real currentMouseScreenY: 0

    // // Snap Guideline Visualization States
    //     property bool snapGuideXVisible: false
    //     property bool snapGuideYVisible: false
    //     property real snapGuideXPos: 0
    //     property real snapGuideYPos: 0

    // Red Dotted Alignment Snap Lines
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
        if (nodePositions[nodeId] !== undefined) {
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
    // function segmentsIntersect(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y) {
    //     var d = (p2x - p1x) * (p4y - p3y) - (p2y - p1y) * (p4x - p3x);
    //     if (d === 0) return false;
    //     var u = ((p3x - p1x) * (p4y - p3y) - (p3y - p1y) * (p4x - p3x)) / d;
    //     var v = ((p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x)) / d;
    //     return (u >= 0 && u <= 1 && v >= 0 && v <= 1);
    // }

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
    function alignSelectedToAverageHorizontal() {
        if (selectedNodeIds.length < 2)
            return;
        var sumX = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumX += getNodeCenterPos(selectedNodeIds[i], 0, 0).x;
        }
        var avgX = Math.round(sumX / selectedNodeIds.length);

        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            var curY = getNodeCenterPos(id, 0, 0).y;
            temp[id] = {
                x: avgX,
                y: curY
            };
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, avgX, curY);
            }
        }
        root.nodePositions = temp;
    }

    // Align all selected nodes along their average/mean vertical center (Average Y)
    function alignSelectedToAverageVertical() {
        if (selectedNodeIds.length < 2)
            return;
        var sumY = 0;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            sumY += getNodeCenterPos(selectedNodeIds[i], 0, 0).y;
        }
        var avgY = Math.round(sumY / selectedNodeIds.length);

        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            var curX = getNodeCenterPos(id, 0, 0).x;
            temp[id] = {
                x: curX,
                y: avgY
            };
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, curX, avgY);
            }
        }
        root.nodePositions = temp;
    }

    // function isPointInPolygon(px, py, points) {
    //         if (!points || points.length < 3) return false;
    //         var inside = false;
    //         for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    //             var xi = points[i].x, yi = points[i].y;
    //             var xj = points[j].x, yj = points[j].y;
    //             var intersect = ((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
    //             if (intersect) inside = !inside;
    //         }
    //         return inside;
    //     }

    // Pixel-perfect pin coordinate calculator (matches NodeCard layout)
    // 1. Exact Pin Coordinate Lookup from actual instantiated card items
    // Reliable Global Pin Position Calculator
    // Pixel-perfect pin calculator - Reads nodePositions directly for 60fps real-time wire updates
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
    // function calculatePinGlobalPos(nodeId, socketId, isOutput) {
    //     var nData = null;
    //     for (var j = 0; j < nodeList.length; ++j) {
    //         if (nodeList[j].id === nodeId) {
    //             nData = nodeList[j];
    //             break;
    //         }
    //     }
    //     var center = getNodeCenterPos(nodeId, nData ? nData.x : 0, nData ? nData.y : 0);
    //     var cardW = 180;
    //     var px = center.x + (isOutput ? (cardW / 2) : (-cardW / 2));
    //     var cardH = getNodeRealHeight(nodeId);
    //     var topY = center.y - cardH / 2;
    //
    //     var sIdx = 0;
    //     if (isOutput) {
    //         if (nData && nData.outputs) {
    //             for (var o = 0; o < nData.outputs.length; ++o) {
    //                 if (nData.outputs[o].id === socketId) { sIdx = o; break; }
    //             }
    //         }
    //         return Qt.point(px, topY + 28 + 8 + (sIdx * 24) + 12);
    //     } else {
    //         if (nData && nData.inputs) {
    //             for (var k = 0; k < nData.inputs.length; ++k) {
    //                 if (nData.inputs[k].id === socketId) { sIdx = k; break; }
    //             }
    //         }
    //         return Qt.point(px, topY + 28 + 8 + (sIdx * 24) + 12);
    //     }
    // }

    // Inserts a Reroute dot on an existing wire connection
    function insertRerouteOnLink(link, clickWsX, clickWsY) {
        if (!root.activeTimelineModel || root.currentGraphId === "")
            return;

        // 1. Add the "Reroute" node at the click position
        var newRerouteId = "";
        if (root.activeTimelineModel.addNode) {
            newRerouteId = root.activeTimelineModel.addNode(root.currentGraphId, "Reroute", clickWsX, clickWsY);
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
    // function insertRerouteOnLink(link, clickX, clickY) {
    //     if (!root.activeTimelineModel) return;
    //     var rId = root.activeTimelineModel.addNode(root.currentGraphId, "Reroute", clickX, clickY);
    //     if (!rId) return;
    //
    //     root.activeTimelineModel.disconnectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);
    //     root.activeTimelineModel.connectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, rId, "in");
    //     root.activeTimelineModel.connectSockets(root.currentGraphId, rId, "out", link.toNodeId, link.toSocketId);
    // }

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

    function findTargetInputPinAt(wsX, wsY) {
        var threshold = 28.0; // In world space pixels
        for (var i = 0; i < cardRepeater.count; ++i) {
            var card = cardRepeater.itemAt(i);
            if (!card || card.nodeId === root.wireFromNodeId)
                continue;

            if (card.nodeData && card.nodeData.inputs) {
                for (var s = 0; s < card.nodeData.inputs.length; ++s) {
                    var sock = card.nodeData.inputs[s];
                    var pinPos = card.getPinCenterInWorkspace(sock.id, false);
                    var dx = wsX - pinPos.x;
                    var dy = wsY - pinPos.y;
                    if (Math.sqrt(dx * dx + dy * dy) <= threshold) {
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
        var ub = ((a2x - a1x) * (a1y - b1y) - (a2y - a1y) * (a1x - b1x)) / denom;
        return (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1);
    }

    function executeScissorCut() {
        if (!root.activeTimelineModel)
            return;
        for (var i = root.linkList.length - 1; i >= 0; --i) {
            var link = root.linkList[i];
            var p1 = calculatePinGlobalPos(link.fromNodeId, link.fromSocketId, true);
            var p2 = calculatePinGlobalPos(link.toNodeId, link.toSocketId, false);
            if (linesIntersect(scissorStartX, scissorStartY, scissorCurrentX, scissorCurrentY, p1.x, p1.y, p2.x, p2.y)) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, link.fromNodeId, link.fromSocketId, link.toNodeId, link.toSocketId);
            }
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
    // KEY / NODE MENU ACTIONS
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
            temp[id] = {
                x: Math.round(cur.x / gridSize) * gridSize,
                y: Math.round(cur.y / gridSize) * gridSize
            };
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, temp[id].y);
            }
        }
        root.nodePositions = temp;
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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, minX, temp[id].y);
            }
        }
        root.nodePositions = temp;
    }

    function alignSelectedRight() {
        if (selectedNodeIds.length < 2)
            return;
        var maxX = -Infinity;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            maxX = Math.max(maxX, getNodeCenterPos(selectedNodeIds[i], 0, 0).x);
        }
        var temp = Object.assign({}, root.nodePositions);
        for (var j = 0; j < selectedNodeIds.length; ++j) {
            var id = selectedNodeIds[j];
            temp[id] = {
                x: maxX,
                y: getNodeCenterPos(id, 0, 0).y
            };
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, maxX, temp[id].y);
            }
        }
        root.nodePositions = temp;
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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, minY);
            }
        }
        root.nodePositions = temp;
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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, maxY);
            }
        }
        root.nodePositions = temp;
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
            var newX = startX + (i * step);
            temp[id] = {
                x: newX,
                y: getNodeCenterPos(id, 0, 0).y
            };
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, newX, temp[id].y);
            }
        }
        root.nodePositions = temp;
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
            if (root.activeTimelineModel) {
                root.activeTimelineModel.setNodePosition(root.currentGraphId, id, temp[id].x, newY);
            }
        }
        root.nodePositions = temp;
    }

    function duplicateSelectedNodes() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        var newSelection = [];
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            var origId = selectedNodeIds[i];
            var pos = getNodeCenterPos(origId, 0, 0);
            var nodeType = "Transform";
            for (var j = 0; j < nodeList.length; ++j) {
                if (nodeList[j].id === origId) {
                    nodeType = nodeList[j].typeName;
                    break;
                }
            }

            var newId = root.activeTimelineModel.addNode(root.currentGraphId, nodeType, pos.x + 40, pos.y + 40);
            if (newId)
                newSelection.push(newId);
        }
        selectedNodeIds = newSelection;
    }

    function cutSelectedNodeLinks() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = linkList.length - 1; i >= 0; --i) {
            var l = linkList[i];
            if (selectedNodeIds.indexOf(l.fromNodeId) !== -1 || selectedNodeIds.indexOf(l.toNodeId) !== -1) {
                root.activeTimelineModel.disconnectSockets(root.currentGraphId, l.fromNodeId, l.fromSocketId, l.toNodeId, l.toSocketId);
            }
        }
    }

    function deleteSelectedNodes() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            root.activeTimelineModel.removeNode(root.currentGraphId, selectedNodeIds[i]);
        }
        selectedNodeIds = [];
    }

    function toggleMuteSelectedNodes() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (root.activeTimelineModel.setNodeBypassed) {
                root.activeTimelineModel.setNodeBypassed(root.currentGraphId, selectedNodeIds[i]);
            }
        }
    }

    function openSearchPopupAtWorkspace(wsX, wsY, fromNode, fromSocket) {
        var canvasPt = graphWorkspace.mapToItem(Overlay.overlay, wsX, wsY);
        searchPopup.spawnX = wsX;
        searchPopup.spawnY = wsY;
        searchPopup.linkFromNodeId = fromNode;
        searchPopup.linkFromSocketId = fromSocket;
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

    function clearSelectedNodeValues() {
        if (!root.activeTimelineModel || selectedNodeIds.length === 0)
            return;
        for (var i = 0; i < selectedNodeIds.length; ++i) {
            if (root.activeTimelineModel.resetNodeValues) {
                root.activeTimelineModel.resetNodeValues(root.currentGraphId, selectedNodeIds[i]);
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
            keyMenu.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.deleteSelectedNodes();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_A)) {
            var wsPt = mapToItem(graphWorkspace, currentMouseScreenX, currentMouseScreenY);
            root.openSearchPopupAtWorkspace(wsPt.x, wsPt.y, "", "");
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
        Rectangle {
            id: mainTopBar
            Layout.fillWidth: true
            height: 38
            color: root.bgDark
            z: 110

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Rectangle {
                    id: btnView
                    implicitWidth: viewLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 5
                    color: viewMouse.containsMouse ? "#282828" : "transparent"
                    Text {
                        id: viewLabel
                        anchors.centerIn: parent
                        text: "View"
                        color: "#c4c4c4"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: viewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var pt = btnView.mapToItem(Overlay.overlay, 0, btnView.height + 4);
                            viewMenu.openAt(pt.x, pt.y);
                        }
                    }
                }

                Rectangle {
                    id: btnSelect
                    implicitWidth: selectLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 5
                    color: selectMouse.containsMouse ? "#282828" : "transparent"
                    Text {
                        id: selectLabel
                        anchors.centerIn: parent
                        text: "Select"
                        color: "#c4c4c4"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: selectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var pt = btnSelect.mapToItem(Overlay.overlay, 0, btnSelect.height + 4);
                            selectMenu.openAt(pt.x, pt.y);
                        }
                    }
                }

                Rectangle {
                    id: btnKey
                    implicitWidth: keyLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 5
                    color: keyMouse.containsMouse ? "#282828" : "transparent"
                    Text {
                        id: keyLabel
                        anchors.centerIn: parent
                        text: "Key"
                        color: "#c4c4c4"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: keyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var pt = btnKey.mapToItem(Overlay.overlay, 0, btnKey.height + 4);
                            keyMenu.openAt(pt.x, pt.y);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        XylaNodeGraphBreadcrumbBar {
            activeTimelineModel: root.activeTimelineModel
            activeSelectedClipId: root.activeSelectedClipId
            currentGraphId: root.currentGraphId

            onGraphSelected: function (gId) {
                root.selectGraph(gId);
            }
        }

        // =====================================================================
        // 2. Canvas Container with Floating Transparent Bar
        // =====================================================================
        ////////// NOTE: REVERT HERE //////////////////////////////////////////

        // Canvas Container Area
        // -------------------------------------------------------------------------
        // CANVAS CONTAINER (Direct child of layout, or anchored to root)
        // -------------------------------------------------------------------------
        Item {
            id: canvasAreaContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // 2. THE EMPTY STATE / DEFAULT GRAPH INDICATOR
            XylaNodeGraphEmptyState {
                anchors.centerIn: parent
                visible: root.isCurrentGraphReadOnly

                onCreateRequested: {
                    if (!root.activeTimelineModel)
                        return;
                    var allG = root.activeTimelineModel.getAllProjectGraphs();
                    var newName = "Graph " + (allG.length + 1);
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

                // [All your existing interactive canvas components: grid canvas, wires, cardRepeater, etc.]

                ////////// NOTE: REVERT HERE //////////////////////////////////////////
                //
                // Item {
                //     id: canvasContainer
                //     Layout.fillWidth: true
                //     Layout.fillHeight: true
                //     clip: true

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
                                var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
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
                                if (!(mouse.modifiers & Qt.ShiftModifier)) {
                                    root.selectedNodeIds = [];
                                }
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            var overlayPt = canvasPanArea.mapToItem(Overlay.overlay, mouse.x, mouse.y);
                            contextMenu.openAt(overlayPt.x, overlayPt.y, root.currentGraphId, "", 0, root.selectedNodeIds.length > 0);
                        }
                    }

                    onPositionChanged: function (mouse) {
                        root.currentMouseScreenX = mouse.x;
                        root.currentMouseScreenY = mouse.y;

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

                            root.selectedNodeIds = newlySelected;
                            root.isBoxSelecting = false;
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

                // =================================================================
                // 1. Auto-Fitting Minimap (Camera frustum never overflows)
                // =================================================================
                Rectangle {
                    id: minimapHUD
                    visible: root.showMinimap
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: 190
                    height: 130
                    radius: 8
                    color: "#181818"
                    border.color: "#303030"
                    border.width: 1
                    z: 105
                    clip: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#90000000"
                        shadowBlur: 0.6
                        shadowVerticalOffset: 4
                    }

                    Item {
                        id: minimapScene
                        anchors.fill: parent
                        // anchors.margins: 8

                        // Active Camera Frustum in World Space
                        readonly property real camLeft: (-canvasContainer.width / 2 - root.panX) / root.zoomLevel
                        readonly property real camRight: (canvasContainer.width / 2 - root.panX) / root.zoomLevel
                        readonly property real camTop: (-canvasContainer.height / 2 - root.panY) / root.zoomLevel
                        readonly property real camBottom: (canvasContainer.height / 2 - root.panY) / root.zoomLevel

                        // Dynamic Combined Bounds (Encloses all nodes + current camera view)
                        property real minX: camLeft
                        property real maxX: camRight
                        property real minY: camTop
                        property real maxY: camBottom

                        function updateBounds() {
                            var bMinX = camLeft, bMaxX = camRight;
                            var bMinY = camTop, bMaxY = camBottom;
                            for (var i = 0; i < root.nodeList.length; ++i) {
                                var pos = root.getNodeCenterPos(root.nodeList[i].id, root.nodeList[i].x, root.nodeList[i].y);
                                bMinX = Math.min(bMinX, pos.x - 100);
                                bMaxX = Math.max(bMaxX, pos.x + 100);
                                bMinY = Math.min(bMinY, pos.y - 70);
                                bMaxY = Math.max(bMaxY, pos.y + 70);
                            }
                            var spanX = Math.max(400, bMaxX - bMinX);
                            var spanY = Math.max(300, bMaxY - bMinY);
                            minX = bMinX - spanX * 0.05;
                            maxX = bMaxX + spanX * 0.05;
                            minY = bMinY - spanY * 0.05;
                            maxY = bMaxY + spanY * 0.05;
                        }

                        onCamLeftChanged: updateBounds()
                        onCamTopChanged: updateBounds()
                        onCamRightChanged: updateBounds()
                        onCamBottomChanged: updateBounds()

                        // World-to-Minimap coordinate converters
                        function mapWsToMinimapX(wsX) {
                            var rangeX = maxX - minX;
                            if (rangeX <= 0)
                                return 0;
                            return (wsX - minX) / rangeX * minimapScene.width;
                        }

                        function mapWsToMinimapY(wsY) {
                            var rangeY = maxY - minY;
                            if (rangeY <= 0)
                                return 0;
                            return (wsY - minY) / rangeY * minimapScene.height;
                        }

                        // Subtle Dotted Central Origin Axes in Minimap
                        Shape {
                            anchors.fill: parent
                            z: 1
                            ShapePath {
                                strokeColor: "#2a2a2a"
                                strokeWidth: 1
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [2, 3]
                                startX: minimapScene.mapWsToMinimapX(0)
                                startY: 0
                                PathLine {
                                    x: minimapScene.mapWsToMinimapX(0)
                                    y: minimapScene.height
                                }
                            }
                            ShapePath {
                                strokeColor: "#2a2a2a"
                                strokeWidth: 1
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [2, 3]
                                startX: 0
                                startY: minimapScene.mapWsToMinimapY(0)
                                PathLine {
                                    x: minimapScene.width
                                    y: minimapScene.mapWsToMinimapY(0)
                                }
                            }
                        }

                        // Aspect-Ratio Aware Node Cards in Minimap
                        // Real-Height-Aware Node Cards in Minimap
                        Repeater {
                            model: root.nodeList
                            delegate: Rectangle {
                                property var pos: root.getNodeCenterPos(modelData.id, modelData.x, modelData.y)
                                readonly property real realNodeH: root.getNodeRealHeight(modelData.id)

                                readonly property real scaleFactorX: minimapScene.width / Math.max(1, minimapScene.maxX - minimapScene.minX)
                                readonly property real scaleFactorY: minimapScene.height / Math.max(1, minimapScene.maxY - minimapScene.minY)

                                readonly property real cardMiniW: Math.max(6, 180 * scaleFactorX)
                                readonly property real cardMiniH: Math.max(3, realNodeH * scaleFactorY)

                                x: minimapScene.mapWsToMinimapX(pos.x) - cardMiniW / 2
                                y: minimapScene.mapWsToMinimapY(pos.y) - cardMiniH / 2
                                width: cardMiniW
                                height: cardMiniH
                                radius: 1.5
                                color: root.selectedNodeIds.indexOf(modelData.id) !== -1 ? "#3B82F6" : "#444444"
                                border.color: "#181818"
                                border.width: 0.5
                                z: 2
                            }
                        }

                        // Viewport Frustum Box Frame
                        Rectangle {
                            z: 3
                            x: minimapScene.mapWsToMinimapX(minimapScene.camLeft)
                            y: minimapScene.mapWsToMinimapY(minimapScene.camTop)
                            width: Math.max(8, (minimapScene.camRight - minimapScene.camLeft) / Math.max(1, minimapScene.maxX - minimapScene.minX) * minimapScene.width)
                            height: Math.max(8, (minimapScene.camBottom - minimapScene.camTop) / Math.max(1, minimapScene.maxY - minimapScene.minY) * minimapScene.height)
                            radius: 2
                            color: "#15ffffff"
                            border.color: "#60A5FA"
                            border.width: 1
                        }

                        // Click minimap to jump camera
                        MouseArea {
                            anchors.fill: parent
                            z: 4
                            onClicked: function (mouse) {
                                var clickWsX = minimapScene.minX + (mouse.x / minimapScene.width) * (minimapScene.maxX - minimapScene.minX);
                                var clickWsY = minimapScene.minY + (mouse.y / minimapScene.height) * (minimapScene.maxY - minimapScene.minY);
                                root.panX = -clickWsX * root.zoomLevel;
                                root.panY = -clickWsY * root.zoomLevel;
                                dagCanvas.requestPaint();
                            }
                        }
                    }
                }

                // Floating Transparent Bar: Controls pushed to RIGHT edge
                Rectangle {
                    id: graphUtilityBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 42
                    color: "transparent"
                    z: 100

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 4
                        spacing: 8

                        // 1. Selection Mode Toggle (Box / Circle / Lasso)
                        XylaSegmentedToggle {
                            id: selectionModeToggle

                            options: [
                                {
                                    icon: "qrc:/assets/icons/square.svg",
                                    value: "box"
                                },
                                {
                                    icon: "qrc:/assets/icons/circle.svg",
                                    value: "circle"
                                },
                                {
                                    icon: "qrc:/assets/icons/lasso.svg",
                                    value: "lasso"
                                }
                            ]

                            currentIndex: root.selectionMode === "box" ? 0 : root.selectionMode === "circle" ? 1 : 2

                            onOptionSelected: (index, value) => {
                                root.selectionMode = value;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        } // Pushes items to the right

                        // 2. Wire Style Toggle (Curve vs Straight)
                        XylaSegmentedToggle {
                            id: wireStyleToggle

                            options: [
                                {
                                    icon: "qrc:/assets/icons/curve.svg",
                                    value: "curve"
                                },
                                {
                                    icon: "qrc:/assets/icons/line.svg",
                                    value: "straight"
                                }
                            ]

                            currentIndex: root.wireStyle === "curve" ? 0 : 1

                            onOptionSelected: (index, value) => {
                                root.wireStyle = value;
                            }
                        }

                        // 3. Active Graph Selector Dropdown
                        // =========================================================
                        // 3. Project Graphs Selector with Working Double-Click Rename
                        // =========================================================
                        Item {
                            id: graphSelectWrapper
                            Layout.preferredWidth: 175
                            Layout.preferredHeight: 30

                            property bool isRenaming: false

                            readonly property var projectGraphs: root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : []

                            // readonly property var graphNames: {
                            //     var names = [];
                            //     for (var i = 0; i < projectGraphs.length; ++i) {
                            //         names.push(projectGraphs[i].name + (projectGraphs[i].isDefault ? "" : ""));
                            //     }
                            //     return names;
                            // }
                            //
                            // readonly property int activeIndex: {
                            //     for (var i = 0; i < projectGraphs.length; ++i) {
                            //         if (projectGraphs[i].id === root.currentGraphId) return i;
                            //     }
                            //     return 0;
                            // }
                            //
                            // Bind directly to the reactive revision counter
                            property var allProjectGraphs: {
                                var _ = root.graphRevision;
                                return root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : [];
                            }

                            // Force a brand new array instance on every change
                            readonly property var graphNames: {
                                var _ = root.graphRevision;
                                var names = [];
                                for (var i = 0; i < allProjectGraphs.length; ++i) {
                                    names.push(allProjectGraphs[i].name + (allProjectGraphs[i].isDefault ? " (Default)" : ""));
                                }
                                return names;
                            }

                            readonly property int activeIndex: {
                                var _ = root.graphRevision;
                                for (var i = 0; i < allProjectGraphs.length; ++i) {
                                    if (allProjectGraphs[i].id === root.currentGraphId)
                                        return i;
                                }
                                return 0;
                            }

                            // Ensure XylaSelect model is reassigned on change:
                            XylaSelect {
                                id: graphSelector
                                anchors.fill: parent
                                visible: !graphSelectWrapper.isRenaming

                                model: graphSelectWrapper.graphNames
                                currentIndex: graphSelectWrapper.activeIndex

                                // Refresh model explicitly whenever graphRevision changes:
                                Connections {
                                    target: root
                                    function onGraphRevisionChanged() {
                                        graphSelector.model = graphSelectWrapper.graphNames;
                                        graphSelector.currentIndex = graphSelectWrapper.activeIndex;
                                    }
                                }

                                onActivated: function (index) {
                                    if (index >= 0 && index < graphSelectWrapper.allProjectGraphs.length) {
                                        var targetGraphId = graphSelectWrapper.allProjectGraphs[index].id;
                                        root.selectGraph(targetGraphId);
                                    }
                                }
                            }

                            // Single-click opens dropdown; Double-click enters rename mode
                            MouseArea {
                                anchors.fill: parent
                                visible: !graphSelectWrapper.isRenaming
                                acceptedButtons: Qt.LeftButton

                                property int clickCount: 0
                                Timer {
                                    id: clickTimer
                                    interval: 180
                                    onTriggered: {
                                        parent.clickCount = 0;
                                        if (graphSelector.opened)
                                            graphSelector.popup.close();
                                        else if (!graphSelector.opened)
                                            graphSelector.open();
                                    }
                                }

                                onClicked: {
                                    clickCount++;
                                    if (clickCount === 1) {
                                        clickTimer.start();
                                    } else if (clickCount >= 2) {
                                        clickTimer.stop();
                                        clickCount = 0;
                                        if (root.currentGraphId !== "default_io_graph") {
                                            graphSelectWrapper.triggerRename();
                                        }
                                    }
                                }
                            }

                            // Inline Rename Surface
                            Rectangle {
                                anchors.fill: parent
                                visible: graphSelectWrapper.isRenaming
                                color: "#18181B"
                                radius: 6
                                border.color: "#2555D3"
                                border.width: 1
                                z: 100

                                TextInput {
                                    id: renameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    color: "#FFFFFF"
                                    font.pixelSize: 12
                                    selectByMouse: true

                                    onEditingFinished: {
                                        if (graphSelectWrapper.isRenaming) {
                                            var trimmed = text.trim();
                                            if (trimmed !== "" && root.activeTimelineModel && root.currentGraphId !== "default_io_graph") {
                                                root.activeTimelineModel.setGraphName(root.currentGraphId, trimmed);
                                            }
                                            graphSelectWrapper.isRenaming = false;
                                        }
                                    }

                                    Keys.onEscapePressed: {
                                        graphSelectWrapper.isRenaming = false;
                                    }
                                }
                            }

                            function triggerRename() {
                                if (root.currentGraphId === "default_io_graph")
                                    return;
                                renameInput.text = root.currentGraphName;
                                isRenaming = true;
                                renameInput.forceActiveFocus();
                                renameInput.selectAll();
                            }
                        }

                        // =========================================================
                        // 4. Create New Graph (+) & Auto-Trigger Rename
                        // =========================================================
                        XylaIconButton {
                            iconSource: "qrc:/assets/icons/plus.svg"
                            tooltip: "Create New Node Graph"

                            onClicked: {
                                if (!root.activeTimelineModel)
                                    return;
                                var allG = root.activeTimelineModel.getAllProjectGraphs();
                                var newName = "Graph " + (allG.length + 1);
                                var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
                                if (newGId !== "") {
                                    if (root.activeSelectedClipId !== "") {
                                        root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
                                        root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newGId);
                                    } else {
                                        root.activeTimelineModel.setStandaloneActiveGraphId(newGId);
                                    }
                                    root.notifyGraphStateChanged();

                                    // Immediate focus rename on the newly created graph
                                    Qt.callLater(function () {
                                        graphSelectWrapper.triggerRename();
                                    });
                                }
                            }
                        }

                        // =========================================================
                        // 5. Link / Unlink Toggle (Live UI Feedback)
                        // =========================================================
                        XylaIconButton {
                            visible: root.activeSelectedClipId !== ""
                            // Cannot unlink the default immutable In/Out graph
                            enabled: !(root.currentGraphId === "default_io_graph" && root.isCurrentGraphAttachedToClip)
                            opacity: enabled ? 1.0 : 0.4

                            // Dynamic icon based on attachment state
                            iconSource: root.isCurrentGraphAttachedToClip ? "qrc:/assets/icons/unlink.svg" : "qrc:/assets/icons/link.svg"

                            tooltip: root.isCurrentGraphAttachedToClip ? "Unlink (detach) graph from this clip" : "Link (attach) this graph to this clip"

                            primary: !root.isCurrentGraphAttachedToClip

                            onClicked: {
                                if (!root.activeTimelineModel || root.activeSelectedClipId === "")
                                    return;

                                if (root.isCurrentGraphAttachedToClip) {
                                    // Detach
                                    root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.currentGraphId);
                                } else {
                                    // Explicitly attach to the clip and set as clip's active graph
                                    root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, root.currentGraphId);
                                    root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, root.currentGraphId);
                                }
                            }
                        }

                        // =========================================================
                        // 6. Delete Graph with Auto-Select Fallback
                        // =========================================================
                        XylaIconButton {
                            enabled: root.currentGraphId !== "default_io_graph"
                            opacity: enabled ? 1.0 : 0.4
                            iconSource: "qrc:/assets/icons/trash.svg"
                            tooltip: enabled ? "Delete graph from project" : "Default cannot be deleted"

                            onClicked: {
                                if (!root.activeTimelineModel || root.currentGraphId === "default_io_graph")
                                    return;

                                var targetToDelete = root.currentGraphId;
                                var allG = root.activeTimelineModel.getAllProjectGraphs();

                                // Find a fallback graph ID before deletion
                                var fallbackId = "default_io_graph";
                                for (var i = allG.length - 1; i >= 0; --i) {
                                    if (allG[i].id !== targetToDelete) {
                                        fallbackId = allG[i].id;
                                        break;
                                    }
                                }

                                // Perform deletion in C++
                                root.activeTimelineModel.deleteProjectGraph(targetToDelete);

                                // Switch active selection to fallback graph
                                if (root.activeSelectedClipId !== "") {
                                    root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, fallbackId);
                                } else {
                                    root.activeTimelineModel.setStandaloneActiveGraphId(fallbackId);
                                }

                                // Trigger immediate UI refresh
                                root.notifyGraphStateChanged();
                            }
                        }
                        // XylaSelect {
                        //     id: graphSelector
                        //     Layout.preferredWidth: 160
                        //
                        //     // If clip is selected, show graphs attached to this clip; otherwise show all project graphs!
                        //     model: {
                        //         if (!root.activeTimelineModel) return [];
                        //         var list = (root.activeSelectedClipId !== "")
                        //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
                        //             : root.activeTimelineModel.getAllProjectGraphs();
                        //
                        //         // Map to array of names for display, keeping IDs accessible
                        //         var names = [];
                        //         for (var i = 0; i < list.length; ++i) {
                        //             names.push(list[i].name + (list[i].isDefault ? " (Default)" : ""));
                        //         }
                        //         return names;
                        //     }
                        //
                        //     // Synchronize current index with root.currentGraphId
                        //     currentIndex: {
                        //         if (!root.activeTimelineModel) return 0;
                        //         var list = (root.activeSelectedClipId !== "")
                        //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
                        //             : root.activeTimelineModel.getAllProjectGraphs();
                        //         for (var i = 0; i < list.length; ++i) {
                        //             if (list[i].id === root.currentGraphId) return i;
                        //         }
                        //         return 0;
                        //     }
                        //
                        //     onActivated: function (index) {
                        //         if (!root.activeTimelineModel) return;
                        //         var list = (root.activeSelectedClipId !== "")
                        //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
                        //             : root.activeTimelineModel.getAllProjectGraphs();
                        //
                        //         if (index >= 0 && index < list.length) {
                        //             var targetGraphId = list[index].id;
                        //             if (root.activeSelectedClipId !== "") {
                        //                 root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, targetGraphId);
                        //             } else {
                        //                 root.activeTimelineModel.setStandaloneActiveGraphId(targetGraphId);
                        //             }
                        //         }
                        //     }
                        // }

                        // 4. Create New Graph (+)
                        // XylaIconButton {
                        //     iconSource: "qrc:/assets/icons/plus.svg"
                        //     ToolTip.text: "Create New Node Graph"
                        //     ToolTip.visible: hovered
                        //
                        //     onClicked: {
                        //         if (!root.activeTimelineModel) return;
                        //         var allGraphs = root.activeTimelineModel.getAllProjectGraphs();
                        //         var newName = "Graph " + (allGraphs.length + 1);
                        //         var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
                        //         if (newGId !== "") {
                        //             if (root.activeSelectedClipId !== "") {
                        //                 root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
                        //                 root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newGId);
                        //             } else {
                        //                 root.activeTimelineModel.setStandaloneActiveGraphId(newGId);
                        //             }
                        //         }
                        //     }
                        // }
                        //
                        // // 5. Detach / Remove Graph from Clip (Only visible when a clip is selected)
                        // XylaIconButton {
                        //     visible: root.activeSelectedClipId !== ""
                        //     enabled: root.currentGraphId !== "default_io_graph"
                        //     opacity: enabled ? 1.0 : 0.4
                        //     iconSource: "qrc:/assets/icons/unlink.svg" // or a disconnect/minus icon
                        //     ToolTip.text: "Detach this graph from the selected clip"
                        //     ToolTip.visible: hovered
                        //
                        //     onClicked: {
                        //         if (root.activeTimelineModel && root.activeSelectedClipId !== "") {
                        //             root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.currentGraphId);
                        //         }
                        //     }
                        // }
                        //
                        // // 6. Delete Graph Entirely (Trash)
                        // XylaIconButton {
                        //     enabled: root.currentGraphId !== "default_io_graph"
                        //     opacity: enabled ? 1.0 : 0.4
                        //     iconSource: "qrc:/assets/icons/trash.svg"
                        //     ToolTip.text: enabled ? "Delete graph from project" : "Default In/Out cannot be deleted"
                        //     ToolTip.visible: hovered
                        //
                        //     onClicked: {
                        //         if (root.activeTimelineModel && root.currentGraphId !== "default_io_graph") {
                        //             root.activeTimelineModel.deleteProjectGraph(root.currentGraphId);
                        //         }
                        //     }
                        // }
                    }
                }
                // Rectangle {
                //     id: graphUtilityBar
                //     anchors.top: parent.top
                //     anchors.left: parent.left
                //     anchors.right: parent.right
                //     height: 42
                //     color: "transparent"
                //     z: 100
                //
                //     RowLayout {
                //         anchors.fill: parent
                //         anchors.leftMargin: 12
                //         anchors.rightMargin: 12
                //         anchors.topMargin: 4
                //         spacing: 8
                //
                //         XylaSegmentedToggle {
                //             id: selectionModeToggle
                //
                //             options: [
                //                 {
                //                     icon: "qrc:/assets/icons/square.svg",
                //                     value: "box"
                //                 },
                //                 {
                //                     icon: "qrc:/assets/icons/circle.svg",
                //                     value: "circle"
                //                 },
                //                 {
                //                     icon: "qrc:/assets/icons/lasso.svg",
                //                     value: "lasso"
                //                 }
                //             ]
                //
                //             currentIndex: root.selectionMode === "box" ? 0 : root.selectionMode === "circle" ? 1 : 2
                //
                //             onOptionSelected: (index, value) => {
                //                 root.selectionMode = value;
                //             }
                //         }
                //
                //         Item { Layout.fillWidth: true } // Pushes items to the right
                //
                //         // Wire Style Toggle (Curve vs Straight)
                //         XylaSegmentedToggle {
                //             id: wireStyleToggle
                //
                //             options: [
                //                 {
                //                     icon: "qrc:/assets/icons/curve.svg",
                //                     value: "curve"
                //                 },
                //                 {
                //                     icon: "qrc:/assets/icons/line.svg",
                //                     value: "straight"
                //                 }
                //             ]
                //
                //             currentIndex: root.wireStyle === "curve" ? 0 : 1
                //
                //             onOptionSelected: (index, value) => {
                //                 root.wireStyle = value;
                //             }
                //         }
                //
                //         XylaIconButton {
                //             iconSource: "qrc:/assets/icons/trash.svg"
                //             onClicked: {
                //                 if (root.activeTimelineModel) {
                //                     root.activeTimelineModel.removeNodeGraph(root.activeGraphId, root.currentGraphId);
                //                 }
                //             }
                //         }
                //
                //         XylaSelect {
                //             id: graphSelector
                //             model: root.availableGraphs
                //             Layout.preferredWidth: 150
                //             onActivated: function (index) {
                //                 if (!root.activeTimelineModel || root.currentGraphId === "") return;
                //                 var graphName = root.availableGraphs[index];
                //                 if (root.activeTimelineModel.setClipActiveGraph) {
                //                     root.activeTimelineModel.setClipActiveGraph(root.currentGraphId, graphName);
                //                 } else if (root.activeTimelineModel.setActiveGraph) {
                //                     root.activeTimelineModel.setActiveGraph(root.currentGraphId, graphName);
                //                 } else if (root.activeTimelineModel.setActiveNodeGraph) {
                //                     root.activeTimelineModel.setActiveNodeGraph(root.currentGraphId, graphName);
                //                 }
                //             }
                //         }
                //
                //         XylaIconButton {
                //             iconSource: "qrc:/assets/icons/plus.svg"
                //             onClicked: {
                //                 var newName = "Graph " + (root.activeTimelineModel.getAllProjectGraphs().length + 1);
                //                 var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
                //                 if (newGId !== "") {
                //                     if (root.activeSelectedClipId !== "") {
                //                         root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
                //                     } else {
                //                         root.activeTimelineModel.setStandaloneActiveGraphId(newGId);
                //                     }
                //                 }
                //             }
                //             // onClicked: {
                //             //     if (root.activeTimelineModel) {
                //             //         root.activeTimelineModel.createNewNodeGraph(root.currentGraphId);
                //             //     }
                //             // }
                //         }
                //
                //         XylaIconButton {
                //             iconSource: "qrc:/assets/icons/trash.svg"
                //             onClicked: {
                //                 if (root.activeTimelineModel) {
                //                     root.activeTimelineModel.removeNodeGraph(root.activeGraphId, root.currentGraphId);
                //                 }
                //             }
                //         }
                //     }
                // }

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

                    // Vertical Red Dotted Snap Line
                    // Shape {
                    //     anchors.fill: parent
                    //     visible: root.snapGuideXVisible
                    //     z: 98
                    //     ShapePath {
                    //         strokeColor: "#AF0044"
                    //         strokeWidth: 1
                    //         strokeStyle: ShapePath.DashLine
                    //         dashPattern: [3, 3]
                    //         startX: root.snapGuideXPos
                    //         startY: -20000
                    //         PathLine { x: root.snapGuideXPos; y: 20000 }
                    //     }
                    // }
                    //
                    // // Horizontal Red Dotted Snap Line
                    // Shape {
                    //     anchors.fill: parent
                    //     visible: root.snapGuideYVisible
                    //     z: 98
                    //     ShapePath {
                    //         strokeColor: "#AF0044"
                    //         strokeWidth: 1
                    //         strokeStyle: ShapePath.DashLine
                    //         dashPattern: [3, 3]
                    //         startX: -20000
                    //         startY: root.snapGuideYPos
                    //         PathLine { x: 20000; y: root.snapGuideYPos }
                    //     }
                    // }

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

                    // 3. Freehand Lasso Canvas Visual
                    // Canvas {
                    //     id: lassoCanvas
                    //     anchors.fill: parent
                    //     visible: root.isBoxSelecting && root.selectionMode === "lasso"
                    //     z: 90
                    //     onPaint: {
                    //         var ctx = getContext("2d");
                    //         ctx.reset();
                    //         if (root.lassoPoints.length < 2) return;
                    //         ctx.strokeStyle = "#3B82F6";
                    //         ctx.fillStyle = "#153B82F6";
                    //         ctx.lineWidth = 1.5;
                    //         ctx.beginPath();
                    //         ctx.moveTo(root.lassoPoints[0].x, root.lassoPoints[0].y);
                    //         for (var i = 1; i < root.lassoPoints.length; ++i) {
                    //             ctx.lineTo(root.lassoPoints[i].x, root.lassoPoints[i].y);
                    //         }
                    //         ctx.closePath();
                    //         ctx.fill();
                    //         ctx.stroke();
                    //     }
                    // }

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
                    // 1. Main Connected Wires (Always Visible on Workspace Canvas)
                    // =============================================================
                    // =============================================================
                    // Connected Wires
                    // =============================================================
                    // =============================================================
                    // Connected Wires Repeater
                    // =============================================================
                    // =============================================================
                    // Connected Wires Repeater
                    // =============================================================
                    Repeater {
                        id: linkRepeater
                        model: root.linkList

                        delegate: Item {
                            id: linkDelegate
                            z: 25

                            property var p1: root.calculatePinGlobalPos(modelData.fromNodeId, modelData.fromSocketId, true)
                            property var p2: root.calculatePinGlobalPos(modelData.toNodeId, modelData.toSocketId, false)

                            readonly property var path: root.solveWirePath(p1, p2, modelData.fromNodeId, modelData.toNodeId)

                            // Bounding box covering pins, straight corners, and bezier control points
                            x: {
                                var minX = Math.min(p1.x, p2.x, path.c1x, path.c2x);
                                if (path.isBlocked) {
                                    minX = Math.min(minX, path.straightPts[1].x, path.straightPts[2].x);
                                }
                                return minX - 40;
                            }
                            y: {
                                var minY = Math.min(p1.y, p2.y, path.c1y, path.c2y);
                                if (path.isBlocked) {
                                    minY = Math.min(minY, path.straightPts[1].y, path.straightPts[2].y);
                                }
                                return minY - 40;
                            }
                            width: {
                                var maxX = Math.max(p1.x, p2.x, path.c1x, path.c2x);
                                if (path.isBlocked) {
                                    maxX = Math.max(maxX, path.straightPts[1].x, path.straightPts[2].x);
                                }
                                return Math.max(60, maxX - x + 40);
                            }
                            height: {
                                var maxY = Math.max(p1.y, p2.y, path.c1y, path.c2y);
                                if (path.isBlocked) {
                                    maxY = Math.max(maxY, path.straightPts[1].y, path.straightPts[2].y);
                                }
                                return Math.max(60, maxY - y + 40);
                            }

                            // Local coordinates
                            readonly property real sX: p1.x - x
                            readonly property real sY: p1.y - y
                            readonly property real eX: p2.x - x
                            readonly property real eY: p2.y - y

                            // 1. STRAIGHT LINE (Direct when clear, 2-turn box detour when blocked)
                            Shape {
                                anchors.fill: parent
                                visible: root.wireStyle === "straight"

                                ShapePath {
                                    strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                                    strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.MiterJoin

                                    startX: linkDelegate.sX
                                    startY: linkDelegate.sY

                                    PathLine {
                                        x: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[1].x - linkDelegate.x) : linkDelegate.eX
                                        y: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[1].y - linkDelegate.y) : linkDelegate.eY
                                    }

                                    PathLine {
                                        x: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[2].x - linkDelegate.x) : linkDelegate.eX
                                        y: linkDelegate.path.isBlocked ? (linkDelegate.path.straightPts[2].y - linkDelegate.y) : linkDelegate.eY
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
                                visible: root.wireStyle === "curve"

                                ShapePath {
                                    strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
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
                                    root.insertRerouteOnLink(modelData, wsPt.x, wsPt.y);
                                }
                            }
                        }
                    }
                    // Repeater {
                    //     id: linkRepeater
                    //     model: root.linkList
                    //
                    //     delegate: Item {
                    //         id: linkDelegate
                    //         z: 25 // Render above grid, below cards
                    //
                    //         property var p1: root.calculatePinGlobalPos(modelData.fromNodeId, modelData.fromSocketId, true)
                    //         property var p2: root.calculatePinGlobalPos(modelData.toNodeId, modelData.toSocketId, false)
                    //
                    //         // Enclose bounding box around the curve + margins
                    //         x: Math.min(p1.x, p2.x) - 30
                    //         y: Math.min(p1.y, p2.y) - 30
                    //         width: Math.abs(p2.x - p1.x) + 60
                    //         height: Math.max(60, Math.abs(p2.y - p1.y) + 60)
                    //
                    //         readonly property real localStartX: p1.x - x
                    //         readonly property real localStartY: p1.y - y
                    //         readonly property real localEndX: p2.x - x
                    //         readonly property real localEndY: p2.y - y
                    //
                    //         Shape {
                    //             anchors.fill: parent
                    //
                    //             ShapePath {
                    //                 strokeColor: wireHoverArea.containsMouse ? "#60A5FA" : (root.showWireColors ? "#3B82F6" : "#71717A")
                    //                 strokeWidth: wireHoverArea.containsMouse ? 3.0 : 2.0
                    //                 fillColor: "transparent"
                    //                 capStyle: ShapePath.RoundCap
                    //
                    //                 startX: linkDelegate.localStartX
                    //                 startY: linkDelegate.localStartY
                    //
                    //                 PathCubic {
                    //                     x: linkDelegate.localEndX
                    //                     y: linkDelegate.localEndY
                    //
                    //                     readonly property var obs: root.getWireObstacleData(
                    //                         linkDelegate.p1,
                    //                         linkDelegate.p2,
                    //                         modelData.fromNodeId,
                    //                         modelData.toNodeId
                    //                     )
                    //
                    //                     readonly property real totalDx: linkDelegate.localEndX - linkDelegate.localStartX
                    //                     readonly property real totalDy: linkDelegate.localEndY - linkDelegate.localStartY
                    //                     readonly property real spanDx: Math.abs(totalDx)
                    //
                    //                     // Detour offset relative to delegate origin
                    //                     readonly property real detourOffsetY: obs.detected ? (obs.detourY - linkDelegate.y - linkDelegate.localStartY) : 0
                    //
                    //                     // 1. STRAIGHT LINE: Orthogonal sharp-turn routing points
                    //                     readonly property real straightC1X: obs.detected ? (obs.leftX - linkDelegate.x) : (linkDelegate.localStartX + totalDx * 0.4)
                    //                     readonly property real straightC1Y: obs.detected ? (obs.detourY - linkDelegate.y) : (linkDelegate.localStartY + totalDy * 0.1)
                    //                     readonly property real straightC2X: obs.detected ? (obs.rightX - linkDelegate.x) : (linkDelegate.localStartX + totalDx * 0.6)
                    //                     readonly property real straightC2Y: obs.detected ? (obs.detourY - linkDelegate.y) : (linkDelegate.localStartY + totalDy * 0.9)
                    //
                    //                     // 2. CURVED LINE: Smooth bezier bowing around obstacle
                    //                     readonly property real curveC1X: linkDelegate.localStartX + Math.max(45, spanDx * 0.45)
                    //                     readonly property real curveC1Y: linkDelegate.localStartY + detourOffsetY
                    //                     readonly property real curveC2X: linkDelegate.localEndX - Math.max(45, spanDx * 0.45)
                    //                     readonly property real curveC2Y: linkDelegate.localEndY + detourOffsetY
                    //
                    //                     // Animated smooth transition between straight orthogonal and curved
                    //                     control1X: straightC1X + (curveC1X - straightC1X) * root.wireCurvatureFactor
                    //                     control1Y: straightC1Y + (curveC1Y - straightC1Y) * root.wireCurvatureFactor
                    //                     control2X: straightC2X + (curveC2X - straightC2X) * root.wireCurvatureFactor
                    //                     control2Y: straightC2Y + (curveC2Y - straightC2Y) * root.wireCurvatureFactor
                    //                 }
                    //             }
                    //         }
                    //
                    //         // Double-click wire to insert Reroute Dot
                    //         MouseArea {
                    //             id: wireHoverArea
                    //             anchors.fill: parent
                    //             hoverEnabled: true
                    //             cursorShape: root.isAltPressed ? Qt.CrossCursor : Qt.ArrowCursor
                    //
                    //             onDoubleClicked: function(mouse) {
                    //                 var wsPt = mapToItem(graphWorkspace, mouse.x, mouse.y);
                    //                 root.insertRerouteOnLink(modelData, wsPt.x, wsPt.y);
                    //             }
                    //         }
                    //     }
                    // }

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

                    // Interactive Dragging Wire
                    // Shape {
                    //     anchors.fill: parent
                    //     visible: root.isConnectingWire
                    //
                    //     ShapePath {
                    //         id: pendingPath
                    //         strokeColor: "#60A5FA"
                    //         strokeWidth: 2
                    //         strokeStyle: ShapePath.DashLine
                    //         dashPattern: [4, 4]
                    //         fillColor: "transparent"
                    //         startX: 0
                    //         startY: 0
                    //
                    //         PathCubic {
                    //             x: root.wireMouseX
                    //             y: root.wireMouseY
                    //             control1X: root.wireStyle === "straight"
                    //                 ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.33)
                    //                 : (pendingPath.startX + Math.max(40, Math.abs(root.wireMouseX - pendingPath.startX) * 0.5))
                    //             control1Y: root.wireStyle === "straight"
                    //                 ? (pendingPath.startY + (root.wireMouseY - pendingPath.startY) * 0.33)
                    //                 : pendingPath.startY
                    //             control2X: root.wireStyle === "straight"
                    //                 ? (pendingPath.startX + (root.wireMouseX - pendingPath.startX) * 0.66)
                    //                 : (root.wireMouseX - Math.max(40, Math.abs(root.wireMouseX - pendingPath.startX) * 0.5))
                    //             control2Y: root.wireStyle === "straight"
                    //                 ? (pendingPath.startY + (root.wireMouseY - pendingPath.startY) * 0.66)
                    //                 : root.wireMouseY
                    //         }
                    //     }
                    // }

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

                    // FIX: Put this inside the delegate
                    // readonly property bool isReroute: root.typeName === "Reroute"
                    //
                    // width: isReroute ? 16 : 180
                    // height: isReroute ? 16 : (root.isCollapsed ? 28 : (28 + bodyColumn.implicitHeight + 14))
                    // radius: isReroute ? 8 : 8
                    // color: isReroute ? (root.isSelected ? "#60A5FA" : "#38BDF8") : "#181818"
                    //
                    // // Only render header and body for regular nodes, not for reroute dots
                    // nodeHeader.visible: !isReroute
                    // bodyColumn.visible: !isReroute && !root.isCollapsed
                    //
                    // // For Reroute dots, the whole 16x16 circle is draggable
                    // MouseArea {
                    //     visible: root.isReroute
                    //     anchors.fill: parent
                    //     cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    //     property real lastX: 0
                    //     property real lastY: 0
                    //
                    //     onPressed: function (mouse) {
                    //         var pt = mapToItem(root.parent, mouse.x, mouse.y);
                    //         lastX = pt.x; lastY = pt.y;
                    //         root.nodeSelected(root.nodeId, mouse.modifiers & Qt.ShiftModifier);
                    //     }
                    //     onPositionChanged: function (mouse) {
                    //         if (pressed) {
                    //             var pt = mapToItem(root.parent, mouse.x, mouse.y);
                    //             root.dragMovedDelta(pt.x - lastX, pt.y - lastY);
                    //             lastX = pt.x; lastY = pt.y;
                    //         }
                    //     }
                    //     onReleased: root.dragFinished()
                    // }
                    // FIX: Put this inside the delegate
                    //
                    // Render Node Cards
                    Repeater {
                        id: cardRepeater
                        model: root.nodeList

                        delegate: XylaNodeCard {
                            nodeData: modelData
                            activeModel: root.activeTimelineModel
                            activeClipId: root.currentGraphId
                            isSelected: root.selectedNodeIds.indexOf(modelData.id) !== -1

                            property var initialPos: root.getNodeCenterPos(modelData.id, modelData.x, modelData.y)
                            x: initialPos.x - width / 2
                            y: initialPos.y - height / 2

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
                                    // Magnetic snap wire tip directly onto the socket
                                    root.wireMouseX = target.pinX;
                                    root.wireMouseY = target.pinY;

                                    // Turn on hover feedback ring on target card
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
                                    root.activeTimelineModel.connectSockets(root.currentGraphId, root.wireFromNodeId, root.wireFromSocketId, target.nodeId, target.socketId);
                                }
                                // Clean up dragging state immediately so it never gets stuck
                                root.clearAllPinHighlights();
                                root.isConnectingWire = false;
                                root.wireFromNodeId = "";
                                root.wireFromSocketId = "";
                            }

                            // Signals: rawTargetX, rawTargetY of the dragged card
                            onDragMovedDelta: function (rawTargetX, rawTargetY) {
                                var primaryId = modelData.id;
                                var curOriginal = root.getNodeCenterPos(primaryId, modelData.x, modelData.y);

                                // Apply snap calculation with zero drag offset buildup
                                var snappedP = root.computeSnappedPosition(primaryId, rawTargetX, rawTargetY);
                                var effectiveDx = snappedP.x - curOriginal.x;
                                var effectiveDy = snappedP.y - curOriginal.y;

                                var temp = Object.assign({}, root.nodePositions);

                                // Move all selected nodes together maintaining exact relative spacing
                                for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                                    var sId = root.selectedNodeIds[i];
                                    var initialPos = root.getNodeCenterPos(sId, 0, 0);
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
                                root.snapGuideXVisible = false;
                                root.snapGuideYVisible = false;
                                // root.resolveDraggedNodeOverlap(modelData.id);
                                root.resolveAllSelectedNodesOverlap(modelData.id);

                                if (root.activeTimelineModel) {
                                    for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                                        var sId = root.selectedNodeIds[i];
                                        var pos = root.getNodeCenterPos(sId, 0, 0);
                                        root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                                    }
                                }
                            }

                            // onDragFinished: {
                            //     if (root.activeTimelineModel) {
                            //         for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                            //             var sId = root.selectedNodeIds[i];
                            //             var pos = root.getNodeCenterPos(sId, 0, 0);
                            //             root.activeTimelineModel.setNodePosition(root.currentGraphId, sId, pos.x, pos.y);
                            //         }
                            //     }
                            // }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 7. Node Search Palette (Overlay Parented)
    // =========================================================================

    // INFO: CONTEXT UP TO HERE

    // =========================================================================
    // Node Search Palette (Overlay Parented)
    // =========================================================================
    Popup {
        id: searchPopup
        parent: Overlay.overlay
        padding: 8
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        transformOrigin: Item.TopLeft
        property real requestedX: 0
        property real requestedY: 0
        property real spawnX: 0
        property real spawnY: 0
        property string linkFromNodeId: ""
        property string linkFromSocketId: ""

        function reposition() {
            if (!Overlay.overlay)
                return;
            x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
        }

        onAboutToShow: reposition()
        onImplicitWidthChanged: if (visible)
            reposition()
        onImplicitHeightChanged: if (visible)
            reposition()

        function openAt(sx, sy) {
            requestedX = sx;
            requestedY = sy;
            searchField.text = "";
            reposition();
            open();
            searchField.forceActiveFocus();
        }

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            id: searchPopupLayout
            width: 240
            spacing: 4

            // Subtle "Add Node" Title at the Top
            Text {
                Layout.leftMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                text: "Add Node"
                color: "#71717A"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            ContextSeparator {}

            // Dynamic Node List Filtered by Search Input
            ListView {
                id: availableNodeListView
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 260)
                clip: true
                spacing: 2

                // Query C++ backend catalog
                readonly property var allNodes: root.activeTimelineModel ? root.activeTimelineModel.getAvailableNodeTypes() : []

                model: {
                    var q = searchField.text.trim().toLowerCase();
                    if (q === "")
                        return allNodes;
                    return allNodes.filter(function (item) {
                        return item.displayName.toLowerCase().indexOf(q) !== -1 || item.category.toLowerCase().indexOf(q) !== -1 || item.typeName.toLowerCase().indexOf(q) !== -1;
                    });
                }

                delegate: ContextMenuRow {
                    width: availableNodeListView.width
                    iconSource: modelData.iconSource
                    text: modelData.displayName

                    onClicked: {
                        searchPopup.close();
                        if (root.isCurrentGraphReadOnly)
                            return;

                        var freePt = root.findFreeSpaceAround(searchPopup.spawnX, searchPopup.spawnY, "");

                        if (modelData.typeName === "Reroute") {
                            root.activeTimelineModel.addRerouteToGraph(root.currentGraphId, freePt.x, freePt.y);
                        } else if (modelData.typeName === "CommentNode") {
                            root.activeTimelineModel.addCommentToGraph(root.currentGraphId, "Notes", freePt.x, freePt.y, 300, 200);
                        } else if (modelData.typeName === "GroupNode") {
                            root.activeTimelineModel.createGroupInGraph(root.currentGraphId, "New Group", root.selectedNodeIds);
                        } else {
                            root.activeTimelineModel.addNodeToGraph(root.currentGraphId, modelData.typeName, freePt.x, freePt.y);
                        }
                    }
                }
            }

            ContextSeparator {}

            // Filter Text Input at the Bottom
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 6
                color: "#121212"
                border.color: searchField.activeFocus ? "#2555D3" : "#333333"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Image {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "qrc:/assets/icons/search.svg"
                        opacity: 0.6
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                    }
                }
            }
        }
    }

    // =========================================================================
    // 1. "View" Menu Popup (All Actions Implemented)
    // =========================================================================
    Popup {
        id: viewMenu
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8
        transformOrigin: Item.TopLeft
        property real requestedX: 0
        property real requestedY: 0

        function reposition() {
            if (!Overlay.overlay)
                return;
            x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
        }

        onAboutToShow: reposition()
        onImplicitWidthChanged: if (visible)
            reposition()
        onImplicitHeightChanged: if (visible)
            reposition()

        function openAt(sx, sy) {
            requestedX = sx;
            requestedY = sy;
            reposition();
            open();
        }

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            width: 240
            spacing: 2

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/focus-2.svg"
                text: "Frame Selected"
                shortcut: "F"
                onClicked: {
                    viewMenu.close();
                    root.frameSelected();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/maximize.svg"
                text: "Frame All" // ; shortcut: "Home"
                onClicked: {
                    viewMenu.close();
                    root.frameAll();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/zoom-in.svg"
                text: "Zoom In" // ; shortcut: "Ctrl++"
                onClicked: {
                    viewMenu.close();
                    root.zoomIn();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/zoom-out.svg"
                text: "Zoom Out"
                shortcut: "Ctrl+-"
                onClicked: {
                    viewMenu.close();
                    root.zoomOut();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/rotate.svg"
                text: "Reset View" // ; shortcut: "Num 0"
                onClicked: {
                    viewMenu.close();
                    root.resetView();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/crosshair.svg"
                text: "View Center" // ; shortcut: "Alt+Home"
                onClicked: {
                    viewMenu.close();
                    root.viewCenter();
                }
            }

            ContextSeparator {}

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/chevron-down.svg"
                text: "Expand All"
                onClicked: {
                    viewMenu.close();
                    root.toggleAllNodeCollapse(false);
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/chevron-right.svg"
                text: "Collapse All"
                onClicked: {
                    viewMenu.close();
                    root.toggleAllNodeCollapse(true);
                }
            }

            ContextSeparator {}

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/grid.svg"
                text: root.showGrid ? "Hide Grid" : "Show Grid"
                onClicked: {
                    viewMenu.close();
                    root.showGrid = !root.showGrid;
                    dagCanvas.requestPaint();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/magnet.svg"
                text: root.isSnappingEnabled ? "Disable Snap to Grid" : "Enable Snap to Grid"
                shortcut: "Shift+S"
                onClicked: {
                    viewMenu.close();
                    root.isSnappingEnabled = !root.isSnappingEnabled;
                    if (root.isSnappingEnabled)
                        root.snapSelectedToGrid();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/palette.svg"
                text: root.showWireColors ? "Hide Wire Colors" : "Show Wire Colors"
                onClicked: {
                    viewMenu.close();
                    root.showWireColors = !root.showWireColors;
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/map-pin.svg"
                text: root.showMinimap ? "Hide Minimap" : "Show Minimap"
                onClicked: {
                    viewMenu.close();
                    root.showMinimap = !root.showMinimap;
                }
            }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/photo.svg"; text: root.showBackdropPreview ? "Hide Backdrop" : "Toggle Backdrop / Viewer Preview"
            //     onClicked: { viewMenu.close(); root.showBackdropPreview = !root.showBackdropPreview; }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/arrows-maximize.svg"; text: "Fullscreen / Maximize Area"; shortcut: "Alt+F10"
            //     onClicked: { viewMenu.close(); root.isFullscreen = !root.isFullscreen; }
            // }
        }
    }

    // =========================================================================
    // 2. "Select" Menu Popup (All Actions Implemented)
    // =========================================================================
    Popup {
        id: selectMenu
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8
        transformOrigin: Item.TopLeft
        property real requestedX: 0
        property real requestedY: 0

        function reposition() {
            if (!Overlay.overlay)
                return;
            x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
        }

        onAboutToShow: reposition()
        onImplicitWidthChanged: if (visible)
            reposition()
        onImplicitHeightChanged: if (visible)
            reposition()

        function openAt(sx, sy) {
            requestedX = sx;
            requestedY = sy;
            reposition();
            open();
        }

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            width: 240
            spacing: 2

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/select-all.svg"
                text: "Select All"
                shortcut: "Ctrl+A"
                onClicked: {
                    selectMenu.close();
                    root.selectAllNodes();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/square-x.svg"
                text: "Deselect All"
                shortcut: "Alt+A"
                onClicked: {
                    selectMenu.close();
                    root.deselectAllNodes();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/switch.svg"
                text: "Invert Selection"
                shortcut: "Ctrl+I"
                onClicked: {
                    selectMenu.close();
                    root.invertNodeSelection();
                }
            }

            ContextSeparator {}

            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/box.svg"; text: "Box Select"; shortcut: "B"
            //     onClicked: { selectMenu.close(); root.selectionMode = "box"; }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/circle-dot.svg"; text: "Circle Select"; shortcut: "C"
            //     onClicked: { selectMenu.close(); root.selectionMode = "circle" }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/circle-dot.svg"; text: "Lasso Select"
            //     onClicked: { selectMenu.close(); root.selectionMode = "lasso" }
            // }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/arrow-back-up.svg"
                text: "Select Linked From"
                shortcut: "["
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    selectMenu.close();
                    root.selectLinkedFrom();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/arrow-forward-up.svg"
                text: "Select Linked To"
                shortcut: "]"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    selectMenu.close();
                    root.selectLinkedTo();
                }
            }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/category.svg"; text: "Select Grouped (by Type, Color, or Category)"; shortcut: "Shift+G"
            //     enabled_: root.selectedNodeIds.length > 0
            //     onClicked: { selectMenu.close(); root.selectGroupedByType(); }
            // }
            //
            // ContextSeparator {}
            //
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/player-pause.svg"; text: "Select Muted / Bypassed Nodes"
            //     onClicked: {
            //         selectMenu.close();
            //         root.selectNodesByFilter(function(node) { return node.isBypassed === true; });
            //     }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/alert-triangle.svg"; text: "Select Error / Unresolved Nodes"
            //     onClicked: {
            //         selectMenu.close();
            //         root.selectNodesByFilter(function(node) { return node.hasError === true; });
            //     }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/search.svg"; text: "Find Node / Quick Search"; shortcut: "Ctrl+F"
            //     onClicked: {
            //         selectMenu.close();
            //         var pt = btnSelect.mapToItem(Overlay.overlay, 0, btnSelect.height + 4);
            //         root.openSearchPopupAtWorkspace(0, 0, "", "");
            //     }
            // }
        }
    }

    // =========================================================================
    // 3. "Key" Menu Popup (All Actions Implemented)
    // =========================================================================
    Popup {
        id: keyMenu
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8
        transformOrigin: Item.TopLeft
        property real requestedX: 0
        property real requestedY: 0

        function reposition() {
            if (!Overlay.overlay)
                return;
            x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
        }

        onAboutToShow: reposition()
        onImplicitWidthChanged: if (visible)
            reposition()
        onImplicitHeightChanged: if (visible)
            reposition()

        function openAt(sx, sy) {
            requestedX = sx;
            requestedY = sy;
            reposition();
            open();
        }

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            width: 240
            spacing: 2

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/plus.svg"
                text: "Add Node..."
                shortcut: "Shift+A"
                onClicked: {
                    keyMenu.close();
                    root.openSearchPopupAtWorkspace(0, 0, "", "");
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/copy.svg"
                text: "Duplicate"
                shortcut: "Ctrl+D"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.duplicateSelectedNodes();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/link.svg"
                text: "Duplicate Linked"
                shortcut: "Alt+D"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.duplicateSelectedNodes();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/trash.svg"
                text: "Delete" // ; shortcut: "Del"
                destructive: true
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.deleteSelectedNodes();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/vector-triangle.svg"
                text: "Delete with Reconnect (Dissolve)"
                shortcut: "Ctrl+X"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.deleteWithReconnect();
                }
            }

            ContextSeparator {}

            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/player-pause.svg"; text: "Mute / Bypass Node"; shortcut: "M"
            //     enabled_: root.selectedNodeIds.length > 0
            //     onClicked: { keyMenu.close(); root.toggleMuteSelectedNodes(); }
            // }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/distribute-vertical.svg"; text: "Toggle Hide / Collapse Sockets"; shortcut: "Ctrl+H"
            //     enabled_: root.selectedNodeIds.length > 0
            //     onClicked: { keyMenu.close(); root.toggleAllNodeCollapse(!root.nodeList[0].isCollapsed); }
            // }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/folder-plus.svg"
                text: "Make Group"
                shortcut: "Ctrl+G"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    if (root.activeTimelineModel && root.activeTimelineModel.groupSelectedNodes) {
                        root.activeTimelineModel.groupSelectedNodes(root.currentGraphId, root.selectedNodeIds);
                    }
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/folder-minus.svg"
                text: "Ungroup"
                shortcut: "Ctrl+Alt+G"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                }
            }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/user-x.svg"; text: "Make Single-User (Unlink Data-Block)"
            //     enabled_: root.selectedNodeIds.length > 0
            //     onClicked: { keyMenu.close(); }
            // }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/point.svg"
                text: "Insert Reroute" // ; shortcut: "Shift+RightClick"
                onClicked: {
                    keyMenu.close();
                    graphWorkspace.insertRerouteOnLink();
                }
            }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/plug-connected.svg"; text: "Connect Selected to Active" // ; shortcut: "F"
            //     enabled_: root.selectedNodeIds.length >= 2
            //     onClicked: { keyMenu.close(); root.connectSelectedToActive(); }
            // }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/scissors.svg"
                text: "Cut Links (Scissor)"
                shortcut: "Ctrl+Alt+X"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.cutSelectedNodeLinks();
                }
            }
            // ContextMenuRow {
            //     iconSource: "qrc:/assets/icons/switch-horizontal.svg"; text: "Swap Links / Sockets"; shortcut: "Alt+S"
            //     enabled_: root.selectedNodeIds.length === 2
            //     onClicked: { keyMenu.close(); root.swapSelectedLinks(); }
            // }

            ContextSeparator {}

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/align-left.svg"
                text: "Align Nodes Vertically"
                enabled_: root.selectedNodeIds.length >= 2
                onClicked: {
                    keyMenu.close();
                    root.alignSelectedToAverageVertical();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/align-left.svg"
                text: "Align Nodes Horizontal"
                enabled_: root.selectedNodeIds.length >= 2
                onClicked: {
                    keyMenu.close();
                    root.alignSelectedToAverageHorizontal();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/distribute-horizontal.svg"
                text: "Distribute Nodes Horizontally"
                enabled_: root.selectedNodeIds.length >= 3
                onClicked: {
                    keyMenu.close();
                    root.distributeSelectedHorizontally();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/distribute-vertical.svg"
                text: "Distribute Nodes Vertically"
                enabled_: root.selectedNodeIds.length >= 3
                onClicked: {
                    keyMenu.close();
                    root.distributeSelectedVertically();
                }
            }
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/refresh.svg"
                text: "Reset Node Values" // ; shortcut: "Backspace"
                enabled_: root.selectedNodeIds.length > 0
                onClicked: {
                    keyMenu.close();
                    root.clearSelectedNodeValues();
                }
            }
        }
    }

    // =========================================================================
    // EXACT LITERAL CONTEXT MENU (With Full Shortcut Token Badges & Snapping)
    // =========================================================================
    Popup {
        id: contextMenu
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8

        property var dopesheetRoot: null
        property var timelineModel: null
        property string activeClipId: ""
        property string activePropertyId: ""
        property real clickedFrame: 0
        property bool hasSelectedKeyframe: false

        signal deleteKeyframeRequested
        signal clearAllKeyframesRequested
        signal setInterpolationRequested(int interpMode)

        background: Rectangle {
            id: popupSurface
            anchors.fill: parent
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            id: popupLayout
            spacing: 4
            width: 230

            // =====================================================================
            // Action Tiles: Strictly Cut, Copy, Paste
            // =====================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                ContextActionTile {
                    Layout.fillWidth: true
                    iconSource: "qrc:/assets/icons/cut.svg" // or scissors icon
                    text: "Cut"
                    // enabled_: root.selectedNodeIds.length > 0 && !root.isCurrentGraphReadOnly
                    enabled: root.selectedNodeIds.length > 0 && !root.isCurrentGraphReadOnly
                    onClicked: {
                        contextMenu.close();
                        root.cutSelectedNodes();
                    }
                }

                ContextActionTile {
                    Layout.fillWidth: true
                    iconSource: "qrc:/assets/icons/copy.svg"
                    text: "Copy"
                    // enabled_: root.selectedNodeIds.length > 0
                    enabled: root.selectedNodeIds.length > 0
                    onClicked: {
                        contextMenu.close();
                        root.copySelectedNodes();
                    }
                }

                ContextActionTile {
                    Layout.fillWidth: true
                    iconSource: "qrc:/assets/icons/clipboard.svg"
                    text: "Paste"
                    // enabled_: !root.isCurrentGraphReadOnly
                    enabled: !root.isCurrentGraphReadOnly
                    onClicked: {
                        contextMenu.close();
                        root.pasteNodes();
                    }
                }
            }

            ContextSeparator {}

            // =====================================================================
            // Node Operations
            // =====================================================================
            ContextMenuRow {
                visible: root.selectedNodeIds.length > 0
                iconSource: "qrc:/assets/icons/copy.svg"
                text: "Duplicate"
                shortcut: "Ctrl+D"
                enabled_: !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.duplicateSelectedNodes();
                }
            }

            ContextMenuRow {
                visible: root.selectedNodeIds.length > 0
                iconSource: "qrc:/assets/icons/box.svg"
                text: "Group Selected"
                shortcut: "Ctrl+G"
                enabled_: !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.activeTimelineModel.createGroupInGraph(root.currentGraphId, "New Group", root.selectedNodeIds);
                }
            }

            ContextMenuRow {
                visible: root.selectedNodeIds.length > 0
                iconSource: "qrc:/assets/icons/trash.svg"
                text: "Delete Selected"
                shortcut: "Del"
                destructive: true
                enabled_: !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    if (root.activeTimelineModel && !root.isCurrentGraphReadOnly) {
                        for (var i = 0; i < root.selectedNodeIds.length; ++i) {
                            root.activeTimelineModel.removeNodeFromGraph(root.currentGraphId, root.selectedNodeIds[i]);
                        }
                        root.selectedNodeIds = [];
                    }
                }
            }

            ContextSeparator {
                visible: root.selectedNodeIds.length > 0
            }

            // =====================================================================
            // Snapping & Node Alignment Operations
            // =====================================================================
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/grid.svg"
                text: "Snap to Grid"
                shortcut: "Shift+S"
                tooltip: "Snaps selected nodes to nearest grid milestones"
                enabled_: root.selectedNodeIds.length > 0 && !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.snapSelectedToGrid();
                }
            }

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/align-left.svg"
                text: "Align Left"
                tooltip: "Aligns selected nodes along left boundary"
                enabled_: root.selectedNodeIds.length >= 2 && !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.alignSelectedLeft();
                }
            }

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/align-top.svg"
                text: "Align Top"
                tooltip: "Aligns selected nodes along top boundary"
                enabled_: root.selectedNodeIds.length >= 2 && !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.alignSelectedTop();
                }
            }

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/distribute-horizontal.svg"
                text: "Distribute Horizontally"
                tooltip: "Distributes selected nodes with equal horizontal spacing"
                enabled_: root.selectedNodeIds.length >= 3 && !root.isCurrentGraphReadOnly
                onClicked: {
                    contextMenu.close();
                    root.distributeSelectedHorizontally();
                }
            }

            ContextSeparator {}

            // =====================================================================
            // Canvas View Helpers
            // =====================================================================
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/maximize.svg"
                text: "Frame All Nodes"
                shortcut: "F"
                onClicked: {
                    contextMenu.close();
                    root.frameAllNodes();
                }
            }

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/refresh.svg"
                text: "Reset Zoom & Pan"
                shortcut: "Ctrl+0"
                onClicked: {
                    contextMenu.close();
                    root.resetZoomAndPan();
                }
            }
        }

        transformOrigin: Item.TopLeft

        property real requestedX: 0
        property real requestedY: 0

        function reposition() {
            if (!Overlay.overlay)
                return;
            x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
        }

        onAboutToShow: reposition()
        onImplicitWidthChanged: if (visible)
            reposition()
        onImplicitHeightChanged: if (visible)
            reposition()

        function openAt(screenX, screenY, clipId, propId, frame, hasKf) {
            requestedX = screenX;
            requestedY = screenY;
            activeClipId = clipId || "";
            activePropertyId = propId || "";
            clickedFrame = frame || 0;
            hasSelectedKeyframe = hasKf || false;
            reposition();
            open();
        }
    }

    // =========================================================================
    // Reusable Context Sub-Components
    // =========================================================================
    component ContextActionTile: Rectangle {
        id: tile
        property string iconSource
        property string text
        signal clicked

        implicitWidth: 50
        implicitHeight: 50
        radius: 8
        color: !tile.enabled ? "#151515" : tileMouse.containsMouse ? "#252525" : "#202020"
        border.color: tileMouse.containsMouse ? "#353535" : "#202020"
        border.width: 1
        opacity: tile.enabled ? 1.0 : 0.38

        Column {
            anchors.centerIn: parent
            spacing: 4

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 17
                height: 17
                source: tile.iconSource
                sourceSize: Qt.size(17, 17)
                opacity: tile.enabled ? 0.9 : 0.45
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.text
                color: "#ffffff"
                font.pixelSize: 10
                opacity: tile.enabled ? 1.0 : 0.45
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    // Full ContextMenuRow with individual key token badge repeater and modifier icons
    component ContextMenuRow: Rectangle {
        id: row
        property string iconSource
        property string text
        property string shortcut: ""
        property bool destructive: false
        property bool showArrow: false
        property bool enabled_: true
        property string tooltip: ""

        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 12
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "#181818"

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        function getModifierIcon(key) {
            var cleanKey = key.trim().toLowerCase();

            if (cleanKey === "ctrl" || cleanKey === "control")
                return "qrc:/assets/icons/command.svg";

            if (cleanKey === "alt")
                return "qrc:/assets/icons/alt.svg";

            if (cleanKey === "shift")
                return "qrc:/assets/icons/shift.svg";

            return "";
        }

        HoverHandler {
            id: rowHover
        }

        XylaToolTip {
            visible: rowHover.hovered && tooltip !== ""
            position: "right"
            text: row.tooltip
        }

        RowLayout {
            id: rowContent

            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 6
            anchors.bottomMargin: 6

            spacing: 10

            // ========================================================
            // ICON
            // ========================================================

            Item {
                id: iconContainer

                implicitWidth: 16
                implicitHeight: 16

                property int visibleWidth: visible ? 16 : 0

                // visible: row.iconSource !== ""
                opacity: row.iconSource !== ""

                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg

                    anchors.fill: parent

                    source: row.iconSource

                    sourceSize: Qt.size(16, 16)

                    fillMode: Image.PreserveAspectFit

                    smooth: true

                    visible: false
                }

                MultiEffect {
                    anchors.fill: iconImg

                    source: iconImg

                    colorization: 1.0

                    colorizationColor: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"
                }
            }

            // ========================================================
            // TITLE
            // ========================================================

            Text {
                id: titleText

                text: row.text

                color: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"

                font.pixelSize: 12

                Layout.minimumWidth: 120
                Layout.fillWidth: true
                Layout.fillHeight: true

                verticalAlignment: Text.AlignVCenter

                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ========================================================
            // SHORTCUT
            // ========================================================

            Row {
                id: shortcutRow

                spacing: 4

                Layout.alignment: Qt.AlignVCenter

                visible: !row.showArrow
                opacity: row.shortcut !== ""

                property var keyTokens: {
                    var rawShortcut = row.shortcut || "";

                    return rawShortcut !== "" ? rawShortcut.split("+") : [];
                }

                Repeater {
                    model: shortcutRow.keyTokens

                    delegate: Item {
                        id: tokenItem

                        property string keyText: modelData.trim()
                        property string iconSrc: row.getModifierIcon(keyText)
                        property bool isModifier: iconSrc !== ""
                        property bool hovered: tokenHover.containsMouse

                        implicitWidth: 20
                        implicitHeight: 20

                        // ------------------------------------------------
                        // KEY BACKGROUND
                        // ------------------------------------------------

                        Rectangle {
                            id: keyBackground

                            anchors.fill: parent

                            color: rowMouse.containsMouse ? "#353535" : "#141414"

                            radius: 5

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // ------------------------------------------------
                        // HOVER DETECTOR
                        // ------------------------------------------------

                        MouseArea {
                            id: tokenHover

                            anchors.fill: parent

                            hoverEnabled: true

                            acceptedButtons: Qt.NoButton
                        }

                        // ------------------------------------------------
                        // MODIFIER ICON
                        // ------------------------------------------------

                        Image {
                            id: modifierImg

                            anchors.centerIn: parent

                            width: 14
                            height: 14

                            source: tokenItem.iconSrc

                            sourceSize: Qt.size(14, 14)

                            fillMode: Image.PreserveAspectFit

                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: modifierImg

                            source: modifierImg

                            // visible: tokenItem.isModifier
                            opacity: tokenItem.isModifier

                            colorization: 1.0

                            colorizationColor: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

                            Behavior on colorizationColor {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // ------------------------------------------------
                        // NORMAL KEY
                        // ------------------------------------------------

                        Text {
                            id: letterLabel

                            anchors.centerIn: parent

                            // visible: !tokenItem.isModifier
                            opacity: !tokenItem.isModifier

                            text: tokenItem.keyText

                            color: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

                            font.pixelSize: 10
                            font.weight: Font.DemiBold

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }

            // ========================================================
            // EXPAND ARROW
            // ========================================================

            Text {
                id: arrowText

                visible: row.showArrow

                text: "›"

                color: "#888888"

                font.pixelSize: 20

                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent

            hoverEnabled: true
            enabled: row.enabled_

            cursorShape: Qt.PointingHandCursor

            onClicked: row.clicked()
        }
    }

    component ContextSeparator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 7
        color: "transparent"
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: "#2d2d2d"
        }
    }
}
