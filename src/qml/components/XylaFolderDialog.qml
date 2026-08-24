import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Window {
    id: folderDialogRoot

    readonly property int folderIcon: 0
    readonly property int fileIcon: 1

    property string dialogTitle
    property int dialogTitleIcon: folderIcon

    title: dialogTitle
    width: 1365
    height: 920
    minimumWidth: 700
    minimumHeight: 450

    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    signal folderSelected(string path)

    function open() {
        folderDialogRoot.show();
        folderDialogRoot.requestActivate();
    }

    function hideDialog() {
        folderDialogRoot.hide();
    }

    Rectangle {
        id: dialogBg
        anchors.fill: parent
        color: "#121212"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 10

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Window Title Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                color: "#181818"
                topLeftRadius: 10
                topRightRadius: 10

                Image {
                    id: titleIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    source: folderDialogRoot.dialogTitleIcon === folderDialogRoot.folderIcon ? "qrc:/assets/icons/folder.svg" : folderDialogRoot.dialogTitleIcon === folderDialogRoot.fileIcon ? "qrc:/assets/icons/file.svg" : ""

                    sourceSize.width: 18
                    sourceSize.height: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: titleIcon.right
                    anchors.leftMargin: 16
                    text: folderDialogRoot.dialogTitle
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                XylaIconButton {
                    id: fullscreenBtn

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 6

                    ghost: true
                    iconSource: "qrc:/assets/icons/fullscreen.svg"

                    onClicked: {
                        if (folderDialogRoot.visibility === Window.FullScreen)
                            folderDialogRoot.showNormal();
                        else
                            folderDialogRoot.showFullScreen();
                    }
                }

                XylaIconButton {
                    id: closeBtn

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    ghost: true
                    iconSource: "qrc:/assets/icons/x.svg"
                    onClicked: folderDialogRoot.hideDialog()
                }

                DragHandler {
                    target: null
                    onActiveChanged: {
                        if (active)
                            folderDialogRoot.startSystemMove();
                    }
                }
            }

            // Blender-Style Navigation & Filter Toolbar Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: "#151515"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // 1. Navigation Cluster [ Back | Forward | Up | Refresh ]
                    Rectangle {
                        Layout.preferredHeight: 32
                        implicitWidth: navRow.implicitWidth + 4
                        color: "#181818"
                        border.color: "#2d2d2d"
                        border.width: 1
                        radius: 6

                        Row {
                            id: navRow
                            anchors.centerIn: parent
                            spacing: 0

                            XylaIconButton {
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-left.svg"
                                enabled: fileSystemModel.canCdBack
                                opacity: enabled ? 1.0 : 0.3
                                onClicked: fileSystemModel.cdBack()
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-right.svg"
                                enabled: fileSystemModel.canCdForward
                                opacity: enabled ? 1.0 : 0.3
                                onClicked: fileSystemModel.cdForward()
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-up.svg"
                                onClicked: fileSystemModel.cdUp()
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/refresh.svg"
                                onClicked: fileSystemModel.refresh()
                            }
                        }
                    }

                    XylaNewFolderDialog {
                        id: newFolderDialog

                        onCreateRequested: name => {
                            if (fileSystemModel.makeFolder(name)) {
                                newFolderDialog.close();
                            } else {
                                newFolderDialog.errorMessage = fileSystemModel.lastError;
                            }
                        }
                    }

                    XylaPropertiesDialog {
                        id: propertiesDialog
                    }

                    XylaRenameDialog {
                        id: renameDialog

                        onRenameRequested: newName => {
                            if (fileSystemModel.rename(targetPath, newName)) {
                                renameDialog.close();
                            } else {
                                renameDialog.errorMessage = fileSystemModel.lastError;
                            }
                        }
                    }

                    // 2. New Folder Button [ Folder+ ]
                    XylaIconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        iconSource: "qrc:/assets/icons/folder-plus.svg"
                        onClicked: newFolderDialog.open()
                    }

                    // 3. Address Bar Path Input
                    TextField {
                        id: pathDisplay

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        text: fileSystemModel.currentPath

                        color: "#ffffff"
                        font.pixelSize: 12

                        leftPadding: 10
                        rightPadding: 42

                        selectByMouse: true

                        property bool pathBookmarked: false
                        property var pathCompletionModel: []

                        background: Rectangle {
                            color: "#181818"
                            border.color: pathDisplay.activeFocus ? "#2555D3" : "#2d2d2d"
                            border.width: 1
                            radius: 6
                        }

                        // Reset text to currentPath when focus is lost by clicking elsewhere
                        onActiveFocusChanged: {
                            if (!activeFocus) {
                                text = fileSystemModel.currentPath;
                                pathCompletionPopup.close();
                            }
                        }

                        // Keyboard Handling: Up, Down, Tab, Enter, Escape
                        Keys.onPressed: event => {
                            if (pathCompletionPopup.visible && pathCompletionModel.length > 0) {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    pathCompletionList.currentIndex = (pathCompletionList.currentIndex + 1) % pathCompletionModel.length;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    pathCompletionList.currentIndex = (pathCompletionList.currentIndex - 1 + pathCompletionModel.length) % pathCompletionModel.length;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    var selected = pathCompletionModel[pathCompletionList.currentIndex];
                                    if (selected) {
                                        pathDisplay.text = selected.path;
                                        pathDisplay.cursorPosition = pathDisplay.text.length;
                                        fileSystemModel.cd(selected.path);
                                        pathCompletionPopup.close();
                                        event.accepted = true;
                                    }
                                } else if (event.key === Qt.Key_Escape) {
                                    pathDisplay.text = fileSystemModel.currentPath;
                                    pathDisplay.focus = false;
                                    pathCompletionPopup.close();
                                    event.accepted = true;
                                }
                            }
                        }

                        XylaIconButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter

                            width: 28
                            height: 28

                            ghost: true

                            iconSource: pathDisplay.pathBookmarked ? "qrc:/assets/icons/bookmarked.svg" : "qrc:/assets/icons/bookmark.svg"

                            Component.onCompleted: {
                                pathDisplay.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
                            }

                            onClicked: {
                                fileSystemModel.toggleBookmark(fileSystemModel.currentPath);
                            }
                        }

                        onTextChanged: {
                            pathCompletionModel = fileSystemModel.pathCompletions(text);
                            if (pathCompletionList) {
                                pathCompletionList.currentIndex = 0;
                            }
                        }

                        onEditingFinished: {
                            if (!pathCompletionPopup.visible) {
                                fileSystemModel.cd(text.trim());
                            }
                        }

                        Popup {
                            id: pathCompletionPopup

                            x: 0
                            y: pathDisplay.height + 2

                            width: pathDisplay.width
                            height: Math.min(pathCompletionList.contentHeight + 8, 220)

                            padding: 4
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

                            visible: pathDisplay.activeFocus && pathDisplay.pathCompletionModel.length > 0

                            background: Rectangle {
                                id: popupSurface

                                anchors.fill: parent
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

                            contentItem: ListView {
                                id: pathCompletionList

                                anchors.fill: parent
                                model: pathDisplay.pathCompletionModel
                                clip: true
                                spacing: 2
                                currentIndex: 0

                                delegate: Rectangle {
                                    id: completionRow
                                    required property var modelData
                                    required property int index

                                    width: pathCompletionList.width
                                    height: 32
                                    radius: 6

                                    property bool isCurrent: pathCompletionList.currentIndex === index
                                    color: isCurrent || rowMouse.containsMouse ? "#252525" : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 9
                                        spacing: 10

                                        Image {
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            source: modelData.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
                                            sourceSize: Qt.size(16, 16)
                                            opacity: 0.85
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: 12
                                            font.bold: completionRow.isCurrent
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onPositionChanged: {
                                            pathCompletionList.currentIndex = index;
                                        }

                                        onClicked: {
                                            pathDisplay.text = modelData.path;
                                            pathDisplay.cursorPosition = pathDisplay.text.length;
                                            fileSystemModel.cd(modelData.path);
                                            pathCompletionPopup.close();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. Compact Search Input
                    TextField {
                        id: searchInput

                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 32

                        placeholderText: "Search..."
                        placeholderTextColor: "#555555"

                        color: "#ffffff"
                        font.pixelSize: 12

                        leftPadding: 26
                        rightPadding: 10

                        selectByMouse: true

                        Image {
                            source: "qrc:/assets/icons/search.svg"

                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter

                            sourceSize.width: 12
                            sourceSize.height: 12

                            opacity: 0.5
                        }

                        background: Rectangle {
                            color: "#181818"
                            border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                            border.width: 1
                            radius: 6
                        }

                        onTextChanged: {
                            fileSystemModel.nameFilter = text.trim();
                        }
                    }

                    // 5. List vs Grid Segmented View Toggle
                    XylaSegmentedToggle {
                        id: viewToggle
                        currentIndex: 1
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
                    }

                    // 6. Filter Popup Button Using Reusable XylaFilterPopup
                    XylaIconButton {
                        id: filterBtn
                        iconSource: "qrc:/assets/icons/filter.svg"
                        primary: filterPopup.opened

                        onClicked: {
                            if (filterPopup._recentlyClosed) {
                                filterPopup._recentlyClosed = false;
                                return;
                            }

                            if (filterPopup.opened) {
                                filterPopup.close();
                            } else {
                                filterPopup.open();
                            }
                        }

                        XylaFilterPopup {
                            id: filterPopup
                            parent: filterBtn
                            y: parent.height + 6
                            x: parent.width - width
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#2d2d2d"
                }
            }

            // Main Directory Contents View
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    id: quickAccessSidebar

                    Layout.preferredWidth: 190
                    Layout.fillHeight: true
                    color: "#151515"

                    property var quickAccessModel: fileSystemModel.quickAccessItems()

                    function refresh() {
                        quickAccessModel = fileSystemModel.quickAccessItems();
                    }

                    Connections {
                        target: fileSystemModel

                        function onCurrentPathChanged() {
                            quickAccessSidebar.refresh();
                            pathDisplay.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
                        }

                        function onBookmarksChanged() {
                            pathDisplay.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
                            quickAccessSidebar.refresh();
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth

                            ColumnLayout {
                                width: parent.width
                                spacing: 2

                                Text {
                                    text: "QUICK ACCESS"
                                    color: "#666666"
                                    font.pixelSize: 10
                                    font.bold: true

                                    Layout.leftMargin: 16
                                    Layout.topMargin: 10
                                    Layout.bottomMargin: 4
                                }

                                Repeater {
                                    model: quickAccessSidebar.quickAccessModel

                                    delegate: XylaTextButton {
                                        required property var modelData

                                        visible: modelData.section === "Common"
                                        sleek: true

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        Layout.leftMargin: 10
                                        Layout.rightMargin: 10

                                        text: ""

                                        contentItem: Item {
                                            anchors.fill: parent

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8

                                                spacing: 8

                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16

                                                    source: {
                                                        switch (modelData.name) {
                                                        case "Home":
                                                            return "qrc:/assets/icons/home.svg";
                                                        case "Desktop":
                                                            return "qrc:/assets/icons/desktop.svg";
                                                        case "Documents":
                                                            return "qrc:/assets/icons/file-text.svg";
                                                        case "Downloads":
                                                            return "qrc:/assets/icons/download.svg";
                                                        case "Pictures":
                                                            return "qrc:/assets/icons/image.svg";
                                                        case "Music":
                                                            return "qrc:/assets/icons/music.svg";
                                                        case "Videos":
                                                            return "qrc:/assets/icons/video.svg";
                                                        default:
                                                            return "qrc:/assets/icons/folder.svg";
                                                        }
                                                    }

                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: "#ffffff"
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        onClicked: {
                                            fileSystemModel.cd(modelData.path);
                                        }
                                    }
                                }

                                Text {
                                    text: "DEVICES"
                                    color: "#666666"
                                    font.pixelSize: 10
                                    font.bold: true

                                    Layout.leftMargin: 16
                                    Layout.topMargin: 12
                                    Layout.bottomMargin: 4
                                }

                                Repeater {
                                    model: quickAccessSidebar.quickAccessModel

                                    delegate: XylaTextButton {
                                        required property var modelData

                                        visible: modelData.section === "Devices"
                                        sleek: true

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        Layout.leftMargin: 10
                                        Layout.rightMargin: 10

                                        text: ""

                                        contentItem: Item {
                                            anchors.fill: parent

                                            RowLayout {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8

                                                spacing: 8

                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16

                                                    source: "qrc:/assets/icons/drive.svg"

                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                }

                                                Text {
                                                    Layout.fillWidth: true

                                                    text: modelData.name

                                                    color: "#ffffff"
                                                    font.pixelSize: 12

                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        onClicked: {
                                            fileSystemModel.cd(modelData.path);
                                        }
                                    }
                                }

                                Text {
                                    id: bookmarksTitle

                                    text: "BOOKMARKS"

                                    color: "#666666"

                                    font.pixelSize: 10
                                    font.bold: true

                                    Layout.leftMargin: 16
                                    Layout.topMargin: 12
                                    Layout.bottomMargin: 4

                                    visible: {
                                        for (let i = 0; i < quickAccessSidebar.quickAccessModel.length; ++i) {
                                            if (quickAccessSidebar.quickAccessModel[i].section === "Bookmarks")
                                                return true;
                                        }

                                        return false;
                                    }
                                }

                                Repeater {
                                    model: quickAccessSidebar.quickAccessModel

                                    delegate: XylaTextButton {
                                        required property var modelData

                                        visible: modelData.section === "Bookmarks"
                                        sleek: true

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        Layout.leftMargin: 10
                                        Layout.rightMargin: 10

                                        text: ""

                                        contentItem: Item {
                                            anchors.fill: parent

                                            RowLayout {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8

                                                spacing: 8

                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16

                                                    source: "qrc:/assets/icons/bookmarked.svg"

                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                }

                                                Text {
                                                    Layout.fillWidth: true

                                                    text: modelData.name

                                                    color: "#ffffff"
                                                    font.pixelSize: 12

                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        onClicked: {
                                            fileSystemModel.cd(modelData.path);
                                        }
                                    }
                                }
                            }
                        }

                        XylaTextButton {
                            sleek: true

                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            Layout.margins: 10

                            text: ""

                            contentItem: Item {
                                anchors.fill: parent

                                RowLayout {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8

                                    spacing: 8

                                    Image {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16

                                        source: "qrc:/assets/icons/settings.svg"

                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                    }

                                    Text {
                                        text: "Settings"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            onClicked: {
                                console.log("Settings clicked");
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: "#2d2d2d"
                    }
                }

                // ============================================================
                // DIRECTORY CONTENTS GRID
                // ============================================================

                Item {
                    id: viewContainer

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property var selectedIndexes: ({})
                    property int lastSelectedIndex: -1
                    property int contextMenuIndex: -1

                    function selectedPaths() {
                        var paths = [];
                        var keys = Object.keys(viewContainer.selectedIndexes);
                        for (let i = 0; i < keys.length; ++i) {
                            let idx = parseInt(keys[i]);
                            let item = fileSystemModel.get(idx);
                            if (item && item.filePath)
                                paths.push(item.filePath);
                        }
                        return paths;
                    }

                    function openContextMenu(index, isDir, mouseX, mouseY) {
                        viewContainer.contextMenuIndex = index;
                        contextMenu.hasSelection = true;
                        contextMenu.selectionIsFolder = isDir;
                        contextMenu.selectionIsFile = !isDir;

                        // contextMenu.canPaste = true;

                        var globalPos = mapToItem(contextMenu.parent, mouseX, mouseY);

                        contextMenu.openAt(globalPos.x, globalPos.y);
                    }

                    function openBackgroundContextMenu(mouseX, mouseY) {
                        viewContainer.contextMenuIndex = -1;

                        contextMenu.hasSelection = false;
                        contextMenu.selectionIsFolder = false;
                        contextMenu.selectionIsFile = false;

                        // contextMenu.canPaste = true;

                        var globalPos = mapToItem(contextMenu.parent, mouseX, mouseY);

                        contextMenu.openAt(globalPos.x, globalPos.y);
                    }

                    function selectIndex(idx, mouse) {
                        var newSel = Object.assign({}, selectedIndexes);

                        if (mouse && (mouse.modifiers & Qt.ShiftModifier) && lastSelectedIndex !== -1) {
                            let start = Math.min(lastSelectedIndex, idx);
                            let end = Math.max(lastSelectedIndex, idx);
                            for (let i = start; i <= end; i++)
                                newSel[i] = true;
                        } else if (mouse && (mouse.modifiers & Qt.ControlModifier)) {
                            if (newSel[idx])
                                delete newSel[idx];
                            else
                                newSel[idx] = true;
                        } else {
                            // Plain click → select ONLY this item (standard behaviour)
                            newSel = {};
                            newSel[idx] = true;
                        }

                        selectedIndexes = newSel;
                        lastSelectedIndex = idx;
                    }

                    function clearSelection() {
                        selectedIndexes = {};
                        lastSelectedIndex = -1;
                    }

                    Connections {
                        target: viewToggle

                        function onCurrentIndexChanged() {
                            viewContainer.clearSelection();
                        }
                    }

                    XylaFileContextMenu {
                        id: contextMenu

                        // Keep canPaste in sync
                        canPaste: fileSystemModel.canPaste

                        onCutRequested: {
                            var paths = viewContainer.selectedPaths();
                            if (paths.length === 0 && viewContainer.contextMenuIndex >= 0) {
                                let item = fileSystemModel.get(viewContainer.contextMenuIndex);
                                if (item.filePath)
                                    paths = [item.filePath];
                            }
                            if (paths.length > 0)
                                fileSystemModel.cut(paths);
                        }

                        onCopyRequested: {
                            var paths = viewContainer.selectedPaths();
                            if (paths.length === 0 && viewContainer.contextMenuIndex >= 0) {
                                let item = fileSystemModel.get(viewContainer.contextMenuIndex);
                                if (item.filePath)
                                    paths = [item.filePath];
                            }
                            if (paths.length > 0)
                                fileSystemModel.copy(paths);
                        }

                        onPasteRequested: {
                            fileSystemModel.paste();          // pastes into currentPath
                        }

                        onOpenRequested: {
                            // console.log("UI: Open", contextMenuIndex);
                            //
                            if (viewContainer.contextMenuIndex >= 0) {
                                let item = fileSystemModel.get(viewContainer.contextMenuIndex);

                                if (item.isDir)
                                    fileSystemModel.cd(item.filePath);
                            }
                        }

                        onRenameRequested: {
                            if (viewContainer.contextMenuIndex < 0)
                                return;
                            var item = fileSystemModel.get(viewContainer.contextMenuIndex);
                            if (!item.filePath)
                                return;
                            renameDialog.targetPath = item.filePath;
                            renameDialog.originalName = item.fileName;
                            renameDialog.open();
                        }

                        onDeleteRequested: {
                            var paths = viewContainer.selectedPaths();
                            if (paths.length === 0 && viewContainer.contextMenuIndex >= 0) {
                                let item = fileSystemModel.get(viewContainer.contextMenuIndex);
                                if (item.filePath)
                                    paths = [item.filePath];
                            }
                            if (paths.length > 0)
                                fileSystemModel.moveToTrash(paths);
                        }

                        onNewFolderRequested: {
                            // console.log("UI: New Folder");
                            newFolderDialog.show();
                        }

                        onSelectAllRequested: {
                            // console.log("UI: Select All");

                            var newSel = {};

                            for (let i = 0; i < fileSystemModel.rowCount(); ++i)
                                newSel[i] = true;

                            viewContainer.selectedIndexes = newSel;
                        }

                        onPropertiesRequested: {
                            if (viewContainer.contextMenuIndex < 0)
                                return;
                            var item = fileSystemModel.get(viewContainer.contextMenuIndex);
                            if (!item || !item.filePath)
                                return;
                            propertiesDialog.openWith(item);
                        }
                    }

                    GridView {
                        id: dirGridView

                        visible: viewToggle.currentIndex === 1
                        anchors.fill: parent

                        clip: true

                        cellWidth: 190
                        cellHeight: 220

                        topMargin: 16
                        bottomMargin: 16
                        leftMargin: 16
                        rightMargin: 16

                        model: fileSystemModel

                        // Rubberband Selection Overlay
                        MouseArea {
                            id: gridRubberBandMouseArea

                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right

                            z: 10                                   // on top of content so we can decide
                            preventStealing: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property point startPoint
                            property bool draggingSelection: false

                            onPressed: mouse => {
                                // 1. Always hit-test first
                                var contentPos = mapToItem(dirGridView.contentItem, mouse.x, mouse.y);
                                var item = dirGridView.itemAt(contentPos.x, contentPos.y);

                                if (item) {
                                    // Press is over a real item → let the delegate MouseArea handle it
                                    mouse.accepted = false;
                                    return;
                                }

                                // 2. Empty space
                                if (mouse.button === Qt.RightButton) {
                                    viewContainer.openBackgroundContextMenu(mouse.x, mouse.y);
                                    return;
                                }

                                // 3. Left button on empty space → start rubber-band
                                startPoint = Qt.point(mouse.x, mouse.y);
                                rubberBandGrid.x = mouse.x;
                                rubberBandGrid.y = mouse.y;
                                rubberBandGrid.width = 0;
                                rubberBandGrid.height = 0;
                                rubberBandGrid.visible = false;
                                draggingSelection = false;

                                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                    viewContainer.clearSelection();
                                }
                            }

                            onPositionChanged: mouse => {
                                if (!draggingSelection && !rubberBandGrid.visible) {
                                    let dist = Math.sqrt(Math.pow(mouse.x - startPoint.x, 2) + Math.pow(mouse.y - startPoint.y, 2));
                                    if (dist <= 3)
                                        return;
                                    draggingSelection = true;
                                    rubberBandGrid.visible = true;
                                }

                                if (!draggingSelection)
                                    return;
                                var rx = Math.min(startPoint.x, mouse.x);
                                var ry = Math.min(startPoint.y, mouse.y);
                                var rw = Math.abs(mouse.x - startPoint.x);
                                var rh = Math.abs(mouse.y - startPoint.y);

                                rubberBandGrid.x = rx;
                                rubberBandGrid.y = ry;
                                rubberBandGrid.width = rw;
                                rubberBandGrid.height = rh;

                                var cols = Math.max(1, Math.floor((dirGridView.width - dirGridView.leftMargin - dirGridView.rightMargin) / dirGridView.cellWidth));

                                var newSel = (mouse.modifiers & Qt.ControlModifier) ? Object.assign({}, viewContainer.selectedIndexes) : {};

                                var boxLeft = rx + dirGridView.contentX;
                                var boxTop = ry + dirGridView.contentY;
                                var boxRight = boxLeft + rw;
                                var boxBottom = boxTop + rh;

                                for (let i = 0; i < dirGridView.count; ++i) {
                                    let col = i % cols;
                                    let row = Math.floor(i / cols);

                                    let itemX = dirGridView.leftMargin + col * dirGridView.cellWidth;
                                    let itemY = dirGridView.topMargin + row * dirGridView.cellHeight;

                                    let intersects = !(itemX > boxRight || (itemX + dirGridView.cellWidth) < boxLeft || itemY > boxBottom || (itemY + dirGridView.cellHeight) < boxTop);

                                    if (intersects)
                                        newSel[i] = true;
                                }
                                viewContainer.selectedIndexes = newSel;
                            }

                            onReleased: {
                                draggingSelection = false;
                                rubberBandGrid.visible = false;
                            }
                            onCanceled: {
                                draggingSelection = false;
                                rubberBandGrid.visible = false;
                            }
                        }

                        Rectangle {
                            id: rubberBandGrid

                            z: 100

                            visible: false

                            color: "#332555D3"
                            border.color: "#2555D3"
                            border.width: 1
                        }

                        delegate: XylaFolderCard {
                            id: gridCard

                            width: 175
                            height: 205

                            z: 1

                            selected: !!viewContainer.selectedIndexes[index]

                            folderName: model.fileName !== undefined ? model.fileName : ""

                            folderPath: model.filePath !== undefined ? model.filePath : ""

                            isFolder: model.isDir !== undefined ? model.isDir : false

                            fileCount: model.itemCount !== undefined ? model.itemCount : 0

                            fileExtension: model.extension !== undefined ? model.extension : ""

                            fileSize: model.fileSize !== undefined ? model.fileSize : 0

                            MouseArea {
                                id: gridCardMouseArea
                                anchors.fill: parent
                                z: 50
                                hoverEnabled: true
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onPressed: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (!viewContainer.selectedIndexes[index]) {
                                            let newSel = {};
                                            newSel[index] = true;
                                            viewContainer.selectedIndexes = newSel;
                                            viewContainer.lastSelectedIndex = index;
                                        }

                                        // Correct mapping that respects scroll offset
                                        let p = mapToItem(viewContainer, mouse.x, mouse.y);
                                        viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                                        return;
                                    }

                                    // Left button → select immediately
                                    viewContainer.selectIndex(index, mouse);
                                }

                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton && model.isDir && model.filePath !== undefined && model.filePath !== "") {
                                        fileSystemModel.cd(model.filePath);
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: gridScrollBar

                            z: 200

                            policy: ScrollBar.AsNeeded
                        }
                    }

                    ListView {
                        id: dirListView

                        visible: viewToggle.currentIndex === 0
                        anchors.fill: parent

                        clip: true

                        topMargin: 8
                        bottomMargin: 8
                        leftMargin: 12
                        rightMargin: 12

                        spacing: 2

                        model: fileSystemModel

                        MouseArea {
                            id: listRubberBandMouseArea

                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right

                            z: 10
                            preventStealing: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property point startPoint
                            property bool draggingSelection: false

                            onPressed: mouse => {
                                var contentPos = mapToItem(dirListView.contentItem, mouse.x, mouse.y);
                                var item = dirListView.itemAt(contentPos.x, contentPos.y);

                                if (item) {
                                    mouse.accepted = false;
                                    return;
                                }

                                if (mouse.button === Qt.RightButton) {
                                    viewContainer.openBackgroundContextMenu(mouse.x, mouse.y);
                                    return;
                                }

                                startPoint = Qt.point(mouse.x, mouse.y);
                                draggingSelection = false;

                                rubberBandList.x = mouse.x;
                                rubberBandList.y = mouse.y;
                                rubberBandList.width = 0;
                                rubberBandList.height = 0;
                                rubberBandList.visible = false;

                                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                    viewContainer.clearSelection();
                                }
                            }

                            onPositionChanged: mouse => {
                                if (!draggingSelection && !rubberBandList.visible) {
                                    let dist = Math.sqrt(Math.pow(mouse.x - startPoint.x, 2) + Math.pow(mouse.y - startPoint.y, 2));
                                    if (dist <= 3)
                                        return;
                                    draggingSelection = true;
                                    rubberBandList.visible = true;
                                }

                                if (!draggingSelection)
                                    return;
                                var rx = Math.min(startPoint.x, mouse.x);
                                var ry = Math.min(startPoint.y, mouse.y);
                                var rw = Math.abs(mouse.x - startPoint.x);
                                var rh = Math.abs(mouse.y - startPoint.y);

                                rubberBandList.x = rx;
                                rubberBandList.y = ry;
                                rubberBandList.width = rw;
                                rubberBandList.height = rh;

                                var newSel = (mouse.modifiers & Qt.ControlModifier) ? Object.assign({}, viewContainer.selectedIndexes) : {};

                                var boxTop = ry + dirListView.contentY;
                                var boxBottom = boxTop + rh;
                                var itemStride = 40 + dirListView.spacing;

                                for (let i = 0; i < dirListView.count; ++i) {
                                    let itemY = dirListView.topMargin + (i * itemStride);
                                    let intersects = !(itemY > boxBottom || (itemY + 40) < boxTop);
                                    if (intersects)
                                        newSel[i] = true;
                                }
                                viewContainer.selectedIndexes = newSel;
                            }

                            onReleased: {
                                draggingSelection = false;
                                rubberBandList.visible = false;
                            }
                            onCanceled: {
                                draggingSelection = false;
                                rubberBandList.visible = false;
                            }
                        }

                        Rectangle {
                            id: rubberBandList

                            z: 100

                            visible: false

                            color: "#332555D3"
                            border.color: "#2555D3"
                            border.width: 1
                        }

                        delegate: Rectangle {
                            width: dirListView.width - dirListView.leftMargin - dirListView.rightMargin

                            height: 40

                            z: 1

                            property bool isSelected: !!viewContainer.selectedIndexes[index]

                            color: isSelected ? "#2b4263" : (mouseArea.containsMouse ? "#1f1f1f" : "transparent")

                            border.color: isSelected ? "#3c6ce7" : "transparent"

                            border.width: isSelected ? 1 : 0
                            radius: 4

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20

                                    source: model.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file-text.svg"

                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: model.fileName !== undefined ? model.fileName : ""

                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: model.isDir !== undefined && model.isDir

                                    text: (model.itemCount !== undefined ? model.itemCount : 0) + " items"

                                    color: "#666666"
                                    font.pixelSize: 11
                                }

                                Text {
                                    visible: model.isDir !== undefined && !model.isDir

                                    text: (model.extension !== undefined && model.extension !== "") ? model.extension.toUpperCase() : ""

                                    color: "#666666"
                                    font.pixelSize: 11

                                    Layout.preferredWidth: 50
                                }
                            }

                            MouseArea {
                                id: mouseArea

                                anchors.fill: parent

                                hoverEnabled: true
                                preventStealing: true

                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onPressed: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (!viewContainer.selectedIndexes[index]) {
                                            let newSel = {};
                                            newSel[index] = true;
                                            viewContainer.selectedIndexes = newSel;
                                            viewContainer.lastSelectedIndex = index;
                                        }

                                        let p = mapToItem(viewContainer, mouse.x, mouse.y);
                                        // let p = viewContainer.mapToItem(contextMenu.parent, mouse.x //  + parent.x,
                                        // , mouse.y // + parent.y
                                        // );

                                        viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                                        return;
                                    }

                                    viewContainer.selectIndex(index, mouse);
                                }

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        viewContainer.selectIndex(index, mouse);
                                    }
                                }

                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton && model.isDir && model.filePath !== undefined && model.filePath !== "") {
                                        fileSystemModel.cd(model.filePath);
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            z: 200

                            policy: ScrollBar.AsNeeded
                        }
                    }
                }
            }

            // Footer Action Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "#181818"
                bottomLeftRadius: 10
                bottomRightRadius: 10

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: "#2d2d2d"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.preferredWidth: Math.min(420, parent.width * 0.48)
                        Layout.preferredHeight: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "#151515"
                            border.color: "#2d2d2d"
                            border.width: 1
                            visible: selectionLabel.text.length > 0
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                id: selectionLabel
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideMiddle
                                color: "#e0e0e0"
                                font.pixelSize: 12

                                // Re-evaluate whenever the selection object changes
                                property var sel: viewContainer.selectedIndexes

                                text: {
                                    var keys = Object.keys(sel);
                                    if (keys.length === 0)
                                        return "";

                                    if (keys.length === 1) {
                                        let idx = parseInt(keys[0]);
                                        let item = fileSystemModel.get(idx);
                                        // Prefer full path, fall back to name
                                        if (item && item.filePath)
                                            return item.filePath;
                                        if (item && item.fileName)
                                            return item.fileName;
                                        return "";
                                    }

                                    return keys.length + " items selected";
                                }
                            }

                            // Copy path button – only visible when there is a single selection
                            XylaIconButton {
                                visible: {
                                    var keys = Object.keys(viewContainer.selectedIndexes);
                                    return keys.length === 1;
                                }
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                ghost: true
                                iconSource: "qrc:/assets/icons/copy.svg"
                                iconWidth: 14
                                iconHeight: 14

                                onClicked: {
                                    var keys = Object.keys(viewContainer.selectedIndexes);
                                    if (keys.length !== 1)
                                        return;
                                    var item = fileSystemModel.get(parseInt(keys[0]));
                                    if (item && item.filePath)
                                        fileSystemModel.copyToClipboard(item.filePath);
                                }

                                ToolTip.visible: hovered
                                ToolTip.text: "Copy path"
                                ToolTip.delay: 400
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaTextButton {
                        text: "Cancel"
                        onClicked: folderDialogRoot.hideDialog()
                    }

                    XylaTextButton {
                        text: "Select Folder"
                        primary: true
                        onClicked: {
                            folderDialogRoot.folderSelected(fileSystemModel.currentPath);
                            folderDialogRoot.hideDialog();
                        }
                    }
                }
            }
        }
    }
}
