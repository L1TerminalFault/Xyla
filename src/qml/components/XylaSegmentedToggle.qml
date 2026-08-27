import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: control

    // Array of option objects e.g.: [{ icon: "qrc:/assets/icons/list.svg", value: "list" }, ...]
    property var options: []
    property int currentIndex: 0
    readonly property var currentValue: (options && options.length > currentIndex && currentIndex >= 0) ? (options[currentIndex].value !== undefined ? options[currentIndex].value : options[currentIndex]) : null

    signal optionSelected(int index, var value)

    property int itemWidth: 28
    property int itemPadding: 2

    implicitHeight: 32
    implicitWidth: (itemWidth * (options ? options.length : 0)) + (itemPadding * 2)

    // Main Container Frame
    Rectangle {
        anchors.fill: parent
        color: "#181818"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 6

        // Apple-Style Sliding Indicator Pill
        Rectangle {
            id: indicator
            width: control.itemWidth
            height: parent.height - (control.itemPadding * 2)
            y: control.itemPadding
            radius: 5

            color: "#11389F"
            border.color: "#2555D3"
            border.width: 1

            // Animated Position Calculation
            x: control.itemPadding + (control.currentIndex * control.itemWidth)

            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutQuint // Apple-style fluid deceleration curve
                }
            }
        }

        // Clickable Option Elements
        Row {
            anchors.fill: parent
            anchors.margins: control.itemPadding

            Repeater {
                model: control.options

                Item {
                    id: optionItem
                    width: control.itemWidth
                    height: parent.height

                    property var itemData: (modelData !== undefined && modelData !== null) ? modelData : {}
                    property bool isSelected: index === control.currentIndex
                    property bool isHovered: mouseArea.containsMouse

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            control.currentIndex = index;
                            control.optionSelected(index, control.currentValue);
                        }
                    }

                    XylaToolTip {
                        parent: optionItem
                        visible: optionItem.isHovered && fileSystemModel.fileManagerSettings.showTooltips && (optionItem.itemData.tooltip !== undefined && optionItem.itemData.tooltip !== "")
                        text: optionItem.itemData.tooltip !== undefined ? optionItem.itemData.tooltip : ""
                    }

                    // Icon Rendering with MultiEffect
                    Item {
                        id: iconBtn
                        anchors.centerIn: parent
                        width: 16
                        height: 16

                        Image {
                            id: iconImg
                            anchors.fill: parent
                            source: optionItem.itemData.icon ? optionItem.itemData.icon : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            source: iconImg
                            anchors.fill: iconImg
                            colorization: 1.0
                            colorizationColor: optionItem.isSelected ? "#ffffff" : (optionItem.isHovered ? "#ffffff" : "#888888")

                            Behavior on colorizationColor {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
