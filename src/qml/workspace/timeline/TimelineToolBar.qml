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

    readonly property color borderDark: "#242424"

    signal toolChanged(string toolId, int toolIndex)
    signal addVideoTrackRequested
    signal addAudioTrackRequested
    signal zoomInRequested
    signal zoomOutRequested

    height: 40
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

        // ── 1. EDIT MENU ──────────────────────────────────────────
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

        // ── 2. CLIP MENU ──────────────────────────────────────────
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

        // ── 3. TRACK MENU ─────────────────────────────────────────
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
                XylaMenuSeparator {}
                XylaMenuItem {
                    text: "Global Ripple Mode"
                    checkable: true
                    checked: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.globalRippleMode : false
                    onTriggered: {
                        if (toolbarRoot.timelineModel) {
                            toolbarRoot.timelineModel.globalRippleMode = !toolbarRoot.timelineModel.globalRippleMode;
                        }
                    }
                }
            }
        }

        // ── 4. VIEW MENU ──────────────────────────────────────────
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
                XylaMenuSeparator {}
                XylaMenuItem {
                    text: "Toggle Waveforms"
                    checkable: true
                    checked: toolbarRoot.showAudioWaveforms
                    onTriggered: toolbarRoot.showAudioWaveforms = !toolbarRoot.showAudioWaveforms
                }
            }
        }

        // Divider after Menus
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            color: "#262626"
        }

        // ── 5. SEGMENTED EDITING TOOLS (SLIDING PILL) ──────────────
        Item {
            id: toolControl

            property var options: [
                {
                    id: "pointer",
                    label: "Selection (V)",
                    icon: "qrc:/assets/icons/pointer.svg"
                },
                {
                    id: "razor",
                    label: "Razor Tool (C)",
                    icon: "qrc:/assets/icons/scissors.svg"
                },
                {
                    id: "ripple",
                    label: "Ripple Edit (B)",
                    icon: "qrc:/assets/icons/arrow-bar-to-left.svg"
                },
                {
                    id: "roll",
                    label: "Roll / Resize (N)",
                    icon: "qrc:/assets/icons/arrows-horizontal.svg"
                },
                {
                    id: "slip",
                    label: "Slip Tool (Y)",
                    icon: "qrc:/assets/icons/switch-horizontal.svg"
                }
            ]

            property int currentIndex: toolbarRoot.activeToolIndex
            property int itemWidth: 30
            property int itemPadding: 2
            property int pillMargin: 2

            implicitHeight: 30
            implicitWidth: (itemWidth * options.length) + (itemPadding * 2)

            Rectangle {
                anchors.fill: parent
                color: "#0d0d0d"
                radius: 7
                border.color: "#202020"
                border.width: 1

                // Sliding Active Pill
                Rectangle {
                    id: toolIndicator
                    width: toolControl.itemWidth - (toolControl.pillMargin * 2)
                    height: parent.height - (toolControl.itemPadding * 2) - (toolControl.pillMargin * 2)
                    y: toolControl.itemPadding + toolControl.pillMargin
                    radius: 4
                    color: "#11389F"
                    border.color: "#2555D3"
                    border.width: 1

                    x: toolControl.itemPadding + (toolControl.currentIndex * toolControl.itemWidth) + toolControl.pillMargin

                    Behavior on x {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: toolControl.itemPadding

                    Repeater {
                        model: toolControl.options

                        Item {
                            id: toolItem
                            width: toolControl.itemWidth
                            height: parent.height

                            readonly property bool isSelected: index === toolControl.currentIndex
                            readonly property bool isHovered: toolMouse.containsMouse

                            Image {
                                id: toolIconImg
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: modelData.icon
                                sourceSize: Qt.size(14, 14)
                                opacity: toolItem.isSelected ? 1.0 : (toolItem.isHovered ? 0.85 : 0.45)
                                visible: status === Image.Ready

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            // Fallback glyph canvas if SVG not present
                            Loader {
                                anchors.fill: parent
                                active: toolIconImg.status !== Image.Ready
                                sourceComponent: Canvas {
                                    id: fallbackCanvas
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        var c = toolItem.isSelected ? "#ffffff" : (toolItem.isHovered ? "#cccccc" : "#777777");
                                        ctx.strokeStyle = c;
                                        ctx.fillStyle = c;
                                        ctx.lineWidth = 1.3;

                                        if (modelData.id === "pointer") {
                                            ctx.beginPath();
                                            ctx.moveTo(3, 3);
                                            ctx.lineTo(3, 13);
                                            ctx.lineTo(6.5, 10);
                                            ctx.lineTo(9.5, 14);
                                            ctx.lineTo(11.5, 12.5);
                                            ctx.lineTo(8.5, 8.5);
                                            ctx.lineTo(12.5, 8.5);
                                            ctx.closePath();
                                            ctx.fill();
                                        } else if (modelData.id === "razor") {
                                            ctx.beginPath();
                                            ctx.moveTo(4, 4);
                                            ctx.lineTo(16, 16);
                                            ctx.moveTo(16, 4);
                                            ctx.lineTo(4, 16);
                                            ctx.stroke();
                                        } else {
                                            ctx.beginPath();
                                            ctx.moveTo(3, 10);
                                            ctx.lineTo(17, 10);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }

                            XylaToolTip {
                                visible: toolMouse.containsMouse
                                text: modelData.label
                                position: "bottom"
                            }

                            MouseArea {
                                id: toolMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toolControl.currentIndex = index;
                                    toolbarRoot.activeToolIndex = index;
                                    toolbarRoot.toolChanged(modelData.id, index);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Spacer pushing right controls to edge
        Item {
            Layout.fillWidth: true
        }

        // ── 6. INDEPENDENT SNAPPING TOGGLE BUTTON ─────────────────
        Rectangle {
            id: snapBtnWrapper
            Layout.preferredHeight: 28
            Layout.preferredWidth: 32
            radius: 6
            color: "transparent"
            border.color: "#282828"
            border.width: 1

            readonly property bool isSnapping: toolbarRoot.timelineModel ? toolbarRoot.timelineModel.snappingEnabled : true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 4
                color: {
                    if (snapBtnWrapper.isSnapping)
                        return snapMouse.containsMouse ? "#1645BF" : "#11389F";
                    return snapMouse.containsMouse ? "#222222" : "transparent";
                }
                border.color: snapBtnWrapper.isSnapping ? "#2555D3" : "transparent"
                border.width: snapBtnWrapper.isSnapping ? 1 : 0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/magnet.svg"
                    sourceSize: Qt.size(14, 14)
                    opacity: snapBtnWrapper.isSnapping ? 1.0 : (snapMouse.containsMouse ? 0.75 : 0.45)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
            }

            XylaToolTip {
                visible: snapMouse.containsMouse
                text: snapBtnWrapper.isSnapping ? "Snapping enabled (Click to toggle)" : "Snapping disabled (Click to toggle)"
                position: "bottom"
            }

            MouseArea {
                id: snapMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (toolbarRoot.timelineModel) {
                        toolbarRoot.timelineModel.snappingEnabled = !toolbarRoot.timelineModel.snappingEnabled;
                    }
                }
            }
        }

        // ── 7. AUDIO WAVEFORMS TOGGLE BUTTON ──────────────────────
        Rectangle {
            id: waveformBtnWrapper
            Layout.preferredHeight: 28
            Layout.preferredWidth: 32
            radius: 6
            color: "transparent"
            border.color: "#282828"
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 4
                color: {
                    if (toolbarRoot.showAudioWaveforms)
                        return waveMouse.containsMouse ? "#1645BF" : "#11389F";
                    return waveMouse.containsMouse ? "#222222" : "transparent";
                }
                border.color: toolbarRoot.showAudioWaveforms ? "#2555D3" : "transparent"
                border.width: toolbarRoot.showAudioWaveforms ? 1 : 0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/volume.svg"
                    sourceSize: Qt.size(14, 14)
                    opacity: toolbarRoot.showAudioWaveforms ? 1.0 : (waveMouse.containsMouse ? 0.75 : 0.45)
                }
            }

            XylaToolTip {
                visible: waveMouse.containsMouse
                text: toolbarRoot.showAudioWaveforms ? "Audio waveforms enabled" : "Audio waveforms disabled"
                position: "bottom"
            }

            MouseArea {
                id: waveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toolbarRoot.showAudioWaveforms = !toolbarRoot.showAudioWaveforms
            }
        }

        // ── 8. THUMBNAIL MODE COMBO ───────────────────────────────
        Rectangle {
            id: thumbComboBtn
            Layout.preferredHeight: 28
            Layout.preferredWidth: 62
            radius: 6
            color: "transparent"
            border.color: "#282828"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Rectangle {
                    id: thumbActionBtn
                    Layout.fillHeight: true
                    Layout.preferredWidth: 30
                    radius: 4
                    color: {
                        if (toolbarRoot.thumbnailMode > 0)
                            return thumbActionMouse.containsMouse ? "#1645BF" : "#11389F";
                        return thumbActionMouse.containsMouse ? "#222222" : "transparent";
                    }
                    border.color: toolbarRoot.thumbnailMode > 0 ? "#2555D3" : "transparent"
                    border.width: toolbarRoot.thumbnailMode > 0 ? 1 : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/photo.svg"
                        sourceSize: Qt.size(14, 14)
                        opacity: toolbarRoot.thumbnailMode > 0 ? 1.0 : (thumbActionMouse.containsMouse ? 0.75 : 0.45)
                    }

                    XylaToolTip {
                        visible: thumbActionMouse.containsMouse && !thumbPopup.visible
                        text: toolbarRoot.thumbnailMode > 0 ? "Thumbnails active (Click to turn off)" : "Thumbnails off (Click to enable)"
                        position: "bottom"
                    }

                    MouseArea {
                        id: thumbActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolbarRoot.thumbnailMode = (toolbarRoot.thumbnailMode > 0) ? 0 : 1
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    color: "#282828"
                }

                Rectangle {
                    id: thumbChevronBtn
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    radius: 4
                    color: (thumbChevronMouse.containsMouse || thumbPopup.visible) ? "#202020" : "transparent"

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
                        sourceSize: Qt.size(12, 12)
                        opacity: (thumbChevronMouse.containsMouse || thumbPopup.visible) ? 0.9 : 0.45
                        rotation: thumbPopup.visible ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    MouseArea {
                        id: thumbChevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: thumbPopup.visible ? thumbPopup.close() : thumbPopup.open()
                    }
                }
            }

            Popup {
                id: thumbPopup
                x: thumbComboBtn.width - width
                y: thumbComboBtn.height + 4
                width: 216
                height: 76
                padding: 8
                modal: true
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: "#0d0d0d"
                        radius: 5
                        border.color: "#262626"
                        border.width: 1

                        Rectangle {
                            width: (parent.width - 4) / 3
                            height: parent.height - 4
                            y: 2
                            x: 2 + (toolbarRoot.thumbnailMode * width)
                            radius: 3.5
                            color: "#11389F"
                            border.color: "#2555D3"
                            border.width: 1

                            Behavior on x {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutQuint
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 2

                            Repeater {
                                model: [
                                    {
                                        label: "None",
                                        val: 0
                                    },
                                    {
                                        label: "Ends",
                                        val: 1
                                    },
                                    {
                                        label: "Full",
                                        val: 2
                                    }
                                ]

                                Item {
                                    width: parent.width / 3
                                    height: parent.height

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: toolbarRoot.thumbnailMode === modelData.val
                                        color: toolbarRoot.thumbnailMode === modelData.val ? "#ffffff" : (segMouse.containsMouse ? "#cccccc" : "#777777")
                                    }

                                    MouseArea {
                                        id: segMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            toolbarRoot.thumbnailMode = modelData.val;
                                            thumbPopup.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 9. TIMELINE SETTINGS POPUP ────────────────────────────
        XylaIconButton {
            id: rippleSettingsBtn
            ghost: true
            iconSource: "qrc:/assets/icons/settings.svg"
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            tooltip: "Timeline Settings"
            onClicked: ripplePopup.open()

            XylaTimelineRippleSettingsPopup {
                id: ripplePopup
                x: rippleSettingsBtn.width - width
                y: rippleSettingsBtn.height + 6
                timelineModel: toolbarRoot.timelineModel
            }
        }
    }
}
