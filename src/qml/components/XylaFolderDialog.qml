import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia

Window {
    id: folderDialogRoot

    readonly property int folderIcon: 0
    readonly property int fileIcon: 1

    property string dialogTitle
    property int dialogTitleIcon: folderIcon

    title: dialogTitle
    width: 1453
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

    // Place this at the root container level of your view
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            focus = true; // Shifts focus to the window background, clearing TextField focus
            viewContainer.cancelActiveRename();
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: !pathDisplay.activeFocus && !searchInput.activeFocus && !sortFilter.activeFocus
        onActivated: {
            // 1) cancel inline rename first
            if (viewContainer.renamingItem) {
                viewContainer.cancelActiveRename();
                return;
            }

            if (typeof contextMenu !== "undefined" && contextMenu.visible)
                contextMenu.close();
            if (typeof filterPopup !== "undefined" && filterPopup.opened)
                filterPopup.close();

            viewContainer.clearSelection();
        }
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
                    iconSource: folderDialogRoot.visibility === Window.FullScreen ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/fullscreen.svg"

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
                            // Always handle Escape, whether the popup is open or not
                            if (event.key === Qt.Key_Escape) {
                                text = fileSystemModel.currentPath;
                                pathCompletionPopup.close();
                                pathDisplay.focus = false; // Force clear active focus
                                event.accepted = true;
                                return;
                            }

                            if (!pathCompletionPopup.visible || pathCompletionModel.length === 0)
                                return;
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                pathCompletionList.currentIndex = (pathCompletionList.currentIndex + 1) % pathCompletionModel.length;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                pathCompletionList.currentIndex = (pathCompletionList.currentIndex - 1 + pathCompletionModel.length) % pathCompletionModel.length;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                let selected = pathCompletionModel[pathCompletionList.currentIndex];
                                if (selected) {
                                    text = selected.path;
                                    cursorPosition = text.length;
                                    fileSystemModel.cd(selected.path);
                                    pathCompletionPopup.close();
                                    pathDisplay.focus = false; // Force clear active focus
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
                            if (pathDisplay.activeFocus && pathCompletionModel.length > 0)
                                pathCompletionPopup.open();
                            else
                                pathCompletionPopup.close();
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
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
                            // onClosed: {
                            //     pathDisplay.focus = false
                            // }

                            onAboutToHide: {
                                // If the user clicked outside, also drop focus from the path field
                                if (!pathDisplay.activeFocus)
                                    pathDisplay.text = fileSystemModel.currentPath;
                            }

                            // visible: pathDisplay.activeFocus && pathDisplay.pathCompletionModel.length > 0

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
                                    color: isCurrent || completionMouse.containsMouse ? "#252525" : "transparent"

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
                                            Layout.preferredWidth: 0
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: 12
                                            font.bold: completionRow.isCurrent
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: completionMouse
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

                    Item {
                        id: searchComponent
                        implicitWidth: 32
                        implicitHeight: 32

                        // --- Public API Properties ---
                        property bool searchVisible: false
                        property alias text: searchInput.text
                        property alias placeholderText: searchInput.placeholderText
                        property alias inputItem: searchInput

                        // Function to close search popup and reset focus
                        // function closeSearch() {
                        //     searchComponent.searchVisible = false;
                        //     searchPopup.close();
                        // }
                        function closeSearch() {
                            searchComponent.searchVisible = false;
                            searchPopup.close();
                            searchInput.focus = false;
                        }

                        // Function to open search popup
                        function openSearch() {
                            searchComponent.searchVisible = true;
                            searchPopup.open();
                            searchInput.forceActiveFocus();
                        }

                        // Search Toggle Button
                        XylaIconButton {
                            id: searchBtn
                            anchors.fill: parent
                            iconSource: "qrc:/assets/icons/search.svg"
                            primary: searchComponent.searchVisible

                            onClicked: {
                                if (searchComponent.searchVisible) {
                                    searchComponent.closeSearch();
                                } else {
                                    searchComponent.openSearch();
                                }
                            }
                        }

                        // Floating Search Input Popup using native QtQuick Popup
                        Popup {
                            id: searchPopup
                            x: searchBtn.width - width
                            y: searchBtn.height + 6
                            width: 260
                            height: 32
                            padding: 0
                            margins: 0
                            focus: true
                            modal: false

                            // Automatically handles closing when clicking outside or pressing Escape
                            closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

                            // background: Item {} // Empty background container
                            background: Rectangle {
                                id: popupSurface__
                                anchors.fill: parent
                                color: "#181818"
                                border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                                border.width: 1
                                radius: 6

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
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            exit: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 1.0
                                    to: 0.0
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // onAboutToHide: {
                            //     searchComponent.searchVisible = false;
                            // }

                            onAboutToHide: {
                                searchComponent.searchVisible = false;
                                searchInput.focus = false;          // force lose focus
                                // optional: keep the filter text, or clear it
                                // searchInput.text = ""
                                // fileSystemModel.nameFilter = ""
                            }

                            TextField {
                                id: searchInput
                                anchors.fill: parent
                                placeholderText: "Search..."
                                placeholderTextColor: "#555555"
                                color: "#ffffff"
                                font.pixelSize: 12
                                leftPadding: 26
                                rightPadding: 10
                                selectByMouse: true

                                // Pass trimmed text straight to model filter on change
                                onTextChanged: {
                                    fileSystemModel.nameFilter = text.trim();
                                }

                                // Keyboard navigation: Escape cancels/closes, Enter submits & closes
                                // Keys.onPressed: (event) => {
                                //     if (event.key === Qt.Key_Escape) {
                                //         searchInput.text = "";
                                //         fileSystemModel.nameFilter = "";
                                //         searchComponent.closeSearch();
                                //         event.accepted = true;
                                //     } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                //         searchComponent.closeSearch();
                                //         event.accepted = true;
                                //     }
                                // }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        searchInput.text = "";
                                        fileSystemModel.nameFilter = "";
                                        searchComponent.closeSearch();
                                        searchInput.focus = false;
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        searchComponent.closeSearch();
                                        searchInput.focus = false;
                                        event.accepted = true;
                                    }
                                }

                                // Inline Search Icon inside textfield
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
                            }
                        }
                    }
                    // 4. Compact Search Input
                    // TextField {
                    //     id: searchInput
                    //
                    //     Layout.preferredWidth: 140
                    //     Layout.preferredHeight: 32
                    //
                    //     placeholderText: "Search..."
                    //     placeholderTextColor: "#555555"
                    //
                    //     color: "#ffffff"
                    //     font.pixelSize: 12
                    //
                    //     leftPadding: 26
                    //     rightPadding: 10
                    //
                    //     selectByMouse: true
                    //
                    //     Image {
                    //         source: "qrc:/assets/icons/search.svg"
                    //
                    //         anchors.left: parent.left
                    //         anchors.leftMargin: 8
                    //         anchors.verticalCenter: parent.verticalCenter
                    //
                    //         sourceSize.width: 12
                    //         sourceSize.height: 12
                    //
                    //         opacity: 0.5
                    //     }
                    //
                    //     background: Rectangle {
                    //         color: "#181818"
                    //         border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                    //         border.width: 1
                    //         radius: 6
                    //     }
                    //
                    //     onTextChanged: {
                    //         fileSystemModel.nameFilter = text.trim();
                    //     }
                    // }

                    XylaIconButton {
                        id: sortOrderToggle

                        property bool isAscending: fileSystemModel.sortOrder === "ascending"

                        ToolTip.visible: hovered
                        ToolTip.text: isAscending ? "Sort Ascending" : "Sort Descending"

                        onClicked: {
                            fileSystemModel.sortOrder = isAscending ? "descending" : "ascending";
                        }

                        Item {
                            anchors.fill: parent

                            Image {
                                id: ascendingIcon

                                anchors.centerIn: parent
                                width: 18
                                height: 18

                                source: "qrc:/assets/icons/sort-ascending.svg"
                                fillMode: Image.PreserveAspectFit

                                opacity: sortOrderToggle.isAscending ? 1 : 0
                                scale: sortOrderToggle.isAscending ? 1 : 0.7

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 360
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            Image {
                                id: descendingIcon

                                anchors.centerIn: parent
                                width: 18
                                height: 18

                                source: "qrc:/assets/icons/sort-descending.svg"
                                fillMode: Image.PreserveAspectFit

                                opacity: sortOrderToggle.isAscending ? 0 : 1
                                scale: sortOrderToggle.isAscending ? 0.7 : 1

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 360
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                    }

                    XylaIconButton {
                        id: folderOrderToggle

                        property bool foldersFirst: fileSystemModel.foldersFirst

                        ToolTip.visible: hovered
                        ToolTip.text: foldersFirst ? "Folders at Top" : "Folders at Bottom"

                        onClicked: {
                            fileSystemModel.foldersFirst = !foldersFirst;
                        }

                        Item {
                            anchors.fill: parent

                            Image {
                                id: folderTopIcon

                                anchors.centerIn: parent
                                width: 18
                                height: 18

                                source: "qrc:/assets/icons/folder-top.svg"
                                fillMode: Image.PreserveAspectFit

                                opacity: folderOrderToggle.foldersFirst ? 1 : 0
                                scale: folderOrderToggle.foldersFirst ? 1 : 0.5

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 360
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            Image {
                                id: folderBottomIcon

                                anchors.centerIn: parent
                                width: 18
                                height: 18

                                source: "qrc:/assets/icons/folder-bottom.svg"
                                fillMode: Image.PreserveAspectFit

                                opacity: folderOrderToggle.foldersFirst ? 0 : 1
                                scale: folderOrderToggle.foldersFirst ? 0.5 : 1

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 360
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                    }

                    XylaSelect {
                        id: sortFilter
                        Layout.preferredWidth: 140
                        // Layout.fillWidth: true
                        model: ["Name", "Date Modified", "Size", "Type"]
                        onCurrentTextChanged: fileSystemModel.sortBy = currentText
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

                    XylaIconButton {
                        id: filterBtn
                        iconSource: "qrc:/assets/icons/filter.svg"

                        // Helper property to track whether non-default filters are active
                        property bool isFilterActive: {
                            var typeActive = false;

                            if (filterPopup.filterContainer) {
                                let sel = filterPopup.filterContainer.selectedIndexes;
                                let total = filterPopup.filterContainer.options.length;
                                let count = 0;
                                for (let i = 0; i < sel.length; ++i)
                                    if (sel[i])
                                        count++;

                                // true when at least one chip is unselected (including all unselected)
                                typeActive = (count < total);
                            } else {
                                // fallback if alias isn’t exposed
                                typeActive = fileSystemModel.typeFilter !== "" && fileSystemModel.typeFilter !== "All Files";
                            }

                            var sizeActive = fileSystemModel.sizeFilter !== "" && fileSystemModel.sizeFilter !== "Any Size";

                            return typeActive || sizeActive;
                        }

                        // primary: filterPopup.opened || isFilterActive

                        // Highlight if popup is open OR if any filter criteria is active
                        primary: filterPopup.opened || isFilterActive

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
                    // 6. Filter Popup Button Using Reusable XylaFilterPopup
                    // XylaIconButton {
                    //     id: filterBtn
                    //     iconSource: "qrc:/assets/icons/filter.svg"
                    //     primary: filterPopup.opened
                    //
                    //     onClicked: {
                    //         if (filterPopup._recentlyClosed) {
                    //             filterPopup._recentlyClosed = false;
                    //             return;
                    //         }
                    //
                    //         if (filterPopup.opened) {
                    //             filterPopup.close();
                    //         } else {
                    //             filterPopup.open();
                    //         }
                    //     }
                    //
                    //     XylaFilterPopup {
                    //         id: filterPopup
                    //         parent: filterBtn
                    //         y: parent.height + 6
                    //         x: parent.width - width
                    //     }
                    // }
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

                // The left Section
                Rectangle {
                    id: quickAccessSidebar

                    // Convert preferredWidth to a dynamic property that handles drag updates
                    property int sidebarWidth: 190

                    Layout.preferredWidth: sidebarWidth
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
                                                    Layout.preferredWidth: 0
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
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8

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
                                                    Layout.preferredWidth: 0

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
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8

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
                                                    Layout.preferredWidth: 0

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
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8

                                    spacing: 8

                                    Image {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16

                                        source: "qrc:/assets/icons/settings.svg"

                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
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

                    // Right border separator with dynamic blue highlight on resize/hover
                    Rectangle {
                        id: rightBorder
                        anchors.right: parent.right
                        width: resizeHandle.containsMouse || resizeHandle.pressed ? 2 : 1
                        height: parent.height
                        color: resizeHandle.containsMouse || resizeHandle.pressed ? "#007acc" : "#2d2d2d"
                        z: 2
                    }

                    // Interactive resize handle area pinned to the right edge
                    MouseArea {
                        id: resizeHandle
                        anchors.right: parent.right
                        width: 6
                        height: parent.height
                        anchors.rightMargin: -3
                        z: 3

                        cursorShape: Qt.SplitHCursor
                        hoverEnabled: true

                        property real globalStartX: 0
                        property real startWidth: 0

                        onPressed: mouse => {
                            // Map local mouse position to global screen space so it stays invariant during resizing
                            globalStartX = mapToItem(null, mouse.x, mouse.y).x;
                            startWidth = quickAccessSidebar.sidebarWidth;
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                // Calculate delta using fixed global space
                                let currentGlobalX = mapToItem(null, mouse.x, mouse.y).x;
                                let delta = currentGlobalX - globalStartX;

                                let newWidth = Math.max(120, Math.min(400, startWidth + delta));
                                quickAccessSidebar.sidebarWidth = newWidth;
                            }
                        }
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
                    property Item renamingItem: null   // the card currently renaming

                    readonly property int currentCount: viewToggle.currentIndex === 1 ? dirGridView.count : dirListView.count

                    function cancelActiveRename() {
                        if (renamingItem && renamingItem.cancelRename)
                            renamingItem.cancelRename();
                        renamingItem = null;
                    }

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
                        contextMenuIndex = index;
                        contextMenu.hasSelection = true;
                        contextMenu.selectionIsFolder = isDir;
                        contextMenu.selectionIsFile = !isDir;
                        contextMenu.selectionCount = Object.keys(selectedIndexes).length;
                        // if the right-clicked item wasn't selected, count is at least 1
                        if (contextMenu.selectionCount === 0)
                            contextMenu.selectionCount = 1;

                        var globalPos = mapToItem(contextMenu.parent, mouseX, mouseY);
                        contextMenu.openAt(globalPos.x, globalPos.y);
                    }

                    function openBackgroundContextMenu(mouseX, mouseY) {
                        contextMenuIndex = -1;
                        contextMenu.hasSelection = false;
                        contextMenu.selectionIsFolder = false;
                        contextMenu.selectionIsFile = false;
                        contextMenu.selectionCount = 0;

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

                    Connections {
                        target: fileSystemModel
                        function onCurrentPathChanged() {
                            viewContainer.clearSelection();
                        }
                        function onNameFilterChanged() {
                            viewContainer.clearSelection();
                        }
                        function onTypeFilterChanged() {
                            viewContainer.clearSelection();
                        }
                        function onSizeFilterChanged() {
                            viewContainer.clearSelection();
                        }
                        function onSortByChanged() {
                            viewContainer.clearSelection();
                        }
                        function onSortOrderChanged() {
                            viewContainer.clearSelection();
                        }
                        function onFoldersFirstChanged() {
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
                            // Only single selection reaches here (menu hides Rename otherwise)

                            if (viewToggle.currentIndex === 1) {
                                // Grid: find the delegate and start inline rename
                                let item = dirGridView.itemAtIndex(viewContainer.contextMenuIndex);
                                if (item && item.startRename)
                                    item.startRename();
                            } else {
                                // List: same idea if you add startRename on list rows later
                                // For now fall back to dialog for list mode if needed
                                let entry = fileSystemModel.get(viewContainer.contextMenuIndex);
                                if (!entry.filePath)
                                    return;
                                renameDialog.targetPath = entry.filePath;
                                renameDialog.originalName = entry.fileName;
                                renameDialog.open();
                            }
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

                    // ============================================================
                    // EMPTY STATE
                    // ============================================================
                    Item {
                        id: emptyState
                        anchors.fill: parent
                        visible: viewContainer.currentCount === 0
                        z: 50

                        Column {
                            anchors.centerIn: parent
                            spacing: 16
                            width: Math.min(280, parent.width - 48)

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 72
                                height: 72
                                radius: 18
                                color: "#1c1c1c"
                                border.color: "#2a2a2a"
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    source: fileSystemModel.nameFilter !== "" ? "qrc:/assets/icons/search.svg" : "qrc:/assets/icons/folder.svg"
                                    sourceSize: Qt.size(32, 32)
                                    opacity: 0.4
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: fileSystemModel.nameFilter !== "" ? "No results" : "This folder is empty"
                                color: "#888888"
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: fileSystemModel.nameFilter !== "" ? "Nothing matches “" + fileSystemModel.nameFilter + "”" : "Drop files here or create a new folder"
                                color: "#555555"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                lineHeight: 1.35
                            }

                            // Optional quick action when empty (not searching)
                            XylaTextButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: fileSystemModel.nameFilter === ""
                                text: "New Folder"
                                Layout.topMargin: 8
                                onClicked: newFolderDialog.open()
                            }
                        }
                    }

                    GridView {
                        id: dirGridView

                        visible: viewToggle.currentIndex === 1 && dirGridView.count > 0
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
                                viewContainer.cancelActiveRename();

                                // Stricter hit-test: only treat as “on item” when the point
                                // lies inside the actual card (175×205) not the whole cell (190×220)
                                var contentPos = mapToItem(dirGridView.contentItem, mouse.x, mouse.y);
                                var item = dirGridView.itemAt(contentPos.x, contentPos.y);

                                if (item) {
                                    // item.x / item.y are relative to contentItem
                                    let localX = contentPos.x - item.x;
                                    let localY = contentPos.y - item.y;
                                    // card is centred-ish inside the cell; accept a small margin
                                    if (localX >= 0 && localX <= 175 && localY >= 0 && localY <= 205) {
                                        mouse.accepted = false;   // let the card MouseArea handle it
                                        return;
                                    }
                                    // otherwise fall through → treat as empty space (rubber-band / clear)
                                }

                                if (mouse.button === Qt.RightButton) {
                                    viewContainer.openBackgroundContextMenu(mouse.x, mouse.y);
                                    return;
                                }

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
                            // onPressed: mouse => {
                            //     // 1. Always hit-test first
                            //     var contentPos = mapToItem(dirGridView.contentItem, mouse.x, mouse.y);
                            //     var item = dirGridView.itemAt(contentPos.x, contentPos.y);
                            //
                            //     if (item) {
                            //         // Press is over a real item → let the delegate MouseArea handle it
                            //         mouse.accepted = false;
                            //         return;
                            //     }
                            //
                            //     // 2. Empty space
                            //     if (mouse.button === Qt.RightButton) {
                            //         viewContainer.openBackgroundContextMenu(mouse.x, mouse.y);
                            //         return;
                            //     }
                            //
                            //     // 3. Left button on empty space → start rubber-band
                            //     startPoint = Qt.point(mouse.x, mouse.y);
                            //     rubberBandGrid.x = mouse.x;
                            //     rubberBandGrid.y = mouse.y;
                            //     rubberBandGrid.width = 0;
                            //     rubberBandGrid.height = 0;
                            //     rubberBandGrid.visible = false;
                            //     draggingSelection = false;
                            //
                            //     if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                            //         viewContainer.clearSelection();
                            //     }
                            // }

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

                            property real cardScale: 0.0
                            scale: cardScale
                            transformOrigin: Item.Center

                            // Initial load bounce
                            Component.onCompleted: entranceAnim.restart()

                            // Trigger animation when the assigned model item or index changes
                            // Connections {
                            //     target: gridCard
                            //     function onIndexChanged() { entranceAnim.restart() }
                            // }

                            // React to model property changes (e.g. folder change or filtering)
                            onFolderNameChanged: entranceAnim.restart()
                            onFolderPathChanged: entranceAnim.restart()

                            onRenameCommitted: newName => {
                                fileSystemModel.rename(folderPath, newName);
                            }

                            ParallelAnimation {
                                id: entranceAnim

                                ScriptAction {
                                    script: gridCard.cardScale = 0.0
                                }

                                NumberAnimation {
                                    target: gridCard
                                    property: "cardScale"
                                    from: 0.0
                                    to: 1.0
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            selected: !!viewContainer.selectedIndexes[index]
                            folderName: model.fileName !== undefined ? model.fileName : ""
                            folderPath: model.filePath !== undefined ? model.filePath : ""
                            isFolder: model.isDir !== undefined ? model.isDir : false
                            fileCount: model.itemCount !== undefined ? model.itemCount : 0
                            fileExtension: model.extension !== undefined ? model.extension : ""
                            fileSize: model.fileSize !== undefined ? model.fileSize : 0
                            // ... mouse area remains identical ...

                            MouseArea {
                                id: gridCardMouseArea
                                anchors.fill: parent
                                z: 50
                                hoverEnabled: true
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onPressed: mouse => {
                                    if (viewContainer.renamingItem && viewContainer.renamingItem !== gridCard)
                                        viewContainer.cancelActiveRename();

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
                        // delegate: XylaFolderCard {
                        //     id: gridCard
                        //
                        //     width: 175
                        //     height: 205
                        //
                        //     z: 1
                        //
                        //     selected: !!viewContainer.selectedIndexes[index]
                        //
                        //     folderName: model.fileName !== undefined ? model.fileName : ""
                        //
                        //     folderPath: model.filePath !== undefined ? model.filePath : ""
                        //
                        //     isFolder: model.isDir !== undefined ? model.isDir : false
                        //
                        //     fileCount: model.itemCount !== undefined ? model.itemCount : 0
                        //
                        //     fileExtension: model.extension !== undefined ? model.extension : ""
                        //
                        //     fileSize: model.fileSize !== undefined ? model.fileSize : 0
                        //
                        //     MouseArea {
                        //         id: gridCardMouseArea
                        //         anchors.fill: parent
                        //         z: 50
                        //         hoverEnabled: true
                        //         preventStealing: true
                        //         acceptedButtons: Qt.LeftButton | Qt.RightButton
                        //
                        //         onPressed: mouse => {
                        //             if (mouse.button === Qt.RightButton) {
                        //                 if (!viewContainer.selectedIndexes[index]) {
                        //                     let newSel = {};
                        //                     newSel[index] = true;
                        //                     viewContainer.selectedIndexes = newSel;
                        //                     viewContainer.lastSelectedIndex = index;
                        //                 }
                        //
                        //                 // Correct mapping that respects scroll offset
                        //                 let p = mapToItem(viewContainer, mouse.x, mouse.y);
                        //                 viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                        //                 return;
                        //             }
                        //
                        //             // Left button → select immediately
                        //             viewContainer.selectIndex(index, mouse);
                        //         }
                        //
                        //         onDoubleClicked: mouse => {
                        //             if (mouse.button === Qt.LeftButton && model.isDir && model.filePath !== undefined && model.filePath !== "") {
                        //                 fileSystemModel.cd(model.filePath);
                        //             }
                        //         }
                        //     }
                        // }

                        ScrollBar.vertical: ScrollBar {
                            id: gridScrollBar

                            z: 200

                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // ============================================================
                    // LIST VIEW
                    // ============================================================
                    Item {
                        id: listPane
                        anchors.fill: parent
                        visible: viewToggle.currentIndex === 0

                        readonly property int rowHeight: 40
                        readonly property int headerHeight: 32
                        readonly property int hMargin: 16
                        readonly property int minColWidth: 72

                        property int colName: 280
                        property int colSize: 100
                        property int colDate: 150
                        property int colType: 90

                        property bool userResized: false

                        readonly property int availableWidth: Math.max(0, width - hMargin)

                        // Direct pairwise column resize with hard boundaries
                        function resizeColumn(columnProp, minWidth, delta) {
                            userResized = true;

                            var current = listPane[columnProp];

                            var totalWidth = colName + colSize + colDate + colType;

                            // Width available for the complete column set.
                            var maxTotalWidth = availableWidth;

                            // How much total width is available after removing
                            // the column currently being resized.
                            var otherColumnsWidth = totalWidth - current;

                            var maxWidth = maxTotalWidth - otherColumnsWidth;

                            // Never allow this column below its minimum
                            // or large enough to push the total beyond the parent.
                            maxWidth = Math.max(minWidth, maxWidth);

                            var newWidth = Math.max(minWidth, Math.min(current + delta, maxWidth));

                            if (newWidth === current)
                                return;
                            listPane[columnProp] = newWidth;
                        }

                        // Auto-distribute only before the user manually adjusts columns
                        function redistribute() {
                            if (userResized)
                                return;
                            var w = availableWidth;
                            if (w <= 0)
                                return;
                            var nMin = Math.max(minColWidth, Math.floor(w * 0.40));
                            var s = Math.max(minColWidth, colSize);
                            var d = Math.max(minColWidth, colDate);
                            var t = Math.max(minColWidth, colType);

                            var remaining = w - s - d - t;
                            if (remaining >= nMin) {
                                colName = remaining;
                            } else {
                                colName = nMin;
                                let fixed = s + d + t;
                                let targetFixed = Math.max(minColWidth * 3, w - nMin);
                                if (fixed > 0) {
                                    let scale = targetFixed / fixed;
                                    colSize = Math.max(minColWidth, Math.floor(s * scale));
                                    colDate = Math.max(minColWidth, Math.floor(d * scale));
                                    colType = Math.max(minColWidth, targetFixed - colSize - colDate);
                                }
                            }
                        }

                        onWidthChanged: {
                            if (!userResized)
                                redistribute();
                        }
                        Component.onCompleted: redistribute()

                        // ---------- Header ----------
                        Rectangle {
                            id: listHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: listPane.headerHeight
                            color: "#181818"
                            z: 20

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "#2a2a2a"
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                // Name
                                Item {
                                    width: listPane.colName
                                    height: parent.height

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: nameHandle.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        text: "Name"
                                        color: "#999999"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: nameHandle
                                        width: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: -6
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        cursorShape: Qt.SplitHCursor
                                        hoverEnabled: true
                                        z: 10
                                        property real startX: 0

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 1
                                            height: parent.height * 0.5
                                            color: parent.containsMouse || parent.pressed ? "#2555D3" : "#2d2d2d"
                                        }

                                        onPressed: mouse => {
                                            startX = mapToItem(null, mouse.x, mouse.y).x;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            var currentX = mapToItem(null, mouse.x, mouse.y).x;
                                            var delta = currentX - startX;
                                            startX = currentX;
                                            listPane.resizeColumn("colName", listPane.minColWidth, delta);
                                        }
                                    }
                                }

                                // Size
                                Item {
                                    width: listPane.colSize
                                    height: parent.height

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: sizeHandle.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        text: "Size"
                                        color: "#999999"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: sizeHandle
                                        width: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: -6
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        cursorShape: Qt.SplitHCursor
                                        hoverEnabled: true
                                        z: 10
                                        property real startX: 0

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 1
                                            height: parent.height * 0.5
                                            color: parent.containsMouse || parent.pressed ? "#2555D3" : "#2d2d2d"
                                        }

                                        onPressed: mouse => {
                                            startX = mapToItem(null, mouse.x, mouse.y).x;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            var currentX = mapToItem(null, mouse.x, mouse.y).x;
                                            var delta = currentX - startX;
                                            startX = currentX;
                                            listPane.resizeColumn("colSize", listPane.minColWidth, delta);
                                        }
                                    }
                                }

                                // Date
                                Item {
                                    width: listPane.colDate
                                    height: parent.height

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: dateHandle.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        text: "Date Modified"
                                        color: "#999999"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: dateHandle
                                        width: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: -6
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        cursorShape: Qt.SplitHCursor
                                        hoverEnabled: true
                                        z: 10
                                        property real startX: 0

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 1
                                            height: parent.height * 0.5
                                            color: parent.containsMouse || parent.pressed ? "#2555D3" : "#2d2d2d"
                                        }

                                        onPressed: mouse => {
                                            startX = mapToItem(null, mouse.x, mouse.y).x;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            var currentX = mapToItem(null, mouse.x, mouse.y).x;
                                            var delta = currentX - startX;
                                            startX = currentX;
                                            listPane.resizeColumn("colDate", listPane.minColWidth, delta);
                                        }
                                    }
                                }

                                // Type
                                Item {
                                    width: listPane.colType
                                    height: parent.height

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Type"
                                        color: "#999999"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // ---------- List View ----------
                        ListView {
                            id: dirListView
                            anchors.top: listHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom

                            visible: count > 0
                            clip: true
                            topMargin: 4
                            bottomMargin: 8
                            leftMargin: 8
                            rightMargin: 8
                            spacing: 2
                            model: fileSystemModel

                            contentWidth: listPane.colName + listPane.colSize + listPane.colDate + listPane.colType

                            MouseArea {
                                id: listRubberBandMouseArea
                                anchors.fill: parent
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
                                    var stride = listPane.rowHeight + dirListView.spacing;

                                    for (let i = 0; i < dirListView.count; ++i) {
                                        let itemY = dirListView.topMargin + i * stride;
                                        if (!(itemY > boxBottom || (itemY + listPane.rowHeight) < boxTop))
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
                                id: rowRoot
                                width: Math.max(dirListView.width - dirListView.leftMargin - dirListView.rightMargin, listPane.colName + listPane.colSize + listPane.colDate + listPane.colType)
                                height: listPane.rowHeight
                                z: 1
                                radius: 4

                                property bool isSelected: !!viewContainer.selectedIndexes[index]

                                color: isSelected ? "#2b4263" : (rowMouse.containsMouse ? "#1f1f1f" : "transparent")

                                border.color: isSelected ? "#3c6ce7" : (rowMouse.containsMouse ? "#2a2a2a" : "#222222")
                                border.width: 1

                                function formatBytes(bytes) {
                                    bytes = Number(bytes) || 0;
                                    if (bytes <= 0)
                                        return "—";
                                    if (bytes < 1024)
                                        return bytes + " B";
                                    if (bytes < 1024 * 1024)
                                        return (bytes / 1024).toFixed(1) + " KB";
                                    if (bytes < 1024 * 1024 * 1024)
                                        return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                                    return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
                                }

                                function formatDate(dt) {
                                    if (!dt)
                                        return "—";
                                    return Qt.formatDateTime(dt, "dd MMM yyyy  HH:mm");
                                }

                                Row {
                                    anchors.fill: parent

                                    Item {
                                        width: listPane.colName
                                        height: parent.height

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            Image {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 18
                                                height: 18
                                                source: model.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file-text.svg"
                                                sourceSize: Qt.size(18, 18)
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 28
                                                text: model.fileName !== undefined ? model.fileName : ""
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Item {
                                        width: listPane.colSize
                                        height: parent.height

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: Text.AlignVCenter
                                            text: model.isDir ? "—" : rowRoot.formatBytes(model.fileSize)
                                            color: "#888888"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Item {
                                        width: listPane.colDate
                                        height: parent.height

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: Text.AlignVCenter
                                            text: rowRoot.formatDate(model.lastModified)
                                            color: "#888888"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Item {
                                        width: listPane.colType
                                        height: parent.height

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: Text.AlignVCenter
                                            text: model.isDir ? "Folder" : ((model.extension && model.extension !== "") ? model.extension.toUpperCase() : "File")
                                            color: "#888888"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
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
                                            viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                                            return;
                                        }
                                        viewContainer.selectIndex(index, mouse);
                                    }

                                    onDoubleClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton && model.isDir && model.filePath)
                                            fileSystemModel.cd(model.filePath);
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                z: 200
                                policy: ScrollBar.AsNeeded
                            }

                            ScrollBar.horizontal: ScrollBar {
                                z: 200
                                policy: ScrollBar.AsNeeded
                            }
                        }
                    }

                    // ListView {
                    //     id: dirListView
                    //
                    //     visible: viewToggle.currentIndex === 0
                    //     anchors.fill: parent
                    //
                    //     clip: true
                    //
                    //     topMargin: 8
                    //     bottomMargin: 8
                    //     leftMargin: 12
                    //     rightMargin: 12
                    //
                    //     spacing: 2
                    //
                    //     model: fileSystemModel
                    //
                    //     MouseArea {
                    //         id: listRubberBandMouseArea
                    //
                    //         anchors.left: parent.left
                    //         anchors.top: parent.top
                    //         anchors.bottom: parent.bottom
                    //         anchors.right: parent.right
                    //
                    //         z: 10
                    //         preventStealing: true
                    //         acceptedButtons: Qt.LeftButton | Qt.RightButton
                    //
                    //         property point startPoint
                    //         property bool draggingSelection: false
                    //
                    //         onPressed: mouse => {
                    //             var contentPos = mapToItem(dirListView.contentItem, mouse.x, mouse.y);
                    //             var item = dirListView.itemAt(contentPos.x, contentPos.y);
                    //
                    //             if (item) {
                    //                 mouse.accepted = false;
                    //                 return;
                    //             }
                    //
                    //             if (mouse.button === Qt.RightButton) {
                    //                 viewContainer.openBackgroundContextMenu(mouse.x, mouse.y);
                    //                 return;
                    //             }
                    //
                    //             startPoint = Qt.point(mouse.x, mouse.y);
                    //             draggingSelection = false;
                    //
                    //             rubberBandList.x = mouse.x;
                    //             rubberBandList.y = mouse.y;
                    //             rubberBandList.width = 0;
                    //             rubberBandList.height = 0;
                    //             rubberBandList.visible = false;
                    //
                    //             if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    //                 viewContainer.clearSelection();
                    //             }
                    //         }
                    //
                    //         onPositionChanged: mouse => {
                    //             if (!draggingSelection && !rubberBandList.visible) {
                    //                 let dist = Math.sqrt(Math.pow(mouse.x - startPoint.x, 2) + Math.pow(mouse.y - startPoint.y, 2));
                    //                 if (dist <= 3)
                    //                     return;
                    //                 draggingSelection = true;
                    //                 rubberBandList.visible = true;
                    //             }
                    //
                    //             if (!draggingSelection)
                    //                 return;
                    //             var rx = Math.min(startPoint.x, mouse.x);
                    //             var ry = Math.min(startPoint.y, mouse.y);
                    //             var rw = Math.abs(mouse.x - startPoint.x);
                    //             var rh = Math.abs(mouse.y - startPoint.y);
                    //
                    //             rubberBandList.x = rx;
                    //             rubberBandList.y = ry;
                    //             rubberBandList.width = rw;
                    //             rubberBandList.height = rh;
                    //
                    //             var newSel = (mouse.modifiers & Qt.ControlModifier) ? Object.assign({}, viewContainer.selectedIndexes) : {};
                    //
                    //             var boxTop = ry + dirListView.contentY;
                    //             var boxBottom = boxTop + rh;
                    //             var itemStride = 40 + dirListView.spacing;
                    //
                    //             for (let i = 0; i < dirListView.count; ++i) {
                    //                 let itemY = dirListView.topMargin + (i * itemStride);
                    //                 let intersects = !(itemY > boxBottom || (itemY + 40) < boxTop);
                    //                 if (intersects)
                    //                     newSel[i] = true;
                    //             }
                    //             viewContainer.selectedIndexes = newSel;
                    //         }
                    //
                    //         onReleased: {
                    //             draggingSelection = false;
                    //             rubberBandList.visible = false;
                    //         }
                    //         onCanceled: {
                    //             draggingSelection = false;
                    //             rubberBandList.visible = false;
                    //         }
                    //     }
                    //
                    //     Rectangle {
                    //         id: rubberBandList
                    //
                    //         z: 100
                    //
                    //         visible: false
                    //
                    //         color: "#332555D3"
                    //         border.color: "#2555D3"
                    //         border.width: 1
                    //     }
                    //
                    //     delegate: Rectangle {
                    //         width: dirListView.width - dirListView.leftMargin - dirListView.rightMargin
                    //
                    //         height: 40
                    //
                    //         z: 1
                    //
                    //         property bool isSelected: !!viewContainer.selectedIndexes[index]
                    //
                    //         color: isSelected ? "#2b4263" : (mouseArea.containsMouse ? "#1f1f1f" : "transparent")
                    //
                    //         border.color: isSelected ? "#3c6ce7" : "transparent"
                    //
                    //         border.width: isSelected ? 1 : 0
                    //         radius: 4
                    //
                    //         RowLayout {
                    //             anchors.fill: parent
                    //
                    //             anchors.leftMargin: 10
                    //             anchors.rightMargin: 10
                    //
                    //             spacing: 10
                    //
                    //             Image {
                    //                 Layout.preferredWidth: 20
                    //                 Layout.preferredHeight: 20
                    //
                    //                 source: model.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file-text.svg"
                    //
                    //                 sourceSize.width: 20
                    //                 sourceSize.height: 20
                    //             }
                    //
                    //             Text {
                    //                 Layout.fillWidth: true
                    //                 Layout.preferredWidth: 0
                    //
                    //                 text: model.fileName !== undefined ? model.fileName : ""
                    //
                    //                 color: "#ffffff"
                    //                 font.pixelSize: 12
                    //                 elide: Text.ElideRight
                    //             }
                    //
                    //             Text {
                    //                 visible: model.isDir !== undefined && model.isDir
                    //
                    //                 text: (model.itemCount !== undefined ? model.itemCount : 0) + " items"
                    //
                    //                 color: "#666666"
                    //                 font.pixelSize: 11
                    //             }
                    //
                    //             Text {
                    //                 visible: model.isDir !== undefined && !model.isDir
                    //
                    //                 text: (model.extension !== undefined && model.extension !== "") ? model.extension.toUpperCase() : ""
                    //
                    //                 color: "#666666"
                    //                 font.pixelSize: 11
                    //
                    //                 Layout.preferredWidth: 50
                    //             }
                    //         }
                    //
                    //         MouseArea {
                    //             id: mouseArea
                    //
                    //             anchors.fill: parent
                    //
                    //             hoverEnabled: true
                    //             preventStealing: true
                    //
                    //             acceptedButtons: Qt.LeftButton | Qt.RightButton
                    //
                    //             onPressed: mouse => {
                    //                 if (mouse.button === Qt.RightButton) {
                    //                     if (!viewContainer.selectedIndexes[index]) {
                    //                         let newSel = {};
                    //                         newSel[index] = true;
                    //                         viewContainer.selectedIndexes = newSel;
                    //                         viewContainer.lastSelectedIndex = index;
                    //                     }
                    //
                    //                     let p = mapToItem(viewContainer, mouse.x, mouse.y);
                    //                     // let p = viewContainer.mapToItem(contextMenu.parent, mouse.x //  + parent.x,
                    //                     // , mouse.y // + parent.y
                    //                     // );
                    //
                    //                     viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                    //                     return;
                    //                 }
                    //
                    //                 viewContainer.selectIndex(index, mouse);
                    //             }
                    //
                    //             onClicked: mouse => {
                    //                 if (mouse.button === Qt.LeftButton) {
                    //                     viewContainer.selectIndex(index, mouse);
                    //                 }
                    //             }
                    //
                    //             onDoubleClicked: mouse => {
                    //                 if (mouse.button === Qt.LeftButton && model.isDir && model.filePath !== undefined && model.filePath !== "") {
                    //                     fileSystemModel.cd(model.filePath);
                    //                 }
                    //             }
                    //         }
                    //     }
                    //
                    //     ScrollBar.vertical: ScrollBar {
                    //         z: 200
                    //
                    //         policy: ScrollBar.AsNeeded
                    //     }
                    // }
                }

                // ============================================================
                // FILE DETAILS & PREVIEW SIDEBAR (RIGHT SECTION)
                // ============================================================
                //
                Rectangle {
                    id: detailsSidebar

                    property real sidebarWidth: 280

                    // Derived from the real selection (single item only)
                    property var selectedItem: {
                        var keys = Object.keys(viewContainer.selectedIndexes);
                        if (keys.length !== 1)
                            return null;
                        return fileSystemModel.get(parseInt(keys[0]));
                    }

                    property bool isImage: {
                        if (!selectedItem || selectedItem.isDir)
                            return false;
                        var ext = (selectedItem.extension || "").toLowerCase();
                        return ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg"].indexOf(ext) !== -1;
                    }

                    property bool isVideo: {
                        if (!selectedItem || selectedItem.isDir)
                            return false;
                        var ext = (selectedItem.extension || "").toLowerCase();
                        return ["mp4", "mkv", "avi", "mov", "webm", "m4v"].indexOf(ext) !== -1;
                    }

                    function humanSize(bytes) {
                        bytes = Number(bytes) || 0;
                        if (bytes < 1024)
                            return bytes + " B";
                        if (bytes < 1024 * 1024)
                            return (bytes / 1024).toFixed(1) + " KB";
                        if (bytes < 1024 * 1024 * 1024)
                            return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
                    }

                    function formatDate(dt) {
                        if (!dt)
                            return "—";
                        return Qt.formatDateTime(dt, "dd MMM yyyy  HH:mm");
                    }

                    Layout.preferredWidth: sidebarWidth
                    Layout.fillHeight: true
                    color: "#151515"
                    clip: true

                    // Left edge + resize handle
                    Rectangle {
                        id: leftBorder
                        anchors.left: parent.left
                        width: resizeHandleRight.containsMouse || resizeHandleRight.pressed ? 2 : 1
                        height: parent.height
                        color: resizeHandleRight.containsMouse || resizeHandleRight.pressed ? "#2555D3" : "#2d2d2d"
                        z: 2
                    }

                    MouseArea {
                        id: resizeHandleRight
                        anchors.left: parent.left
                        width: 6
                        height: parent.height
                        anchors.leftMargin: -3
                        z: 3
                        cursorShape: Qt.SplitHCursor
                        hoverEnabled: true

                        property real globalStartX: 0
                        property real startWidth: 0

                        onPressed: mouse => {
                            globalStartX = mapToItem(null, mouse.x, mouse.y).x;
                            startWidth = detailsSidebar.sidebarWidth;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            var currentGlobalX = mapToItem(null, mouse.x, mouse.y).x;
                            var delta = globalStartX - currentGlobalX;
                            detailsSidebar.sidebarWidth = Math.max(220, Math.min(420, startWidth + delta));
                        }
                    }

                    // ============================================================
                    // CONTENT
                    // ============================================================
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 20
                        anchors.bottomMargin: 16
                        spacing: 0

                        // ---------- EMPTY STATE ----------
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: {
                                var n = Object.keys(viewContainer.selectedIndexes).length;
                                return n !== 1;
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 14
                                width: parent.width - 24

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 64
                                    height: 64
                                    radius: 16
                                    color: "#1c1c1c"
                                    border.color: "#2a2a2a"
                                    border.width: 1

                                    Image {
                                        anchors.centerIn: parent
                                        source: Object.keys(viewContainer.selectedIndexes).length > 1 ? "qrc:/assets/icons/copy.svg" : "qrc:/assets/icons/file.svg"
                                        sourceSize: Qt.size(28, 28)
                                        opacity: 0.35
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Object.keys(viewContainer.selectedIndexes).length > 1 ? "Multiple items selected" : "No selection"
                                    color: "#666666"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Object.keys(viewContainer.selectedIndexes).length > 1 ? "Select only one item to preview" : "Select a file or folder\nto see details"
                                    color: "#444444"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }
                            }
                        }

                        // ---------- SELECTED STATE ----------
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: !!detailsSidebar.selectedItem
                            spacing: 16

                            // ---- Preview card (centered) ----
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 200
                                radius: 10
                                color: "#111111"
                                border.color: "#2a2a2a"
                                border.width: 1
                                clip: true

                                // TODO: Put Previews in place of these commented out snippets
                                // Real image preview
                                // Image {
                                //     anchors.fill: parent
                                //     anchors.margins: 8
                                //     visible: detailsSidebar.isImage
                                //     source: visible ? ("file://" + detailsSidebar.selectedItem.filePath) : ""
                                //     fillMode: Image.PreserveAspectFit
                                //     asynchronous: true
                                //     cache: true
                                // }

                                // Video thumbnail
                                // MediaPlayer {
                                //     id: videoPlayer
                                //     source: detailsSidebar.isVideo ? ("file://" + detailsSidebar.selectedItem.filePath) : ""
                                //     videoOutput: videoOutput
                                //     audioOutput: AudioOutput {
                                //         muted: true
                                //     }
                                //
                                //     onMediaStatusChanged: {
                                //         if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                                //             pause();
                                //             position = 1000;
                                //         }
                                //     }
                                // }

                                // VideoOutput {
                                //     id: videoOutput
                                //     anchors.fill: parent
                                //     anchors.margins: 8
                                //     visible: detailsSidebar.isVideo
                                //     fillMode: VideoOutput.PreserveAspectFit
                                //     z: 1
                                // }
                                // Video {
                                //     id: videoPreview
                                //     anchors.fill: parent
                                //     anchors.margins: 8
                                //     visible: detailsSidebar.isVideo
                                //     source: visible ? ("file://" + detailsSidebar.selectedItem.filePath) : ""
                                //     fillMode: VideoOutput.PreserveAspectFit
                                //     muted: true
                                //     autoPlay: true
                                //
                                // onMediaStatusChanged: {
                                //     // Freeze on a frame ~1s in
                                //     if (mediaStatus === MediaPlayer.LoadedMedia ||
                                //         mediaStatus === MediaPlayer.BufferedMedia) {
                                //         pause()
                                //         position = 1000   // milliseconds (no seek() on Video in Qt 6)
                                //     }
                                // }
                                //
                                //     // Play badge
                                //     Rectangle {
                                //         anchors.centerIn: parent
                                //         width: 36; height: 36; radius: 18
                                //         color: "#80000000"
                                //         visible: videoPreview.visible
                                //
                                //         Text {
                                //             anchors.centerIn: parent
                                //             text: "▶"
                                //             color: "#ffffff"
                                //             font.pixelSize: 14
                                //         }
                                //     }
                                // }

                                // Fallback icon + type badge (centered)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    z: 0
                                    // TODO: toggle visibility after implementing previews
                                    visible: true // !detailsSidebar.isImage && !detailsSidebar.isVideo

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 72
                                        height: 72
                                        radius: 18
                                        color: "#1c1c1c"
                                        border.color: "#2d2d2d"
                                        border.width: 1

                                        Image {
                                            anchors.centerIn: parent
                                            source: detailsSidebar.selectedItem && detailsSidebar.selectedItem.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
                                            sourceSize: Qt.size(32, 32)
                                            opacity: 0.85
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: {
                                            if (!detailsSidebar.selectedItem)
                                                return "";
                                            if (detailsSidebar.selectedItem.isDir)
                                                return "FOLDER";
                                            var ext = (detailsSidebar.selectedItem.extension || "").toUpperCase();
                                            return ext !== "" ? ext : "FILE";
                                        }
                                        color: "#666666"
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                    }
                                }
                            }

                            // ---- Name (centered) ----
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: detailsSidebar.selectedItem ? (detailsSidebar.selectedItem.fileName || "") : ""
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                            }

                            // ---- Quick actions row (centered) ----
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                XylaIconButton {
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/copy.svg"
                                    iconWidth: 14
                                    iconHeight: 14
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Copy path"
                                    onClicked: {
                                        if (detailsSidebar.selectedItem && detailsSidebar.selectedItem.filePath)
                                            fileSystemModel.copyToClipboard(detailsSidebar.selectedItem.filePath);
                                    }
                                }

                                XylaIconButton {
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/edit.svg"
                                    iconWidth: 14
                                    iconHeight: 14
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Rename"
                                    onClicked: {
                                        if (!detailsSidebar.selectedItem)
                                            return;
                                        renameDialog.targetPath = detailsSidebar.selectedItem.filePath;
                                        renameDialog.originalName = detailsSidebar.selectedItem.fileName;
                                        renameDialog.open();
                                    }
                                }

                                XylaIconButton {
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/info.svg"
                                    iconWidth: 14
                                    iconHeight: 14
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Properties"
                                    onClicked: {
                                        if (detailsSidebar.selectedItem)
                                            propertiesDialog.openWith(detailsSidebar.selectedItem);
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#2a2a2a"
                            }

                            // ---- Metadata list ----
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: availableWidth

                                ColumnLayout {
                                    width: parent.width
                                    spacing: 14

                                    // Helper component style via repeated blocks
                                    Repeater {
                                        model: {
                                            if (!detailsSidebar.selectedItem)
                                                return [];
                                            var item = detailsSidebar.selectedItem;
                                            var rows = [
                                                {
                                                    label: "Type",
                                                    value: item.isDir ? "Folder" : ((item.extension || "").toUpperCase() + " File")
                                                },
                                                {
                                                    label: "Size",
                                                    value: item.isDir ? ((item.itemCount || 0) + " items") : detailsSidebar.humanSize(item.fileSize)
                                                },
                                                {
                                                    label: "Modified",
                                                    value: detailsSidebar.formatDate(item.lastModified)
                                                }
                                            ];
                                            if (!item.isDir && item.extension)
                                                rows.push({
                                                    label: "Extension",
                                                    value: "." + item.extension.toLowerCase()
                                                });
                                            rows.push({
                                                label: "Location",
                                                value: item.filePath ? item.filePath.substring(0, item.filePath.lastIndexOf("/")) : "—"
                                            });
                                            rows.push({
                                                label: "Full path",
                                                value: item.filePath || "—"
                                            });
                                            return rows;
                                        }

                                        delegate: ColumnLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                text: modelData.label
                                                color: "#666666"
                                                font.pixelSize: 11
                                                font.bold: true
                                                font.letterSpacing: 0.3
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.value
                                                color: "#d0d0d0"
                                                font.pixelSize: 12
                                                elide: Text.ElideMiddle
                                                wrapMode: Text.WrapAnywhere
                                                maximumLineCount: 3
                                            }
                                        }
                                    }
                                }
                            }
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

                    // Full-width path / selection display
                    Item {
                        Layout.fillWidth: true
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
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                id: selectionLabel
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideMiddle
                                color: "#e0e0e0"
                                font.pixelSize: 12

                                property var sel: viewContainer.selectedIndexes

                                text: {
                                    var keys = Object.keys(sel);
                                    if (keys.length === 0)
                                        return "";
                                    if (keys.length === 1) {
                                        let idx = parseInt(keys[0]);
                                        let item = fileSystemModel.get(idx);
                                        if (item && item.filePath)
                                            return item.filePath;
                                        if (item && item.fileName)
                                            return item.fileName;
                                        return "";
                                    }
                                    return keys.length + " items selected";
                                }
                            }

                            XylaIconButton {
                                visible: Object.keys(viewContainer.selectedIndexes).length === 1
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

                    XylaTextButton {
                        Layout.leftMargin: 36
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
