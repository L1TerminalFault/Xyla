import QtQuick
import QtQuick.Controls

Item {
    id: root

    property real from: 0.0
    property real to: 1.0
    property real value: 0.0
    property real stepSize: 0.01

    signal moved

    implicitWidth: 160
    implicitHeight: 28

    readonly property real visualPercent: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))

    // Background Capsule Track with radius 10
    Rectangle {
        id: trackBg
        anchors.fill: parent
        radius: 10
        color: "#161618"
        border.color: "#28282e"
        border.width: 1
        clip: true

        // Active Filled Portion - PURE SOLID WHITE (#ffffff) with radius 10
        Rectangle {
            id: fillRect
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * root.visualPercent)
            radius: 10
            color: "#ffffff"

            // Cutout Thumb Slot
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: parent.height - 8
                radius: 2.5
                color: "#161618"
            }
        }
    }

    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function updateValueFromMouse(mx) {
            var ratio = Math.max(0.0, Math.min(1.0, mx / root.width));
            var raw = root.from + ratio * (root.to - root.from);
            if (root.stepSize > 0) {
                raw = Math.round(raw / root.stepSize) * root.stepSize;
            }
            root.value = Math.max(root.from, Math.min(root.to, raw));
            root.moved();
        }

        onPressed: function (mouse) {
            updateValueFromMouse(mouse.x);
        }
        onPositionChanged: function (mouse) {
            if (pressed)
                updateValueFromMouse(mouse.x);
        }
    }
}
