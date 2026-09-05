import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

MenuItem {
    id: control

    implicitHeight: 32
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding

    property string descriptionText: ""
    property string itemIcon: ""
    property string itemShortcut: ""
    property bool itemIsSubmenu: false

    text: (control.action && control.action.text) ? control.action.text : ""

    function resolvedText() {
        if (control.action && control.action.text && control.action.text.toString() !== "")
            return control.action.text.toString();
        return control.text && control.text.toString() !== "" ? control.text.toString() : "";
    }

    function resolvedIcon() {
        if (control.action && control.action.icon && control.action.icon.source)
            return control.action.icon.source.toString();
        return control.itemIcon || "";
    }

    function resolvedShortcut() {
        if (control.action && control.action.shortcut)
            return control.action.shortcut.toString();
        return control.itemShortcut || "";
    }

    XylaToolTip {
        visible: control.hovered && control.descriptionText !== ""
        text: control.descriptionText
        delay: 800
        position: "right"
    }

    function getModifierIcon(key) {
        var cleanKey = key.trim().toLowerCase();
        if (cleanKey === "ctrl" || cleanKey === "control")
            return "qrc:/assets/icons/command.svg";
        if (cleanKey === "alt")
            return "qrc:/assets/icons/alt.svg";
        if (cleanKey === "shift")
            return "qrc:/assets/icons/shift.svg";
        return "";
    }

    Menu {
        id: subMenu
        padding: 8

        background: Rectangle {
            implicitWidth: 230
            implicitHeight: 32
            color: "#181818"
            border.color: "#303030"
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
    }

    contentItem: RowLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 10

        implicitWidth: iconContainer.implicitWidth + titleText.implicitWidth + shortcutRow.implicitWidth + submenuChevron.implicitWidth + (spacing * 3)

        Item {
            id: iconContainer
            implicitWidth: 16
            implicitHeight: 16
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: iconImg
                anchors.fill: parent
                source: control.resolvedIcon()
                sourceSize: Qt.size(16, 16)
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
            }

            MultiEffect {
                anchors.fill: iconImg
                source: iconImg
                visible: control.resolvedIcon() !== ""
                colorization: 1.0
                colorizationColor: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"
            }
        }

        Text {
            id: titleText
            text: control.resolvedText()
            color: control.enabled ? (control.highlighted ? "#ffffff" : "#d0d0d0") : "#555555"
            font.pixelSize: 12
            Layout.minimumWidth: 120
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            id: shortcutRow
            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            visible: control.resolvedShortcut() !== ""

            property var keyTokens: {
                var rawShortcut = control.resolvedShortcut();
                return rawShortcut !== "" ? rawShortcut.split("+") : [];
            }

            Repeater {
                model: shortcutRow.keyTokens

                delegate: Item {
                    id: tokenItem
                    property string keyText: modelData.trim()
                    property string iconSrc: control.getModifierIcon(keyText)
                    property bool isModifier: iconSrc !== ""

                    implicitWidth: isModifier ? 20 : Math.max(20, letterLabel.implicitWidth + 10)
                    implicitHeight: 20

                    Rectangle {
                        anchors.fill: parent
                        color: control.hovered || control.highlighted ? "#353535" : "#141414"
                        radius: 5

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    Image {
                        id: modifierImg
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: tokenItem.iconSrc
                        sourceSize: Qt.size(14, 14)
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: modifierImg
                        source: modifierImg
                        visible: tokenItem.isModifier
                        colorization: 1.0
                        colorizationColor: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"

                        Behavior on colorizationColor {
                            ColorAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        id: letterLabel
                        anchors.centerIn: parent
                        visible: !tokenItem.isModifier
                        text: tokenItem.keyText
                        color: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: submenuChevron
            implicitWidth: control.itemIsSubmenu ? 14 : 0
            implicitHeight: 14
            visible: control.itemIsSubmenu
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "›"
                color: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }

    leftPadding: 10
    rightPadding: 10

    background: Rectangle {
        anchors.fill: parent
        radius: 8

        color: !control.enabled ? "#181818" : control.pressed ? "#303030" : control.highlighted ? "#252525" : "#181818"

        Behavior on color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    opacity: control.enabled ? 1.0 : 0.48

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
}
