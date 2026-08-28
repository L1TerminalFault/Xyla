import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Effects

T.ToolTip {
    id: control

    horizontalPadding: 12
    verticalPadding: 10
    margins: 6
    delay: 500

    // Custom property for directional positioning: "left", "right", "top", "bottom"
    property string position: "top"
    property real offset: 8

    // Calculate x and y dynamically based on position
    x: {
        if (!parent) return 0;
        switch (control.position) {
            case "left":   return -width - offset;
            case "right":  return parent.width + offset;
            case "top":    return (parent.width - width) / 2;
            case "bottom": return (parent.width - width) / 2;
            default:       return -width - offset;
        }
    }

    y: {
        if (!parent) return 0;
        switch (control.position) {
            case "left":
            case "right":  return (parent.height - height) / 2;
            case "top":    return -height - offset;
            case "bottom": return parent.height + offset;
            default:       return (parent.height - height) / 2;
        }
    }

    // Custom dark surface styling
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

    // Default text label styling
    contentItem: Text {
        text: control.text
        // font: control.font
        color: "#ffffff"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    // Matching scale & fade enter animation
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

    // Matching scale & fade exit animation
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
