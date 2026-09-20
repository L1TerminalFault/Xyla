import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window

Item {
    id: root

    property color selectedColor: "#ffffff"
    property bool keyframeable: false
    property bool hasKeyframe: false
    signal colorCommitted(color newColor)
    signal gradientCommitted(var gradientData)
    signal keyframeToggled

    implicitWidth: 160
    implicitHeight: 32

    // Fill Type Mode: "solid" | "gradient"
    property string fillMode: "solid"

    property int gradientType: 1 // 1: Linear, 2: Radial
    property real gradientAngle: 0.0
    property int activeStopIndex: 0
    property var gradientStops: [
        {
            position: 0.0,
            color: "#C4C4C4"
        },
        {
            position: 1.0,
            color: "#5E5E5E"
        }
    ]

    function commitCurrentGradient() {
        if (!root)
            return;

        if (root.fillMode !== "gradient") {
            root.gradientCommitted({
                type: 0,
                stops: []
            });
            return;
        }

        var sorted = root.gradientStops.slice().sort((a, b) => a.position - b.position);
        var stopsData = [];
        for (var i = 0; i < sorted.length; ++i) {
            stopsData.push({
                position: sorted[i].position,
                color: Qt.color(sorted[i].color).toString()
            });
        }

        var gradConfig = {
            type: root.gradientType,
            scope: 0,
            angleDegrees: root.gradientAngle,
            startX: 0.0,
            startY: 0.0,
            endX: 1.0,
            endY: 0.0,
            radialRadius: 0.5,
            stops: stopsData
        };

        root.gradientCommitted(gradConfig);
    }

    function addGradientStop(pos, col) {
        var stops = root.gradientStops.slice();
        stops.push({
            position: Math.max(0.0, Math.min(1.0, pos)),
            color: col ? col.toString() : "#ffffff"
        });
        stops.sort((a, b) => a.position - b.position);
        root.gradientStops = stops;
        root.activeStopIndex = stops.findIndex(s => Math.abs(s.position - pos) < 0.01);
        root.commitCurrentGradient();
    }

    function removeGradientStop(index) {
        if (root.gradientStops.length <= 2)
            return;
        var stops = root.gradientStops.slice();
        stops.splice(index, 1);
        root.gradientStops = stops;
        root.activeStopIndex = Math.max(0, Math.min(stops.length - 1, root.activeStopIndex));
        root.commitCurrentGradient();
    }

    function reverseGradientStops() {
        var stops = root.gradientStops.slice();
        for (var i = 0; i < stops.length; ++i) {
            stops[i].position = 1.0 - stops[i].position;
        }
        stops.sort((a, b) => a.position - b.position);
        root.gradientStops = stops;
        root.commitCurrentGradient();
    }

    function selectStop(index) {
        if (index < 0 || index >= root.gradientStops.length)
            return;
        root.activeStopIndex = index;
        var col = Qt.color(root.gradientStops[index].color);
        root.selectedColor = col;
        if (col.hsvHue >= 0)
            root.activeHue = col.hsvHue;
        root.activeSat = col.hsvSaturation;
        root.activeVal = col.hsvValue;
        root.activeAlpha = col.a;
    }

    property string colorMode: "RGB"
    property real activeHue: selectedColor.hsvHue >= 0 ? selectedColor.hsvHue : 0.66
    property real activeSat: selectedColor.hsvSaturation
    property real activeVal: selectedColor.hsvValue
    property real activeAlpha: selectedColor.a

    property var colorHistory: ["#ffffffff", "#e0e0e0ff", "#000000ff", "#222222ff", "#10b981ff", "#3b82f6ff", "#f59e0bff", "#ef4444ff", "#8b5cf6ff", "#06b6d4ff", "#64748bff", "#334155ff"]

    function pushToHistory(col) {
        var hex = col.toString();
        var list = root.colorHistory.slice();
        var idx = list.indexOf(hex);
        if (idx !== -1)
            list.splice(idx, 1);
        list.unshift(hex);
        if (list.length > 24)
            list.pop();
        root.colorHistory = list;
    }

    function applyColor(col) {
        root.selectedColor = col;
        if (root.fillMode === "gradient") {
            if (root.gradientStops && root.gradientStops[root.activeStopIndex]) {
                var stops = root.gradientStops.slice();
                stops[root.activeStopIndex].color = col.toString();
                root.gradientStops = stops;
                root.commitCurrentGradient();
            }
        } else {
            root.colorCommitted(col);
        }
    }

    onSelectedColorChanged: {
        if (!satValMouse.pressed && !hueMouse.pressed && !alphaMouse.pressed) {
            if (selectedColor.hsvHue >= 0) {
                root.activeHue = selectedColor.hsvHue;
            }
            root.activeSat = selectedColor.hsvSaturation;
            root.activeVal = selectedColor.hsvValue;
            root.activeAlpha = selectedColor.a;

            if (root.fillMode === "gradient" && root.gradientStops && root.gradientStops[root.activeStopIndex]) {
                var stops = root.gradientStops.slice();
                stops[root.activeStopIndex].color = selectedColor.toString();
                root.gradientStops = stops;
                root.commitCurrentGradient();
            }
        }
    }

    readonly property int rValue: Math.round(selectedColor.r * 255)
    readonly property int gValue: Math.round(selectedColor.g * 255)
    readonly property int bValue: Math.round(selectedColor.b * 255)
    readonly property int hValue: Math.round(activeHue * 360)
    readonly property int sValue: Math.round(activeSat * 100)
    readonly property int vValue: Math.round(activeVal * 100)
    readonly property int alphaPercent: Math.round(activeAlpha * 100)
    readonly property string hexValue: {
        var str = selectedColor.toString().toUpperCase();
        return str.startsWith("#") ? str.substring(1) : str;
    }

    function updateRgb(r, g, b) {
        var col = Qt.rgba(r / 255.0, g / 255.0, b / 255.0, root.activeAlpha);
        if (col.hsvHue >= 0)
            root.activeHue = col.hsvHue;
        root.activeSat = col.hsvSaturation;
        root.activeVal = col.hsvValue;
        applyColor(col);
    }

    function updateHsv(h, s, v) {
        root.activeHue = h / 360.0;
        root.activeSat = s / 100.0;
        root.activeVal = v / 100.0;
        var col = Qt.hsva(root.activeHue, root.activeSat, root.activeVal, root.activeAlpha);
        applyColor(col);
    }

    function updateHue(h) {
        root.activeHue = h;
        var col = Qt.hsva(root.activeHue, root.activeSat, root.activeVal, root.activeAlpha);
        applyColor(col);
    }

    function updateAlpha(a) {
        root.activeAlpha = a;
        var col = Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, a);
        applyColor(col);
    }

    function openPickerWindow() {
        if (!root.Window.window)
            return;
        var globalPos = root.mapToItem(null, 0, 0);
        var winW = root.Window.window.width;
        var winH = root.Window.window.height;
        var popW = colorPopup.width;
        var popH = colorPopup.implicitHeight > 0 ? colorPopup.implicitHeight : 460;

        var targetX = -popW - 8;
        if (globalPos.x + targetX < 12) {
            targetX = root.width + 8;
        }

        var targetY = -12;
        if (globalPos.y + targetY + popH > winH - 12) {
            targetY = (winH - 12) - (globalPos.y + popH);
        }

        colorPopup.x = targetX;
        colorPopup.y = targetY;
        colorPopup.open();
    }

    Rectangle {
        id: openerRect
        anchors.fill: parent
        color: "transparent"
        radius: 7
        border.color: openerMouse.containsMouse || colorPopup.visible ? "#3a3a3a" : "#2d2d2d"
        border.width: 1

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8

            // Swatch Preview
            Rectangle {
                Layout.preferredWidth: parent.height - 12
                Layout.preferredHeight: parent.height - 12
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                clip: true
                color: root.fillMode === "solid" ? root.selectedColor : "transparent"
                border.color: "#3a3a3a"
                border.width: 1

                Canvas {
                    id: openerGradCanvas
                    visible: root.fillMode === "gradient"
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    property var stopsWatcher: root.gradientStops
                    onStopsWatcherChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var grad = ctx.createLinearGradient(0, 0, width, height);
                        for (var i = 0; i < root.gradientStops.length; ++i) {
                            var s = root.gradientStops[i];
                            grad.addColorStop(s.position, s.color);
                        }
                        ctx.fillStyle = grad;
                        ctx.fillRect(0, 0, width, height);
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.fillMode === "gradient" ? (root.gradientType === 2 ? "Radial" : "Linear") : (root.hexValue.length > 6 ? root.hexValue.substring(2) : root.hexValue)
                color: "#ffffff"
                font.pixelSize: 11
                font.family: "Monospace"
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: parent.height - 12
                Layout.alignment: Qt.AlignVCenter
                color: "#2d2d2d"
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    text: root.alphaPercent
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.family: "Monospace"
                }
                Text {
                    text: "%"
                    color: "#888888"
                    font.pixelSize: 10
                    font.family: "Monospace"
                }
            }

            Item {
                visible: root.keyframeable
                Layout.preferredWidth: 14
                Layout.preferredHeight: parent.height
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    rotation: 45
                    color: root.hasKeyframe ? "#ffffff" : "transparent"
                    border.color: root.hasKeyframe ? "#ffffff" : "#666666"
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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (!root.keyframeable || mouse.x < parent.width - 24) {
                    root.openPickerWindow();
                }
            }
        }
    }

    XylaEyedropper {
        id: eyedropperRoot
        grabTarget: Window.window ? Window.window.grabRoot : null   // id of your main window's root Item
        onColorPicked: c => {
            var col = Qt.rgba(c.r, c.g, c.b, root.activeAlpha);
            if (col.hsvHue >= 0)
                root.activeHue = col.hsvHue;
            root.activeSat = col.hsvSaturation;
            root.activeVal = col.hsvValue;
            root.applyColor(col);
        }
    }

    Popup {
        id: colorPopup
        parent: root
        width: 300
        padding: 10
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        opacity: eyedropperRoot.picking ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 120;
                easing.type: Easing.OutCubic
            }
        }

        onClosed: {
            root.pushToHistory(root.selectedColor);
        }

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        background: Rectangle {
            // id: popupSurface

            anchors.fill: parent
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

            // NumberAnimation {
            //     property: "x"
            //     from: x + 20 // Starts slightly to the right
            //     to: 0
            //     duration: 150
            //     easing.type: Easing.OutCubic
            // }
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

            // NumberAnimation {
            //     property: "x"
            //     from: 0
            //     to: x - 20 // Exits toward the left
            //     duration: 120
            //     easing.type: Easing.OutCubic
            // }
        }

        contentItem: ColumnLayout {
            id: mainLayout
            spacing: 10
            width: parent.width

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                MouseArea {
                    id: windowDragArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    preventStealing: true

                    property real startGlobalX: 0
                    property real startGlobalY: 0
                    property real startPopX: 0
                    property real startPopY: 0

                    onPressed: mouse => {
                        var p = mapToGlobal(mouse.x, mouse.y);
                        startGlobalX = p.x;
                        startGlobalY = p.y;
                        startPopX = colorPopup.x;
                        startPopY = colorPopup.y;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            var p = mapToGlobal(mouse.x, mouse.y);
                            colorPopup.x = startPopX + (p.x - startGlobalX);
                            colorPopup.y = startPopY + (p.y - startGlobalY);
                        }
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Solid Tab
                    XylaIconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        // anchors.centerIn: parent
                        iconSource: "qrc:/assets/icons/background.svg"
                        tooltip: "Solid Color"
                        ghost: true
                        active: root.fillMode === "solid"
                        onClicked: {
                            root.fillMode = "solid";
                            root.commitCurrentGradient();
                            root.colorCommitted(root.selectedColor);
                        }
                    }
                    // Gradient Tab
                    XylaIconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        // anchors.centerIn: parent
                        iconSource: "qrc:/assets/icons/grain.svg"
                        tooltip: "Gradient Color"
                        ghost: true
                        active: root.fillMode === "gradient"
                        onClicked: {
                            root.fillMode = "gradient";
                            root.commitCurrentGradient();
                        }
                    }
                }

                // Close Button
                XylaIconButton {

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    iconSource: "qrc:/assets/icons/x.svg"
                    ghost: true

                    onClicked: colorPopup.close()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    XylaSelect {
                        id: modeSelect
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 28
                        model: ["RGB", "HEX", "HSV"]
                        backgroundColor: "transparent"
                        borderColor: "#2d2d2d"
                        currentIndex: 0
                        onActivated: index => {
                            root.colorMode = modeSelect.model[index];
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
                        radius: 7
                        color: "transparent"
                        border.color: hexInput.activeFocus ? "#4a4a4a" : "#2d2d2d"
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
                                var col = Qt.color(text.startsWith("#") ? text : "#" + text);
                                if (col.toString() !== "") {
                                    if (col.hsvHue >= 0)
                                        root.activeHue = col.hsvHue;
                                    root.activeSat = col.hsvSaturation;
                                    root.activeVal = col.hsvValue;
                                    root.applyColor(col);
                                } else {
                                    text = root.hexValue;
                                }
                                hexInput.focus = false;
                            }
                        }
                    }
                }

                // 2D Saturation/Value Field
                Item {
                    id: satValContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140

                    Canvas {
                        id: satValCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.Image
                        property real hueWatcher: root.activeHue
                        onHueWatcherChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var r = 7;
                            var w = width;
                            var h = height;

                            ctx.beginPath();
                            if (typeof ctx.roundRect === "function") {
                                ctx.roundRect(0, 0, w, h, r);
                            } else {
                                ctx.moveTo(r, 0);
                                ctx.lineTo(w - r, 0);
                                ctx.arcTo(w, 0, w, r, r);
                                ctx.lineTo(w, h - r);
                                ctx.arcTo(w, h, w - r, h, r);
                                ctx.lineTo(r, h);
                                ctx.arcTo(0, h, 0, h - r, r);
                                ctx.lineTo(0, r);
                                ctx.arcTo(0, 0, r, 0, r);
                            }
                            ctx.clip();

                            ctx.fillStyle = Qt.hsva(root.activeHue, 1.0, 1.0, 1.0).toString();
                            ctx.fillRect(0, 0, w, h);

                            var gradW = ctx.createLinearGradient(0, 0, w, 0);
                            gradW.addColorStop(0, "#ffffff");
                            gradW.addColorStop(1, "rgba(255,255,255,0)");
                            ctx.fillStyle = gradW;
                            ctx.fillRect(0, 0, w, h);

                            var gradB = ctx.createLinearGradient(0, 0, 0, h);
                            gradB.addColorStop(0, "rgba(0,0,0,0)");
                            gradB.addColorStop(1, "#000000");
                            ctx.fillStyle = gradB;
                            ctx.fillRect(0, 0, w, h);
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: "transparent"
                        border.color: "#2d2d2d"
                        border.width: 1
                    }

                    Item {
                        x: Math.max(0, Math.min(satValContainer.width, Math.round(root.activeSat * satValContainer.width)))
                        y: Math.max(0, Math.min(satValContainer.height, Math.round((1.0 - root.activeVal) * satValContainer.height)))

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.hsva(root.activeHue, root.activeSat, root.activeVal, 1.0)
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
                            var s = Math.max(0.0, Math.min(1.0, mouse.x / satValContainer.width));
                            var v = Math.max(0.0, Math.min(1.0, 1.0 - (mouse.y / satValContainer.height)));
                            root.activeSat = s;
                            root.activeVal = v;
                            var col = Qt.hsva(root.activeHue, s, v, root.activeAlpha);
                            root.applyColor(col);
                        }

                        onPressed: mouse => updateFromMouse(mouse)
                        onPositionChanged: mouse => {
                            if (pressed) {
                                updateFromMouse(mouse);
                            }
                        }
                    }
                }

                // Eyedropper & Sliders Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    XylaIconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        ghost: true
                        iconSource: "qrc:/assets/icons/color-picker.svg"

                        onClicked: eyedropperRoot.startPicking()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Hue Slider
                        Item {
                            id: hueBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                border.color: "#2d2d2d"
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

                            Item {
                                x: Math.max(10, Math.min(hueBar.width - 10, Math.round(root.activeHue * hueBar.width)))
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: Qt.hsva(root.activeHue, 1.0, 1.0, 1.0)
                                    border.color: "#ffffff"
                                    border.width: 3
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

                        // Alpha Slider
                        Item {
                            id: alphaBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 15
                            // height: Layout.preferredHeight

                            Canvas {
                                id: alphaCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                property color colorWatcher: root.selectedColor
                                onColorWatcherChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var r = 9;
                                    var w = width;
                                    var h = height;

                                    ctx.beginPath();
                                    if (typeof ctx.roundRect === "function") {
                                        ctx.roundRect(0, 0, w, h, r);
                                    } else {
                                        ctx.arc(r, r, r, Math.PI, 1.5 * Math.PI);
                                        ctx.arc(w - r, r, r, 1.5 * Math.PI, 2 * Math.PI);
                                        ctx.arc(w - r, h - r, r, 0, 0.5 * Math.PI);
                                        ctx.arc(r, h - r, r, 0.5 * Math.PI, Math.PI);
                                        ctx.closePath();
                                    }
                                    ctx.clip();

                                    var s = 4;
                                    for (var x = 0; x < w; x += s) {
                                        for (var y = 0; y < h; y += s) {
                                            ctx.fillStyle = ((Math.floor(x / s) + Math.floor(y / s)) % 2 === 0) ? "#333333" : "#222222";
                                            ctx.fillRect(x, y, s, s);
                                        }
                                    }

                                    var grad = ctx.createLinearGradient(0, 0, w, 0);
                                    grad.addColorStop(0, Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 0.0).toString());
                                    grad.addColorStop(1, Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 1.0).toString());
                                    ctx.fillStyle = grad;
                                    ctx.fillRect(0, 0, w, h);
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: "transparent"
                                border.color: "#2d2d2d"
                                border.width: 1
                            }

                            Item {
                                x: Math.max(10, Math.min(alphaBar.width - 10, Math.round(root.activeAlpha * alphaBar.width)))
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: root.selectedColor
                                    border.color: "#ffffff"
                                    border.width: 3
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

            Item {
                Layout.fillWidth: true
                // Animate height smoothly based on fillMode state
                Layout.preferredHeight: root.fillMode === "gradient" ? gradientContent.implicitHeight : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                ColumnLayout {
                    id: gradientContent
                    // visible: root.fillMode === "gradient"
                    // Layout.fillWidth: true
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        XylaSelect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            model: ["Linear", "Radial"]
                            currentIndex: root.gradientType === 2 ? 1 : 0
                            onActivated: index => {
                                root.gradientType = index === 1 ? 2 : 1;
                                root.commitCurrentGradient();
                            }
                        }

                        XylaIconButton {

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            iconSource: "qrc:/assets/icons/arrows-left-right.svg"
                            ghost: true

                            onClicked: root.reverseGradientStops()
                        }

                        XylaIconButton {

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            iconSource: "qrc:/assets/icons/rotate.svg"
                            ghost: true

                            onClicked: {
                                root.gradientAngle = (root.gradientAngle + 90.0) % 360.0;
                                root.commitCurrentGradient();
                            }
                        }
                    }

                    Item {
                        id: gradientTrackArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        property int draggingStopIndex: -1

                        Rectangle {
                            id: gradBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.bottom: parent.bottom
                            height: 28
                            radius: 6
                            clip: true
                            border.color: "#2d2d2d"
                            border.width: 1

                            Canvas {
                                id: gradCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                property var stopsWatcher: root.gradientStops
                                property int typeWatcher: root.gradientType
                                onStopsWatcherChanged: requestPaint()
                                onTypeWatcherChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var w = width;
                                    var h = height;
                                    var r = 6;
                                    ctx.beginPath();
                                    ctx.moveTo(r, 0);
                                    ctx.lineTo(width - r, 0);
                                    ctx.arcTo(width, 0, width, r, r);
                                    ctx.lineTo(width, height - r);
                                    ctx.arcTo(width, height, width - r, height, r);
                                    ctx.lineTo(r, height);
                                    ctx.arcTo(0, height, 0, height - r, r);
                                    ctx.lineTo(0, r);
                                    ctx.arcTo(0, 0, r, 0, r);
                                    ctx.closePath();
                                    ctx.clip();

                                    var grad = ctx.createLinearGradient(0, 0, w, 0);
                                    for (var i = 0; i < root.gradientStops.length; ++i) {
                                        var st = root.gradientStops[i];
                                        grad.addColorStop(Math.max(0.0, Math.min(1.0, st.position)), st.color);
                                    }
                                    ctx.fillStyle = grad;
                                    ctx.fillRect(0, 0, w, h);
                                }
                            }
                        }

                        Repeater {
                            model: root.gradientStops

                            Item {
                                id: thumbItem
                                property int stopIdx: index
                                property bool isSelected: root.activeStopIndex === index

                                x: Math.round(gradBar.x + modelData.position * gradBar.width - 10)
                                y: gradBar.y - 14 // 2
                                width: 20
                                height: 28
                                z: isSelected ? 10 : 2

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 15
                                    width: 10
                                    height: 10
                                    rotation: 45
                                    radius: 1.5
                                    color: thumbItem.isSelected ? "#2555D3" : "#2d2d2d"
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 20
                                    radius: 4
                                    color: thumbItem.isSelected ? "#2555D3" : "#2d2d2d"
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    // Inner Color Swatch
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: 3
                                        color: modelData.color
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: trackMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function findStopNear(mouseX) {
                                var stops = root.gradientStops;
                                var bestIdx = -1;
                                var bestDist = 16;

                                if (root.activeStopIndex >= 0 && root.activeStopIndex < stops.length) {
                                    var selCenterX = gradBar.x + stops[root.activeStopIndex].position * gradBar.width;
                                    if (Math.abs(mouseX - selCenterX) <= 12) {
                                        return root.activeStopIndex;
                                    }
                                }

                                for (var i = 0; i < stops.length; ++i) {
                                    var centerX = gradBar.x + stops[i].position * gradBar.width;
                                    var dist = Math.abs(mouseX - centerX);
                                    if (dist < bestDist) {
                                        bestDist = dist;
                                        bestIdx = i;
                                    }
                                }
                                return bestIdx;
                            }

                            onPressed: mouse => {
                                var foundIdx = findStopNear(mouse.x);
                                if (foundIdx !== -1) {
                                    gradientTrackArea.draggingStopIndex = foundIdx;
                                    root.selectStop(foundIdx);
                                } else {
                                    var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - gradBar.x) / gradBar.width));
                                    root.addGradientStop(ratio, root.selectedColor);
                                    gradientTrackArea.draggingStopIndex = root.activeStopIndex;
                                }
                            }

                            onPositionChanged: mouse => {
                                if (pressed && gradientTrackArea.draggingStopIndex >= 0 && gradientTrackArea.draggingStopIndex < root.gradientStops.length) {
                                    var newRatio = Math.max(0.0, Math.min(1.0, (mouse.x - gradBar.x) / gradBar.width));
                                    var stops = root.gradientStops.slice();
                                    stops[gradientTrackArea.draggingStopIndex].position = newRatio;
                                    root.gradientStops = stops;
                                    gradCanvas.requestPaint();
                                    root.commitCurrentGradient();
                                }
                            }

                            onReleased: {
                                if (gradientTrackArea.draggingStopIndex >= 0 && gradientTrackArea.draggingStopIndex < root.gradientStops.length) {
                                    var targetPos = root.gradientStops[gradientTrackArea.draggingStopIndex].position;
                                    var stops = root.gradientStops.slice().sort((a, b) => a.position - b.position);
                                    root.gradientStops = stops;
                                    root.activeStopIndex = stops.findIndex(s => Math.abs(s.position - targetPos) < 0.001);
                                    root.commitCurrentGradient();
                                }
                                gradientTrackArea.draggingStopIndex = -1;
                            }

                            onCanceled: {
                                gradientTrackArea.draggingStopIndex = -1;
                            }
                        }
                    }

                    // Stops Section Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 6

                        Text {
                            text: "Stops"
                            color: "#ffffff"
                            font.pixelSize: 11
                            // font.bold: true
                            Layout.fillWidth: true
                        }

                        XylaIconButton {

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            iconSource: "qrc:/assets/icons/plus.svg"
                            ghost: true

                            onClicked: {
                                root.addGradientStop(0.5, root.selectedColor);
                            }
                        }
                    }

                    // Stops List
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.gradientStops

                            Rectangle {
                                id: stopRow
                                property int rowIndex: index
                                property color stopCol: Qt.color(modelData.color)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: 6
                                color: root.activeStopIndex === index ? "#252525" : "#181818"
                                // border.color: root.activeStopIndex === index ? "#444444" : "#2a2a2a"
                                // border.width: 1
                                //
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    // 1. Position Percentage Input
                                    Rectangle {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 28
                                        radius: 4
                                        color: "#252525" // posInput.activeFocus ? "#181818" : "#252525"
                                        // border.color: posInput.activeFocus ? "#3b82f6" : "transparent"
                                        // border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            TextInput {
                                                id: posInput
                                                width: 24
                                                selectByMouse: true
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.family: "Monospace"
                                                verticalAlignment: TextInput.AlignVCenter
                                                horizontalAlignment: TextInput.AlignRight
                                                text: Math.round(modelData.position * 100)

                                                onActiveFocusChanged: {
                                                    if (activeFocus) {
                                                        selectAll();
                                                    } else {
                                                        text = Math.round(modelData.position * 100);
                                                    }
                                                }

                                                function commitPosition() {
                                                    var val = parseFloat(text);
                                                    if (!isNaN(val)) {
                                                        var stops = root.gradientStops.slice();
                                                        stops[stopRow.rowIndex].position = Math.max(0.0, Math.min(100.0, val)) / 100.0;
                                                        stops.sort((a, b) => a.position - b.position);
                                                        root.gradientStops = stops;
                                                        root.commitCurrentGradient();
                                                    } else {
                                                        text = Math.round(modelData.position * 100);
                                                    }
                                                }

                                                onAccepted: {
                                                    commitPosition();
                                                    posInput.focus = false;
                                                }
                                                onEditingFinished: commitPosition()
                                            }

                                            Text {
                                                text: "%"
                                                color: "#777777"
                                                font.pixelSize: 12
                                                font.family: "Monospace"
                                            }
                                        }
                                    }

                                    // 2. Color Swatch (Click to Select)
                                    // 3. Editable Hex Input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        radius: 4
                                        color: "#252525" // hexStopInput.activeFocus ? "#181818" : "#252525"
                                        // border.color: hexStopInput.activeFocus ? "#3b82f6" : "transparent"
                                        // border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 2

                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 3
                                                color: modelData.color
                                                // border.color: "#3B82F6"
                                                // border.width: root.activeStopIndex === stopRow.rowIndex ? 1 : 0

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.selectStop(stopRow.rowIndex)
                                                }
                                            }

                                            TextInput {
                                                id: hexStopInput
                                                Layout.fillWidth: true
                                                selectByMouse: true
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.family: "Monospace"
                                                verticalAlignment: TextInput.AlignVCenter
                                                text: {
                                                    var hx = stopRow.stopCol.toString().toUpperCase();
                                                    return hx.startsWith("#") ? hx.substring(1, 7) : hx.substring(0, 6);
                                                }

                                                onActiveFocusChanged: {
                                                    if (activeFocus) {
                                                        selectAll();
                                                    } else {
                                                        var hx = stopRow.stopCol.toString().toUpperCase();
                                                        text = hx.startsWith("#") ? hx.substring(1, 7) : hx.substring(0, 6);
                                                    }
                                                }

                                                function commitHex() {
                                                    var raw = text.trim();
                                                    var col = Qt.color(raw.startsWith("#") ? raw : "#" + raw);
                                                    if (col.toString() !== "") {
                                                        var stops = root.gradientStops.slice();
                                                        var merged = Qt.rgba(col.r, col.g, col.b, stopRow.stopCol.a);
                                                        stops[stopRow.rowIndex].color = merged.toString();
                                                        root.gradientStops = stops;
                                                        if (root.activeStopIndex === stopRow.rowIndex) {
                                                            root.selectStop(stopRow.rowIndex);
                                                        }
                                                        root.commitCurrentGradient();
                                                    } else {
                                                        var hx = stopRow.stopCol.toString().toUpperCase();
                                                        text = hx.startsWith("#") ? hx.substring(1, 7) : hx.substring(0, 6);
                                                    }
                                                }

                                                onAccepted: {
                                                    commitHex();
                                                    hexStopInput.focus = false;
                                                }
                                                onEditingFinished: commitHex()
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 42
                                                Layout.preferredHeight: 28
                                                radius: 4
                                                color: "#252525" // alphaStopInput.activeFocus ? "#181818" : "#252525"
                                                // border.color: alphaStopInput.activeFocus ? "#3b82f6" : "transparent"
                                                // border.width: 1

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 1

                                                    TextInput {
                                                        id: alphaStopInput
                                                        width: 22
                                                        selectByMouse: true
                                                        color: "#ffffff"
                                                        font.pixelSize: 12
                                                        font.family: "Monospace"
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        horizontalAlignment: TextInput.AlignRight
                                                        text: Math.round(stopRow.stopCol.a * 100)

                                                        onActiveFocusChanged: {
                                                            if (activeFocus) {
                                                                selectAll();
                                                            } else {
                                                                text = Math.round(stopRow.stopCol.a * 100);
                                                            }
                                                        }

                                                        function commitAlpha() {
                                                            var val = parseFloat(text);
                                                            if (!isNaN(val)) {
                                                                var a = Math.max(0.0, Math.min(100.0, val)) / 100.0;
                                                                var stops = root.gradientStops.slice();
                                                                var c = stopRow.stopCol;
                                                                var merged = Qt.rgba(c.r, c.g, c.b, a);
                                                                stops[stopRow.rowIndex].color = merged.toString();
                                                                root.gradientStops = stops;
                                                                if (root.activeStopIndex === stopRow.rowIndex) {
                                                                    root.selectStop(stopRow.rowIndex);
                                                                }
                                                                root.commitCurrentGradient();
                                                            } else {
                                                                text = Math.round(stopRow.stopCol.a * 100);
                                                            }
                                                        }

                                                        onAccepted: {
                                                            commitAlpha();
                                                            alphaStopInput.focus = false;
                                                        }
                                                        onEditingFinished: commitAlpha()
                                                    }

                                                    Text {
                                                        text: "%"
                                                        color: "#777777"
                                                        font.pixelSize: 12
                                                        font.family: "Monospace"
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            z: -1
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectStop(stopRow.rowIndex)
                                        }
                                    }

                                    // 4. Editable Alpha % Input

                                    // 5. Remove Stop Button
                                    XylaIconButton {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        ghost: true
                                        iconSource: "qrc:/assets/icons/minus.svg"

                                        onClicked: root.removeGradientStop(stopRow.rowIndex)
                                    }
                                }

                                // Click row background to select
                                MouseArea {
                                    anchors.fill: parent
                                    z: -2
                                    onClicked: root.selectStop(stopRow.rowIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
