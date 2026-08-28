import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Xyla 1.0
import "../components"

Item {
    id: root

    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null

    property bool isListView: false
    property int selectedItemIndex: -1

    readonly property color bgDark: "#1a1a1a"
    readonly property color bgCard: "#252526"
    readonly property color textPrimary: "#ffffff"

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

    // Custom Folder Dialog
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

    // Context Menu for Right Click
    Menu {
        id: contextMenu

        MenuItem {
            text: "Import Media Files..."
            onTriggered: folderDialog.open()
        }

        MenuItem {
            text: "New Folder Bin..."
            onTriggered: {
                if (root.activeMediaBinModel) {
                    root.activeMediaBinModel.createFolder("New Bin");
                }
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Remove Asset"
            enabled: root.selectedItemIndex >= 0
            onTriggered: {
                if (root.activeMediaBinModel && root.selectedItemIndex >= 0) {
                    root.activeMediaBinModel.removeAsset(root.selectedItemIndex);
                    root.selectedItemIndex = -1;
                }
            }
        }
    }

    // Panel Background
    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header Toolbar
        RowLayout {
            id: toolbarRow
            Layout.fillWidth: true
            spacing: 6

            // Up folder navigation icon
            XylaIconButton {
                iconSource: "qrc:/assets/icons/arrow-up.svg"
                visible: root.activeMediaBinModel && root.activeMediaBinModel.currentBinId !== "root"
                onClicked: {
                    if (root.activeMediaBinModel) {
                        root.activeMediaBinModel.currentBinId = "root";
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Search Toggle Button
            XylaIconButton {
                id: searchBtn
                iconSource: "qrc:/assets/icons/search.svg"
                primary: searchPopup.opened
                onClicked: {
                    if (searchPopup.opened) {
                        searchPopup.close();
                    } else {
                        searchPopup.open();
                    }
                }
            }

            // Search Popup anchored at top-right under toolbarRow
            Popup {
                id: searchPopup
                parent: toolbarRow
                x: parent.width - width
                y: parent.height + 4
                width: 240
                height: 32
                padding: 0
                modal: false
                focus: true
                closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

                onOpened: {
                    searchInput.forceActiveFocus();
                }

                background: Rectangle {
                    color: "#181818"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 6
                }

                contentItem: TextField {
                    id: searchInput
                    anchors.fill: parent
                    placeholderText: "Search media..."
                    placeholderTextColor: "#555555"
                    color: "#ffffff"
                    font.pixelSize: 12
                    leftPadding: 10
                    rightPadding: 10
                    selectByMouse: true

                    background: Item {}

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
                }
            }

            // Sort Select Dropdown
            XylaSelect {
                id: sortComboBox
                Layout.preferredWidth: 110
                activeFocusOnTab: false
                model: ["Name", "Duration", "Path"]
                onActivated: function (index) {
                    if (!root.activeMediaBinModel)
                        return;
                    root.activeMediaBinModel.setSortRole(index);
                }
            }

            // Sort Order Toggle
            XylaIconButton {
                id: sortOrderToggle
                property bool isAscending: true
                iconSource: isAscending ? "qrc:/assets/icons/sort-ascending.svg" : "qrc:/assets/icons/sort-descending.svg"
                onClicked: {
                    isAscending = !isAscending;
                    if (root.activeMediaBinModel) {
                        root.activeMediaBinModel.setSortAscending(isAscending);
                    }
                }
            }

            // View Mode Segmented Toggle (List vs Grid)
            XylaSegmentedToggle {
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

            // Primary Blue Import Button
            XylaIconButton {
                iconSource: "qrc:/assets/icons/plus.svg"
                primary: true
                onClicked: folderDialog.open()
            }
        }

        // Drop Area & Views Container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            DropArea {
                id: dropArea
                anchors.fill: parent

                // Reject internal QML drags so MediaPanel never drops on itself
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

                // Context Menu Mouse Handler & Empty Space Right Click
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            root.selectedItemIndex = -1;
                            contextMenu.popup();
                        }
                    }
                }

                // Drop Overlay Highlight
                Rectangle {
                    anchors.fill: parent
                    color: (dropArea.containsDrag && dropArea.drag.source === null) ? "#15ffffff" : "transparent"
                    border.color: (dropArea.containsDrag && dropArea.drag.source === null) ? "#2d2d2d" : "transparent"
                    border.width: 1
                    radius: 4
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
                        spacing: 6
                        model: root.activeMediaBinModel

                        delegate: Rectangle {
                            id: listDelegateItem
                            width: listView.width
                            height: 38
                            color: itemMouseArea.containsMouse ? "#2a2a2b" : root.bgCard
                            border.color: "#2d2d2d"
                            border.width: 1
                            radius: 5

                            // Automatic Cross-Panel QML Drag
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
                                anchors.margins: 8
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
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.resolution || ""
                                    color: "#888888"
                                    font.pixelSize: 11
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
                                drag.target: listDummyDragTarget // Triggers Automatic Drag without moving item UI!

                                Item {
                                    id: listDummyDragTarget
                                }

                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.selectedItemIndex = index;
                                        contextMenu.popup();
                                    } else if (model.isFolder) {
                                        root.activeMediaBinModel.currentBinId = model.id;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#555555"
                            font.pixelSize: 13
                            visible: listView.count === 0
                        }
                    }

                    // GRID VIEW
                    GridView {
                        id: gridView
                        clip: true
                        cellWidth: 125
                        cellHeight: 105
                        model: root.activeMediaBinModel

                        delegate: Item {
                            id: gridDelegateItem
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            // Automatic Cross-Panel QML Drag
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

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: cardMouseArea.containsMouse ? "#2a2a2b" : root.bgCard
                                    radius: 5
                                    border.color: "#2d2d2d"
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: !model.isFolder
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.path ? "image://thumbnails/" + model.path + "?width=120" : ""
                                        asynchronous: true
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        visible: model.isFolder
                                        source: "qrc:/assets/icons/folder.svg"
                                        sourceSize.width: 28
                                        sourceSize.height: 28
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 4
                                        width: durationText.implicitWidth + 6
                                        height: durationText.implicitHeight + 2
                                        color: "#cc000000"
                                        radius: 2
                                        visible: !model.isFolder && model.duration !== undefined && model.duration !== ""

                                        Text {
                                            id: durationText
                                            anchors.centerIn: parent
                                            text: model.duration || ""
                                            color: "#ffffff"
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name || ""
                                    color: root.textPrimary
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: gridDummyDragTarget // Triggers Automatic Drag without moving item UI!

                                Item {
                                    id: gridDummyDragTarget
                                }

                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.selectedItemIndex = index;
                                        contextMenu.popup();
                                    } else if (model.isFolder) {
                                        root.activeMediaBinModel.currentBinId = model.id;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#555555"
                            font.pixelSize: 13
                            visible: gridView.count === 0
                        }
                    }
                }
            }
        }
    }
}
