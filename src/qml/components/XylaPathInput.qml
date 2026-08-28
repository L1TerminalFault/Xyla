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
            return "qrc:/assets/icons/lock.svg";
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

        if (!crumbs.length) {
            crumbs.push({ name: "/", path: "/", icon: getPathIcon("root", "/") });
        }
        return crumbs;
    }

    // Main Surface
    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: "#0e0e0e"
        border.color: (pathBarContainer.isEditing || pathDisplay.activeFocus) ? "#2555D3" : "#101010" // "#2d2d2d"
        border.width: 1
        radius: height / 2

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

        Item {
            id: breadcrumbContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property var breadcrumbs:
                parseBreadcrumbs(fileSystemModel.currentPath)

            // Each entry is either:
            // { type: "crumb", index: N }
            // { type: "ellipsis" }
            property var displayItems: []

            property var hiddenIndexes: []

            function breadcrumbWidth(index) {
                var item = breadcrumbMeasurements.itemAt(index);
                return item ? item.implicitWidth : 0;
            }

            function separatorWidth() {
                // Keep the same visual spacing as the original breadcrumb
                // delegate: RowLayout spacing + separator glyph width.
                return 4 + 8;
            }

            function rebuildDisplayItems() {
                var result = [];

                for (var i = 0; i < breadcrumbs.length; ++i) {
                    if (i > 0 && i === hiddenIndexes[0])
                        result.push({ type: "ellipsis" });

                    if (hiddenIndexes.indexOf(i) === -1)
                        result.push({ type: "crumb", index: i });
                }

                displayItems = result;
            }

            function recalculateBreadcrumbs() {
                var count = breadcrumbs.length;

                hiddenIndexes = [];
                displayItems = [];

                if (count === 0)
                    return;

                if (count === 1) {
                    rebuildDisplayItems();
                    return;
                }

                var available = width - 16;

                if (available <= 0)
                    return;

                /*
                 * Everything is measured using the actual breadcrumb
                 * contents. Do not use a fixed number of breadcrumbs.
                 *
                 * We search every possible CONTIGUOUS hidden middle range
                 * and choose the one which gives us the greatest amount
                 * of visible breadcrumb content while still fitting.
                 *
                 * This gives:
                 *
                 * Home > Documents > ... > SomeFiles > SomeDir
                 *
                 * rather than arbitrarily dropping individual crumbs.
                 */
                var bestHiddenStart = -1;
                var bestHiddenEnd = -1;
                var bestVisibleWidth = -1;

                // Test whether all breadcrumbs fit first.
                var fullWidth = 0;

                for (var f = 0; f < count; ++f) {
                    fullWidth += breadcrumbWidth(f);

                    if (f < count - 1)
                        fullWidth += separatorWidth();
                }

                if (fullWidth <= available) {
                    rebuildDisplayItems();
                    return;
                }

                /*
                 * Hide at least one middle breadcrumb.
                 *
                 * start/end are inclusive and are never 0 or count - 1.
                 */
                for (var start = 1; start < count - 1; ++start) {
                    for (var end = start; end < count - 1; ++end) {
                        var visibleWidth = 0;
                        var visibleCount = 0;

                        // First breadcrumb.
                        visibleWidth += breadcrumbWidth(0);
                        visibleCount++;

                        // Visible middle breadcrumbs before hidden range.
                        for (var left = 1; left < start; ++left) {
                            visibleWidth += breadcrumbWidth(left);
                            visibleCount++;
                        }

                        // Ellipsis replaces the hidden range.
                        var ellipsisWidth = 28;
                        visibleWidth += ellipsisWidth;
                        visibleCount++;

                        // Visible middle breadcrumbs after hidden range.
                        for (var right = end + 1; right < count - 1; ++right) {
                            visibleWidth += breadcrumbWidth(right);
                            visibleCount++;
                        }

                        // Last breadcrumb.
                        visibleWidth += breadcrumbWidth(count - 1);
                        visibleCount++;

                        // Separators between displayed items.
                        if (visibleCount > 1)
                            visibleWidth +=
                                (visibleCount - 1) * separatorWidth();

                        if (visibleWidth <= available) {
                            /*
                             * Primary objective:
                             * use as much of the available width as possible.
                             *
                             * Secondary objective:
                             * when equally good, prefer keeping more of the
                             * recent/current-side breadcrumbs visible.
                             */
                            var rightVisibleCount =
                                count - 1 - (end + 1);

                            var bestRightVisibleCount =
                                bestHiddenEnd >= 0
                                ? count - 1 - (bestHiddenEnd + 1)
                                : -1;

                            if (visibleWidth > bestVisibleWidth ||
                                (visibleWidth === bestVisibleWidth &&
                                 rightVisibleCount >
                                 bestRightVisibleCount)) {

                                bestVisibleWidth = visibleWidth;
                                bestHiddenStart = start;
                                bestHiddenEnd = end;
                            }
                        }
                    }
                }

                /*
                 * There should normally always be a solution because the
                 * basic structure is:
                 *
                 * first > ... > last
                 *
                 * If even that does not fit, still preserve the first and
                 * last and hide all middle breadcrumbs.
                 */
                if (bestHiddenStart === -1) {
                    bestHiddenStart = 1;
                    bestHiddenEnd = count - 2;
                }

                var hidden = [];

                for (var h = bestHiddenStart;
                     h <= bestHiddenEnd;
                     ++h) {
                    hidden.push(h);
                }

                hiddenIndexes = hidden;
                rebuildDisplayItems();
            }

            onWidthChanged:
                Qt.callLater(recalculateBreadcrumbs)

            Connections {
                target: fileSystemModel

                function onCurrentPathChanged() {
                    breadcrumbContainer.breadcrumbs =
                        parseBreadcrumbs(fileSystemModel.currentPath);

                    Qt.callLater(
                        breadcrumbContainer.recalculateBreadcrumbs
                    );
                }
            }

            RowLayout {
                id: breadcrumbRow

                anchors.left: parent.left
                // anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                spacing: 2

                Repeater {
                    id: visibleBreadcrumbs

                    model: breadcrumbContainer.displayItems

                    delegate: RowLayout {
                        required property var modelData
                        required property int index

                        spacing: 4

                        height: breadcrumbRow.height

                        /*
                         * Normal breadcrumb.
                         */
                        Rectangle {
                            visible: modelData.type === "crumb"

                            implicitWidth:
                                modelData.type === "crumb"
                                ? breadcrumbContainer.breadcrumbWidth(
                                      modelData.index
                                  )
                                : 28

                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: 24

                            radius: height / 2

                            color:
                                crumbMouse.containsMouse
                                ? "#252525"
                                : "transparent"

                            RowLayout {
                                id: crumbContent

                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14

    source: {
        if (modelData.type !== "crumb") return "";
        var item = breadcrumbContainer.breadcrumbs ? breadcrumbContainer.breadcrumbs[modelData.index] : undefined;
        return (item !== undefined && item !== null && item.icon !== undefined) ? item.icon : "";
    }
                                    // source:
                                    //     modelData.type === "crumb"
                                    //     ? breadcrumbContainer.breadcrumbs[
                                    //           modelData.index
                                    //       ].icon
                                    //     : ""

                                    sourceSize: Qt.size(14, 14)

                                    opacity: 0.85
                                }

                                Text {
    text: {
        if (modelData.type !== "crumb") return "";
        var item = breadcrumbContainer.breadcrumbs ? breadcrumbContainer.breadcrumbs[modelData.index] : undefined;
        return (item !== undefined && item !== null && item.name !== undefined) ? item.name : "";
    }
                                    // text:
                                    //     modelData.type === "crumb"
                                    //     ? breadcrumbContainer.breadcrumbs[
                                    //           modelData.index
                                    //       ].name
                                    //     : ""

                                    color: "#ffffff"

                                    font.pixelSize: 12

                                    font.weight:
                                        modelData.type === "crumb" &&
                                        modelData.index ===
                                        breadcrumbContainer.breadcrumbs.length - 1
                                        ? Font.Bold
                                        : Font.Normal
                                }
                            }

                            MouseArea {
                                id: crumbMouse

                                anchors.fill: parent

                                enabled:
                                    modelData.type === "crumb"

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    var crumb =
                                        breadcrumbContainer.breadcrumbs[
                                            modelData.index
                                        ];

                                    if (crumb.path !== fileSystemModel.currentPath) {
                                        fileSystemModel.cd(crumb.path);
                                        return;
                                    }

                                    let originPos =
                                        parent.mapToItem(
                                            Overlay.overlay,
                                            0,
                                            parent.height + 4
                                        );

                                    dynamicSubfolderMenu.targetPath =
                                        crumb.path;

                                    dynamicSubfolderMenu.openAt(
                                        originPos.x,
                                        originPos.y
                                    );

                                    dynamicSubfolderMenu.forceActiveFocus();
                                }
                            }
                        }

                        /*
                         * The collapsed middle range.
                         */
                        Rectangle {
                            visible: modelData.type === "ellipsis"

                            implicitWidth: 28

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 24

                            radius: 6

                            color:
                                ellipsisMouse.containsMouse
                                ? "#252525"
                                : "transparent"

                            Text {
                                anchors.centerIn: parent

                                text: "..."

                                color: "#ffffff"

                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: ellipsisMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    var p =
                                        parent.mapToItem(
                                            Overlay.overlay,
                                            0,
                                            parent.height + 4
                                        );

                                    hiddenBreadcrumbPopup.x = p.x;
                                    hiddenBreadcrumbPopup.y = p.y;

                                    hiddenBreadcrumbPopup.open();
                                }
                            }
                        }

                        /*
                         * Keep the original separator behavior:
                         * every breadcrumb delegate owns its separator,
                         * so two breadcrumbs still have their separator.
                         *
                         * The final separator is intentionally omitted
                         * only for the final displayed item.
                         */
                        Text {
                            visible:
                                index <
                                breadcrumbContainer.displayItems.length - 1

                            text: "›"

                            color:
                                separatorMouse.containsMouse
                                ? "#ffffff"
                                : "#666666"

                            font.pixelSize: 16

                            Layout.alignment:
                                Qt.AlignVCenter

                            MouseArea {
                                id: separatorMouse

                                anchors.fill: parent
                                anchors.margins: -4

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    if (modelData.type !== "crumb")
                                        return;

                                    let crumb =
                                        breadcrumbContainer.breadcrumbs[
                                            modelData.index
                                        ];

                                    let originPos =
                                        parent.mapToItem(
                                            Overlay.overlay,
                                            0,
                                            parent.height + 4
                                        );

                                    dynamicSubfolderMenu.targetPath =
                                        crumb.path;

                                    dynamicSubfolderMenu.openAt(
                                        originPos.x,
                                        originPos.y
                                    );
                                }
                            }
                        }
                    }
                }
            }

            /*
             * Measurement-only repeater.
             *
             * This uses the same icon/text dimensions as the real
             * breadcrumb, but does not participate in the layout.
             */
            Repeater {
                id: breadcrumbMeasurements

                model: breadcrumbContainer.breadcrumbs

                delegate: Item {
                    required property var modelData
                    required property int index

                    visible: false

                    implicitWidth:
                        measurementText.implicitWidth +
                        12 +
                        14 +
                        6

                    Text {
                        id: measurementText

                        text: modelData.name

                        font.pixelSize: 12

                        font.weight:
                            index ===
                            breadcrumbContainer.breadcrumbs.length - 1
                            ? Font.Bold
                            : Font.Normal
                    }
                }

                onCountChanged:
                    Qt.callLater(
                        breadcrumbContainer.recalculateBreadcrumbs
                    )
            }

Popup {
    id: hiddenBreadcrumbPopup

    parent: Overlay.overlay

    modal: false
    focus: true

    closePolicy:
        Popup.CloseOnEscape |
        Popup.CloseOnPressOutside

    padding: 6

    width: 240

    // Reset list selection index whenever the popup opens
    onOpened: {
        hiddenBreadcrumbList.currentIndex = 0
        hiddenBreadcrumbList.forceActiveFocus()
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

            easing.type: Easing.InCubic
        }
    }

    contentItem: ListView {
        id: hiddenBreadcrumbList

        focus: true
        clip: true
        spacing: 2

        implicitHeight: Math.min(contentHeight, 320)

        model: breadcrumbContainer.hiddenIndexes

        // Keyboard navigation and shortcut overrides
        Keys.onShortcutOverride: event => {
            if (event.key === Qt.Key_Escape) {
                hiddenBreadcrumbPopup.close();
                event.accepted = true;
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                hiddenBreadcrumbPopup.close();
                event.accepted = true;
                return;
            }

            let itemCount = hiddenBreadcrumbList.count;
            if (itemCount === 0)
                return;

            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                hiddenBreadcrumbList.currentIndex = (hiddenBreadcrumbList.currentIndex + 1) % itemCount;
                hiddenBreadcrumbList.positionViewAtIndex(hiddenBreadcrumbList.currentIndex, ListView.Beginning);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                hiddenBreadcrumbList.currentIndex = (hiddenBreadcrumbList.currentIndex - 1 + itemCount) % itemCount;
                hiddenBreadcrumbList.positionViewAtIndex(hiddenBreadcrumbList.currentIndex, ListView.Beginning);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let currentModelIdx = hiddenBreadcrumbList.model[hiddenBreadcrumbList.currentIndex];
                let crumb = breadcrumbContainer.breadcrumbs[currentModelIdx];
                if (crumb) {
                    hiddenBreadcrumbPopup.close();
                    fileSystemModel.cd(crumb.path);

                    // let item = hiddenBreadcrumbList.currentItem;
                    // let originPos = item
                    //     ? item.mapToItem(Overlay.overlay, 0, item.height + 4)
                    //     : Qt.point(0, 0);
                    //
                    // dynamicSubfolderMenu.targetPath = crumb.path;
                    // dynamicSubfolderMenu.openAt(originPos.x, originPos.y);
                    // dynamicSubfolderMenu.forceActiveFocus();

                    event.accepted = true;
                }
            }
        }

        delegate: Rectangle {
            required property int modelData
            required property int index

            width: hiddenBreadcrumbList.width
            height: 32
            radius: 6

            // Highlight on hover OR keyboard navigation focus
            color: (hiddenBreadcrumbList.currentIndex === index || hiddenBreadcrumbMouse.containsMouse)
                ? "#252525"
                : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: breadcrumbContainer.breadcrumbs[modelData].icon
                    sourceSize: Qt.size(14, 14)
                    opacity: 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: breadcrumbContainer.breadcrumbs[modelData].name
                    color: "#ffffff"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: hiddenBreadcrumbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: hiddenBreadcrumbList.currentIndex = index

                onClicked: {
                    var crumb = breadcrumbContainer.breadcrumbs[modelData]

                    hiddenBreadcrumbPopup.close()
                    fileSystemModel.cd(crumb.path)

                    // let originPos = hiddenBreadcrumbMouse.mapToItem(
                    //     Overlay.overlay,
                    //     0,
                    //     hiddenBreadcrumbMouse.height + 4
                    // )
                    //
                    // dynamicSubfolderMenu.targetPath = crumb.path
                    // dynamicSubfolderMenu.openAt(originPos.x, originPos.y)
                    // dynamicSubfolderMenu.forceActiveFocus()
                }
            }
        }
    }
}

            Component.onCompleted:
                Qt.callLater(recalculateBreadcrumbs)
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

                let itemCount = pathCompletionList.count;
                if (!pathCompletionPopup.visible || itemCount === 0)
                    return;

                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    pathCompletionList.currentIndex = (pathCompletionList.currentIndex + 1) % itemCount;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    pathCompletionList.currentIndex = (pathCompletionList.currentIndex - 1 + itemCount) % itemCount;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let selected = pathCompletionList.currentItem ? pathCompletionList.currentItem.modelData : null;
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
            tooltip: pathBarContainer.pathBookmarked ? "Unbookmark" : "Bookmark"
            round: true
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
                model: (pathDisplay.pathCompletionModel || []).filter(item => item.isFolder)
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
