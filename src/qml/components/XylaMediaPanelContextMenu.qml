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
            let it = root.activeMediaBinModel.get(root.selectedItemIndex);
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

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: {
            contextMenu.close();
            contextMenu.renameRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+D"
        onActivated: {
            contextMenu.close();
            contextMenu.deleteRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: {
            contextMenu.close();
            contextMenu.newFolderRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+A"
        onActivated: {
            contextMenu.close();
            contextMenu.selectAllRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+I"
        onActivated: {
            contextMenu.close();
            folderDialog.open();
        }
    }

    Shortcut {
        sequence: "Ctrl+C"
        onActivated: {
            contextMenu.close();
            contextMenu.copyRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+V"
        onActivated: {
            contextMenu.close();
            contextMenu.pasteRequested();
        }
    }

    Shortcut {
        sequence: "Ctrl+X"
        onActivated: {
            contextMenu.close();
            contextMenu.cutRequested();
        }
    }

    contentItem: ColumnLayout {
        id: popupLayout
        spacing: 0
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
            tooltip: "Opens the selected folder and displays its contents"
            onClicked: {
                contextMenu.close();
                contextMenu.openRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasSelection && contextMenu.selectionCount === 1
            iconSource: "qrc:/assets/icons/edit.svg"
            text: "Rename"
            shortcut: "Ctrl+R"
            tooltip: "Changes the name of the selected file or folder"
            onClicked: {
                contextMenu.close();
                contextMenu.renameRequested();
            }
        }

        ContextMenuRow {
            visible: contextMenu.hasSelection
            iconSource: "qrc:/assets/icons/trash.svg"
            text: "Remove Asset"
            shortcut: "Ctrl+D"
            destructive: true
            tooltip: "Removes the selected asset from the current media panel"
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
            shortcut: "Ctrl+Shift+N"
            tooltip: "Creates a new folder in the current location"
            onClicked: {
                contextMenu.close();
                contextMenu.newFolderRequested();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/plus.svg"
            text: "Import Media..."
            shortcut: "Ctrl+I"
            tooltip: "Imports media into the current project"
            onClicked: {
                contextMenu.close();
                folderDialog.open();
            }
        }

        ContextMenuRow {
            iconSource: "qrc:/assets/icons/select-all.svg"
            text: "Select All"
            shortcut: "Ctrl+A"
            tooltip: "Selects all available files and folders"
            onClicked: {
                contextMenu.close();
                contextMenu.selectAllRequested();
            }
        }

        ContextSeparator {
            visible: selectionIsFile && contextMenu.hasSelection && contextMenu.selectionCount === 1
        }

        ContextMenuRow {
            visible: selectionIsFile && contextMenu.hasSelection && contextMenu.selectionCount === 1
            iconSource: "qrc:/assets/icons/info.svg"
            text: "Properties"
            tooltip: "Displays more info for the selected asset"
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
    onImplicitWidthChanged: if (visible)
        reposition()
    onImplicitHeightChanged: if (visible)
        reposition()

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
        // border.color: tileMouse.containsMouse ? "#353535" : "#202020"
        // border.width: 1
        opacity: tile.enabled ? 1.0 : 0.38

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

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
        property string shortcut: ""
        property bool destructive: false
        property bool showArrow: false
        property bool enabled_: true
        property string tooltip: ""

        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 12
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "#181818"

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        function getModifierIcon(key) {
            var cleanKey = key.trim().toLowerCase();

            if (cleanKey === "ctrl" || cleanKey === "control")
                return "qrc:/assets/icons/command.svg";

            if (cleanKey === "alt")
                return "qrc:/assets/icons/alt.svg";

            if (cleanKey === "shift")
                return "qrc:/assets/icons/shift.svg";

            return "";
        }

        HoverHandler {
            id: rowHover
        }

        XylaToolTip {
            visible: rowHover.hovered
            position: "right"
            text: row.tooltip
        }

        RowLayout {
            id: rowContent

            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 6
            anchors.bottomMargin: 6

            spacing: 10

            // ========================================================
            // ICON
            // ========================================================

            Item {
                id: iconContainer

                implicitWidth: 16
                implicitHeight: 16

                property int visibleWidth: visible ? 16 : 0

                visible: row.iconSource !== ""

                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg

                    anchors.fill: parent

                    source: row.iconSource

                    sourceSize: Qt.size(16, 16)

                    fillMode: Image.PreserveAspectFit

                    smooth: true

                    visible: false
                }

                MultiEffect {
                    anchors.fill: iconImg

                    source: iconImg

                    colorization: 1.0

                    colorizationColor: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"
                }
            }

            // ========================================================
            // TITLE
            // ========================================================

            Text {
                id: titleText

                text: row.text

                color: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"

                font.pixelSize: 12

                Layout.minimumWidth: 120
                Layout.fillWidth: true
                Layout.fillHeight: true

                verticalAlignment: Text.AlignVCenter

                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ========================================================
            // SHORTCUT
            // ========================================================

            Row {
                id: shortcutRow

                spacing: 4

                Layout.alignment: Qt.AlignVCenter

                visible: !row.showArrow && row.shortcut !== ""

                property var keyTokens: {
                    var rawShortcut = row.shortcut || "";

                    return rawShortcut !== "" ? rawShortcut.split("+") : [];
                }

                Repeater {
                    model: shortcutRow.keyTokens

                    delegate: Item {
                        id: tokenItem

                        property string keyText: modelData.trim()
                        property string iconSrc: row.getModifierIcon(keyText)
                        property bool isModifier: iconSrc !== ""
                        property bool hovered: tokenHover.containsMouse

                        implicitWidth: 20
                        implicitHeight: 20

                        // ------------------------------------------------
                        // KEY BACKGROUND
                        // ------------------------------------------------

                        Rectangle {
                            id: keyBackground

                            anchors.fill: parent

                            color: rowMouse.containsMouse ? "#353535" : "#141414"

                            radius: 5

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // ------------------------------------------------
                        // HOVER DETECTOR
                        // ------------------------------------------------

                        MouseArea {
                            id: tokenHover

                            anchors.fill: parent

                            hoverEnabled: true

                            acceptedButtons: Qt.NoButton
                        }

                        // ------------------------------------------------
                        // MODIFIER ICON
                        // ------------------------------------------------

                        Image {
                            id: modifierImg

                            anchors.centerIn: parent

                            width: 14
                            height: 14

                            source: tokenItem.iconSrc

                            sourceSize: Qt.size(14, 14)

                            fillMode: Image.PreserveAspectFit

                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: modifierImg

                            source: modifierImg

                            visible: tokenItem.isModifier

                            colorization: 1.0

                            colorizationColor: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

                            Behavior on colorizationColor {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // ------------------------------------------------
                        // NORMAL KEY
                        // ------------------------------------------------

                        Text {
                            id: letterLabel

                            anchors.centerIn: parent

                            visible: !tokenItem.isModifier

                            text: tokenItem.keyText

                            color: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

                            font.pixelSize: 10
                            font.weight: Font.DemiBold

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }

            // ========================================================
            // EXPAND ARROW
            // ========================================================

            Text {
                id: arrowText

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
        implicitHeight: 7 + 8
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
