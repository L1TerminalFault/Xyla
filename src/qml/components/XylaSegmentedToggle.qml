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

readonly property real maxContentWidth: {
    var maxW = itemWidth;
    if (!options) return maxW;
    for (var i = 0; i < options.length; i++) {
        var opt = options[i];
        var txt = typeof opt === "string" ? opt : (opt && opt.text ? opt.text : "");
        var hasIcn = opt && opt.icon ? true : false;
        if (txt.length > 0) {
            var w = (txt.length * 7) + (hasIcn ? 32 : 16);
            if (w > maxW) maxW = w;
        }
    }
    return maxW;
}

readonly property real computedItemWidth: (options && options.length > 0) 
    ? (width > 0 ? (width - (itemPadding * 2)) / options.length : maxContentWidth) 
    : itemWidth

implicitHeight: 32
implicitWidth: (maxContentWidth * (options ? options.length : 0)) + (itemPadding * 2)

    // Main Container Frame
    Rectangle {
        anchors.fill: parent
        color: "#0d0d0d"
        // border.color: "#2d2d2d"
        // border.width: 1
        radius: 7

        // Apple-Style Sliding Indicator Pill
        Rectangle {
            id: indicator
            width: control.computedItemWidth
            height: parent.height - (control.itemPadding * 2)
            y: control.itemPadding
            radius: 6

                        color: "#11389F"
                        // border.color: "#2555D3"
                        // border.width: 1

            x: control.itemPadding + (control.currentIndex * control.computedItemWidth)


            // Animated Position Calculation
            // x: control.itemPadding + (control.currentIndex * control.itemWidth)

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
    width: control.computedItemWidth
    height: parent.height
    // ...

                    property var itemData: (modelData !== undefined && modelData !== null) ? modelData : {}
                    property bool isSelected: index === control.currentIndex
                    property bool isHovered: mouseArea.containsMouse
                    property string optText: typeof modelData === "string" ? modelData : (itemData && itemData.text ? itemData.text : "")
                    property string optIcon: itemData && itemData.icon ? itemData.icon : ""
                    property bool hasText: optText.length > 0
                    property bool hasIcon: optIcon.length > 0

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
// Content Container (Icon, Text, or Both in a Row)
Row {
    anchors.centerIn: parent
    spacing: 4

    // Icon Rendering
    Item {
        id: iconBtn
        width: 16
        height: 16
        visible: optionItem.hasIcon

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

    // Text Rendering
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: optionItem.hasText
        text: optionItem.optText
        color: optionItem.isSelected ? "#ffffff" : (optionItem.isHovered ? "#ffffff" : "#888888")
        font.pixelSize: 11
        // font.bold: optionItem.isSelected
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}
                    // Item {
                    //     id: iconBtn
                    //     anchors.centerIn: parent
                    //     width: 16
                    //     height: 16
                    //
                    //     Image {
                    //         id: iconImg
                    //         anchors.fill: parent
                    //         source: optionItem.itemData.icon ? optionItem.itemData.icon : ""
                    //         fillMode: Image.PreserveAspectFit
                    //         smooth: true
                    //         visible: false
                    //     }
                    //
                    //     MultiEffect {
                    //         source: iconImg
                    //         anchors.fill: iconImg
                    //         colorization: 1.0
                    //         colorizationColor: optionItem.isSelected ? "#ffffff" : (optionItem.isHovered ? "#ffffff" : "#888888")
                    //
                    //         Behavior on colorizationColor {
                    //             ColorAnimation {
                    //                 duration: 120
                    //             }
                    //         }
                    //     }
                    // }
                }
            }
        }
    }
}
 
