import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: control

    // Array of option objects e.g.: [{ text: "Center", value: 0 }, ...] or strings ["A", "B"]
    property var options: []
    property int currentIndex: 0
    readonly property var currentValue: (options && options.length > currentIndex && currentIndex >= 0) ? ((options[currentIndex].value !== undefined) ? options[currentIndex].value : options[currentIndex]) : null

    signal optionSelected(int index, var value)

    property int itemPadding: 2
    property color indicatorColor: "#11389F"
    property color backgroundColor: "#0d0d0d"

    // Computes equal width per segment dynamically when stretched in Layouts
    readonly property real computedItemWidth: (options && options.length > 0) ? (width - (itemPadding * 2)) / options.length : 28

    implicitHeight: 26
    implicitWidth: (computedItemWidth * (options ? options.length : 0)) + (itemPadding * 2)

    // Main Container Frame
    Rectangle {
        anchors.fill: parent
        color: control.backgroundColor
        radius: 6

        // Apple-Style Sliding Indicator Pill
        Rectangle {
            id: indicator
            width: Math.max(0, control.computedItemWidth)
            height: Math.max(0, parent.height - (control.itemPadding * 2))
            y: control.itemPadding
            radius: 5
            color: control.indicatorColor

            x: control.itemPadding + (control.currentIndex * control.computedItemWidth)

            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutQuint
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
                    width: control.computedItemWidth
                    height: parent.height

                    property var itemData: (modelData !== undefined && modelData !== null) ? modelData : {}
                    property string optText: typeof modelData === "string" ? modelData : (itemData.text ? itemData.text : "")
                    property string optIcon: itemData.icon ? itemData.icon : ""
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

                    // Text label
                    Text {
                        anchors.centerIn: parent
                        visible: optionItem.optText.length > 0
                        text: optionItem.optText
                        color: optionItem.isSelected ? "#ffffff" : (optionItem.isHovered ? "#ffffff" : "#888888")
                        font.pixelSize: 11
                        font.bold: optionItem.isSelected
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    // Optional Icon with MultiEffect
                    Item {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: optionItem.optIcon.length > 0 && optionItem.optText.length === 0

                        Image {
                            id: iconImg
                            anchors.fill: parent
                            source: optionItem.optIcon
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
