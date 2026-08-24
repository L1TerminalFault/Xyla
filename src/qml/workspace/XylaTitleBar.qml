import QtQuick 2.15
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TitleBarBase {
    id: root

    implicitHeight: 36
    heightWhenVisible: 36

    Rectangle {
        anchors.fill: parent
        color: "#191919"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#2d2d2d"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 4

            Rectangle {
                height: parent.height
                implicitWidth: singleTitleText.implicitWidth + 24
                color: root.isFocused ? "#252526" : "#0d0d0d"
                border.color: "#2d2d2d"
                border.width: 1
                radius: 5 // 5px tab radius

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
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                id: floatBtn
                visible: root.floatButtonVisible
                width: 22
                height: 22
                radius: 4
                color: floatArea.containsMouse ? "#2d2d2d" : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "❐"
                    color: floatArea.containsMouse ? "#ffffff" : "#888888"
                    font.pixelSize: 10
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
                radius: 4
                color: closeArea.containsMouse ? "#e81123" : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.containsMouse ? "#ffffff" : "#888888"
                    font.pixelSize: 10
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
