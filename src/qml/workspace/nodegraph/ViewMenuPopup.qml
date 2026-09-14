import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: viewMenu
    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 8
    transformOrigin: Item.TopLeft

    // =====================================================================
    // State Input Properties (Dependencies from parent)
    // =====================================================================
    property bool showGrid: true
    property bool isSnappingEnabled: false
    property bool showWireColors: true
    property bool showMinimap: true

    // =====================================================================
    // Pure Action Signals (No internal business logic or root calls)
    // =====================================================================
    signal frameSelectedRequested()
    signal frameAllRequested()
    signal zoomInRequested()
    signal zoomOutRequested()
    signal resetViewRequested()
    signal viewCenterRequested()
    signal expandAllRequested()
    signal collapseAllRequested()
    signal toggleGridRequested()
    signal toggleSnapRequested()
    signal toggleWireColorsRequested()
    signal toggleMinimapRequested()

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
                viewMenu.frameSelectedRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/maximize.svg"
            text: "Frame All"
            onClicked: {
                viewMenu.close();
                viewMenu.frameAllRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/zoom-in.svg"
            text: "Zoom In"
            onClicked: {
                viewMenu.close();
                viewMenu.zoomInRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/zoom-out.svg"
            text: "Zoom Out"
            shortcut: "Ctrl+-"
            onClicked: {
                viewMenu.close();
                viewMenu.zoomOutRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/rotate.svg"
            text: "Reset View"
            onClicked: {
                viewMenu.close();
                viewMenu.resetViewRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/crosshair.svg"
            text: "View Center"
            onClicked: {
                viewMenu.close();
                viewMenu.viewCenterRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/chevron-down.svg"
            text: "Expand All"
            onClicked: {
                viewMenu.close();
                viewMenu.expandAllRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/chevron-right.svg"
            text: "Collapse All"
            onClicked: {
                viewMenu.close();
                viewMenu.collapseAllRequested();
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/grid.svg"
            text: viewMenu.showGrid ? "Hide Grid" : "Show Grid"
            onClicked: {
                viewMenu.close();
                viewMenu.toggleGridRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/magnet.svg"
            text: viewMenu.isSnappingEnabled ? "Disable Snap to Grid" : "Enable Snap to Grid"
            shortcut: "Shift+S"
            onClicked: {
                viewMenu.close();
                viewMenu.toggleSnapRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/palette.svg"
            text: viewMenu.showWireColors ? "Hide Wire Colors" : "Show Wire Colors"
            onClicked: {
                viewMenu.close();
                viewMenu.toggleWireColorsRequested();
            }
        }
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/map-pin.svg"
            text: viewMenu.showMinimap ? "Hide Minimap" : "Show Minimap"
            onClicked: {
                viewMenu.close();
                viewMenu.toggleMinimapRequested();
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
    //     id: viewMenu
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
    //             iconSource: "qrc:/assets/icons/focus-2.svg"
    //             text: "Frame Selected"
    //             shortcut: "F"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.frameSelected();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/maximize.svg"
    //             text: "Frame All" // ; shortcut: "Home"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.frameAll();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/zoom-in.svg"
    //             text: "Zoom In" // ; shortcut: "Ctrl++"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.zoomIn();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/zoom-out.svg"
    //             text: "Zoom Out"
    //             shortcut: "Ctrl+-"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.zoomOut();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/rotate.svg"
    //             text: "Reset View" // ; shortcut: "Num 0"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.resetView();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/crosshair.svg"
    //             text: "View Center" // ; shortcut: "Alt+Home"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.viewCenter();
    //             }
    //         }
    //
    //         ContextSeparator {}
    //
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/chevron-down.svg"
    //             text: "Expand All"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.toggleAllNodeCollapse(false);
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/chevron-right.svg"
    //             text: "Collapse All"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.toggleAllNodeCollapse(true);
    //             }
    //         }
    //
    //         ContextSeparator {}
    //
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/grid.svg"
    //             text: root.showGrid ? "Hide Grid" : "Show Grid"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.showGrid = !root.showGrid;
    //                 dagCanvas.requestPaint();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/magnet.svg"
    //             text: root.isSnappingEnabled ? "Disable Snap to Grid" : "Enable Snap to Grid"
    //             shortcut: "Shift+S"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.isSnappingEnabled = !root.isSnappingEnabled;
    //                 if (root.isSnappingEnabled)
    //                     root.snapSelectedToGrid();
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/palette.svg"
    //             text: root.showWireColors ? "Hide Wire Colors" : "Show Wire Colors"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.showWireColors = !root.showWireColors;
    //             }
    //         }
    //         ContextMenuRow {
    //             iconSource: "qrc:/assets/icons/map-pin.svg"
    //             text: root.showMinimap ? "Hide Minimap" : "Show Minimap"
    //             onClicked: {
    //                 viewMenu.close();
    //                 root.showMinimap = !root.showMinimap;
    //             }
    //         }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/photo.svg"; text: root.showBackdropPreview ? "Hide Backdrop" : "Toggle Backdrop / Viewer Preview"
    //         //     onClicked: { viewMenu.close(); root.showBackdropPreview = !root.showBackdropPreview; }
    //         // }
    //         // ContextMenuRow {
    //         //     iconSource: "qrc:/assets/icons/arrows-maximize.svg"; text: "Fullscreen / Maximize Area"; shortcut: "Alt+F10"
    //         //     onClicked: { viewMenu.close(); root.isFullscreen = !root.isFullscreen; }
    //         // }
    //     }
    // }

