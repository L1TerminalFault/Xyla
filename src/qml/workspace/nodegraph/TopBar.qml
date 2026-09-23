import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: topBarRoot
    Layout.fillWidth: true
    spacing: 0

    property var root: null

    onRootChanged: {
        if (root) {
            graphSelectWrapper.refresh();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        color: root ? root.bgDark : "#18181B"
        z: 100

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Rectangle {
                id: btnView
                implicitWidth: viewLabel.implicitWidth + 20
                implicitHeight: 28
                radius: 6
                color: viewMouse.containsMouse ? "#27272A" : "transparent"

                Text {
                    id: viewLabel
                    anchors.centerIn: parent
                    text: qsTr("View")
                    color: "#E4E4E7"
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
                implicitHeight: 28
                radius: 6
                color: selectMouse.containsMouse ? "#27272A" : "transparent"

                Text {
                    id: selectLabel
                    anchors.centerIn: parent
                    text: qsTr("Select")
                    color: "#E4E4E7"
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
                id: btnNode
                implicitWidth: nodeLabel.implicitWidth + 20
                implicitHeight: 28
                radius: 6
                color: nodeMouse.containsMouse ? "#27272A" : "transparent"

                Text {
                    id: nodeLabel
                    anchors.centerIn: parent
                    text: qsTr("Node")
                    color: "#E4E4E7"
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

            XylaIconButton {
                iconSource: "qrc:/assets/icons/plus.svg"
                tooltip: qsTr("Create New Graph")
                primary: true

                onClicked: {
                    if (typeof nodeGraphController === "undefined" || !nodeGraphController)
                        return;

                    var allGraphs = nodeGraphController.getAllProjectGraphs() || [];
                    var name = "Graph " + allGraphs.length;

                    var newId = nodeGraphController.createNewProjectGraph(name);
                    if (newId && newId !== "") {
                        if (root && root.activeSelectedClipId && root.activeSelectedClipId !== "") {
                            nodeGraphController.attachGraphToClip(root.activeSelectedClipId, newId);
                            nodeGraphController.setClipActiveGraphId(root.activeSelectedClipId, newId);
                        }
                        if (root && root.selectGraph) {
                            root.selectGraph(newId);
                        }
                        graphSelectWrapper.refresh();
                    }
                }
            }

            Item {
                id: graphSelectWrapper
                Layout.preferredWidth: 200
                Layout.preferredHeight: 30

                property bool isRenaming: false
                property var graphItems: []
                property var graphNames: []

                function refresh() {
                    if (typeof nodeGraphController === "undefined" || !nodeGraphController)
                        return;

                    var all = nodeGraphController.getAllProjectGraphs() || [];
                    var names = [];
                    for (var i = 0; i < all.length; ++i) {
                        names.push(all[i].name || all[i].id);
                    }

                    graphItems = all;
                    graphNames = names;
                    graphCombo.model = names;

                    var currentId = root ? (root.activeGraphId || root.currentGraphId || "") : "";
                    for (var j = 0; j < all.length; ++j) {
                        if (all[j].id === currentId) {
                            graphCombo.currentIndex = j;
                            return;
                        }
                    }
                    graphCombo.currentIndex = 0;
                }

                Connections {
                    target: (typeof nodeGraphController !== "undefined") ? nodeGraphController : null
                    function onProjectGraphsChanged() {
                        graphSelectWrapper.refresh();
                    }
                    function onActiveGraphChanged() {
                        graphSelectWrapper.refresh();
                    }
                }

                Connections {
                    target: root ? root : null
                    function onActiveGraphIdChanged() {
                        graphSelectWrapper.refresh();
                    }
                    function onActiveSelectedClipIdChanged() {
                        graphSelectWrapper.refresh();
                    }
                }

                Component.onCompleted: refresh()

                XylaSelect {
                    id: graphCombo
                    anchors.fill: parent
                    visible: !graphSelectWrapper.isRenaming
                    model: graphSelectWrapper.graphNames

                    onActivated: function (index) {
                        if (index < 0 || index >= graphSelectWrapper.graphItems.length)
                            return;
                        var selectedGraph = graphSelectWrapper.graphItems[index];

                        if (root && root.activeSelectedClipId && root.activeSelectedClipId !== "") {
                            nodeGraphController.attachGraphToClip(root.activeSelectedClipId, selectedGraph.id);
                            nodeGraphController.setClipActiveGraphId(root.activeSelectedClipId, selectedGraph.id);
                        }

                        if (root && root.selectGraph) {
                            root.selectGraph(selectedGraph.id);
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: graphSelectWrapper.isRenaming
                    color: "#27272A"
                    radius: 6
                    border.color: "#3B82F6"
                    border.width: 1

                    TextInput {
                        id: renameInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        selectByMouse: true

                        function commit() {
                            if (!graphSelectWrapper.isRenaming || typeof nodeGraphController === "undefined")
                                return;
                            var trimmed = text.trim();
                            if (trimmed !== "" && root && !root.isCurrentGraphReadOnly) {
                                nodeGraphController.setGraphName(root.activeGraphId, trimmed);
                            }
                            graphSelectWrapper.isRenaming = false;
                        }

                        Keys.onReturnPressed: commit()
                        Keys.onEnterPressed: commit()
                        Keys.onEscapePressed: graphSelectWrapper.isRenaming = false
                    }
                }

                function startRename() {
                    if (!root || root.isCurrentGraphReadOnly)
                        return;
                    renameInput.text = root.currentGraphName || "";
                    isRenaming = true;
                    renameInput.forceActiveFocus();
                    renameInput.selectAll();
                }
            }

            XylaIconButton {
                iconSource: "qrc:/assets/icons/pen.svg"
                tooltip: qsTr("Rename Graph")
                enabled: root && !root.isCurrentGraphReadOnly

                onClicked: graphSelectWrapper.startRename()
            }

            XylaIconButton {
                iconSource: "qrc:/assets/icons/trash.svg"
                iconColor: "#EF4444"
                tooltip: qsTr("Delete Graph")
                enabled: root && !root.isCurrentGraphReadOnly

                onClicked: {
                    if (!root || typeof nodeGraphController === "undefined" || root.isCurrentGraphReadOnly)
                        return;

                    var targetId = root.activeGraphId;
                    nodeGraphController.deleteProjectGraph(targetId);

                    if (root.selectGraph) {
                        root.selectGraph("default_io_graph");
                    }
                    graphSelectWrapper.refresh();
                }
            }
        }
    }

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
        onToggleWireColorsRequested: root.showWireColors = !root.showWireColors
        onToggleMinimapRequested: root.showMinimap = !root.showMinimap
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
