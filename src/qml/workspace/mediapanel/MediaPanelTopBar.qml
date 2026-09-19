import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Xyla 1.0
import "../../components"

RowLayout {
    id: toolbarRow
    // Exposed references to parent and dialogs
    property var panelRoot: null
    property var folderDialog: null
    property var settingsPopup: null

    // Subcomponent aliases for external bindings
    property alias settingsBtn: _settingsBtn
    property alias sortComboBox: _sortComboBox
    property alias sortOrderToggle: _sortOrderToggle
    property alias viewModeToggle: _viewModeToggle
    property alias filterBtn: _filterBtn
    property alias filterPopup: _filterPopup
    property alias searchBtn: _searchBtn
    property alias searchPopup: _searchPopup
    property alias searchInput: _searchInput

    Layout.fillWidth: true
    spacing: 6

    // Add button
    XylaIconButton {
        // implicitWidth: 30
        // implicitHeight: 30
        iconSource: "qrc:/assets/icons/plus.svg"
        tooltip: "Add Assets"
        primary: true
        onClicked: {
            panelRoot.editingItemId = "";
            folderDialog.open();
        }
    }

    // Settings button
    XylaIconButton {
        id: _settingsBtn
        // implicitWidth: 30
        // implicitHeight: 30
        tooltip: "Asset Manager Settings"
        primary: settingsPopup.opened
        iconSource: "qrc:/assets/icons/settings.svg"
        onClicked: {
            panelRoot.editingItemId = "";
            if (settingsPopup.opened) {
                settingsPopup.close();
            } else {
                settingsPopup.open();
            }
        }
    }

    // Up folder navigation (Only relevant in Grid View)
    RowLayout {
        spacing: 6
        visible: !panelRoot.isListView && panelRoot.activeMediaBinModel && panelRoot.activeMediaBinModel.currentBinId !== "root"

        XylaIconButton {
            // implicitWidth: 30
            // implicitHeight: 30
            iconSource: "qrc:/assets/icons/arrow-up.svg"
            tooltip: "Go to parent folder"
            onClicked: {
                panelRoot.editingItemId = "";
                if (panelRoot.activeMediaBinModel) {
                    panelRoot.activeMediaBinModel.goToParentBin();
                    panelRoot.clearSelection();
                }
            }
        }

        Text {
            text: panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinName : ""
            color: panelRoot.textPrimary
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.maximumWidth: 120
        }
    }

    Item {
        Layout.minimumWidth: 10
        Layout.fillWidth: true
    }

    // Sort Select Dropdown
    XylaSelect {
        id: _sortComboBox

        // Layout.preferredWidth: 95
        // implicitHeight: 30

        icon: "qrc:/assets/icons/sort.svg"
        activeFocusOnTab: false

        model: ["Name", "Duration", "Path"]

        currentIndex: {
            var settings = panelRoot.mediaPanelSettings;
            if (!settings || !settings.sortMode)
                return 0;

            var idx = model.indexOf(settings.sortMode);
            return idx >= 0 ? idx : 0;
        }

        onActivated: function (index) {
            panelRoot.editingItemId = "";

            if (panelRoot.mediaPanelSettings) {
                panelRoot.mediaPanelSettings.sortMode = model[index];
            }

            if (panelRoot.activeMediaBinModel) {
                panelRoot.activeMediaBinModel.setSortRole(index);
            }
        }
    }

    // Sort Order Toggle
    XylaIconButton {
        id: _sortOrderToggle
        // implicitWidth: 30
        // implicitHeight: 30
        property bool isAscending: true
        iconSource: ""

        onClicked: {
            panelRoot.editingItemId = "";
            isAscending = !isAscending;
            if (panelRoot.activeMediaBinModel) {
                panelRoot.activeMediaBinModel.setSortAscending(isAscending);
            }
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

    // Segmented Toggle (List / Grid)
    XylaSegmentedToggle {
        id: _viewModeToggle

        // implicitHeight: 30

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

        // Declarative binding to root UI state
        currentIndex: panelRoot.isListView ? 0 : 1

        onOptionSelected: (index, value) => {
            panelRoot.editingItemId = "";

            var isList = (value === "list");
            panelRoot.isListView = isList;

            if (panelRoot.mediaPanelSettings) {
                panelRoot.mediaPanelSettings.defaultView = value;
            }
        }
    }

    XylaIconButton {
        id: _filterBtn
        iconSource: "qrc:/assets/icons/filter.svg"
        // implicitWidth: 30
        // implicitHeight: 30
        tooltip: "Filter assets"

        // Lights up whenever any filter is active or when the popup is open
        primary: filterPopup.opened || (panelRoot.activeMediaBinModel && panelRoot.activeMediaBinModel.hasActiveFilters)

        onClicked: {
            if (filterPopup._recentlyClosed) {
                filterPopup._recentlyClosed = false;
                return;
            }
            if (filterPopup.opened)
                filterPopup.close();
            else
                filterPopup.open();
        }

        MediaBinFilterPopup {
            id: _filterPopup
            parent: filterBtn
            mediaBinModel: panelRoot.activeMediaBinModel
            y: parent.height + 6
            x: parent.width - width
        }
    }
    // Search Toggle Button

    XylaIconButton {
        id: _searchBtn
        // implicitWidth: 30
        // implicitHeight: 30
        iconSource: "qrc:/assets/icons/search.svg"
        primary: searchPopup.opened || (searchInput.text !== "")
        tooltip: "Search assets"

        onClicked: {
            panelRoot.editingItemId = "";
            if (searchPopup.opened) {
                searchPopup.close();
            } else {
                searchPopup.open();
            }
        }

        Popup {
            id: _searchPopup
            y: searchBtn.height + 6
            x: searchBtn.width - width
            width: 360
            height: 34
            padding: 0
            modal: false
            focus: false
            closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

            // Synchronize with model's globalSearch property
            property bool globalSearch: (panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.globalSearch : true)

            onOpened: searchInput.forceActiveFocus()
            onAboutToHide: searchInput.focus = false

            background: Rectangle {
                color: "#181818"
                border.color: searchInput.activeFocus ? (panelRoot.activeMediaBinModel.globalSearch ? "#8555D3" : panelRoot.accentColor) : "#2e2e30"
                border.width: 1
                radius: 7

                // Animate any change to the border.color property
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200 // Time in milliseconds for the transition
                        easing.type: Easing.InOutQuad // Smooth acceleration and deceleration
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
                    id: _searchInput

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    placeholderText: (searchPopup.globalSearch || panelRoot.isListView) ? "Search everywhere..." : "Search this folder..."

                    placeholderTextColor: "#606060"
                    color: "#ffffff"
                    font.pixelSize: 11

                    background: Item {}

                    selectByMouse: true
                    focus: true
                    activeFocusOnTab: false

                    // Preserved exact focus lock fix
                    onActiveFocusChanged: {
                        if (!activeFocus && searchPopup.opened && panelRoot.editingItemId === "") {
                            searchInput.forceActiveFocus();
                        }
                    }

                    onTextChanged: searchDebounce.restart()

                    Timer {
                        id: searchDebounce
                        interval: 50
                        repeat: false

                        onTriggered: {
                            if (panelRoot.activeMediaBinModel) {
                                panelRoot.activeMediaBinModel.searchFilter = searchInput.text;
                            }
                        }
                    }

                    Keys.onEscapePressed: {
                        text = "";
                        if (panelRoot.activeMediaBinModel) {
                            panelRoot.activeMediaBinModel.searchFilter = "";
                        }
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

                // Quick clear button ('✕')
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
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            if (panelRoot.activeMediaBinModel) {
                                panelRoot.activeMediaBinModel.searchFilter = "";
                            }
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // Search scope toggle (Visible in Grid View where folders exist)
                Rectangle {
                    id: searchScopeButton
                    visible: !panelRoot.isListView
                    Layout.preferredWidth: scopeRow.implicitWidth + 12
                    Layout.preferredHeight: 24
                    radius: 6

                    color: scopeMouse.pressed ? "#303033" : scopeMouse.containsMouse ? "#28282b" : "#181818"

                    Behavior on color {
                        ColorAnimation {
                            duration: scopeMouse.pressed ? 80 : 140
                            easing.type: scopeMouse.pressed ? Easing.OutQuad : Easing.OutCubic
                        }
                    }

                    Row {
                        id: scopeRow
                        anchors.centerIn: parent
                        spacing: 4

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            sourceSize: Qt.size(13, 13)
                            fillMode: Image.PreserveAspectFit
                            source: searchPopup.globalSearch ?
                            // FIX: Icon
                            "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/clear-all.svg"
                            opacity: scopeMouse.containsMouse ? 1.0 : 0.65
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: searchPopup.globalSearch ? "This folder" : "Everywhere"
                            color: scopeMouse.containsMouse ? "#ffffff" : "#989898"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            width: implicitWidth

                            // Animate the text color change
                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Animate the width change when the text string changes
                            Behavior on width {
                                NumberAnimation {
                                    duration: 200 // Slightly longer than color for a smoother layout shift
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: scopeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            var nextState = !searchPopup.globalSearch;
                            searchPopup.globalSearch = nextState;

                            if (panelRoot.activeMediaBinModel) {
                                panelRoot.activeMediaBinModel.globalSearch = nextState;
                            }

                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }
}
