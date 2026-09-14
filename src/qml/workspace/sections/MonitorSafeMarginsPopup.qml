import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: popupRoot

    property bool actionSafeEnabled: false
    property bool titleSafeEnabled: false
    property real actionSafePercent: 90.0
    property real titleSafePercent: 80.0

    signal actionSafeToggled(bool enabled)
    signal titleSafeToggled(bool enabled)
    signal actionPercentChanged(real percent)
    signal titlePercentChanged(real percent)

    width: 236
    padding: 12
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: "#181818"
        border.color: "#303030"
        border.width: 1
        radius: 8

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.65
            shadowVerticalOffset: 6
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            text: "Safe Margins"
            color: "#888888"
            font.pixelSize: 10
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            XylaCheckBox {
                id: actionCheck
                text: "Action Safe"
                checked: popupRoot.actionSafeEnabled
                onToggled: function (val) {
                    popupRoot.actionSafeToggled(val);
                }
            }

            Item {
                Layout.fillWidth: true
            }

            XylaFloatInput {
                enabled: actionCheck.checked
                opacity: actionCheck.checked ? 1.0 : 0.4
                value: popupRoot.actionSafePercent
                minValue: 50.0
                maxValue: 99.0
                stepSize: 1.0
                decimals: 0
                unit: "%"
                implicitWidth: 68
                implicitHeight: 22
                onValueCommitted: function (v) {
                    popupRoot.actionPercentChanged(v);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            XylaCheckBox {
                id: titleCheck
                text: "Title Safe"
                checked: popupRoot.titleSafeEnabled
                onToggled: function (val) {
                    popupRoot.titleSafeToggled(val);
                }
            }

            Item {
                Layout.fillWidth: true
            }

            XylaFloatInput {
                enabled: titleCheck.checked
                opacity: titleCheck.checked ? 1.0 : 0.4
                value: popupRoot.titleSafePercent
                minValue: 40.0
                maxValue: 95.0
                stepSize: 1.0
                decimals: 0
                unit: "%"
                implicitWidth: 68
                implicitHeight: 22
                onValueCommitted: function (v) {
                    popupRoot.titlePercentChanged(v);
                }
            }
        }
    }
}
