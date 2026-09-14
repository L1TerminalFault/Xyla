import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    property var root: null
    property alias graphSelectWrapper: graphSelectWrapper


    // =====================================================================
    // 1. Top Bar Navigation & Menu Triggers
    // =====================================================================
    Rectangle {
        id: mainTopBar
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        color: root.bgDark
        z: 110

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            // --- View Menu Button ---
            Rectangle {
                id: btnView
                implicitWidth: viewLabel.implicitWidth + 22
                implicitHeight: 26
                radius: 6
                color: viewMouse.containsMouse ? "#282828" : root.bgDark

                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

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

            // --- Select Menu Button ---
            Rectangle {
                id: btnSelect
                implicitWidth: selectLabel.implicitWidth + 22
                implicitHeight: 26
                radius: 6
                color: selectMouse.containsMouse ? "#282828" : root.bgDark

                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

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

            // --- Node Menu Button ---
            Rectangle {
                id: btnNode
                implicitWidth: nodeLabel.implicitWidth + 22
                implicitHeight: 26
                radius: 6
                color: nodeMouse.containsMouse ? "#282828" : root.bgDark

                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Text {
                    id: nodeLabel
                    anchors.centerIn: parent
                    text: "Node"
                    color: "#c4c4c4"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: nodeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pt = btnNode.mapToItem(Overlay.overlay, 0, btnNode.height + 4);
                        nodeMenu.openAt(pt.x, pt.y);
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // -----------------------------------------------------------------
            // CREATE NEW GRAPH BUTTON (+)
            // -----------------------------------------------------------------
            XylaIconButton {
                iconSource: "qrc:/assets/icons/plus.svg"
                tooltip: "Create New Node Graph"

                primary: true

                onClicked: {
                    if (!root || !root.activeTimelineModel) return;
                    // Count existing user graphs for clear numbering
                    var allG = root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : [];
                    var userGraphCount = 0;
                    for (var i = 0; i < allG.length; ++i) {
                        if (allG[i].id !== "default_io_graph" && !allG[i].isDefault) {
                            userGraphCount++;
                        }
                    }
                    var desiredName = "Graph " + (userGraphCount + 1);

                    var newId = root.activeTimelineModel.createNewProjectGraph(desiredName);
                    if (newId && newId !== "") {
                        // If clip selected, auto-bind
                        if (root.activeSelectedClipId !== "") {
                            root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newId);
                            root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newId);
                        }

                        // Select the new graph immediately
                        root.selectGraph(newId);

                        // Trigger rename with the EXACT newly assigned name
                        Qt.callLater(function() {
                            graphSelectWrapper.triggerRename(newId, desiredName);
                        });
                    }
                }
            }

            // -----------------------------------------------------------------
            // XYLA SELECT (NO DEFAULT GRAPH, INLINE RENAME, AUTO-SYNC ON DELETE)
            // -----------------------------------------------------------------
            Item {
                id: graphSelectWrapper
                Layout.preferredWidth: 175
                Layout.preferredHeight: 30

                property bool isRenaming: false
                property var userGraphs: [] // ONLY user editable graphs (NO default_io_graph)
                property var userGraphNames: []
                property bool _cancelGuard: false

                function refreshGraphs() {
                    if (!root || !root.activeTimelineModel) return;
                    var all = root.activeTimelineModel.getAllProjectGraphs();
                    var filtered = [];
                    var names = [];

                    for (var i = 0; i < all.length; ++i) {
                        // FILTER OUT DEFAULT GRAPH COMPLETELY
                        if (all[i].id !== "default_io_graph" && !all[i].isDefault) {
                            filtered.push(all[i]);
                            names.push(all[i].name);
                        }
                    }

                    userGraphs = filtered;
                    userGraphNames = names;
                    graphSelector.model = names;

                    // Sync current index
                    var idx = -1;
                    for (var j = 0; j < filtered.length; ++j) {
                        if (filtered[j].id === root.activeGraphId) {
                            idx = j;
                            break;
                        }
                    }
                    graphSelector.currentIndex = idx;
                }

                Component.onCompleted: {
                    refreshGraphs()
                    // Force evaluation on first load
                    if (root) {
                        var targetId = root.activeGraphId;
                        if (targetId && targetId !== "") {
                            root.selectGraph(targetId);
                        }
                    }
                }

                // Normal Dropdown Mode
                XylaSelect {
                    id: graphSelector
                    anchors.fill: parent
                    visible: !graphSelectWrapper.isRenaming
                    model: graphSelectWrapper.userGraphNames

                    onActivated: function (index) {
                        if (index >= 0 && index < graphSelectWrapper.userGraphs.length) {
                            var chosen = graphSelectWrapper.userGraphs[index];
                            if (root) root.selectGraph(chosen.id);
                        }
                    }
                }

                // Single Click = Dropdown, Double Click = Rename (BLOCKED on Default)
                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (!graphSelector || !graphSelector.popup) return;

                        if (graphSelector.popup.opened || graphSelector.popup.visible) {
                            graphSelector.popup.close();
                        } else {
                            graphSelector.popup.open();
                        }
                    }

                    onDoubleClicked: {
                        if (graphSelector.popup) graphSelector.popup.close();
                        // BLOCK RENAME IF DEFAULT GRAPH OR NO USER GRAPHS
                        if (root && !root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) {
                            graphSelectWrapper.triggerRename(root.activeGraphId, root.currentGraphName);
                        }
                    }
                }

                // Inline Rename Box
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
                        focus: true
                        font.pixelSize: 12
                        selectByMouse: true

                        Connections {
                            target: graphSelectWrapper
                            function onIsRenamingChanged() {
                                if (graphSelectWrapper.isRenaming) {
                                    renameInput.forceActiveFocus();
                                    renameInput.selectAll();
                                }
                            }
                        }

                        // 2. Click outside -> Lost focus -> Cancel rename
                        onActiveFocusChanged: {
                            if (!activeFocus && graphSelectWrapper.isRenaming) {
                                graphSelectWrapper._cancelGuard = true;
                                graphSelectWrapper.isRenaming = false;
                            }
                        }

                        // Helper function to commit changes
                        function commit() {
                            if (!graphSelectWrapper.isRenaming) return;

                            var trimmed = text.trim();
                            if (trimmed !== "" && root && root.activeTimelineModel && !root.isCurrentGraphReadOnly) {
                                // 1. Gather existing names except current
                                var existingNames = [];
                                var all = root.activeTimelineModel.getAllProjectGraphs();
                                for (var i = 0; i < all.length; ++i) {
                                    if (all[i].id !== root.activeGraphId) {
                                        existingNames.push(all[i].name);
                                    }
                                }

                                // 2. Resolve name collisions
                                var finalName = trimmed;
                                var counter = 1;
                                while (existingNames.indexOf(finalName) !== -1) {
                                    finalName = trimmed + " (" + counter + ")";
                                    counter++;
                                }

                                // 3. Commit
                                root.activeTimelineModel.setGraphName(root.activeGraphId, finalName);
                                graphSelectWrapper.refreshGraphs();
                            }
                            graphSelectWrapper.isRenaming = false;
                        }

                        // Commit strictly on Enter / Numpad Enter
                        Keys.onReturnPressed: function(event) {
                            commit();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: function(event) {
                            commit();
                            event.accepted = true;
                        }

                        // Cancel strictly on Escape
                        Keys.onEscapePressed: function(event) {
                            graphSelectWrapper.isRenaming = false;
                            event.accepted = true;
                        }
                    }
                }

                function triggerRename(targetId, initialName) {
                    if (targetId === "default_io_graph" || (root && root.isCurrentGraphReadOnly)) return;
                    renameInput.text = initialName;
                    isRenaming = true;
                    renameInput.forceActiveFocus();
                    renameInput.selectAll();
                }
            }

            // -----------------------------------------------------------------
            // RENAME GRAPH BUTTON
            // -----------------------------------------------------------------
            XylaIconButton {
                iconSource: "qrc:/assets/icons/pen.svg"
                tooltip: "Rename Node Graph"
                
                primary: graphSelectWrapper.isRenaming
                enabled: root && !root.isCurrentGraphReadOnly && root.activeGraphId !== "default_io_graph"

                onClicked: {
                    // If focus loss during this click already canceled the rename, stop here
                    if (graphSelectWrapper._cancelGuard) {
                        Qt.callLater(function() {
                            graphSelectWrapper._cancelGuard = false;
                        });
                        return;
                    }

                    if (graphSelectWrapper.isRenaming) {
                        graphSelectWrapper.isRenaming = false;
                    } else if (root && !root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) {
                        graphSelectWrapper.triggerRename(root.activeGraphId, root.currentGraphName);
                    }
                }
            }

            // -----------------------------------------------------------------
            // LINK / UNLINK BUTTON (INSTANT UI REACTION)
            // -----------------------------------------------------------------
            XylaIconButton {
                visible: root ? root.activeSelectedClipId !== "" : false
                enabled: root ? !root.isCurrentGraphReadOnly : false
                opacity: enabled ? 1.0 : 0.4

                iconSource: root && root.isCurrentGraphLinked 
                    ? "qrc:/assets/icons/unlink.svg" 
                    : "qrc:/assets/icons/link.svg"

                tooltip: root && root.isCurrentGraphLinked 
                    ? "Unlink (detach) graph from clip" 
                    : "Link (attach) graph to clip"

                primary: root ? !root.isCurrentGraphLinked : true

                onClicked: {
                    if (!root || !root.activeTimelineModel || root.activeSelectedClipId === "" || root.isCurrentGraphReadOnly)
                        return;

                    if (root.isCurrentGraphLinked) {
                        root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.activeGraphId);
                        root.isCurrentGraphLinked = false;
                    } else {
                        root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, root.activeGraphId);
                        root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, root.activeGraphId);
                        root.isCurrentGraphLinked = true;
                    }
                }
            }

            // -----------------------------------------------------------------
            // DELETE GRAPH BUTTON (AUTO-SELECTS NEXT REMAINING GRAPH)
            // -----------------------------------------------------------------
            XylaIconButton {
                enabled: root ? (!root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) : false
                opacity: enabled ? 1.0 : 0.4
                iconColor: "#CA1010"
                iconSource: "qrc:/assets/icons/trash.svg"
                tooltip: enabled ? "Delete graph from project" : "Default graph cannot be deleted"

                onClicked: {
                    if (!root || !root.activeTimelineModel || root.isCurrentGraphReadOnly) return;

                    var idToDelete = root.activeGraphId;
                    var list = graphSelectWrapper.userGraphs;

                    // 1. Find index of graph being deleted
                    var curIdx = -1;
                    for (var i = 0; i < list.length; ++i) {
                        if (list[i].id === idToDelete) {
                            curIdx = i;
                            break;
                        }
                    }

                    // 2. Pick next fallback graph from remaining items, or default_io_graph
                    var fallbackId = "default_io_graph";
                    if (list.length > 1) {
                        // If we are deleting the last item, pick the one before it; otherwise pick the next one
                        var nextIdx = (curIdx === list.length - 1) ? (curIdx - 1) : (curIdx + 1);
                        fallbackId = list[nextIdx].id;
                    }

                    // 3. Delete in C++
                    root.activeTimelineModel.deleteProjectGraph(idToDelete);

                    // 4. Switch active graph to fallback and update XylaSelect index
                    root.selectGraph(fallbackId);
                }
            }
        }
    }

    // =====================================================================
    // 2. Breadcrumb Bar Component
    // =====================================================================
    BreadcrumbBar {
        Layout.fillWidth: true
        activeTimelineModel: root.activeTimelineModel
        activeSelectedClipId: root.activeSelectedClipId
        currentGraphId: root.currentGraphId

        onGraphSelected: function (gId) {
            root.selectGraph(gId);
        }

        onReorderClipGraphsRequested: function (cId, orderedIds) {
            if (root.activeTimelineModel && root.activeTimelineModel.reorderClipGraphs) {
                root.activeTimelineModel.reorderClipGraphs(cId, orderedIds);
            }
        }
    }

    // =====================================================================
    // 3. Popup Menu Instances & Signal Bindings
    // =====================================================================
    ViewMenuPopup {
        id: viewMenu
        showGrid: root.showGrid
        isSnappingEnabled: root.isSnappingEnabled
        showWireColors: root.showWireColors
        showMinimap: root.showMinimap

        onFrameSelectedRequested: root.frameSelected()
        onFrameAllRequested: root.frameAll()
        onZoomInRequested: root.zoomIn()
        onZoomOutRequested: root.zoomOut()
        onResetViewRequested: root.resetView()
        onViewCenterRequested: root.viewCenter()
        onExpandAllRequested: root.toggleAllNodeCollapse(false)
        onCollapseAllRequested: root.toggleAllNodeCollapse(true)
        onToggleGridRequested: {
            root.showGrid = !root.showGrid;
            dagCanvas.requestPaint();
        }
        onToggleSnapRequested: {
            root.isSnappingEnabled = !root.isSnappingEnabled;
            if (root.isSnappingEnabled)
                root.snapSelectedToGrid();
        }
        onToggleWireColorsRequested: {
            root.showWireColors = !root.showWireColors;
        }
        onToggleMinimapRequested: {
            root.showMinimap = !root.showMinimap;
        }
    }

    SelectMenuPopup {
        id: selectMenu
        selectedNodeIds: root.selectedNodeIds

        onSelectAllRequested: root.selectAllNodes()
        onDeselectAllRequested: root.deselectAllNodes()
        onInvertSelectionRequested: root.invertNodeSelection()
        onSelectLinkedFromRequested: root.selectLinkedFrom()
        onSelectLinkedToRequested: root.selectLinkedTo()
    }

    NodeMenuPopup {
        id: nodeMenu
        selectedNodeIds: root.selectedNodeIds
        currentGraphId: root.currentGraphId

        // Spawning & Duplication
        onAddNodeRequested: {
            var wsX = (currentMouseScreenX - canvasContainer.width / 2 - root.panX) / root.zoomLevel;
            var wsY = (currentMouseScreenY - canvasContainer.height / 2 - root.panY) / root.zoomLevel;
            root.openSearchPopupAtWorkspace(wsX, wsY, "", "");
        }
        // onAddNodeRequested: {
        //     var centerPt = root.getNodeCenterPos(root.selectedNodeIds[0] || "", 0, 0);
        //     var spawnPt = root.findFreeSpaceAround(centerPt.x + 60, centerPt.y + 60, "");
        //     root.openSearchPopupAtWorkspace(spawnPt.x, spawnPt.y, "", "");
        // }
        onDuplicateSelectedRequested: root.duplicateSelectedNodes()
        onDuplicateLinkedRequested: root.duplicateLinkedNodes()

        // Deletion
        onDeleteSelectedRequested: root.deleteSelectedNodes()
        onDeleteWithReconnectRequested: root.deleteWithReconnect()

        // Group Management
        onMakeGroupRequested: root.createGroupFromSelected()
        onUngroupRequested: root.ungroupSelectedNodes()
        onMoveToGroupRequested: root.createGroupFromSelected()

        // Wire Operations
        onInsertRerouteRequested: root.insertRerouteOnSelectedWire()
        onCutLinksRequested: root.cutSelectedNodeLinks()

        // Node Visual / State Modifiers
        onMuteSelectedRequested: root.toggleMuteSelectedNodes()
        onTogglePreviewRequested: root.togglePreviewForSelected()
        onCollapseSelectedRequested: root.collapseSelectedNodes()

        // Graph Traversal Selection
        onSelectUpstreamRequested: root.selectLinkedFrom()
        onSelectDownstreamRequested: root.selectLinkedTo()

        // Alignment & Distribution
        onAlignVerticalRequested: root.alignSelectedToAverageVertical()
        onAlignHorizontalRequested: root.alignSelectedToAverageHorizontal()
        onDistributeHorizontallyRequested: root.distributeSelectedHorizontally()
        onDistributeVerticallyRequested: root.distributeSelectedVertically()

        // Parameter Reset
        onResetNodeValuesRequested: root.clearSelectedNodeValues()
    }
}

// Rectangle {
//     id: mainTopBar
//     Layout.fillWidth: true
//     height: 38
//     color: root.bgDark
//     z: 110
//
//     RowLayout {
//         anchors.fill: parent
//         anchors.leftMargin: 10
//         anchors.rightMargin: 10
//         spacing: 6
//
//         Rectangle {
//             id: btnView
//             implicitWidth: viewLabel.implicitWidth + 20
//             implicitHeight: 26
//             radius: 5
//             color: viewMouse.containsMouse ? "#282828" : "transparent"
//             Text {
//                 id: viewLabel
//                 anchors.centerIn: parent
//                 text: "View"
//                 color: "#c4c4c4"
//                 font.pixelSize: 12
//                 font.weight: Font.Medium
//             }
//             MouseArea {
//                 id: viewMouse
//                 anchors.fill: parent
//                 hoverEnabled: true
//                 cursorShape: Qt.PointingHandCursor
//                 onClicked: {
//                     var pt = btnView.mapToItem(Overlay.overlay, 0, btnView.height + 4);
//                     viewMenu.openAt(pt.x, pt.y);
//                 }
//             }
//         }
//
//         Rectangle {
//             id: btnSelect
//             implicitWidth: selectLabel.implicitWidth + 20
//             implicitHeight: 26
//             radius: 5
//             color: selectMouse.containsMouse ? "#282828" : "transparent"
//             Text {
//                 id: selectLabel
//                 anchors.centerIn: parent
//                 text: "Select"
//                 color: "#c4c4c4"
//                 font.pixelSize: 12
//                 font.weight: Font.Medium
//             }
//             MouseArea {
//                 id: selectMouse
//                 anchors.fill: parent
//                 hoverEnabled: true
//                 cursorShape: Qt.PointingHandCursor
//                 onClicked: {
//                     var pt = btnSelect.mapToItem(Overlay.overlay, 0, btnSelect.height + 4);
//                     selectMenu.openAt(pt.x, pt.y);
//                 }
//             }
//         }
//
//         Rectangle {
//             id: btnKey
//             implicitWidth: keyLabel.implicitWidth + 20
//             implicitHeight: 26
//             radius: 5
//             color: keyMouse.containsMouse ? "#282828" : "transparent"
//             Text {
//                 id: keyLabel
//                 anchors.centerIn: parent
//                 text: "Key"
//                 color: "#c4c4c4"
//                 font.pixelSize: 12
//                 font.weight: Font.Medium
//             }
//             MouseArea {
//                 id: keyMouse
//                 anchors.fill: parent
//                 hoverEnabled: true
//                 cursorShape: Qt.PointingHandCursor
//                 onClicked: {
//                     var pt = btnKey.mapToItem(Overlay.overlay, 0, btnKey.height + 4);
//                     nodeMenu.openAt(pt.x, pt.y);
//                 }
//             }
//         }
//
//         Item {
//             Layout.fillWidth: true
//         }
//     }
// }
//
// NodeGraphBreadcrumbBar {
//     activeTimelineModel: root.activeTimelineModel
//     activeSelectedClipId: root.activeSelectedClipId
//     currentGraphId: root.currentGraphId
//
//     onGraphSelected: function (gId) {
//         root.selectGraph(gId);
//     }
// }
//
//
//

// Floating Transparent Bar: Controls pushed to RIGHT edge
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
//         // 1. Selection Mode Toggle (Box / Circle / Lasso)
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
//         Item {
//             Layout.fillWidth: true
//         } // Pushes items to the right
//
//         // 2. Wire Style Toggle (Curve vs Straight)
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
//         // 3. Active Graph Selector Dropdown
//         // =========================================================
//         // 3. Project Graphs Selector with Working Double-Click Rename
//         // =========================================================
//         Item {
//             id: graphSelectWrapper
//             Layout.preferredWidth: 175
//             Layout.preferredHeight: 30
//
//             property bool isRenaming: false
//
//             readonly property var projectGraphs: root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : []
//
//             // readonly property var graphNames: {
//             //     var names = [];
//             //     for (var i = 0; i < projectGraphs.length; ++i) {
//             //         names.push(projectGraphs[i].name + (projectGraphs[i].isDefault ? "" : ""));
//             //     }
//             //     return names;
//             // }
//             //
//             // readonly property int activeIndex: {
//             //     for (var i = 0; i < projectGraphs.length; ++i) {
//             //         if (projectGraphs[i].id === root.currentGraphId) return i;
//             //     }
//             //     return 0;
//             // }
//             //
//             // Bind directly to the reactive revision counter
//             property var allProjectGraphs: {
//                 var _ = root.graphRevision;
//                 return root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : [];
//             }
//
//             // Force a brand new array instance on every change
//             readonly property var graphNames: {
//                 var _ = root.graphRevision;
//                 var names = [];
//                 for (var i = 0; i < allProjectGraphs.length; ++i) {
//                     names.push(allProjectGraphs[i].name + (allProjectGraphs[i].isDefault ? " (Default)" : ""));
//                 }
//                 return names;
//             }
//
//             readonly property int activeIndex: {
//                 var _ = root.graphRevision;
//                 for (var i = 0; i < allProjectGraphs.length; ++i) {
//                     if (allProjectGraphs[i].id === root.currentGraphId)
//                         return i;
//                 }
//                 return 0;
//             }
//
//             // Ensure XylaSelect model is reassigned on change:
//             XylaSelect {
//                 id: graphSelector
//                 anchors.fill: parent
//                 visible: !graphSelectWrapper.isRenaming
//
//                 model: graphSelectWrapper.graphNames
//                 currentIndex: graphSelectWrapper.activeIndex
//
//                 // Refresh model explicitly whenever graphRevision changes:
//                 Connections {
//                     target: root
//                     function onGraphRevisionChanged() {
//                         graphSelector.model = graphSelectWrapper.graphNames;
//                         graphSelector.currentIndex = graphSelectWrapper.activeIndex;
//                     }
//                 }
//
//                 onActivated: function (index) {
//                     if (index >= 0 && index < graphSelectWrapper.allProjectGraphs.length) {
//                         var targetGraphId = graphSelectWrapper.allProjectGraphs[index].id;
//                         root.selectGraph(targetGraphId);
//                     }
//                 }
//             }
//
//             // Single-click opens dropdown; Double-click enters rename mode
//             MouseArea {
//                 anchors.fill: parent
//                 visible: !graphSelectWrapper.isRenaming
//                 acceptedButtons: Qt.LeftButton
//
//                 property int clickCount: 0
//                 Timer {
//                     id: clickTimer
//                     interval: 210
//                     onTriggered: {
//                         parent.clickCount = 0;
//                         if (graphSelector.popup) {
//                             if (graphSelector.popup.opened)
//                                 graphSelector.popup.close();
//                             else
//                                 graphSelector.popup.open();
//                         } else {
//                             graphSelector.open = !graphSelector.open;
//                         }
//                     }
//                 }
//
//                 onClicked: {
//                     clickCount++;
//                     if (clickCount === 1) {
//                         clickTimer.start();
//                     } else if (clickCount >= 2) {
//                         clickTimer.stop();
//                         clickCount = 0;
//                         if (root.currentGraphId !== "default_io_graph") {
//                             graphSelectWrapper.triggerRename();
//                         }
//                     }
//                 }
//             }
//
//             // Inline Rename Surface
//             Rectangle {
//                 anchors.fill: parent
//                 visible: graphSelectWrapper.isRenaming
//                 color: "#18181B"
//                 radius: 6
//                 border.color: "#2555D3"
//                 border.width: 1
//                 z: 100
//
//                 TextInput {
//                     id: renameInput
//                     anchors.fill: parent
//                     anchors.leftMargin: 8
//                     anchors.rightMargin: 8
//                     verticalAlignment: Text.AlignVCenter
//                     color: "#FFFFFF"
//                     font.pixelSize: 12
//                     selectByMouse: true
//
//                     onEditingFinished: {
//                         if (graphSelectWrapper.isRenaming) {
//                             var trimmed = text.trim();
//                             if (trimmed !== "" && root.activeTimelineModel && root.currentGraphId !== "default_io_graph") {
//                                 root.activeTimelineModel.setGraphName(root.currentGraphId, trimmed);
//                             }
//                             graphSelectWrapper.isRenaming = false;
//                         }
//                     }
//
//                     Keys.onEscapePressed: {
//                         graphSelectWrapper.isRenaming = false;
//                     }
//                 }
//             }
//
//             function triggerRename() {
//                 if (root.currentGraphId === "default_io_graph")
//                     return;
//                 renameInput.text = root.currentGraphName;
//                 isRenaming = true;
//                 renameInput.forceActiveFocus();
//                 renameInput.selectAll();
//             }
//         }
//
//         // =========================================================
//         // 4. Create New Graph (+) & Auto-Trigger Rename
//         // =========================================================
//         XylaIconButton {
//             iconSource: "qrc:/assets/icons/plus.svg"
//             tooltip: "Create New Node Graph"
//
//             onClicked: {
//                 if (!root.activeTimelineModel)
//                     return;
//                 var allG = root.activeTimelineModel.getAllProjectGraphs();
//                 var newName = "Graph " + (allG.length + 1);
//                 var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
//                 if (newGId !== "") {
//                     if (root.activeSelectedClipId !== "") {
//                         root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
//                         root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newGId);
//                     } else {
//                         root.activeTimelineModel.setStandaloneActiveGraphId(newGId);
//                     }
//                     root.notifyGraphStateChanged();
//
//                     // Immediate focus rename on the newly created graph
//                     Qt.callLater(function () {
//                         graphSelectWrapper.triggerRename();
//                     });
//                 }
//             }
//         }
//
//         // =========================================================
//         // 5. Link / Unlink Toggle (Live UI Feedback)
//         // =========================================================
//         XylaIconButton {
//             visible: root.activeSelectedClipId !== ""
//             enabled: !(root.currentGraphId === "default_io_graph" && root.isCurrentGraphAttachedToClip)
//             opacity: enabled ? 1.0 : 0.4
//
//             iconSource: root.isCurrentGraphAttachedToClip
//                 ? "qrc:/assets/icons/unlink.svg"
//                 : "qrc:/assets/icons/link.svg"
//
//             tooltip: root.isCurrentGraphAttachedToClip
//                 ? "Unlink (detach) graph from this clip"
//                 : "Link (attach) this graph to this clip"
//
//             primary: !root.isCurrentGraphAttachedToClip
//
//             onClicked: {
//                 if (!root.activeTimelineModel || root.activeSelectedClipId === "")
//                     return;
//
//                 if (root.isCurrentGraphAttachedToClip) {
//                     root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.currentGraphId);
//                 } else {
//                     root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, root.currentGraphId);
//                     root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, root.currentGraphId);
//                 }
//
//                 // Force instant UI re-evaluation on both sides
//                 root.notifyGraphStateChanged();
//             }
//         }
//
//         // =========================================================
//         // 6. Delete Graph with Auto-Select Fallback
//         // =========================================================
//         XylaIconButton {
//             enabled: root.currentGraphId !== "default_io_graph"
//             opacity: enabled ? 1.0 : 0.4
//             iconSource: "qrc:/assets/icons/trash.svg"
//             tooltip: enabled ? "Delete graph from project" : "Default cannot be deleted"
//
//             onClicked: {
//                 if (!root.activeTimelineModel || root.currentGraphId === "default_io_graph")
//                     return;
//
//                 var targetToDelete = root.currentGraphId;
//                 var allG = root.activeTimelineModel.getAllProjectGraphs();
//
//                 // Find a fallback graph ID before deletion
//                 var fallbackId = "default_io_graph";
//                 for (var i = allG.length - 1; i >= 0; --i) {
//                     if (allG[i].id !== targetToDelete) {
//                         fallbackId = allG[i].id;
//                         break;
//                     }
//                 }
//
//                 // Perform deletion in C++
//                 root.activeTimelineModel.deleteProjectGraph(targetToDelete);
//
//                 // Switch active selection to fallback graph
//                 if (root.activeSelectedClipId !== "") {
//                     root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, fallbackId);
//                 } else {
//                     root.activeTimelineModel.setStandaloneActiveGraphId(fallbackId);
//                 }
//
//                 // Trigger immediate UI refresh
//                 root.notifyGraphStateChanged();
//             }
//         }
//         // XylaSelect {
//         //     id: graphSelector
//         //     Layout.preferredWidth: 160
//         //
//         //     // If clip is selected, show graphs attached to this clip; otherwise show all project graphs!
//         //     model: {
//         //         if (!root.activeTimelineModel) return [];
//         //         var list = (root.activeSelectedClipId !== "")
//         //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
//         //             : root.activeTimelineModel.getAllProjectGraphs();
//         //
//         //         // Map to array of names for display, keeping IDs accessible
//         //         var names = [];
//         //         for (var i = 0; i < list.length; ++i) {
//         //             names.push(list[i].name + (list[i].isDefault ? " (Default)" : ""));
//         //         }
//         //         return names;
//         //     }
//         //
//         //     // Synchronize current index with root.currentGraphId
//         //     currentIndex: {
//         //         if (!root.activeTimelineModel) return 0;
//         //         var list = (root.activeSelectedClipId !== "")
//         //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
//         //             : root.activeTimelineModel.getAllProjectGraphs();
//         //         for (var i = 0; i < list.length; ++i) {
//         //             if (list[i].id === root.currentGraphId) return i;
//         //         }
//         //         return 0;
//         //     }
//         //
//         //     onActivated: function (index) {
//         //         if (!root.activeTimelineModel) return;
//         //         var list = (root.activeSelectedClipId !== "")
//         //             ? root.activeTimelineModel.getClipAttachedGraphs(root.activeSelectedClipId)
//         //             : root.activeTimelineModel.getAllProjectGraphs();
//         //
//         //         if (index >= 0 && index < list.length) {
//         //             var targetGraphId = list[index].id;
//         //             if (root.activeSelectedClipId !== "") {
//         //                 root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, targetGraphId);
//         //             } else {
//         //                 root.activeTimelineModel.setStandaloneActiveGraphId(targetGraphId);
//         //             }
//         //         }
//         //     }
//         // }
//
//         // 4. Create New Graph (+)
//         // XylaIconButton {
//         //     iconSource: "qrc:/assets/icons/plus.svg"
//         //     ToolTip.text: "Create New Node Graph"
//         //     ToolTip.visible: hovered
//         //
//         //     onClicked: {
//         //         if (!root.activeTimelineModel) return;
//         //         var allGraphs = root.activeTimelineModel.getAllProjectGraphs();
//         //         var newName = "Graph " + (allGraphs.length + 1);
//         //         var newGId = root.activeTimelineModel.createNewProjectGraph(newName);
//         //         if (newGId !== "") {
//         //             if (root.activeSelectedClipId !== "") {
//         //                 root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newGId);
//         //                 root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newGId);
//         //             } else {
//         //                 root.activeTimelineModel.setStandaloneActiveGraphId(newGId);
//         //             }
//         //         }
//         //     }
//         // }
//         //
//         // // 5. Detach / Remove Graph from Clip (Only visible when a clip is selected)
//         // XylaIconButton {
//         //     visible: root.activeSelectedClipId !== ""
//         //     enabled: root.currentGraphId !== "default_io_graph"
//         //     opacity: enabled ? 1.0 : 0.4
//         //     iconSource: "qrc:/assets/icons/unlink.svg" // or a disconnect/minus icon
//         //     ToolTip.text: "Detach this graph from the selected clip"
//         //     ToolTip.visible: hovered
//         //
//         //     onClicked: {
//         //         if (root.activeTimelineModel && root.activeSelectedClipId !== "") {
//         //             root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.currentGraphId);
//         //         }
//         //     }
//         // }
//         //
//         // // 6. Delete Graph Entirely (Trash)
//         // XylaIconButton {
//         //     enabled: root.currentGraphId !== "default_io_graph"
//         //     opacity: enabled ? 1.0 : 0.4
//         //     iconSource: "qrc:/assets/icons/trash.svg"
//         //     ToolTip.text: enabled ? "Delete graph from project" : "Default In/Out cannot be deleted"
//         //     ToolTip.visible: hovered
//         //
//         //     onClicked: {
//         //         if (root.activeTimelineModel && root.currentGraphId !== "default_io_graph") {
//         //             root.activeTimelineModel.deleteProjectGraph(root.currentGraphId);
//         //         }
//         //     }
//         // }
//     }
// }
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
