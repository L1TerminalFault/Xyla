import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ColumnLayout {
    id: root

    property var clipData: null
    property string clipId: clipData?.clipId ?? ""
    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    readonly property bool isTextClip: {
        if (clipData && clipData.isTextClip !== undefined && clipData.isTextClip !== null)
            return Boolean(clipData.isTextClip);
        if (clipData && clipData.assetId && (clipData.assetId.indexOf("asset_title_") !== -1 || clipData.assetId.indexOf("title") !== -1))
            return true;
        return false;
    }

    // Local model list that only refreshes when animators are added/removed, avoiding mouse drag cancellation
    property var cachedAnimators: []

    function reloadAnimators() {
        if (root.activeTimelineModel && root.clipId && root.activeTimelineModel.getTextAnimators) {
            cachedAnimators = root.activeTimelineModel.getTextAnimators(root.clipId);
        } else {
            cachedAnimators = clipData?.textAnimators ?? [];
        }
    }

    onClipIdChanged: reloadAnimators()
    Component.onCompleted: reloadAnimators()

    spacing: 10
    Layout.fillWidth: true

    // =========================================================================
    // TOP ACTION BAR
    // =========================================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        Text {
            text: "Text Modifiers"
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: 120
            radius: 4
            color: addMouse.containsMouse ? "#262626" : "#1c1c1c"
            border.color: "#333333"
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                Image {
                    width: 12
                    height: 12
                    source: "qrc:/assets/icons/plus.svg"
                    sourceSize: Qt.size(12, 12)
                }

                Text {
                    text: "Add Animator"
                    color: "#ffffff"
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activeTimelineModel && root.clipId) {
                        root.activeTimelineModel.addTextAnimator(root.clipId, "Animator " + (root.cachedAnimators.length + 1));
                        root.reloadAnimators();
                    }
                }
            }
        }
    }

    // =========================================================================
    // EMPTY STATES
    // =========================================================================
    Item {
        visible: !root.clipId
        Layout.fillWidth: true
        Layout.preferredHeight: 120

        Text {
            anchors.centerIn: parent
            text: "No clip selected"
            color: "#666666"
            font.pixelSize: 12
        }
    }

    Item {
        visible: root.clipId && root.cachedAnimators.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 120

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No Text Animators Added"
                color: "#888888"
                font.pixelSize: 12
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Click '+ Add Animator' to create kinetic text effects"
                color: "#555555"
                font.pixelSize: 10
            }
        }
    }

    // =========================================================================
    // BLENDER-STYLE MODIFIER STACK
    // =========================================================================
    Repeater {
        model: root.cachedAnimators

        Rectangle {
            id: modifierCard
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight
            radius: 6
            color: "#141416"
            border.color: "#28282e"
            border.width: 1

            property int animIndex: index
            property var animData: modelData
            property bool expanded: true

            function commit(prop, val) {
                if (root.activeTimelineModel && root.clipId) {
                    modifierCard.animData[prop] = val;
                    root.activeTimelineModel.updateClipProperty(root.clipId, "text.animator." + animIndex + "." + prop, val);
                }
            }

            function toggleKf(prop, val) {
                if (root.activeTimelineModel && root.clipId) {
                    var curFrame = root.activeTimelineModel.currentFrame !== undefined ? root.activeTimelineModel.currentFrame : 0;
                    root.activeTimelineModel.toggleKeyframe(root.clipId, "text.animator." + animIndex + "." + prop, curFrame, val);
                }
            }

            ColumnLayout {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                // --- HEADER ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: headerArea.containsMouse ? "#202024" : "#19191d"
                    border.color: "#24242a"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Image {
                            width: 12
                            height: 12
                            source: "qrc:/assets/icons/chevron-right.svg"
                            sourceSize: Qt.size(12, 12)
                            rotation: modifierCard.expanded ? 90 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            text: "✦"
                            color: "#3b82f6"
                            font.pixelSize: 12
                        }

                        TextInput {
                            id: nameInput
                            text: modifierCard.animData?.name ?? "Animator"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onAccepted: {
                                modifierCard.commit("name", text);
                                focus = false;
                            }
                        }

                        Image {
                            width: 14
                            height: 14
                            source: (modifierCard.animData?.enabled ?? true) ? "qrc:/assets/icons/eye.svg" : "qrc:/assets/icons/eye-off.svg"
                            sourceSize: Qt.size(14, 14)
                            opacity: eyeMouse.containsMouse ? 1.0 : 0.6
                            MouseArea {
                                id: eyeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var current = modifierCard.animData?.enabled ?? true;
                                    modifierCard.commit("enabled", !current);
                                }
                            }
                        }

                        Image {
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/x.svg"
                            sourceSize: Qt.size(14, 14)
                            opacity: deleteMouse.containsMouse ? 1.0 : 0.6
                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activeTimelineModel && root.clipId) {
                                        root.activeTimelineModel.removeTextAnimator(root.clipId, modifierCard.animIndex);
                                        root.reloadAnimators();
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: headerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: modifierCard.expanded = !modifierCard.expanded
                    }
                }

                // --- BODY ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 10
                    spacing: 10
                    visible: modifierCard.expanded

                    // 1. PRESETS
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                {
                                    label: "Typewriter",
                                    id: "typewriter"
                                },
                                {
                                    label: "Letter Drop",
                                    id: "drop"
                                },
                                {
                                    label: "Wave",
                                    id: "wave"
                                },
                                {
                                    label: "Pop In",
                                    id: "pop"
                                }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                radius: 3
                                color: pMouse.containsMouse ? "#2c2c34" : "#1f1f24"
                                border.color: "#2a2a30"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: "#dddddd"
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: pMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeTimelineModel && root.clipId) {
                                            root.activeTimelineModel.applyTextAnimatorPreset(root.clipId, modifierCard.animIndex, modelData.id);
                                            root.reloadAnimators();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. FALLOFF & SEGMENTATION SECTION
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "FALLOFF & RANGE"
                            color: "#888888"
                            font.pixelSize: 9
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Based On"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaSelect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                model: ["Characters", "Excl. Spaces", "Words", "Lines", "Chunks", "Separator", "Regex"]
                                currentIndex: modifierCard.animData?.selectors?.[0]?.basedOn ?? 0
                                onActivated: modifierCard.commit("basedOn", currentIndex)
                            }
                        }

                        RowLayout {
                            visible: (modifierCard.animData?.selectors?.[0]?.basedOn ?? 0) === 4
                            Layout.fillWidth: true
                            Text {
                                text: "Chunk Size"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 1
                                maxValue: 50
                                stepSize: 1
                                decimals: 0
                                value: modifierCard.animData?.selectors?.[0]?.chunkSize ?? 2
                                onValueCommitted: newVal => modifierCard.commit("chunkSize", newVal)
                            }
                        }

                        RowLayout {
                            visible: (modifierCard.animData?.selectors?.[0]?.basedOn ?? 0) === 5
                            Layout.fillWidth: true
                            Text {
                                text: "Separator"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            TextField {
                                Layout.fillWidth: true
                                height: 24
                                text: modifierCard.animData?.selectors?.[0]?.customSeparator ?? "|"
                                color: "#ffffff"
                                font.pixelSize: 11
                                padding: 4
                                background: Rectangle {
                                    color: "#101010"
                                    radius: 3
                                    border.color: "#28282e"
                                }
                                onEditingFinished: modifierCard.commit("customSeparator", text)
                            }
                        }

                        RowLayout {
                            visible: (modifierCard.animData?.selectors?.[0]?.basedOn ?? 0) === 6
                            Layout.fillWidth: true
                            Text {
                                text: "Pattern"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            TextField {
                                Layout.fillWidth: true
                                height: 24
                                text: modifierCard.animData?.selectors?.[0]?.regexPattern ?? "\\w+"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.family: "Monospace"
                                padding: 4
                                background: Rectangle {
                                    color: "#101010"
                                    radius: 3
                                    border.color: "#28282e"
                                }
                                onEditingFinished: modifierCard.commit("regexPattern", text)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Shape"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaSelect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                model: ["Square", "Ramp Up", "Ramp Down", "Triangle", "Round", "Smooth", "Gaussian"]
                                currentIndex: modifierCard.animData?.selectors?.[0]?.shape ?? 0
                                onActivated: modifierCard.commit("shape", currentIndex)
                            }
                        }

                        // Start (KEYFRAMEABLE, SAFE UNWRAP)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Start"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 0.0
                                maxValue: 1.0
                                stepSize: 0.01
                                decimals: 2
                                unit: "%"
                                keyframeable: true
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".start", (root.activeTimelineModel.currentFrame !== undefined ? root.activeTimelineModel.currentFrame : 0)) : false
                                value: typeof modifierCard.animData?.selectors?.[0]?.start === "number" ? modifierCard.animData.selectors[0].start : (modifierCard.animData?.selectors?.[0]?.start?.value ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("start", newVal)
                                onKeyframeToggled: modifierCard.toggleKf("start", value)
                            }
                        }

                        // End (KEYFRAMEABLE, SAFE UNWRAP)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "End"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 0.0
                                maxValue: 1.0
                                stepSize: 0.01
                                decimals: 2
                                unit: "%"
                                keyframeable: true
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".end", (root.activeTimelineModel.currentFrame !== undefined ? root.activeTimelineModel.currentFrame : 0)) : false
                                value: typeof modifierCard.animData?.selectors?.[0]?.end === "number" ? modifierCard.animData.selectors[0].end : (modifierCard.animData?.selectors?.[0]?.end?.value ?? 1.0)
                                onValueCommitted: newVal => modifierCard.commit("end", newVal)
                                onKeyframeToggled: modifierCard.toggleKf("end", value)
                            }
                        }

                        // Offset (KEYFRAMEABLE, SAFE UNWRAP)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Offset"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -100.0
                                maxValue: 100.0
                                stepSize: 1.0
                                decimals: 0
                                unit: "%"
                                keyframeable: true
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".offset", (root.activeTimelineModel.currentFrame !== undefined ? root.activeTimelineModel.currentFrame : 0)) : false
                                value: typeof modifierCard.animData?.selectors?.[0]?.offset === "number" ? modifierCard.animData.selectors[0].offset : (modifierCard.animData?.selectors?.[0]?.offset?.value ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("offset", newVal)
                                onKeyframeToggled: modifierCard.toggleKf("offset", value)
                            }
                        }

                        // Randomize
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Randomize"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            CheckBox {
                                checked: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                onToggled: modifierCard.commit("randomize", checked)
                            }
                            Text {
                                visible: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                text: "Seed"
                                color: "#888888"
                                font.pixelSize: 11
                            }
                            XylaFloatInput {
                                visible: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 1
                                maxValue: 99999
                                stepSize: 1
                                decimals: 0
                                value: modifierCard.animData?.selectors?.[0]?.randomSeed ?? 12345
                                onValueCommitted: newVal => modifierCard.commit("randomSeed", newVal)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#28282e"
                    }

                    // 3. ANIMATED DELTAS
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "ANIMATED DELTAS"
                            color: "#888888"
                            font.pixelSize: 9
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Position Y"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -500
                                maxValue: 500
                                stepSize: 1
                                decimals: 0
                                unit: "px"
                                value: Number(modifierCard.animData?.posY ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("posY", newVal)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Scale Y"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -1.0
                                maxValue: 10.0
                                stepSize: 0.1
                                decimals: 1
                                unit: "%"
                                value: Number(modifierCard.animData?.scaleY ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("scaleY", newVal)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Rotation"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -360
                                maxValue: 360
                                stepSize: 1
                                decimals: 0
                                unit: "°"
                                value: Number(modifierCard.animData?.rotation ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("rotation", newVal)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Opacity"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 0.0
                                maxValue: 1.0
                                stepSize: 0.05
                                decimals: 2
                                value: Number(modifierCard.animData?.opacity ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("opacity", newVal)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Tracking"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -50
                                maxValue: 100
                                stepSize: 1
                                decimals: 0
                                unit: "px"
                                value: Number(modifierCard.animData?.tracking ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("tracking", newVal)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Stroke Width"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: -20
                                maxValue: 50
                                stepSize: 1
                                decimals: 0
                                unit: "px"
                                value: Number(modifierCard.animData?.strokeWidth ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("strokeWidth", newVal)
                            }
                        }
                    }
                }
            }
        }
    }
}
