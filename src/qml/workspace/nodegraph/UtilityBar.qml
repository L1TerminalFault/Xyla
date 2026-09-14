import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: graphUtilityBar

    // --- Required External Properties & Usage Lines ---
    // Usage line when calling: root: root
    property var root: null
    // property alias graphSelectWrapper: graphSelectWrapper

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
        spacing: 8

        // Segmented Toggles (Selection & Wire Style)
        XylaSegmentedToggle {
            id: selectionModeToggle
            options: [
                { icon: "qrc:/assets/icons/square.svg", value: "box" },
                { icon: "qrc:/assets/icons/circle.svg", value: "circle" },
                { icon: "qrc:/assets/icons/lasso.svg", value: "lasso" }
            ]
            currentIndex: root && root.selectionMode === "box" ? 0 : root && root.selectionMode === "circle" ? 1 : 2
            onOptionSelected: (index, value) => { if (root) root.selectionMode = value; }
        }

        Item { Layout.fillWidth: true }

        XylaSegmentedToggle {
            id: wireStyleToggle
            options: [
                { icon: "qrc:/assets/icons/curve.svg", value: "curve" },
                { icon: "qrc:/assets/icons/line.svg", value: "straight" }
            ]
            currentIndex: root && root.wireStyle === "curve" ? 0 : 1
            onOptionSelected: (index, value) => { if (root) root.wireStyle = value; }
        }

        // // -----------------------------------------------------------------
        // // XYLA SELECT (NO DEFAULT GRAPH, INLINE RENAME, AUTO-SYNC ON DELETE)
        // // -----------------------------------------------------------------
        // Item {
        //     id: graphSelectWrapper
        //     Layout.preferredWidth: 175
        //     Layout.preferredHeight: 30
        //
        //     property bool isRenaming: false
        //     property var userGraphs: [] // ONLY user editable graphs (NO default_io_graph)
        //     property var userGraphNames: []
        //
        //     function refreshGraphs() {
        //         if (!root || !root.activeTimelineModel) return;
        //         var all = root.activeTimelineModel.getAllProjectGraphs();
        //         var filtered = [];
        //         var names = [];
        //
        //         for (var i = 0; i < all.length; ++i) {
        //             // FILTER OUT DEFAULT GRAPH COMPLETELY
        //             if (all[i].id !== "default_io_graph" && !all[i].isDefault) {
        //                 filtered.push(all[i]);
        //                 names.push(all[i].name);
        //             }
        //         }
        //
        //         userGraphs = filtered;
        //         userGraphNames = names;
        //         graphSelector.model = names;
        //
        //         // Sync current index
        //         var idx = -1;
        //         for (var j = 0; j < filtered.length; ++j) {
        //             if (filtered[j].id === root.activeGraphId) {
        //                 idx = j;
        //                 break;
        //             }
        //         }
        //         graphSelector.currentIndex = idx;
        //     }
        //
        //     Component.onCompleted: {
        //         refreshGraphs()
        //         // Force evaluation on first load
        //         if (root) {
        //             var targetId = root.activeGraphId;
        //             if (targetId && targetId !== "") {
        //                 root.selectGraph(targetId);
        //             }
        //         }
        //     }
        //
        //     // Normal Dropdown Mode
        //     XylaSelect {
        //         id: graphSelector
        //         anchors.fill: parent
        //         visible: !graphSelectWrapper.isRenaming
        //         model: graphSelectWrapper.userGraphNames
        //
        //         onActivated: function (index) {
        //             if (index >= 0 && index < graphSelectWrapper.userGraphs.length) {
        //                 var chosen = graphSelectWrapper.userGraphs[index];
        //                 if (root) root.selectGraph(chosen.id);
        //             }
        //         }
        //     }
        //
        //     // Single Click = Dropdown, Double Click = Rename (BLOCKED on Default)
        //     MouseArea {
        //         anchors.fill: parent
        //         visible: !graphSelectWrapper.isRenaming
        //         acceptedButtons: Qt.LeftButton
        //
        //         property int clickCount: 0
        //         Timer {
        //             id: clickTimer
        //             interval: 250
        //             onTriggered: {
        //                 parent.clickCount = 0;
        //                 if (graphSelector.popup) graphSelector.popup.open();
        //                 else if (graphSelector.open) graphSelector.open();
        //             }
        //         }
        //
        //         onClicked: {
        //             clickCount++;
        //             if (clickCount === 1) {
        //                 clickTimer.start();
        //             } else if (clickCount >= 2) {
        //                 clickTimer.stop();
        //                 clickCount = 0;
        //                 // BLOCK RENAME IF DEFAULT GRAPH OR NO USER GRAPHS
        //                 if (root && !root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) {
        //                     graphSelectWrapper.triggerRename(root.activeGraphId, root.currentGraphName);
        //                 }
        //             }
        //         }
        //     }
        //
        //     // Inline Rename Box
        //     Rectangle {
        //         anchors.fill: parent
        //         visible: graphSelectWrapper.isRenaming
        //         color: "#18181B"
        //         radius: 6
        //         border.color: "#2555D3"
        //         border.width: 1
        //         z: 100
        //
        //         TextInput {
        //             id: renameInput
        //             anchors.fill: parent
        //             anchors.leftMargin: 8
        //             anchors.rightMargin: 8
        //             verticalAlignment: Text.AlignVCenter
        //             color: "#FFFFFF"
        //             font.pixelSize: 12
        //             selectByMouse: true
        //
        //             onEditingFinished: {
        //                 if (graphSelectWrapper.isRenaming) {
        //                     var trimmed = text.trim();
        //                     if (trimmed !== "" && root && root.activeTimelineModel && !root.isCurrentGraphReadOnly) {
        //                         // 1. Gather all existing graph names except the one currently being renamed
        //                         var existingNames = [];
        //                         var all = root.activeTimelineModel.getAllProjectGraphs();
        //                         for (var i = 0; i < all.length; ++i) {
        //                             if (all[i].id !== root.activeGraphId) {
        //                                 existingNames.push(all[i].name);
        //                             }
        //                         }
        //
        //                         // 2. Resolve collisions -> "Name (1)", "Name (2)", etc.
        //                         var finalName = trimmed;
        //                         var counter = 1;
        //                         while (existingNames.indexOf(finalName) !== -1) {
        //                             finalName = trimmed + " (" + counter + ")";
        //                             counter++;
        //                         }
        //
        //                         // 3. Commit unique name
        //                         root.activeTimelineModel.setGraphName(root.activeGraphId, finalName);
        //                         graphSelectWrapper.refreshGraphs();
        //                     }
        //                     graphSelectWrapper.isRenaming = false;
        //                 }
        //             }
        //
        //             Keys.onEscapePressed: {
        //                 graphSelectWrapper.isRenaming = false;
        //             }
        //         }
        //     }
        //
        //     function triggerRename(targetId, initialName) {
        //         if (targetId === "default_io_graph" || (root && root.isCurrentGraphReadOnly)) return;
        //         renameInput.text = initialName;
        //         isRenaming = true;
        //         renameInput.forceActiveFocus();
        //         renameInput.selectAll();
        //     }
        // }
        //
        // // -----------------------------------------------------------------
        // // CREATE NEW GRAPH BUTTON (+)
        // // -----------------------------------------------------------------
        // XylaIconButton {
        //     iconSource: "qrc:/assets/icons/plus.svg"
        //     tooltip: "Create New Node Graph"
        //
        //     onClicked: {
        //         if (!root || !root.activeTimelineModel) return;
        //         // Count existing user graphs for clear numbering
        //         var allG = root.activeTimelineModel ? root.activeTimelineModel.getAllProjectGraphs() : [];
        //         var userGraphCount = 0;
        //         for (var i = 0; i < allG.length; ++i) {
        //             if (allG[i].id !== "default_io_graph" && !allG[i].isDefault) {
        //                 userGraphCount++;
        //             }
        //         }
        //         var desiredName = "Graph " + (userGraphCount + 1);
        //
        //         var newId = root.activeTimelineModel.createNewProjectGraph(desiredName);
        //         if (newId && newId !== "") {
        //             // If clip selected, auto-bind
        //             if (root.activeSelectedClipId !== "") {
        //                 root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, newId);
        //                 root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, newId);
        //             }
        //
        //             // Select the new graph immediately
        //             root.selectGraph(newId);
        //
        //             // Trigger rename with the EXACT newly assigned name
        //             Qt.callLater(function() {
        //                 graphSelectWrapper.triggerRename(newId, desiredName);
        //             });
        //         }
        //     }
        // }
        //
        // // -----------------------------------------------------------------
        // // LINK / UNLINK BUTTON (INSTANT UI REACTION)
        // // -----------------------------------------------------------------
        // XylaIconButton {
        //     visible: root ? root.activeSelectedClipId !== "" : false
        //     enabled: root ? !root.isCurrentGraphReadOnly : false
        //     opacity: enabled ? 1.0 : 0.4
        //
        //     iconSource: root && root.isCurrentGraphLinked 
        //         ? "qrc:/assets/icons/unlink.svg" 
        //         : "qrc:/assets/icons/link.svg"
        //
        //     tooltip: root && root.isCurrentGraphLinked 
        //         ? "Unlink (detach) graph from clip" 
        //         : "Link (attach) graph to clip"
        //
        //     primary: root ? !root.isCurrentGraphLinked : true
        //
        //     onClicked: {
        //         if (!root || !root.activeTimelineModel || root.activeSelectedClipId === "" || root.isCurrentGraphReadOnly)
        //             return;
        //
        //         if (root.isCurrentGraphLinked) {
        //             root.activeTimelineModel.detachGraphFromClip(root.activeSelectedClipId, root.activeGraphId);
        //             root.isCurrentGraphLinked = false;
        //         } else {
        //             root.activeTimelineModel.attachGraphToClip(root.activeSelectedClipId, root.activeGraphId);
        //             root.activeTimelineModel.setClipActiveGraphId(root.activeSelectedClipId, root.activeGraphId);
        //             root.isCurrentGraphLinked = true;
        //         }
        //     }
        // }
        //
        // // -----------------------------------------------------------------
        // // DELETE GRAPH BUTTON (AUTO-SELECTS NEXT REMAINING GRAPH)
        // // -----------------------------------------------------------------
        // XylaIconButton {
        //     enabled: root ? (!root.isCurrentGraphReadOnly && graphSelectWrapper.userGraphs.length > 0) : false
        //     opacity: enabled ? 1.0 : 0.4
        //     iconColor: "#CA1010"
        //     iconSource: "qrc:/assets/icons/trash.svg"
        //     tooltip: enabled ? "Delete graph from project" : "Default graph cannot be deleted"
        //
        //     onClicked: {
        //         if (!root || !root.activeTimelineModel || root.isCurrentGraphReadOnly) return;
        //
        //         var idToDelete = root.activeGraphId;
        //         var list = graphSelectWrapper.userGraphs;
        //
        //         // 1. Find index of graph being deleted
        //         var curIdx = -1;
        //         for (var i = 0; i < list.length; ++i) {
        //             if (list[i].id === idToDelete) {
        //                 curIdx = i;
        //                 break;
        //             }
        //         }
        //
        //         // 2. Pick next fallback graph from remaining items, or default_io_graph
        //         var fallbackId = "default_io_graph";
        //         if (list.length > 1) {
        //             // If we are deleting the last item, pick the one before it; otherwise pick the next one
        //             var nextIdx = (curIdx === list.length - 1) ? (curIdx - 1) : (curIdx + 1);
        //             fallbackId = list[nextIdx].id;
        //         }
        //
        //         // 3. Delete in C++
        //         root.activeTimelineModel.deleteProjectGraph(idToDelete);
        //
        //         // 4. Switch active graph to fallback and update XylaSelect index
        //         root.selectGraph(fallbackId);
        //     }
        // }
    }
}
