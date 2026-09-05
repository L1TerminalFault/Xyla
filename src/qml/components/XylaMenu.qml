import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../components"

Menu {
    id: customMenu

    property string menuIcon: ""
    property string menuDescription: ""

    padding: 8
    overlap: 1
    transformOrigin: Item.TopLeft

    width: {
        var maxWidth = 180
        for (var i = 0; i < customMenu.count; ++i) {
            var item = customMenu.itemAt(i)
            if (item && item.implicitWidth)
                maxWidth = Math.max(maxWidth, item.implicitWidth + 20)
        }
        return maxWidth
    }

    background: Rectangle {
        anchors.fill: parent
        color: "#181818"
        border.color: "#202020"
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

    delegate: MenuItem {
        id: menuDelegate

        implicitHeight: 32
        implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding

        padding: 0
        leftPadding: 10
        rightPadding: 10

        readonly property bool isSubmenuTrigger: menuDelegate.subMenu !== null

        readonly property string resolvedIconSource: {
            if (menuDelegate.icon && menuDelegate.icon.source && menuDelegate.icon.source.toString().length > 0)
                return menuDelegate.icon.source.toString()
            if (menuDelegate.isSubmenuTrigger && menuDelegate.subMenu) {
                if (menuDelegate.subMenu.menuIcon && menuDelegate.subMenu.menuIcon.length > 0)
                    return menuDelegate.subMenu.menuIcon
                if (menuDelegate.subMenu.icon && menuDelegate.subMenu.icon.source && menuDelegate.subMenu.icon.source.toString().length > 0)
                    return menuDelegate.subMenu.icon.source.toString()
            }
            return ""
        }

        readonly property string resolvedDescription: {
            if (menuDelegate.isSubmenuTrigger && menuDelegate.subMenu && menuDelegate.subMenu.menuDescription)
                return menuDelegate.subMenu.menuDescription
            if (menuDelegate.action && menuDelegate.action.description)
                return menuDelegate.action.description
            return ""
        }

        enabled: isSubmenuTrigger && subMenu !== null ? subMenu.enabled : true

        palette.windowText: "#ffffff"
        palette.buttonText: "#ffffff"
        palette.brightText: "#ffffff"
        palette.highlightedText: "#ffffff"
        palette.text: "#e0e0e0"

        XylaToolTip {
            visible: menuDelegate.hovered && menuDelegate.resolvedDescription !== ""
            text: menuDelegate.resolvedDescription
            delay: 800
            position: "right"
        }

        contentItem: RowLayout {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 10

            implicitWidth: iconSlot.implicitWidth
                           + titleText.implicitWidth
                           + shortcutText.implicitWidth
                           + submenuChevron.implicitWidth
                           + (spacing * 3)

            Item {
                id: iconSlot
                implicitWidth: 16
                implicitHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg
                    anchors.fill: parent
                    source: menuDelegate.resolvedIconSource
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: iconImg
                    source: iconImg
                    visible: menuDelegate.resolvedIconSource.length > 0
                    colorization: 1.0
                    colorizationColor: menuDelegate.enabled
                                       ? (menuDelegate.highlighted ? "#ffffff" : "#a0a0a0")
                                       : "#555555"
                }
            }

            Text {
                id: titleText
                text: menuDelegate.text
                color: menuDelegate.enabled ? (menuDelegate.highlighted ? "#ffffff" : "#d0d0d0") : "#555555"
                font.pixelSize: 12
                Layout.minimumWidth: 120
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            Text {
                id: shortcutText
                visible: !menuDelegate.isSubmenuTrigger
                         && menuDelegate.action
                         && menuDelegate.action.shortcut
                         && String(menuDelegate.action.shortcut).length > 0
                text: visible ? String(menuDelegate.action.shortcut) : ""
                color: "#8d8d8d"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                id: submenuChevron
                implicitWidth: menuDelegate.isSubmenuTrigger ? 14 : 0
                implicitHeight: 14
                visible: menuDelegate.isSubmenuTrigger
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: chevronImg
                    anchors.fill: parent
                    source: "qrc:/assets/icons/chevron-right.svg"
                    sourceSize: Qt.size(14, 14)
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: chevronImg
                    source: chevronImg
                    visible: menuDelegate.isSubmenuTrigger
                    colorization: 1.0
                    colorizationColor: menuDelegate.enabled
                                       ? (menuDelegate.highlighted ? "#ffffff" : "#a0a0a0")
                                       : "#555555"
                }
            }
        }

        background: Rectangle {
            anchors.fill: parent
            radius: 8
            color: !menuDelegate.enabled ? "transparent"
                                         : menuDelegate.pressed ? "#303030"
                                                                : menuDelegate.highlighted ? "#252525"
                                                                                           : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }

        opacity: menuDelegate.enabled ? 1.0 : 0.48

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        arrow: Item {
            width: 0
            height: 0
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 120; easing.type: Easing.OutCubic }
    }
}
