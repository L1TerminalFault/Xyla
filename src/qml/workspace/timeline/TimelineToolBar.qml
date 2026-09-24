import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Rectangle {
    id: toolbarRoot

    property var playbackManager: null
    property var timelineModel: null
    property real projectFps: 30.0

    property bool showAudioWaveforms: true
    property int thumbnailMode: 1
    property int activeToolIndex: 0
    property string activeTool: "pointer"
    property string playheadTimeMode: "never"

    readonly property color borderDark: "#242424"

    signal toolChanged(string toolId, int toolIndex)
    signal addVideoTrackRequested
    signal addAudioTrackRequested
    signal zoomInRequested
    signal zoomOutRequested

    height: 60
    color: "#181818"

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: toolbarRoot.borderDark
    }

    component TimelineMenuButton: Rectangle {
        id: btnRoot

        property string label: ""
        property string tooltipText: ""
        property Menu targetMenu: null
        readonly property bool isOpen: targetMenu ? targetMenu.visible : false
        readonly property bool isHovered: btnMouse.containsMouse

        implicitHeight: 24
        implicitWidth: btnText.implicitWidth + 16
        radius: 4
        color: (btnRoot.isOpen || btnRoot.isHovered) ? "#262626" : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 60
            }
        }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btnRoot.label
            color: (btnRoot.isOpen || btnRoot.isHovered) ? "#ffffff" : "#aaaaaa"
            font.pixelSize: 11
            font.weight: (btnRoot.isOpen || btnRoot.isHovered) ? Font.Medium : Font.Normal

            Behavior on color {
                ColorAnimation {
                    duration: 60
                }
            }
        }

        XylaToolTip {
            visible: btnMouse.containsMouse && !btnRoot.isOpen && btnRoot.tooltipText !== ""
            text: btnRoot.tooltipText
            position: "bottom"
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btnRoot.targetMenu) {
                    if (btnRoot.targetMenu.visible)
                        btnRoot.targetMenu.close();
                    else
                        btnRoot.targetMenu.open();
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        TimelineMenuButton {
            label: "View"
            tooltipText: "Timeline view options"
            targetMenu: viewMenu

            XylaMenu {
                id: viewMenu
                y: parent.height + 3

                XylaMenuItem {
                    text: "Zoom In"
                    itemShortcut: "Ctrl+="
                    onTriggered: toolbarRoot.zoomInRequested()
                }
                XylaMenuItem {
                    text: "Zoom Out"
                    itemShortcut: "Ctrl+-"
                    onTriggered: toolbarRoot.zoomOutRequested()
                }
                // XylaMenuSeparator {}
                // XylaMenuItem {
                //     text: "Toggle Waveforms"
                //     checkable: true
                //     checked: toolbarRoot.showAudioWaveforms
                //     onTriggered: toolbarRoot.showAudioWaveforms = !toolbarRoot.showAudioWaveforms
                // }
            }
        }

        TimelineMenuButton {
            label: "Edit"
            tooltipText: "Timeline edit operations"
            targetMenu: editMenu

            XylaMenu {
                id: editMenu
                y: parent.height + 3

                XylaMenuItem {
                    text: "Cut at Playhead"
                    itemShortcut: "Ctrl+K"
                    onTriggered: {
                        if (toolbarRoot.timelineModel && toolbarRoot.playbackManager) {
                            toolbarRoot.timelineModel.cutAtPlayhead(toolbarRoot.playbackManager.currentFrame);
                        }
                    }
                }
                XylaMenuItem {
                    text: "Delete Selected"
                    itemShortcut: "Del"
                    onTriggered: {
                        if (toolbarRoot.timelineModel) {
                            toolbarRoot.timelineModel.deleteSelectedClips();
                        }
                    }
                }
                XylaMenuSeparator {}
                XylaMenuItem {
                    text: "Select All Clips"
                    itemShortcut: "Ctrl+A"
                    onTriggered: {
                        if (toolbarRoot.timelineModel) {
                            var all = toolbarRoot.timelineModel.getAllClips();
                            var ids = [];
                            for (var i = 0; i < all.length; ++i)
                                ids.push(all[i].clipId);
                            toolbarRoot.timelineModel.applyDirectSelection(ids);
                        }
                    }
                }
                XylaMenuItem {
                    text: "Deselect All"
                    itemShortcut: "Esc"
                    onTriggered: {
                        if (toolbarRoot.timelineModel) {
                            toolbarRoot.timelineModel.clearSelection();
                        }
                    }
                }
            }
        }

        TimelineMenuButton {
            label: "Add"
            tooltipText: "Insert generators and titles"
            targetMenu: addMenu

            XylaMenu {
                id: addMenu
                y: parent.height + 3

                XylaMenuItem {
                    text: "Text / Title Clip"
                    itemShortcut: "Ctrl+T"
                    onTriggered: {
                        if (toolbarRoot.timelineModel && toolbarRoot.playbackManager) {
                            var currentFrame = toolbarRoot.playbackManager.currentFrame;
                            toolbarRoot.timelineModel.addTitleClip(0, currentFrame, 150, "Title");
                        }
                    }
                }
                XylaMenuItem {
                    text: "Vector Graphic (SVG)..."
                    enabled: false
                }
            }
        }

        TimelineMenuButton {
            label: "Clip"
            tooltipText: "Link & clip options"
            targetMenu: clipMenu

            XylaMenu {
                id: clipMenu
                y: parent.height + 3

                XylaMenuItem {
                    text: "Link Audio/Video"
                    itemShortcut: "Ctrl+L"
                    enabled: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.canLinkSelection() : false
                    onTriggered: if (toolbarRoot.timelineModel)
                        toolbarRoot.timelineModel.linkSelectedClips()
                }
                XylaMenuItem {
                    text: "Unlink Selection"
                    itemShortcut: "Ctrl+Shift+L"
                    enabled: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.canUnlinkSelection() : false
                    onTriggered: if (toolbarRoot.timelineModel)
                        toolbarRoot.timelineModel.unlinkSelectedClips()
                }
            }
        }

        TimelineMenuButton {
            label: "Track"
            tooltipText: "Track management"
            targetMenu: trackMenu

            XylaMenu {
                id: trackMenu
                y: parent.height + 3

                XylaMenuItem {
                    text: "Add Video Track"
                    onTriggered: toolbarRoot.addVideoTrackRequested()
                }
                XylaMenuItem {
                    text: "Add Audio Track"
                    onTriggered: toolbarRoot.addAudioTrackRequested()
                }
                // XylaMenuSeparator {}
                // XylaMenuItem {
                //     text: "Global Ripple Mode"
                //     checkable: true
                //     checked: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.globalRippleMode : false
                //     onTriggered: {
                //         if (toolbarRoot.timelineModel) {
                //             toolbarRoot.timelineModel.globalRippleMode = !toolbarRoot.timelineModel.globalRippleMode;
                //         }
                //     }
                // }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            color: "#262626"
        }

XylaSegmentedToggle {
    id: toolControl

    // Map options to include both id/value and label for tooltips/actions
    options: [
        {
            id: "pointer",
            value: "pointer",
            tooltip: "Selection (V)",
            icon: "qrc:/assets/icons/cursor.svg"
        },
        {
            id: "razor",
            value: "razor",
            tooltip: "Razor Tool (C)",
            icon: "qrc:/assets/icons/scissors.svg"
        },
        {
            id: "ripple",
            value: "ripple",
            tooltip: "Ripple Edit (B)",
            icon: "qrc:/assets/icons/arrow-bar-to-left.svg"
        },
        {
            id: "roll",
            value: "roll",
            tooltip: "Roll / Resize (N)",
            icon: "qrc:/assets/icons/arrows-horizontal.svg"
        },
        {
            id: "slip",
            value: "slip",
            tooltip: "Slip Tool (Y)",
            icon: "qrc:/assets/icons/switch-horizontal.svg"
        }
    ]

    // Declarative binding to root toolbar state
    currentIndex: toolbarRoot.activeToolIndex

    onOptionSelected: (index, value) => {
        toolbarRoot.activeToolIndex = index;
        
        // Retrieve the tool ID using the selected value or options array
        var toolId = (options[index] && options[index].id) ? options[index].id : value;
        toolbarRoot.activeTool = toolId;
        toolbarRoot.toolChanged(toolId, index);
    }
}

        Item {
            Layout.fillWidth: true
        }

XylaIconButton {
    id: snapBtn

    // Layout.preferredWidth: 32
    Layout.preferredHeight: 30

    readonly property bool isSnapping: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.snappingEnabled : true

    iconSource: "qrc:/assets/icons/magnet.svg"
    tooltip: isSnapping ? "Snapping enabled (Click to toggle)" : "Snapping disabled (Click to toggle)"
    primary: isSnapping

    onClicked: {
        if (toolbarRoot.timelineModel) {
            toolbarRoot.timelineModel.snappingEnabled = !toolbarRoot.timelineModel.snappingEnabled;
        }
    }
}

XylaIconButton {
    id: waveformBtn

    // Layout.preferredWidth: 32
    Layout.preferredHeight: 30

    iconSource: "qrc:/assets/icons/waveform.svg"
    tooltip: toolbarRoot.showAudioWaveforms ? "Audio waveforms enabled (Click to toggle)" : "Audio waveforms disabled (Click to toggle)"
    primary: toolbarRoot.showAudioWaveforms

    onClicked: {
        toolbarRoot.showAudioWaveforms = !toolbarRoot.showAudioWaveforms;
    }
}

Item {
    id: thumbComboWrapper
    Layout.preferredHeight: thumbBtn.height
    Layout.preferredWidth: 50

    RowLayout {
        anchors.fill: parent
        spacing: 1

        // Main Thumbnail Toggle Button (Using XylaIconButton)
        XylaIconButton {
            id: thumbBtn
            // Layout.fillHeight: true
            Layout.preferredHeight: 30
            iconSource: "qrc:/assets/icons/photo.svg"
            tooltip: toolbarRoot.thumbnailMode > 0 ? "Thumbnails active (Click to turn off)" : "Thumbnails off (Click to enable)"
            primary: toolbarRoot.thumbnailMode > 0
            onClicked: {
                toolbarRoot.thumbnailMode = (toolbarRoot.thumbnailMode > 0) ? 0 : 1;
            }
        }

        // Dropdown Chevron Button (Custom to support rotation animation)
        Rectangle {
            id: thumbChevronBtn
            Layout.fillHeight: true
            Layout.preferredWidth: 18
            radius: 4
            color: "transparent" // (thumbChevronMouse.containsMouse || thumbPopup.visible) ? "#202020" : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Image {
                anchors.centerIn: parent
                width: 12
                height: 12
                source: "qrc:/assets/icons/chevron-down.svg"
                sourceSize: Qt.size(20, 20)
                opacity: (thumbChevronMouse.containsMouse || thumbPopup.visible) ? 0.9 : 0.45
                rotation: thumbPopup.visible ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            XylaToolTip {
                visible: thumbChevronMouse.containsMouse && !thumbPopup.visible
                text: "Thumbnail options"
                delay: 800
                position: "bottom"
            }

            MouseArea {
                id: thumbChevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (thumbPopup.visible) {
                        thumbPopup.close();
                    } else {
                        thumbPopup.open();
                    }
                }
            }
        }
    }

    Popup {
        id: thumbPopup
        x: thumbComboWrapper.width - width
        y: thumbComboWrapper.height + 4
        width: 216
        height: 76
        padding: 8
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 120; easing.type: Easing.OutCubic }
        }

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 8

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        contentItem: ColumnLayout {
            spacing: 6

            Text {
                text: "Thumbnail Mode"
                color: "#888888"
                font.pixelSize: 10
                font.bold: true
            }

            XylaSegmentedToggle {
                Layout.fillWidth: true
                options: [
                    { text: "None", value: 0 },
                    { text: "Ends", value: 1 },
                    { text: "Full", value: 2 }
                ]
                currentIndex: toolbarRoot.thumbnailMode
                onOptionSelected: (index, value) => {
                    toolbarRoot.thumbnailMode = value;
                    thumbPopup.close();
                }
            }
        }
    }
}

XylaIconButton {
    id: rippleSettingsBtn
    ghost: true
    iconSource: "qrc:/assets/icons/settings.svg"
    Layout.preferredHeight: 30
    tooltip: "Timeline Settings"
    onClicked: settingsPopup.open()

    Popup {
        id: settingsPopup
        parent: rippleSettingsBtn   // make the coordinate space explicit, don't rely on default
        x: rippleSettingsBtn.width - width   // align right edge of popup to right edge of button
        y: rippleSettingsBtn.height + 6      // sit just below the button, small gap

        width: 216
        height: 76
        padding: 8
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 120; easing.type: Easing.OutCubic }
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

        contentItem: ColumnLayout {
            spacing: 6

            Text {
                text: "Playhead Show Time"
                color: "#888888"
                font.pixelSize: 10
            }

            XylaSegmentedToggle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                options: [
                    { text: "Never", value: "never" },
                    { text: "On Hover", value: "hover" },
                    { text: "Always", value: "always" }
                ]
                currentIndex: {
                    if (toolbarRoot.playheadTimeMode === "never") return 0;
                    if (toolbarRoot.playheadTimeMode === "hover") return 1;
                    if (toolbarRoot.playheadTimeMode === "always") return 2;
                    return 0;
                }
                onOptionSelected: function(index, value) {
                    toolbarRoot.playheadTimeMode = value;
                    settingsPopup.close();
                }
            }
        }
    }
}
    }
}
