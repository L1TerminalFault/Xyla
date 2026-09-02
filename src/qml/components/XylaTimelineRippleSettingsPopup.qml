import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: control

    width: 260
    padding: 12
    clip: false

    property var timelineModel: null

    background: Rectangle {
        anchors.fill: parent
        color: "#181818"
        border.color: "#282828"
        border.width: 1
        radius: 12

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.65
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 0.95
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 1.0
            to: 0.95
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Ripple Mode Scope"
                color: "#888888"
                font.pixelSize: 11
            }

            Rectangle {
                id: categoryContainer
                Layout.fillWidth: true
                height: 32
                color: "#181818"
                border.color: "#2d2d2d"
                border.width: 1
                radius: 6

                readonly property var categories: ["Single-Track", "Global Multi-Track"]
                property Item activeTargetItem: null

                Rectangle {
                    id: categoryIndicator
                    height: parent.height - 4
                    y: 2
                    radius: 4
                    color: "#11389F"
                    border.color: "#2555D3"
                    border.width: 1

                    x: categoryContainer.activeTargetItem ? categoryContainer.activeTargetItem.x + 2 : 2
                    width: categoryContainer.activeTargetItem ? categoryContainer.activeTargetItem.width : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Row {
                    id: categoryRow
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 0

                    Repeater {
                        model: categoryContainer.categories

                        Item {
                            id: pillRoot
                            height: categoryContainer.height - 4
                            width: (categoryContainer.width - 4) / 2

                            readonly property bool isSelected: {
                                var isGlobal = control.timelineModel ? control.timelineModel.globalRippleMode : false;
                                return (index === 1) === isGlobal;
                            }

                            onIsSelectedChanged: {
                                if (isSelected)
                                    categoryContainer.activeTargetItem = pillRoot;
                            }
                            Component.onCompleted: {
                                if (isSelected)
                                    categoryContainer.activeTargetItem = pillRoot;
                            }

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: modelData
                                color: pillRoot.isSelected ? "#ffffff" : (pillMouse.containsMouse ? "#ffffff" : "#a1a1aa")
                                font.pixelSize: 11
                                font.weight: pillRoot.isSelected ? Font.DemiBold : Font.Normal

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (control.timelineModel) {
                                        control.timelineModel.globalRippleMode = (index === 1);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
