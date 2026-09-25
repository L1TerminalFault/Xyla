import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: control

    property string text: ""
    property bool checked: false
    property string tooltip: ""

    signal toggled(bool isChecked)

    implicitHeight: 24
    implicitWidth: rowLayout.implicitWidth

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 8

        Rectangle {
            id: indicator
            implicitWidth: 16
            implicitHeight: 16
            radius: 5
            color: control.checked ? (checkMouse.containsMouse ? "#1645BF" : "#11389F") : (checkMouse.containsMouse ? "#242428" : "#161618")
            border.color: control.checked ? "#1645BF" : (checkMouse.containsMouse ? "#11389F" : "#2d2d32")
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 100
                }
            }

            Image {
                id: checkIcon
                anchors.centerIn: parent
                width: 10
                height: 10
                source: "qrc:/assets/icons/check.svg"
                sourceSize: Qt.size(10, 10)
                visible: control.checked && status === Image.Ready
            }

            // Fallback checkmark if check.svg icon is not found
            Loader {
                anchors.fill: parent
                active: control.checked && checkIcon.status !== Image.Ready
                sourceComponent: Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1.6;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.beginPath();
                        ctx.moveTo(3.5, 8.5);
                        ctx.lineTo(6.5, 11.5);
                        ctx.lineTo(12.5, 4.5);
                        ctx.stroke();
                    }
                }
            }
        }

        Text {
            id: labelText
            text: control.text
            font.pixelSize: 11
            color: control.enabled ? (checkMouse.containsMouse ? "#ffffff" : "#cccccc") : "#555555"
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
        }
    }

    XylaToolTip {
        visible: control.tooltip.length > 0 && checkMouse.containsMouse
        text: control.tooltip
        position: "bottom"
    }

    MouseArea {
        id: checkMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            control.checked = !control.checked;
            control.toggled(control.checked);
        }
    }
}
