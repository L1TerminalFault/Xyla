import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtQml.Models

Window {
    id: splashRoot
    width: 850
    height: 750
    minimumWidth: 850
    maximumWidth: 850
    minimumHeight: 750
    maximumHeight: 750
    flags: Qt.Dialog | Qt.MSWindowsFixedSizeDialogHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    title: "Xyla - Welcome"
    color: bgDark

    property var settingsManager: null

    property bool isListView: false
    property bool searchVisible: false

    property string searchQuery: ""

    function _restartViewAnimations(view) {
        for (var i = 0; i < view.count; ++i) {
            var item = view.itemAtIndex(i);
            if (item && typeof item.playEntry === "function")
                item.playEntry();
        }
    }

    function restartProjectAnimations() {
        Qt.callLater(function() {
            if (splashRoot.isListView)
                _restartViewAnimations(recentProjectsList);
            else
                _restartViewAnimations(recentProjectsGrid);
        });
    }

    function refreshProjects() {
        recentProjectsProxy.invalidate();
        recentProjectsProxy.invalidateSorter();
        restartProjectAnimations();
    }

    function refreshFromSourceChange() {
        refreshProjects();
    }

    readonly property color bgDark: "#121212"
    readonly property color bgCard: "#282828"
    readonly property color accentColor: "#2555D3"
    readonly property color textPrimary: "#ffffff"

    SortFilterProxyModel {
        id: recentProjectsProxy
        model: projectManager.recentProjects
        dynamicSortFilter: true

        filters: [
            FunctionFilter {
                id: projectSearchFilter

                component RoleData_: QtObject {
                    property string name: ""
                    property string filePath: ""
                }

                function filter(data: RoleData_): bool {
                    var query = splashRoot.searchQuery.trim().toLowerCase();
                    if (query === "")
                        return true;

                    return data.name.toLowerCase().indexOf(query) !== -1
                            || data.filePath.toLowerCase().indexOf(query) !== -1;
                }
            }
        ]

        sorters: [
            FunctionSorter {
                id: projectSorter

                component RoleData: QtObject {
                    property string name: ""
                    property string filePath: ""
                    property var lastModified: null
                }

                function dateValue(value): real {
                    if (value === null || value === undefined)
                        return 0;

                    if (typeof value === "number")
                        return value;

                    if (value instanceof Date)
                        return value.getTime();

                    var parsed = Date.parse(value);
                    return isNaN(parsed) ? 0 : parsed;
                }

                function sort(lhs: RoleData, rhs: RoleData): int {
                    var sortIndex = sortComboBox.currentIndex;
                    var av;
                    var bv;

                    if (sortIndex === 1) {
                        av = lhs.name.toLowerCase();
                        bv = rhs.name.toLowerCase();
                    } else if (sortIndex === 2) {
                        av = lhs.filePath.toLowerCase();
                        bv = rhs.filePath.toLowerCase();
                    } else {
                        av = dateValue(lhs.lastModified);
                        bv = dateValue(rhs.lastModified);
                    }

                    if (av < bv)
                        return sortOrderToggle.isAscending ? -1 : 1;
                    if (av > bv)
                        return sortOrderToggle.isAscending ? 1 : -1;
                    return 0;
                }
            }
        ]
    }

    Rectangle {
        anchors.fill: parent
        color: splashRoot.bgDark
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            color: "transparent"
            clip: true

            Image {
                anchors.fill: parent
                source: "qrc:/assets/splash_banner.png"
                fillMode: Image.PreserveAspectCrop
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                RowLayout {
                    id: toolbarRow
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Recent Projects"
                        color: splashRoot.textPrimary
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        id: searchBtn
                        iconSource: "qrc:/assets/icons/search.svg"
                        primary: searchPopup.opened || (searchInput.text !== "")
                        tooltip: "Search projects"

                        onClicked: {
                            if (searchPopup.opened) {
                                searchPopup.close();
                            } else {
                                searchPopup.open();
                            }
                        }

                        Popup {
                            id: searchPopup
                            y: searchBtn.height + 6
                            width: 230
                            height: 34
                            padding: 0
                            modal: false
                            focus: false
                            closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

                            onOpened: searchInput.forceActiveFocus()
                            onAboutToHide: searchInput.focus = false

                            background: Rectangle {
                                color: "#181818"
                                border.color: searchInput.activeFocus ? splashRoot.accentColor : "#2e2e30"
                                border.width: 1
                                radius: 7

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 200
                                        easing.type: Easing.InOutQuad
                                    }
                                }

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
                                spacing: 6

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    placeholderText: "Search projects..."
                                    placeholderTextColor: "#606060"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    background: Item {}
                                    selectByMouse: true
                                    focus: true
                                    activeFocusOnTab: false

                                    onActiveFocusChanged: {
                                        if (!activeFocus && searchPopup.opened) {
                                            searchInput.forceActiveFocus();
                                        }
                                    }

                                    onTextChanged: {
                                      splashRoot.searchQuery = text;
                                      searchDebounce.restart();
                                    }

                                    Timer {
                                        id: searchDebounce
                                        interval: 50
                                        repeat: false
                                        onTriggered: {
                                            splashRoot.refreshProjects()
                                        }
                                    }

                                    Keys.onEscapePressed: {
                                        text = "";
                                        searchPopup.close();
                                    }

                                    Keys.onReturnPressed: event => {
                                        searchPopup.close();
                                        event.accepted = true;
                                    }

                                    Keys.onEnterPressed: event => {
                                        searchPopup.close();
                                        event.accepted = true;
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    radius: 9
                                    color: clearMouse.containsMouse ? "#28282b" : "#181818"
                                    opacity: searchInput.text.length > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: clearMouse.containsMouse ? "#ffffff" : "#777777"
                                        font.pixelSize: 10

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = "";
                                            searchInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    XylaSelect {
                        id: sortComboBox
                        Layout.preferredWidth: 140
                        model: ["Date Modified", "Name", "Path"]

                        onCurrentIndexChanged: splashRoot.refreshProjects()
                    }

                    XylaIconButton {
                        id: sortOrderToggle
                        property bool isAscending: false

                        onClicked: {
                            isAscending = !isAscending;
                            splashRoot.refreshProjects();
                        }

                        Image {
                            id: sortIcon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/sort-ascending.svg"
                            fillMode: Image.PreserveAspectFit
                            rotation: sortOrderToggle.isAscending ? 0 : 180

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }

                    XylaSegmentedToggle {
                        currentIndex: splashRoot.isListView ? 0 : 1
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
                            splashRoot.isListView = (value === "list");
                            splashRoot.restartProjectAnimations();
                        }
                    }
                }

                StackLayout {
                    id: delegateContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: searchPopup.opened ? 40 : 0
                    currentIndex: splashRoot.isListView ? 0 : 1
                    property bool _clicked: false

                    Behavior on Layout.topMargin {
                        NumberAnimation {
                            duration: 220;
                            easing.type: Easing.OutCubic
                        }
                    }

                    ListView {
                        id: recentProjectsList
                        clip: true
                        spacing: 8
                        model: recentProjectsProxy

                        delegate: RecentProjectListCard {
                            id: cardItem
                            required property int index
                            required property var model

                            width: recentProjectsList.width
                            projectName: model.name
                            projectPath: model.filePath
                            lastModifiedDate: Qt.formatDateTime(model.lastModified, "ddd, MMM d, yyyy, h:mm ap")

                            onClicked: {
                                if (delegateContainer._clicked) return;
                                delegateContainer._clicked = true;
                                projectManager.openProject(model.filePath);
                            }

                            opacity: 0
                            scale: 0.82
                            transformOrigin: Item.Center
                            transform: Translate { id: cardTranslation; y: 20 }

                            function playEntry() {
                                cardItem.opacity = 0
                                cardItem.scale = 0.82
                                cardTranslation.y = 20
                                entryAnimation.restart()
                            }

                            Component.onCompleted: {
                                cardItem.playEntry()
                            }

                            SequentialAnimation {
                                id: entryAnimation

                                PauseAnimation {
                                    duration: 120 + cardItem.index * 55
                                }

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: cardItem
                                        property: "opacity"
                                        to: 1.0
                                        duration: 280
                                        easing.type: Easing.OutCubic
                                    }

                                    NumberAnimation {
                                        target: cardItem
                                        property: "scale"
                                        to: 1.0
                                        duration: 350
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.3
                                    }

                                    NumberAnimation {
                                        target: cardTranslation
                                        property: "y"
                                        to: 0
                                        duration: 380
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }
                                }
                            }
                        }

                        SplashEmpty {
                            visible: recentProjectsList.count === 0
                            anchors.centerIn: parent
                        }
                    }

                    GridView {
                        id: recentProjectsGrid
                        clip: true
                        cellWidth: width / 3
                        cellHeight: 240
                        model: recentProjectsProxy

                        delegate: RecentProjectPaletteCard {
                            id: cardItem
                            required property int index
                            required property var model

                            width: recentProjectsGrid.cellWidth - 10
                            height: recentProjectsGrid.cellHeight - 10
                            projectName: model.name
                            projectPath: model.filePath
                            lastModifiedDate: Qt.formatDateTime(model.lastModified, "ddd, MMM d, yyyy, h:mm ap")

                            onClicked: {
                                if (delegateContainer._clicked) return;
                                delegateContainer._clicked = true;
                                projectManager.openProject(model.filePath);
                            }

                            opacity: 0
                            scale: 0.82
                            transformOrigin: Item.Center
                            transform: Translate { id: cardTranslation; y: 20 }

                            function playEntry() {
                                cardItem.opacity = 0
                                cardItem.scale = 0.82
                                cardTranslation.y = 20
                                entryAnimation.restart()
                            }

                            Component.onCompleted: {
                                cardItem.playEntry()
                            }

                            SequentialAnimation {
                                id: entryAnimation

                                PauseAnimation {
                                    duration: 120 + cardItem.index * 55
                                }

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: cardItem
                                        property: "opacity"
                                        to: 1.0
                                        duration: 280
                                        easing.type: Easing.OutCubic
                                    }

                                    NumberAnimation {
                                        target: cardItem
                                        property: "scale"
                                        to: 1.0
                                        duration: 350
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.3
                                    }

                                    NumberAnimation {
                                        target: cardTranslation
                                        property: "y"
                                        to: 0
                                        duration: 380
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }
                                }
                            }
                        }

                        SplashEmpty {
                            visible: recentProjectsList.count === 0
                            anchors.centerIn: parent
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Always Show Splash on Startup"
                        color: "#ffffff"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }

StyledSwitch {
    id: alwaysShowSplashBtn
    Layout.alignment: Qt.AlignVCenter
    
    checked: (typeof settingsManager !== "undefined" && settingsManager !== null) 
             ? settingsManager.showSplashOnStartup 
             : true
             
    onToggled: {
        if (typeof settingsManager !== "undefined" && settingsManager !== null) {
            settingsManager.showSplashOnStartup = checked;
        }
    }
}

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaTextButton {
                        id: openBtn
                        text: "Open File"
                        sleek: true
                        onClicked: fileDialog.open()
                    }

                    XylaTextButton {
                        id: newBtn
                        text: "New Project"
                        primary: true
                        onClicked: newProjectDialog.open()
                    }
                }
            }
        }
    }

    component StyledSwitch: Switch {
        id: control

        implicitWidth: 44
        implicitHeight: 24

        indicator: Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            x: control.leftPadding
            y: parent.height / 2 - height / 2
            radius: 12
            color: control.checked ? "#11389F" : "#0C0C0C"
            border.color: control.checked ? "#11389F" : "#0C0C0C"
            border.width: control.checked ? 0 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: control.checked ? parent.width - width - 3 : 3
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        contentItem: Item {}
    }

    Connections {
        target: projectManager.recentProjects
        ignoreUnknownSignals: true

        function onCountChanged() {
            splashRoot.refreshFromSourceChange();
        }

        function onRowsInserted() {
            splashRoot.refreshFromSourceChange();
        }

        function onRowsRemoved() {
            splashRoot.refreshFromSourceChange();
        }

        function onRowsMoved() {
            splashRoot.refreshFromSourceChange();
        }

        function onModelReset() {
            splashRoot.refreshFromSourceChange();
        }

        function onDataChanged() {
            splashRoot.refreshFromSourceChange();
        }

        function onLayoutChanged() {
            splashRoot.refreshFromSourceChange();
        }
    }

    Component.onCompleted: refreshProjects();

    FileDialog {
        id: fileDialog
        title: "Open Xyla Project"
        nameFilters: ["Xyla Projects (*.xyla)", "All Files (*)"]
        onAccepted: {
            var selectedPath = fileDialog.selectedFile.toString().replace(/^file:\/\//, "");
            projectManager.openProject(selectedPath);
        }
    }

    NewProjectDialog {
        id: newProjectDialog
    }
}
