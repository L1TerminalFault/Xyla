import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

ComboBox {
    id: control

    property string icon: ""
    property color backgroundColor: "transparent"
    property color highlightedColor: "#262626"
    property string tooltip: ""
    property color borderColor: "#2d2d2d"

    implicitHeight: 32
    implicitWidth: 140

    focus: false
    activeFocusOnTab: true

    onPressedChanged: {
        if (pressed) {
            control.focus = true;
        }
    }

    XylaToolTip {
        visible: control.tooltip.length && control.hovered && fileSystemModel.fileManagerSettings.showTooltips
        text: control.tooltip
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            if (control.popup.visible) {
                control.popup.close();
                event.accepted = true;
            }
        }
    }

    // Selected Item Display Text
    contentItem: RowLayout {
        spacing: 6

        Item {
            Layout.preferredWidth: 2
        }

        Image {
            id: iconImage
            visible: control.icon !== ""
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            source: control.icon
            sourceSize.width: 16
            sourceSize.height: 16
        }

        Text {
            Layout.fillWidth: true
            text: control.displayText
            font.pixelSize: 12
            color: "#ffffff"
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Item {
            Layout.preferredWidth: 18
        }
    }

    // Rotating Chevron Indicator
    indicator: Item {
        x: control.width - width - 8
        y: (control.height - height) / 2
        width: 10
        height: 10

        Item {
            id: chevronContainer
            anchors.fill: parent
            rotation: control.popup.opened ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                id: chevronIcon
                anchors.fill: parent
                source: "qrc:/assets/icons/chevron-down.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
            }

            MultiEffect {
                source: chevronIcon
                anchors.fill: chevronIcon
                colorization: 1.0
                colorizationColor: control.hovered || control.popup.opened ? "#ffffff" : "#888888"

                Behavior on colorizationColor {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }
    }

    // Input Box Background (Transparent with subtle #2d2d2d border)
    background: Rectangle {
        color: "transparent"
        border.color: control.borderColor
        border.width: 1
        radius: 7
    }

    // Animated Dropdown Popup
    popup: Popup {
        id: dropdownPopup
        x: 0
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2, 200)
        padding: 1

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: control.focus = false
        transformOrigin: Popup.Top

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

        contentItem: Item {
            id: contentContainer
            implicitHeight: listView.implicitHeight

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null

                ScrollIndicator.vertical: ScrollIndicator {
                    id: scrollIndicator
                    visible: listView.contentHeight > listView.height
                    active: true

                    contentItem: Rectangle {
                        implicitWidth: 4
                        implicitHeight: 100
                        radius: 2
                        color: scrollIndicator.pressed || scrollIndicator.hovered ? "#ffffff" : (scrollIndicator.active ? "#66ffffff" : "#33ffffff")

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    background: null
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: contentContainer.width
                        height: contentContainer.height
                        radius: 7
                    }
                }
            }
        }

        // Dropdown Background
        background: Rectangle {
            anchors.fill: parent
            color: "#191919"
            border.color: "#2d2d2d"
            border.width: 1
            radius: 7

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }
        }
    }

    // Popup Item Delegate (Neutral dark highlight)
    delegate: ItemDelegate {
        id: itemDelegate
        width: control.width
        height: 32

        contentItem: Text {
            text: modelData
            color: (itemDelegate.highlighted || itemDelegate.hovered) ? "#ffffff" : "#d0d0d0"
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            leftPadding: 8
        }

        background: Rectangle {
            color: (itemDelegate.highlighted || itemDelegate.hovered) ? control.highlightedColor : "#191919"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }
    }
}
