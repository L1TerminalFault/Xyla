import QtQuick
import QtQuick.Controls

Item {
    id: root

    property real value: 0.0
    property real stepSize: 0.01
    property real minValue: -999999.0
    property real maxValue: 999999.0
    property int decimals: 2
    property string label: ""

    signal valueCommitted(real newValue)

    implicitWidth: 64
    implicitHeight: 20

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: dragArea.containsMouse || inputField.activeFocus ? "#1f1f24" : "#121215"
        border.color: inputField.activeFocus ? "#3B82F6" : (dragArea.containsMouse ? "#3f3f4a" : "#28282e")
        border.width: 1
        radius: 3

        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 2

            Text {
                id: labelText
                text: root.label
                color: "#777780"
                font.pixelSize: 10
                font.bold: true
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: inputField
                width: parent.width - (labelText.visible ? labelText.width + 6 : 0)
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: "#ffffff"
                font.pixelSize: 10
                font.family: "Monospace"
                selectByMouse: true
                text: root.value.toFixed(root.decimals)

                onEditingFinished: {
                    var parsed = parseFloat(text);
                    if (!isNaN(parsed)) {
                        var clamped = Math.max(root.minValue, Math.min(root.maxValue, parsed));
                        root.value = clamped;
                        root.valueCommitted(clamped);
                    }
                    text = root.value.toFixed(root.decimals);
                    focus = false;
                }
            }
        }

        // Scrubbing Drag Handler (Click & Drag horizontally to alter value)
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            visible: !inputField.activeFocus

            property real startX: 0
            property real startVal: 0

            onDoubleClicked: {
                inputField.forceActiveFocus();
                inputField.selectAll();
            }

            onPressed: function (mouse) {
                startX = mouse.x;
                startVal = root.value;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var delta = (mouse.x - startX) * root.stepSize;
                    var newVal = Math.max(root.minValue, Math.min(root.maxValue, startVal + delta));
                    root.value = newVal;
                    root.valueCommitted(newVal);
                }
            }
        }
    }
}
