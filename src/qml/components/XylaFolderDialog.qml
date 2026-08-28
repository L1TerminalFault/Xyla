import QtQuick
import QtQuick.Shapes

import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Window {
    id: folderDialogRoot

    // property bool selectExisting: false
    property bool selectMultiple: false

    // Caller sets these:
    //   returnType: "folder" | "file" | "image" | "video" | "audio"
    //               | "document" | "archive" | "" (any file)
    //   nameFilter: "" = all in that category
    //               or one extension: "png", "mp4", "pdf", ...
    property string returnType
    property string nameFilter: ""
readonly property bool isPicker: returnType.length > 0
readonly property string resolvedTitle: {
    // if (dialogTitle && dialogTitle.length)
    //     return dialogTitle
    if (!isPicker)
        return "Xyla File Manager"
    const multi = selectMultiple
    switch (returnType.toLowerCase().trim()) {
    case "folder":   return multi ? "Select Folders" : "Select Folder"
    case "file":     return multi ? "Select Files"   : "Select a File"
    case "image":    return multi ? "Select Images"  : "Select Image"
    case "video":    return multi ? "Select Videos"  : "Select Video"
    case "audio":    return multi ? "Select Audio"   : "Select Audio"
    case "document": return multi ? "Select Documents" : "Select Document"
    case "archive":  return multi ? "Select Archives"  : "Select Archive"
    default:         return multi ? "Select Items"   : "Select Item"
    }
}

function itemIsSelectable(index) {
    if (!isPicker)
        return true
    const item = fileSystemModel.get(index)
    if (!item || !item.filePath)
        return false
    const kind = returnType.toLowerCase().trim()
    if (kind === "folder")
        return item.isDir === true
    if (item.isDir)
        return false
    return matchesReturnType(item.filePath)
}

function clampSelection(sel) {
    const keys = Object.keys(sel)
    const next = {}
    for (let i = 0; i < keys.length; ++i) {
        const idx = Number(keys[i])
        if (itemIsSelectable(idx))
            next[idx] = true
    }
    const kept = Object.keys(next)
    if (!selectMultiple && kept.length > 1) {
        const only = kept[kept.length - 1]
        return { [only]: true }
    }
    return next
}

Connections {
    target: fileSystemModel
// function onLoadingChanged() {
//     if (fileSystemModel.loading)
//         return
//     viewContainer.flushPendingRename()
//     Qt.callLater(function () {
//         viewContainer.suppressMotion = false
//         viewContainer.pendingRenameName = ""
//     })
// }
    function onLoadingChanged() {
        if (fileSystemModel.loading)
            return
        viewContainer.flushPendingRename()
        viewContainer.suppressMotion = false     // FIX A: restore loader/bounce
    }
}

    readonly property bool pickingFolder: returnType.toLowerCase() === "folder"

    readonly property var _filterCatalog: ({
        image: {
            label: "Image Files",
            exts: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "tiff"]
        },
        video: {
            label: "Video Files",
            exts: ["mp4", "mkv", "avi", "mov", "webm", "m4v"]
        },
        audio: {
            label: "Audio Files",
            exts: ["mp3", "wav", "flac", "aac", "ogg", "m4a"]
        },
        document: {
            label: "Documents",
            exts: ["pdf", "doc", "docx", "txt", "odt", "rtf", "md"]
        },
        archive: {
            label: "Archives",
            exts: ["zip", "tar", "gz", "tgz", "rar", "7z", "xz"]
        }
    })

    readonly property var nameFilters: {
        const kind = returnType.toLowerCase().trim()
        const spec = nameFilter.toLowerCase().replace(/^\./, "").trim()

        if (kind === "folder")
            return []

        const cat = _filterCatalog[kind]
        if (!cat) {
            // "" or "file" → any file
            return ["All Files (*)"]
        }

        const glob = e => "*." + e

        if (spec.length > 0) {
            if (cat.exts.indexOf(spec) < 0)
                console.warn("FilePicker: unknown nameFilter '" + spec
                             + "' for returnType '" + kind + "'")
            const extra = (spec === "jpg") ? ["*.jpeg"]
                        : (spec === "jpeg") ? ["*.jpg"]
                        : []
            return [
                spec.toUpperCase() + " (*." + spec + (extra.length ? " " + extra.join(" ") : "") + ")",
                cat.label + " (" + cat.exts.map(glob).join(" ") + ")",
                "All Files (*)"
            ]
        }

        return [
            cat.label + " (" + cat.exts.map(glob).join(" ") + ")",
            "All Files (*)"
        ]
    }

    // Use this when matching a chosen path (not the dialog combo box).
    function matchesReturnType(filePath) {
        const kind = returnType.toLowerCase().trim()
        if (kind === "folder" || kind === "" || kind === "file")
            return true

        const cat = _filterCatalog[kind]
        if (!cat)
            return true

        const spec = nameFilter.toLowerCase().replace(/^\./, "").trim()
        const ext = filePath.toLowerCase().split(".").pop()
        if (spec.length > 0) {
            if (spec === "jpg" || spec === "jpeg")
                return ext === "jpg" || ext === "jpeg"
            return ext === spec
        }
        return cat.exts.indexOf(ext) >= 0
    }

    title: resolvedTitle
    width: 1453
    height: 920
    minimumWidth: 700
    minimumHeight: 450

    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    signal folderSelected(var paths)

    function open() {
        folderDialogRoot.show();
        folderDialogRoot.requestActivate();
    }

    function hideDialog() {
        folderDialogRoot.hide();
    }

function triggerRenameForIndex(targetIndex) {
    if (targetIndex < 0 || targetIndex >= fileSystemModel.rowCount())
        return

    viewContainer.suppressMotion = true          // FIX A

    if (viewToggle.currentIndex === 1) {
        const go = item => {
            if (!item || !item.startRename)
                return false
            if (item.entranceAnim)
                item.entranceAnim.stop()
            if (item.cardScale !== undefined)
                item.cardScale = 1.0
            item.startRename()
            return true
        }
        if (!go(dirGridView.itemAtIndex(targetIndex))) {
            dirGridView.positionViewAtIndex(targetIndex, GridView.Center)
            Qt.callLater(() => go(dirGridView.itemAtIndex(targetIndex)))
        }
    } else {
        const entry = fileSystemModel.get(targetIndex)
        if (!entry || !entry.filePath)
            return
        renameDialog.targetPath = entry.filePath
        renameDialog.originalName = entry.fileName
        renameDialog.open()
    }
}

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
        border.color: "#202020"
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

                    source: folderDialogRoot.returnType === "folder" ? "qrc:/assets/icons/folder-open.svg" : "qrc:/assets/icons/file.svg" // : ""

                    sourceSize.width: 18
                    sourceSize.height: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: titleIcon.right
                    anchors.leftMargin: 12
                    text: folderDialogRoot.resolvedTitle
                    color: "#ffffff"
                    font.pixelSize: 14
                }

                XylaIconButton {
                    id: fullscreenBtn

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 6

                    ghost: true
                    iconSource: folderDialogRoot.visibility === Window.FullScreen ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/fullscreen.svg"
                    tooltip: "Fullscreen"

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
                    tooltip: "Close"
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
                        border.color: "#202020"
                        border.width: 1
                        radius: 6

                        Row {
                            id: navRow
                            anchors.centerIn: parent
                            spacing: 0

                            XylaIconButton {
                                id: cdBackButton
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-left.svg"
                                enabled: fileSystemModel.canCdBack
                                opacity: enabled ? 1.0 : 0.3
                                onClicked: fileSystemModel.cdBack()

                                XylaToolTip {
                                    visible: cdBackButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                    text: "Navigate Back"
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                id: cdForwardButton
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-right.svg"
                                enabled: fileSystemModel.canCdForward
                                opacity: enabled ? 1.0 : 0.3
                                onClicked: fileSystemModel.cdForward()

                                XylaToolTip {
                                    visible: cdForwardButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                    text: "Navigate Forward"
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                id: cdUpButton
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/arrow-up.svg"
                                onClicked: fileSystemModel.cdUp()

                                XylaToolTip {
                                    visible: cdUpButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                    text: "Navigate Up"
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            XylaIconButton {
                                id: refreshButton
                                width: 28
                                height: 28
                                ghost: true
                                iconWidth: 14
                                iconHeight: 14
                                iconSource: "qrc:/assets/icons/refresh.svg"
                                onClicked: fileSystemModel.refresh()

                                XylaToolTip {
                                    visible: refreshButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                    text: "Refresh"
                                }
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
                            viewContainer.suppressMotion = true          // FIX A
                            if (fileSystemModel.rename(targetPath, newName))
                                renameDialog.close()
                            else
                                renameDialog.errorMessage = fileSystemModel.lastError
                        }
                    }

                    XylaSettingsWindow {
                        id: settingsWindow
                    }

                    // FIX: Bug not selecting the new folder
                    XylaIconButton {
                        id: newFolderButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        iconSource: "qrc:/assets/icons/folder-plus.svg"

                        XylaToolTip {
                            visible: newFolderButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                            text: "Create New Folder"
                        }
// onClicked: {
//     viewContainer.suppressMotion = true
//     const createdName = fileSystemModel.makeFolder("New folder")
//     if (!createdName) {
//         viewContainer.suppressMotion = false
//         return
//     }
//     viewContainer.pendingRenameName = createdName
//     if (!fileSystemModel.loading)
//         viewContainer.flushPendingRename()
// }
                        onClicked: {
                            const createdName = fileSystemModel.makeFolder("New folder")
                            if (!createdName)
                                return
                            viewContainer.suppressMotion = true          // FIX A
                            viewContainer.pendingRenameName = createdName
                            if (!fileSystemModel.loading)
                                viewContainer.flushPendingRename()
                        }
                    }

                    XylaPathInput {
                        id: pathDisplay
                    }

                    Item {
                        id: searchComponent
                        implicitWidth: 32
                        implicitHeight: 32

                        property bool searchVisible: false
                        property alias text: searchInput.text
                        property alias placeholderText: searchInput.placeholderText
                        property alias inputItem: searchInput

                        // Function to close search popup and reset focus
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
                            primary: searchComponent.searchVisible || searchInput.text.trim().length > 0

                            XylaToolTip {
                                visible: searchBtn.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                text: "Search"
                            }

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

                            closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

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

                            // Exact matching scale and opacity transitions from your context menu
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

                            onAboutToHide: {
                                searchComponent.searchVisible = false;
                                searchInput.focus = false;          // force lose focus
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

                                onTextChanged: {
                                    fileSystemModel.nameFilter = text.trim();
                                }

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

                    XylaSelect {
                        id: sortFilter

                        Layout.preferredWidth: 140

                        icon: "qrc:/assets/icons/sort.svg"

                        tooltip: "Select Filter"

                        model: ["Name", "Date Modified", "Size", "Type"]

                        currentIndex: model.indexOf(fileSystemModel.fileManagerSettings.sortMode)

                        onActivated: {
                            fileSystemModel.fileManagerSettings.sortMode = model[currentIndex];
                        }
                    }

                    Rectangle {
                        implicitWidth: rowLayout.implicitWidth
                        implicitHeight: rowLayout.implicitHeight
                        radius: 6
                        color: "#181818"
                        border.color: "#2d2d2d"
                        border.width: 1

                        Row {
                            id: rowLayout
                            spacing: 0

                            XylaIconButton {
                                id: sortOrderToggle
                                ghost: true

                                property bool isAscending: fileSystemModel.sortOrder === "ascending"

                                // XylaToolTip {
                                //     visible: sortOrderToggle.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                tooltip: sortOrderToggle.isAscending ? "Sort Ascending" : "Sort Descending"
                                //     delay: 500
                                // }

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

                            Rectangle {
                                width: 1
                                height: 16
                                color: "#2d2d2d"
                                anchors.verticalCenter: rowLayout.verticalCenter
                            }

                            XylaIconButton {
                                id: folderOrderToggle
                                ghost: true

                                property bool foldersFirst: fileSystemModel.foldersFirst

                                // XylaToolTip {
                                //     visible: folderOrderToggle.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                tooltip: folderOrderToggle.foldersFirst ? "Folders at Top" : "Folders at Bottom"
                                //     delay: 500
                                // }

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
                        }
                    }

                    // 5. List vs Grid Segmented View Toggle
                    XylaSegmentedToggle {
                        id: viewToggle

                        currentIndex: fileSystemModel.fileManagerSettings.defaultView.toLowerCase() === "list" ? 0 : 1

                        options: [
                            {
                                icon: "qrc:/assets/icons/list.svg",
                                value: "list",
                                tooltip: "List View"
                            },
                            {
                                icon: "qrc:/assets/icons/layout-grid.svg",
                                value: "grid",
                                tooltip: "Grid View"
                            }
                        ]

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < options.length) {
                                fileSystemModel.fileManagerSettings.defaultView = options[currentIndex].value === "list" ? "List" : "Grid";
                            }
                        }
                    }

                    XylaIconButton {
                        id: filterBtn
                        iconSource: "qrc:/assets/icons/filter.svg"

                        tooltip: "Filter"

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
                            var createdActive = fileSystemModel.createdAtFilter !== "" && fileSystemModel.createdAtFilter !== "Any Time";
                            var modifiedActive = fileSystemModel.modifiedAtFilter !== "" && fileSystemModel.modifiedAtFilter !== "Any Time";

                            return typeActive || sizeActive || createdActive || modifiedActive;
                        }

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
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#202020"
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
                    property string activePath: fileSystemModel.currentPath

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
                            quickAccessSidebar.activePath = fileSystemModel.currentPath;
                            quickAccessSidebar.refresh();
                            if (typeof pathDisplay !== "undefined")
                                pathDisplay.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
                        }
                        function onBookmarksChanged() {
                            quickAccessSidebar.refresh();
                        }
                    }

                    ColumnLayout {
                        id: sidebarColumn
                        anchors.fill: parent
                        spacing: 0
                        clip: true

                        ScrollView {
                            id: sidebarScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth

                            Item {
                                id: scrollContentContainer
                                width: sidebarScrollView.availableWidth
                                implicitHeight: quickAccessColumn.implicitHeight

                                // ── WinUI Settings Selection Pill (Directional Stretch & Shrink) ─────────────
                                Rectangle {
                                    id: selectionPill
                                    width: 3
                                    radius: 1.5
                                    color: "#0078d4"
                                    x: 10
                                    z: 10

                                    property Item targetItem: null
                                    property real baseHeight: 16
                                    property real pillY: 0
                                    property real pillHeight: baseHeight

                                    visible: targetItem !== null
                                    opacity: targetItem !== null ? 1.0 : 0.0

                                    y: pillY
                                    height: pillHeight

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }

                                    // Dynamic state transition handles directional stretch then contraction
                                    SequentialAnimation {
                                        id: pillAnim

                                        property real startY: 0
                                        property real targetY: 0
                                        property real startHeight: selectionPill.baseHeight
                                        property real distance: 0
                                        property bool movingDown: true

                                        onStarted: {
                                            distance = Math.abs(targetY - startY);
                                            movingDown = targetY > startY;
                                        }

                                        // ============================================================
                                        // PHASE 1
                                        //
                                        // Stretch the pill toward the destination.
                                        //
                                        // DOWN:
                                        //   top stays fixed
                                        //   bottom stretches downward
                                        //
                                        // UP:
                                        //   bottom stays fixed
                                        //   top stretches upward
                                        // ============================================================

                                        ParallelAnimation {

                                            NumberAnimation {
                                                target: selectionPill
                                                property: "pillY"

                                                from: pillAnim.startY

                                                to: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY

                                                duration: 140

                                                easing.type: Easing.OutCubic
                                            }

                                            NumberAnimation {
                                                target: selectionPill
                                                property: "pillHeight"

                                                from: pillAnim.startHeight

                                                to: selectionPill.baseHeight + pillAnim.distance

                                                duration: 140

                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // ============================================================
                                        // PHASE 2
                                        //
                                        // Collapse the stretched pill into the destination.
                                        //
                                        // DOWN:
                                        //   top moves downward
                                        //   bottom stays at destination + baseHeight
                                        //
                                        // UP:
                                        //   top stays at destination
                                        //   bottom moves upward
                                        // ============================================================

                                        ParallelAnimation {

                                            NumberAnimation {
                                                target: selectionPill
                                                property: "pillY"

                                                from: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY

                                                to: pillAnim.targetY

                                                duration: 40

                                                easing.type: Easing.OutCubic
                                            }

                                            NumberAnimation {
                                                target: selectionPill
                                                property: "pillHeight"

                                                from: selectionPill.baseHeight + pillAnim.distance

                                                to: selectionPill.baseHeight

                                                duration: 40

                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        onFinished: {
                                            // Always eliminate accumulated floating point error.
                                            selectionPill.pillY = targetY;
                                            selectionPill.pillHeight = selectionPill.baseHeight;
                                        }
                                    }

                                    function updatePosition(item) {
                                        if (!item) {
                                            targetItem = null;
                                            return;
                                        }

                                        Qt.callLater(function () {
                                            if (!item || !selectionPill.parent)
                                                return;

                                            var mapped = item.mapToItem(selectionPill.parent, 0, 0);

                                            var newY = mapped.y + (item.height - selectionPill.baseHeight) / 2;

                                            // --------------------------------------------------------
                                            // First selection
                                            // --------------------------------------------------------

                                            if (targetItem === null) {
                                                targetItem = item;

                                                pillY = newY;
                                                pillHeight = selectionPill.baseHeight;

                                                return;
                                            }

                                            if (targetItem === item)
                                                return;

                                            // --------------------------------------------------------
                                            // IMPORTANT:
                                            //
                                            // Capture the actual visual state BEFORE stopping.
                                            // --------------------------------------------------------

                                            var currentY = selectionPill.pillY;
                                            var currentHeight = selectionPill.pillHeight;

                                            if (pillAnim.running) {
                                                pillAnim.stop();
                                            }

                                            // --------------------------------------------------------
                                            // The pill may have been halfway through a stretch.
                                            //
                                            // We must continue from exactly what is currently visible,
                                            // not from baseHeight.
                                            // --------------------------------------------------------

                                            pillAnim.startY = currentY;
                                            pillAnim.targetY = newY;
                                            pillAnim.startHeight = currentHeight;

                                            targetItem = item;

                                            pillAnim.start();
                                        });
                                    }
                                }

                                ColumnLayout {
                                    id: quickAccessColumn
                                    width: parent.width
                                    spacing: 2

                                    // --- SECTION 1: QUICK ACCESS ---
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
                                            id: qaBtn
                                            required property var modelData
                                            readonly property bool isSectionVisible: modelData.section === "Common"

                                            visible: isSectionVisible
                                            sleek: true
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: isSectionVisible ? 36 : 0
                                            Layout.leftMargin: isSectionVisible ? 10 : 0
                                            Layout.rightMargin: isSectionVisible ? 10 : 0
                                            text: ""

                                            readonly property bool isSelected: quickAccessSidebar.activePath === modelData.path

                                            onIsSelectedChanged: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(qaBtn);
                                                    });
                                                }
                                            }

                                            Component.onCompleted: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(qaBtn);
                                                    });
                                                }
                                            }

                                            background: Rectangle {
                                                radius: 6
                                                color: parent.isSelected ? "#262626" : (parent.hovered ? "#202020" : "#151515")
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }
                                            }

                                            contentItem: RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 8
                                                spacing: 10

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
                                                    opacity: parent.parent.isSelected ? 1.0 : 0.8
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 0
                                                    text: modelData.name
                                                    color: parent.parent.isSelected ? "#ffffff" : "#cccccc"
                                                    font.pixelSize: 12
                                                    font.weight: parent.parent.isSelected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            onClicked: fileSystemModel.cd(modelData.path)
                                        }
                                    }

                                    // --- SECTION 2: DEVICES ---
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
                                            id: devBtn
                                            required property var modelData
                                            readonly property bool isSectionVisible: modelData.section === "Devices"

                                            visible: isSectionVisible
                                            sleek: true
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: isSectionVisible ? 36 : 0
                                            Layout.leftMargin: isSectionVisible ? 10 : 0
                                            Layout.rightMargin: isSectionVisible ? 10 : 0
                                            text: ""

                                            readonly property bool isSelected: quickAccessSidebar.activePath === modelData.path

                                            onIsSelectedChanged: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(devBtn);
                                                    });
                                                }
                                            }

                                            Component.onCompleted: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(devBtn);
                                                    });
                                                }
                                            }

                                            background: Rectangle {
                                                radius: 6
                                                color: parent.isSelected ? "#262626" : (parent.hovered ? "#202020" : "#151515")
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }
                                            }

                                            contentItem: RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 8
                                                spacing: 10

                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16
                                                    source: "qrc:/assets/icons/drive.svg"
                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                    opacity: parent.parent.isSelected ? 1.0 : 0.8
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 0
                                                    text: modelData.name
                                                    color: parent.parent.isSelected ? "#ffffff" : "#cccccc"
                                                    font.pixelSize: 12
                                                    font.weight: parent.parent.isSelected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            onClicked: fileSystemModel.cd(modelData.path)
                                        }
                                    }

                                    // --- SECTION 3: BOOKMARKS ---
                                    Text {
                                        id: bookmarksTitle
                                        text: "BOOKMARKS"
                                        color: "#666666"
                                        font.pixelSize: 10
                                        font.bold: true
                                        Layout.leftMargin: 16
                                        Layout.topMargin: 12
                                        Layout.bottomMargin: 4
                                        visible: quickAccessSidebar.quickAccessModel.some(item => item.section === "Bookmarks")
                                    }

                                    Repeater {
                                        model: quickAccessSidebar.quickAccessModel
                                        delegate: XylaTextButton {
                                            id: bmBtn
                                            required property var modelData
                                            readonly property bool isSectionVisible: modelData.section === "Bookmarks"

                                            visible: isSectionVisible
                                            sleek: true
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: isSectionVisible ? 36 : 0
                                            Layout.leftMargin: isSectionVisible ? 10 : 0
                                            Layout.rightMargin: isSectionVisible ? 10 : 0
                                            text: ""

                                            readonly property bool isSelected: quickAccessSidebar.activePath === modelData.path

                                            onIsSelectedChanged: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(bmBtn);
                                                    });
                                                }
                                            }

                                            Component.onCompleted: {
                                                if (isSelected && isSectionVisible) {
                                                    Qt.callLater(function () {
                                                        selectionPill.updatePosition(bmBtn);
                                                    });
                                                }
                                            }

                                            background: Rectangle {
                                                radius: 6
                                                color: parent.isSelected ? "#262626" : (parent.hovered ? "#202020" : "#151515")
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }
                                            }

                                            contentItem: RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 8
                                                spacing: 10

                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16
                                                    source: "qrc:/assets/icons/bookmarked.svg"
                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                    opacity: parent.parent.isSelected ? 1.0 : 0.8
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 0
                                                    text: modelData.name
                                                    color: parent.parent.isSelected ? "#ffffff" : "#cccccc"
                                                    font.pixelSize: 12
                                                    font.weight: parent.parent.isSelected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            onClicked: fileSystemModel.cd(modelData.path)
                                        }
                                    }
                                }
                            }
                        }

                        // --- BOTTOM SETTINGS BUTTON ---
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
                                if (typeof settingsWindow !== "undefined")
                                    settingsWindow.show();
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            // Layout.bottomMargin: 8 // Space between this line and the button below
                            height: 1
                            color: "#2c2c2c"
                        }

                        Text {
                            Layout.leftMargin: 22
                            Layout.bottomMargin: 15
                            Layout.topMargin: 10
                            text: "Xyla File Manager"
                            color: "#777777"
                            font.pixelSize: 11
                        }
                    }

                    // Border Separator
                    Rectangle {
                        id: rightBorder
                        anchors.right: parent.right
                        width: resizeHandle.containsMouse || resizeHandle.pressed ? 2 : 1
                        height: parent.height
                        color: resizeHandle.containsMouse || resizeHandle.pressed ? "#2d2d4d" : "#202020"
                        z: 2
                    }

                    // Interactive Splitter Handle
                    MouseArea {
                        id: resizeHandle
                        anchors.right: parent.right
                        width: 6
                        height: parent.height
                        anchors.rightMargin: -3
                        z: 3
                        cursorShape: Qt.SplitHCursor
                        hoverEnabled: true

                        // property real globalStartX: 0
                        property real startGlobalX: 0
                        property real startWidth: 0

                        onPressed: mouse => {
                            startGlobalX = mapToItem(null, mouse.x, 0).x;
                            startWidth = quickAccessSidebar.sidebarWidth;
                        }

                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;

                            const currentGlobalX = mapToItem(null, mouse.x, 0).x;
                            const delta = currentGlobalX - startGlobalX;

                            quickAccessSidebar.sidebarWidth = Math.max(140, Math.min(320, startWidth + delta));
                        }
                    }
                }

ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0
                // ============================================================
                // DIRECTORY CONTENTS GRID
                // ============================================================


            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    id: viewContainer

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property bool suppressMotion: false   // FIX A: mkdir / rename only
                    property string pendingRenameName: ""

                    property var selectedIndexes: ({})
                    property int lastSelectedIndex: -1
                    property int contextMenuIndex: -1
                    property Item renamingItem: null   // the card currently renaming

                    readonly property int currentCount: viewToggle.currentIndex === 1 ? dirGridView.count : dirListView.count

                    function flushPendingRename() {
                        const name = pendingRenameName
                        if (!name)
                            return

                        let newIndex = -1
                        const n = fileSystemModel.rowCount()
                        for (let i = 0; i < n; i++) {
                            const item = fileSystemModel.get(i)
                            if (item && item.fileName === name) {
                                newIndex = i
                                break
                            }
                        }
                        if (newIndex < 0)
                            return

                        pendingRenameName = ""
                        selectedIndexes = { [newIndex]: true }
                        lastSelectedIndex = newIndex

                        const view = viewToggle.currentIndex === 1 ? dirGridView : dirListView
                        view.currentIndex = newIndex
                        if (view.positionViewAtIndex)
                            view.positionViewAtIndex(newIndex, GridView.Contain)

                        Qt.callLater(function () {
                            folderDialogRoot.triggerRenameForIndex(newIndex)
                        })
                    }

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
    if (!folderDialogRoot.itemIsSelectable(idx)) {
        const item = fileSystemModel.get(idx)
        if (item && item.isDir && item.filePath
                && !fileSystemModel.fileManagerSettings.openFoldersWithDoubleClick)
            fileSystemModel.cd(item.filePath)
        return
    }

    var newSel = Object.assign({}, selectedIndexes)

    if (mouse && (mouse.modifiers & Qt.ShiftModifier) && lastSelectedIndex !== -1) {
        const start = Math.min(lastSelectedIndex, idx)
        const end = Math.max(lastSelectedIndex, idx)
        for (let i = start; i <= end; i++)
            newSel[i] = true
    } else if (mouse && (mouse.modifiers & Qt.ControlModifier)) {
        if (newSel[idx])
            delete newSel[idx]
        else
            newSel[idx] = true
    } else {
        newSel = {}
        newSel[idx] = true
    }

    selectedIndexes = folderDialogRoot.clampSelection(newSel)
    lastSelectedIndex = idx
}
                    // function selectIndex(idx, mouse) {
                    //     var newSel = Object.assign({}, selectedIndexes);
                    //
                    //     if (mouse && (mouse.modifiers & Qt.ShiftModifier) && lastSelectedIndex !== -1) {
                    //         let start = Math.min(lastSelectedIndex, idx);
                    //         let end = Math.max(lastSelectedIndex, idx);
                    //         for (let i = start; i <= end; i++)
                    //             newSel[i] = true;
                    //     } else if (mouse && (mouse.modifiers & Qt.ControlModifier)) {
                    //         if (newSel[idx])
                    //             delete newSel[idx];
                    //         else
                    //             newSel[idx] = true;
                    //     } else {
                    //         // Plain click → select ONLY this item (standard behaviour)
                    //         newSel = {};
                    //         newSel[idx] = true;
                    //     }
                    //
                    //     selectedIndexes = newSel;
                    //     lastSelectedIndex = idx;
                    // }

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

                    Popup {
                        id: deleteConfirm
                        parent: Overlay.overlay
                        anchors.centerIn: parent
                        width: 390
                        padding: 20
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        property var pendingPaths: []

                        // Same surface + shadow as the context menu
                        background: Rectangle {
                            id: deletePopupSurface
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

                        // Same enter animation
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

                        // Same exit animation
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
                            spacing: 14

                            Text {
                                text: deleteConfirm.pendingPaths.length === 1 ? "Move to trash?" : "Move " + deleteConfirm.pendingPaths.length + " items to trash?"
                                color: "#ffffff"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: deleteConfirm.pendingPaths.length === 1 ? "This item will be moved to the trash. You can restore it later from the system trash." : "These items will be moved to the trash. You can restore them later from the system trash."
                                color: "#a8a8a8"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 8

                                StyledButton {
                                    text: "Cancel"
                                    onClicked: {
                                        deleteConfirm.pendingPaths = [];
                                        deleteConfirm.close();
                                    }
                                }

                                StyledButton {
                                    text: "Move to trash"
                                    accent: true
                                    onClicked: {
                                        if (deleteConfirm.pendingPaths.length > 0)
                                            fileSystemModel.moveToTrash(deleteConfirm.pendingPaths);
                                        deleteConfirm.pendingPaths = [];
                                        deleteConfirm.close();
                                    }
                                }
                            }
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
                            triggerRenameForIndex(viewContainer.contextMenuIndex);
                        }

                        onDeleteRequested: {
                            var paths = viewContainer.selectedPaths();

                            // Fall back to the item under the context menu if nothing is selected
                            if (paths.length === 0 && viewContainer.contextMenuIndex >= 0) {
                                let item = fileSystemModel.get(viewContainer.contextMenuIndex);
                                if (item.filePath)
                                    paths = [item.filePath];
                            }

                            if (paths.length === 0)
                                return;

                            // Respect the setting
                            if (fileSystemModel.fileManagerSettings.confirmDelete) {
                                deleteConfirm.pendingPaths = paths;
                                deleteConfirm.open();
                            } else {
                                fileSystemModel.moveToTrash(paths);
                            }
                        }
                        // onDeleteRequested: {
                        //     var paths = viewContainer.selectedPaths();
                        //     if (paths.length === 0 && viewContainer.contextMenuIndex >= 0) {
                        //         let item = fileSystemModel.get(viewContainer.contextMenuIndex);
                        //         if (item.filePath)
                        //             paths = [item.filePath];
                        //     }
                        //     if (paths.length > 0)
                        //         fileSystemModel.moveToTrash(paths);
                        // }

                        onNewFolderRequested: {
                            // console.log("UI: New Folder");
                            newFolderDialog.show();
                        }

onSelectAllRequested: {
    var newSel = {}
    for (let i = 0; i < fileSystemModel.rowCount(); ++i)
        newSel[i] = true
    viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel)
}
                        // onSelectAllRequested: {
                        //     // console.log("UI: Select All");
                        //
                        //     var newSel = {};
                        //
                        //     for (let i = 0; i < fileSystemModel.rowCount(); ++i)
                        //         newSel[i] = true;
                        //
                        //     viewContainer.selectedIndexes = newSel;
                        // }

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
                    // LOADING STATE
                    // ============================================================
                    Item {
                        id: loadingState
                        anchors.fill: parent
                        visible: fileSystemModel.loading && !viewContainer.suppressMotion
                        z: 50

                        onVisibleChanged: {
                            if (visible) {
                                spinAnim.start();
                            } else {
                                spinAnim.stop();
                            }
                        }

                        Item {
                            id: spinner
                            anchors.centerIn: parent
                            width: 64
                            height: 64

                            // Base Ring with Gradient Mask
                            Item {
                                id: ringContainer
                                anchors.fill: parent

                                // 1. The #2d2d2d Circle Base
                                Rectangle {
                                    id: ringShape
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: "#2d2d2d"
                                    border.width: 6
                                    visible: false // Hidden, used only as a source for opacity masking
                                }

                                Rectangle {
                                    width: 6  // Must match border.width of ringShape
                                    height: 6
                                    radius: 3
                                    color: "#2d2d2d"

                                    // Position centered on the top edge of the ring stroke
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                }

                                // 2. Conical Gradient (Fades 1/4 of the circle smoothly to opacity 0)
                                ConicalGradient {
                                    id: gradientSource
                                    anchors.fill: parent
                                    visible: false
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.00
                                            color: "#ff000000"
                                        } // Fully opaque
                                        GradientStop {
                                            position: 0.25
                                            color: "#ff000000"
                                        } // Starts fading at 270°
                                        GradientStop {
                                            position: 1.00
                                            color: "#00000000"
                                        } // Fully transparent at 360° (1/4 fade)
                                    }
                                }

                                // 3. Apply Gradient Mask onto the #2d2d2d Ring
                                OpacityMask {
                                    anchors.fill: parent
                                    source: ringShape
                                    maskSource: gradientSource
                                }
                            }

                            // Hardware-accelerated continuous spin
                            RotationAnimator {
                                id: spinAnim
                                target: spinner
                                from: 360
                                to: 0
                                duration: 850
                                loops: Animation.Infinite
                                running: loadingState.visible
                            }
                        }
                    }

                    // ============================================================
                    // EMPTY STATE
                    // ============================================================
                    Item {
                        id: emptyState
                        anchors.fill: parent
                        visible: viewContainer.currentCount === 0 && !fileSystemModel.loading
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
    let intersects = !(itemX > boxRight || (itemX + dirGridView.cellWidth) < boxLeft
                    || itemY > boxBottom || (itemY + dirGridView.cellHeight) < boxTop);
    if (intersects && folderDialogRoot.itemIsSelectable(i))
        newSel[i] = true;
}

if (!folderDialogRoot.selectMultiple) {
    const col = Math.floor((mouse.x + dirGridView.contentX - dirGridView.leftMargin) / dirGridView.cellWidth);
    const row = Math.floor((mouse.y + dirGridView.contentY - dirGridView.topMargin) / dirGridView.cellHeight);
    const idx = row * cols + col;
    let only = {};
    if (col >= 0 && row >= 0 && idx >= 0 && idx < dirGridView.count
            && folderDialogRoot.itemIsSelectable(idx) && newSel[idx])
        only[idx] = true;
    viewContainer.selectedIndexes = only;
} else {
    viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel);
}
                                // viewContainer.selectedIndexes = newSel;
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

                            opacity: (!folderDialogRoot.isPicker || folderDialogRoot.itemIsSelectable(index) || gridCard.isFolder)
                                    ? 1.0 : 0.4
                            width: 175
                            height: 205
                            z: 1

                            property real cardScale: 0.0
                            scale: cardScale
                            transformOrigin: Item.Center

                            // Initial load bounce
                            Component.onCompleted: entranceAnim.restart()
// Component.onCompleted: {
//     const mine = viewContainer.suppressMotion
//                  && folderName === viewContainer.pendingRenameName
//     if (viewContainer.suppressMotion && !mine)
//         gridCard.cardScale = 1.0
//     else
//         entranceAnim.restart()
// }

                            // Trigger animation when the assigned model item or index changes
                            // Connections {
                            //     target: gridCard
                            //     function onIndexChanged() { entranceAnim.restart() }
                            // }

                            // React to model property changes (e.g. folder change or filtering)
                            onFolderNameChanged: entranceAnim.restart()
                            onFolderPathChanged: entranceAnim.restart()
// onFolderNameChanged: {
//     if (viewContainer.suppressMotion)
//         return
//     entranceAnim.restart()
// }
// onFolderPathChanged: {
//     if (viewContainer.suppressMotion)
//         return
//     entranceAnim.restart()
// }

// onRenameCommitted: newName => {
//     viewContainer.suppressMotion = true
//     viewContainer.pendingRenameName = newName
//     fileSystemModel.rename(folderPath, newName)
// }
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
                                    from: 0.8
                                    to: 1.0
                                    duration: 180
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
    if (!folderDialogRoot.itemIsSelectable(index))
        return
    let newSel = {}
    newSel[index] = true
    viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel)
    viewContainer.lastSelectedIndex = index
}
                                        // if (!viewContainer.selectedIndexes[index]) {
                                        //     let newSel = {};
                                        //     newSel[index] = true;
                                        //     viewContainer.selectedIndexes = newSel;
                                        //     viewContainer.lastSelectedIndex = index;
                                        // }

                                        let p = mapToItem(viewContainer, mouse.x, mouse.y);
                                        viewContainer.openContextMenu(index, model.isDir, p.x, p.y);
                                        return;
                                    }

                                    if (mouse.button === Qt.LeftButton) {
                                        if (!fileSystemModel.fileManagerSettings.openFoldersWithDoubleClick && model.isDir && model.filePath !== undefined && model.filePath !== "") {
                                            fileSystemModel.cd(model.filePath);
                                            return;
                                        }

                                        viewContainer.selectIndex(index, mouse);
                                    }
                                }

                                onDoubleClicked: mouse => {
                                    if (!fileSystemModel.fileManagerSettings.openFoldersWithDoubleClick)
                                        return;

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
if (!folderDialogRoot.selectMultiple) {
    const stride = listPane.rowHeight + dirListView.spacing;
    const idx = Math.floor((mouse.y + dirListView.contentY - dirListView.topMargin) / stride);
    let only = {};
    if (idx >= 0 && idx < dirListView.count
            && folderDialogRoot.itemIsSelectable(idx) && newSel[idx])
        only[idx] = true;
    viewContainer.selectedIndexes = only;
} else {
    viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel);
}
// if (!(itemY > boxBottom || (itemY + listPane.rowHeight) < boxTop)
//         && folderDialogRoot.itemIsSelectable(i))
//     newSel[i] = true
// }
// viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel)
                                    // viewContainer.selectedIndexes = newSel;
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
                                opacity: (!folderDialogRoot.isPicker || folderDialogRoot.itemIsSelectable(index) || model.isDir)
                                        ? 1.0 : 0.4
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
    if (!folderDialogRoot.itemIsSelectable(index))
        return
    let newSel = {}
    newSel[index] = true
    viewContainer.selectedIndexes = folderDialogRoot.clampSelection(newSel)
    viewContainer.lastSelectedIndex = index
}
                                            // if (!viewContainer.selectedIndexes[index]) {
                                            //     let newSel = {};
                                            //     newSel[index] = true;
                                            //     viewContainer.selectedIndexes = newSel;
                                            //     viewContainer.lastSelectedIndex = index;
                                            // }
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
                        color: resizeHandleRight.containsMouse || resizeHandleRight.pressed ? "#2d2d4d" : "#202020"
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
                                return (n !== 1); // && !fileSystemModel.loading;
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
                                    id: copyButtonPreview
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/copy.svg"
                                    iconWidth: 14
                                    iconHeight: 14

                                    XylaToolTip {
                                        visible: copyButtonPreview.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                        text: "Copy path"
                                    }

                                    onClicked: {
                                        if (detailsSidebar.selectedItem && detailsSidebar.selectedItem.filePath)
                                            fileSystemModel.copyToClipboard(detailsSidebar.selectedItem.filePath);
                                    }
                                }

                                XylaIconButton {
                                    id: renameButtonPreview
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/edit.svg"
                                    iconWidth: 14
                                    iconHeight: 14

                                    XylaToolTip {
                                        visible: renameButtonPreview.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                        text: "Rename"
                                    }

                                    onClicked: {
                                        if (!detailsSidebar.selectedItem)
                                            return;
                                        renameDialog.targetPath = detailsSidebar.selectedItem.filePath;
                                        renameDialog.originalName = detailsSidebar.selectedItem.fileName;
                                        renameDialog.open();
                                    }
                                }

                                XylaIconButton {
                                    id: propertiesButtonPreview
                                    width: 32
                                    height: 32
                                    ghost: true
                                    iconSource: "qrc:/assets/icons/info.svg"
                                    iconWidth: 14
                                    iconHeight: 14

                                    XylaToolTip {
                                        visible: propertiesButtonPreview.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                        text: "Properties"
                                    }
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
          // }

            // Footer Action Bar
            Rectangle {
                Layout.fillWidth: true
                visible: folderDialogRoot.isPicker
                height: visible ? 56 : 0
                Layout.preferredHeight: visible ? 56 : 0
                color: "#181818"
                bottomLeftRadius: 10
                bottomRightRadius: 10

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: "#202020"
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
                                id: copyButton

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

                                XylaToolTip {
                                    visible: copyButton.hovered && fileSystemModel.fileManagerSettings.showTooltips
                                    text: "Copy path"
                                    delay: 500
                                }
                            }
                        }
                    }

                    XylaTextButton {
                        Layout.leftMargin: 36
                        text: "Cancel"
                        onClicked: folderDialogRoot.hideDialog()
                    }

XylaTextButton {
    text: {
        const n = Object.keys(viewContainer.selectedIndexes).length
        const kind = folderDialogRoot.returnType.toLowerCase()
        if (kind === "folder")
            return n <= 1 ? "Select Folder" : "Select Folders"
        if (n === 0)
            return "Select"
        if (n === 1)
            return "Select"
        return "Select " + n + " Items"
    }
    primary: true
    enabled: {
        const kind = folderDialogRoot.returnType.toLowerCase()
        const n = Object.keys(viewContainer.selectedIndexes).length
        if (kind === "folder")
            return true                    // current dir is a valid choice
        return n > 0
    }
    onClicked: {
        const kind = folderDialogRoot.returnType.toLowerCase()
        const keys = Object.keys(viewContainer.selectedIndexes)
        if (kind === "folder" && keys.length === 0) {
            folderDialogRoot.folderSelected(fileSystemModel.currentPath)
        } else {
            const paths = keys.map(k => fileSystemModel.get(Number(k)).filePath)
            folderDialogRoot.folderSelected(folderDialogRoot.selectMultiple ? paths : paths[0])
        }
        folderDialogRoot.hideDialog()
    }
}
                }
              }
            }
            }
        }
    }

    component StyledButton: Button {
        id: button

        property bool accent: false

        implicitWidth: Math.max(84, contentItem.implicitWidth + 28)
        implicitHeight: 34

        contentItem: Text {
            text: button.text
            color: button.accent ? "#ffffff" : "#eeeeee"
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: button.accent ? (button.pressed ? "#0e2d80" : button.hovered ? "#1644bf" : "#11389F") : (button.pressed ? "#383838" : button.hovered ? "#303030" : "#292929")
            border.color: button.accent ? "#11389F" : "#454545"
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 90
                }
            }
        }
    }
}
