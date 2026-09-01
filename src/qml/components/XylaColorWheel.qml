import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: wheelRoot

    property string title: "Lift"
    property real defaultBase: 0.0
    property real sensitivity: 0.35

    property real redVal: defaultBase
    property real greenVal: defaultBase
    property real blueVal: defaultBase
    property real masterVal: 0.0

    property real handleX: 0.0
    property real handleY: 0.0
    property color pinFillColor: "#ffffff"

    signal colorChanged(real r, real g, real b, real master)

    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 140
    implicitHeight: 210

    function resetAll() {
        handleX = 0.0;
        handleY = 0.0;
        masterVal = 0.0;
        redVal = defaultBase;
        greenVal = defaultBase;
        blueVal = defaultBase;
        pinFillColor = "#ffffff";
        wheelRoot.colorChanged(redVal, greenVal, blueVal, masterVal);
    }

    function updateFromHandle(nx, ny) {
        handleX = nx;
        handleY = ny;

        var rad = Math.sqrt(nx * nx + ny * ny);
        var angle = Math.atan2(ny, nx);

        var rDelta = rad * Math.cos(angle);
        var gDelta = rad * Math.cos(angle - (2.0 * Math.PI / 3.0));
        var bDelta = rad * Math.cos(angle - (4.0 * Math.PI / 3.0));

        if (defaultBase === 0.0) {
            redVal = masterVal + (rDelta * sensitivity);
            greenVal = masterVal + (gDelta * sensitivity);
            blueVal = masterVal + (bDelta * sensitivity);
        } else {
            redVal = Math.max(0.01, 1.0 + masterVal + (rDelta * sensitivity));
            greenVal = Math.max(0.01, 1.0 + masterVal + (gDelta * sensitivity));
            blueVal = Math.max(0.01, 1.0 + masterVal + (bDelta * sensitivity));
        }

        if (rad < 0.02) {
            pinFillColor = "#ffffff";
        } else {
            var normAngle = (angle < 0 ? angle + 2 * Math.PI : angle) / (2 * Math.PI);
            var sat = Math.min(1.0, rad * 1.2);
            pinFillColor = Qt.hsla(normAngle, sat, 0.5, 1.0);
        }

        wheelRoot.colorChanged(redVal, greenVal, blueVal, masterVal);
    }

    function updateFromManualRGB() {
        var rDiff = redVal - defaultBase - masterVal;
        var gDiff = greenVal - defaultBase - masterVal;
        var bDiff = blueVal - defaultBase - masterVal;

        var ny = (rDiff - gDiff) / (sensitivity * 1.732);
        var nx = (bDiff - 0.5 * (rDiff + gDiff)) / sensitivity;

        var len = Math.sqrt(nx * nx + ny * ny);
        if (len > 1.0) {
            nx /= len;
            ny /= len;
        }
        handleX = nx;
        handleY = ny;

        var angle = Math.atan2(ny, nx);
        if (len < 0.02) {
            pinFillColor = "#ffffff";
        } else {
            var normAngle = (angle < 0 ? angle + 2 * Math.PI : angle) / (2 * Math.PI);
            pinFillColor = Qt.hsla(normAngle, Math.min(1.0, len * 1.2), 0.5, 1.0);
        }

        wheelRoot.colorChanged(redVal, greenVal, blueVal, masterVal);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // 1. Header Title & Reset
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 2

            Text {
                text: wheelRoot.title
                color: "#eeeeee"
                font.pixelSize: 11
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "↺"
                color: resetMouse.containsMouse ? "#ffffff" : "#666677"
                font.pixelSize: 12
                font.bold: true

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wheelRoot.resetAll()
                }
            }
        }

        // 2. Responsive Expanding Color Wheel Circle
        Rectangle {
            id: wheelCircle
            readonly property real wheelDim: Math.max(90, Math.min(parent.width - 8, parent.height - 70))
            Layout.preferredWidth: wheelDim
            Layout.preferredHeight: wheelDim
            Layout.alignment: Qt.AlignHCenter
            radius: width / 2
            color: "#121212"
            border.color: "#222228"
            border.width: 1
            clip: false

            readonly property real usableRadius: (width / 2) - 7

            Canvas {
                id: spectrumCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    var cx = width / 2;
                    var cy = height / 2;
                    var outerR = cx - 1;
                    var innerR = outerR - 5;

                    var segments = 60;
                    for (var i = 0; i < segments; i++) {
                        var startAngle = (i / segments) * 2 * Math.PI - (Math.PI / 2);
                        var endAngle = ((i + 1.5) / segments) * 2 * Math.PI - (Math.PI / 2);
                        var hue = i / segments;

                        ctx.beginPath();
                        ctx.arc(cx, cy, outerR - 2.5, startAngle, endAngle, false);
                        ctx.strokeStyle = Qt.hsla(hue, 1.0, 0.5, 0.95);
                        ctx.lineWidth = 5;
                        ctx.stroke();
                    }

                    var grad = ctx.createRadialGradient(cx, cy, 2, cx, cy, innerR);
                    grad.addColorStop(0.0, "#121212");
                    grad.addColorStop(0.85, "#121212");
                    grad.addColorStop(1.0, "rgba(18, 18, 18, 0.6)");
                    ctx.fillStyle = grad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, innerR, 0, 2 * Math.PI);
                    ctx.fill();

                    ctx.strokeStyle = "#282830";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(cx, 6);
                    ctx.lineTo(cx, height - 6);
                    ctx.moveTo(6, cy);
                    ctx.lineTo(width - 6, cy);
                    ctx.stroke();

                    ctx.fillStyle = "#444455";
                    ctx.beginPath();
                    ctx.arc(cx, cy, 2, 0, 2 * Math.PI);
                    ctx.fill();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Rectangle {
                id: trackballHandle
                width: 14
                height: 14
                radius: 7
                color: wheelRoot.pinFillColor
                border.color: "#ffffff"
                border.width: 2
                z: 30

                x: (wheelCircle.width / 2) + (wheelRoot.handleX * wheelCircle.usableRadius) - 7
                y: (wheelCircle.height / 2) - (wheelRoot.handleY * wheelCircle.usableRadius) - 7
            }

            MouseArea {
                id: wheelMouseArea
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.CrossCursor

                function handleMouse(mouse) {
                    var cx = wheelCircle.width / 2;
                    var cy = wheelCircle.height / 2;
                    var nx = (mouse.x - cx) / wheelCircle.usableRadius;
                    var ny = (cy - mouse.y) / wheelCircle.usableRadius;

                    var len = Math.sqrt(nx * nx + ny * ny);
                    if (len > 1.0) {
                        nx /= len;
                        ny /= len;
                    }
                    wheelRoot.updateFromHandle(nx, ny);
                }

                onPressed: function (mouse) {
                    handleMouse(mouse);
                }
                onPositionChanged: function (mouse) {
                    if (pressed)
                        handleMouse(mouse);
                }
                onDoubleClicked: wheelRoot.resetAll()
            }
        }

        // 3. Inputs Underneath Color Wheel with Integrated Left Accent Colors
        ColumnLayout {
            Layout.preferredWidth: Math.max(110, wheelCircle.width)
            Layout.alignment: Qt.AlignHCenter
            spacing: 3

            // Top Row: 3 Inputs for R, G, B
            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                // Red Input
                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.redVal
                    accentColor: "#EF4444"
                    stepSize: 0.02
                    onValueCommitted: function (newVal) {
                        wheelRoot.redVal = newVal;
                        wheelRoot.updateFromManualRGB();
                    }
                }

                // Green Input
                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.greenVal
                    accentColor: "#22C55E"
                    stepSize: 0.02
                    onValueCommitted: function (newVal) {
                        wheelRoot.greenVal = newVal;
                        wheelRoot.updateFromManualRGB();
                    }
                }

                // Blue Input
                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.blueVal
                    accentColor: "#3B82F6"
                    stepSize: 0.02
                    onValueCommitted: function (newVal) {
                        wheelRoot.blueVal = newVal;
                        wheelRoot.updateFromManualRGB();
                    }
                }
            }

            // Bottom Row: Full Width Gain/Master Input
            XylaFloatInput {
                label: "Gain"
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                value: wheelRoot.masterVal
                stepSize: 0.02
                onValueCommitted: function (newVal) {
                    wheelRoot.masterVal = newVal;
                    wheelRoot.updateFromHandle(wheelRoot.handleX, wheelRoot.handleY);
                }
            }
        }
    }
}
