import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Window {
    id: dialogRoot

    title: "Keyboard Shortcuts — Xyla"

    // Strict fixed dimensions to prevent tiling by WMs
    width: 1240
    height: 820
    minimumWidth: 1240
    maximumWidth: 1240
    minimumHeight: 820
    maximumHeight: 820

    color: "#191919"
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
        // 1. TOP HEADER TOOLBAR
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#1a1a1a"
            border.color: "#2d2d2d"
            border.width: 1
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "PRESET"
                    color: "#555562"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }

                XylaSelect {
                    id: presetSelect
                    implicitWidth: 190
                    implicitHeight: 28
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

                Rectangle {
                    height: 28
                    width: 28
                    radius: 4
                    color: newPresetM.containsMouse ? "#262632" : "#1b1b22"
                    border.color: "#282834"

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#cccccc"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    MouseArea {
                        id: newPresetM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: newPresetDialog.open()
                    }
                }

                Rectangle {
                    visible: {
                        var p = shortcutManager.activePresetName;
                        return p !== "Xyla Default" && p !== "DaVinci Resolve" && p !== "Adobe Premiere Pro" && p !== "Apple Final Cut Pro" && p !== "Avid Media Composer";
                    }
                    height: 28
                    width: 28
                    radius: 4
                    color: delPresetM.containsMouse ? "#321a1a" : "#201414"
                    border.color: "#4a2222"

                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        color: "#ef4444"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    MouseArea {
                        id: delPresetM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shortcutManager.deleteCustomPreset(shortcutManager.activePresetName)
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "MODIFIERS"
                    color: "#555562"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }

                RowLayout {
                    spacing: 4

                    ModifierToggleBtn {
                        label: "Ctrl"
                        active: dialogRoot.modCtrl
                        onToggled: dialogRoot.modCtrl = !dialogRoot.modCtrl
                    }
                    ModifierToggleBtn {
                        label: "Shift"
                        active: dialogRoot.modShift
                        onToggled: dialogRoot.modShift = !dialogRoot.modShift
                    }
                    ModifierToggleBtn {
                        label: "Alt"
                        active: dialogRoot.modAlt
                        onToggled: dialogRoot.modAlt = !dialogRoot.modAlt
                    }
                    ModifierToggleBtn {
                        label: "Cmd"
                        active: dialogRoot.modMeta
                        onToggled: dialogRoot.modMeta = !dialogRoot.modMeta
                    }
                }

                Rectangle {
                    width: 1
                    height: 18
                    color: "#25252d"
                }

                Rectangle {
                    height: 28
                    width: 80
                    radius: 4
                    color: resetM.containsMouse ? "#281b1b" : "#1a1616"
                    border.color: resetM.containsMouse ? "#552828" : "#322020"

                    Text {
                        anchors.centerIn: parent
                        text: "Reset All"
                        color: "#e06c75"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: resetM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shortcutManager.resetAllToDefault()
                    }
                }
            }
        }

        // =====================================================================
        // 2. FULL PHYSICAL DESKTOP KEYBOARD + NUMPAD
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 330
            color: "#1a1a1a"
            border.color: "#2d2d2d"
            border.width: 1
            radius: 6

            Row {
                anchors.centerIn: parent
                spacing: 14

                Column {
                    spacing: 4

                    Row {
                        spacing: 4
                        KeyCap {
                            primaryKey: "Esc"
                            keyWidth: 44
                            keyHeight: 28
                            isSpecial: true
                        }
                        Item {
                            width: 10
                            height: 28
                        }
                        KeyCap {
                            primaryKey: "F1"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F2"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F3"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F4"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        Item {
                            width: 8
                            height: 28
                        }
                        KeyCap {
                            primaryKey: "F5"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F6"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F7"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F8"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        Item {
                            width: 8
                            height: 28
                        }
                        KeyCap {
                            primaryKey: "F9"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F10"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F11"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "F12"
                            keyWidth: 42
                            keyHeight: 28
                            isSpecial: true
                        }
                    }

                    // Number Row
                    Row {
                        spacing: 4
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
                            labelOverride: "Bksp"
                            keyWidth: 92
                            isSpecial: true
                        }
                    }

                    // Tab / QWERTY Row
                    Row {
                        spacing: 4
                        KeyCap {
                            primaryKey: "Tab"
                            labelOverride: "Tab"
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

                    // Caps / ASDF Row
                    Row {
                        spacing: 4
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
                            labelOverride: "Return"
                            keyWidth: 106
                            isAccentReturn: true
                        }
                    }

                    // Shift / ZXCV Row
                    Row {
                        spacing: 4
                        KeyCap {
                            primaryKey: "Shift"
                            labelOverride: "Shift"
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
                        KeyCap {
                            primaryKey: "Shift"
                            labelOverride: "Shift"
                            keyWidth: 134
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modShift
                        }
                    }

                    // Bottom Modifier Row
                    Row {
                        spacing: 4
                        KeyCap {
                            primaryKey: "Ctrl"
                            labelOverride: "Ctrl"
                            keyWidth: 56
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modCtrl
                        }
                        KeyCap {
                            primaryKey: "Win"
                            labelOverride: "Win"
                            keyWidth: 48
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modMeta
                        }
                        KeyCap {
                            primaryKey: "Alt"
                            labelOverride: "Alt"
                            keyWidth: 52
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modAlt
                        }
                        KeyCap {
                            primaryKey: "Space"
                            labelOverride: "Space"
                            keyWidth: 328
                        }
                        KeyCap {
                            primaryKey: "Alt"
                            labelOverride: "Alt"
                            keyWidth: 52
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modAlt
                        }
                        KeyCap {
                            primaryKey: "Win"
                            labelOverride: "Win"
                            keyWidth: 48
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modMeta
                        }
                        KeyCap {
                            primaryKey: "Menu"
                            labelOverride: "Menu"
                            keyWidth: 48
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "Ctrl"
                            labelOverride: "Ctrl"
                            keyWidth: 56
                            isSpecial: true
                            isModifierToggle: true
                            isModifierActive: dialogRoot.modCtrl
                        }
                    }
                }

                // -------------------------------------------------------------
                // B. NAVIGATION & SYSTEM CLUSTER (Width: 140px)
                // -------------------------------------------------------------
                Column {
                    spacing: 4

                    Row {
                        spacing: 4
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

                    Row {
                        spacing: 4
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
                        spacing: 4
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
                        spacing: 4
                        Item {
                            width: 44
                            height: 44
                        }
                        KeyCap {
                            primaryKey: "Up"
                            labelOverride: "Up"
                            keyWidth: 44
                            isSpecial: true
                        }
                        Item {
                            width: 44
                            height: 44
                        }
                    }

                    Row {
                        spacing: 4
                        KeyCap {
                            primaryKey: "Left"
                            labelOverride: "Left"
                            keyWidth: 44
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "Down"
                            labelOverride: "Down"
                            keyWidth: 44
                            isSpecial: true
                        }
                        KeyCap {
                            primaryKey: "Right"
                            labelOverride: "Right"
                            keyWidth: 44
                            isSpecial: true
                        }
                    }
                }

                // -------------------------------------------------------------
                // C. NUMPAD CLUSTER (Width: 188px)
                // -------------------------------------------------------------
                Column {
                    spacing: 4

                    Row {
                        spacing: 4
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

                    Row {
                        spacing: 4
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
                        spacing: 4

                        Column {
                            spacing: 4
                            Row {
                                spacing: 4
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
                                spacing: 4
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
                        spacing: 4

                        Column {
                            spacing: 4
                            Row {
                                spacing: 4
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
                                spacing: 4
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
                            keyWidth: 44
                            keyHeight: 92
                            isAccentReturn: true
                        }
                    }
                }
            }
        }

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
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                color: "#1a1a1a"
                border.color: "#2d2d2d"
                border.width: 1
                radius: 6

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Text {
                            text: "KEY DETAILS"
                            color: "#555562"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.0
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: dialogRoot.currentActionForSelectedKey !== null
                            height: 16
                            width: activeBadgeText.implicitWidth + 10
                            radius: 8
                            color: "#182a1d"
                            border.color: "#2a5433"
                            Text {
                                id: activeBadgeText
                                anchors.centerIn: parent
                                text: "Bound"
                                color: "#4ade80"
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }

                    // Keycap Preview Box
                    Rectangle {
                        Layout.fillWidth: true
                        height: 56
                        color: "#101013"
                        border.color: "#1e1e24"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 4
                                color: "#1f1f26"
                                border.color: "#3e3e4f"
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName)
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "Monospace"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.name : "Unassigned Key"
                                    color: dialogRoot.currentActionForSelectedKey ? "#ffffff" : "#60606e"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: dialogRoot.currentActionForSelectedKey ? "Category: " + dialogRoot.currentActionForSelectedKey.category : "Click an action on the right to assign"
                                    color: "#7e7e8e"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    // Action Description / Info
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#101013"
                        border.color: "#1b1b20"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Text {
                                text: dialogRoot.currentActionForSelectedKey ? dialogRoot.currentActionForSelectedKey.description : "No action bound to this key combination. Select a command from the table to bind it."
                                color: "#808092"
                                font.pixelSize: 11
                                lineHeight: 1.3
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            // Conflict Notification
                            Rectangle {
                                visible: {
                                    if (!dialogRoot.selectedActionFromList)
                                        return false;
                                    var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                                    var conflict = shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq);
                                    return conflict !== "";
                                }
                                Layout.fillWidth: true
                                height: 26
                                radius: 4
                                color: "#281e14"
                                border.color: "#5c381c"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 5
                                    Text {
                                        text: "CONFLICT:"
                                        color: "#f59e0b"
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                    Text {
                                        text: {
                                            if (!dialogRoot.selectedActionFromList)
                                                return "";
                                            var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                                            return "Replaces hotkey for '" + shortcutManager.findConflictingAction(dialogRoot.selectedActionFromList.id, seq) + "'";
                                        }
                                        color: "#f59e0b"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                    // Inspector Action Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 4
                            color: unbindM.containsMouse ? "#281b1b" : "#1a1516"
                            border.color: unbindM.containsMouse ? "#552828" : "#321e20"
                            enabled: dialogRoot.currentActionForSelectedKey !== null
                            opacity: enabled ? 1.0 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: "Unbind"
                                color: "#ef4444"
                                font.pixelSize: 10
                                font.bold: true
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
                            height: 28
                            radius: 4
                            color: resetKeyM.containsMouse ? "#22222c" : "#181820"
                            border.color: "#282834"
                            enabled: dialogRoot.currentActionForSelectedKey !== null
                            opacity: enabled ? 1.0 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: "Default"
                                color: "#9ca3af"
                                font.pixelSize: 10
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

            // -----------------------------------------------------------------
            // RIGHT: BACKEND ACTIONS DIRECTORY TABLE
            // -----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1a1a1a"
                border.color: "#2d2d2d"
                border.width: 1
                radius: 6

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Search & Category Filters
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Search Input Field
                        Rectangle {
                            Layout.preferredWidth: 220
                            height: 28
                            color: "#181818"
                            border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                            border.width: 1
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Image {
                                    source: "qrc:/assets/icons/search.svg"
                                    sourceSize.width: 11
                                    sourceSize.height: 11
                                    visible: status === Image.Ready
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    selectByMouse: true
                                    clip: true
                                    onTextChanged: dialogRoot.searchQuery = text.toLowerCase().trim()

                                    Text {
                                        text: "Search actions..."
                                        color: "#71717a"
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        // Category Selector Bar with Animated Sliding Indicator
                        Rectangle {
                            id: categoryContainer
                            height: 28
                            implicitWidth: categoryRow.implicitWidth + 4
                            color: "#181818"
                            border.color: "#2d2d2d"
                            border.width: 1
                            radius: 6

                            readonly property var categories: ["All", "Edit", "Tools", "Playback", "Timeline"]
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
                                        width: pillText.implicitWidth + 16

                                        readonly property bool isSelected: dialogRoot.selectedCategory === modelData

                                        onIsSelectedChanged: {
                                            if (isSelected) {
                                                categoryContainer.activeTargetItem = pillRoot;
                                            }
                                        }

                                        Component.onCompleted: {
                                            if (isSelected) {
                                                categoryContainer.activeTargetItem = pillRoot;
                                            }
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
                                            onClicked: dialogRoot.selectedCategory = modelData
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Direct Assign Button using Outline mode (No Opacity)
                        XylaTextButton {
                            Layout.preferredHeight: 28
                            Layout.maximumWidth: 220
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 12
                            rightPadding: 12
                            outline: true
                            enabled: dialogRoot.selectedActionFromList !== null
                            text: "Assign to [" + dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName) + "]"

                            onClicked: {
                                if (dialogRoot.selectedActionFromList) {
                                    var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                                    shortcutManager.setKeySequence(dialogRoot.selectedActionFromList.id, seq);
                                }
                            }
                        }
                    }

                    // Table Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 22
                        color: "#101013"
                        radius: 3

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "COMMAND"
                                color: "#52525e"
                                font.pixelSize: 9
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "CATEGORY"
                                color: "#52525e"
                                font.pixelSize: 9
                                font.bold: true
                                Layout.preferredWidth: 100
                            }
                            Text {
                                text: "CURRENT SHORTCUT"
                                color: "#52525e"
                                font.pixelSize: 9
                                font.bold: true
                                Layout.preferredWidth: 120
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Action Table List
                    ListView {
                        id: actionTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2

                        model: {
                            var rev = dialogRoot.shortcutRevision;
                            var all = shortcutManager.getAllActions();
                            var filtered = [];
                            for (var i = 0; i < all.length; ++i) {
                                var matchesCategory = (dialogRoot.selectedCategory === "All" || all[i].category === dialogRoot.selectedCategory);
                                var matchesSearch = (dialogRoot.searchQuery === "" || all[i].name.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1 || all[i].category.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1 || (all[i].currentKey && all[i].currentKey.toLowerCase().indexOf(dialogRoot.searchQuery) !== -1));
                                if (matchesCategory && matchesSearch)
                                    filtered.push(all[i]);
                            }
                            return filtered;
                        }

                        delegate: Rectangle {
                            width: actionTable.width
                            height: 26
                            readonly property bool isSelected: dialogRoot.selectedActionFromList && dialogRoot.selectedActionFromList.id === modelData.id
                            color: isSelected ? "#222530" : (rowM.containsMouse ? "#1f1e1e" : "transparent")
                            border.color: isSelected ? "#384259" : "transparent"
                            border.width: 1
                            radius: 3

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: modelData.name
                                    color: isSelected ? "#ffffff" : "#d0d0d8"
                                    font.pixelSize: 11
                                    font.weight: isSelected ? Font.DemiBold : Font.Normal
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.category
                                    color: "#727282"
                                    font.pixelSize: 10
                                    Layout.preferredWidth: 100
                                }

                                Rectangle {
                                    Layout.preferredWidth: 120
                                    height: 18
                                    radius: 3
                                    color: modelData.currentKey ? "#1a1a1a" : "transparent"
                                    border.color: modelData.currentKey ? "#2c2c3e" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.currentKey || "-"
                                        color: modelData.currentKey ? "#e4e4ed" : "#444450"
                                        font.pixelSize: 9
                                        font.family: "Monospace"
                                        font.weight: modelData.currentKey ? Font.DemiBold : Font.Normal
                                    }
                                }
                            }

                            MouseArea {
                                id: rowM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialogRoot.selectedActionFromList = modelData
                                onDoubleClicked: {
                                    dialogRoot.selectedActionFromList = modelData;
                                    var seq = dialogRoot.buildCurrentSequence(dialogRoot.selectedKeyName);
                                    shortcutManager.setKeySequence(modelData.id, seq);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Keycap Component
    component KeyCap: Rectangle {
        id: capRoot
        property string primaryKey: ""
        property string shiftKey: ""
        property string labelOverride: ""
        property real keyWidth: 44
        property real keyHeight: 44
        property bool isSpecial: false
        property bool isAccentReturn: false
        property bool isModifierToggle: false
        property bool isModifierActive: false

        width: keyWidth
        height: keyHeight

        readonly property var mappedAction: dialogRoot.getActionForKey(primaryKey, dialogRoot.shortcutRevision)
        readonly property bool hasAnyBound: dialogRoot.hasAnyShortcut(primaryKey, dialogRoot.shortcutRevision)
        readonly property bool isKeySelected: dialogRoot.selectedKeyName.toLowerCase() === primaryKey.toLowerCase()

        radius: 4

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: isKeySelected ? (isAccentReturn ? "#2563eb" : "#1d4ed8") : (isModifierActive ? "#3f3f46" : (capMouse.containsMouse ? "#27272a" : (isSpecial ? "#141414" : "#18181b")))
            }
            GradientStop {
                position: 1.0
                color: isKeySelected ? (isAccentReturn ? "#1d4ed8" : "#1e40af") : (isModifierActive ? "#27272a" : (capMouse.containsMouse ? "#18181b" : (isSpecial ? "#0f0f11" : "#121214")))
            }
        }

        border.color: isKeySelected ? (isAccentReturn ? "#60a5fa" : "#2555d3") : (isModifierActive ? "#52525b" : (mappedAction ? "#3f3f46" : "#2d2d2d"))
        border.width: isKeySelected ? 1.5 : 1

        Rectangle {
            visible: isAccentReturn || hasAnyBound
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 3
            width: 4
            height: 4
            radius: 2
            color: isKeySelected ? "#93c5fd" : (mappedAction ? "#ffffff" : "#71717a")
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                visible: capRoot.shiftKey !== ""
                text: capRoot.shiftKey
                color: dialogRoot.modShift ? "#60a5fa" : (isKeySelected ? "#bfdbfe" : "#52525b")
                font.pixelSize: 8
                font.family: "Monospace"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: capRoot.labelOverride !== "" ? capRoot.labelOverride : capRoot.primaryKey
                color: isKeySelected ? "#ffffff" : (mappedAction ? "#ffffff" : (isSpecial ? "#a1a1aa" : "#d4d4d8"))
                font.pixelSize: (capRoot.primaryKey.length > 2 && capRoot.labelOverride === "") ? 9 : 11
                font.weight: (isKeySelected || mappedAction) ? Font.DemiBold : Font.Normal
                font.family: "Monospace"
                anchors.horizontalCenter: parent.horizontalCenter
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
                    if (lk === "ctrl")
                        dialogRoot.modCtrl = !dialogRoot.modCtrl;
                    else if (lk === "shift")
                        dialogRoot.modShift = !dialogRoot.modShift;
                    else if (lk === "alt")
                        dialogRoot.modAlt = !dialogRoot.modAlt;
                    else if (lk === "win" || lk === "cmd")
                        dialogRoot.modMeta = !dialogRoot.modMeta;
                } else {
                    dialogRoot.selectedKeyName = capRoot.primaryKey;
                }
            }
        }
    }

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
