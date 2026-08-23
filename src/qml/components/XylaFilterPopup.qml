import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control

    width: 240
    padding: 12
    clip: false

    property bool _recentlyClosed: false

    signal filterChanged(string resolution, string fps, string scan, string orientation)

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

        // Resolution Filter
        ColumnLayout {
            spacing: 4
            Text {
                text: "Resolution"
                color: "#888888"
                font.pixelSize: 11
            }
            XylaSelect {
                id: resolutionFilter
                Layout.fillWidth: true
                model: ["All Resolutions", "1080p", "4K", "720p", "Custom"]
                onCurrentTextChanged: control.emitFilter()
            }
        }

        // FPS Filter
        ColumnLayout {
            spacing: 4
            Text {
                text: "Framerate"
                color: "#888888"
                font.pixelSize: 11
            }
            XylaSelect {
                id: fpsFilter
                Layout.fillWidth: true
                model: ["All FPS", "60 fps", "30 fps", "24 fps", "50 fps"]
                onCurrentTextChanged: control.emitFilter()
            }
        }

        // Scan Mode Filter
        ColumnLayout {
            spacing: 4
            Text {
                text: "Scan Mode"
                color: "#888888"
                font.pixelSize: 11
            }
            XylaSelect {
                id: scanFilter
                Layout.fillWidth: true
                model: ["All Scans", "Progressive", "Interlaced"]
                onCurrentTextChanged: control.emitFilter()
            }
        }

        // Orientation Segmented Control
        ColumnLayout {
            spacing: 4
            Text {
                text: "Orientation"
                color: "#888888"
                font.pixelSize: 11
            }
            XylaSegmentedToggle {
                id: orientationToggle
                currentIndex: 0
                options: [
                    {
                        icon: "qrc:/assets/icons/layout-grid.svg",
                        value: "all"
                    },
                    {
                        icon: "qrc:/assets/icons/crop-landscape.svg",
                        value: "landscape"
                    },
                    {
                        icon: "qrc:/assets/icons/crop-portrait.svg",
                        value: "portrait"
                    }
                ]
                onOptionSelected: (index, value) => control.emitFilter()
            }
        }
    }

    function emitFilter() {
        filterChanged(resolutionFilter.currentText, fpsFilter.currentText, scanFilter.currentText, orientationToggle.currentValue);
    }
}
