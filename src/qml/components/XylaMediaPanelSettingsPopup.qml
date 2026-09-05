import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: settingsPopup
    parent: settingsBtn
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    padding: 10
    width: 270
    y: settingsBtn.height + 6
    // x: settingsBtn.width - width

    // ================================================================
    // MEDIA PANEL SETTINGS PROPERTIES & STATE
    // ================================================================
    property var clipboardAsset: null
    property bool isListView: false
    property real gridCellSize: 160
    property bool hoverScrubEnabled: true
    property bool showWaveforms: true
    property bool showExtensions: true
    // property bool groupByMediaType: false
    // property string currentSortField: "Name"    // "Name", "Date", "Duration", "Size"
    // property bool sortAscending: true

    // ================================================================
    // SIGNALS
    // ================================================================
    signal viewModeChanged(bool isListView)
    signal gridCellSizeChanged_(real size)
    signal hoverScrubToggled(bool enabled)
    signal showWaveformsToggled(bool enabled)
    signal showExtensionsToggled(bool enabled)
    signal groupByMediaTypeRequested
    signal sortOrderChanged(string field, bool ascending)
    signal relinkMediaRequested
    signal cleanupUnusedRequested
    signal preferencesRequested

    // ================================================================
    // BACKGROUND & SHADOW
    // ================================================================
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

    // ================================================================
    // ENTER & EXIT ANIMATIONS
    // ================================================================
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

    // ================================================================
    // MAIN POPUP CONTENT
    // ================================================================
    contentItem: ColumnLayout {
        id: popupLayout
        spacing: 6
        implicitWidth: 250
        Layout.preferredWidth: 250
        Layout.fillWidth: true

        // --- 1. VIEW MODE SWITCHER ---
        // RowLayout {
        //     Layout.fillWidth: true
        //     spacing: 6

            // ViewModeTile {
            //     Layout.fillWidth: true
            //     iconSource: "qrc:/assets/icons/grid-view.svg"
            //     text: "Grid View"
            //     active: !settingsPopup.isListView
            //     onClicked: {
            //         settingsPopup.isListView = false;
            //         settingsPopup.viewModeChanged(false);
            //     }
            // }
            //
            // ViewModeTile {
            //     Layout.fillWidth: true
            //     iconSource: "qrc:/assets/icons/list-view.svg"
            //     text: "List View"
            //     active: settingsPopup.isListView
            //     onClicked: {
            //         settingsPopup.isListView = true;
            //         settingsPopup.viewModeChanged(true);
            //     }
            // }
        // }

        // --- 2. GRID / THUMBNAIL SIZE SLIDER ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: 5
            visible: !settingsPopup.isListView

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Thumbnail Size"
                    color: "#a0a0a0"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                }
                // Text {
                //     text: Math.round(sizeSlider.value) + " px"
                //     color: "#6b6b6b"
                //     font.pixelSize: 11
                //     font.family: "Monospace"
                //     Layout.rightMargin: 2
                // }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaIconButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSource: "qrc:/assets/icons/zoom-out.svg"
                    ghost: true
                    onClicked: sizeSlider.value = Math.max(sizeSlider.from, sizeSlider.value - 20)
                }

                Slider {
                    id: sizeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    from: 130
                    to: 260
                    value: settingsPopup.gridCellSize
                    // onMoved: root.gridCellSize = value
                    onValueChanged: settingsPopup.gridCellSize = value

                    background: Rectangle {
                        id: trackGroove
                        x: sizeSlider.leftPadding
                        y: sizeSlider.topPadding + (sizeSlider.availableHeight - height) / 2
                        implicitWidth: 150
                        implicitHeight: 28
                        width: sizeSlider.availableWidth
                        height: implicitHeight
                        radius: 10 // height / 2
                        color: "#232323"
                        clip: true

                        // Light Pill Progress Fill (Matches reference screenshot)
                        Rectangle {
                            id: progressFill
                            // width: Math.max(10, (sizeSlider.position * parent.width) + (indicator.width / 2 - indicator.anchors.rightMargin))
                            width: Math.min(parent.width, Math.max(10, (sizeSlider.position * parent.width) + (indicator.width / 2 - indicator.anchors.rightMargin)))
                            // width: Math.max(10, sizeSlider.position * parent.width)
                            // width: Math.max(parent.height, sizeSlider.visualPosition * parent.width)
                            height: parent.height
                            // radius: 10 // height / 2

                            topLeftRadius: 10 // height / 2
                            bottomLeftRadius: 10 // height / 2

                            // Lower/subtle curvature on the right thumb end
                            topRightRadius: 5
                            bottomRightRadius: 5
                            color: "#d8d8d8"

                            // Dark vertical pill-shaped indicator inside the handle end
                            Rectangle {
                                id: indicator
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 22
                                radius: 3
                                color: "#232323"
                            }
                        }
                    }

                    handle: Item {
                        x: sizeSlider.leftPadding + sizeSlider.visualPosition * sizeSlider.availableWidth
                        implicitWidth: 0
                        implicitHeight: 0
                        visible: false
                    }
                }

                XylaIconButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSource: "qrc:/assets/icons/zoom-in.svg"
                    ghost: true
                    onClicked: sizeSlider.value = Math.min(sizeSlider.to, sizeSlider.value + 20)
                }
            }
        }

        ContextSeparator {
            visible: !settingsPopup.isListView
        }

        // --- 3. PREVIEW & METADATA TOGGLES ---
MenuToggleRow {
    iconSource: "qrc:/assets/icons/player-play.svg"
    text: "Live Hover Scrub"

    checked: panelRoot.activeMediaBinModel
             ? panelRoot.activeMediaBinModel.mediaPanelSettings.hoverScrub
             : false

    onToggled: function (val) {
        if (!panelRoot.activeMediaBinModel)
            return;

        panelRoot.activeMediaBinModel.mediaPanelSettings.hoverScrub = val;
    }
}
        // MenuToggleRow {
        //     iconSource: "qrc:/assets/icons/player-play.svg"
        //     text: "Live Hover Scrub"
        //     checked: settingsPopup.hoverScrubEnabled
        //     onToggled: function (val) {
        //         settingsPopup.hoverScrubEnabled = val;
        //         settingsPopup.hoverScrubToggled(val);
        //     }
        // }

MenuToggleRow {
    iconSource: "qrc:/assets/icons/waveform.svg"
    text: "Show Waveforms"

    checked: panelRoot.activeMediaBinModel
             ? panelRoot.activeMediaBinModel.mediaPanelSettings.showWaveforms
             : false

    onToggled: function (val) {
        if (!panelRoot.activeMediaBinModel)
            return;

        panelRoot.activeMediaBinModel.mediaPanelSettings.showWaveforms = val;
    }
}
        // MenuToggleRow {
        //     iconSource: "qrc:/assets/icons/waveform.svg"
        //     text: "Show Waveforms"
        //     checked: settingsPopup.showWaveforms
        //     onToggled: function (val) {
        //         settingsPopup.showWaveforms = val;
        //         settingsPopup.showWaveformsToggled(val);
        //     }
        // }

        // MenuToggleRow {
        //     iconSource: "qrc:/assets/icons/stack.svg"
        //     text: "Group by Media Type"
        //     checked: settingsPopup.groupByMediaType
        //     onToggled: function (val) {
        //         settingsPopup.groupByMediaType = val;
        //         settingsPopup.groupByMediaTypeToggled(val);
        //     }
        // }

MenuToggleRow {
    iconSource: "qrc:/assets/icons/file-text.svg"
    text: "Show File Extensions"

    checked: panelRoot.activeMediaBinModel
             ? panelRoot.activeMediaBinModel.mediaPanelSettings.showFileExtensions
             : true

    onToggled: function (val) {
        if (!panelRoot.activeMediaBinModel)
            return;

        panelRoot.activeMediaBinModel.mediaPanelSettings.showFileExtensions = val;
    }
}
        // MenuToggleRow {
        //     iconSource: "qrc:/assets/icons/file-text.svg"
        //     text: "Show File Extensions"
        //     checked: settingsPopup.showExtensions
        //     onToggled: function (val) {
        //         settingsPopup.showExtensions = val;
        //         settingsPopup.showExtensionsToggled(val);
        //     }
        // }

        // ContextSeparator {}

        // --- 4. SORTING ---
        // ContextMenuRow {
        //     iconSource: "qrc:/assets/icons/arrow-up-down.svg"
        //     text: "Sort by: " + settingsPopup.currentSortField + (settingsPopup.sortAscending ? " (Asc)" : " (Desc)")
        //     showSubValue: true
        //     onClicked: {
        //         // Cycle through sort modes or trigger a sub-menu / dialog
        //         if (settingsPopup.currentSortField === "Name") {
        //             settingsPopup.currentSortField = "Date";
        //         } else if (settingsPopup.currentSortField === "Date") {
        //             settingsPopup.currentSortField = "Duration";
        //         } else if (settingsPopup.currentSortField === "Duration") {
        //             settingsPopup.currentSortField = "Type";
        //         } else {
        //             settingsPopup.currentSortField = "Name";
        //             settingsPopup.sortAscending = !settingsPopup.sortAscending;
        //         }
        //         settingsPopup.sortOrderChanged(settingsPopup.currentSortField, settingsPopup.sortAscending);
        //     }
        // }

        ContextSeparator {}

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/stack.svg"
            text: "Group by Media Type"
            onClicked: {
                // settingsPopup.groupByMediaType;
                settingsPopup.close();
                settingsPopup.groupByMediaTypeRequested();
            }
        }

        // --- 5. MEDIA MAINTENANCE ACTIONS ---
        // ContextMenuRow {
        //     iconSource: "qrc:/assets/icons/link.svg"
        //     text: "Relink Offline Media..."
        //     onClicked: {
        //         settingsPopup.close();
        //         settingsPopup.relinkMediaRequested();
        //     }
        // }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Clean Unused Clips"
            destructive: true
            onClicked: {
                settingsPopup.close();
                settingsPopup.cleanupUnusedRequested();
            }
        }

        // ContextMenuRow {
        //     iconSource: "qrc:/assets/icons/sliders.svg"
        //     text: "Media Bin Preferences..."
        //     onClicked: {
        //         settingsPopup.close();
        //         settingsPopup.preferencesRequested();
        //     }
        // }
    }

    // ================================================================
    // VIEW MODE TILE (GRID vs LIST)
    // ================================================================
    // component ViewModeTile: Rectangle {
    //     id: modeTile
    //     property string iconSource
    //     property string text
    //     property bool active: false
    //
    //     signal clicked
    //
    //     implicitHeight: 46
    //     radius: 8
    //
    //     color: modeTile.active ? "#2a2a2a" : (tileMouse.containsMouse ? "#222222" : "#1b1b1b")
    //     border.color: modeTile.active ? "#4a4a4a" : (tileMouse.containsMouse ? "#303030" : "#222222")
    //     border.width: 1
    //
    //     RowLayout {
    //         anchors.centerIn: parent
    //         spacing: 6
    //
    //         Image {
    //             Layout.preferredWidth: 16
    //             Layout.preferredHeight: 16
    //             source: modeTile.iconSource
    //             sourceSize: Qt.size(16, 16)
    //             opacity: modeTile.active ? 1.0 : 0.6
    //         }
    //
    //         Text {
    //             text: modeTile.text
    //             color: modeTile.active ? "#ffffff" : "#888888"
    //             font.pixelSize: 11
    //             font.weight: modeTile.active ? Font.DemiBold : Font.Normal
    //         }
    //     }
    //
    //     MouseArea {
    //         id: tileMouse
    //         anchors.fill: parent
    //         hoverEnabled: true
    //         cursorShape: Qt.PointingHandCursor
    //         onClicked: modeTile.clicked()
    //     }
    // }

    // ================================================================
    // TOGGLE ROW (SWITCH)
    // ================================================================
    component MenuToggleRow: Rectangle {
        id: toggleRow
        property string iconSource
        property string text
        property bool checked: false

        signal toggled(bool value)

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 7

        color: rowMouse.containsMouse ? "#252525" : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Image {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: toggleRow.iconSource
                sourceSize: Qt.size(16, 16)
                opacity: 0.8
            }

            Text {
                Layout.fillWidth: true
                text: toggleRow.text
                color: "#dedede"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            // Compact Mini Switch
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 16
                radius: 8
                color: toggleRow.checked ? "#3875d7" : "#2e2e2e"
                border.color: toggleRow.checked ? "#4d88e8" : "#3e3e3e"
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Rectangle {
                    x: toggleRow.checked ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: "#ffffff"

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                toggleRow.checked = !toggleRow.checked;
                toggleRow.toggled(toggleRow.checked);
            }
        }
    }

    // ================================================================
    // ACTION ROW (CLICKABLE ITEM)
    // ================================================================
    component ContextMenuRow: Rectangle {
        id: row
        property string iconSource
        property string text
        property bool destructive: false
        property bool showSubValue: false

        signal clicked

        Layout.fillWidth: true
        implicitHeight: 30
        radius: 7

        color: rowMouse.containsMouse ? "#252525" : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Image {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: row.iconSource
                sourceSize: Qt.size(16, 16)
                opacity: 0.85
            }

            Text {
                Layout.fillWidth: true
                text: row.text
                color: row.destructive ? "#e06b6b" : "#dedede"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                visible: row.showSubValue
                text: "›"
                color: "#6b6b6b"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    // ================================================================
    // COMPACT ICON BUTTON (FOR ZOOM IN / ZOOM OUT)
    // ================================================================
    component IconButton: Rectangle {
        id: btn
        property string iconSource
        signal clicked

        radius: 6
        color: btnMouse.containsMouse ? (btnMouse.pressed ? "#1e1e1e" : "#2a2a2a") : "#202020"
        border.color: btnMouse.containsMouse ? "#3a3a3a" : "#282828"
        border.width: 1

        Image {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: btn.iconSource
            sourceSize: Qt.size(14, 14)
            opacity: btnMouse.containsMouse ? 1.0 : 0.7
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // ================================================================
    // SEPARATOR
    // ================================================================
    component ContextSeparator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 7
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: 1
            color: "#282828"
        }
    }

    // ================================================================
    // POSITIONING HELPER
    // ================================================================
    // property real requestedX: -1
    // property real requestedY: 0
    //
    // function reposition() {
    //     x = Math.max(8, Math.min(requestedX, parent.width - width - 8));
    //     y = Math.max(8, Math.min(requestedY, parent.height - height - 8));
    // }
    //
    // onImplicitWidthChanged: if (visible)
    //     reposition()
    // onImplicitHeightChanged: if (visible)
    //     reposition()
    //
    // function openAt(screenX, screenY) {
    //     requestedX = screenX;
    //     requestedY = screenY;
    //     reposition();
    //     open();
    // }
}
