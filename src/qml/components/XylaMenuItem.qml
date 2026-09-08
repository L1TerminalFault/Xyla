import QtQuick
import QtQuick.Controls
import QtQuick.Effects

MenuItem {
    id: control

    implicitHeight: 32
    implicitWidth: Math.max(160, 16 + titleText.implicitWidth + (isSubmenuTrigger ? 20 : shortcutRow.implicitWidth) + 40)

    property string descriptionText: ""
    property string itemIcon: ""
    property string itemShortcut: ""
    property bool itemIsSubmenu: false

    readonly property bool isSubmenuTrigger: control.subMenu !== null || control.itemIsSubmenu

    function resolvedText(): string {
        if (control.action && control.action.text)
            return control.action.text;
        if (control.subMenu && control.subMenu.title)
            return control.subMenu.title;
        return control.text ? control.text : "";
    }

    function resolvedIcon(): string {
        if (control.action && control.action.icon && control.action.icon.source)
            return control.action.icon.source.toString();
        if (control.subMenu) {
            if ("menuIcon" in control.subMenu && control.subMenu.menuIcon)
                return control.subMenu.menuIcon;
            if (control.subMenu.icon && control.subMenu.icon.source)
                return control.subMenu.icon.source.toString();
        }
        return control.itemIcon;
    }

    function resolvedShortcut(): string {
        if (control.action && control.action.shortcut)
            return control.action.shortcut.toString();
        return control.itemShortcut;
    }

    function getModifierIcon(key: string): string {
        var cleanKey = key.trim().toLowerCase();
        if (cleanKey === "ctrl" || cleanKey === "control")
            return "qrc:/assets/icons/command.svg";
        if (cleanKey === "alt")
            return "qrc:/assets/icons/alt.svg";
        if (cleanKey === "shift")
            return "qrc:/assets/icons/shift.svg";
        return "";
    }

    indicator: Item {
        implicitWidth: 0
        implicitHeight: 0
        visible: false
    }

    arrow: Item {
        implicitWidth: control.isSubmenuTrigger ? 14 : 0
        implicitHeight: 14
        visible: control.isSubmenuTrigger
        anchors.right: parent ? parent.right : undefined
        anchors.rightMargin: 10
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Text {
            anchors.centerIn: parent
            text: "›"
            color: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    contentItem: Item {
        implicitHeight: 20

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Item {
                id: iconContainer
                width: 16
                height: 16
                visible: control.resolvedIcon() !== ""
                anchors.verticalCenter: parent.verticalCenter

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
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Row {
            id: shortcutRow
            anchors.right: parent.right
            anchors.rightMargin: control.isSubmenuTrigger ? 16 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: !control.isSubmenuTrigger && control.resolvedShortcut() !== ""

            property var keyTokens: {
                var raw = control.resolvedShortcut();
                return raw !== "" ? raw.split("+") : [];
            }

            Repeater {
                model: shortcutRow.keyTokens

                delegate: Item {
                    id: tokenItem
                    property string keyText: String(modelData).trim()
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
}
