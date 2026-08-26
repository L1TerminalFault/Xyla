import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Menu {
    id: customMenu

    padding: 8

    // ============================================================
    // Dynamic width
    // ============================================================

    width: {
        var maxWidth = 160;

        for (var i = 0; i < customMenu.count; ++i) {
            var item = customMenu.itemAt(i);

            if (item && item.implicitWidth)
                maxWidth = Math.max(maxWidth, item.implicitWidth + 24);
        }

        return maxWidth;
    }

    // ============================================================
    // Popup surface
    // ============================================================

    background: Rectangle {
        id: menuSurface

        anchors.fill: parent

        color: "#181818"

        border.color: "#202020"
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

    // ============================================================
    // Windows/Xyla popup opening animation
    // ============================================================

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

    // ============================================================
    // Closing animation
    // ============================================================

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
