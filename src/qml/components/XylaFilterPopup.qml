import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: control

    width: 200
    padding: 12
    clip: false

    property alias filterContainer: filterContainer
    property bool _recentlyClosed: false
    signal filterChanged(string type, string size, string sortBy, string order)

    onAboutToHide: {
        _recentlyClosed = true;
        closeResetTimer.restart();
    }

    Timer {
        id: closeResetTimer
        interval: 200
        onTriggered: control._recentlyClosed = false
    }

    background: Rectangle {
        id: popupSurface__
        anchors.fill: parent
        color: "#181818"
        border.color: searchInput.activeFocus ? "#2555D3" : "#282828"
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

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            text: "Filter Options"
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
        }

        // ============================================================
        // FILE TYPE
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "File Type"
                color: "#888888"
                font.pixelSize: 11
            }

            Item {
                id: filterContainer
                Layout.fillWidth: true
                Layout.preferredHeight: flowLayout.implicitHeight

                // property var options: ["Folders", "Files", "Images", "Videos", "Audio", "Documents"]
                property var options: ["Folders", "Images", "Videos", "Audio", "Documents"]
                property var selectedIndexes: [true, true, true, true, true]
                property int lastSelectedIndex: 0

                function notifyModel() {
                    let selectedList = [];
                    for (let i = 0; i < options.length; i++) {
                        if (selectedIndexes[i]) {
                            selectedList.push(options[i]);
                        }
                    }

                    if (selectedList.length === options.length) {
                        // Everything on → no type filtering
                        fileSystemModel.typeFilter = "All Files";
                    } else if (selectedList.length === 0) {
                        // Nothing selected → match nothing (empty view)
                        fileSystemModel.typeFilter = "__NONE__";
                    } else if (selectedList.length === 1) {
                        fileSystemModel.typeFilter = selectedList[0];
                    } else {
                        fileSystemModel.typeFilter = selectedList.join(",");
                    }
                }

                Component.onCompleted: notifyModel()

                ColumnLayout {
                    id: flowLayout

                    anchors.fill: parent
                    spacing: 6

                    Repeater {
                        model: filterContainer.options

                        delegate: Rectangle {
                            id: delegateRect

                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            radius: 7

                            property bool isItemSelected: filterContainer.selectedIndexes[index]
                            property bool hovered: mouseArea.containsMouse
                            property bool down: mouseArea.pressed

                            color: {
                                if (isItemSelected) {
                                    return down ? "#11389F" : (hovered ? "#2555D3" : "#11389F");
                                } else {
                                    return down ? "#353535" : (hovered ? "#262626" : "#181818");
                                }
                            }

                            // border.color: isItemSelected ? "#11389F" : "#2d2d2d"
                            // border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16

                                    source: {
                                        switch (modelData) {
                                        case "Folders":
                                            return "qrc:/assets/icons/folder.svg";
                                        case "Images":
                                            return "qrc:/assets/icons/image.svg";
                                        case "Videos":
                                            return "qrc:/assets/icons/video.svg";
                                        case "Audio":
                                            return "qrc:/assets/icons/music.svg";
                                        case "Documents":
                                            return "qrc:/assets/icons/file-text.svg";
                                        default:
                                            return "qrc:/assets/icons/file.svg";
                                        }
                                    }

                                    sourceSize.width: 16
                                    sourceSize.height: 16

                                    opacity: delegateRect.isItemSelected ? 1.0 : 0.7
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData
                                    color: delegateRect.isItemSelected ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: mouseArea

                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: mouse => {
                                    let updated = filterContainer.selectedIndexes.slice();

                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        let start = Math.min(filterContainer.lastSelectedIndex, index);

                                        let end = Math.max(filterContainer.lastSelectedIndex, index);

                                        for (let i = start; i <= end; i++) {
                                            updated[i] = true;
                                        }
                                    } else {
                                        updated[index] = !updated[index];
                                        filterContainer.lastSelectedIndex = index;
                                    }

                                    filterContainer.selectedIndexes = updated;
                                    filterContainer.notifyModel();
                                }
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // SIZE
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "Size"
                color: "#888888"
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaSelect {
                    id: sizeFilter
                    Layout.fillWidth: true
                    model: ["Any Size", "Empty", "Under 1 MB", "1–10 MB", "10–100 MB", "Over 100 MB"]
                    onCurrentTextChanged: fileSystemModel.sizeFilter = currentText
                }

                XylaIconButton {
                    ghost: true
                    iconColor: fileSystemModel.sizeFilter === "Any Size" ? "#333" : "#fff"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Clear Filter"
                    iconSource: "qrc:/assets/icons/clear.svg"
                    onClicked: {
                        sizeFilter.currentIndex = 0;
                    }
                }
            }
        }

        // ============================================================
        // CREATED AT
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "Created At"
                color: "#888888"
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaSelect {
                    id: createdAtFilter
                    Layout.fillWidth: true
                    model: ["Any Time", "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Year"]

                    onCurrentTextChanged: {
                        fileSystemModel.createdAtFilter = currentText;
                    }
                }

                XylaIconButton {
                    ghost: true
                    iconColor: fileSystemModel.createdAtFilter === "Any Time" ? "#333" : "#fff"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Clear Filter"
                    iconSource: "qrc:/assets/icons/clear.svg"
                    onClicked: {
                        createdAtFilter.currentIndex = 0;
                    }
                }
            }
        }

        // ============================================================
        // MODIFIED AT
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "Modified At"
                color: "#888888"
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaSelect {
                    id: modifiedAtFilter

                    Layout.fillWidth: true

                    model: ["Any Time", "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Year"]

                    onCurrentTextChanged: {
                        fileSystemModel.modifiedAtFilter = currentText;
                    }
                }

                XylaIconButton {
                    ghost: true
                    iconColor: fileSystemModel.modifiedAtFilter === "Any Time" ? "#333" : "#fff"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Clear Filter"
                    iconSource: "qrc:/assets/icons/clear.svg"
                    onClicked: {
                        modifiedAtFilter.currentIndex = 0;
                    }
                }
            }
        }
    }

    function emitFilter() {
        filterChanged(typeFilter.currentText, sizeFilter.currentText, sortFilter.currentText, orderToggle.currentValue, modifiedAtFilter.currentText, createdAtFilter.currentText);
    }
}
