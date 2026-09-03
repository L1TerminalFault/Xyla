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

    readonly property bool hasClipSelection: {
        if (!timelineModel)
            return false;
        var selIds = timelineModel.selectedClipIds ?? [];
        return selIds.length > 0 || (timelineModel.selectedClipId ?? "") !== "";
    }
    readonly property int selectionCount: timelineModel?.selectedClipIds?.length ?? (hasClipSelection ? 1 : 0)
    readonly property bool isSingleClip: selectionCount === 1
    readonly property bool canPaste: timelineModel ? (typeof timelineModel.canPaste !== "undefined" ? timelineModel.canPaste : true) : false

    // Signals for timeline operations
    signal cutRequested
    signal copyRequested
    signal pasteRequested(real targetFrame, int targetTrack)
    signal duplicateRequested
    signal splitRequested(real frame, int track)
    signal deleteRequested
    signal rippleDeleteRequested
    signal rippleDeleteGapRequested(real gapStart, real gapEnd, int track)
    signal selectAllRequested
    signal toggleMuteRequested

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
        width: 240

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
                enabled: contextMenu.hasClipSelection
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
                enabled: contextMenu.canPaste
                onClicked: {
                    contextMenu.close();
                    contextMenu.pasteRequested(contextMenu.clickedFrame, contextMenu.clickedTrack);
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/split.svg"
                text: "Split"
                enabled: true
                onClicked: {
                    contextMenu.close();
                    contextMenu.splitRequested(contextMenu.clickedFrame, contextMenu.clickedTrack);
                }
            }
        }

        ContextSeparator {}

        // =====================================================================
        // Clip Specific Operations
        // =====================================================================
        ContextMenuRow {
            visible: contextMenu.hasClipSelection
            iconSource: "qrc:/assets/icons/split.svg"
            text: "Split at Playhead"
            shortcutText: "Ctrl+K"
            onClicked: {
                contextMenu.close();
                if (contextMenu.timelineModel && contextMenu.playbackManager) {
                    contextMenu.timelineModel.cutAtPlayhead(contextMenu.playbackManager.currentFrame);
                }
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasClipSelection && contextMenu.isSingleClip
            iconSource: "qrc:/assets/icons/volume-x.svg"
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
            onClicked: {
                contextMenu.close();
                contextMenu.rippleDeleteRequested();
            }
        }

        ContextSeparator {
            visible: contextMenu.hasClipSelection
        }

        // =====================================================================
        // Global Timeline Operations
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
        reposition();
        open();
    }

    component ContextActionTile: Rectangle {
        id: tile
        property string iconSource
        property string text
        signal clicked

        implicitWidth: 52
        implicitHeight: 52
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
                width: 18
                height: 18
                source: tile.iconSource
                sourceSize: Qt.size(18, 18)
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
        property bool enabled_: true
        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 8
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "transparent"

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
                visible: row.shortcutText.length > 0
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
