import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: popupRoot

    property bool gridEnabled: false
    property int gridRows: 3
    property int gridColumns: 3
    property real gridOpacity: 0.35
    property color gridColor: "#ffffff"

    signal gridToggled(bool enabled)
    signal rowsModified(int rows)
    signal columnsModified(int cols)
    signal opacityModified(real opacityVal)
    signal colorSelected(color c)

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
            text: "Alignment Grid"
            color: "#888888"
            font.pixelSize: 10
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            XylaCheckBox {
                id: gridCheck
                text: "Show Grid"
                checked: popupRoot.gridEnabled
                onToggled: function (val) {
                    popupRoot.gridToggled(val);
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
            opacity: gridCheck.checked ? 1.0 : 0.4
            enabled: gridCheck.checked
            spacing: 6

            Text {
                text: "Rows"
                color: "#cccccc"
                font.pixelSize: 11
                Layout.preferredWidth: 32
            }

            XylaFloatInput {
                value: popupRoot.gridRows
                minValue: 2
                maxValue: 32
                stepSize: 1
                decimals: 0
                implicitWidth: 54
                implicitHeight: 22
                onValueCommitted: function (v) {
                    popupRoot.rowsModified(Math.round(v));
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "Cols"
                color: "#cccccc"
                font.pixelSize: 11
                Layout.preferredWidth: 32
            }

            XylaFloatInput {
                value: popupRoot.gridColumns
                minValue: 2
                maxValue: 32
                stepSize: 1
                decimals: 0
                implicitWidth: 54
                implicitHeight: 22
                onValueCommitted: function (v) {
                    popupRoot.columnsModified(Math.round(v));
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            opacity: gridCheck.checked ? 1.0 : 0.4
            enabled: gridCheck.checked
            spacing: 6

            Text {
                text: "Opacity"
                color: "#cccccc"
                font.pixelSize: 11
            }

            XylaFloatInput {
                value: Math.round(popupRoot.gridOpacity * 100)
                minValue: 5
                maxValue: 100
                stepSize: 5
                decimals: 0
                unit: "%"
                implicitWidth: 58
                implicitHeight: 22
                onValueCommitted: function (v) {
                    popupRoot.opacityModified(v / 100.0);
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: 4
                readonly property var colors: ["#ffffff", "#00e5ff", "#facc15", "#ef4444"]

                Repeater {
                    model: parent.colors
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 3
                        color: modelData
                        border.color: popupRoot.gridColor === modelData ? "#3b82f6" : "#404048"
                        border.width: popupRoot.gridColor === modelData ? 2 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupRoot.colorSelected(modelData)
                        }
                    }
                }
            }
        }
    }
}
