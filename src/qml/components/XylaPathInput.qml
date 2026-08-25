import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: pathBarContainer

    Layout.fillWidth: true
    Layout.preferredHeight: 32

    property bool isEditing: false
    property bool pathBookmarked: false

    function getPathIcon(name, path) {
        let lowerName = name.toLowerCase();
        let lowerPath = path.toLowerCase();
        if (lowerPath === "/" || lowerName === "root")
            return "qrc:/assets/icons/folder.svg";
        if (lowerName === "home" || lowerPath.endsWith("/home"))
            return "qrc:/assets/icons/home.svg";
        if (lowerName === "downloads")
            return "qrc:/assets/icons/download.svg";
        if (lowerName === "documents")
            return "qrc:/assets/icons/file-text.svg";
        if (lowerName === "pictures")
            return "qrc:/assets/icons/image.svg";
        if (lowerName === "videos")
            return "qrc:/assets/icons/video.svg";
        if (lowerName === "music")
            return "qrc:/assets/icons/music.svg";
        return "qrc:/assets/icons/folder.svg";
    }

    function parseBreadcrumbs(path) {
        if (!path)
            return [];
        let parts = path.split("/").filter(p => p.length > 0);
        let crumbs = [];

        // INFO: Uncomment this if root folder needs to be in the bread
        // crumbs.push({ name: "/", path: "/", icon: getPathIcon("root", "/") });

        let currentBuild = "";
        for (let i = 0; i < parts.length; i++) {
            currentBuild += "/" + parts[i];
            crumbs.push({
                name: parts[i],
                path: currentBuild,
                icon: getPathIcon(parts[i], currentBuild)
            });
        }
        return crumbs;
    }

    // Main Surface
    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: "#181818"
        border.color: (pathBarContainer.isEditing || pathDisplay.activeFocus) ? "#2555D3" : "#2d2d2d"
        border.width: 1
        radius: 6

        // 1. Click non-breadcrumb whitespace to invoke text editing
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: {
                pathBarContainer.isEditing = true;
                pathDisplay.forceActiveFocus();
                pathDisplay.selectAll();
            }
        }

        // ================================================================
        // BREADCRUMBS MODE VIEW
        // ================================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 42
            spacing: 2
            visible: !pathBarContainer.isEditing
            z: 1

            ListView {
                id: breadcrumbList
                // Keep ListView tightly bound to contents so clicks outside breadcrumbs trigger edit mode
                Layout.fillWidth: false
                Layout.preferredWidth: contentWidth
                Layout.maximumWidth: parent.width
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                spacing: 2

                model: parseBreadcrumbs(fileSystemModel.currentPath)

                delegate: RowLayout {
                    id: crumbRow
                    required property var modelData
                    required property int index

                    height: parent.height
                    spacing: 4

                    // 2. Breadcrumb item button opens sub-folder menu below it
                    Rectangle {
                        id: crumbBtn
                        implicitWidth: crumbContent.implicitWidth + 12
                        height: 24
                        radius: 6
                        color: crumbMouse.containsMouse ? "#252525" : "transparent"

                        RowLayout {
                            id: crumbContent
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                source: modelData.icon
                                sourceSize: Qt.size(14, 14)
                                opacity: 0.85
                            }

                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.weight: index === breadcrumbList.count - 1 ? Font.Bold : Font.Normal
                            }
                        }

                        MouseArea {
                            id: crumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let originPos = crumbBtn.mapToItem(Overlay.overlay, 0, crumbBtn.height + 4);
                                dynamicSubfolderMenu.targetPath = modelData.path;
                                dynamicSubfolderMenu.openAt(originPos.x, originPos.y);
                                dynamicSubfolderMenu.forceActiveFocus();
                            }
                        }
                    }

                    // Separator dropdown trigger
                    Text {
                        text: "›"
                        color: "#666666"
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let originPos = parent.mapToItem(Overlay.overlay, 0, parent.height + 4);
                                dynamicSubfolderMenu.targetPath = modelData.path;
                                dynamicSubfolderMenu.openAt(originPos.x, originPos.y);
                            }
                        }
                    }
                }
            }
        }

        // ================================================================
        // EDIT MODE (TEXT FIELD)
        // ================================================================
        TextField {
            id: pathDisplay
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 40
            visible: pathBarContainer.isEditing
            z: 2

            text: fileSystemModel.currentPath
            color: "#ffffff"
            font.pixelSize: 12
            selectByMouse: true
            background: Item {}

            property var pathCompletionModel: []

            onActiveFocusChanged: {
                if (!activeFocus) {
                    pathBarContainer.isEditing = false;
                    pathCompletionPopup.close();
                }
            }

            // Intercept Escape key before TextField's internal undo stack handles it
            Keys.onShortcutOverride: event => {
                if (event.key === Qt.Key_Escape) {
                    text = fileSystemModel.currentPath;
                    pathCompletionPopup.close();
                    pathBarContainer.isEditing = false;
                    pathDisplay.focus = false;
                    event.accepted = true;
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    text = fileSystemModel.currentPath;
                    pathCompletionPopup.close();
                    pathBarContainer.isEditing = false;
                    pathDisplay.focus = false;
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
                        fileSystemModel.cd(selected.path);
                        pathCompletionPopup.close();
                        pathBarContainer.isEditing = false;
                        pathDisplay.focus = false;
                        event.accepted = true;
                    }
                }
            }

            onTextChanged: {
                if (!pathBarContainer.isEditing)
                    return;
                pathCompletionModel = fileSystemModel.pathCompletions(text);
                if (pathCompletionList)
                    pathCompletionList.currentIndex = 0;

                if (pathDisplay.activeFocus && pathCompletionModel.length > 0)
                    pathCompletionPopup.open();
                else
                    pathCompletionPopup.close();
            }

            onEditingFinished: {
                if (!pathCompletionPopup.visible && pathBarContainer.isEditing) {
                    fileSystemModel.cd(text.trim());
                    pathBarContainer.isEditing = false;
                }
            }
        }

        // Bookmark Action Button
        XylaIconButton {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            ghost: true
            z: 3

            iconColor: pathBarContainer.pathBookmarked ? "#ffb020" : (hovered ? "#ffffff" : "#888888")
            iconSource: pathBarContainer.pathBookmarked ? "qrc:/assets/icons/bookmarked.svg" : "qrc:/assets/icons/bookmark.svg"

            Component.onCompleted: {
                pathBarContainer.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
            }

            onClicked: {
                fileSystemModel.toggleBookmark(fileSystemModel.currentPath);
                pathBarContainer.pathBookmarked = fileSystemModel.isBookmarked(fileSystemModel.currentPath);
            }
        }
    }

    // ================================================================
    // BREADCRUMB SUB-FOLDER POPUP MENU (STYLE SPECIFICATIONS)
    // ================================================================
    Popup {
        id: dynamicSubfolderMenu
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 6

        property string targetPath: ""
        property var folderItems: []

        property real requestedX: 0
        property real requestedY: 0
        property int currentIndex: 0

        function reposition() {
            x = Math.max(8, Math.min(requestedX, parent.width - width - 8));
            y = Math.max(8, Math.min(requestedY, parent.height - height - 8));
        }

        function openAt(screenX, screenY) {
            requestedX = screenX;
            requestedY = screenY;

            let queryPath = targetPath.endsWith("/") ? targetPath : targetPath + "/";
            let rawItems = fileSystemModel.pathCompletions(queryPath);
            folderItems = rawItems.filter(item => item.isFolder === true);
            currentIndex = 0; // Reset index on open

            reposition();
            open();
            // Target the inner ListView directly for active focus
            folderList.forceActiveFocus();
        }

        background: Rectangle {
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

        contentItem: Item {
            implicitWidth: 200
            implicitHeight: dynamicSubfolderMenu.folderItems.length > 0 ? Math.min(folderList.contentHeight, 240) : 32

            Text {
                anchors.centerIn: parent
                visible: dynamicSubfolderMenu.folderItems.length === 0
                text: "No subfolders"
                color: "#666666"
                font.pixelSize: 12
            }

            ListView {
                id: folderList
                anchors.fill: parent
                visible: dynamicSubfolderMenu.folderItems.length > 0
                model: dynamicSubfolderMenu.folderItems
                clip: true
                spacing: 2
                focus: true // MUST be true for key navigation to work
                currentIndex: dynamicSubfolderMenu.currentIndex

                Keys.onShortcutOverride: event => {
                    if (event.key === Qt.Key_Escape) {
                        dynamicSubfolderMenu.close();
                        event.accepted = true;
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        dynamicSubfolderMenu.close();
                        event.accepted = true;
                        return;
                    }

                    if (dynamicSubfolderMenu.folderItems.length === 0)
                        return;

                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        dynamicSubfolderMenu.currentIndex = (dynamicSubfolderMenu.currentIndex + 1) % dynamicSubfolderMenu.folderItems.length;
                        positionViewAtIndex(dynamicSubfolderMenu.currentIndex, ListView.Beginning);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        dynamicSubfolderMenu.currentIndex = (dynamicSubfolderMenu.currentIndex - 1 + dynamicSubfolderMenu.folderItems.length) % dynamicSubfolderMenu.folderItems.length;
                        positionViewAtIndex(dynamicSubfolderMenu.currentIndex, ListView.Beginning);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        let selected = dynamicSubfolderMenu.folderItems[dynamicSubfolderMenu.currentIndex];
                        if (selected) {
                            fileSystemModel.cd(selected.path);
                            dynamicSubfolderMenu.close();
                            event.accepted = true;
                        }
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: folderList.width
                    height: 30
                    radius: 7
                    // Highlight on keyboard index or mouse hover
                    color: (dynamicSubfolderMenu.currentIndex === index || itemMouse.containsMouse) ? "#252525" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: getPathIcon(modelData.name, modelData.path)
                            sourceSize: Qt.size(16, 16)
                            opacity: 0.85
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: "#ffffff"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: dynamicSubfolderMenu.currentIndex = index
                        onClicked: {
                            fileSystemModel.cd(modelData.path);
                            dynamicSubfolderMenu.close();
                        }
                    }
                }
            }
        }
    }

    // Text Input Autocomplete Suggestions Popup
    Popup {
        id: pathCompletionPopup
        x: 0
        y: pathBarContainer.height + 4
        width: pathBarContainer.width
        padding: 6 // Matches dynamicSubfolderMenu padding
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
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

        contentItem: Item {
            implicitWidth: parent.width
            implicitHeight: Math.min(pathCompletionList.contentHeight, 240)

            ListView {
                id: pathCompletionList
                anchors.fill: parent
                model: pathDisplay.pathCompletionModel
                clip: true
                spacing: 2
                currentIndex: 0

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: pathCompletionList.width
                    height: 30
                    radius: 7
                    color: (pathCompletionList.currentIndex === index || completionMouse.containsMouse) ? "#252525" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: modelData.isFolder ? getPathIcon(modelData.name, modelData.path) : "qrc:/assets/icons/file.svg"
                            sourceSize: Qt.size(16, 16)
                            opacity: 0.85
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: "#ffffff"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: completionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pathDisplay.text = modelData.path;
                            fileSystemModel.cd(modelData.path);
                            pathCompletionPopup.close();
                            pathBarContainer.isEditing = false;
                        }
                    }
                }
            }
        }
    }
}
