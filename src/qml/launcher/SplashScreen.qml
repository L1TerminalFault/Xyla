import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects

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

    property bool isListView: true
    property bool searchVisible: false

    readonly property color bgDark: "#121212"
    readonly property color bgCard: "#282828"
    readonly property color accentColor: "#2555D3"
    readonly property color textPrimary: "#ffffff"

    Connections {
        target: projectManager

        function onProjectOpenedSuccessfully() {
            appController.showSplash = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: splashRoot.bgDark
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Banner Image Top Header
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

        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                // Recent Projects Header Toolbar
                RowLayout {
                    id: toolbarRow
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Recent Projects"
                        color: splashRoot.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        id: searchBtn
                        iconSource: "qrc:/assets/icons/search.svg"
                        primary: splashRoot.searchVisible
                        onClicked: {
                            splashRoot.searchVisible = !splashRoot.searchVisible;
                            if (splashRoot.searchVisible)
                                searchInput.forceActiveFocus();
                        }
                    }

                    XylaSelect {
                        id: sortComboBox
                        Layout.preferredWidth: 140
                        model: ["Date Modified", "Name", "Path"]
                    }

                    XylaIconButton {
                        id: sortOrderToggle
                        property bool isAscending: false
                        iconSource: isAscending ? "qrc:/assets/icons/sort-ascending.svg" : "qrc:/assets/icons/sort-descending.svg"
                        onClicked: isAscending = !isAscending
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
                        }
                    }
                }

                // Search Overlay
                Item {
                    id: searchOverlayWrapper
                    Layout.fillWidth: true
                    Layout.preferredHeight: 0
                    z: 100

                    Item {
                        id: searchPopupOverlay
                        anchors.right: parent.right
                        y: splashRoot.searchVisible ? 6 : -6
                        width: 260
                        height: 32

                        visible: opacity > 0
                        opacity: splashRoot.searchVisible ? 1.0 : 0.0

                        Behavior on y {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        TextField {
                            id: searchInput
                            anchors.fill: parent
                            placeholderText: "Search projects..."
                            placeholderTextColor: "#555555"
                            color: "#ffffff"
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            selectByMouse: true

                            background: Rectangle {
                                color: "#181818"
                                border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                                border.width: 1
                                radius: 6
                            }
                        }
                    }
                }

                // Recent Projects View
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: splashRoot.isListView ? 0 : 1

                    ListView {
                        id: recentProjectsList
                        clip: true
                        spacing: 8
                        model: projectManager.recentProjects

                        delegate: RecentProjectCard {
                            width: recentProjectsList.width
                            projectName: model.name
                            projectPath: model.filePath
                            lastModifiedDate: Qt.formatDateTime(model.lastModified, "dd/MM/yyyy hh:mm")

                            onClicked: {
                                projectManager.openProject(model.filePath);
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: recentProjectsList.count === 0
                            text: "No recent projects"
                            color: "#555555"
                            font.pixelSize: 15
                        }
                    }

                    GridView {
                        id: recentProjectsGrid
                        clip: true
                        cellWidth: 200
                        cellHeight: 140
                        model: projectManager.recentProjects

                        delegate: RecentProjectCard {
                            width: 190
                            height: 130
                            projectName: model.name
                            projectPath: model.filePath
                            lastModifiedDate: Qt.formatDateTime(model.lastModified, "dd/MM/yyyy hh:mm")

                            onClicked: {
                                projectManager.openProject(model.filePath);
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: recentProjectsGrid.count === 0
                            text: "No recent projects"
                            color: "#555555"
                            font.pixelSize: 15
                        }
                    }
                }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaTextButton {
                        id: openBtn
                        text: "Open File"
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
