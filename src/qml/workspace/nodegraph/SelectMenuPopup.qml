import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: selectMenu
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

    // =====================================================================
    // Pure Action Signals (No internal business logic or root calls)
    // =====================================================================
    signal selectAllRequested()
    signal deselectAllRequested()
    signal invertSelectionRequested()
    signal selectLinkedFromRequested()
    signal selectLinkedToRequested()

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
                selectMenu.selectAllRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/square-x.svg"
            text: "Deselect All"
            shortcut: "Alt+A"
            onClicked: {
                selectMenu.close();
                selectMenu.deselectAllRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/switch.svg"
            text: "Invert Selection"
            shortcut: "Ctrl+I"
            onClicked: {
                selectMenu.close();
                selectMenu.invertSelectionRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/arrow-back-up.svg"
            text: "Select Linked From"
            shortcut: "["
            enabled_: selectMenu.selectedNodeIds.length > 0
            onClicked: {
                selectMenu.close();
                selectMenu.selectLinkedFromRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/arrow-forward-up.svg"
            text: "Select Linked To"
            shortcut: "]"
            enabled_: selectMenu.selectedNodeIds.length > 0
            onClicked: {
                selectMenu.close();
                selectMenu.selectLinkedToRequested();
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
    //     id: selectMenu
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
    //             iconSource: "qrc:/assets/icons/select-all.svg"
    //             text: "Select All"
    //             shortcut: "Ctrl+A"
    //             onClicked: {
    //                 selectMenu.close();
    //                 root.selectAllNodes();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/square-x.svg"
    //             text: "Deselect All"
    //             shortcut: "Alt+A"
    //             onClicked: {
    //                 selectMenu.close();
    //                 root.deselectAllNodes();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/switch.svg"
    //             text: "Invert Selection"
    //             shortcut: "Ctrl+I"
    //             onClicked: {
    //                 selectMenu.close();
    //                 root.invertNodeSelection();
    //             }
    //         }
    //
    //         ContextSeparator {}
    //
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/box.svg"; text: "Box Select"; shortcut: "B"
    //         //     onClicked: { selectMenu.close(); root.selectionMode = "box"; }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/circle-dot.svg"; text: "Circle Select"; shortcut: "C"
    //         //     onClicked: { selectMenu.close(); root.selectionMode = "circle" }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/circle-dot.svg"; text: "Lasso Select"
    //         //     onClicked: { selectMenu.close(); root.selectionMode = "lasso" }
    //         // }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/arrow-back-up.svg"
    //             text: "Select Linked From"
    //             shortcut: "["
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 selectMenu.close();
    //                 root.selectLinkedFrom();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/arrow-forward-up.svg"
    //             text: "Select Linked To"
    //             shortcut: "]"
    //             enabled_: root.selectedNodeIds.length > 0
    //             onClicked: {
    //                 selectMenu.close();
    //                 root.selectLinkedTo();
    //             }
    //         }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/category.svg"; text: "Select Grouped (by Type, Color, or Category)"; shortcut: "Shift+G"
    //         //     enabled_: root.selectedNodeIds.length > 0
    //         //     onClicked: { selectMenu.close(); root.selectGroupedByType(); }
    //         // }
    //         //
    //         // ContextSeparator {}
    //         //
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/player-pause.svg"; text: "Select Muted / Bypassed Nodes"
    //         //     onClicked: {
    //         //         selectMenu.close();
    //         //         root.selectNodesByFilter(function(node) { return node.isBypassed === true; });
    //         //     }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/alert-triangle.svg"; text: "Select Error / Unresolved Nodes"
    //         //     onClicked: {
    //         //         selectMenu.close();
    //         //         root.selectNodesByFilter(function(node) { return node.hasError === true; });
    //         //     }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/search.svg"; text: "Find Node / Quick Search"; shortcut: "Ctrl+F"
    //         //     onClicked: {
    //         //         selectMenu.close();
    //         //         var pt = btnSelect.mapToItem(Overlay.overlay, 0, btnSelect.height + 4);
    //         //         root.openSearchPopupAtWorkspace(0, 0, "", "");
    //         //     }
    //         // }
    //     }
    // }
