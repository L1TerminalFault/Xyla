import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Effects

T.ToolTip {
    id: control

    horizontalPadding: 12
    verticalPadding: 10
    margins: 6
    delay: 500

    property string position: "top"
    property real offset: 8

    x: {
        var p = control.parent;
        if (!p || p.width <= 0)
            return 0;
        switch (control.position) {
        case "left":
            return -width - offset;
        case "right":
            return p.width + offset;
        case "top":
            return (p.width - width) / 2;
        case "bottom":
            return (p.width - width) / 2;
        default:
            return -width - offset;
        }
    }

    y: {
        var p = control.parent;
        if (!p || p.height <= 0)
            return 0;
        switch (control.position) {
        case "left":
        case "right":
            return (p.height - height) / 2;
        case "top":
            return -height - offset;
        case "bottom":
            return p.height + offset;
        default:
            return (p.height - height) / 2;
        }
    }

    background: Rectangle {
        id: tooltipSurface
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

    contentItem: Text {
        text: control.text
        color: "#ffffff"
        font.pixelSize: 12
        wrapMode: Text.Wrap
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
}
