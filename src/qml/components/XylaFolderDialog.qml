import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Window {
    id: folderDialogRoot

    title: "Select Directory"
    width: 900
    height: 600
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

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: "Select Directory"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                XylaIconButton {
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

                    // 2. New Folder Button [ Folder+ ]
                    XylaIconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        iconSource: "qrc:/assets/icons/folder-plus.svg"
                        onClicked: fileSystemModel.makeFolder("New Folder")
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
                        rightPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: "#181818"
                            border.color: pathDisplay.activeFocus ? "#2555D3" : "#2d2d2d"
                            border.width: 1
                            radius: 6
                        }

                        onEditingFinished: {
                            fileSystemModel.cd(text.trim());
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
                    }

                    // 5. List vs Grid Segmented View Toggle
                    XylaSegmentedToggle {
                        id: viewToggle
                        currentIndex: 1 // Default Grid View
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

                    // 7. Settings Gear Button
                    XylaIconButton {
                        iconSource: "qrc:/assets/icons/settings.svg"
                        onClicked: console.log("Settings clicked")
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

                // Quick Access Sidebar
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.fillHeight: true
                    color: "#151515"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Text {
                            text: "QUICK ACCESS"
                            color: "#666666"
                            font.pixelSize: 10
                            font.bold: true
                            Layout.leftMargin: 6
                        }

                        XylaTextButton {
                            Layout.fillWidth: true
                            text: "Home"
                            onClicked: fileSystemModel.cd("/home")
                        }

                        XylaTextButton {
                            Layout.fillWidth: true
                            text: "Root"
                            onClicked: fileSystemModel.cd("/")
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: "#2d2d2d"
                    }
                }

                // Directory Contents Grid
                GridView {
                    id: dirGridView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 190
                    cellHeight: 220
                    topMargin: 16
                    bottomMargin: 16
                    leftMargin: 16
                    rightMargin: 16

                    model: fileSystemModel

                    delegate: XylaFolderCard {
                        width: 175
                        height: 205
                        folderName: model.fileName
                        fileCount: model.isDir ? model.itemCount : 0

                        onDoubleClicked: {
                            if (model.isDir) {
                                fileSystemModel.cd(model.filePath);
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
