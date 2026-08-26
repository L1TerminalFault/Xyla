import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

MenuItem {
    id: control

    implicitHeight: 32
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding

    text: control.action ? control.action.text : ""

    property string descriptionText: ""

    XylaToolTip {
        visible: control.hovered && control.descriptionText !== ""
        text: control.descriptionText
        delay: 500
    }

    // ============================================================
    // MODIFIER ICONS
    // ============================================================

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

    // ============================================================
    // SUBMENU
    //
    // Same visual language as the application's Popup:
    // #181818 surface
    // #303030 border
    // 12px radius
    // MultiEffect shadow
    // opacity + scale entrance
    // ============================================================

    Menu {
        id: subMenu

        padding: 8

        background: Rectangle {
            id: subMenuBackground

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

    // ============================================================
    // MENU ITEM CONTENT
    // ============================================================

    contentItem: RowLayout {

        anchors.top: parent.top
        anchors.bottom: parent.bottom

        spacing: 10

        implicitWidth: iconContainer.implicitWidth + titleText.implicitWidth + shortcutRow.implicitWidth + (spacing * 2)

        // ========================================================
        // ICON
        // ========================================================

        Item {
            id: iconContainer

            implicitWidth: 16
            implicitHeight: 16

            property int visibleWidth: visible ? 16 : 0

            visible: !!(control.action && control.action.icon.source.toString())

            Layout.alignment: Qt.AlignVCenter

            Image {
                id: iconImg

                anchors.fill: parent

                source: control.action && control.action.icon.source ? control.action.icon.source : ""

                sourceSize: Qt.size(16, 16)

                fillMode: Image.PreserveAspectFit

                smooth: true

                visible: false
            }

            MultiEffect {
                anchors.fill: iconImg

                source: iconImg

                colorization: 1.0

                colorizationColor: control.enabled ? (control.highlighted ? "#ffffff" : "#a0a0a0") : "#555555"
            }
        }

        // ========================================================
        // TITLE
        // ========================================================

        Text {
            id: titleText

            text: control.text

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

        // ========================================================
        // SHORTCUT
        // ========================================================

        Row {
            id: shortcutRow

            spacing: 4

            Layout.alignment: Qt.AlignVCenter

            visible: control.action && control.action.shortcut ? true : false

            property var keyTokens: {
                var rawShortcut = control.action && control.action.shortcut ? control.action.shortcut.toString() : "";

                return rawShortcut !== "" ? rawShortcut.split("+") : [];
            }

            Repeater {
                model: shortcutRow.keyTokens

                delegate: Item {
                    id: tokenItem

                    property string keyText: modelData.trim()
                    property string iconSrc: control.getModifierIcon(keyText)
                    property bool isModifier: iconSrc !== ""
                    property bool hovered: tokenHover.containsMouse

                    implicitWidth: 20
                    implicitHeight: 20

                    // ------------------------------------------------
                    // KEY BACKGROUND
                    // ------------------------------------------------

                    Rectangle {
                        id: keyBackground

                        anchors.fill: parent

                        color: control.hovered || control.highlighted // tokenItem.hovered
                              ? "#353535"
                              : "#141414"

                        // border.color: tokenItem.hovered
                        //               ? "#484848"
                        //               : "#292929"
                        //
                        // border.width: 1
                        radius: 5

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Behavior on border.color {
                        //     ColorAnimation {
                        //         duration: 100
                        //         easing.type: Easing.OutCubic
                        //     }
                        // }
                    }

                    // ------------------------------------------------
                    // HOVER DETECTOR
                    // ------------------------------------------------

                    MouseArea {
                        id: tokenHover

                        anchors.fill: parent

                        hoverEnabled: true

                        acceptedButtons: Qt.NoButton
                    }

                    // ------------------------------------------------
                    // MODIFIER ICON
                    // ------------------------------------------------

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

                        colorizationColor:
                            control.enabled
                                ? (
                                    control.highlighted
                                        ? "#ffffff"
                                        : "#a0a0a0"
                                )
                                : "#555555"

                        Behavior on colorizationColor {
                            ColorAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // ------------------------------------------------
                    // NORMAL KEY
                    // ------------------------------------------------

                    Text {
                        id: letterLabel

                        anchors.centerIn: parent

                        visible: !tokenItem.isModifier

                        text: tokenItem.keyText

                        color:
                            control.enabled
                                ? (
                                    control.highlighted
                                        ? "#ffffff"
                                        : "#a0a0a0"
                                )
                                : "#555555"

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

    // ============================================================
    // ITEM PADDING
    // ============================================================

    leftPadding: 12
    rightPadding: 12

    // ============================================================
    // MENU ITEM BACKGROUND
    //
    // This is the important part that was missing.
    //
    // Normal:
    //     transparent
    //
    // Hover:
    //     #252525
    //
    // Pressed:
    //     #303030
    //
    // Disabled:
    //     transparent
    //
    // Radius:
    //     6px
    //
    // This matches the application's context-menu rows rather
    // than using the default Qt Controls blue highlight.
    // ============================================================

    background: Rectangle {
        id: itemBackground

        anchors.fill: parent

        radius: 8

        color: !control.enabled ? "transparent" : control.pressed ? "#303030" : control.highlighted ? "#252525" : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    // ============================================================
    // SUBTLE ITEM SCALE/OPACITY FEEL
    //
    // Keep the item itself stable spatially; only the visual
    // background responds. This prevents menu rows from shifting.
    // ============================================================

    opacity: control.enabled ? 1.0 : 0.48

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
}
