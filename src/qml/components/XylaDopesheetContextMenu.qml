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

    property var dopesheetRoot: null
    property var timelineModel: null
    property string activeClipId: ""
    property string activePropertyId: ""
    property real clickedFrame: 0
    property bool hasSelectedKeyframe: false

    signal deleteKeyframeRequested
    signal clearAllKeyframesRequested
    signal setInterpolationRequested(int interpMode)

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
        // Action Tiles (Delete / Linear / Bezier / Hold)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: contextMenu.hasSelectedKeyframe

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/trash.svg"
                text: "Delete"
                onClicked: {
                    contextMenu.close();
                    contextMenu.deleteKeyframeRequested();
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/chart-line.svg"
                text: "Bezier"
                onClicked: {
                    contextMenu.close();
                    contextMenu.setInterpolationRequested(2);
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/line.svg"
                text: "Linear"
                onClicked: {
                    contextMenu.close();
                    contextMenu.setInterpolationRequested(1);
                }
            }

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/player-pause.svg"
                text: "Hold"
                onClicked: {
                    contextMenu.close();
                    contextMenu.setInterpolationRequested(0);
                }
            }
        }

        ContextSeparator {
            visible: contextMenu.hasSelectedKeyframe
        }

        // =====================================================================
        // Keyframe Operations
        // =====================================================================
        ContextMenuRow {
            visible: contextMenu.hasSelectedKeyframe
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Delete Selected Keyframes"
            shortcutText: "Del"
            destructive: true
            onClicked: {
                contextMenu.close();
                contextMenu.deleteKeyframeRequested();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Clear All Clip Keyframes"
            destructive: true
            onClicked: {
                contextMenu.close();
                contextMenu.clearAllKeyframesRequested();
            }
        }

        ContextSeparator {}

        // =====================================================================
        // Navigation
        // =====================================================================
        ContextMenuRow {
            iconSource: "qrc:/assets/icons/player-play.svg"
            text: "Go to Playhead"
            onClicked: {
                contextMenu.close();
                if (contextMenu.dopesheetRoot) {
                    contextMenu.dopesheetRoot.centerOnPlayhead();
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

    function openAt(screenX, screenY, clipId, propId, frame, hasKf) {
        requestedX = screenX;
        requestedY = screenY;
        activeClipId = clipId;
        activePropertyId = propId;
        clickedFrame = frame;
        hasSelectedKeyframe = hasKf;
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
