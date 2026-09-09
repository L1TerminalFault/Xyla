import QtQuick
import QtQuick.Controls
import QtQuick.Window

Item {
    id: root

    property real value: 0.0
    property real stepSize: 0.01
    property real minValue: -999999.0
    property real maxValue: 999999.0
    property int decimals: 2
    property string label: ""
    property string unit: ""
    property color accentColor: "transparent"

    property bool keyframeable: false
    property bool hasKeyframe: false
    signal keyframeToggled

    property var warpCursor: null
    signal valueCommitted(real newValue)

    implicitWidth: 64
    implicitHeight: 24

    // Live preview during active drag
    property real liveDragValue: root.value
    property bool isDragging: dragArea.dragging

    function clamp(v) {
        return Math.max(root.minValue, Math.min(root.maxValue, v));
    }

    function setValue(v, commit) {
        var clamped = clamp(v);
        liveDragValue = clamped;
        if (commit) {
            root.valueCommitted(clamped);
        }
    }

    function globalXFromMouse(mouse) {
        if (mouse.globalPosition !== undefined && mouse.globalPosition !== null)
            return mouse.globalPosition.x;
        return mapToGlobal(mouse.x, mouse.y).x;
    }

    function globalYFromMouse(mouse) {
        if (mouse.globalPosition !== undefined && mouse.globalPosition !== null)
            return mouse.globalPosition.y;
        return mapToGlobal(mouse.x, mouse.y).y;
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: dragArea.containsMouse || inputField.activeFocus ? "#1f1f24" : "#121215"
        border.color: inputField.activeFocus ? "#3B82F6" : (dragArea.containsMouse || dragArea.pressed ? "#3f3f4a" : "#28282e")
        border.width: 1
        radius: 3
        clip: true

        Rectangle {
            id: leftAccent
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: Math.max(6, parent.height - 8)
            radius: 1.5
            color: root.accentColor
            visible: root.accentColor !== "transparent" && root.accentColor !== "#00000000"
            z: 2
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: leftAccent.visible ? 10 : 6
            anchors.rightMargin: root.keyframeable ? 20 : 6
            spacing: 4

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
                width: parent.width - (labelText.visible ? labelText.width + 4 : 0) - (unitText.visible ? unitText.width + 4 : 0)
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: "#ffffff"
                font.pixelSize: 10
                font.family: "Monospace"
                selectByMouse: true

                // Displays liveDragValue while dragging, or root.value during playback
                Binding on text {
                    when: !inputField.activeFocus
                    value: (root.isDragging ? root.liveDragValue : root.value).toFixed(root.decimals)
                }

                onAccepted: {
                    commitManualText();
                    focus = false;
                }
                onEditingFinished: {
                    commitManualText();
                    focus = false;
                }

                function commitManualText() {
                    var parsed = parseFloat(text);
                    if (!isNaN(parsed))
                        root.setValue(parsed, true);
                }
            }

            Text {
                id: unitText
                text: root.unit
                color: "#666670"
                font.pixelSize: 9
                font.family: "Monospace"
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: dragArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: root.keyframeable ? 20 : 0
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            visible: !inputField.activeFocus
            z: 1

            property real lastGlobalX: 0
            property bool dragging: false

            onDoubleClicked: {
                inputField.forceActiveFocus();
                inputField.selectAll();
            }

            onPressed: function (mouse) {
                lastGlobalX = root.globalXFromMouse(mouse);
                root.liveDragValue = root.value;
                dragging = true;
            }

            onReleased: function (mouse) {
                dragging = false;
                root.valueCommitted(root.liveDragValue);
            }

            onCanceled: {
                dragging = false;
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !dragging)
                    return;
                var currentGlobalX = root.globalXFromMouse(mouse);
                var deltaX = currentGlobalX - lastGlobalX;

                root.setValue(root.liveDragValue + deltaX * root.stepSize, true);

                if (typeof root.warpCursor === "function") {
                    var screenW = Screen.width;
                    var margin = 2;
                    var newX = currentGlobalX;
                    var warped = false;

                    if (currentGlobalX <= margin) {
                        newX = screenW - margin - 1;
                        warped = true;
                    } else if (currentGlobalX >= screenW - margin) {
                        newX = margin + 1;
                        warped = true;
                    }

                    if (warped) {
                        root.warpCursor(newX, root.globalYFromMouse(mouse));
                        lastGlobalX = newX;
                        return;
                    }
                }

                lastGlobalX = currentGlobalX;
            }

            onWheel: function (wheel) {
                var steps = wheel.angleDelta.y / 120;
                if (steps === 0 && wheel.pixelDelta.y !== 0)
                    steps = wheel.pixelDelta.y > 0 ? 1 : -1;

                if (steps !== 0) {
                    root.setValue(root.value + steps * root.stepSize, true);
                    wheel.accepted = true;
                }
            }
        }

        Item {
            id: kfContainer
            visible: root.keyframeable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 20
            z: 10

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                rotation: 45
                color: root.hasKeyframe ? "#3B82F6" : (kfMouse.containsMouse ? "#4f4f60" : "transparent")
                border.color: root.hasKeyframe ? "#60A5FA" : (kfMouse.containsMouse ? "#888899" : "#444455")
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }

            MouseArea {
                id: kfMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keyframeToggled()
            }
        }
    }
}
