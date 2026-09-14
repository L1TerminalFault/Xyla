import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

    Rectangle {
        id: row
        property string iconSource
        property string text
        property string shortcut: ""
        property bool destructive: false
        property bool showArrow: false
        property bool enabled_: true
        property string tooltip: ""

        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 12
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "#181818"

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
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

        HoverHandler {
            id: rowHover
        }

        XylaToolTip {
            visible: rowHover.hovered && tooltip !== ""
            position: "right"
            text: row.tooltip
        }

        RowLayout {
            id: rowContent

            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 6
            anchors.bottomMargin: 6

            spacing: 10

            // ========================================================
            // ICON
            // ========================================================

            Item {
                id: iconContainer

                implicitWidth: 16
                implicitHeight: 16

                property int visibleWidth: visible ? 16 : 0

                // visible: row.iconSource !== ""
                opacity: row.iconSource !== ""

                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg

                    anchors.fill: parent

                    source: row.iconSource

                    sourceSize: Qt.size(16, 16)

                    fillMode: Image.PreserveAspectFit

                    smooth: true

                    visible: false
                }

                MultiEffect {
                    anchors.fill: iconImg

                    source: iconImg

                    colorization: 1.0

                    colorizationColor: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"
                }
            }

            // ========================================================
            // TITLE
            // ========================================================

            Text {
                id: titleText

                text: row.text

                color: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"

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

                visible: !row.showArrow
                opacity: row.shortcut !== ""

                property var keyTokens: {
                    var rawShortcut = row.shortcut || "";

                    return rawShortcut !== "" ? rawShortcut.split("+") : [];
                }

                Repeater {
                    model: shortcutRow.keyTokens

                    delegate: Item {
                        id: tokenItem

                        property string keyText: modelData.trim()
                        property string iconSrc: row.getModifierIcon(keyText)
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

                            color: rowMouse.containsMouse ? "#353535" : "#141414"

                            radius: 5

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
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

                            // visible: tokenItem.isModifier
                            opacity: tokenItem.isModifier

                            colorization: 1.0

                            colorizationColor: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

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

                            // visible: !tokenItem.isModifier
                            opacity: !tokenItem.isModifier

                            text: tokenItem.keyText

                            color: row.enabled_ ? (rowMouse.containsMouse ? "#ffffff" : "#a0a0a0") : "#555555"

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

            // ========================================================
            // EXPAND ARROW
            // ========================================================

            Text {
                id: arrowText

                visible: row.showArrow

                text: "›"

                color: "#888888"

                font.pixelSize: 20

                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent

            hoverEnabled: true
            enabled: row.enabled_

            cursorShape: Qt.PointingHandCursor

            onClicked: row.clicked()
        }
    }

