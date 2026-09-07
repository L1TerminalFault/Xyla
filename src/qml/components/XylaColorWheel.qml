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
    implicitHeight: 220

    function setColor(r, g, b, master) {
        redVal = r;
        greenVal = g;
        blueVal = b;
        masterVal = master;
        updateFromManualRGB();
    }

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
        var angle = Math.atan2(ny, nx); // [-PI, PI]

        // 3-Phase Color Projection (Red: +90 deg, Green: 210 deg, Blue: 330 deg)
        var rDelta = rad * Math.sin(angle);
        var gDelta = rad * Math.sin(angle + (2.0 * Math.PI / 3.0));
        var bDelta = rad * Math.sin(angle + (4.0 * Math.PI / 3.0));

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
            // Un-inverted Hue alignment matching ring canvas:
            var normHue = (Math.PI / 2 - angle) / (2.0 * Math.PI);
            while (normHue < 0.0)
                normHue += 1.0;
            while (normHue >= 1.0)
                normHue -= 1.0;
            pinFillColor = Qt.hsla(normHue, Math.min(1.0, rad * 1.2), 0.5, 1.0);
        }

        wheelRoot.colorChanged(redVal, greenVal, blueVal, masterVal);
    }

    function updateFromManualRGB() {
        var rDiff = redVal - defaultBase - masterVal;
        var gDiff = greenVal - defaultBase - masterVal;
        var bDiff = blueVal - defaultBase - masterVal;

        // Inverse 3-phase projection
        var ny = (2.0 * rDiff - gDiff - bDiff) / (3.0 * sensitivity);
        var nx = (gDiff - bDiff) / (Math.sqrt(3.0) * sensitivity);

        var len = Math.sqrt(nx * nx + ny * ny);
        if (len > 1.0) {
            nx /= len;
            ny /= len;
        }
        handleX = nx;
        handleY = ny;

        if (len < 0.02) {
            pinFillColor = "#ffffff";
        } else {
            var angle = Math.atan2(ny, nx);
            var normHue = (Math.PI / 2 - angle) / (2.0 * Math.PI);
            while (normHue < 0.0)
                normHue += 1.0;
            while (normHue >= 1.0)
                normHue -= 1.0;
            pinFillColor = Qt.hsla(normHue, Math.min(1.0, len * 1.2), 0.5, 1.0);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 2

            Text {
                text: wheelRoot.title
                color: "#cccccc"
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

        Rectangle {
            id: wheelCircle
            readonly property real wheelDim: Math.max(90, Math.min(parent.width - 8, parent.height - 75))
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

                    var segments = 72;
                    for (var i = 0; i < segments; i++) {
                        // Starts at top center (Red) and sweeps clockwise
                        var startAngle = (i / segments) * 2.0 * Math.PI - (Math.PI / 2.0);
                        var endAngle = ((i + 1.2) / segments) * 2.0 * Math.PI - (Math.PI / 2.0);
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
                    grad.addColorStop(1.0, "rgba(18, 18, 18, 0.7)");
                    ctx.fillStyle = grad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, innerR, 0, 2 * Math.PI);
                    ctx.fill();

                    // Center Crosshairs
                    ctx.strokeStyle = "#25252d";
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

                onPressed: mouse => handleMouse(mouse)
                onPositionChanged: mouse => {
                    if (pressed)
                        handleMouse(mouse);
                }
                onDoubleClicked: wheelRoot.resetAll()
            }
        }

        ColumnLayout {
            Layout.preferredWidth: Math.max(110, wheelCircle.width)
            Layout.alignment: Qt.AlignHCenter
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.redVal
                    accentColor: "#EF4444"
                    stepSize: 0.02
                    onValueCommitted: newVal => {
                        wheelRoot.redVal = newVal;
                        wheelRoot.updateFromManualRGB();
                        wheelRoot.colorChanged(wheelRoot.redVal, wheelRoot.greenVal, wheelRoot.blueVal, wheelRoot.masterVal);
                    }
                }

                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.greenVal
                    accentColor: "#22C55E"
                    stepSize: 0.02
                    onValueCommitted: newVal => {
                        wheelRoot.greenVal = newVal;
                        wheelRoot.updateFromManualRGB();
                        wheelRoot.colorChanged(wheelRoot.redVal, wheelRoot.greenVal, wheelRoot.blueVal, wheelRoot.masterVal);
                    }
                }

                XylaFloatInput {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    value: wheelRoot.blueVal
                    accentColor: "#3B82F6"
                    stepSize: 0.02
                    onValueCommitted: newVal => {
                        wheelRoot.blueVal = newVal;
                        wheelRoot.updateFromManualRGB();
                        wheelRoot.colorChanged(wheelRoot.redVal, wheelRoot.greenVal, wheelRoot.blueVal, wheelRoot.masterVal);
                    }
                }
            }

            XylaFloatInput {
                label: "Master"
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                value: wheelRoot.masterVal
                stepSize: 0.02
                onValueCommitted: newVal => {
                    wheelRoot.masterVal = newVal;
                    wheelRoot.updateFromHandle(wheelRoot.handleX, wheelRoot.handleY);
                }
            }
        }
    }
}
