import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import Xyla 1.0
import "../components"

Item {
    id: root

    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null

    property bool isListView: false
    property int selectedItemIndex: -1
    property real gridCellSize: 195

    readonly property color bgDark: "#141414"
    readonly property color bgCard: "#1f1f20"
    readonly property color bgCardHover: "#2a2a2c"
    readonly property color bgCardSelected: "#232d42"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#888888"
    readonly property color accentColor: "#2555D3"
    readonly property color borderColor: "#282829"

    function urlToLocalPath(urlVal) {
        if (!urlVal)
            return "";
        var str = urlVal.toString().trim();
        if (str.startsWith("//"))
            return "";

        if (str.startsWith("file://")) {
            var path = str.replace(/^file:\/\//, "");
            path = decodeURIComponent(path);
            if (/^\/[a-zA-Z]:/.test(path))
                path = path.substring(1);
            return path;
        }

        if (str.startsWith("/") && !str.startsWith("//"))
            return decodeURIComponent(str);
        if (/^[a-zA-Z]:[/\\]/.test(str))
            return decodeURIComponent(str);
        return "";
    }

    // Custom File/Folder Dialog
    XylaFolderDialog {
        id: folderDialog
        returnType: "file"
        selectMultiple: true
        onFolderSelected: function (path) {
            if (!root.activeMediaPool)
                return;
            if (path && path.length > 0) {
                var currentBin = root.activeMediaBinModel ? root.activeMediaBinModel.currentBinId : "root";
                root.activeMediaPool.importFilesAsync([path], currentBin);
            }
        }
    }

    // Context Menu Popup
Popup {
    id: contextMenu
    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 8

    property bool hasSelection: root.selectedItemIndex >= 0
    property bool selectionIsFolder: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            return it ? !!it.isFolder : false;
        }
        return false;
    }
    property bool selectionIsFile: hasSelection && !selectionIsFolder
    property var clipboardAsset: null
    property bool canPaste: clipboardAsset !== null
    property int selectionCount: hasSelection ? 1 : 0

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

    onCutRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            if (it) {
                contextMenu.clipboardAsset = {
                    item: it,
                    isCut: true,
                    sourceIndex: root.selectedItemIndex
                };
            }
        }
    }

    onCopyRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            if (it) {
                contextMenu.clipboardAsset = {
                    item: it,
                    isCut: false,
                    sourceIndex: -1
                };
            }
        }
    }

    onPasteRequested: {
        if (!contextMenu.clipboardAsset || !root.activeMediaBinModel)
            return;
        var curBin = root.activeMediaBinModel.currentBinId || "root";
        var item = contextMenu.clipboardAsset.item;
        if (contextMenu.clipboardAsset.isCut) {
            if (root.activeMediaBinModel.moveAsset) {
                root.activeMediaBinModel.moveAsset(contextMenu.clipboardAsset.sourceIndex, curBin);
            }
            contextMenu.clipboardAsset = null;
        } else if (item && item.path) {
            if (root.activeMediaPool) {
                root.activeMediaPool.importFilesAsync([item.path], curBin);
            }
        }
    }

    onOpenRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            if (it && it.isFolder) {
                root.activeMediaBinModel.currentBinId = it.id;
                root.selectedItemIndex = -1;
            }
        }
    }

    onRenameRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            var curName = it ? (it.name || "") : "";
            renameDialogInput.text = curName;
            renameDialog.targetIndex = root.selectedItemIndex;
            renameDialog.open();
        }
    }

    onDeleteRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            root.activeMediaBinModel.removeAsset(root.selectedItemIndex);
            root.selectedItemIndex = -1;
        }
    }

    onNewFolderRequested: {
        if (root.activeMediaBinModel) {
            root.activeMediaBinModel.createFolder("New Folder");
        }
    }

    onSelectAllRequested: {
        if (root.activeMediaBinModel && root.activeMediaBinModel.count > 0) {
            root.selectedItemIndex = 0;
        }
    }

    onPropertiesRequested: {
        if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
            var it = root.activeMediaBinModel.get(root.selectedItemIndex);
            if (it) {
                propDialog.assetName = it.name || "Unknown";
                propDialog.assetPath = it.path || "-";
                propDialog.assetDuration = it.duration || "-";
                propDialog.assetResolution = it.resolution || "-";
                propDialog.assetType = it.isFolder ? "Folder Bin" : "Media Clip";
                propDialog.open();
            }
        }
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

        // Cut / Copy / Paste Tiles (Shown when item is selected or clipboard has asset)
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: contextMenu.hasActionTiles

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

        // Custom Pill Track Zoom Slider (Shown on blank space when in Grid mode)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: 4
            visible: !contextMenu.hasActionTiles && !root.isListView

            Text {
                text: "Grid Size"
                color: "#a0a0a0"
                font.pixelSize: 11
                font.weight: Font.Medium
                Layout.leftMargin: 2
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaIconButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    iconSource: "qrc:/assets/icons/zoom-out.svg"
                    ghost: true
                    onClicked: sizeSlider.value = Math.max(sizeSlider.from, sizeSlider.value - 20)
                }

                Slider {
                    id: sizeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    from: 130
                    to: 260
                    value: root.gridCellSize
                    onValueChanged: root.gridCellSize = value

                    background: Rectangle {
                        id: trackGroove
                        x: sizeSlider.leftPadding
                        y: sizeSlider.topPadding + (sizeSlider.availableHeight - height) / 2
                        implicitWidth: 140
                        implicitHeight: 24
                        width: sizeSlider.availableWidth
                        height: implicitHeight
                        radius: 8
                        color: "#232323"
                        clip: true

                        Rectangle {
                            id: progressFill
                            width: Math.max(8, sizeSlider.position * parent.width)
                            height: parent.height
                            topLeftRadius: 8
                            bottomLeftRadius: 8
                            topRightRadius: 4
                            bottomRightRadius: 4
                            color: "#d8d8d8"

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 18
                                radius: 2.5
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
                    implicitWidth: 28
                    implicitHeight: 28
                    iconSource: "qrc:/assets/icons/zoom-in.svg"
                    ghost: true
                    onClicked: sizeSlider.value = Math.min(sizeSlider.to, sizeSlider.value + 20)
                }
            }
        }

        ContextSeparator {
          visible: contextMenu.hasActionTiles || !root.isListView
        }

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

    property real requestedX: 0
    property real requestedY: 0

    function reposition() {
        if (!Overlay.overlay)
            return;
        x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
        y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
    }

    onImplicitWidthChanged: if (visible) reposition()
    onImplicitHeightChanged: if (visible) reposition()

    function openAt(screenX, screenY) {
        requestedX = screenX;
        requestedY = screenY;
        reposition();
        open();
    }
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

    // Helper Rename Dialog
    Dialog {
        id: renameDialog
        anchors.centerIn: parent
        modal: true
        title: "Rename Asset"
        property int targetIndex: -1

        background: Rectangle {
            color: "#1e1e20"
            border.color: "#353538"
            radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 10
            TextField {
                id: renameDialogInput
                Layout.fillWidth: true
                color: "#ffffff"
                selectByMouse: true
                background: Rectangle {
                    color: "#121212"
                    border.color: renameDialogInput.activeFocus ? "#2555D3" : "#303030"
                    radius: 4
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button {
                    text: "Cancel"
                    onClicked: renameDialog.close()
                }
                Button {
                    text: "Apply"
                    onClicked: {
                        if (root.activeMediaBinModel && renameDialog.targetIndex >= 0 && renameDialogInput.text.trim() !== "") {
                            if (root.activeMediaBinModel.renameAsset) {
                                root.activeMediaBinModel.renameAsset(renameDialog.targetIndex, renameDialogInput.text.trim());
                            } else {
                                var it = root.activeMediaBinModel.get(renameDialog.targetIndex);
                                if (it)
                                    it.name = renameDialogInput.text.trim();
                            }
                        }
                        renameDialog.close();
                    }
                }
            }
        }
    }

    // Helper Properties Dialog
    Dialog {
        id: propDialog
        anchors.centerIn: parent
        modal: true
        title: "Asset Properties"
        property string assetName: ""
        property string assetPath: ""
        property string assetDuration: ""
        property string assetResolution: ""
        property string assetType: ""

        background: Rectangle {
            color: "#1e1e20"
            border.color: "#353538"
            radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 6
            Text {
                text: "Name: " + propDialog.assetName
                color: "#ffffff"
                font.pixelSize: 12
            }
            Text {
                text: "Type: " + propDialog.assetType
                color: "#aaaaaa"
                font.pixelSize: 11
            }
            Text {
                text: "Resolution: " + propDialog.assetResolution
                color: "#aaaaaa"
                font.pixelSize: 11
            }
            Text {
                text: "Duration: " + propDialog.assetDuration
                color: "#aaaaaa"
                font.pixelSize: 11
            }
            Text {
                text: "Path: " + propDialog.assetPath
                color: "#777777"
                font.pixelSize: 10
                elide: Text.ElideMiddle
                Layout.maximumWidth: 320
            }
            Button {
                Layout.alignment: Qt.AlignRight
                text: "Close"
                onClicked: propDialog.close()
            }
        }
    }

    // Panel Background
    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    // INFO: Main Media Panel Container
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // INFO: Header Toolbar
        RowLayout {
            id: toolbarRow
            Layout.fillWidth: true
            spacing: 6

            // INFO: Add button
            XylaIconButton {
                implicitWidth: 30
                implicitHeight: 30
                iconSource: "qrc:/assets/icons/plus.svg"
                primary: true
                onClicked: folderDialog.open()
            }

            // INFO: Settings button
            XylaIconButton {
                implicitWidth: 30
                implicitHeight: 30
                iconSource: "qrc:/assets/icons/settings.svg"
                // primary: true
                onClicked: folderDialog.open()
            }

            // INFO: Up folder navigation / Bin Title
            RowLayout {
                spacing: 6
                visible: root.activeMediaBinModel && root.activeMediaBinModel.currentBinId !== "root"

                XylaIconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    iconSource: "qrc:/assets/icons/arrow-up.svg"
                    onClicked: {
                        if (root.activeMediaBinModel) {
                            root.activeMediaBinModel.currentBinId = "root";
                        }
                    }
                }

                Text {
                    text: root.activeMediaBinModel ? root.activeMediaBinModel.currentBinId : ""
                    color: root.textSecondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.maximumWidth: 200
                //     font.weight: Font.DemiBold
                }
            }

            // INFO: Horizontal space filler
            Item {
                Layout.minimumWidth: 50
                Layout.fillWidth: true
            }

            // INFO: Sort Select Dropdown
            XylaSelect {
                id: sortComboBox
                Layout.preferredWidth: 100
                implicitHeight: 32
                icon: "qrc:/assets/icons/sort.svg"
                activeFocusOnTab: false
                model: ["Name", "Duration", "Path"]
                onActivated: function (index) {
                    if (!root.activeMediaBinModel)
                        return;
                    root.activeMediaBinModel.setSortRole(index);
                }
            }

            // INFO: Sort Order Toggle
            XylaIconButton {
                id: sortOrderToggle
                implicitWidth: 32
                implicitHeight: 32
                property bool isAscending: true
                iconSource: "" 

                onClicked: {
                    isAscending = !isAscending;
                    if (root.activeMediaBinModel) {
                        root.activeMediaBinModel.setSortAscending(isAscending);
                    }
                }

                Image {
                    id: sortIcon
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: "qrc:/assets/icons/sort-ascending.svg"
                    fillMode: Image.PreserveAspectFit

                    // Rotates 180 degrees when descending, 0 degrees when ascending
                    rotation: sortOrderToggle.isAscending ? 0 : 180

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 360
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
            // XylaIconButton {
            //     id: sortOrderToggle
            //     implicitWidth: 32
            //     implicitHeight: 32
            //     property bool isAscending: true
            //     // Removed static iconSource so custom animated Item renders cleanly
            //     iconSource: "" 
            //
            //     onClicked: {
            //         isAscending = !isAscending;
            //         if (root.activeMediaBinModel) {
            //             root.activeMediaBinModel.setSortAscending(isAscending);
            //         }
            //     }
            //
            //     Item {
            //         anchors.fill: parent
            //
            //         Image {
            //             id: ascendingIcon
            //             anchors.centerIn: parent
            //             width: 18
            //             height: 18
            //             source: "qrc:/assets/icons/sort-ascending.svg"
            //             fillMode: Image.PreserveAspectFit
            //
            //             opacity: sortOrderToggle.isAscending ? 1 : 0
            //             scale: sortOrderToggle.isAscending ? 1 : 0.7
            //
            //             Behavior on opacity {
            //                 NumberAnimation {
            //                     duration: 340
            //                     easing.type: Easing.OutCubic
            //                 }
            //             }
            //
            //             Behavior on scale {
            //                 NumberAnimation {
            //                     duration: 360
            //                     easing.type: Easing.OutBack
            //                 }
            //             }
            //         }
            //
            //         Image {
            //             id: descendingIcon
            //             anchors.centerIn: parent
            //             width: 18
            //             height: 18
            //             source: "qrc:/assets/icons/sort-descending.svg"
            //             fillMode: Image.PreserveAspectFit
            //
            //             opacity: sortOrderToggle.isAscending ? 0 : 1
            //             scale: sortOrderToggle.isAscending ? 0.7 : 1
            //
            //             Behavior on opacity {
            //                 NumberAnimation {
            //                     duration: 340
            //                     easing.type: Easing.OutCubic
            //                 }
            //             }
            //
            //             Behavior on scale {
            //                 NumberAnimation {
            //                     duration: 360
            //                     easing.type: Easing.OutBack
            //                 }
            //             }
            //         }
            //     }
            // }

            // View Mode Segmented Toggle
            // Small Inverted "^" (Dropdown Chevron) Resize Invoker
// Unified View Mode Toggle + Size Dropdown Group
            // Row {
            //     spacing: 0
            //     Layout.alignment: Qt.AlignVCenter

                // INFO: Segmented Toggle (List / Grid)
                XylaSegmentedToggle {
                    id: viewModeToggle
                    implicitHeight: 32
                    currentIndex: root.isListView ? 0 : 1
                    options: [
                        {
                            icon: "qrc:/assets/icons/list.svg",
                            value: "list"
                        },
                        {
                            icon: "qrc:/assets/icons/layout-grid.svg",
                            value: "grid"
                        }
                    ]
                    onOptionSelected: (index, value) => {
                        root.isListView = (value === "list");
                    }
                }

                // Chevron Dropdown Button for Grid Zoom Popup
//                 Rectangle {
//                     id: resizeInvokerBtn
//                     implicitWidth: 20
//                     implicitHeight: 32
//                     radius: 4
//                     color: "transparent" // sizePopup.opened ? "#2c2c2e" : (invokerMouse.containsMouse && enabled ? "#222224" : "transparent")
//                     enabled: !root.isListView
//                     opacity: enabled ? 1.0 : 0.35
//
//                     Item {
//                         id: chevronContainer
//                         anchors.centerIn: parent
//                         width: 10
//                         height: 10
//                         rotation: sizePopup.opened ? 180 : 0
//
//                         Behavior on rotation {
//                             NumberAnimation {
//                                 duration: 200
//                                 easing.type: Easing.OutCubic
//                             }
//                         }
//
//                         Image {
//                             id: chevronIcon
//                             anchors.fill: parent
//                             source: "qrc:/assets/icons/chevron-down.svg"
//                             fillMode: Image.PreserveAspectFit
//                             smooth: true
//                             visible: false
//                         }
//
//                         MultiEffect {
//                             source: chevronIcon
//                             anchors.fill: chevronIcon
//                             colorization: 1.0
//                             colorizationColor: (invokerMouse.containsMouse && resizeInvokerBtn.enabled) || sizePopup.opened ? "#ffffff" : "#888888"
//
//                             Behavior on colorizationColor {
//                                 ColorAnimation {
//                                     duration: 120
//                                 }
//                             }
//                         }
//                     }
//
//                     MouseArea {
//                         id: invokerMouse
//                         anchors.fill: parent
//                         hoverEnabled: true
//                         cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
//                         onClicked: {
//                             if (sizePopup.opened) sizePopup.close();
//                             else sizePopup.open();
//                         }
//                     }
//
//                     // Zoom Popup anchored directly under the invoker
//                     Popup {
//                         id: sizePopup
//                         y: resizeInvokerBtn.height + 4
//                         x: resizeInvokerBtn.width - width
//                         width: 280
//                         height: 48
//                         padding: 6
//                         horizontalPadding: 8
//                         modal: false
//                         focus: true
//                         closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
//
//                         background: Rectangle {
//                             color: "#161616"
//                             border.color: "#282828"
//                             border.width: 1
//                             radius: 10
//
//                             layer.enabled: true
//                             layer.effect: MultiEffect {
//                                 shadowEnabled: true
//                                 shadowColor: "#a0000000"
//                                 shadowBlur: 0.7
//                                 shadowVerticalOffset: 6
//                             }
//                         }
//
//                         enter: Transition {
//                             NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
//                             NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
//                         }
//
//                         exit: Transition {
//                             NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 110; easing.type: Easing.OutCubic }
//                             NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 110; easing.type: Easing.OutCubic }
//                         }
//
//                         contentItem: RowLayout {
//                             anchors.fill: parent
//                             anchors.leftMargin: 10
//                             anchors.rightMargin: 10
//                             spacing: 8
//
//                             // Zoom Out Button
//                             XylaIconButton {
//                                 implicitWidth: 30
//                                 implicitHeight: 30
//                                 iconSource: "qrc:/assets/icons/zoom-out.svg"
//                                 ghost: true
//                                 onClicked: sizeSlider.value = Math.max(sizeSlider.from, sizeSlider.value - 20)
//                             }
//
//                             // Custom Pill Track Zoom Slider
//                             Slider {
//                                 id: sizeSlider
//                                 Layout.fillWidth: true
//                                 Layout.preferredHeight: 32
//                                 from: 130
//                                 to: 260
//                                 value: root.gridCellSize
//                                 // onMoved: root.gridCellSize = value
//                                 onValueChanged: root.gridCellSize = value
//
//                                 background: Rectangle {
//                                     id: trackGroove
//                                     x: sizeSlider.leftPadding
//                                     y: sizeSlider.topPadding + (sizeSlider.availableHeight - height) / 2
//                                     implicitWidth: 150
//                                     implicitHeight: 28
//                                     width: sizeSlider.availableWidth
//                                     height: implicitHeight
//                                     radius: 10 // height / 2
//                                     color: "#232323"
//                                     clip: true
//
//                                     // Light Pill Progress Fill (Matches reference screenshot)
//                                     Rectangle {
//                                         id: progressFill
//                                         width: Math.max(10, sizeSlider.position * parent.width)
//                                         // width: Math.max(parent.height, sizeSlider.visualPosition * parent.width)
//                                         height: parent.height
//                                         // radius: 10 // height / 2
//
//                                         topLeftRadius: 10 // height / 2
//                                         bottomLeftRadius: 10 // height / 2
//
//                                         // Lower/subtle curvature on the right thumb end
//                                         topRightRadius: 5
//                                         bottomRightRadius: 5
//                                         color: "#d8d8d8"
//
//                                         // Dark vertical pill-shaped indicator inside the handle end
//                                         Rectangle {
//                                             anchors.right: parent.right
//                                             anchors.rightMargin: 2
//                                             anchors.verticalCenter: parent.verticalCenter
//                                             width: 6
//                                             height: 22
//                                             radius: 3
//                                             color: "#232323"
//                                         }
//                                     }
//                                 }
//
// handle: Item {
//     x: sizeSlider.leftPadding + sizeSlider.visualPosition * sizeSlider.availableWidth
//     implicitWidth: 0
//     implicitHeight: 0
//     visible: false
// }
//                                 // handle: Item {
//                                 //     x: sizeSlider.leftPadding + sizeSlider.visualPosition * (sizeSlider.availableWidth - width)
//                                 //     // y: sizeSlider.topPadding + (sizeSlider.availableHeight - height) / 2
//                                 //     implicitWidth: 28
//                                 //     implicitHeight: 28
//                                 // }
//                             }
//
//                             // Zoom In Button
//                             XylaIconButton {
//                                 implicitWidth: 30
//                                 implicitHeight: 30
//                                 iconSource: "qrc:/assets/icons/zoom-in.svg"
//                                 ghost: true
//                                 onClicked: sizeSlider.value = Math.min(sizeSlider.to, sizeSlider.value + 20)
//                             }
//                         }
//                     }
//                 }
            // }

            // Primary Blue Import Button (Matches 32x32)
            // XylaIconButton {
            //     implicitWidth: 30
            //     implicitHeight: 30
            //     iconSource: "qrc:/assets/icons/plus.svg"
            //     primary: true
            //     onClicked: folderDialog.open()
            // }

            // INFO: Search Toggle Button
            XylaIconButton {
                id: searchBtn
                implicitWidth: 32
                implicitHeight: 32
                iconSource: "qrc:/assets/icons/search.svg"
                primary: searchPopup.opened || searchInput.text !== ""
                property bool searchPopupJustClosed: false

                onClicked: {
                    if (searchPopup.opened) {
                        searchPopup.close();
                    } else {
                        searchPopup.open();
                    }
                }

                // Directly under the search button
                Popup {
                    id: searchPopup
                    y: searchBtn.height + 6
                    x: searchBtn.width - (width)
                    width: 230
                    height: 34
                    padding: 0
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

                    onOpened: searchInput.forceActiveFocus()
                    onAboutToHide: searchInput.focus = false

                    background: Rectangle {
                        color: "#181818"
                        border.color: searchInput.activeFocus ? root.accentColor : "#2e2e30"
                        border.width: 1
                        radius: 6

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
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.95
                            to: 1.0
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    exit: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0
                            to: 0.0
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 1.0
                            to: 0.95
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search bin..."
                            placeholderTextColor: "#606060"
                            color: "#ffffff"
                            font.pixelSize: 11
                            background: Item {}
                            selectByMouse: true

                            onTextChanged: {
                                if (root.activeMediaBinModel) {
                                    root.activeMediaBinModel.searchFilter = text;
                                }
                            }

                            Keys.onEscapePressed: {
                                text = "";
                                if (root.activeMediaBinModel) {
                                    root.activeMediaBinModel.searchFilter = "";
                                }
                                searchPopup.close();
                            }

                            Keys.onReturnPressed: (event) => {
                                searchPopup.close();
                                event.accepted = true;
                            }

                            Keys.onEnterPressed: (event) => {
                                searchPopup.close();
                                event.accepted = true;
                            }
                        }

                        // Quick clear button
                        Text {
                            text: "✕"
                            color: "#777777"
                            font.pixelSize: 11
                            visible: searchInput.text.length > 0
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }
            }

        }

        // Drop Area & Media Container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: function (drag) {
                    if (drag.source !== null) {
                        drag.accepted = false;
                        return;
                    }
                    drag.acceptProposedAction();
                }

                onPositionChanged: function (drag) {
                    if (drag.source !== null) {
                        drag.accepted = false;
                        return;
                    }
                    drag.acceptProposedAction();
                }

                onDropped: function (drop) {
                    if (drop.source !== null)
                        return;
                    drop.acceptProposedAction();

                    if (!drop.hasUrls || drop.urls.length === 0 || !root.activeMediaPool)
                        return;

                    var rawPaths = [];
                    for (var i = 0; i < drop.urls.length; i++) {
                        rawPaths.push(drop.urls[i].toString());
                    }

                    var currentBin = root.activeMediaBinModel ? root.activeMediaBinModel.currentBinId : "root";
                    root.activeMediaPool.importFilesAsync(rawPaths, currentBin);
                }

                // Empty space context menu
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            root.selectedItemIndex = -1;
                            var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                            contextMenu.openAt(globalPoint.x, globalPoint.y, false);
                        }
                    }
                }

                // Drop Overlay Highlight
                Rectangle {
                    anchors.fill: parent
                    color: (dropArea.containsDrag && dropArea.drag.source === null) ? "#152555D3" : "transparent"
                    border.color: (dropArea.containsDrag && dropArea.drag.source === null) ? root.accentColor : "transparent"
                    border.width: 1.5
                    radius: 6
                    z: 10
                }

                // Stack View: List vs Grid
                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.isListView ? 0 : 1

                    // LIST VIEW
                    ListView {
                        id: listView
                        clip: true
                        spacing: 4
                        model: root.activeMediaBinModel

                        delegate: Rectangle {
                            id: listDelegateItem
                            width: listView.width
                            height: 36
                            radius: 6
                            color: root.selectedItemIndex === index ? root.bgCardSelected : (itemMouseArea.containsMouse ? root.bgCardHover : root.bgCard)
                            border.color: root.selectedItemIndex === index ? root.accentColor : root.borderColor
                            border.width: 1

                            Drag.active: itemMouseArea.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.keys: ["xyla/media-asset", "text/uri-list"]
                            Drag.source: listDelegateItem
                            Drag.mimeData: {
                                "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
                            }
                            Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
                            Drag.hotSpot.x: 16
                            Drag.hotSpot.y: 16
                            Drag.supportedActions: Qt.CopyAction

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Image {
                                    source: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }

                                Text {
                                    text: model.name || ""
                                    color: root.textPrimary
                                    font.pixelSize: 12
                                    font.weight: root.selectedItemIndex === index ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.resolution || ""
                                    color: "#777777"
                                    font.pixelSize: 10
                                    visible: !model.isFolder
                                }

                                Text {
                                    text: model.duration || ""
                                    color: "#aaaaaa"
                                    font.pixelSize: 11
                                    visible: !model.isFolder
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: listDummyDragTarget

                                Item {
                                    id: listDummyDragTarget
                                }

                                onClicked: function (mouse) {
                                    root.selectedItemIndex = index;
                                    if (mouse.button === Qt.RightButton) {
                                        var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        contextMenu.openAt(globalPoint.x, globalPoint.y, model.isFolder);
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton && model.isFolder) {
                                        root.activeMediaBinModel.currentBinId = model.id;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#505050"
                            font.pixelSize: 12
                            visible: listView.count === 0
                        }
                    }

                    // GRID VIEW
                    GridView {
                        id: gridView
                        clip: true
                        cellWidth: root.gridCellSize
                        cellHeight: root.gridCellSize * 0.90
                        model: root.activeMediaBinModel

                        delegate: Item {
                            id: gridDelegateItem
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            // Animated entrance properties
                            property real cardScale: 1.0
                            scale: cardScale
                            transformOrigin: Item.Center

                            Component.onCompleted: entranceAnim.restart()

                            // Re-trigger entrance animation when item model data changes (filtering, bin navigation)
                            Connections {
                                target: model
                                function onNameChanged() { entranceAnim.restart() }
                                function onPathChanged() { entranceAnim.restart() }
                            }

                            ParallelAnimation {
                                id: entranceAnim

                                ScriptAction {
                                    script: gridDelegateItem.cardScale = 0.0
                                }

                                NumberAnimation {
                                    target: gridDelegateItem
                                    property: "cardScale"
                                    from: 0.8
                                    to: 1.0
                                    duration: 180
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            Drag.active: cardMouseArea.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.keys: ["xyla/media-asset", "text/uri-list"]
                            Drag.source: gridDelegateItem
                            Drag.mimeData: {
                                "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
                            }
                            Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
                            Drag.hotSpot.x: 16
                            Drag.hotSpot.y: 16
                            Drag.supportedActions: Qt.CopyAction

                            // Main Card Container with padding & border styling
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 10
                                radius: 12
                                color: root.selectedItemIndex === index ? "#1c2538" : (cardMouseArea.containsMouse ? "#222225" : root.bgCard)
                                border.color: root.selectedItemIndex === index ? "#2555D3" : (cardMouseArea.containsMouse ? "#3a3a3d" : "#28282a")
                                border.width: root.selectedItemIndex === index ? 1.5 : 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 8

                                    // Thumbnail / Icon viewport frame
                                    Rectangle {
                                        id: thumbFrame
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 8
                                        color: "#121213"

                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                            maskSource: ShaderEffectSource {
                                                sourceItem: Rectangle {
                                                    width: thumbFrame.width
                                                    height: thumbFrame.height
                                                    radius: thumbFrame.radius
                                                }
                                            }
                                        }

                                        // Image/Video Thumbnail
                                        Image {
                                            anchors.fill: parent
                                            visible: !model.isFolder
                                            fillMode: Image.PreserveAspectCrop
                                            source: model.path ? "image://thumbnails/" + model.path + "?width=" + Math.round(root.gridCellSize * 1.5) : ""
                                            asynchronous: true
                                        }

                                        // Folder Bin Icon
                                        Image {
                                            anchors.centerIn: parent
                                            visible: model.isFolder
                                            source: "qrc:/assets/icons/folder.svg"
                                            sourceSize.width: Math.max(22, Math.min(46, root.gridCellSize * 0.3))
                                            sourceSize.height: Math.max(22, Math.min(46, root.gridCellSize * 0.3))
                                        }

                                        // Pill Duration Badge
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 4
                                            width: durationText.implicitWidth + 8
                                            height: 16
                                            radius: 4
                                            color: "#e60d0d0e"
                                            visible: !model.isFolder && model.duration !== undefined && model.duration !== ""

                                            Text {
                                                id: durationText
                                                anchors.centerIn: parent
                                                text: model.duration || ""
                                                color: "#ffffff"
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }

                                    // Card Title & Extension
                                    Text {
                                        Layout.bottomMargin: 2
                                        Layout.fillWidth: true
                                        text: model.name || ""
                                        color: root.selectedItemIndex === index ? "#ffffff" : "#c4c4c4"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: gridDummyDragTarget

                                Item {
                                    id: gridDummyDragTarget
                                }

                                onClicked: function (mouse) {
                                    root.selectedItemIndex = index;
                                    if (mouse.button === Qt.RightButton) {
                                        var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        contextMenu.openAt(globalPoint.x, globalPoint.y);
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton && model.isFolder) {
                                        root.activeMediaBinModel.currentBinId = model.id;
                                        root.selectedItemIndex = -1;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#555555"
                            font.pixelSize: 12
                            visible: gridView.count === 0
                        }
                    }
                }
            }
        }
    }
}
