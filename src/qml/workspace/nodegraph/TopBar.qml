import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    property var root: null
    property alias graphSelectWrapper: graphSelectWrapper

    // Helper to resolve the node controller safely
    readonly property var controller: (root && root.graphEngine) ? root.graphEngine : (root && root.nodeGraphController ? root.nodeGraphController : null)

    // =====================================================================
    // 1. Top Bar Navigation & Menu Triggers
    // =====================================================================
    Rectangle {
        id: mainTopBar
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        color: root ? root.bgDark : "#1e1e1e"
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
                color: viewMouse.containsMouse ? "#282828" : (root ? root.bgDark : "#1e1e1e")

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
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
                color: selectMouse.containsMouse ? "#282828" : (root ? root.bgDark : "#1e1e1e")

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
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
                color: nodeMouse.containsMouse ? "#282828" : (root ? root.bgDark : "#1e1e1e")

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
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
                    if (!controller)
                        return;

                    var allG = (typeof controller.getAllProjectGraphs === "function") ? (controller.getAllProjectGraphs() || []) : [];
                    var userGraphCount = 0;
                    for (var i = 0; i < allG.length; ++i) {
                        if (allG[i].id !== "default_io_graph" && !allG[i].isDefault) {
                            userGraphCount++;
                        }
                    }
                    var desiredName = "Graph " + (userGraphCount + 1);

                    var newId = (typeof controller.createNewProjectGraph === "function") ? controller.createNewProjectGraph(desiredName) : "";

                    if (newId && newId !== "") {
                        if (root && root.activeSelectedClipId !== "") {
                            if (typeof controller.attachGraphToClip === "function")
                                controller.attachGraphToClip(root.activeSelectedClipId, newId);
                            if (typeof controller.setClipActiveGraphId === "function")
                                controller.setClipActiveGraphId(root.activeSelectedClipId, newId);
                        }

                        if (root && root.selectGraph) {
                            root.selectGraph(newId);
                        }

                        Qt.callLater(function () {
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
                property var userGraphs: []
                property var userGraphNames: []
                property bool _cancelGuard: false

                function refreshGraphs() {
                    if (!controller || typeof controller.getAllProjectGraphs !== "function")
                        return;

                    var all = controller.getAllProjectGraphs() || [];
                    var filtered = [];
                    var names = [];

                    for (var i = 0; i < all.length; ++i) {
                        var item = all[i];
                        var gId = (typeof item === "object") ? item.id : item;
                        var isDef = (typeof item === "object") ? (item.isDefault === true || item.isReadOnly === true || gId === "default_io_graph") : (gId === "default_io_graph");

                        if (gId !== "default_io_graph" && !isDef) {
                            filtered.push(item);
                            names.push(item.name || gId);
                        }
                    }

                    userGraphs = filtered;
                    userGraphNames = names;
                    graphSelector.model = names;

                    // Sync current index
                    var idx = -1;
                    for (var j = 0; j < filtered.length; ++j) {
                        if (filtered[j].id === (root ? root.activeGraphId : "")) {
                            idx = j;
                            break;
                        }
                    }
                    graphSelector.currentIndex = idx;
                }

                Component.onCompleted: {
                    refreshGraphs();
                    if (root && root.activeGraphId && root.activeGraphId !== "") {
                        root.selectGraph(root.activeGraphId);
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
                            if (root && root.selectGraph)
                                root.selectGraph(chosen.id);
                        }
                    }
                }

                // Single Click = Dropdown, Double Click = Rename
                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (!graphSelector || !graphSelector.popup)
                            return;
                        if (graphSelector.popup.opened || graphSelector.popup.visible) {
                            graphSelector.popup.close();
                        } else {
                            graphSelector.popup.open();
                        }
                    }

                    onDoubleClicked: {
                        if (graphSelector.popup)
                            graphSelector.popup.close();
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

                        onActiveFocusChanged: {
                            if (!activeFocus && graphSelectWrapper.isRenaming) {
                                graphSelectWrapper._cancelGuard = true;
                                graphSelectWrapper.isRenaming = false;
                            }
                        }

                        function commit() {
                            if (!graphSelectWrapper.isRenaming || !controller)
                                return;

                            var trimmed = text.trim();
                            if (trimmed !== "" && root && !root.isCurrentGraphReadOnly) {
                                var existingNames = [];
                                var all = (typeof controller.getAllProjectGraphs === "function") ? (controller.getAllProjectGraphs() || []) : [];

                                for (var i = 0; i < all.length; ++i) {
                                    if (all[i].id !== root.activeGraphId) {
                                        existingNames.push(all[i].name);
                                    }
                                }

                                var finalName = trimmed;
                                var counter = 1;
                                while (existingNames.indexOf(finalName) !== -1) {
                                    finalName = trimmed + " (" + counter + ")";
                                    counter++;
                                }

                                if (typeof controller.setGraphName === "function") {
                                    controller.setGraphName(root.activeGraphId, finalName);
                                }
                                graphSelectWrapper.refreshGraphs();
                            }
                            graphSelectWrapper.isRenaming = false;
                        }

                        Keys.onReturnPressed: function (event) {
                            commit();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: function (event) {
                            commit();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function (event) {
                            graphSelectWrapper.isRenaming = false;
                            event.accepted = true;
                        }
                    }
                }

                function triggerRename(targetId, initialName) {
                    if (targetId === "default_io_graph" || (root && root.isCurrentGraphReadOnly))
                        return;
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
                    if (graphSelectWrapper._cancelGuard) {
                        Qt.callLater(function () {
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
            // LINK / UNLINK BUTTON
            // -----------------------------------------------------------------
            XylaIconButton {
                visible: root ? root.activeSelectedClipId !== "" : false
                enabled: root ? !root.isCurrentGraphReadOnly : false
                opacity: enabled ? 1.0 : 0.4

                iconSource: root && root.isCurrentGraphLinked ? "qrc:/assets/icons/unlink.svg" : "qrc:/assets/icons/link.svg"

                tooltip: root && root.isCurrentGraphLinked ? "Unlink (detach) graph from clip" : "Link (attach) graph to clip"

                primary: root ? !root.isCurrentGraphLinked : true

                onClicked: {
                    if (!root || !controller || root.activeSelectedClipId === "" || root.isCurrentGraphReadOnly)
                        return;

                    if (root.isCurrentGraphLinked) {
                        if (typeof controller.detachGraphFromClip === "function") {
                            controller.detachGraphFromClip(root.activeSelectedClipId, root.activeGraphId);
                        }
                        root.isCurrentGraphLinked = false;
                    } else {
                        if (typeof controller.attachGraphToClip === "function") {
                            controller.attachGraphToClip(root.activeSelectedClipId, root.activeGraphId);
                        }
                        if (typeof controller.setClipActiveGraphId === "function") {
                            controller.setClipActiveGraphId(root.activeSelectedClipId, root.activeGraphId);
                        }
                        root.isCurrentGraphLinked = true;
                    }
                }
            }

            // -----------------------------------------------------------------
            // DELETE GRAPH BUTTON
            // -----------------------------------------------------------------
            XylaIconButton {
                enabled: root ? (!root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) : false
                opacity: enabled ? 1.0 : 0.4
                iconColor: "#CA1010"
                iconSource: "qrc:/assets/icons/trash.svg"
                tooltip: enabled ? "Delete graph from project" : "Default graph cannot be deleted"

                onClicked: {
                    if (!root || !controller || root.isCurrentGraphReadOnly)
                        return;

                    var idToDelete = root.activeGraphId;
                    var list = graphSelectWrapper.userGraphs;

                    var curIdx = -1;
                    for (var i = 0; i < list.length; ++i) {
                        if (list[i].id === idToDelete) {
                            curIdx = i;
                            break;
                        }
                    }

                    var fallbackId = "default_io_graph";
                    if (list.length > 1) {
                        var nextIdx = (curIdx === list.length - 1) ? (curIdx - 1) : (curIdx + 1);
                        fallbackId = list[nextIdx].id;
                    }

                    if (typeof controller.deleteProjectGraph === "function") {
                        controller.deleteProjectGraph(idToDelete);
                    } else if (typeof controller.removeGraph === "function") {
                        controller.removeGraph(idToDelete);
                    }

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
        activeTimelineModel: root ? root.activeTimelineModel : null
        activeSelectedClipId: root ? root.activeSelectedClipId : ""
        currentGraphId: root ? root.currentGraphId : ""

        onGraphSelected: function (gId) {
            if (root && root.selectGraph)
                root.selectGraph(gId);
        }

        onReorderClipGraphsRequested: function (cId, orderedIds) {
            if (controller && typeof controller.reorderClipGraphs === "function") {
                controller.reorderClipGraphs(cId, orderedIds);
            }
        }
    }

    // =====================================================================
    // 3. Popup Menu Instances
    // =====================================================================
    ViewMenuPopup {
        id: viewMenu
        showGrid: root ? root.showGrid : false
        isSnappingEnabled: root ? root.isSnappingEnabled : false
        showWireColors: root ? root.showWireColors : false
        showMinimap: root ? root.showMinimap : false

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
        selectedNodeIds: root ? root.selectedNodeIds : []

        onSelectAllRequested: root.selectAllNodes()
        onDeselectAllRequested: root.deselectAllNodes()
        onInvertSelectionRequested: root.invertNodeSelection()
        onSelectLinkedFromRequested: root.selectLinkedFrom()
        onSelectLinkedToRequested: root.selectLinkedTo()
    }

    NodeMenuPopup {
        id: nodeMenu
        selectedNodeIds: root ? root.selectedNodeIds : []
        currentGraphId: root ? root.currentGraphId : ""

        onAddNodeRequested: {
            var wsX = (currentMouseScreenX - canvasContainer.width / 2 - root.panX) / root.zoomLevel;
            var wsY = (currentMouseScreenY - canvasContainer.height / 2 - root.panY) / root.zoomLevel;
            root.openSearchPopupAtWorkspace(wsX, wsY, "", "");
        }
        onDuplicateSelectedRequested: root.duplicateSelectedNodes()
        onDuplicateLinkedRequested: root.duplicateLinkedNodes()
        onDeleteSelectedRequested: root.deleteSelectedNodes()
        onDeleteWithReconnectRequested: root.deleteWithReconnect()
        onMakeGroupRequested: root.createGroupFromSelected()
        onUngroupRequested: root.ungroupSelectedNodes()
        onMoveToGroupRequested: root.createGroupFromSelected()
        onInsertRerouteRequested: root.insertRerouteOnSelectedWire()
        onCutLinksRequested: root.cutSelectedNodeLinks()
        onMuteSelectedRequested: root.toggleMuteSelectedNodes()
        onTogglePreviewRequested: root.togglePreviewForSelected()
        onCollapseSelectedRequested: root.collapseSelectedNodes()
        onSelectUpstreamRequested: root.selectLinkedFrom()
        onSelectDownstreamRequested: root.selectLinkedTo()
        onAlignVerticalRequested: root.alignSelectedToAverageVertical()
        onAlignHorizontalRequested: root.alignSelectedToAverageHorizontal()
        onDistributeHorizontallyRequested: root.distributeSelectedHorizontally()
        onDistributeVerticallyRequested: root.distributeSelectedVertically()
        onResetNodeValuesRequested: root.clearSelectedNodeValues()
    }
}
