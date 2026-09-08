import QtQuick
import Qt5Compat.GraphicalEffects
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TitleBarBase {
    id: root

    implicitHeight: 36
    heightWhenVisible: 36
    color: "#0E0E0E"

// Find enclosing XylaGroup or DockWidget
    readonly property Item parentGroup: {
        var p = parent
        while (p) {
            if (p.hasOwnProperty("hasTopSibling")) return p
            p = p.parent
        }
        return null
    }

    readonly property bool hasTopSibling: parentGroup ? parentGroup.hasTopSibling : false
    readonly property bool hasLeftSibling: parentGroup ? parentGroup.hasLeftSibling : false
    readonly property bool hasRightSibling: parentGroup ? parentGroup.hasRightSibling : false
    // readonly property bool isFloating: parentGroup ? parentGroup.isFloating : false
    readonly property bool isFloating: Boolean(parentGroup && parentGroup.isFloating)

    Rectangle {
        anchors.fill: parent
        color: "#191919"

        readonly property int cornerRadius: 10

        topLeftRadius: ( /* root.isFloating || */ (!root.hasTopSibling && !root.hasLeftSibling)) ? cornerRadius : 0
        topRightRadius: ( /* root.isFloating || */ (!root.hasTopSibling && !root.hasRightSibling)) ? cornerRadius : 0
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#191919"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 4

            Rectangle {
                height: parent.height
                implicitWidth: singleTitleText.implicitWidth + 24
                color: root.isFocused ? "#252526" : "#0d0d0d"
                // border.color: "#2d2d2d"
                // border.width: 1
                radius: 8 // 5px tab radius

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    id: singleTitleText
                    anchors.centerIn: parent
                    text: root.title
                    color: root.isFocused ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    font.weight: Font.Medium

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                id: floatBtn
                visible: root.floatButtonVisible
                width: 22
                height: 22
                radius: 6
                color: floatArea.containsMouse ? "#2d2d2d" : "#191919"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Image {
                    id: floatIcon
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    source: "qrc:/assets/icons/maximize.svg" // Adjust path if using relative filesystem path e.g. "assets/icons/maximize.svg"
                    fillMode: Image.PreserveAspectFit

                    property color iconColor: floatArea.containsMouse ? "#ffffff" : "#888888"

                    Behavior on iconColor {
                        ColorAnimation { duration: 150 }
                    }

                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: floatIcon.iconColor
                    }
                }

                MouseArea {
                    id: floatArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.floatButtonClicked()
                }
            }

            Rectangle {
                id: closeBtn
                enabled: root.closeButtonEnabled
                visible: root.closeButtonEnabled
                width: 22
                height: 22
                radius: 6
                color: closeArea.containsMouse ? "#2D2D2D" /* "#e81123" */ : "#191919"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Image {
                    id: floatIcon_
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    source: "qrc:/assets/icons/x.svg" // Adjust path if using relative filesystem path e.g. "assets/icons/maximize.svg"
                    fillMode: Image.PreserveAspectFit

                    property color iconColor: closeArea.containsMouse ? "#e81123" : "#df8888"

                    Behavior on iconColor {
                        ColorAnimation { duration: 150 }
                    }

                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: floatIcon_.iconColor
                    }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeButtonClicked()
                }
            }
        }
    }
}
