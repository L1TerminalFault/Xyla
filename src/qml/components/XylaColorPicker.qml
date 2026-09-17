import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root

    property color selectedColor: "#ffffff"
    property bool keyframeable: false
    property bool hasKeyframe: false
    signal colorCommitted(color newColor)
    signal keyframeToggled
    signal eyedropperRequested

    implicitWidth: 64
    implicitHeight: 24

    // Internal color mode: "RGB" | "HEX" | "HSV"
    property string colorMode: "RGB"

    // Internal HSV state tracking to avoid Hue reset on black/white
    property real activeHue: selectedColor.hsvHue >= 0 ? selectedColor.hsvHue : 0.66
    property real activeSat: selectedColor.hsvSaturation
    property real activeVal: selectedColor.hsvValue
    property real activeAlpha: selectedColor.a

    onSelectedColorChanged: {
        if (!satValMouse.pressed && !hueMouse.pressed && !alphaMouse.pressed) {
            if (selectedColor.hsvHue >= 0) {
                root.activeHue = selectedColor.hsvHue;
            }
            root.activeSat = selectedColor.hsvSaturation;
            root.activeVal = selectedColor.hsvValue;
            root.activeAlpha = selectedColor.a;
        }
    }

    // Reactive color channel bindings
    readonly property int rValue: Math.round(selectedColor.r * 255)
    readonly property int gValue: Math.round(selectedColor.g * 255)
    readonly property int bValue: Math.round(selectedColor.b * 255)
    readonly property int hValue: Math.round(activeHue * 360)
    readonly property int sValue: Math.round(activeSat * 100)
    readonly property int vValue: Math.round(activeVal * 100)
    readonly property string hexValue: selectedColor.toString().toUpperCase()

    function updateRgb(r, g, b) {
        var col = Qt.rgba(r / 255.0, g / 255.0, b / 255.0, root.activeAlpha);
        root.selectedColor = col;
        root.colorCommitted(col);
    }

    function updateHsv(h, s, v) {
        root.activeHue = h / 360.0;
        root.activeSat = s / 100.0;
        root.activeVal = v / 100.0;
        var col = Qt.hsva(root.activeHue, root.activeSat, root.activeVal, root.activeAlpha);
        root.selectedColor = col;
        root.colorCommitted(col);
    }

    function updateHue(h) {
        root.activeHue = h;
        var col = Qt.hsva(root.activeHue, root.activeSat, root.activeVal, root.activeAlpha);
        root.selectedColor = col;
        root.colorCommitted(col);
    }

    function updateAlpha(a) {
        root.activeAlpha = a;
        var col = Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, a);
        root.selectedColor = col;
        root.colorCommitted(col);
    }

    // Smart positioning: defaults to opening towards the left
    function openSmartPopup() {
        if (root.Window.window) {
            var globalPos = root.mapToItem(null, 0, 0);
            var winW = root.Window.window.width;
            var winH = root.Window.window.height;
            var popH = colorPopup.implicitHeight > 0 ? colorPopup.implicitHeight : 340;
            var popW = colorPopup.width;

            var spaceBelow = winH - (globalPos.y + root.height);
            var spaceAbove = globalPos.y;

            if (spaceBelow < popH + 10 && spaceAbove > spaceBelow) {
                colorPopup.y = -popH - 6;
            } else {
                colorPopup.y = root.height + 6;
            }

            var targetX = root.width - popW;
            if (globalPos.x + targetX < 12) {
                targetX = 12 - globalPos.x;
            }
            if (globalPos.x + targetX + popW > winW - 12) {
                targetX = (winW - 12) - (globalPos.x + popW);
            }
            colorPopup.x = targetX;
        }
        colorPopup.open();
    }

    // =========================================================================
    // CALLSITE OPENER
    // =========================================================================
    Rectangle {
        id: openerRect
        anchors.fill: parent
        color: "#121215"
        radius: 3
        border.color: openerMouse.containsMouse || colorPopup.visible ? "#38383e" : "#28282e"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 6

            Rectangle {
                Layout.alignment: Qt.AlignCenter
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height - 8
                radius: 2
                color: root.selectedColor
                border.color: "#333333"
                border.width: 1
            }

            Item {
                visible: root.keyframeable
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    rotation: 45
                    color: root.hasKeyframe ? "#3b82f6" : "transparent"
                    border.color: root.hasKeyframe ? "#3b82f6" : "#ffffff"
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.keyframeToggled()
                }
            }
        }

        MouseArea {
            id: openerMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (!root.keyframeable || mouse.x < parent.width - 24) {
                    root.openSmartPopup();
                }
            }
        }
    }

    // =========================================================================
    // POPUP PICKER WINDOW
    // =========================================================================
    Popup {
        id: colorPopup
        width: 300
        padding: 10
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 140
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.97
                to: 1.0
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 100
                easing.type: Easing.InCubic
            }
        }

        background: Rectangle {
            color: "#191919"
            radius: 6
            border.color: "#28282e"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 10
            width: parent.width

            // -----------------------------------------------------------------
            // 1. TITLEBAR
            // -----------------------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 3
                    color: closeMouse.containsMouse ? "#2a2a2a" : "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/x.svg"
                        sourceSize: Qt.size(14, 14)
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorPopup.close()
                    }
                }
            }

            // -----------------------------------------------------------------
            // 2. INPUT SECTION
            // -----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                XylaSelect {
                    id: modeSelect
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 28
                    model: ["RGB", "HEX", "HSV"]
                    backgroundColor: "#181818"
                    borderColor: "#2d2d2d"
                    currentIndex: 0
                    onActivated: {
                        root.colorMode = currentText;
                    }
                }

                // RGB Mode
                RowLayout {
                    visible: root.colorMode === "RGB"
                    Layout.fillWidth: true
                    spacing: 4

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "R"
                        minValue: 0
                        maxValue: 255
                        stepSize: 1
                        decimals: 0
                        value: root.rValue
                        onValueCommitted: newVal => root.updateRgb(newVal, root.gValue, root.bValue)
                    }

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "G"
                        minValue: 0
                        maxValue: 255
                        stepSize: 1
                        decimals: 0
                        value: root.gValue
                        onValueCommitted: newVal => root.updateRgb(root.rValue, newVal, root.bValue)
                    }

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "B"
                        minValue: 0
                        maxValue: 255
                        stepSize: 1
                        decimals: 0
                        value: root.bValue
                        onValueCommitted: newVal => root.updateRgb(root.rValue, root.gValue, newVal)
                    }
                }

                // HSV Mode
                RowLayout {
                    visible: root.colorMode === "HSV"
                    Layout.fillWidth: true
                    spacing: 4

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "H"
                        minValue: 0
                        maxValue: 360
                        stepSize: 1
                        decimals: 0
                        value: root.hValue
                        onValueCommitted: newVal => root.updateHsv(newVal, root.sValue, root.vValue)
                    }

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "S"
                        unit: "%"
                        minValue: 0
                        maxValue: 100
                        stepSize: 1
                        decimals: 0
                        value: root.sValue
                        onValueCommitted: newVal => root.updateHsv(root.hValue, newVal, root.vValue)
                    }

                    XylaFloatInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        label: "V"
                        unit: "%"
                        minValue: 0
                        maxValue: 100
                        stepSize: 1
                        decimals: 0
                        value: root.vValue
                        onValueCommitted: newVal => root.updateHsv(root.hValue, root.sValue, newVal)
                    }
                }

                // HEX Mode
                Rectangle {
                    visible: root.colorMode === "HEX"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 4
                    color: "#1a1a1a"
                    border.color: hexInput.activeFocus ? "#4a4a4a" : "#28282e"
                    border.width: 1

                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.family: "Monospace"

                        Binding on text {
                            value: root.hexValue
                            when: !hexInput.activeFocus
                        }

                        onAccepted: {
                            var col = Qt.color(text);
                            if (col.toString() !== "") {
                                root.selectedColor = col;
                                root.colorCommitted(col);
                            } else {
                                text = root.hexValue;
                            }
                            hexInput.focus = false;
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // 3. SATURATION / VALUE 2D COLOR FIELD
            // -----------------------------------------------------------------
            Rectangle {
                id: satValBox
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 4
                clip: true
                border.color: "#28282e"
                border.width: 1
                color: Qt.hsva(root.activeHue, 1.0, 1.0, 1.0)

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: "#ffffff"
                        }
                        GradientStop {
                            position: 1.0
                            color: "transparent"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop {
                            position: 0.0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#000000"
                        }
                    }
                }

                // Reticle Handle
                Item {
                    id: handleContainer
                    x: Math.round(root.activeSat * satValBox.width)
                    y: Math.round((1.0 - root.activeVal) * satValBox.height)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8
                        color: "transparent"
                        border.color: "#55000000"
                        border.width: 1
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: "transparent"
                        border.color: "#ffffff"
                        border.width: 2.5
                    }
                }

                MouseArea {
                    id: satValMouse
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    preventStealing: true

                    function updateFromMouse(mouse) {
                        var s = Math.max(0.0, Math.min(1.0, mouse.x / satValBox.width));
                        var v = Math.max(0.0, Math.min(1.0, 1.0 - (mouse.y / satValBox.height)));
                        root.activeSat = s;
                        root.activeVal = v;
                        var col = Qt.hsva(root.activeHue, s, v, root.activeAlpha);
                        root.selectedColor = col;
                        root.colorCommitted(col);
                    }

                    onPressed: mouse => updateFromMouse(mouse)
                    onPositionChanged: mouse => {
                        if (pressed) {
                            updateFromMouse(mouse);
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // 4. EYEDROPPER & HUE / OPACITY SLIDERS (Image 3)
            // -----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Eyedropper Button with jump animation
                Rectangle {
                    id: eyedropperBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 6
                    color: eyedropperMouse.containsMouse ? "#242424" : "#1a1a1a"
                    border.color: "#28282e"
                    border.width: 1

                    Item {
                        id: iconContainer
                        anchors.centerIn: parent
                        width: 18
                        height: 18

                        Image {
                            id: pickerIcon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/color-picker.svg"
                            sourceSize: Qt.size(16, 16)
                        }
                    }

                    // Tactile bouncy jump and tilt animation
                    ParallelAnimation {
                        id: jumpAnimation
                        SequentialAnimation {
                            NumberAnimation {
                                target: iconContainer
                                property: "y"
                                to: -5
                                duration: 75
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: iconContainer
                                property: "y"
                                to: 0
                                duration: 125
                                easing.type: Easing.OutBounce
                            }
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: iconContainer
                                property: "rotation"
                                to: -15
                                duration: 70
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: iconContainer
                                property: "rotation"
                                to: 0
                                duration: 130
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    MouseArea {
                        id: eyedropperMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            jumpAnimation.restart();
                            root.eyedropperRequested();
                        }
                    }
                }

                // Vertical stack of Hue & Alpha Sliders
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // --- Hue Slider ---
                    Item {
                        id: hueBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        Rectangle {
                            id: hueTrack
                            anchors.fill: parent
                            radius: 6
                            border.color: "#28282e"
                            border.width: 1

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.00
                                    color: "#ff0000"
                                }
                                GradientStop {
                                    position: 0.17
                                    color: "#ffff00"
                                }
                                GradientStop {
                                    position: 0.33
                                    color: "#00ff00"
                                }
                                GradientStop {
                                    position: 0.50
                                    color: "#00ffff"
                                }
                                GradientStop {
                                    position: 0.67
                                    color: "#0000ff"
                                }
                                GradientStop {
                                    position: 0.83
                                    color: "#ff00ff"
                                }
                                GradientStop {
                                    position: 1.00
                                    color: "#ff0000"
                                }
                            }
                        }

                        // Hue Thumb (Matches image: white ring with current hue inside)
                        Item {
                            x: Math.round(root.activeHue * hueBar.width)
                            anchors.verticalCenter: parent.verticalCenter
                            z: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: Qt.hsva(root.activeHue, 1.0, 1.0, 1.0)
                                border.color: "#ffffff"
                                border.width: 3.5

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 2
                                    height: parent.height + 2
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: "#33000000"
                                    border.width: 1
                                    z: -1
                                }
                            }
                        }

                        MouseArea {
                            id: hueMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function updateFromMouse(mouse) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / hueBar.width));
                                root.updateHue(ratio);
                            }

                            onPressed: mouse => updateFromMouse(mouse)
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    updateFromMouse(mouse);
                                }
                            }
                        }
                    }

                    // --- Alpha / Opacity Slider ---
                    Item {
                        id: alphaBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        // Performant checkerboard background (painted once into GPU texture)
                        Canvas {
                            id: checkerCanvas
                            anchors.fill: parent
                            renderTarget: Canvas.Image
                            layer.enabled: true

                            onPaint: {
                                var ctx = getContext("2d");
                                var size = 4;
                                for (var x = 0; x < width; x += size) {
                                    for (var y = 0; y < height; y += size) {
                                        ctx.fillStyle = ((Math.floor(x / size) + Math.floor(y / size)) % 2 === 0) ? "#333333" : "#222222";
                                        ctx.fillRect(x, y, size, size);
                                    }
                                }
                            }

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                        }

                        // Alpha color gradient
                        Rectangle {
                            id: alphaTrack
                            anchors.fill: parent
                            radius: 6
                            border.color: "#28282e"
                            border.width: 1

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 0.0)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 1.0)
                                }
                            }
                        }

                        // Alpha Thumb (Matches image: white ring with current color inside)
                        Item {
                            x: Math.round(root.activeAlpha * alphaBar.width)
                            anchors.verticalCenter: parent.verticalCenter
                            z: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: root.selectedColor
                                border.color: "#ffffff"
                                border.width: 3.5

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 2
                                    height: parent.height + 2
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: "#33000000"
                                    border.width: 1
                                    z: -1
                                }
                            }
                        }

                        MouseArea {
                            id: alphaMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function updateFromMouse(mouse) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / alphaBar.width));
                                root.updateAlpha(ratio);
                            }

                            onPressed: mouse => updateFromMouse(mouse)
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    updateFromMouse(mouse);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
