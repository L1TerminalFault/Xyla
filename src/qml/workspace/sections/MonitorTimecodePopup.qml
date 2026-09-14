import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: popupRoot

    property bool timecodeEnabled: false
    property string timecodePosition: "bottom-right"

    signal timecodeToggled(bool enabled)
    signal positionChanged(string pos)

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
            text: "Timecode Overlay"
            color: "#888888"
            font.pixelSize: 10
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            XylaCheckBox {
                id: tcCheck
                text: "Show Timecode HUD"
                checked: popupRoot.timecodeEnabled
                onToggled: function (val) {
                    popupRoot.timecodeToggled(val);
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#26262a"
        }

        RowLayout {
            Layout.fillWidth: true
            opacity: tcCheck.checked ? 1.0 : 0.4
            enabled: tcCheck.checked
            spacing: 8

            Text {
                text: "Position"
                color: "#cccccc"
                font.pixelSize: 11
            }

            Item {
                Layout.fillWidth: true
            }

            XylaSelect {
                id: posSelect
                implicitHeight: 24
                implicitWidth: 120
                borderColor: "#28282c"
                backgroundColor: "#141416"

                model: ["Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"]

                currentIndex: {
                    if (popupRoot.timecodePosition === "top-left")
                        return 0;
                    if (popupRoot.timecodePosition === "top-right")
                        return 1;
                    if (popupRoot.timecodePosition === "bottom-left")
                        return 2;
                    return 3;
                }

                onActivated: function (index) {
                    var selected = model[index];
                    var mapped = "bottom-right";
                    if (selected === "Top-Left")
                        mapped = "top-left";
                    else if (selected === "Top-Right")
                        mapped = "top-right";
                    else if (selected === "Bottom-Left")
                        mapped = "bottom-left";
                    else if (selected === "Bottom-Right")
                        mapped = "bottom-right";

                    popupRoot.positionChanged(mapped);
                }
            }
        }
    }
}
