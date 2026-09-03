import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: contextMenu
    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 8

    property var timelineRoot: null
    property var timelineModel: null
    property var playbackManager: null

    property real clickedFrame: 0
    property int clickedTrack: 0
    property var clickedClipData: null
    property string clickedClipId: ""

    // Live Fresh Lock & Link States
    property bool isCurrentTrackLocked: false
    property bool isCurrentClipLocked: false
    property bool isCurrentClipLinked: false
    property bool canLinkCurrentSelection: false
    property bool canUnlinkCurrentSelection: false

    readonly property bool hasClipSelection: {
        if (!timelineModel)
            return false;
        var selIds = timelineModel.selectedClipIds ?? [];
        return selIds.length > 0 || (timelineModel.selectedClipId ?? "") !== "" || clickedClipId.length > 0;
    }
    readonly property int selectionCount: timelineModel?.selectedClipIds?.length ?? (hasClipSelection ? 1 : 0)
    readonly property bool isSingleClip: selectionCount === 1
    readonly property bool canPaste: timelineModel ? (typeof timelineModel.canPaste !== "undefined" ? timelineModel.canPaste : true) : false

    signal cutRequested
    signal copyRequested
    signal pasteRequested(real targetFrame, int targetTrack)
    signal splitRequested(real frame, int track)
    signal deleteRequested
    signal rippleDeleteRequested
    signal selectAllRequested
    signal toggleMuteRequested

    onClosed: {
        lockSubmenu.close();
    }

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
        id: popupLayout
        spacing: 4
        width: 230

        // =====================================================================
        // Action Tiles (Cut / Copy / Paste / Split)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/scissors.svg"
                text: "Cut"
                enabled: contextMenu.hasClipSelection && !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
                onClicked: {
                    contextMenu.close();
                    contextMenu.cutRequested();
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/copy.svg"
                text: "Copy"
                enabled: contextMenu.hasClipSelection
                onClicked: {
                    contextMenu.close();
                    contextMenu.copyRequested();
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/clipboard.svg"
                text: "Paste"
                enabled: contextMenu.canPaste && !contextMenu.isCurrentTrackLocked
                onClicked: {
                    contextMenu.close();
                    contextMenu.pasteRequested(contextMenu.clickedFrame, contextMenu.clickedTrack);
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/split.svg"
                text: "Split"
                enabled: !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
                onClicked: {
                    contextMenu.close();
                    contextMenu.splitRequested(contextMenu.clickedFrame, contextMenu.clickedTrack);
                }
            }
        }

        ContextSeparator {}

        // =====================================================================
        // Linking Operations
        // =====================================================================
        ContextMenuRow {
            visible: contextMenu.hasClipSelection && (contextMenu.canLinkCurrentSelection || contextMenu.selectionCount >= 2)
            iconSource: "qrc:/assets/icons/link.svg"
            text: "Link Clips"
            shortcutText: "Ctrl+L"
            enabled_: contextMenu.canLinkCurrentSelection && !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
            onClicked: {
                contextMenu.close();
                if (contextMenu.timelineModel) {
                    contextMenu.timelineModel.linkSelectedClips();
                }
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasClipSelection && (contextMenu.isCurrentClipLinked || contextMenu.canUnlinkCurrentSelection)
            iconSource: "qrc:/assets/icons/unlink.svg"
            text: "Unlink Clips"
            shortcutText: "Ctrl+Shift+L"
            enabled_: (contextMenu.isCurrentClipLinked || contextMenu.canUnlinkCurrentSelection) && !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
            onClicked: {
                contextMenu.close();
                if (contextMenu.timelineModel) {
                    contextMenu.timelineModel.unlinkSelectedClips();
                }
            }
        }

        ContextSeparator {
            visible: contextMenu.hasClipSelection && (contextMenu.canLinkCurrentSelection || contextMenu.isCurrentClipLinked || contextMenu.canUnlinkCurrentSelection)
        }

        // =====================================================================
        // Clip Operations
        // =====================================================================
        ContextMenuRow {
            visible: contextMenu.hasClipSelection
            iconSource: "qrc:/assets/icons/split.svg"
            text: "Split at Playhead"
            shortcutText: "Ctrl+K"
            enabled_: !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
            onClicked: {
                contextMenu.close();
                if (contextMenu.timelineModel && contextMenu.playbackManager) {
                    contextMenu.timelineModel.cutAtPlayhead(contextMenu.playbackManager.currentFrame);
                }
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasClipSelection && contextMenu.isSingleClip
            iconSource: "qrc:/assets/icons/mute.svg"
            text: contextMenu.clickedClipData?.isMuted ? "Unmute Clip" : "Mute Clip"
            onClicked: {
                contextMenu.close();
                contextMenu.toggleMuteRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasClipSelection
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Delete (Lift)"
            shortcutText: "Del"
            destructive: true
            enabled_: !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
            onClicked: {
                contextMenu.close();
                contextMenu.deleteRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasClipSelection
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Ripple Delete"
            shortcutText: "Shift+Del"
            destructive: true
            enabled_: !contextMenu.isCurrentClipLocked && !contextMenu.isCurrentTrackLocked
            onClicked: {
                contextMenu.close();
                contextMenu.rippleDeleteRequested();
            }
        }

        ContextSeparator {
            visible: contextMenu.hasClipSelection
        }

        // =====================================================================
        // Lock / Unlock Submenu Item
        // =====================================================================
        ContextMenuRow {
            id: lockSubmenuRow
            iconSource: "qrc:/assets/icons/lock.svg"
            text: "Lock / Unlock"
            showArrow: true
            onHoveredChanged: {
                if (isHovered) {
                    var globalPt = lockSubmenuRow.mapToItem(Overlay.overlay, lockSubmenuRow.width, 0);
                    lockSubmenu.openAt(globalPt.x - 4, globalPt.y - 4);
                }
            }
            onClicked: {
                var globalPt = lockSubmenuRow.mapToItem(Overlay.overlay, lockSubmenuRow.width, 0);
                lockSubmenu.openAt(globalPt.x - 4, globalPt.y - 4);
            }
        }

        ContextSeparator {}

        // =====================================================================
        // Global Operations
        // =====================================================================
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/select-all.svg"
            text: "Select All"
            shortcutText: "Ctrl+A"
            onClicked: {
                contextMenu.close();
                contextMenu.selectAllRequested();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/magnet.svg"
            text: (contextMenu.timelineModel && contextMenu.timelineModel.snappingEnabled) ? "Disable Snapping" : "Enable Snapping"
            shortcutText: "N"
            onClicked: {
                contextMenu.close();
                if (contextMenu.timelineModel) {
                    contextMenu.timelineModel.snappingEnabled = !contextMenu.timelineModel.snappingEnabled;
                }
            }
        }
    }

    // =========================================================================
    // Cascading Lock Submenu
    // =========================================================================
    Popup {
        id: lockSubmenu
        parent: Overlay.overlay
        modal: false
        focus: true
        padding: 6

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 10

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }
        }

        contentItem: ColumnLayout {
            spacing: 3
            width: 200

            // 1. Lock/Unlock Clip
            ContextMenuRow {
                visible: contextMenu.hasClipSelection && contextMenu.clickedClipId.length > 0
                iconSource: "qrc:/assets/icons/lock.svg"
                text: contextMenu.isCurrentClipLocked ? "Unlock Selected Clip" : "Lock Selected Clip"
                onClicked: {
                    lockSubmenu.close();
                    contextMenu.close();
                    if (contextMenu.timelineModel && contextMenu.clickedClipId.length > 0) {
                        contextMenu.timelineModel.toggleClipLock(contextMenu.clickedClipId);
                    }
                }
            }

            // 2. Lock/Unlock Current Track
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/lock.svg"
                text: contextMenu.isCurrentTrackLocked ? "Unlock Track " + (contextMenu.clickedTrack + 1) : "Lock Track " + (contextMenu.clickedTrack + 1)
                onClicked: {
                    lockSubmenu.close();
                    contextMenu.close();
                    if (contextMenu.timelineModel) {
                        contextMenu.timelineModel.toggleTrackLock(contextMenu.clickedTrack);
                    }
                }
            }

            ContextSeparator {}

            // 3. Lock All Tracks
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/lock.svg"
                text: "Lock All Tracks"
                onClicked: {
                    lockSubmenu.close();
                    contextMenu.close();
                    if (contextMenu.timelineModel) {
                        var count = contextMenu.timelineModel.rowCount();
                        for (var t = 0; t < count; ++t) {
                            contextMenu.timelineModel.setTrackLocked(t, true);
                        }
                    }
                }
            }

            // 4. Unlock All Tracks
            ContextMenuRow {
                iconSource: "qrc:/assets/icons/lock.svg"
                text: "Unlock All Tracks"
                onClicked: {
                    lockSubmenu.close();
                    contextMenu.close();
                    if (contextMenu.timelineModel) {
                        var count = contextMenu.timelineModel.rowCount();
                        for (var t = 0; t < count; ++t) {
                            contextMenu.timelineModel.setTrackLocked(t, false);
                        }
                    }
                }
            }
        }

        function openAt(targetX, targetY) {
            if (!Overlay.overlay)
                return;
            if (targetX + width > Overlay.overlay.width - 8) {
                targetX = contextMenu.x - width + 4;
            }
            x = Math.max(8, Math.min(targetX, Overlay.overlay.width - width - 8));
            y = Math.max(8, Math.min(targetY, Overlay.overlay.height - height - 8));
            open();
        }
    }

    transformOrigin: Item.TopLeft

    property real requestedX: 0
    property real requestedY: 0

    function reposition() {
        if (!Overlay.overlay)
            return;
        x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
        y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
    }

    onAboutToShow: reposition()
    onImplicitWidthChanged: if (visible)
        reposition()
    onImplicitHeightChanged: if (visible)
        reposition()

    function openAt(screenX, screenY, frame, trackIdx, clipData) {
        requestedX = screenX;
        requestedY = screenY;
        clickedFrame = frame !== undefined ? frame : 0;
        clickedTrack = trackIdx !== undefined ? trackIdx : 0;
        clickedClipData = clipData !== undefined ? clipData : null;
        clickedClipId = clipData ? (clipData.clipId ?? "") : (timelineModel?.selectedClipId ?? "");

        // Query Live C++ State
        isCurrentTrackLocked = timelineModel ? timelineModel.isTrackLocked(clickedTrack) : false;
        isCurrentClipLocked = (timelineModel && clickedClipId.length > 0) ? timelineModel.isClipOrGroupLocked(clickedClipId) : false;
        isCurrentClipLinked = (timelineModel && clickedClipId.length > 0) ? (timelineModel.getLinkedClipIds(clickedClipId).length > 1) : false;
        canLinkCurrentSelection = timelineModel ? timelineModel.canLinkSelection() : false;
        canUnlinkCurrentSelection = timelineModel ? timelineModel.canUnlinkSelection() : false;

        reposition();
        open();
    }

    component ContextActionTile: Rectangle {
        id: tile
        property string iconSource
        property string text
        signal clicked

        implicitWidth: 50
        implicitHeight: 50
        radius: 8
        color: !tile.enabled ? "#151515" : tileMouse.containsMouse ? "#252525" : "#202020"
        border.color: tileMouse.containsMouse ? "#353535" : "#202020"
        border.width: 1
        opacity: tile.enabled ? 1.0 : 0.38

        Column {
            anchors.centerIn: parent
            spacing: 4

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 17
                height: 17
                source: tile.iconSource
                sourceSize: Qt.size(17, 17)
                opacity: tile.enabled ? 0.9 : 0.45
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.text
                color: "#ffffff"
                font.pixelSize: 10
                opacity: tile.enabled ? 1.0 : 0.45
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component ContextMenuRow: Rectangle {
        id: row
        property string iconSource
        property string text
        property string shortcutText: ""
        property bool destructive: false
        property bool showArrow: false
        property bool enabled_: true
        readonly property bool isHovered: rowMouse.containsMouse
        signal hoveredChanged(bool isHovered)
        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 8
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "transparent"
        opacity: row.enabled_ ? 1.0 : 0.38

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 10

            Image {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: row.iconSource
                sourceSize: Qt.size(16, 16)
                opacity: row.enabled_ ? 0.9 : 0.4
            }

            Text {
                Layout.fillWidth: true
                text: row.text
                color: row.destructive ? "#e06b6b" : "#ffffff"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                visible: row.showArrow
                text: "›"
                color: "#888888"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: !row.showArrow && row.shortcutText.length > 0
                text: row.shortcutText
                color: "#777777"
                font.pixelSize: 11
                font.family: "Monospace"
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled_
            cursorShape: Qt.PointingHandCursor
            onEntered: row.hoveredChanged(true)
            onExited: row.hoveredChanged(false)
            onClicked: row.clicked()
        }
    }

    component ContextSeparator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 7
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: "#2d2d2d"
        }
    }
}
