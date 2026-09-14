import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: popupRoot

    property bool rulersEnabled: false
    property bool guidesEnabled: true
    property bool guidesLocked: false
    property int guideCount: 0

    signal rulersToggled(bool enabled)
    signal guidesToggled(bool enabled)
    signal guidesLockedToggled(bool locked)
    signal clearAllGuidesRequested

    width: 220
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
            text: "Rulers & Guides"
            color: "#888888"
            font.pixelSize: 10
            font.bold: true
        }

        XylaCheckBox {
            text: "Show Rulers"
            checked: popupRoot.rulersEnabled
            onToggled: function (val) {
                popupRoot.rulersToggled(val);
            }
        }

        XylaCheckBox {
            text: "Show Guides"
            checked: popupRoot.guidesEnabled
            onToggled: function (val) {
                popupRoot.guidesToggled(val);
            }
        }

        XylaCheckBox {
            text: "Lock Guides"
            checked: popupRoot.guidesLocked
            enabled: popupRoot.guidesEnabled
            opacity: enabled ? 1.0 : 0.4
            onToggled: function (val) {
                popupRoot.guidesLockedToggled(val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#26262a"
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: popupRoot.guideCount + " guides active"
                color: "#666666"
                font.pixelSize: 11
            }

            Item {
                Layout.fillWidth: true
            }

            XylaIconButton {
                implicitWidth: 26
                implicitHeight: 26
                iconWidth: 13
                iconHeight: 13
                ghost: true
                enabled: popupRoot.guideCount > 0 && !popupRoot.guidesLocked
                opacity: enabled ? 1.0 : 0.4
                iconSource: "qrc:/assets/icons/trash.svg"
                tooltip: "Clear All Guides"
                onClicked: popupRoot.clearAllGuidesRequested()
            }
        }
    }
}
