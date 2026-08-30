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

    property var root
    property bool hasSelection: root.selectedIndices.length > 0
    property bool selectionIsFolder: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            return it ? !!it.isFolder : false;
        }
        return false;
    }
    property bool selectionIsFile: hasSelection && !selectionIsFolder
    property bool canPaste: root.clipboardAssets && root.clipboardAssets.length > 0
    property int selectionCount: root.selectedIndices.length

    // Evaluates whether any action tile in the upper row is active
    property bool hasActionTiles: hasSelection || canPaste

    signal cutRequested
    signal copyRequested
    signal pasteRequested
    signal openRequested
    signal renameRequested
    signal deleteRequested
    signal newFolderRequested
    signal selectAllRequested
    signal propertiesRequested

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

        // Cut / Copy / Paste Tiles (Shown when item is selected or clipboard has asset)
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            // visible: contextMenu.hasActionTiles

            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/scissors.svg"
                text: "Cut"
                enabled: contextMenu.hasSelection
                onClicked: {
                    contextMenu.close();
                    contextMenu.cutRequested();
                }
            }
            ContextActionTile {
                Layout.fillWidth: true
                iconSource: "qrc:/assets/icons/copy.svg"
                text: "Copy"
                enabled: contextMenu.hasSelection
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
                    contextMenu.pasteRequested();
                }
            }
        }

        ContextSeparator {}

        ContextMenuRow {
            visible: contextMenu.hasSelection && contextMenu.selectionCount === 1 && contextMenu.selectionIsFolder
            iconSource: "qrc:/assets/icons/folder-open.svg"
            text: "Open"
            onClicked: {
                contextMenu.close();
                contextMenu.openRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasSelection && contextMenu.selectionCount === 1
            iconSource: "qrc:/assets/icons/edit.svg"
            text: "Rename"
            onClicked: {
                contextMenu.close();
                contextMenu.renameRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasSelection
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Remove Asset"
            destructive: true
            onClicked: {
                contextMenu.close();
                contextMenu.deleteRequested();
            }
        }

        ContextSeparator {
            visible: contextMenu.hasSelection
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/folder-plus.svg"
            text: "New Folder"
            onClicked: {
                contextMenu.close();
                contextMenu.newFolderRequested();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/plus.svg"
            text: "Import Media..."
            onClicked: {
                contextMenu.close();
                folderDialog.open();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/select-all.svg"
            text: "Select All"
            onClicked: {
                contextMenu.close();
                contextMenu.selectAllRequested();
            }
        }

        ContextSeparator {
            visible: contextMenu.hasSelection
        }

        ContextMenuRow {
            visible: contextMenu.hasSelection
            iconSource: "qrc:/assets/icons/info.svg"
            text: "Properties"
            onClicked: {
                contextMenu.close();
                contextMenu.propertiesRequested();
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
    onImplicitWidthChanged: if (visible) reposition()
    onImplicitHeightChanged: if (visible) reposition()

    function openAt(screenX, screenY) {
        requestedX = screenX;
        requestedY = screenY;
        reposition();
        open();
    }

    component ContextActionTile: Rectangle {
        id: tile
        property string iconSource
        property string text
        signal clicked

        implicitWidth: 70
        implicitHeight: 62
        radius: 8
        color: !tile.enabled ? "#151515" : tileMouse.containsMouse ? "#252525" : "#202020"
        border.color: tileMouse.containsMouse ? "#353535" : "#202020"
        border.width: 1
        opacity: tile.enabled ? 1.0 : 0.38

        Column {
            anchors.centerIn: parent
            spacing: 5

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20
                height: 20
                source: tile.iconSource
                sourceSize: Qt.size(20, 20)
                opacity: tile.enabled ? 0.9 : 0.45
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.text
                color: "#ffffff"
                font.pixelSize: 11
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
        property bool destructive: false
        property bool showArrow: false
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
                Layout.preferredWidth: 17
                Layout.preferredHeight: 17
                source: row.iconSource
                sourceSize: Qt.size(17, 17)
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
                font.pixelSize: 20
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

