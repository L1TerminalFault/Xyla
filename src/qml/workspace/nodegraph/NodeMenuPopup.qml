import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: nodeMenu
    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 8
    transformOrigin: Item.TopLeft

    // =====================================================================
    // State Input Properties (Dependencies from parent)
    // =====================================================================
    property var selectedNodeIds: []
    property string currentGraphId: ""

    // =====================================================================
    // Pure Action Signals (No internal business logic or root calls)
    // =====================================================================
    signal addNodeRequested()
    signal duplicateSelectedRequested()
    signal duplicateLinkedRequested()
    signal deleteSelectedRequested()
    signal deleteWithReconnectRequested()
    signal makeGroupRequested()
    signal ungroupRequested()
    signal moveToGroupRequested()
    signal insertRerouteRequested()
    signal cutLinksRequested()
    signal muteSelectedRequested()
    signal togglePreviewRequested()
    signal collapseSelectedRequested()
    signal selectUpstreamRequested()
    signal selectDownstreamRequested()
    signal alignVerticalRequested()
    signal alignHorizontalRequested()
    signal distributeHorizontallyRequested()
    signal distributeVerticallyRequested()
    signal resetNodeValuesRequested()

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
                nodeMenu.close();
                nodeMenu.addNodeRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/copy.svg"
            text: "Duplicate"
            shortcut: "Ctrl+D"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.duplicateSelectedRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/link.svg"
            text: "Duplicate Linked"
            shortcut: "Alt+D"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.duplicateLinkedRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Delete"
            destructive: true
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.deleteSelectedRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/vector-triangle.svg"
            text: "Delete with Reconnect (Dissolve)"
            shortcut: "Ctrl+X"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.deleteWithReconnectRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/folder-plus.svg"
            text: "Make Group"
            shortcut: "Ctrl+G"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.makeGroupRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/folder-minus.svg"
            text: "Ungroup"
            shortcut: "Ctrl+Alt+G"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.ungroupRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/folder-arrow-right.svg"
            text: "Move to Node Group..."
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.moveToGroupRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/point.svg"
            text: "Insert Reroute"
            onClicked: {
                nodeMenu.close();
                nodeMenu.insertRerouteRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/scissors.svg"
            text: "Cut Links (Scissor)"
            shortcut: "Ctrl+Alt+X"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.cutLinksRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/eye-off.svg"
            text: "Mute / Bypass"
            shortcut: "M"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.muteSelectedRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/monitor.svg"
            text: "Toggle Viewer"
            shortcut: "V"
            enabled_: nodeMenu.selectedNodeIds.length === 1
            onClicked: {
                nodeMenu.close();
                nodeMenu.togglePreviewRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/arrow-left-circle.svg"
            text: "Select Upstream Nodes"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.selectUpstreamRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/arrow-right-circle.svg"
            text: "Select Downstream Nodes"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.selectDownstreamRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/align-left.svg"
            text: "Align Nodes Vertically"
            enabled_: nodeMenu.selectedNodeIds.length >= 2
            onClicked: {
                nodeMenu.close();
                nodeMenu.alignVerticalRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/align-left.svg"
            text: "Align Nodes Horizontal"
            enabled_: nodeMenu.selectedNodeIds.length >= 2
            onClicked: {
                nodeMenu.close();
                nodeMenu.alignHorizontalRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/distribute-horizontal.svg"
            text: "Distribute Nodes Horizontally"
            enabled_: nodeMenu.selectedNodeIds.length >= 3
            onClicked: {
                nodeMenu.close();
                nodeMenu.distributeHorizontallyRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/distribute-vertical.svg"
            text: "Distribute Nodes Vertically"
            enabled_: nodeMenu.selectedNodeIds.length >= 3
            onClicked: {
                nodeMenu.close();
                nodeMenu.distributeVerticallyRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/refresh.svg"
            text: "Reset Node Values"
            enabled_: nodeMenu.selectedNodeIds.length > 0
            onClicked: {
                nodeMenu.close();
                nodeMenu.resetNodeValuesRequested();
            }
        }
    }

    property real requestedX: 0
    property real requestedY: 0

    function reposition() {
        if (!Overlay.overlay)
            return;
        x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
        y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
    }

    onAboutToShow: reposition()
    onImplicitWidthChanged: if (visible) reposition()
    onImplicitHeightChanged: if (visible) reposition()

    function openAt(sx, sy) {
        requestedX = sx;
        requestedY = sy;
        reposition();
        open();
    }
}


    // Popup {
    //     id: nodeMenu
    //     parent: Overlay.overlay
    //     modal: false
    //     focus: true
    //     closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    //     padding: 8
    //     transformOrigin: Item.TopLeft
    //     property real requestedX: 0
    //     property real requestedY: 0
    //
    //     function reposition() {
    //         if (!Overlay.overlay)
    //             return;
    //         x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
    //         y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
    //     }
    //
    //     onAboutToShow: reposition()
    //     onImplicitWidthChanged: if (visible)
    //         reposition()
    //     onImplicitHeightChanged: if (visible)
    //         reposition()
    //
    //     function openAt(sx, sy) {
    //         requestedX = sx;
    //         requestedY = sy;
    //         reposition();
    //         open();
    //     }
    //
    //     background: Rectangle {
    //         color: "#181818"
    //         border.color: "#303030"
    //         border.width: 1
    //         radius: 12
    //         layer.enabled: true
    //         layer.effect: MultiEffect {
    //             shadowEnabled: true
    //             shadowColor: "#90000000"
    //             shadowBlur: 0.65
    //             shadowVerticalOffset: 6
    //         }
    //     }
    //
    //     enter: Transition {
    //         NumberAnimation {
    //             property: "opacity"
    //             from: 0.0
    //             to: 1.0
    //             duration: 150
    //             easing.type: Easing.OutCubic
    //         }
    //         NumberAnimation {
    //             property: "scale"
    //             from: 0.95
    //             to: 1.0
    //             duration: 180
    //             easing.type: Easing.OutCubic
    //         }
    //     }
    //
    //     exit: Transition {
    //         NumberAnimation {
    //             property: "opacity"
    //             from: 1.0
    //             to: 0.0
    //             duration: 120
    //             easing.type: Easing.OutCubic
    //         }
    //         NumberAnimation {
    //             property: "scale"
    //             from: 1.0
    //             to: 0.95
    //             duration: 120
    //             easing.type: Easing.OutCubic
    //         }
    //     }
    //
    //     contentItem: ColumnLayout {
    //         width: 240
    //         spacing: 2
    //
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/plus.svg"
    //             text: "Add Node..."
    //             shortcut: "Shift+A"
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.openSearchPopupAtWorkspace(0, 0, "", "");
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/copy.svg"
    //             text: "Duplicate"
    //             shortcut: "Ctrl+D"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.duplicateSelectedNodes();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/link.svg"
    //             text: "Duplicate Linked"
    //             shortcut: "Alt+D"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.duplicateSelectedNodes();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/trash.svg"
    //             text: "Delete" // ; shortcut: "Del"
    //             destructive: true
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.deleteSelectedNodes();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/vector-triangle.svg"
    //             text: "Delete with Reconnect (Dissolve)"
    //             shortcut: "Ctrl+X"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.deleteWithReconnect();
    //             }
    //         }
    //
    //         ContextSeparator {}
    //
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/player-pause.svg"; text: "Mute / Bypass Node"; shortcut: "M"
    //         //     enabled_: root.selectedNodeIds.length > 0
    //         //     onClicked: { nodeMenu.close(); root.toggleMuteSelectedNodes(); }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/distribute-vertical.svg"; text: "Toggle Hide / Collapse Sockets"; shortcut: "Ctrl+H"
    //         //     enabled_: root.selectedNodeIds.length > 0
    //         //     onClicked: { nodeMenu.close(); root.toggleAllNodeCollapse(!root.nodeList[0].isCollapsed); }
    //         // }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/folder-plus.svg"
    //             text: "Make Group"
    //             shortcut: "Ctrl+G"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 if (root.activeTimelineModel && root.activeTimelineModel.groupSelectedNodes) {
    //                     root.activeTimelineModel.groupSelectedNodes(root.currentGraphId, root.selectedNodeIds);
    //                 }
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/folder-minus.svg"
    //             text: "Ungroup"
    //             shortcut: "Ctrl+Alt+G"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //             }
    //         }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/user-x.svg"; text: "Make Single-User (Unlink Data-Block)"
    //         //     enabled_: root.selectedNodeIds.length > 0
    //         //     onClicked: { nodeMenu.close(); }
    //         // }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/point.svg"
    //             text: "Insert Reroute" // ; shortcut: "Shift+RightClick"
    //             onClicked: {
    //                 nodeMenu.close();
    //                 graphWorkspace.insertRerouteOnLink();
    //             }
    //         }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/plug-connected.svg"; text: "Connect Selected to Active" // ; shortcut: "F"
    //         //     enabled_: root.selectedNodeIds.length >= 2
    //         //     onClicked: { nodeMenu.close(); root.connectSelectedToActive(); }
    //         // }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/scissors.svg"
    //             text: "Cut Links (Scissor)"
    //             shortcut: "Ctrl+Alt+X"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.cutSelectedNodeLinks();
    //             }
    //         }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/switch-horizontal.svg"; text: "Swap Links / Sockets"; shortcut: "Alt+S"
    //         //     enabled_: root.selectedNodeIds.length === 2
    //         //     onClicked: { nodeMenu.close(); root.swapSelectedLinks(); }
    //         // }
    //
    //         ContextSeparator {}
    //
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/align-left.svg"
    //             text: "Align Nodes Vertically"
    //             enabled_: root.selectedNodeIds.length >= 2
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.alignSelectedToAverageVertical();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/align-left.svg"
    //             text: "Align Nodes Horizontal"
    //             enabled_: root.selectedNodeIds.length >= 2
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.alignSelectedToAverageHorizontal();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/distribute-horizontal.svg"
    //             text: "Distribute Nodes Horizontally"
    //             enabled_: root.selectedNodeIds.length >= 3
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.distributeSelectedHorizontally();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/distribute-vertical.svg"
    //             text: "Distribute Nodes Vertically"
    //             enabled_: root.selectedNodeIds.length >= 3
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.distributeSelectedVertically();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/refresh.svg"
    //             text: "Reset Node Values" // ; shortcut: "Backspace"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 nodeMenu.close();
    //                 root.clearSelectedNodeValues();
    //             }
    //         }
    //     }
    // }
