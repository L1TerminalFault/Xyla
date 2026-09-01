import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Button {
    id: control

    // Custom Properties
    property url iconSource: ""
    property bool ghost: false
    property bool primary: false
    property string tooltip
    property bool round

    // In ghost mode, automatically dim icon when idle and brighten on hover (unless overridden)
    property color iconColor: control.ghost ? (control.hovered ? "#ffffff" : "#989898") : "#ffffff"
    property int iconWidth: 18
    property int iconHeight: 18

    implicitWidth: 32
    implicitHeight: 32

    leftPadding: 5
    rightPadding: 5
    topPadding: 4
    bottomPadding: 4

    XylaToolTip {
        visible: control.tooltip && control.hovered && fileSystemModel.fileManagerSettings.showTooltips
        text: control.tooltip
    }

    contentItem: Item {
        implicitWidth: control.iconWidth
        implicitHeight: control.iconHeight

        Image {
            id: iconImg
            anchors.centerIn: parent
            source: control.iconSource
            sourceSize.width: control.iconWidth
            sourceSize.height: control.iconHeight
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
        }

        scale: control.down ? 0.87 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: control.down ? 80 : 160
                easing.type: control.down ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: 1.3
            }
        }

        MultiEffect {
            source: iconImg
            anchors.fill: iconImg
            colorization: 1.0
            colorizationColor: control.iconColor

            // 2. Smooth color transition for icon
            Behavior on colorizationColor {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    background: Rectangle {
        radius: round ? height / 2 : 7

        color: {
            if (control.ghost) {
                return control.down ? "#353535" : (control.hovered ? "#262626" : "transparent");
            } else if (control.primary) {
                return control.down ? "#11389F" : (control.hovered ? "#2555D3" : "#19389F");
            } else {
                return control.down ? "#353535" : (control.hovered ? "#262626" : "#222222"); // "#181818");
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        border.color: {
            if (control.ghost) {
                return "transparent";
            } else if (control.primary) {
                return "#1938AF"; // "#2555D3";
            } else {
                return "#292929"; // "#2d2d2d";
            }
        }

        border.width: control.ghost ? 0 : 1
    }
}
