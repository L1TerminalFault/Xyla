import QtQuick
import QtQuick.Controls
import QtQuick.Window

Item {
    id: root

    property real value: 0.0
    property real stepSize: 0.01
    property real minValue: -999999.0
    property real maxValue: 999999.0
    property int decimals: 2
    property string label: ""
    property string icon: ""
    property alias leadingIcon: root.icon
    property string unit: ""
    property string tooltip: ""

    // Preserved for call-site compatibility
    property color accentColor: "transparent"

    // Colors matching XylaSelect
    property color backgroundColor: "#222222"
    property color hoverColor: "#262626"
    property color borderColor: "#2d2d2d"

    // Target colors with identical RGB to avoid dark intermediary interpolation artifacts
    readonly property color borderIdleColor: "#002d2d2d"
    readonly property color borderActiveColor: "#ff2d2d2d"

    property bool keyframeable: false
    property bool hasKeyframe: false
    signal keyframeToggled

    property var warpCursor: null
    signal valueCommitted(real newValue)

    implicitWidth: 64
    implicitHeight: 28

    // Live preview during active drag
    property real liveDragValue: root.value
    property bool isDragging: dragArea.dragging

    function clamp(v) {
        return Math.max(root.minValue, Math.min(root.maxValue, v));
    }

    function setValue(v, commit) {
        var clamped = clamp(v);
        liveDragValue = clamped;
        if (commit) {
            root.valueCommitted(clamped);
        }
    }

    function globalXFromMouse(mouse) {
        if (mouse.globalPosition !== undefined && mouse.globalPosition !== null)
            return mouse.globalPosition.x;
        return mapToGlobal(mouse.x, mouse.y).x;
    }

    function globalYFromMouse(mouse) {
        if (mouse.globalPosition !== undefined && mouse.globalPosition !== null)
            return mouse.globalPosition.y;
        return mapToGlobal(mouse.x, mouse.y).y;
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 7
        color: inputField.activeFocus || dragArea.containsMouse ? root.hoverColor : root.backgroundColor

        // Fixed 1px border width to prevent layout flicker
        // border.width: 1
        // border.color: (inputField.activeFocus || dragArea.containsMouse || dragArea.pressed) ? root.borderActiveColor : root.borderIdleColor
        clip: true

        Behavior on border.color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        // =====================================================================
        // 1. LEFT-ALIGNED LEADING SLOT (Icon overrides Label)
        // =====================================================================
        Item {
            id: leadContainer
            anchors.left: parent.left
            anchors.leftMargin: (root.icon !== "" || root.label !== "") ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: (root.icon !== "" || root.label !== "") ? childrenRect.width : 0
            height: parent.height

            // Optional Leading Icon (Overrides Text Label)
            Image {
                id: leadIcon
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                source: root.icon
                sourceSize.width: 13
                sourceSize.height: 13
                opacity: 0.7
            }

            // Left-anchored Text Label (Rendered only when icon is empty)
            Text {
                id: labelText
                visible: root.icon === "" && root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: "#888888"
                font.pixelSize: 12
                // font.bold: true
            }
        }

        // =====================================================================
        // 2. KEYFRAME TOGGLE DIAMOND (RIGHT ANCHORED)
        // =====================================================================
        Item {
            id: kfContainer
            visible: root.keyframeable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.keyframeable ? 22 : 0
            z: 10

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                rotation: 45
                color: root.hasKeyframe ? "#ffffff" : (kfMouse.containsMouse ? "#555555" : "transparent")
                border.color: root.hasKeyframe ? "#ffffff" : (kfMouse.containsMouse ? "#888888" : "#444444")
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }

            MouseArea {
                id: kfMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keyframeToggled()
            }
        }

        // =====================================================================
        // 3. CENTERED NUMERICAL VALUE (Balanced between Lead and Keyframe)
        // =====================================================================
        Item {
            id: valueArea
            anchors.left: leadContainer.right
            anchors.right: kfContainer.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Row {
                anchors.centerIn: parent
                spacing: 2

                TextInput {
                    id: inputField
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.family: "Monospace"
                    selectByMouse: true

                    width: Math.max(16, contentWidth + 2)
                    height: valueArea.height

                    Binding on text {
                        when: !inputField.activeFocus
                        value: (root.isDragging ? root.liveDragValue : root.value).toFixed(root.decimals)
                    }

                    onAccepted: {
                        commitManualText();
                        focus = false;
                    }
                    onEditingFinished: {
                        commitManualText();
                        focus = false;
                    }

                    function commitManualText() {
                        var parsed = parseFloat(text);
                        if (!isNaN(parsed))
                            root.setValue(parsed, true);
                    }
                }

                // Suffix attached directly next to the value
                Text {
                    id: unitText
                    text: root.unit
                    color: "#888888"
                    font.pixelSize: 12
                    font.family: "Monospace"
                    visible: text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // =====================================================================
        // 4. DRAG / SCRUB MOUSE AREA
        // =====================================================================
        MouseArea {
            id: dragArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: root.keyframeable ? 22 : 0
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            visible: !inputField.activeFocus
            z: 1

            property real lastGlobalX: 0
            property bool dragging: false

            onDoubleClicked: {
                inputField.forceActiveFocus();
                inputField.selectAll();
            }

            onPressed: function (mouse) {
                lastGlobalX = root.globalXFromMouse(mouse);
                root.liveDragValue = root.value;
                dragging = true;
            }

            onReleased: function (mouse) {
                dragging = false;
                root.valueCommitted(root.liveDragValue);
            }

            onCanceled: {
                dragging = false;
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !dragging)
                    return;
                var currentGlobalX = root.globalXFromMouse(mouse);
                var deltaX = currentGlobalX - lastGlobalX;

                root.setValue(root.liveDragValue + deltaX * root.stepSize, true);

                if (typeof root.warpCursor === "function") {
                    var screenW = Screen.width;
                    var margin = 2;
                    var newX = currentGlobalX;
                    var warped = false;

                    if (currentGlobalX <= margin) {
                        newX = screenW - margin - 1;
                        warped = true;
                    } else if (currentGlobalX >= screenW - margin) {
                        newX = margin + 1;
                        warped = true;
                    }

                    if (warped) {
                        root.warpCursor(newX, root.globalYFromMouse(mouse));
                        lastGlobalX = newX;
                        return;
                    }
                }

                lastGlobalX = currentGlobalX;
            }
        }
    }
}
