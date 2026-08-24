import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control

    width: 240
    padding: 12
    clip: false
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
        color: "#181818"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 8
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

            XylaSelect {
                id: typeFilter
                Layout.fillWidth: true
                model: ["All Files", "Folders", "Files", "Images", "Videos", "Audio", "Documents"]
                onCurrentTextChanged: fileSystemModel.typeFilter = currentText
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

            XylaSelect {
                id: sizeFilter
                Layout.fillWidth: true
                model: ["Any Size", "Empty", "Under 1 MB", "1–10 MB", "10–100 MB", "Over 100 MB"]
                onCurrentTextChanged: fileSystemModel.sizeFilter = currentText
            }
        }

        // ============================================================
        // SORT BY
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "Sort By"
                color: "#888888"
                font.pixelSize: 11
            }

            XylaSelect {
                id: sortFilter
                Layout.fillWidth: true
                model: ["Name", "Date Modified", "Size", "Type"]
                onCurrentTextChanged: fileSystemModel.sortBy = currentText
            }
        }

        // ============================================================
        // SORT ORDER
        // ============================================================

        ColumnLayout {
            spacing: 4

            Text {
                text: "Order"
                color: "#888888"
                font.pixelSize: 11
            }

            XylaSegmentedToggle {
                id: orderToggle
                currentIndex: 0
                options: [
                    {
                        // icon: "qrc:/assets/icons/arrow-down-a-z.svg",
                        icon: "qrc:/assets/icons/arrow-down.svg",
                        value: "ascending"
                    },
                    {
                        // icon: "qrc:/assets/icons/arrow-up-a-z.svg",
                        icon: "qrc:/assets/icons/arrow-up.svg",
                        value: "descending"
                    }
                ]
                // onOptionSelected: (index, value) => control.emitFilter()
                onOptionSelected: (index, value) => {
                    fileSystemModel.sortOrder = value;
                }
            }
        }
    }

    function emitFilter() {
        filterChanged(typeFilter.currentText, sizeFilter.currentText, sortFilter.currentText, orderToggle.currentValue);
    }
}
