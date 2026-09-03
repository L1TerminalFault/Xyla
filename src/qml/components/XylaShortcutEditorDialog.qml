import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../components"

Window {
    id: dialogRoot

    title: "Keyboard Shortcuts — Xyla"

    // Strict fixed dimensions to prevent tiling by WMs
    width: 980
    height: 820
    minimumWidth: 1240
    maximumWidth: 1240
    minimumHeight: 820
    maximumHeight: 820

    color: "#131313"
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.CustomizeWindowHint

    // Invalidation revision to trigger reactive re-computation on C++ signals
    property int shortcutRevision: 0

    // Active Modifier Layer Toggles
    property bool modCtrl: false
    property bool modShift: false
    property bool modAlt: false
    property bool modMeta: false

    // Selection & Filter State
    property string selectedKeyName: "C"
    property var currentActionForSelectedKey: null
    property var selectedActionFromList: null
    property string searchQuery: ""
    property string selectedCategory: "All"

    // -------------------------------------------------------------------------
    // C++ BACKEND SIGNAL CONNECTIONS
    // -------------------------------------------------------------------------
    Connections {
        target: shortcutManager
        function onShortcutsChanged() {
            dialogRoot.shortcutRevision++;
        }
        function onActivePresetNameChanged() {
            dialogRoot.shortcutRevision++;
        }
        function onAvailablePresetsChanged() {
            dialogRoot.shortcutRevision++;
        }
    }

    // -------------------------------------------------------------------------
    // KEY SEQUENCE RESOLUTION & MAPPING
    // -------------------------------------------------------------------------
    function normalizeKeyName(key) {
        var k = key.trim();
        var lk = k.toLowerCase();
        if (lk === "delete" || lk === "del")
            return "Delete";
        if (lk === "backspace" || lk === "bksp")
            return "Backspace";
        if (lk === "return" || lk === "enter")
            return "Return";
        if (lk === "esc" || lk === "escape")
            return "Esc";
        if (lk === "space" || lk === "spacebar")
            return "Space";
        if (lk === "tab")
            return "Tab";
        if (lk === "caps" || lk === "capslock")
            return "Caps";
        if (lk === "numlock" || lk === "num")
            return "NumLock";
        return k;
    }

    function buildCurrentSequence(key) {
        var seq = "";
        if (dialogRoot.modCtrl)
            seq += "Ctrl+";
        if (dialogRoot.modShift)
            seq += "Shift+";
        if (dialogRoot.modAlt)
            seq += "Alt+";
        if (dialogRoot.modMeta)
            seq += "Cmd+";
        seq += normalizeKeyName(key);
        return seq;
    }

    function getActionForKey(key, revision) {
        var targetSeq = buildCurrentSequence(key).toLowerCase();
        var all = shortcutManager.getAllActions();
        for (var i = 0; i < all.length; ++i) {
            if (all[i].currentKey) {
                var cur = all[i].currentKey.toLowerCase();
                if (cur === targetSeq)
                    return all[i];
                if (targetSeq === "delete" && cur === "backspace")
                    return all[i];
                if (targetSeq === "backspace" && cur === "delete")
                    return all[i];
            }
        }
        return null;
    }

    function hasAnyShortcut(key, revision) {
        var norm = normalizeKeyName(key).toLowerCase();
        var all = shortcutManager.getAllActions();
        for (var i = 0; i < all.length; ++i) {
            if (all[i].currentKey) {
                var parts = all[i].currentKey.toLowerCase().split("+");
                var base = parts[parts.length - 1];
                if (base === norm || (norm === "delete" && base === "backspace") || (norm === "backspace" && base === "delete")) {
                    return true;
                }
            }
        }
        return false;
    }

    function updateSelectedKeyInfo() {
        currentActionForSelectedKey = getActionForKey(selectedKeyName, shortcutRevision);
    }

    onSelectedKeyNameChanged: updateSelectedKeyInfo()
    onModCtrlChanged: updateSelectedKeyInfo()
    onModShiftChanged: updateSelectedKeyInfo()
    onModAltChanged: updateSelectedKeyInfo()
    onModMetaChanged: updateSelectedKeyInfo()
    onShortcutRevisionChanged: updateSelectedKeyInfo()

    // -------------------------------------------------------------------------
    // HARDWARE KEYBOARD EVENT TRAP
    // -------------------------------------------------------------------------
    Item {
        id: hardwareFocusTrap
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Control) {
                dialogRoot.modCtrl = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Shift) {
                dialogRoot.modShift = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Alt) {
                dialogRoot.modAlt = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Meta) {
                dialogRoot.modMeta = true;
                event.accepted = true;
            }
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Control) {
                dialogRoot.modCtrl = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Shift) {
                dialogRoot.modShift = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Alt) {
                dialogRoot.modAlt = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Meta) {
                dialogRoot.modMeta = false;
                event.accepted = true;
            }
        }
    }

    // -------------------------------------------------------------------------
    // MAIN INTERFACE LAYOUT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // =====================================================================
        // 3. BOTTOM INSPECTOR & DIRECTORY MATRIX
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // -----------------------------------------------------------------
            // LEFT: SELECTED KEY INSPECTOR & CONFLICT DETECTOR
            // -----------------------------------------------------------------
Rectangle {
    id: detailsPanelRoot

    Layout.preferredWidth: 340
    Layout.fillHeight: true

    color: "#1c1c1c"
    radius: 8

    function getModifierIcon(keyName) {
        if (!keyName) return "";
        var normalized = keyName.trim().toLowerCase();
        switch (normalized) {
            case "ctrl":
            case "control":
                return "qrc:/assets/icons/ctrl.svg";
            case "shift":
                return "qrc:/assets/icons/shift.svg";
            case "alt":
                return "qrc:/assets/icons/alt.svg";
            case "meta":
            case "win":
            case "super":
            case "cmd":
                return "qrc:/assets/icons/win.svg";
            default:
                return "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                spacing: 6

                Text {
                    text: "KEY DETAILS"
                    color: "#71717a"
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: activeBadge
                opacity: dialogRoot.currentActionForSelectedKey !== null ? 1.0 : 0.0
                height: 22
                width: badgeLayout.implicitWidth + 16
                radius: 11
                color: "#121212"

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.InOutQuad
                    }
                }

                RowLayout {
                    id: badgeLayout
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        id: activeBadgeText
                        text: "Bound"
                        color: "#fff"
                        font.pixelSize: 9
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: "#131313"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Row {
                    id: shortcutRow

                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    visible: {
                        var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                        return seq && seq.trim() !== "";
                    }

                    property var keyTokens: {
                        var rawShortcut = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                        return rawShortcut ? rawShortcut.split("+") : [];
                    }

                    Repeater {
                        model: shortcutRow.keyTokens

                        delegate: Item {
                            id: tokenItem

                            property string keyText: modelData.trim()
                            property string iconSrc: detailsPanelRoot.getModifierIcon ? detailsPanelRoot.getModifierIcon(keyText) : ""
                            property bool isModifier: iconSrc !== ""
                            property bool hovered: tokenHover.containsMouse

                            implicitWidth: isModifier ? 24 : Math.max(24, letterLabel.implicitWidth + 10)
                            implicitHeight: 24

                            Rectangle {
                                id: keyBackground

                                anchors.fill: parent
                                radius: 6
                                color: "#222222"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 4
                                    color: "transparent"
                                    border.color: "#2a2a2a"
                                    border.width: 1
                                }
                            }

                            MouseArea {
                                id: tokenHover

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
                            }

                            Text {
                                id: letterLabel

                                anchors.centerIn: parent
                                visible: !tokenItem.isModifier
                                text: tokenItem.keyText
                                color: "#fff"
                                font.pixelSize: 11
                                font.family: "Monospace"

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.name : "Unassigned Key"
                        color: dialogRoot.currentActionForSelectedKey ? "#ffffff" : "#71717a"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.category : "Select an action to bind"
                            color: "#a1a1aa"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#131313"
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.description : "No action bound to this key combination. Select a command from the table to bind it."
                    color: "#a1a1aa"
                    font.pixelSize: 11
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    opacity: {
                        if (!dialogRoot.selectedActionFromList) return 0.0;
                        var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                        var conflict = shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq);
                        return conflict !== "" ? 1.0 : 0.0;
                    }
                    Layout.fillWidth: true
                    implicitHeight: conflictRow.implicitHeight + 14
                    radius: 8
                    color: "#cc2d1b28"
                    border.color: "#5c2a4d"
                    border.width: 1

                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuint } }

                    RowLayout {
                        id: conflictRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Item {
                            width: 14
                            height: 14
                            Layout.alignment: Qt.AlignVCenter

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.lineWidth = 1.2;
                                    ctx.strokeStyle = "#e64a85";
                                    
                                    ctx.beginPath();
                                    ctx.moveTo(7, 1.5);
                                    ctx.lineTo(13, 12);
                                    ctx.lineTo(1, 12);
                                    ctx.closePath();
                                    ctx.stroke();

                                    ctx.fillStyle = "#e64a85";
                                    ctx.fillRect(6.4, 5, 1.2, 3.5);
                                    ctx.beginPath();
                                    ctx.arc(7, 10, 0.7, 0, 2 * Math.PI);
                                    ctx.fill();
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            // Text {
                            //     text: "HOTKEY CONFLICT"
                            //     color: "#ef4081"
                            //     font.pixelSize: 9
                            //     font.letterSpacing: 0.5
                            // }

                            Text {
                                text: {
                                    if (!dialogRoot.selectedActionFromList) return "";
                                    var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                                    return "Replaces '" + shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq) + "'";
                                }
                                color: "#d884b0"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: unbindBtn
                Layout.fillWidth: true
                height: 34
                radius: 6
                enabled: dialogRoot.currentActionForSelectedKey !== null
                opacity: enabled ? 1.0 : 0.55

                color: !enabled ? "#20ff3355" : unbindM.containsPress ? "#39ff3355" : unbindM.containsMouse ? "#33ff3355" : "#20ff3355"

                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        width: 15
                        height: 15

                        Image {
                            id: svgImage2
                            anchors.fill: parent
                            source: "qrc:/assets/icons/link.svg"
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: svgImage2
                            source: svgImage2
                            colorization: 1.0
                            colorizationColor: "#ff4365"
                        }
                    }

                    Text {
                        text: "Unbind"
                        color: "#ff4365"
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: unbindM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (dialogRoot.currentActionForSelectedKey) {
                            shortcutManager.setKeySequence(dialogRoot.currentActionForSelectedKey.id, "");
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 8
                enabled: dialogRoot.currentActionForSelectedKey !== null
                opacity: enabled ? 1.0 : 0.55

                color: !enabled ? "#2a2a2a" : resetKeyM.containsPress ? "#353535" : resetKeyM.containsMouse ? "#333333" : "#2a2a2a"

                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        width: 15
                        height: 15

                        Image {
                            id: svgImage3
                            anchors.fill: parent
                            source: "qrc:/assets/icons/refresh.svg"
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: svgImage3
                            source: svgImage3
                            colorization: 1.0
                            colorizationColor: "#ffffff"
                        }
                    }

                    Text {
                        text: "Default"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: resetKeyM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (dialogRoot.currentActionForSelectedKey) {
                            shortcutManager.resetActionToDefault(dialogRoot.currentActionForSelectedKey.id);
                        }
                    }
                }
            }
        }
    }
}
// Rectangle {
//     id: detailsPanelRoot
//
//     // -------------------------------------------------------------------------
//     // PROPERTIES & INTEGRATION SLOTS
//     // -------------------------------------------------------------------------
//     Layout.preferredWidth: 340
//     Layout.fillHeight: true
//
//     // -------------------------------------------------------------------------
//     // THEME PALETTE (Synced directly with KeyCap palette structure)
//     // -------------------------------------------------------------------------
//     // readonly property color colorBasePanel: "#191919"
//     readonly property color colorCardBackground: "#131313"  // Matches colorBaseSpecial
//     readonly property color colorCardBorder: "#222222"      // Matches colorBaseNormal
//     readonly property color colorBorderHover: "#303030"     // Matches colorNormalHover
//
//     // Typography Colors
//     readonly property color colorTextPrimary: "#ffffff"
//     readonly property color colorTextSecondary: "#a1a1aa"
//     readonly property color colorTextMuted: "#71717a"
//     readonly property color colorAccentBlue: "#60a5fa"     // Matches KeyCap colorBlueAccentText
//
//     // Status & Feedback Colors
//     readonly property color colorSuccessText: "#4ade80"
//     readonly property color colorSuccessBg: "#14291e"
//     readonly property color colorSuccessBorder: "#1e4620"
//
//     readonly property color colorWarningText: "#f97316"
//     readonly property color colorWarningSubtext: "#fb923c"
//     readonly property color colorWarningBg: "#2a1708"
//     readonly property color colorWarningBorder: "#7c2d12"
//
//     // Destructive Action Colors
//     readonly property color colorDangerText: "#f87171"
//     readonly property color colorDangerBg: "#1f1315"
//     readonly property color colorDangerHoverBg: "#270e0f"
//     readonly property color colorDangerPressBg: "#450a0a"
//     readonly property color colorDangerBorder: "#451a1c"
//     readonly property color colorDangerHoverBorder: "#7f1d1d"
//
//     // Default Action Colors
//     readonly property color colorNeutralBtnBg: "#222222"
//     readonly property color colorNeutralBtnHoverBg: "#303030"
//     readonly property color colorNeutralBtnPressBg: "#3a3a3a"
//     readonly property color colorNeutralBtnBorder: "#303030"
//
//     // -------------------------------------------------------------------------
//     // PANEL CONTAINER
//     // -------------------------------------------------------------------------
//     color: "#1c1c1c" // colorBasePanel
//     radius: 12
//
// // Helper function to resolve modifier string names to icon paths
// function getModifierIcon(keyName) {
//     if (!keyName) return "";
//
//     var normalized = keyName.trim().toLowerCase();
//
//     switch (normalized) {
//         case "ctrl":
//         case "control":
//             return "qrc:/assets/icons/ctrl.svg"; // Adjust path to match your resource directory
//         case "shift":
//             return "qrc:/assets/icons/shift.svg";
//         case "alt":
//             return "qrc:/assets/icons/alt.svg";
//         case "meta":
//         case "win":
//         case "super":
//         case "cmd":
//             return "qrc:/assets/icons/win.svg";
//         default:
//             return ""; // Returns empty string for normal characters (A-Z, 0-9, etc.)
//     }
// }
//
//     ColumnLayout {
//         anchors.fill: parent
//         anchors.margins: 14
//         spacing: 12
//
//         // =====================================================================
//         // SECTION 1: HEADER & STATUS BADGE
//         // =====================================================================
//         RowLayout {
//             Layout.fillWidth: true
//             spacing: 8
//
//             // Section Icon + Header Title
//             RowLayout {
//                 spacing: 6
//
//                 // Vector Graphic Icon: Key Information
// // Image {
// //     source: "qrc:/assets/icons/info.svg"
// //     color: detailsPanelRoot.colorTextMuted
// //     sourceSize.width: 12
// //     sourceSize.height: 12
// //     fillMode: Image.PreserveAspectFit
// //     smooth: true
// //     antialiasing: true
// // }
//
// // Item {
// //     width: 12
// //     height: 12
// //
// //     // 1. The source SVG image (hidden from direct view)
// //     Image {
// //         id: svgImage1
// //         anchors.fill: parent
// //         source: "qrc:/assets/icons/info.svg"
// //         sourceSize: Qt.size(width, height)
// //         fillMode: Image.PreserveAspectFit
// //         visible: false // Hide the original SVG
// //     }
// //
// //     // 2. The effect that applies the color overlay
// //     MultiEffect {
// //         anchors.fill: svgImage1
// //         source: svgImage1
// //         colorization: 1.0                // Fully tint the icon (0.0 = original, 1.0 = fully tinted)
// //         colorizationColor: detailsPanelRoot.colorTextMuted /* "#ff3355" */
// //     }
// // }
//
//
//                 // Item {
//                 //     width: 14
//                 //     height: 14
//                 //
//                 //     Canvas {
//                 //         anchors.fill: parent
//                 //         onPaint: {
//                 //             var ctx = getContext("2d");
//                 //             ctx.reset();
//                 //             ctx.lineWidth = 1.25;
//                 //             ctx.strokeStyle = detailsPanelRoot.colorTextMuted;
//                 //
//                 //             // Info Circle Icon
//                 //             ctx.beginPath();
//                 //             ctx.arc(7, 7, 5.5, 0, 2 * Math.PI);
//                 //             ctx.stroke();
//                 //
//                 //             ctx.fillStyle = detailsPanelRoot.colorTextMuted;
//                 //             ctx.beginPath();
//                 //             ctx.arc(7, 4.5, 0.9, 0, 2 * Math.PI);
//                 //             ctx.fill();
//                 //
//                 //             ctx.beginPath();
//                 //             ctx.moveTo(7, 6.8);
//                 //             ctx.lineTo(7, 9.8);
//                 //             ctx.stroke();
//                 //         }
//                 //     }
//                 // }
//
//                 Text {
//                     text: "KEY DETAILS"
//                     color: detailsPanelRoot.colorTextMuted
//                     font.pixelSize: 10
//                     // font.bold: true
//                     // font.letterSpacing: 1.1
//                 }
//             }
//
//             Item { Layout.fillWidth: true }
//
//             // Active Status Badge
//             Rectangle {
//                 id: activeBadge
//                 opacity: dialogRoot.currentActionForSelectedKey !== null ? 1.0 : 0.0
//                 height: 22
//                 width: badgeLayout.implicitWidth + 16
//                 radius: 11
//                 color: "#141414" // detailsPanelRoot.colorSuccessBg
//                 // border.color: detailsPanelRoot.colorSuccessBorder
//                 // border.width: 1
//
//                 Behavior on opacity {
//                     NumberAnimation {
//                         duration: 180
//                         easing.type: Easing.InOutQuad
//                     }
//                 }
//
//                 RowLayout {
//                     id: badgeLayout
//                     anchors.centerIn: parent
//                     spacing: 5
//
//
//
//                     // Image {
//                     //     source: "qrc:/assets/icons/link.svg"
//                     //     color: detailsPanelRoot.colorTextMuted
//                     //     sourceSize.width: 12
//                     //     sourceSize.height: 12
//                     //     fillMode: Image.PreserveAspectFit
//                     //     smooth: true
//                     //     antialiasing: true
//                     // }
// // Item {
// //     width: 12
// //     height: 12
// //
// //     // 1. The source SVG image (hidden from direct view)
// //     Image {
// //         id: svgImage
// //         anchors.fill: parent
// //         source: "qrc:/assets/icons/link.svg"
// //         sourceSize: Qt.size(width, height)
// //         fillMode: Image.PreserveAspectFit
// //         visible: false // Hide the original SVG
// //     }
// //
// //     // 2. The effect that applies the color overlay
// //     MultiEffect {
// //         anchors.fill: svgImage
// //         source: svgImage
// //         colorization: 1.0                // Fully tint the icon (0.0 = original, 1.0 = fully tinted)
// //         colorizationColor: "#60a5fa" // detailsPanelRoot.colorTextMuted /* "#ff3355" */
// //     }
// // }
//
//                     // Indicator Dot
//                     // Rectangle {
//                     //     width: 5
//                     //     height: 5
//                     //     radius: 2.5
//                     //     color: detailsPanelRoot.colorSuccessText
//                     // }
//
//                     Text {
//                         id: activeBadgeText
//                         text: "Bound"
//                         color: "#fff" // "#60a5fa" // detailsPanelRoot.colorSuccessText
//                         font.pixelSize: 9
//                         // font.bold: true
//                     }
//                 }
//             }
//         }
//
//         // =====================================================================
//         // SECTION 2: KEYCAP & COMMAND HEADER CARD
//         // =====================================================================
//         Rectangle {
//             Layout.fillWidth: true
//             height: 64
//             color: detailsPanelRoot.colorCardBackground
//             // border.color: detailsPanelRoot.colorCardBorder
//             // border.width: 1
//             radius: 10
//
//             RowLayout {
//                 anchors.fill: parent
//                 anchors.margins: 10
//                 spacing: 12
//
//                 // Embedded Preview KeyCap Simulation
// Row {
//     id: shortcutRow
//
//     spacing: 4
//     Layout.alignment: Qt.AlignVCenter
//
//     // Evaluates whether a valid sequence exists
//     visible: {
//         var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
//         return seq && seq.trim() !== "";
//     }
//
//     // Splits sequence string (e.g., "Ctrl+Shift+A") into key tokens
//     property var keyTokens: {
//         var rawShortcut = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
//         return rawShortcut ? rawShortcut.split("+") : [];
//     }
//
//     Repeater {
//         model: shortcutRow.keyTokens
//
//         delegate: Item {
//             id: tokenItem
//
//             property string keyText: modelData.trim()
//             property string iconSrc: detailsPanelRoot.getModifierIcon ? detailsPanelRoot.getModifierIcon(keyText) : ""
//             property bool isModifier: iconSrc !== ""
//             property bool hovered: tokenHover.containsMouse
//
//             // Dynamic width based on text length for regular keys, fixed for icons
//             implicitWidth: isModifier ? 24 : Math.max(24, letterLabel.implicitWidth + 10)
//             implicitHeight: 24
//
//             // ------------------------------------------------
//             // KEY BACKGROUND & CONTAINER
//             // ------------------------------------------------
//             Rectangle {
//                 id: keyBackground
//
//                 anchors.fill: parent
//                 radius: 6
//                 color: "#222222" // tokenItem.hovered ? "#222222" : detailsPanelRoot.colorBasePanel
//                 // border.color: tokenItem.hovered ? detailsPanelRoot.colorBorderHover : detailsPanelRoot.colorCardBorder
//                 // border.width: 1
//
//                 Behavior on color {
//                     ColorAnimation {
//                         duration: 120
//                         easing.type: Easing.OutCubic
//                     }
//                 }
//
//                 Behavior on border.color {
//                     ColorAnimation {
//                         duration: 120
//                         easing.type: Easing.OutCubic
//                     }
//                 }
//
//                 // Inner keycap bevel effect
//                 Rectangle {
//                     anchors.fill: parent
//                     anchors.margins: 1
//                     radius: 4
//                     color: "transparent"
//                     border.color: "#2a2a2a"
//                     border.width: 1
//                 }
//             }
//
//             // ------------------------------------------------
//             // HOVER DETECTOR
//             // ------------------------------------------------
//             MouseArea {
//                 id: tokenHover
//
//                 anchors.fill: parent
//                 hoverEnabled: true
//                 acceptedButtons: Qt.NoButton
//             }
//
//             // ------------------------------------------------
//             // MODIFIER ICON
//             // ------------------------------------------------
//             Image {
//                 id: modifierImg
//
//                 anchors.centerIn: parent
//                 width: 14
//                 height: 14
//                 source: tokenItem.iconSrc
//                 sourceSize: Qt.size(14, 14)
//                 fillMode: Image.PreserveAspectFit
//             }
//
//             // MultiEffect {
//             //     anchors.fill: modifierImg
//             //     source: modifierImg
//             //     visible: tokenItem.isModifier
//             //     colorization: 1.0
//             //     colorizationColor: tokenItem.hovered ? "#ffffff" : detailsPanelRoot.colorAccentBlue
//             //
//             //     Behavior on colorizationColor {
//             //         ColorAnimation {
//             //             duration: 120
//             //             easing.type: Easing.OutCubic
//             //         }
//             //     }
//             // }
//
//             // ------------------------------------------------
//             // NORMAL KEY TEXT
//             // ------------------------------------------------
//             Text {
//                 id: letterLabel
//
//                 anchors.centerIn: parent
//                 visible: !tokenItem.isModifier
//                 text: tokenItem.keyText
//                 color: "#fff" // tokenItem.hovered ? "#ffffff" : detailsPanelRoot.colorAccentBlue
//                 font.pixelSize: 11
//                 // font.bold: true
//                 font.family: "Monospace"
//
//                 Behavior on color {
//                     ColorAnimation {
//                         duration: 120
//                         easing.type: Easing.OutCubic
//                     }
//                 }
//             }
//         }
//     }
// }
//                 // Rectangle {
//                 //     width: 44
//                 //     height: 44
//                 //     radius: 6
//                 //     color: detailsPanelRoot.colorBasePanel
//                 //     border.color: detailsPanelRoot.colorCardBorder
//                 //     border.width: 1
//                 //
//                 //     // Keycap drop-shadow visual styling
//                 //     Rectangle {
//                 //         anchors.fill: parent
//                 //         anchors.margins: 1
//                 //         radius: 5
//                 //         color: "transparent"
//                 //         border.color: "#2a2a2a"
//                 //         border.width: 1
//                 //     }
//                 //
//                 //     Text {
//                 //         anchors.centerIn: parent
//                 //         text: dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName)
//                 //         color: detailsPanelRoot.colorAccentBlue
//                 //         font.pixelSize: 11
//                 //         font.bold: true
//                 //         font.family: "Monospace"
//                 //     }
//                 // }
//
//                 ColumnLayout {
//                     Layout.fillWidth: true
//                     spacing: 2
//
//                     Text {
//                         text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.name : "Unassigned Key"
//                         color: dialogRoot.currentActionForSelectedKey ? detailsPanelRoot.colorTextPrimary : detailsPanelRoot.colorTextMuted
//                         font.pixelSize: 13
//                         // font.weight: Font.DemiBold
//                         elide: Text.ElideRight
//                         Layout.fillWidth: true
//                     }
//
//                     RowLayout {
//                         Layout.fillWidth: true
//                         spacing: 4
//
//                         // Icon: Folder / Category
//                         // Item {
//                         //     width: 12
//                         //     height: 12
//                         //     visible: dialogRoot.currentActionForSelectedKey !== null
//                         //
//                         //     Canvas {
//                         //         anchors.fill: parent
//                         //         onPaint: {
//                         //             var ctx = getContext("2d");
//                         //             ctx.reset();
//                         //             ctx.lineWidth = 1;
//                         //             ctx.strokeStyle = detailsPanelRoot.colorTextSecondary;
//                         //             ctx.beginPath();
//                         //             ctx.moveTo(1, 3);
//                         //             ctx.lineTo(4.5, 3);
//                         //             ctx.lineTo(6, 4.5);
//                         //             ctx.lineTo(11, 4.5);
//                         //             ctx.lineTo(11, 10.5);
//                         //             ctx.lineTo(1, 10.5);
//                         //             ctx.closePath();
//                         //             ctx.stroke();
//                         //         }
//                         //     }
//                         // }
//
//                         Text {
//                             text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.category : "Select an action to bind"
//                             color: detailsPanelRoot.colorTextSecondary
//                             font.pixelSize: 10
//                             elide: Text.ElideRight
//                             Layout.fillWidth: true
//                         }
//                     }
//                 }
//             }
//         }
//
//         // =====================================================================
//         // SECTION 3: DESCRIPTION & CONFLICT DISPLAY CARD
//         // =====================================================================
//         Rectangle {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             color: detailsPanelRoot.colorCardBackground
//             // border.color: detailsPanelRoot.colorCardBorder
//             // border.width: 1
//             radius: 8
//
//             ColumnLayout {
//                 anchors.fill: parent
//                 anchors.margins: 12
//                 spacing: 8
//
//                 // Description Title Header
//                 // RowLayout {
//                 //     spacing: 5
//                 //
//                 //     // Icon: Document Text
//                 //     Item {
//                 //         width: 12
//                 //         height: 12
//                 //         Canvas {
//                 //             anchors.fill: parent
//                 //             onPaint: {
//                 //                 var ctx = getContext("2d");
//                 //                 ctx.reset();
//                 //                 ctx.lineWidth = 1;
//                 //                 ctx.strokeStyle = detailsPanelRoot.colorTextMuted;
//                 //                 ctx.strokeRect(2, 1.5, 8, 9);
//                 //                 ctx.beginPath();
//                 //                 ctx.moveTo(4, 4); ctx.lineTo(8, 4);
//                 //                 ctx.moveTo(4, 6.5); ctx.lineTo(8, 6.5);
//                 //                 ctx.moveTo(4, 9); ctx.lineTo(6.5, 9);
//                 //                 ctx.stroke();
//                 //             }
//                 //         }
//                 //     }
//                 //
//                 //     Text {
//                 //         text: "DESCRIPTION"
//                 //         color: detailsPanelRoot.colorTextMuted
//                 //         font.pixelSize: 9
//                 //         font.bold: true
//                 //         font.letterSpacing: 0.8
//                 //     }
//                 // }
//
//                 Text {
//                     text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.description : "No action bound to this key combination. Select a command from the table to bind it."
//                     color: detailsPanelRoot.colorTextSecondary
//                     font.pixelSize: 11
//                     lineHeight: 1.35
//                     wrapMode: Text.WordWrap
//                     Layout.fillWidth: true
//                 }
//
//                 Item { Layout.fillHeight: true }
//
// Rectangle {
//     visible: {
//         if (!dialogRoot.selectedActionFromList) return false;
//         var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
//         var conflict = shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq);
//         return conflict !== "";
//     }
//     Layout.fillWidth: true
//     implicitHeight: conflictRow.implicitHeight + 14
//     radius: 8
//     color: "#cc2d1b28"
//     border.color: "#5c2a4d"
//     border.width: 1
//
//     RowLayout {
//         id: conflictRow
//         anchors.fill: parent
//         anchors.margins: 8
//         spacing: 8
//
//         // Icon: Warning Triangle
//         Item {
//             width: 14
//             height: 14
//             Layout.alignment: Qt.AlignVCenter
//
//             Canvas {
//                 anchors.fill: parent
//                 onPaint: {
//                     var ctx = getContext("2d");
//                     ctx.reset();
//                     ctx.lineWidth = 1.2;
//                     ctx.strokeStyle = "#e64a85";
//
//                     ctx.beginPath();
//                     ctx.moveTo(7, 1.5);
//                     ctx.lineTo(13, 12);
//                     ctx.lineTo(1, 12);
//                     ctx.closePath();
//                     ctx.stroke();
//
//                     ctx.fillStyle = "#e64a85";
//                     ctx.fillRect(6.4, 5, 1.2, 3.5);
//                     ctx.beginPath();
//                     ctx.arc(7, 10, 0.7, 0, 2 * Math.PI);
//                     ctx.fill();
//                 }
//             }
//         }
//
//         ColumnLayout {
//             Layout.fillWidth: true
//             spacing: 1
//
//             Text {
//                 text: "HOTKEY CONFLICT"
//                 color: "#ef4081"
//                 font.pixelSize: 9
//                 // font.bold: true
//                 font.letterSpacing: 0.5
//             }
//
//             Text {
//                 text: {
//                     if (!dialogRoot.selectedActionFromList) return "";
//                     var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
//                     return "Replaces '" + shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq) + "'";
//                 }
//                 color: "#d884b0"
//                 font.pixelSize: 10
//                 elide: Text.ElideRight
//                 Layout.fillWidth: true
//             }
//         }
//     }
// }
//             }
//         }
//
//         // =====================================================================
//         // SECTION 4: ACTION BUTTONS (UNBIND & DEFAULT)
//         // =====================================================================
//         RowLayout {
//             Layout.fillWidth: true
//             spacing: 8
//
//             // Unbind Button (Destructive Style)
//             Rectangle {
//                 id: unbindBtn
//                 Layout.fillWidth: true
//                 height: 34
//                 radius: 8
//                 enabled: dialogRoot.currentActionForSelectedKey !== null
//                 opacity: enabled ? 1.0 : 0.55
//
//                 // color: "#481f25"
//                 color: !enabled ? "#20ff3355" : unbindM.containsPress ? "#39ff3355" : unbindM.containsMouse ? "#33ff3355" : "#20ff3355"  // !enabled ? detailsPanelRoot.colorCardBackground : // "#ff3355"
//                        // (unbindM.containsPress ? detailsPanelRoot.colorDangerPressBg : 
//                        // (unbindM.containsMouse ? detailsPanelRoot.colorDangerHoverBg : detailsPanelRoot.colorDangerBg))
//
//                 // border.color: !enabled ? detailsPanelRoot.colorCardBorder : 
//                 //        (unbindM.containsMouse ? detailsPanelRoot.colorDangerHoverBorder : detailsPanelRoot.colorDangerBorder)
//                 // border.width: 1
//
//                 Behavior on opacity { NumberAnimation { duration: 120 } }
//                 Behavior on color { ColorAnimation { duration: 120 } }
//                 Behavior on border.color { ColorAnimation { duration: 120 } }
//
//                 RowLayout {
//                     anchors.centerIn: parent
//                     spacing: 6
//
//                     // Icon: Unlink / Trash
// // Image {
// //     source: "qrc:/assets/icons/link.svg"
// //     color: detailsPanelRoot.colorDangerText
// //     sourceSize.width: 12
// //     sourceSize.height: 12
// //     fillMode: Image.PreserveAspectFit
// //     smooth: true
// //     antialiasing: true
// // }
//
// Item {
//     width: 14
//     height: 14
//
//     // 1. The source SVG image (hidden from direct view)
//     Image {
//         id: svgImage2
//         anchors.fill: parent
//         source: "qrc:/assets/icons/link.svg"
//         sourceSize: Qt.size(width, height)
//         fillMode: Image.PreserveAspectFit
//         visible: false // Hide the original SVG
//     }
//
//     // 2. The effect that applies the color overlay
//     MultiEffect {
//         anchors.fill: svgImage2
//         source: svgImage2
//         colorization: 1.0                // Fully tint the icon (0.0 = original, 1.0 = fully tinted)
//         colorizationColor: "#ff3355" // detailsPanelRoot.colorDangerText
//     }
// }
//                     // Item {
//                     //     width: 12
//                     //     height: 12
//                     //     Canvas {
//                     //         anchors.fill: parent
//                     //         onPaint: {
//                     //             var ctx = getContext("2d");
//                     //             ctx.reset();
//                     //             ctx.lineWidth = 1.2;
//                     //             ctx.strokeStyle = detailsPanelRoot.colorDangerText;
//                     //             // Broken chain link / Unbind symbol
//                     //             ctx.beginPath();
//                     //             ctx.moveTo(2, 10); ctx.lineTo(10, 2); // Slash
//                     //             ctx.moveTo(3, 4); ctx.lineTo(6, 1); ctx.lineTo(9, 4); // Top link segment
//                     //             ctx.moveTo(9, 8); ctx.lineTo(6, 11); ctx.lineTo(3, 8); // Bottom link segment
//                     //             ctx.stroke();
//                     //         }
//                     //     }
//                     // }
//
//                     Text {
//                         text: "Unbind"
//                         color: "#ff3355" //detailsPanelRoot.colorDangerText
//                         font.pixelSize: 11
//                         // font.bold: true
//                     }
//                 }
//
//                 MouseArea {
//                     id: unbindM
//                     anchors.fill: parent
//                     hoverEnabled: true
//                     cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
//                     onClicked: {
//                         if (dialogRoot.currentActionForSelectedKey) {
//                             shortcutManager.setKeySequence(dialogRoot.currentActionForSelectedKey.id, "");
//                         }
//                     }
//                 }
//             }
//
//             // Default Reset Button (Neutral Style)
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 34
//                 radius: 8
//                 enabled: dialogRoot.currentActionForSelectedKey !== null
//                 opacity: enabled ? 1.0 : 0.55
//
//                 color: !enabled ? "#2a2a2a" : resetKeyM.containsPress ? "#353535" : resetKeyM.containsMouse ? "#333333" : "#2a2a2a" // !enabled ? detailsPanelRoot.colorCardBackground : 
//                        // (resetKeyM.containsPress ? detailsPanelRoot.colorNeutralBtnPressBg : 
//                        // (resetKeyM.containsMouse ? detailsPanelRoot.colorNeutralBtnHoverBg : detailsPanelRoot.colorNeutralBtnBg))
//
//                 // border.color: !enabled ? detailsPanelRoot.colorCardBorder : 
//                 //        (resetKeyM.containsMouse ? detailsPanelRoot.colorBorderHover : detailsPanelRoot.colorNeutralBtnBorder)
//                 // border.width: 1
//
//                 Behavior on opacity { NumberAnimation { duration: 120 } }
//                 Behavior on color { ColorAnimation { duration: 120 } }
//
//                 RowLayout {
//                     anchors.centerIn: parent
//                     spacing: 6
//
//                     // Icon: Reset / Undo Arrow
// // Image {
// //     source: "qrc:/assets/icons/refresh.svg"
// //     sourceSize.width: 12
// //     sourceSize.height: 12
// //     fillMode: Image.PreserveAspectFit
// //     smooth: true
// //     antialiasing: true
// // }
//
// Item {
//     width: 14
//     height: 14
//
//     // 1. The source SVG image (hidden from direct view)
//     Image {
//         id: svgImage3
//         anchors.fill: parent
//         source: "qrc:/assets/icons/refresh.svg"
//         sourceSize: Qt.size(width, height)
//         fillMode: Image.PreserveAspectFit
//         visible: false // Hide the original SVG
//     }
//
//     // 2. The effect that applies the color overlay
//     MultiEffect {
//         anchors.fill: svgImage3
//         source: svgImage3
//         colorization: 1.0                // Fully tint the icon (0.0 = original, 1.0 = fully tinted)
//         colorizationColor: detailsPanelRoot.colorTextPrimary // "#ff3355"      // Your target color (e.g., Red)
//     }
// }
//
//                     Text {
//                         text: "Default"
//                         color: detailsPanelRoot.colorTextPrimary
//                         font.pixelSize: 11
//                         font.weight: Font.Medium
//                     }
//                 }
//
//                 MouseArea {
//                     id: resetKeyM
//                     anchors.fill: parent
//                     hoverEnabled: true
//                     cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
//                     onClicked: {
//                         if (dialogRoot.currentActionForSelectedKey) {
//                             shortcutManager.resetActionToDefault(dialogRoot.currentActionForSelectedKey.id);
//                         }
//                     }
//                 }
//             }
//         }
//     }
// } 
// Rectangle {
            //     Layout.preferredWidth: 340
            //     Layout.fillHeight: true
            //     color: "#1a1a1a"
            //     border.color: "#2d2d2d"
            //     border.width: 1
            //     radius: 6
            //
            //     ColumnLayout {
            //         anchors.fill: parent
            //         anchors.margins: 12
            //         spacing: 8
            //
            //         RowLayout {
            //             Text {
            //                 text: "KEY DETAILS"
            //                 color: "#555562"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 font.letterSpacing: 1.0
            //             }
            //             Item {
            //                 Layout.fillWidth: true
            //             }
            //             Rectangle {
            //                 visible: dialogRoot.currentActionForSelectedKey !== null
            //                 height: 16
            //                 width: activeBadgeText.implicitWidth + 10
            //                 radius: 8
            //                 color: "#182a1d"
            //                 border.color: "#2a5433"
            //                 Text {
            //                     id: activeBadgeText
            //                     anchors.centerIn: parent
            //                     text: "Bound"
            //                     color: "#4ade80"
            //                     font.pixelSize: 8
            //                     font.bold: true
            //                 }
            //             }
            //         }
            //
            //         // Keycap Preview Box
            //         Rectangle {
            //             Layout.fillWidth: true
            //             height: 56
            //             color: "#101013"
            //             border.color: "#1e1e24"
            //             radius: 4
            //
            //             RowLayout {
            //                 anchors.fill: parent
            //                 anchors.margins: 8
            //                 spacing: 10
            //
            //                 Rectangle {
            //                     width: 40
            //                     height: 40
            //                     radius: 4
            //                     color: "#1f1f26"
            //                     border.color: "#3e3e4f"
            //                     border.width: 1.5
            //
            //                     Text {
            //                         anchors.centerIn: parent
            //                         text: dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName)
            //                         color: "#ffffff"
            //                         font.pixelSize: 10
            //                         font.bold: true
            //                         font.family: "Monospace"
            //                     }
            //                 }
            //
            //                 ColumnLayout {
            //                     Layout.fillWidth: true
            //                     spacing: 2
            //
            //                     Text {
            //                         text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.name : "Unassigned Key"
            //                         color: dialogRoot.currentActionForSelectedKey ? "#ffffff" : "#60606e"
            //                         font.pixelSize: 12
            //                         font.weight: Font.DemiBold
            //                         elide: Text.ElideRight
            //                         Layout.fillWidth: true
            //                     }
            //
            //                     Text {
            //                         text: dialogRoot.currentActionForSelectedKey ? "Category: " + dialogRoot.currentActionForSelectedKey.category : "Click an action on the right to assign"
            //                         color: "#7e7e8e"
            //                         font.pixelSize: 10
            //                     }
            //                 }
            //             }
            //         }
            //
            //         // Action Description / Info
            //         Rectangle {
            //             Layout.fillWidth: true
            //             Layout.fillHeight: true
            //             color: "#101013"
            //             border.color: "#1b1b20"
            //             radius: 4
            //
            //             ColumnLayout {
            //                 anchors.fill: parent
            //                 anchors.margins: 10
            //                 spacing: 6
            //
            //                 Text {
            //                     text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.description : "No action bound to this key combination. Select a command from the table to bind it."
            //                     color: "#808092"
            //                     font.pixelSize: 11
            //                     lineHeight: 1.3
            //                     wrapMode: Text.WordWrap
            //                     Layout.fillWidth: true
            //                 }
            //
            //                 Item {
            //                     Layout.fillHeight: true
            //                 }
            //
            //                 // Conflict Notification
            //                 Rectangle {
            //                     visible: {
            //                         if (!dialogRoot.selectedActionFromList)
            //                             return false;
            //                         var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
            //                         var conflict = shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq);
            //                         return conflict !== "";
            //                     }
            //                     Layout.fillWidth: true
            //                     height: 26
            //                     radius: 4
            //                     color: "#281e14"
            //                     border.color: "#5c381c"
            //
            //                     RowLayout {
            //                         anchors.fill: parent
            //                         anchors.margins: 6
            //                         spacing: 5
            //                         Text {
            //                             text: "CONFLICT:"
            //                             color: "#f59e0b"
            //                             font.pixelSize: 8
            //                             font.bold: true
            //                         }
            //                         Text {
            //                             text: {
            //                                 if (!dialogRoot.selectedActionFromList)
            //                                     return "";
            //                                 var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
            //                                 return "Replaces hotkey for '" + shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq) + "'";
            //                             }
            //                             color: "#f59e0b"
            //                             font.pixelSize: 9
            //                             elide: Text.ElideRight
            //                             Layout.fillWidth: true
            //                         }
            //                     }
            //                 }
            //             }
            //         }
            //
            //         // Inspector Action Buttons
            //         RowLayout {
            //             Layout.fillWidth: true
            //             spacing: 8
            //
            //             Rectangle {
            //                 Layout.fillWidth: true
            //                 height: 28
            //                 radius: 4
            //                 color: unbindM.containsMouse ? "#281b1b" : "#1a1516"
            //                 border.color: unbindM.containsMouse ? "#552828" : "#321e20"
            //                 enabled: dialogRoot.currentActionForSelectedKey !== null
            //                 opacity: enabled ? 1.0 : 0.4
            //
            //                 Text {
            //                     anchors.centerIn: parent
            //                     text: "Unbind"
            //                     color: "#ef4444"
            //                     font.pixelSize: 10
            //                     font.bold: true
            //                 }
            //
            //                 MouseArea {
            //                     id: unbindM
            //                     anchors.fill: parent
            //                     hoverEnabled: true
            //                     cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            //                     onClicked: {
            //                         if (dialogRoot.currentActionForSelectedKey) {
            //                             shortcutManager.setKeySequence(dialogRoot.currentActionForSelectedKey.id, "");
            //                         }
            //                     }
            //                 }
            //             }
            //
            //             Rectangle {
            //                 Layout.fillWidth: true
            //                 height: 28
            //                 radius: 4
            //                 color: resetKeyM.containsMouse ? "#22222c" : "#181820"
            //                 border.color: "#282834"
            //                 enabled: dialogRoot.currentActionForSelectedKey !== null
            //                 opacity: enabled ? 1.0 : 0.4
            //
            //                 Text {
            //                     anchors.centerIn: parent
            //                     text: "Default"
            //                     color: "#9ca3af"
            //                     font.pixelSize: 10
            //                 }
            //
            //                 MouseArea {
            //                     id: resetKeyM
            //                     anchors.fill: parent
            //                     hoverEnabled: true
            //                     cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            //                     onClicked: {
            //                         if (dialogRoot.currentActionForSelectedKey) {
            //                             shortcutManager.resetActionToDefault(dialogRoot.currentActionForSelectedKey.id);
            //                         }
            //                     }
            //                 }
            //             }
            //         }
            //     }
            // }

            // -----------------------------------------------------------------
            // RIGHT: BACKEND ACTIONS DIRECTORY TABLE
            // -----------------------------------------------------------------
Rectangle {
    id: actionTableRoot

    // ============================================================
    // FULL WIDTH ROOT CONTAINER
    // ============================================================

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.minimumWidth: 0
    Layout.maximumWidth: Infinity

    Layout.fillHeight: true

    width: parent ? parent.width : 0

    color: "#1c1c1c"
    radius: 8

    // ============================================================
    // Resizable columns
    // ============================================================

property real categoryColumnWidth: 100
property real shortcutColumnWidth: 150

readonly property real contentWidth: Math.max(0, tableHeader.width - 16)

readonly property real commandColumnWidth:
    Math.max(140, contentWidth - categoryColumnWidth - shortcutColumnWidth)

function resizeCommandCategory(delta) {
    var minimumCommand  = 140
    var minimumCategory = 70

    var newCategory = categoryColumnWidth - delta
    var maxCategory  = contentWidth - shortcutColumnWidth - minimumCommand

    if (newCategory > maxCategory)  newCategory = maxCategory
    if (newCategory < minimumCategory) newCategory = minimumCategory

    categoryColumnWidth = newCategory
}

function resizeCategoryShortcut(delta) {
    var minimumCategory = 70
    var minimumShortcut = 100

    var newCategory = categoryColumnWidth + delta
    var newShortcut = shortcutColumnWidth - delta

    if (newCategory < minimumCategory) {
        newShortcut -= (minimumCategory - newCategory)
        newCategory = minimumCategory
    }
    if (newShortcut < minimumShortcut) {
        newCategory -= (minimumShortcut - newShortcut)
        newShortcut = minimumShortcut
    }

    categoryColumnWidth = newCategory
    shortcutColumnWidth = newShortcut
}

    onWidthChanged: {
        if (commandColumnWidth <= 0)
            initializeColumns();
    }

    // Component.onCompleted: {
    //     initializeColumns();
    // }

    // ============================================================
    // CONTENT
    // ============================================================

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent

        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 12
        anchors.bottomMargin: 12

        spacing: 8

        // ========================================================
        // Search / Category / Assign
        // ========================================================

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            Rectangle {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 28

                color: "#131313"
                radius: 6

                RowLayout {
                    anchors.fill: parent

                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    spacing: 6

                    Image {
                        source:
                            "qrc:/assets/icons/search.svg"

                        sourceSize:
                            Qt.size(13, 13)

                        visible:
                            status === Image.Ready
                    }

                    TextInput {
                        id: searchInput

                        Layout.fillWidth: true

                        color: "#ffffff"

                        font.pixelSize: 11

                        selectByMouse: true
                        clip: true

                        onTextChanged: {
                            dialogRoot.searchQuery =
                                text.toLowerCase().trim();
                        }

                        Text {
                            anchors.fill: parent

                            text: "Search actions..."

                            color: "#71717a"

                            font: parent.font

                            visible:
                                !parent.text
                                && !parent.activeFocus

                            verticalAlignment:
                                Text.AlignVCenter
                        }
                    }
                }
            }

            Rectangle {
                id: categoryContainer

                height: 28

                implicitWidth:
                    categoryRow.implicitWidth + 4

                color: "#131313"

                radius: 6

                readonly property var categories: [
                    "All",
                    "Edit",
                    "Tools",
                    "Playback",
                    "Timeline"
                ]

                property Item activeTargetItem: null

                Rectangle {
                    id: categoryIndicator

                    height:
                        parent.height - 4

                    y: 2

                    radius: 4

                    color: "#11389F"

                    x:
                        categoryContainer.activeTargetItem
                        ? categoryContainer.activeTargetItem.x + 2
                        : 2

                    width:
                        categoryContainer.activeTargetItem
                        ? categoryContainer.activeTargetItem.width
                        : 0

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
                        model:
                            categoryContainer.categories

                        Item {
                            id: pillRoot

                            height:
                                categoryContainer.height - 4

                            width:
                                pillText.implicitWidth + 16

                            readonly property bool isSelected:
                                dialogRoot.selectedCategory ===
                                modelData

                            onIsSelectedChanged: {
                                if (isSelected)
                                    categoryContainer.activeTargetItem =
                                        pillRoot;
                            }

                            Component.onCompleted: {
                                if (isSelected)
                                    categoryContainer.activeTargetItem =
                                        pillRoot;
                            }

                            Text {
                                id: pillText

                                anchors.centerIn: parent

                                text: modelData

                                color:
                                    pillRoot.isSelected
                                    ? "#ffffff"
                                    : (
                                        pillMouse.containsMouse
                                        ? "#ffffff"
                                        : "#a1a1aa"
                                    )

                                font.pixelSize: 11

                                // font.weight:
                                //     pillRoot.isSelected
                                //     ? Font.DemiBold
                                //     : Font.Normal
                            }

                            MouseArea {
                                id: pillMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    dialogRoot.selectedCategory =
                                        modelData;
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // ====================================================
            // ASSIGN
            // ====================================================

                Row {
                    spacing: 6

                    // anchors.verticalCenter:
                    //     parent.verticalCenter

                    // Text {
                    //     text: "Assign to"
                    //
                    //     color:
                    //         assignButton.enabled
                    //         ? "#d0d0d8"
                    //         : "#55555f"
                    //
                    //     font.pixelSize: 11
                    //     font.weight: Font.DemiBold
                    //
                    //     anchors.verticalCenter:
                    //         parent.verticalCenter
                    // }
                    //
                    Row {
                        id: assignShortcutRow

                        spacing: 4

                        anchors.verticalCenter:
                            parent.verticalCenter

                        property var keyTokens: {
                            var rawShortcut =
                                dialogRoot.buildCurrentSequence(
                                    dialogRoot.selectedKeyName
                                );

                            return rawShortcut
                                   ? rawShortcut.split("+")
                                   : [];
                        }

                        Repeater {
                            model:
                                assignShortcutRow.keyTokens

                            delegate: Item {
                                id: assignTokenItem

                                property string keyText:
                                    modelData.trim()

                                property string iconSrc:
                                    detailsPanelRoot.getModifierIcon
                                    ? detailsPanelRoot.getModifierIcon(
                                          keyText
                                      )
                                    : ""

                                property bool isModifier:
                                    iconSrc !== ""

                                implicitWidth:
                                    isModifier
                                    ? 22
                                    : Math.max(
                                          22,
                                          assignLetterLabel
                                              .implicitWidth + 8
                                      )

                                implicitHeight: 22

                                Rectangle {
                                    anchors.fill: parent

                                    radius: 5

                                    color: "#141414"
                                }

                                Image {
                                    anchors.centerIn: parent

                                    width: 13
                                    height: 13

                                    source:
                                        assignTokenItem.iconSrc

                                    sourceSize:
                                        Qt.size(13, 13)

                                    fillMode:
                                        Image.PreserveAspectFit

                                    visible:
                                        assignTokenItem.isModifier
                                }

                                Text {
                                    id: assignLetterLabel

                                    anchors.centerIn: parent

                                    visible:
                                        !assignTokenItem.isModifier

                                    text:
                                        assignTokenItem.keyText

                                    color: "#d0d0d8"

                                    font.pixelSize: 10
                                    font.family: "Monospace"
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    Text {
                        visible:
                            assignShortcutRow.keyTokens.length === 0

                        text: "[None]"

                        color: "#55555f"

                        font.pixelSize: 10
                        font.family: "Monospace"

                        anchors.verticalCenter:
                            parent.verticalCenter
                    }
                }
        }

        // ========================================================
        // HEADER
        // ========================================================

Rectangle {
    id: backgroundContainer
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "#131313" // Background color
    radius: 8        // Optional rounded corners
    clip: true
    // border.color: "#2a2a2e"
    // border.width: 1

    ColumnLayout {
        id: mainWrapper
        anchors.fill: parent
        anchors.margins: 8 // Padding around the child components
        spacing: 8

        Item {
            id: tableHeader

            Layout.fillWidth: true

            Layout.preferredHeight: 22

            Row {
                id: headerRow

                anchors.fill: parent

                spacing: 0

                Item {
                    id: commandHeader

                    width:
                        actionTableRoot.commandColumnWidth

                    height: parent.height

                    Text {
                        anchors.fill: parent

                        verticalAlignment:
                            Text.AlignVCenter

                        text: "COMMAND"

                        color: "#52525e"

                        font.pixelSize: 9
                        font.bold: true
                    }

MouseArea {
    id: commandCategoryResizeHandle
    z: 100
    x: parent.width - 20
    width: 14
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.SizeHorCursor

    property real lastSceneX: 0

    onPressed: function(mouse) {
        lastSceneX = mapToItem(actionTableRoot, mouse.x, 0).x;
    }

    onPositionChanged: function(mouse) {
        if (!pressed) return;

        var sceneX = mapToItem(actionTableRoot, mouse.x, 0).x;
        var delta = sceneX - lastSceneX;
        if (delta === 0) return;

        actionTableRoot.resizeCommandCategory(delta);
        lastSceneX = sceneX;
    }

    Rectangle {
        anchors.centerIn: parent
        width: 2
        height: 12
        radius: 1
        color: parent.containsMouse ? "#808088" : "#3a3a40"
    }
}
                }

                Item {
                    id: categoryHeader

                    width:
                        actionTableRoot.categoryColumnWidth

                    height: parent.height

                    Text {
                        anchors.fill: parent
                        anchors.rightMargin: 18   // clears the 14px handle zone
                        verticalAlignment: Text.AlignVCenter
                        text: "CATEGORY"
                        color: "#52525e"
                        font.pixelSize: 9
                        font.bold: true
                        elide: Text.ElideRight
                    }

MouseArea {
    z: 100
    x: parent.width - 28
    width: 14
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.SizeHorCursor

    property real lastSceneX: 0

    onPressed: function(mouse) {
        lastSceneX = mapToItem(actionTableRoot, mouse.x, 0).x;
    }

    onPositionChanged: function(mouse) {
        if (!pressed) return;

        var sceneX = mapToItem(actionTableRoot, mouse.x, 0).x;
        var delta = sceneX - lastSceneX;
        if (delta === 0) return;

        actionTableRoot.resizeCategoryShortcut(delta);
        lastSceneX = sceneX;
    }

    Rectangle {
        anchors.centerIn: parent
        width: 2
        height: 12
        radius: 1
        color: parent.containsMouse ? "#808088" : "#3a3a40"
    }
}
                }

                Item {
                    id: shortcutHeader

                    width:
                        actionTableRoot.shortcutColumnWidth

                    height: parent.height

                    Text {
                        anchors.fill: parent
                        anchors.rightMargin: 8   // clears the 14px handle zone

                        verticalAlignment:
                            Text.AlignVCenter

                        horizontalAlignment:
                            Text.AlignRight

                        text: "CURRENT SHORTCUT"

                        color: "#52525e"

                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }

        // ========================================================
        // ACTION TABLE
        // ========================================================

        ListView {
            id: actionTable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true

            spacing: 2

            model: {
                var rev = dialogRoot.shortcutRevision;

                var all =
                    shortcutManager.getAllActions();

                var filtered = [];

                for (var i = 0; i < all.length; ++i) {
                    var matchesCategory =
                        dialogRoot.selectedCategory === "All"
                        || all[i].category ===
                           dialogRoot.selectedCategory;

                    var matchesSearch =
                        dialogRoot.searchQuery === ""
                        || all[i].name
                               .toLowerCase()
                               .indexOf(
                                   dialogRoot.searchQuery
                               ) !== -1
                        || all[i].category
                               .toLowerCase()
                               .indexOf(
                                   dialogRoot.searchQuery
                               ) !== -1
                        || (
                            all[i].currentKey
                            && all[i].currentKey
                                   .toLowerCase()
                                   .indexOf(
                                       dialogRoot.searchQuery
                                   ) !== -1
                        );

                    if (matchesCategory && matchesSearch)
                        filtered.push(all[i]);
                }

                return filtered;
            }

            delegate: Rectangle {
                id: actionRow

                width:
                    actionTable.width

                height: 34

                readonly property bool isSelected:
                    dialogRoot.selectedActionFromList
                    && dialogRoot.selectedActionFromList.id ===
                       modelData.id

                color:
                    isSelected
                    ? "#2d2d2d"
                    : (
                        rowM.containsMouse
                        ? "#1f1e1e"
                        : "transparent"
                    )

                radius: 3

                Row {
                    anchors.fill: parent
        anchors.leftMargin: 8     // this is your "padding" — pushes children in
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
                    spacing: 0

                    Item {
                        width:
                            actionTableRoot.commandColumnWidth

                        height: parent.height

                        Text {
                            anchors.fill: parent

                            verticalAlignment:
                                Text.AlignVCenter

                            text:
                                modelData.name

                            color:
                                actionRow.isSelected
                                ? "#ffffff"
                                : "#d0d0d8"

                            font.pixelSize: 11

                            // font.weight:
                            //     actionRow.isSelected
                            //     ? Font.DemiBold
                            //     : Font.Normal

                            elide:
                                Text.ElideRight
                        }
                    }

                    Item {
                        width:
                            actionTableRoot.categoryColumnWidth

                        height: parent.height

                        Text {
                            anchors.fill: parent

                            verticalAlignment:
                                Text.AlignVCenter

                            text:
                                modelData.category

                            color: "#727282"

                            font.pixelSize: 10
                        }
                    }

                    Item {
                        width:
                            actionTableRoot.shortcutColumnWidth

                        height: parent.height

                        Row {
                            anchors.right:
                                parent.right

                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 4

                            property var keyTokens: {
                                var rawShortcut =
                                    modelData.currentKey || "";

                                return rawShortcut
                                       ? rawShortcut.split("+")
                                       : [];
                            }

                            Repeater {
                                model:
                                    parent.keyTokens

                                delegate: Item {
                                    id: shortcutTokenItem

                                    property string keyText:
                                        modelData.trim()

                                    property string iconSrc:
                                        detailsPanelRoot.getModifierIcon
                                        ? detailsPanelRoot.getModifierIcon(
                                              keyText
                                          )
                                        : ""

                                    property bool isModifier:
                                        iconSrc !== ""

                                    implicitWidth:
                                        isModifier
                                        ? 24
                                        : Math.max(
                                              24,
                                              shortcutLetterLabel
                                                  .implicitWidth + 10
                                          )

                                    implicitHeight: 24

                                    Rectangle {
                                        anchors.fill: parent

                                        radius: 6

                                        color: "#1b1b1b"
                                    }

                                    Image {
                                        anchors.centerIn: parent

                                        width: 14
                                        height: 14

                                        source:
                                            shortcutTokenItem.iconSrc

                                        sourceSize:
                                            Qt.size(14, 14)

                                        fillMode:
                                            Image.PreserveAspectFit

                                        visible:
                                            shortcutTokenItem.isModifier
                                    }

                                    Text {
                                        id: shortcutLetterLabel

                                        anchors.centerIn: parent

                                        visible:
                                            !shortcutTokenItem.isModifier

                                        text:
                                            shortcutTokenItem.keyText

                                        color: "#e0e0e0"

                                        font.pixelSize: 11
                                        font.family: "Monospace"
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            Text {
                                visible:
                                    parent.keyTokens.length === 0

                                text: "-"

                                color: "#444450"

                                font.pixelSize: 9
                                font.family: "Monospace"

                                anchors.verticalCenter:
                                    parent.verticalCenter
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowM

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        dialogRoot.selectedActionFromList =
                            modelData;
                    }

                    onDoubleClicked: {
                        dialogRoot.selectedActionFromList =
                            modelData;

                        var seq =
                            dialogRoot.buildCurrentSequence(
                                dialogRoot.selectedKeyName
                            );

                        shortcutManager.setKeySequence(
                            modelData.id,
                            seq
                        );
                    }
                }
            }
        }
      }
      }
    }
}
            // Rectangle {
            //     Layout.fillWidth: true
            //     Layout.fillHeight: true
            //     color: "#1a1a1a"
            //     border.color: "#2d2d2d"
            //     border.width: 1
            //     radius: 6
            //
            //     ColumnLayout {
            //         anchors.fill: parent
            //         anchors.margins: 12
            //         spacing: 8
            //
            //         // Search & Category Filters
            //         RowLayout {
            //             Layout.fillWidth: true
            //             spacing: 8
            //
            //             // Search Input Field
            //             Rectangle {
            //                 Layout.preferredWidth: 220
            //                 height: 28
            //                 color: "#181818"
            //                 border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
            //                 border.width: 1
            //                 radius: 4
            //
            //                 RowLayout {
            //                     anchors.fill: parent
            //                     anchors.leftMargin: 8
            //                     anchors.rightMargin: 8
            //                     spacing: 6
            //
            //                     Image {
            //                         source: "qrc:/assets/icons/search.svg"
            //                         sourceSize.width: 11
            //                         sourceSize.height: 11
            //                         visible: status === Image.Ready
            //                     }
            //
            //                     TextInput {
            //                         id: searchInput
            //                         Layout.fillWidth: true
            //                         color: "#ffffff"
            //                         font.pixelSize: 11
            //                         selectByMouse: true
            //                         clip: true
            //                         onTextChanged: dialogRoot.searchQuery = text.toLowerCase().trim()
            //
            //                         Text {
            //                             text: "Search actions..."
            //                             color: "#71717a"
            //                             font: parent.font
            //                             visible: !parent.text && !parent.activeFocus
            //                             anchors.fill: parent
            //                             verticalAlignment: Text.AlignVCenter
            //                         }
            //                     }
            //                 }
            //             }
            //
            //             // Category Selector Bar with Animated Sliding Indicator
            //             Rectangle {
            //                 id: categoryContainer
            //                 height: 28
            //                 implicitWidth: categoryRow.implicitWidth + 4
            //                 color: "#181818"
            //                 border.color: "#2d2d2d"
            //                 border.width: 1
            //                 radius: 6
            //
            //                 readonly property var categories: ["All", "Edit", "Tools", "Playback", "Timeline"]
            //                 property Item activeTargetItem: null
            //
            //                 Rectangle {
            //                     id: categoryIndicator
            //                     height: parent.height - 4
            //                     y: 2
            //                     radius: 4
            //                     color: "#11389F"
            //                     border.color: "#2555D3"
            //                     border.width: 1
            //
            //                     x: categoryContainer.activeTargetItem ? categoryContainer.activeTargetItem.x + 2 : 2
            //                     width: categoryContainer.activeTargetItem ? categoryContainer.activeTargetItem.width : 0
            //
            //                     Behavior on x {
            //                         NumberAnimation {
            //                             duration: 220
            //                             easing.type: Easing.OutQuint
            //                         }
            //                     }
            //
            //                     Behavior on width {
            //                         NumberAnimation {
            //                             duration: 220
            //                             easing.type: Easing.OutQuint
            //                         }
            //                     }
            //                 }
            //
            //                 Row {
            //                     id: categoryRow
            //                     anchors.fill: parent
            //                     anchors.margins: 2
            //                     spacing: 0
            //
            //                     Repeater {
            //                         model: categoryContainer.categories
            //
            //                         Item {
            //                             id: pillRoot
            //                             height: categoryContainer.height - 4
            //                             width: pillText.implicitWidth + 16
            //
            //                             readonly property bool isSelected: dialogRoot.selectedCategory === modelData
            //
            //                             onIsSelectedChanged: {
            //                                 if (isSelected) {
            //                                     categoryContainer.activeTargetItem = pillRoot;
            //                                 }
            //                             }
            //
            //                             Component.onCompleted: {
            //                                 if (isSelected) {
            //                                     categoryContainer.activeTargetItem = pillRoot;
            //                                 }
            //                             }
            //
            //                             Text {
            //                                 id: pillText
            //                                 anchors.centerIn: parent
            //                                 text: modelData
            //                                 color: pillRoot.isSelected ? "#ffffff" : (pillMouse.containsMouse ? "#ffffff" : "#a1a1aa")
            //                                 font.pixelSize: 11
            //                                 font.weight: pillRoot.isSelected ? Font.DemiBold : Font.Normal
            //
            //                                 Behavior on color {
            //                                     ColorAnimation {
            //                                         duration: 150
            //                                     }
            //                                 }
            //                             }
            //
            //                             MouseArea {
            //                                 id: pillMouse
            //                                 anchors.fill: parent
            //                                 hoverEnabled: true
            //                                 cursorShape: Qt.PointingHandCursor
            //                                 onClicked: dialogRoot.selectedCategory = modelData
            //                             }
            //                         }
            //                     }
            //                 }
            //             }
            //
            //             Item {
            //                 Layout.fillWidth: true
            //             }
            //
            //             // Direct Assign Button using Outline mode (No Opacity)
            //             XylaTextButton {
            //                 Layout.preferredHeight: 28
            //                 Layout.maximumWidth: 220
            //                 topPadding: 0
            //                 bottomPadding: 0
            //                 leftPadding: 12
            //                 rightPadding: 12
            //                 outline: true
            //                 enabled: dialogRoot.selectedActionFromList !== null
            //                 text: "Assign to [" + dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName) + "]"
            //
            //                 onClicked: {
            //                     if (dialogRoot.selectedActionFromList) {
            //                         var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
            //                         shortcutManager.setKeySequence(dialogRoot.selectedActionFromList.id, seq);
            //                     }
            //                 }
            //             }
            //         }
            //
            //         // Table Header
            //         Rectangle {
            //             Layout.fillWidth: true
            //             height: 22
            //             color: "#101013"
            //             radius: 3
            //
            //             RowLayout {
            //                 anchors.fill: parent
            //                 anchors.leftMargin: 10
            //                 anchors.rightMargin: 10
            //                 spacing: 8
            //
            //                 Text {
            //                     text: "COMMAND"
            //                     color: "#52525e"
            //                     font.pixelSize: 9
            //                     font.bold: true
            //                     Layout.fillWidth: true
            //                 }
            //                 Text {
            //                     text: "CATEGORY"
            //                     color: "#52525e"
            //                     font.pixelSize: 9
            //                     font.bold: true
            //                     Layout.preferredWidth: 100
            //                 }
            //                 Text {
            //                     text: "CURRENT SHORTCUT"
            //                     color: "#52525e"
            //                     font.pixelSize: 9
            //                     font.bold: true
            //                     Layout.preferredWidth: 120
            //                     horizontalAlignment: Text.AlignRight
            //                 }
            //             }
            //         }
            //
            //         // Action Table List
            //         ListView {
            //             id: actionTable
            //             Layout.fillWidth: true
            //             Layout.fillHeight: true
            //             clip: true
            //             spacing: 2
            //
            //             model: {
            //                 var rev = dialogRoot.shortcutRevision;
            //                 var all = shortcutManager.getAllActions();
            //                 var filtered = [];
            //                 for (var i = 0; i < all.length; ++i) {
            //                     var matchesCategory = (dialogRoot.selectedCategory === "All" || all[i].category === dialogRoot.selectedCategory);
            //                     var matchesSearch = (dialogRoot.searchQuery === "" || all[i].name.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1 || all[i].category.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1 || (all[i].currentKey && all[i].currentKey.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1));
            //                     if (matchesCategory && matchesSearch)
            //                         filtered.push(all[i]);
            //                 }
            //                 return filtered;
            //             }
            //
            //             delegate: Rectangle {
            //                 width: actionTable.width
            //                 height: 26
            //                 readonly property bool isSelected: dialogRoot.selectedActionFromList && dialogRoot.selectedActionFromList.id === modelData.id
            //                 color: isSelected ? "#222530" : (rowM.containsMouse ? "#1f1e1e" : "transparent")
            //                 border.color: isSelected ? "#384259" : "transparent"
            //                 border.width: 1
            //                 radius: 3
            //
            //                 RowLayout {
            //                     anchors.fill: parent
            //                     anchors.leftMargin: 10
            //                     anchors.rightMargin: 10
            //                     spacing: 8
            //
            //                     Text {
            //                         text: modelData.name
            //                         color: isSelected ? "#ffffff" : "#d0d0d8"
            //                         font.pixelSize: 11
            //                         font.weight: isSelected ? Font.DemiBold : Font.Normal
            //                         Layout.fillWidth: true
            //                         elide: Text.ElideRight
            //                     }
            //
            //                     Text {
            //                         text: modelData.category
            //                         color: "#727282"
            //                         font.pixelSize: 10
            //                         Layout.preferredWidth: 100
            //                     }
            //
            //                     Rectangle {
            //                         Layout.preferredWidth: 120
            //                         height: 18
            //                         radius: 3
            //                         color: modelData.currentKey ? "#1a1a1a" : "transparent"
            //                         border.color: modelData.currentKey ? "#2c2c3e" : "transparent"
            //
            //                         Text {
            //                             anchors.centerIn: parent
            //                             text: modelData.currentKey || "-"
            //                             color: modelData.currentKey ? "#e4e4ed" : "#444450"
            //                             font.pixelSize: 9
            //                             font.family: "Monospace"
            //                             font.weight: modelData.currentKey ? Font.DemiBold : Font.Normal
            //                         }
            //                     }
            //                 }
            //
            //                 MouseArea {
            //                     id: rowM
            //                     anchors.fill: parent
            //                     hoverEnabled: true
            //                     cursorShape: Qt.PointingHandCursor
            //                     onClicked: dialogRoot.selectedActionFromList = modelData
            //                     onDoubleClicked: {
            //                         dialogRoot.selectedActionFromList = modelData;
            //                         var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
            //                         shortcutManager.setKeySequence(modelData.id, seq);
            //                     }
            //                 }
            //             }
            //         }
            //     }
            // }
        }

        // =====================================================================
        // 1. TOP HEADER TOOLBAR
        // =====================================================================
Rectangle {
    Layout.fillWidth: true
    height: 40
    color: "#131313"
    // border.color: "#2d2d2d"
    // border.width: 1
    radius: 6

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // Text {
        //     text: "PRESET"
        //     color: "#555562"
        //     font.pixelSize: 9
        //     font.bold: true
        //     font.letterSpacing: 1.0
        //     Layout.alignment: Qt.AlignVCenter
        // }

        XylaSelect {
            id: presetSelect
            Layout.preferredWidth: 190
            // Layout.preferredHeight: 28
            // Layout.alignment: Qt.AlignVCenter
            icon: "qrc:/assets/icons/keyboard.svg"
            tooltip: "Select Preset"
            highlightedColor: "#262632"
            model: shortcutManager.availablePresets
            currentIndex: {
                var cur = shortcutManager.activePresetName;
                for (var i = 0; i < model.length; i++) {
                    if (model[i] === cur)
                        return i;
                }
                return 0;
            }
            onActivated: index => {
                shortcutManager.activePresetName = model[index];
            }
        }

        XylaIconButton {
            id: addPresetBtn
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
            ghost: true
            iconSource: "qrc:/assets/icons/plus.svg"
            tooltip: "New Preset"
            onClicked: newPresetDialog.open()
        }

        XylaIconButton {
            id: delPresetBtn
            // Layout.preferredWidth: 28
            // Layout.preferredHeight: 28
            // Layout.alignment: Qt.AlignVCenter
            ghost: true
            iconSource: "qrc:/assets/icons/minus.svg"
            iconColor: "#ff3355"
            tooltip: "Delete Preset"
            visible: {
                var defaults = ["Xyla Default", "DaVinci Resolve", "Adobe Premiere Pro", "Apple Final Cut Pro", "Avid Media Composer"];
                return defaults.indexOf(shortcutManager.activePresetName) === -1;
            }
            onClicked: shortcutManager.deleteCustomPreset(shortcutManager.activePresetName)
        }

        Item {
            Layout.fillWidth: true
        }

        // Text {
        //     text: "MODIFIERS"
        //     color: "#555562"
        //     font.pixelSize: 9
        //     font.bold: true
        //     font.letterSpacing: 1.0
        //     Layout.alignment: Qt.AlignVCenter
        // }
        //
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

    XylaIconButton {
        id: modCtrlBtn
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        primary: dialogRoot.modCtrl
        iconSource: "qrc:/assets/icons/ctrl.svg"
        tooltip: "Toggle Ctrl/Command Modifier"
        onClicked: dialogRoot.modCtrl = !dialogRoot.modCtrl
    }

    XylaIconButton {
        id: modShiftBtn
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        primary: dialogRoot.modShift
        iconSource: "qrc:/assets/icons/shift.svg"
        tooltip: "Toggle Shift Modifier"
        onClicked: dialogRoot.modShift = !dialogRoot.modShift
    }

    XylaIconButton {
        id: modAltBtn
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        primary: dialogRoot.modAlt
        iconSource: "qrc:/assets/icons/alt.svg"
        tooltip: "Toggle Alt/Option Modifier"
        onClicked: dialogRoot.modAlt = !dialogRoot.modAlt
    }

    XylaIconButton {
        id: modCmdBtn
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        primary: dialogRoot.modMeta
        iconSource: "qrc:/assets/icons/win.svg"
        tooltip: "Toggle Win Modifier"
        onClicked: dialogRoot.modMeta = !dialogRoot.modMeta
    }
        }

        Rectangle {
            width: 1
            height: 18
            color: "#25252d"
            Layout.alignment: Qt.AlignVCenter
        }

        XylaIconButton {
            id: resetBtn
            // Layout.preferredHeight: 28
            // Layout.alignment: Qt.AlignVCenter
            ghost: true
            iconSource: "qrc:/assets/icons/clear.svg"
            iconColor: "#ff3355"
            tooltip: "Reset All Shortcuts to Default"
            onClicked: shortcutManager.resetAllToDefault()
        }
    }
}


Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 330

        // Hidden dummy shape for shadow generation
        Rectangle {
            id: shadowSource
            anchors.fill: parent
            radius: 20
            visible: false
        }

        // Shadow element
        MultiEffect {
            anchors.fill: shadowSource
            source: shadowSource
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.6
            shadowVerticalOffset: 5
        }
        // =====================================================================
        // 2. FULL PHYSICAL DESKTOP KEYBOARD + NUMPAD
        // =====================================================================
        Rectangle {
            id: panel
            anchors.fill: parent
            // Layout.fillWidth: true
            // Layout.preferredHeight: 330
            color: "#191919"
            // border.color: "#1d1d1d"
            // border.width: 1
            radius: 20

Row {
    anchors.centerIn: parent
    spacing: 28

    // =============================================================
    // A. MAIN QWERTY CLUSTER
    // =============================================================
    Column {
        spacing: 6

        // ---------------------------------------------------------
        // Function row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Esc"
                keyWidth: 46 // 44
                keyHeight: 28
                isSpecial: true
            }

            // Spacer between Esc and F1-F4
            Item {
                width: 10
                height: 28
            }

            KeyCap {
                primaryKey: "F1"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F2"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F3"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F4"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            // Spacer between F4 and F5
            Item {
                width: 10
                height: 28
            }

            KeyCap {
                primaryKey: "F5"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F6"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F7"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F8"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            // Spacer between F8 and F9
            Item {
                width: 10
                height: 28
            }

            KeyCap {
                primaryKey: "F9"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F10"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F11"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "F12"
                keyWidth: 48
                keyHeight: 28
                isSpecial: true
            }

            // Extend the function row to the exact width
            // of the number row through Backspace.
            // Item {
            //     width: 74
            //     height: 28
            // }
        }

        // ---------------------------------------------------------
        // Vertical spacer between function row and normal blocks
        // ---------------------------------------------------------
        Item {
            width: 1
            height: 4
        }

        // ---------------------------------------------------------
        // Number Row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "`"
                shiftKey: "~"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "1"
                shiftKey: "!"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "2"
                shiftKey: "@"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "3"
                shiftKey: "#"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "4"
                shiftKey: "$"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "5"
                shiftKey: "%"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "6"
                shiftKey: "^"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "7"
                shiftKey: "&"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "8"
                shiftKey: "*"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "9"
                shiftKey: "("
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "0"
                shiftKey: ")"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "-"
                shiftKey: "_"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "="
                shiftKey: "+"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "Backspace"
                labelOverride: "Backsp"
                iconSource: "qrc:/assets/icons/arrow-left.svg"
                showIconAndText: true
                iconTextPosition: "icon-left"
                iconTextSpacing: 5
                iconSize: 14
                keyWidth: 92
                isSpecial: true
            }
        }

        // ---------------------------------------------------------
        // Tab / QWERTY Row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Tab"
                labelOverride: "Tab"
                iconSource: "qrc:/assets/icons/tab.svg"
                showIconAndText: true
                iconTextPosition: "text-left"
                iconTextSpacing: 5
                iconSize: 13
                keyWidth: 66
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Q"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "W"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "E"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "R"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "T"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "Y"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "U"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "I"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "O"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "P"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "["
                shiftKey: "{"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "]"
                shiftKey: "}"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "\\"
                shiftKey: "|"
                keyWidth: 70
                isSpecial: true
            }
        }

        // ---------------------------------------------------------
        // Caps / ASDF Row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Caps"
                labelOverride: "Caps"
                keyWidth: 78
                isSpecial: true
            }

            KeyCap {
                primaryKey: "A"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "S"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "D"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "F"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "G"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "H"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "J"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "K"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "L"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: ";"
                shiftKey: ":"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "'"
                shiftKey: "\""
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "Return"
                labelOverride: "Enter"
                iconSource: "qrc:/assets/icons/enter.svg"
                showIconAndText: true
                iconTextPosition: "icon-left"
                iconTextSpacing: 5
                iconSize: 14
                keyWidth: 108
                isAccentReturn: true
            }
        }

        // ---------------------------------------------------------
        // Shift / ZXCV Row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            // Left Shift = icon first, then text
            KeyCap {
                primaryKey: "Shift"
                labelOverride: "Shift"
                iconSource: "qrc:/assets/icons/shift.svg"
                showIconAndText: true
                iconTextPosition: "text-left"
                iconTextSpacing: 5
                iconSize: 14
                keyWidth: 98
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modShift
            }

            KeyCap {
                primaryKey: "Z"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "X"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "C"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "V"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "B"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "N"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "M"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: ","
                shiftKey: "<"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "."
                shiftKey: ">"
                keyWidth: 44
            }

            KeyCap {
                primaryKey: "/"
                shiftKey: "?"
                keyWidth: 44
            }

            // Right Shift = text first, then icon
            KeyCap {
                primaryKey: "Shift"
                labelOverride: "Shift"
                iconSource: "qrc:/assets/icons/shift.svg"
                showIconAndText: true
                iconTextPosition: "icon-left"
                iconTextSpacing: 5
                iconSize: 14
                keyWidth: 138
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modShift
            }
        }

        // ---------------------------------------------------------
        // Bottom Modifier Row
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Ctrl"
                iconSource: "qrc:/assets/icons/ctrl.svg"
                keyWidth: 56
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modCtrl
            }

            KeyCap {
                primaryKey: "Win"
                iconSource: "qrc:/assets/icons/win.svg"
                keyWidth: 48
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modMeta
            }

            KeyCap {
                primaryKey: "Alt"
                iconSource: "qrc:/assets/icons/alt.svg"
                keyWidth: 52
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modAlt
            }

            KeyCap {
                primaryKey: "Space"
                iconSource: "qrc:/assets/icons/space.svg"
                keyWidth: 340
            }

            KeyCap {
                primaryKey: "Alt"
                iconSource: "qrc:/assets/icons/alt.svg"
                keyWidth: 52
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modAlt
            }

            KeyCap {
                primaryKey: "Win"
                iconSource: "qrc:/assets/icons/win.svg"
                keyWidth: 48
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modMeta
            }

            KeyCap {
                primaryKey: "Menu"
                iconSource: "qrc:/assets/icons/menu.svg"
                keyWidth: 48
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Ctrl"
                iconSource: "qrc:/assets/icons/ctrl.svg"
                keyWidth: 56
                isSpecial: true
                isModifierToggle: true
                isModifierActive: dialogRoot.modCtrl
            }
        }
    }

    // =============================================================
    // B. NAVIGATION & SYSTEM CLUSTER
    // =============================================================
    Column {
        spacing: 6

        // ---------------------------------------------------------
        // Top system family
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "PrtSc"
                labelOverride: "Prt"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "ScrLk"
                labelOverride: "Scr"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Pause"
                labelOverride: "Pau"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }
        }

        // ---------------------------------------------------------
        // Vertical spacer between Prt/Scr/Pau and normal block
        // ---------------------------------------------------------
        Item {
            width: 1
            height: 4
        }

        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Ins"
                labelOverride: "Ins"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Home"
                labelOverride: "Home"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "PgUp"
                labelOverride: "PgUp"
                keyWidth: 44
                isSpecial: true
            }
        }

        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Delete"
                labelOverride: "Del"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "End"
                labelOverride: "End"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "PgDn"
                labelOverride: "PgDn"
                keyWidth: 44
                isSpecial: true
            }
        }

        Item {
            width: 140
            height: 44
        }

        Row {
            spacing: 6

            Item {
                width: 44
                height: 44
            }

            KeyCap {
                primaryKey: "Up"
                iconSource: "qrc:/assets/icons/arrow-up.svg"
                keyWidth: 44
                isSpecial: true
            }

            Item {
                width: 44
                height: 44
            }
        }

        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Left"
                iconSource: "qrc:/assets/icons/arrow-left.svg"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Down"
                iconSource: "qrc:/assets/icons/arrow-down.svg"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Right"
                iconSource: "qrc:/assets/icons/arrow-right.svg"
                keyWidth: 44
                isSpecial: true
            }
        }
    }

    // =============================================================
    // C. NUMPAD CLUSTER
    // =============================================================
    Column {
        spacing: 6

        // ---------------------------------------------------------
        // Top numpad/system family
        // ---------------------------------------------------------
        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Cal"
                labelOverride: "Cal"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Mute"
                labelOverride: "Mut"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Vol-"
                labelOverride: "V-"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Vol+"
                labelOverride: "V+"
                keyWidth: 44
                keyHeight: 28
                isSpecial: true
            }
        }

        // ---------------------------------------------------------
        // Vertical spacer between top family and normal numpad
        // ---------------------------------------------------------
        Item {
            width: 1
            height: 4
        }

        Row {
            spacing: 6

            KeyCap {
                primaryKey: "Num"
                labelOverride: "Num"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Num/"
                labelOverride: "/"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Num*"
                labelOverride: "*"
                keyWidth: 44
                isSpecial: true
            }

            KeyCap {
                primaryKey: "Num-"
                labelOverride: "-"
                keyWidth: 44
                isSpecial: true
            }
        }

        Row {
            spacing: 6

            Column {
                spacing: 6

                Row {
                    spacing: 6

                    KeyCap {
                        primaryKey: "Num7"
                        labelOverride: "7"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num8"
                        labelOverride: "8"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num9"
                        labelOverride: "9"
                        keyWidth: 44
                    }
                }

                Row {
                    spacing: 6

                    KeyCap {
                        primaryKey: "Num4"
                        labelOverride: "4"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num5"
                        labelOverride: "5"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num6"
                        labelOverride: "6"
                        keyWidth: 44
                    }
                }
            }

            KeyCap {
                primaryKey: "Num+"
                labelOverride: "+"
                keyWidth: 44
                keyHeight: 92
                isSpecial: true
            }
        }

        Row {
            spacing: 6

            Column {
                spacing: 6

                Row {
                    spacing: 6

                    KeyCap {
                        primaryKey: "Num1"
                        labelOverride: "1"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num2"
                        labelOverride: "2"
                        keyWidth: 44
                    }

                    KeyCap {
                        primaryKey: "Num3"
                        labelOverride: "3"
                        keyWidth: 44
                    }
                }

                Row {
                    spacing: 6

                    KeyCap {
                        primaryKey: "Num0"
                        labelOverride: "0"
                        keyWidth: 92
                    }

                    KeyCap {
                        primaryKey: "Num."
                        labelOverride: "."
                        keyWidth: 44
                    }
                }
            }

            KeyCap {
                primaryKey: "NumEnter"
                labelOverride: "Enter"
                iconSource: "qrc:/assets/icons/enter.svg"
                // showIconAndText: true
                iconTextPosition: "icon-left"
                iconTextSpacing: 4
                iconSize: 13
                keyWidth: 44
                keyHeight: 92
                isAccentReturn: true
            }
        }
    }
}
            // Row {
            //     anchors.centerIn: parent
            //     spacing: 20
            //
            //     Column {
            //         spacing: 6
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Esc"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             Item {
            //                 width: 10
            //                 height: 28
            //             }
            //             KeyCap {
            //                 primaryKey: "F1"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F2"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F3"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F4"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             Item {
            //                 width: 8
            //                 height: 28
            //             }
            //             KeyCap {
            //                 primaryKey: "F5"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F6"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F7"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F8"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             Item {
            //                 width: 8
            //                 height: 28
            //             }
            //             KeyCap {
            //                 primaryKey: "F9"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F10"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F11"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "F12"
            //                 keyWidth: 42
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //         }
            //
            //         // Number Row
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "`"
            //                 shiftKey: "~"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "1"
            //                 shiftKey: "!"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "2"
            //                 shiftKey: "@"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "3"
            //                 shiftKey: "#"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "4"
            //                 shiftKey: "$"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "5"
            //                 shiftKey: "%"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "6"
            //                 shiftKey: "^"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "7"
            //                 shiftKey: "&"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "8"
            //                 shiftKey: "*"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "9"
            //                 shiftKey: "("
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "0"
            //                 shiftKey: ")"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "-"
            //                 shiftKey: "_"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "="
            //                 shiftKey: "+"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "Backspace"
            //                 labelOverride: "Bksp"
            //                 keyWidth: 92
            //                 isSpecial: true
            //             }
            //         }
            //
            //         // Tab / QWERTY Row
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Tab"
            //                 labelOverride: "Tab"
            //                 keyWidth: 66
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Q"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "W"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "E"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "R"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "T"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "Y"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "U"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "I"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "O"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "P"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "["
            //                 shiftKey: "{"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "]"
            //                 shiftKey: "}"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "\\"
            //                 shiftKey: "|"
            //                 keyWidth: 70
            //                 isSpecial: true
            //             }
            //         }
            //
            //         // Caps / ASDF Row
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Caps"
            //                 labelOverride: "Caps"
            //                 keyWidth: 78
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "A"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "S"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "D"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "F"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "G"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "H"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "J"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "K"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "L"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: ";"
            //                 shiftKey: ":"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "'"
            //                 shiftKey: "\""
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "Return"
            //                 labelOverride: "Return"
            //                 keyWidth: 106
            //                 isAccentReturn: true
            //             }
            //         }
            //
            //         // Shift / ZXCV Row
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Shift"
            //                 labelOverride: "Shift"
            //                 keyWidth: 98
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modShift
            //             }
            //             KeyCap {
            //                 primaryKey: "Z"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "X"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "C"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "V"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "B"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "N"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "M"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: ","
            //                 shiftKey: "<"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "."
            //                 shiftKey: ">"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "/"
            //                 shiftKey: "?"
            //                 keyWidth: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "Shift"
            //                 labelOverride: "Shift"
            //                 keyWidth: 134
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modShift
            //             }
            //         }
            //
            //         // Bottom Modifier Row
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Ctrl"
            //                 labelOverride: "Ctrl"
            //                 keyWidth: 56
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modCtrl
            //             }
            //             KeyCap {
            //                 primaryKey: "Win"
            //                 labelOverride: "Win"
            //                 keyWidth: 48
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modMeta
            //             }
            //             KeyCap {
            //                 primaryKey: "Alt"
            //                 labelOverride: "Alt"
            //                 keyWidth: 52
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modAlt
            //             }
            //             KeyCap {
            //                 primaryKey: "Space"
            //                 labelOverride: "Space"
            //                 keyWidth: 328
            //             }
            //             KeyCap {
            //                 primaryKey: "Alt"
            //                 labelOverride: "Alt"
            //                 keyWidth: 52
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modAlt
            //             }
            //             KeyCap {
            //                 primaryKey: "Win"
            //                 labelOverride: "Win"
            //                 keyWidth: 48
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modMeta
            //             }
            //             KeyCap {
            //                 primaryKey: "Menu"
            //                 labelOverride: "Menu"
            //                 keyWidth: 48
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Ctrl"
            //                 labelOverride: "Ctrl"
            //                 keyWidth: 56
            //                 isSpecial: true
            //                 isModifierToggle: true
            //                 isModifierActive: dialogRoot.modCtrl
            //             }
            //         }
            //     }
            //
            //     // -------------------------------------------------------------
            //     // B. NAVIGATION & SYSTEM CLUSTER (Width: 140px)
            //     // -------------------------------------------------------------
            //     Column {
            //         spacing: 6
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "PrtSc"
            //                 labelOverride: "Prt"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "ScrLk"
            //                 labelOverride: "Scr"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Pause"
            //                 labelOverride: "Pau"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Ins"
            //                 labelOverride: "Ins"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Home"
            //                 labelOverride: "Home"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "PgUp"
            //                 labelOverride: "PgUp"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Delete"
            //                 labelOverride: "Del"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "End"
            //                 labelOverride: "End"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "PgDn"
            //                 labelOverride: "PgDn"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Item {
            //             width: 140
            //             height: 44
            //         }
            //
            //         Row {
            //             spacing: 6
            //             Item {
            //                 width: 44
            //                 height: 44
            //             }
            //             KeyCap {
            //                 primaryKey: "Up"
            //                 labelOverride: "Up"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             Item {
            //                 width: 44
            //                 height: 44
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Left"
            //                 labelOverride: "Left"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Down"
            //                 labelOverride: "Down"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Right"
            //                 labelOverride: "Right"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //         }
            //     }
            //
            //     // -------------------------------------------------------------
            //     // C. NUMPAD CLUSTER (Width: 188px)
            //     // -------------------------------------------------------------
            //     Column {
            //         spacing: 6
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Cal"
            //                 labelOverride: "Cal"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Mute"
            //                 labelOverride: "Mut"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Vol-"
            //                 labelOverride: "V-"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Vol+"
            //                 labelOverride: "V+"
            //                 keyWidth: 44
            //                 keyHeight: 28
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //             KeyCap {
            //                 primaryKey: "Num"
            //                 labelOverride: "Num"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Num/"
            //                 labelOverride: "/"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Num*"
            //                 labelOverride: "*"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //             KeyCap {
            //                 primaryKey: "Num-"
            //                 labelOverride: "-"
            //                 keyWidth: 44
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //
            //             Column {
            //                 spacing: 6
            //                 Row {
            //                     spacing: 6
            //                     KeyCap {
            //                         primaryKey: "Num7"
            //                         labelOverride: "7"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num8"
            //                         labelOverride: "8"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num9"
            //                         labelOverride: "9"
            //                         keyWidth: 44
            //                     }
            //                 }
            //                 Row {
            //                     spacing: 6
            //                     KeyCap {
            //                         primaryKey: "Num4"
            //                         labelOverride: "4"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num5"
            //                         labelOverride: "5"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num6"
            //                         labelOverride: "6"
            //                         keyWidth: 44
            //                     }
            //                 }
            //             }
            //
            //             KeyCap {
            //                 primaryKey: "Num+"
            //                 labelOverride: "+"
            //                 keyWidth: 44
            //                 keyHeight: 92
            //                 isSpecial: true
            //             }
            //         }
            //
            //         Row {
            //             spacing: 6
            //
            //             Column {
            //                 spacing: 6
            //                 Row {
            //                     spacing: 6
            //                     KeyCap {
            //                         primaryKey: "Num1"
            //                         labelOverride: "1"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num2"
            //                         labelOverride: "2"
            //                         keyWidth: 44
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num3"
            //                         labelOverride: "3"
            //                         keyWidth: 44
            //                     }
            //                 }
            //                 Row {
            //                     spacing: 6
            //                     KeyCap {
            //                         primaryKey: "Num0"
            //                         labelOverride: "0"
            //                         keyWidth: 92
            //                     }
            //                     KeyCap {
            //                         primaryKey: "Num."
            //                         labelOverride: "."
            //                         keyWidth: 44
            //                     }
            //                 }
            //             }
            //
            //             KeyCap {
            //                 primaryKey: "NumEnter"
            //                 labelOverride: "Enter"
            //                 keyWidth: 44
            //                 keyHeight: 92
            //                 isAccentReturn: true
            //             }
            //         }
            //     }
            // }
        }
      }
    }

    // Keycap Component
component KeyCap: Rectangle {
    id: capRoot
    property string primaryKey: ""
    property string shiftKey: ""
    property string labelOverride: ""
    property string iconSource: "" // Optional icon source (e.g. "qrc:/assets/icons/...")

    // Icon + text configuration
    property bool showIconAndText: false
    property string iconTextPosition: "icon-left" // "icon-left" or "text-left"
    property real iconTextSpacing: 5
    property real iconSize: 14

    property real keyWidth: 44
    property real keyHeight: 44
    property bool isSpecial: false
    property bool isAccentReturn: false
    property bool isModifierToggle: false
    property bool isModifierActive: false

    // ---------------------------------------------------------------------
    // COLOR PALETTE & CONFIGURATION (Edit colors here)
    // ---------------------------------------------------------------------
    // Base Surface Colors
    readonly property color colorBaseNormal: "#222222"
    readonly property color colorBaseSpecial: "#131313"
    readonly property color colorClusterHighlight: "#22262c"

    // Interactive States - WASD / HJKL Cluster Keys
    readonly property color colorClusterHover: "#30343b"
    readonly property color colorClusterPress: "#454b55"
    readonly property color colorClusterSelected: "#414750"
    // readonly property color colorClusterPress: "#393e47"
    // readonly property color colorClusterSelected: "#373d46"

    // Interactive States - Normal Keys (RESTORED EXACT ORIGINALS)
    readonly property color colorNormalHover: "#303030"    // Exact original hover
    readonly property color colorNormalPress: "#3a3a3a"    // Exact original click press
    readonly property color colorNormalSelected: "#393939" // Exact original selected

    // Interactive States - Special / Modifier Keys (Pushed to distinct ranges to avoid blending)
    readonly property color colorSpecialHover: "#0E0E0E"    // Distinct from normal idle (#202020) and hover (#252525)
    readonly property color colorSpecialPress: "#070707"
    readonly property color colorSpecialSelected: "#090909" // Distinct from normal selected (#303030)
    readonly property color colorModifierActive: "#080808"

    // Accent / Special Overrides
    readonly property color colorAccentReturnSelected: "#3a4c6f"
    readonly property color colorBlueAccentText: "#60a5fa"

    // Indicator Dot
    readonly property color colorIndicatorActive: "#ffffff"
    readonly property color colorIndicatorInactive: "#666666"

    // Text & Label Colors
    readonly property color colorTextNormal: "#e0e0e0"
    readonly property color colorTextSelected: "#ffffff"
    readonly property color colorTextSpecialIdle: "#999999"
    readonly property color colorTextSpecialHover: "#cccccc"
    readonly property color colorTextShiftIdle: "#666666"

    // ---------------------------------------------------------------------
    // GEOMETRY & LOGIC
    // ---------------------------------------------------------------------
    width: keyWidth
    height: keyHeight

    readonly property var mappedAction: dialogRoot.getActionForKey(primaryKey, dialogRoot.shortcutRevision)
    readonly property bool hasAnyBound: dialogRoot.hasAnyShortcut(primaryKey, dialogRoot.shortcutRevision)
    readonly property bool isKeySelected: dialogRoot.selectedKeyName.toLowerCase() === primaryKey.toLowerCase()

    // Key group detection for keycap subtle highlighting
    readonly property string normKey: primaryKey.toLowerCase()
    readonly property bool isWASD: normKey === "w" || normKey === "a" || normKey === "s" || normKey === "d"
    readonly property bool isHJKL: normKey === "h" || normKey === "j" || normKey === "k" || normKey === "l"

    radius: 8

// Surface color evaluation using top palette vars
color: {
    // 1. Selected State
    if (isKeySelected) {
        if (isAccentReturn) return colorAccentReturnSelected;
        if (isWASD || isHJKL) return colorClusterSelected;
        return isSpecial ? colorSpecialSelected : colorNormalSelected;
    }

    // 2. Click Press State
    if (capMouse.pressed) {
        if (isWASD || isHJKL) return colorClusterPress;
        return isSpecial ? colorSpecialPress : colorNormalPress;
    }

    // 4. Active Toggle / Modifier State
    if (isModifierActive) return colorModifierActive;

    // 3. Hover State
    if (capMouse.containsMouse) {
        if (isWASD || isHJKL) return colorClusterHover;
        return isSpecial ? colorSpecialHover : colorNormalHover;
    }

    // 5. Cluster Highlights (WASD / HJKL)
    if (isWASD || isHJKL) return colorClusterHighlight;

    // 6. Idle Base States
    return isSpecial ? colorBaseSpecial : colorBaseNormal;
}

    // Animated color morphing on state changes
    Behavior on color {
        ColorAnimation {
            duration: capMouse.pressed ? 50 : 150
            easing.type: Easing.OutCubic
        }
    }

    // BORDERS PURGED (Commented out)
    // border.color: ...
    // border.width: ...

    // Indicator dot for shortcuts
    Rectangle {
        visible: isAccentReturn || hasAnyBound
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 4
        height: 4
        radius: 2
        color: isKeySelected ? colorIndicatorActive : (mappedAction ? colorIndicatorActive : colorIndicatorInactive)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        // Secondary Shift text
        Text {
            visible: capRoot.shiftKey !== "" &&
                     !capRoot.showIconAndText &&
                     capRoot.iconSource === ""

            text: capRoot.shiftKey
            color: dialogRoot.modShift ? colorBlueAccentText : (isKeySelected ? colorTextSelected : colorTextShiftIdle)
            font.pixelSize: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        // Primary Content: Render Icon if provided, otherwise render Text label

        // Render both icon and text when explicitly enabled
        Row {
            visible: capRoot.showIconAndText && capRoot.iconSource !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: capRoot.iconTextSpacing

            // Icon first: used for keys such as Left Shift
            Image {
                visible: capRoot.iconTextPosition === "icon-left"
                source: capRoot.iconSource
                width: capRoot.iconSize
                height: capRoot.iconSize
                fillMode: Image.PreserveAspectFit
                smooth: true
                anchors.verticalCenter: parent.verticalCenter
                opacity: capRoot.isKeySelected || capRoot.mappedAction ? 1.0 : 0.85

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }

            // Text first: used when the label should appear before the icon
            Text {
                visible: capRoot.iconTextPosition === "text-left"
                text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
                color: {
                    if (isKeySelected) return colorTextSelected;
                    if (mappedAction) return colorTextSelected;
                    if (isWASD || isHJKL) return colorBlueAccentText;
                    if (isSpecial) return capMouse.containsMouse ? colorTextSpecialHover : colorTextSpecialIdle;
                    return colorTextNormal;
                }
                font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
                font.weight: (isKeySelected || mappedAction || isWASD || isHJKL) ? Font.Medium : Font.Normal
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Text after icon
            Text {
                visible: capRoot.iconTextPosition === "icon-left"
                text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
                color: {
                    if (isKeySelected) return colorTextSelected;
                    if (mappedAction) return colorTextSelected;
                    if (isWASD || isHJKL) return colorBlueAccentText;
                    if (isSpecial) return capMouse.containsMouse ? colorTextSpecialHover : colorTextSpecialIdle;
                    return colorTextNormal;
                }
                font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
                font.weight: (isKeySelected || mappedAction || isWASD || isHJKL) ? Font.Medium : Font.Normal
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Icon after text
            Image {
                visible: capRoot.iconTextPosition === "text-left"
                source: capRoot.iconSource
                width: capRoot.iconSize
                height: capRoot.iconSize
                fillMode: Image.PreserveAspectFit
                smooth: true
                anchors.verticalCenter: parent.verticalCenter
                opacity: capRoot.isKeySelected || capRoot.mappedAction ? 1.0 : 0.85

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: capRoot.iconSource !== "" && !capRoot.showIconAndText
            sourceComponent: Image {
                source: capRoot.iconSource
                width: capRoot.iconSize + 3
                height: capRoot.iconSize + 3
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: capRoot.isKeySelected || capRoot.mappedAction ? 1.0 : 0.85

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        Text {
            visible: capRoot.iconSource === "" && !capRoot.showIconAndText
            text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
            color: {
                if (isWASD || isHJKL) return colorBlueAccentText;
                if (isKeySelected) return colorTextSelected;
                if (mappedAction) return colorTextSelected;
                if (isSpecial) return capMouse.containsMouse ? colorTextSpecialHover : colorTextSpecialIdle;
                return colorTextNormal;
            }
            font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
            font.weight: (isKeySelected || mappedAction || isWASD || isHJKL) ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: capMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (capRoot.isModifierToggle) {
                var lk = capRoot.primaryKey.toLowerCase();
                if (lk === "ctrl") dialogRoot.modCtrl = !dialogRoot.modCtrl;
                else if (lk === "shift") dialogRoot.modShift = !dialogRoot.modShift;
                else if (lk === "alt") dialogRoot.modAlt = !dialogRoot.modAlt;
                else if (lk === "win" || lk === "cmd") dialogRoot.modMeta = !dialogRoot.modMeta;
            } else {
                dialogRoot.selectedKeyName = capRoot.primaryKey;
            }
        }
    }
}
    // component KeyCap: Rectangle {
    //     id: capRoot
    //     property string primaryKey: ""
    //     property string shiftKey: ""
    //     property string labelOverride: ""
    //     property string iconSource: "" // Optional icon source (e.g. "qrc:/assets/icons/...")
    //     property real keyWidth: 44
    //     property real keyHeight: 44
    //     property bool isSpecial: false
    //     property bool isAccentReturn: false
    //     property bool isModifierToggle: false
    //     property bool isModifierActive: false
    //
    //     // ---------------------------------------------------------------------
    //     // COLOR PALETTE & CONFIGURATION (Edit colors here)
    //     // ---------------------------------------------------------------------
    //     // Base Surface Colors
    //     readonly property color colorBaseNormal: "#222222"
    //     readonly property color colorBaseSpecial: "#131313"
    //     readonly property color colorClusterHighlight: "#22262c"
    //
    //     // Interactive States - Normal Keys (RESTORED EXACT ORIGINALS)
    //     readonly property color colorNormalHover: "#303030"    // Exact original hover
    //     readonly property color colorNormalPress: "#393939"    // Exact original click press
    //     readonly property color colorNormalSelected: "#373737" // Exact original selected
    //
    //     // Interactive States - Special / Modifier Keys (Pushed to distinct ranges to avoid blending)
    //     readonly property color colorSpecialHover: "#0E0E0E"    // Distinct from normal idle (#202020) and hover (#252525)
    //     readonly property color colorSpecialPress: "#070707"
    //     readonly property color colorSpecialSelected: "#090909" // Distinct from normal selected (#303030)
    //     readonly property color colorModifierActive: "#080808"
    //
    //     // Accent / Special Overrides
    //     readonly property color colorAccentReturnSelected: "#2563eb"
    //     readonly property color colorBlueAccentText: "#60a5fa"
    //
    //     // Indicator Dot
    //     readonly property color colorIndicatorActive: "#ffffff"
    //     readonly property color colorIndicatorInactive: "#666666"
    //
    //     // Text & Label Colors
    //     readonly property color colorTextNormal: "#e0e0e0"
    //     readonly property color colorTextSelected: "#ffffff"
    //     readonly property color colorTextSpecialIdle: "#999999"
    //     readonly property color colorTextSpecialHover: "#cccccc"
    //     readonly property color colorTextShiftIdle: "#666666"
    //
    //     // ---------------------------------------------------------------------
    //     // GEOMETRY & LOGIC
    //     // ---------------------------------------------------------------------
    //     width: keyWidth
    //     height: keyHeight
    //
    //     readonly property var mappedAction: dialogRoot.getActionForKey(primaryKey, dialogRoot.shortcutRevision)
    //     readonly property bool hasAnyBound: dialogRoot.hasAnyShortcut(primaryKey, dialogRoot.shortcutRevision)
    //     readonly property bool isKeySelected: dialogRoot.selectedKeyName.toLowerCase() === primaryKey.toLowerCase()
    //
    //     // Key group detection for keycap subtle highlighting
    //     readonly property string normKey: primaryKey.toLowerCase()
    //     readonly property bool isWASD: normKey === "w" || normKey === "a" || normKey === "s" || normKey === "d"
    //     readonly property bool isHJKL: normKey === "h" || normKey === "j" || normKey === "k" || normKey === "l"
    //
    //     radius: 8
    //
    //     // Surface color evaluation using top palette vars
    //     color: {
    //         // 1. Selected State
    //         if (isKeySelected) {
    //             if (isAccentReturn) return colorAccentReturnSelected;
    //             return isSpecial ? colorSpecialSelected : colorNormalSelected;
    //         }
    //
    //         // 2. Click Press State
    //         if (capMouse.pressed) {
    //             return isSpecial ? colorSpecialPress : colorNormalPress;
    //         }
    //
    //         // 3. Hover State
    //         if (capMouse.containsMouse) {
    //             return isSpecial ? colorSpecialHover : colorNormalHover;
    //         }
    //
    //         // 4. Active Toggle / Modifier State
    //         if (isModifierActive) return colorModifierActive;
    //
    //         // 5. Cluster Highlights (WASD / HJKL)
    //         if (isWASD || isHJKL) return colorClusterHighlight;
    //
    //         // 6. Idle Base States
    //         return isSpecial ? colorBaseSpecial : colorBaseNormal;
    //     }
    //
    //     // Animated color morphing on state changes
    //     Behavior on color {
    //         ColorAnimation {
    //             duration: capMouse.pressed ? 50 : 150
    //             easing.type: Easing.OutCubic
    //         }
    //     }
    //
    //     // BORDERS PURGED (Commented out)
    //     // border.color: ...
    //     // border.width: ...
    //
    //     // Indicator dot for shortcuts
    //     Rectangle {
    //         visible: isAccentReturn || hasAnyBound
    //         anchors.top: parent.top
    //         anchors.right: parent.right
    //         anchors.margins: 4
    //         width: 4
    //         height: 4
    //         radius: 2
    //         color: isKeySelected ? colorIndicatorActive : (mappedAction ? colorIndicatorActive : colorIndicatorInactive)
    //
    //         Behavior on color {
    //             ColorAnimation { duration: 120 }
    //         }
    //     }
    //
    //     Column {
    //         anchors.centerIn: parent
    //         spacing: 1
    //
    //         // Secondary Shift text
    //         Text {
    //             visible: capRoot.shiftKey !== "" && capRoot.iconSource === ""
    //             text: capRoot.shiftKey
    //             color: dialogRoot.modShift ? colorBlueAccentText : (isKeySelected ? colorTextSelected : colorTextShiftIdle)
    //             font.pixelSize: 8
    //             anchors.horizontalCenter: parent.horizontalCenter
    //
    //             Behavior on color {
    //                 ColorAnimation { duration: 120 }
    //             }
    //         }
    //
    //         // Primary Content: Render Icon if provided, otherwise render Text label
    //         Loader {
    //             anchors.horizontalCenter: parent.horizontalCenter
    //             active: capRoot.iconSource !== ""
    //             sourceComponent: Image {
    //                 source: capRoot.iconSource
    //                 width: 14
    //                 height: 14
    //                 fillMode: Image.PreserveAspectFit
    //                 smooth: true
    //                 opacity: capRoot.isKeySelected || capRoot.mappedAction ? 1.0 : 0.85
    //
    //                 Behavior on opacity {
    //                     NumberAnimation { duration: 120 }
    //                 }
    //             }
    //         }
    //
    //         Text {
    //             visible: capRoot.iconSource === ""
    //             text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
    //             color: {
    //                 if (isKeySelected) return colorTextSelected;
    //                 if (mappedAction) return colorTextSelected;
    //                 if (isWASD || isHJKL) return colorBlueAccentText;
    //                 if (isSpecial) return capMouse.containsMouse ? colorTextSpecialHover : colorTextSpecialIdle;
    //                 return colorTextNormal;
    //             }
    //             font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
    //             font.weight: (isKeySelected || mappedAction || isWASD || isHJKL) ? Font.Medium : Font.Normal
    //             anchors.horizontalCenter: parent.horizontalCenter
    //
    //             Behavior on color {
    //                 ColorAnimation { duration: 120 }
    //             }
    //         }
    //     }
    //
    //     MouseArea {
    //         id: capMouse
    //         anchors.fill: parent
    //         hoverEnabled: true
    //         cursorShape: Qt.PointingHandCursor
    //
    //         onClicked: {
    //             if (capRoot.isModifierToggle) {
    //                 var lk = capRoot.primaryKey.toLowerCase();
    //                 if (lk === "ctrl") dialogRoot.modCtrl = !dialogRoot.modCtrl;
    //                 else if (lk === "shift") dialogRoot.modShift = !dialogRoot.modShift;
    //                 else if (lk === "alt") dialogRoot.modAlt = !dialogRoot.modAlt;
    //                 else if (lk === "win" || lk === "cmd") dialogRoot.modMeta = !dialogRoot.modMeta;
    //             } else {
    //                 dialogRoot.selectedKeyName = capRoot.primaryKey;
    //             }
    //         }
    //     }
    // }
    
    // component KeyCap: Rectangle {
    //     id: capRoot
    //     property string primaryKey: ""
    //     property string shiftKey: ""
    //     property string labelOverride: ""
    //     property real keyWidth: 44
    //     property real keyHeight: 44
    //     property bool isSpecial: false
    //     property bool isAccentReturn: false
    //     property bool isModifierToggle: false
    //     property bool isModifierActive: false
    //
    //     width: keyWidth
    //     height: keyHeight
    //
    //     readonly property var mappedAction: dialogRoot.getActionForKey(primaryKey, dialogRoot.shortcutRevision)
    //     readonly property bool hasAnyBound: dialogRoot.hasAnyShortcut(primaryKey, dialogRoot.shortcutRevision)
    //     readonly property bool isKeySelected: dialogRoot.selectedKeyName.toLowerCase() === primaryKey.toLowerCase()
    //
    //     radius: 4
    //
    //     gradient: Gradient {
    //         GradientStop {
    //             position: 0.0
    //             color: isKeySelected ? (isAccentReturn ? "#2563eb" : "#1d4ed8") : (isModifierActive ? "#3f3f46" : (capMouse.containsMouse ? "#27272a" : (isSpecial ? "#141414" : "#18181b")))
    //         }
    //         GradientStop {
    //             position: 1.0
    //             color: isKeySelected ? (isAccentReturn ? "#1d4ed8" : "#1e40af") : (isModifierActive ? "#27272a" : (capMouse.containsMouse ? "#18181b" : (isSpecial ? "#0f0f11" : "#121214")))
    //         }
    //     }
    //
    //     border.color: isKeySelected ? (isAccentReturn ? "#60a5fa" : "#2555d3") : (isModifierActive ? "#52525b" : (mappedAction ? "#3f3f46" : "#2d2d2d"))
    //     border.width: isKeySelected ? 1.5 : 1
    //
    //     Rectangle {
    //         visible: isAccentReturn || hasAnyBound
    //         anchors.top: parent.top
    //         anchors.right: parent.right
    //         anchors.margins: 3
    //         width: 4
    //         height: 4
    //         radius: 2
    //         color: isKeySelected ? "#93c5fd" : (mappedAction ? "#ffffff" : "#71717a")
    //     }
    //
    //     Column {
    //         anchors.centerIn: parent
    //         spacing: 1
    //
    //         Text {
    //             visible: capRoot.shiftKey !== ""
    //             text: capRoot.shiftKey
    //             color: dialogRoot.modShift ? "#60a5fa" : (isKeySelected ? "#bfdbfe" : "#52525b")
    //             font.pixelSize: 8
    //             font.family: "Monospace"
    //             anchors.horizontalCenter: parent.horizontalCenter
    //         }
    //
    //         Text {
    //             text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
    //             color: isKeySelected ? "#ffffff" : (mappedAction ? "#ffffff" : (isSpecial ? "#a1a1aa" : "#d4d4d8"))
    //             font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
    //             font.weight: (isKeySelected || mappedAction) ? Font.DemiBold : Font.Normal
    //             font.family: "Monospace"
    //             anchors.horizontalCenter: parent.horizontalCenter
    //         }
    //     }
    //
    //     MouseArea {
    //         id: capMouse
    //         anchors.fill: parent
    //         hoverEnabled: true
    //         cursorShape: Qt.PointingHandCursor
    //
    //         onClicked: {
    //             if (capRoot.isModifierToggle) {
    //                 var lk = capRoot.primaryKey.toLowerCase();
    //                 if (lk === "ctrl")
    //                     dialogRoot.modCtrl = !dialogRoot.modCtrl;
    //                 else if (lk === "shift")
    //                     dialogRoot.modShift = !dialogRoot.modShift;
    //                 else if (lk === "alt")
    //                     dialogRoot.modAlt = !dialogRoot.modAlt;
    //                 else if (lk === "win" || lk === "cmd")
    //                     dialogRoot.modMeta = !dialogRoot.modMeta;
    //             } else {
    //                 dialogRoot.selectedKeyName = capRoot.primaryKey;
    //             }
    //         }
    //     }
    // }

    // Modifier Toggle Button Component
    component ModifierToggleBtn: Rectangle {
        property string label: ""
        property bool active: false
        signal toggled

        height: 26
        width: modText.implicitWidth + 20
        radius: 4
        color: active ? "#2c3447" : (modM.containsMouse ? "#1d1d24" : "#16161b")
        border.color: active ? "#5075c7" : "#282834"

        Text {
            id: modText
            anchors.centerIn: parent
            text: label
            color: active ? "#ffffff" : "#888898"
            font.pixelSize: 10
            font.weight: Font.Medium
        }

        MouseArea {
            id: modM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggled()
        }
    }

    // Category Filter Chip Component
    component CategoryPill: Rectangle {
        property string label: ""
        property bool active: false
        signal selected

        height: 24
        width: pillText.implicitWidth + 14
        radius: 12
        color: active ? "#252834" : (pillM.containsMouse ? "#1a1a22" : "transparent")
        border.color: active ? "#485372" : "transparent"

        Text {
            id: pillText
            anchors.centerIn: parent
            text: label
            color: active ? "#ffffff" : "#727282"
            font.pixelSize: 10
            font.weight: active ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: pillM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: selected()
        }
    }

    // Modal Dialog: New Custom Preset Creation
    Dialog {
        id: newPresetDialog
        anchors.centerIn: parent
        width: 300
        height: 140
        modal: true
        title: "Create Preset"

        background: Rectangle {
            color: "#16161a"
            border.color: "#2a2a34"
            border.width: 1
            radius: 6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: "Preset Name:"
                color: "#888898"
                font.pixelSize: 11
            }

            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: "#0f0f12"
                border.color: "#282834"
                border.width: 1
                radius: 4

                TextInput {
                    id: newPresetInput
                    anchors.fill: parent
                    anchors.margins: 6
                    color: "#ffffff"
                    font.pixelSize: 11
                    selectByMouse: true
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: "Cancel"
                    onClicked: newPresetDialog.close()
                }

                Button {
                    text: "Create"
                    onClicked: {
                        if (newPresetInput.text.trim() !== "") {
                            shortcutManager.createCustomPreset(newPresetInput.text.trim(), shortcutManager.activePresetName);
                            newPresetDialog.close();
                        }
                    }
                }
            }
        }
    }
}
