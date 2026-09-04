import QtQuick
import QtQuick.Controls

Item {
    id: root

    property real value: 0.0
    property real minValue: -1.0
    property real maxValue: 1.0
    property real stepSize: 0.01
    property color accentColor: "#3b82f6"
    property color trackColor: "#262626"

    implicitWidth: 32
    implicitHeight: 32

    // Normalized 0 → 1
    readonly property real _normalized: {
        var range = maxValue - minValue;
        if (range <= 0)
            return 0;
        return (Math.max(minValue, Math.min(maxValue, value)) - minValue) / range;
    }

    // Knob angle: -135° (7 o'clock) → +135° (5 o'clock), 0° = top
    readonly property real _angle: -135 + (_normalized * 270)

    // ------------------------------------------------------------------
    // Outer track + value arc
    // ------------------------------------------------------------------
    Canvas {
        id: trackCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var cX = width / 2;
            var cY = height / 2;
            var radius = Math.min(width, height) / 2 - 3;

            // Canvas angles: 0 = east, positive = clockwise
            // Our knob 0° (top) → canvas -90° / 270°
            function toCanvas(deg) {
                return (deg - 90) * Math.PI / 180;
            }

            var startA = toCanvas(-135);          // bottom-left
            var endA = toCanvas(135);           // bottom-right

            // Background arc (full travel)
            ctx.beginPath();
            ctx.arc(cX, cY, radius, startA, endA, false);
            ctx.strokeStyle = root.trackColor;
            ctx.lineWidth = 3;
            ctx.stroke();

            // Active value arc
            var valueA = toCanvas(root._angle);

            ctx.beginPath();
            if (root.minValue < 0 && root.maxValue > 0) {
                // Bi-directional from centre (0)
                var zeroA = toCanvas(0);
                ctx.arc(cX, cY, radius, zeroA, valueA, valueA < zeroA);
            } else {
                // From minimum up to current value
                ctx.arc(cX, cY, radius, startA, valueA, false);
            }
            ctx.strokeStyle = root.enabled ? root.accentColor : "#555555";
            ctx.lineWidth = 3;
            ctx.stroke();
        }

        Connections {
            target: root
            function onValueChanged() {
                trackCanvas.requestPaint();
            }
            function onMinValueChanged() {
                trackCanvas.requestPaint();
            }
            function onMaxValueChanged() {
                trackCanvas.requestPaint();
            }
            function onEnabledChanged() {
                trackCanvas.requestPaint();
            }
        }
    }

    // ------------------------------------------------------------------
    // Inner dial + needle
    // ------------------------------------------------------------------
    Rectangle {
        id: dial
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - 10
        height: width
        radius: width / 2
        color: root.enabled ? "#1e1e1e" : "#161616"
        border.color: "#333333"
        border.width: 1

        // Needle – points up at rotation 0, matches _angle
        Rectangle {
            width: 2
            height: parent.height / 2 - 2
            color: root.enabled ? "#ffffff" : "#666666"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 2
            transformOrigin: Item.Bottom
            rotation: root._angle
        }
    }

    // ------------------------------------------------------------------
    // Interaction
    // ------------------------------------------------------------------
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabled
        preventStealing: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        property real startY: 0
        property real startValue: 0

        onPressed: function (mouse) {
            startY = mouse.y;
            startValue = root.value;
        }

        onPositionChanged: function (mouse) {
            if (!pressed)
                return;
            var dy = startY - mouse.y;
            var range = root.maxValue - root.minValue;
            var sensitivity = range / 150.0;          // 150 px = full range
            var newValue = startValue + dy * sensitivity;

            if (root.stepSize > 0)
                newValue = Math.round(newValue / root.stepSize) * root.stepSize;

            newValue = Math.max(root.minValue, Math.min(root.maxValue, newValue));
            if (root.value !== newValue)
                root.value = newValue;
        }

        // Double-click → reset to centre (or min)
        onDoubleClicked: {
            var defaultVal = (root.minValue < 0 && root.maxValue > 0) ? 0.0 : root.minValue;
            root.value = defaultVal;
        }

        // Mouse wheel
        onWheel: function (wheel) {
            if (!root.enabled)
                return;
            var range = root.maxValue - root.minValue;
            // One “notch” ≈ 1/40 of the full range (feels natural)
            var step = (root.stepSize > 0) ? root.stepSize : range / 40;

            // Invert so scrolling up increases the value
            var delta = wheel.angleDelta.y > 0 ? step : -step;
            var newValue = root.value + delta;

            if (root.stepSize > 0)
                newValue = Math.round(newValue / root.stepSize) * root.stepSize;

            newValue = Math.max(root.minValue, Math.min(root.maxValue, newValue));
            if (root.value !== newValue)
                root.value = newValue;

            wheel.accepted = true;
        }
    }
}
