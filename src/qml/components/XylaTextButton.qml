import QtQuick
import QtQuick.Controls

Button {
    id: control

    property bool primary: false
    property bool sleek: false

    leftPadding: 16
    rightPadding: 16
    topPadding: 10
    bottomPadding: 10

    // Tactile Click Scale Bounce
    scale: control.down ? 0.96 : 1.0
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation {
            duration: control.down ? 80 : 160
            easing.type: control.down ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 1.5 // Spring bounce overshoot on release
        }
    }

    contentItem: Text {
        text: control.text
        color: "#ffffff"
        font.pixelSize: 13
        font.bold: control.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 6
        border.color: control.primary || control.sleek ? "transparent" : "#2d2d2d"
        border.width: control.primary || control.sleek ? 0 : 1

        color: control.primary ? "transparent" : (control.down ? "#353535" : (control.hovered ? "#262626" : control.sleek ? "transparent" : "#181818"))

        gradient: control.primary ? primaryGradient : null

        Gradient {
            id: primaryGradient
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: control.down ? "#0e2d80" : (control.hovered ? "#1644bf" : "#11389F")
            }
            GradientStop {
                position: 1.0
                color: control.down ? "#1d45ab" : (control.hovered ? "#3c6ce7" : "#2555D3")
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}
