import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: control

    property int value: 1
    property int minValue: 1
    property int maxValue: 99
    property int stepSize: 1

    signal valueChangedByUser(int newValue)

    implicitWidth: 120
    implicitHeight: 32

    // Keep text field synchronized whenever value changes externally
    onValueChanged: {
        if (!inputField.activeFocus) {
            inputField.text = control.value.toString();
        }
    }

    // Outer Unified Input Frame
    Rectangle {
        anchors.fill: parent
        color: inputField.activeFocus ? "#1f1f1f" : "#181818"
        border.color: inputField.activeFocus ? "#2555D3" : "#2d2d2d"
        border.width: 1
        radius: 6

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            spacing: 0

            // Embedded Left (-) Ghost Button
            XylaIconButton {
                id: minusBtn
                ghost: true
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                iconWidth: 14
                iconHeight: 14
                iconSource: "qrc:/assets/icons/minus.svg"
                enabled: control.value > control.minValue
                opacity: enabled ? 1.0 : 0.25

                onClicked: {
                    inputField.focus = false;
                    if (control.value > control.minValue) {
                        control.value -= control.stepSize;
                        inputField.text = control.value.toString();
                        control.valueChangedByUser(control.value);
                    }
                }
            }

            // Center Editable TextField
            TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: control.value.toString()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
                selectByMouse: true
                validator: IntValidator {
                    bottom: control.minValue
                    top: control.maxValue
                }

                background: null // Transparent inside container

                onEditingFinished: {
                    var val = parseInt(text);
                    if (isNaN(val) || val < control.minValue)
                        val = control.minValue;
                    if (val > control.maxValue)
                        val = control.maxValue;

                    control.value = val;

                    // Restore QML binding so [+] and [-] buttons continue to work!
                    text = Qt.binding(function () {
                        return control.value.toString();
                    });

                    control.valueChangedByUser(val);
                }
            }

            // Embedded Right (+) Ghost Button
            XylaIconButton {
                id: plusBtn
                ghost: true
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                iconWidth: 14
                iconHeight: 14
                iconSource: "qrc:/assets/icons/plus.svg"
                enabled: control.value < control.maxValue
                opacity: enabled ? 1.0 : 0.25

                onClicked: {
                    inputField.focus = false;
                    if (control.value < control.maxValue) {
                        control.value += control.stepSize;
                        inputField.text = control.value.toString();
                        control.valueChangedByUser(control.value);
                    }
                }
            }
        }
    }
}
