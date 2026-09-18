import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property var availableProperties: []

    // Fallback descriptors for all supported animatable properties
    readonly property var fallbackDescriptors: ({
            "position.y": {
                displayName: "Position Y",
                unit: "px",
                min: -2000,
                max: 2000,
                step: 1.0,
                dec: 0,
                def: 50.0
            },
            "position.x": {
                displayName: "Position X",
                unit: "px",
                min: -2000,
                max: 2000,
                step: 1.0,
                dec: 0,
                def: 0.0
            },
            "opacity": {
                displayName: "Opacity",
                unit: "%",
                min: -1.0,
                max: 1.0,
                step: 0.05,
                dec: 2,
                def: -1.0
            },
            "scale": {
                displayName: "Scale",
                unit: "%",
                min: -1.0,
                max: 10.0,
                step: 0.05,
                dec: 2,
                def: -1.0
            },
            "scale.y": {
                displayName: "Scale Y",
                unit: "%",
                min: -1.0,
                max: 10.0,
                step: 0.05,
                dec: 2,
                def: -1.0
            },
            "scale.x": {
                displayName: "Scale X",
                unit: "%",
                min: -1.0,
                max: 10.0,
                step: 0.05,
                dec: 2,
                def: -1.0
            },
            "rotation": {
                displayName: "Rotation",
                unit: "°",
                min: -360,
                max: 360,
                step: 1.0,
                dec: 0,
                def: 0.0
            },
            "tracking": {
                displayName: "Tracking",
                unit: "px",
                min: -100,
                max: 200,
                step: 1.0,
                dec: 0,
                def: 0.0
            },
            "strokeWidth": {
                displayName: "Stroke W.",
                unit: "px",
                min: -50,
                max: 100,
                step: 1.0,
                dec: 1,
                def: 0.0
            },
            "blur": {
                displayName: "Blur",
                unit: "px",
                min: 0,
                max: 100,
                step: 1.0,
                dec: 0,
                def: 10.0
            }
        })

    function getDescriptor(propId) {
        if (root.availableProperties && root.availableProperties.length > 0) {
            for (var i = 0; i < root.availableProperties.length; ++i) {
                if (root.availableProperties[i].propertyId === propId)
                    return root.availableProperties[i];
            }
        }
        if (root.fallbackDescriptors[propId]) {
            var fb = root.fallbackDescriptors[propId];
            return {
                propertyId: propId,
                displayName: fb.displayName,
                unit: fb.unit,
                minValue: fb.min,
                maxValue: fb.max,
                stepSize: fb.step,
                decimals: fb.dec,
                defaultValue: fb.def
            };
        }
        return {
            propertyId: propId,
            displayName: propId,
            unit: "",
            minValue: -2000,
            maxValue: 2000,
            stepSize: 1.0,
            decimals: 1,
            defaultValue: 0.0
        };
    }

    function reloadAnimators() {
        if (root.activeTimelineModel && root.clipId && root.activeTimelineModel.getTextAnimators) {
            cachedAnimators = root.activeTimelineModel.getTextAnimators(root.clipId);
        } else {
            cachedAnimators = clipData?.textAnimators ?? [];
        }

        if (root.activeTimelineModel?.getAvailableAnimatorProperties) {
            availableProperties = root.activeTimelineModel.getAvailableAnimatorProperties();
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
            Layout.preferredWidth: 116
            radius: 4
            color: addMouse.containsMouse ? "#242424" : "#1a1a1a"
            border.color: "#2e2e2e"
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
    // MODIFIER STACK
    // =========================================================================
    Repeater {
        model: root.cachedAnimators

        Rectangle {
            id: modifierCard
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight
            radius: 8
            clip: true
            color: "#141414"
            border.color: "#242424"
            border.width: 1

            property int animIndex: index
            property var animData: modelData
            property bool expanded: true

            function commit(prop, val) {
                if (root.activeTimelineModel && root.clipId) {
                    var data = JSON.parse(JSON.stringify(modifierCard.animData || {}));
                    var selectorProps = ["start", "end", "offset", "shape", "basedOn", "chunkSize", "customSeparator", "regexPattern", "randomize", "randomSeed"];

                    if (selectorProps.indexOf(prop) !== -1) {
                        if (!data.selectors || !Array.isArray(data.selectors) || data.selectors.length === 0) {
                            data.selectors = [
                                {}
                            ];
                        }
                        data.selectors[0][prop] = val;
                    } else {
                        data[prop] = val;
                    }

                    modifierCard.animData = data;
                    if (root.cachedAnimators && root.cachedAnimators[animIndex] !== undefined) {
                        root.cachedAnimators[animIndex] = data;
                    }

                    root.activeTimelineModel.updateClipProperty(root.clipId, "text.animator." + animIndex + "." + prop, val);
                }
            }

            function commitDelta(propId, val) {
                if (root.activeTimelineModel && root.clipId) {
                    var data = JSON.parse(JSON.stringify(modifierCard.animData || {}));
                    if (!data.deltas || !Array.isArray(data.deltas)) {
                        data.deltas = [];
                    }

                    var found = false;
                    for (var i = 0; i < data.deltas.length; ++i) {
                        if (data.deltas[i].propertyId === propId) {
                            data.deltas[i].value = val;
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        data.deltas.push({
                            propertyId: propId,
                            value: val
                        });
                    }

                    modifierCard.animData = data;
                    if (root.cachedAnimators && root.cachedAnimators[animIndex] !== undefined) {
                        root.cachedAnimators[animIndex] = data;
                    }

                    root.activeTimelineModel.updateClipProperty(root.clipId, "text.animator." + animIndex + ".delta." + propId, val);
                }
            }

            function addDelta(propId, initialVal) {
                if (root.activeTimelineModel && root.clipId) {
                    root.activeTimelineModel.addTextAnimatorDelta(root.clipId, modifierCard.animIndex, propId, initialVal);
                    root.reloadAnimators();
                }
            }

            function removeDelta(propId) {
                if (root.activeTimelineModel && root.clipId) {
                    root.activeTimelineModel.removeTextAnimatorDelta(root.clipId, modifierCard.animIndex, propId);
                    root.reloadAnimators();
                }
            }

            function toggleKf(prop, val) {
                if (root.activeTimelineModel && root.clipId) {
                    var curFrame = (typeof playbackManager !== "undefined" && playbackManager?.currentFrame !== undefined) ? playbackManager.currentFrame : (root.activeTimelineModel.currentFrame !== undefined ? root.activeTimelineModel.currentFrame : 0);
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
                    Layout.preferredHeight: 30
                    color: headerArea.containsMouse ? "#202020" : "#181818"
                    border.color: "#242424"
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

                        // Presets Dropdown beside enable/disable
                        XylaSelect {
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: 22
                            model: ["Presets...", "Typewriter", "Letter Drop", "Wave", "Pop In"]
                            currentIndex: 0
                            onActivated: index => {
                                var presetIds = ["", "typewriter", "drop", "wave", "pop"];
                                if (index > 0 && presetIds[index]) {
                                    if (root.activeTimelineModel && root.clipId) {
                                        root.activeTimelineModel.applyTextAnimatorPreset(root.clipId, modifierCard.animIndex, presetIds[index]);
                                        root.reloadAnimators();
                                    }
                                    currentIndex = 0;
                                }
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

                    // 1. FALLOFF & RANGE SECTION
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
                                Layout.preferredWidth: 80
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
                                Layout.preferredWidth: 80
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
                                Layout.preferredWidth: 80
                            }
                            TextField {
                                Layout.fillWidth: true
                                height: 24
                                text: modifierCard.animData?.selectors?.[0]?.customSeparator ?? "|"
                                color: "#ffffff"
                                font.pixelSize: 11
                                padding: 4
                                background: Rectangle {
                                    color: "#121212"
                                    radius: 3
                                    border.color: "#262626"
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
                                Layout.preferredWidth: 80
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
                                    color: "#121212"
                                    radius: 3
                                    border.color: "#262626"
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
                                Layout.preferredWidth: 80
                            }
                            XylaSelect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                model: ["Square", "Ramp Up", "Ramp Down", "Triangle", "Round", "Smooth", "Gaussian"]
                                currentIndex: modifierCard.animData?.selectors?.[0]?.shape ?? 0
                                onActivated: modifierCard.commit("shape", currentIndex)
                            }
                        }

                        // Start (0% -> 100%)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Start"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 80
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 0.0
                                maxValue: 100.0
                                stepSize: 1.0
                                decimals: 0
                                unit: "%"
                                keyframeable: true
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".start", (typeof playbackManager !== "undefined" ? playbackManager.currentFrame : 0)) : false
                                value: {
                                    var raw = typeof modifierCard.animData?.selectors?.[0]?.start === "number" ? modifierCard.animData.selectors[0].start : (modifierCard.animData?.selectors?.[0]?.start?.value ?? 0.0);
                                    return Math.round(raw * 100.0);
                                }
                                onValueCommitted: newVal => modifierCard.commit("start", newVal * 0.01)
                                onKeyframeToggled: modifierCard.toggleKf("start", value * 0.01)
                            }
                        }

                        // End (0% -> 100%)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "End"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 80
                            }
                            XylaFloatInput {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                minValue: 0.0
                                maxValue: 100.0
                                stepSize: 1.0
                                decimals: 0
                                unit: "%"
                                keyframeable: true
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".end", (typeof playbackManager !== "undefined" ? playbackManager.currentFrame : 0)) : false
                                value: {
                                    var raw = typeof modifierCard.animData?.selectors?.[0]?.end === "number" ? modifierCard.animData.selectors[0].end : (modifierCard.animData?.selectors?.[0]?.end?.value ?? 1.0);
                                    return Math.round(raw * 100.0);
                                }
                                onValueCommitted: newVal => modifierCard.commit("end", newVal * 0.01)
                                onKeyframeToggled: modifierCard.toggleKf("end", value * 0.01)
                            }
                        }

                        // Offset (-100% -> 100%)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Offset"
                                color: "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 80
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
                                hasKeyframe: root.activeTimelineModel ? root.activeTimelineModel.hasKeyframe(root.clipId, "text.animator." + modifierCard.animIndex + ".offset", (typeof playbackManager !== "undefined" ? playbackManager.currentFrame : 0)) : false
                                value: typeof modifierCard.animData?.selectors?.[0]?.offset === "number" ? modifierCard.animData.selectors[0].offset : (modifierCard.animData?.selectors?.[0]?.offset?.value ?? 0.0)
                                onValueCommitted: newVal => modifierCard.commit("offset", newVal)
                                onKeyframeToggled: modifierCard.toggleKf("offset", value)
                            }
                        }

                        // Randomize
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            XylaCheckBox {
                                text: "Randomize"
                                checked: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                onToggled: isChecked => modifierCard.commit("randomize", isChecked)
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                text: "Seed"
                                color: "#888888"
                                font.pixelSize: 11
                            }
                            XylaFloatInput {
                                visible: modifierCard.animData?.selectors?.[0]?.randomize ?? false
                                Layout.preferredWidth: 90
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
                        color: "#222222"
                    }

                    // 2. DYNAMIC ANIMATED DELTAS SECTION
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "ANIMATED DELTAS"
                                color: "#888888"
                                font.pixelSize: 9
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            // "+ Add Property" button
                            Rectangle {
                                id: addPropBtn
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 96
                                radius: 3
                                color: addPropMouse.containsMouse ? "#242424" : "#1a1a1a"
                                border.color: "#282828"
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Image {
                                        width: 10
                                        height: 10
                                        source: "qrc:/assets/icons/plus.svg"
                                        sourceSize: Qt.size(10, 10)
                                    }

                                    Text {
                                        text: "Add Property"
                                        color: "#cccccc"
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    id: addPropMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: propPopup.open()
                                }

                                // Property Search & Selection Popup
                                Popup {
                                    id: propPopup
                                    property string filterText: ""

                                    y: addPropBtn.height + 4
                                    x: -width + addPropBtn.width
                                    width: 180
                                    height: Math.min(220, popupCol.implicitHeight + 16)
                                    padding: 6
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                    onClosed: {
                                        filterText = "";
                                        searchPropInput.text = "";
                                    }

                                    background: Rectangle {
                                        color: "#191919"
                                        radius: 4
                                        border.color: "#282828"
                                        border.width: 1
                                    }

                                    ColumnLayout {
                                        id: popupCol
                                        width: parent.width
                                        spacing: 4

                                        TextField {
                                            id: searchPropInput
                                            Layout.fillWidth: true
                                            height: 24
                                            placeholderText: "Search..."
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            padding: 4
                                            background: Rectangle {
                                                color: "#121212"
                                                radius: 3
                                                border.color: "#262626"
                                            }
                                            onTextChanged: propPopup.filterText = text.toLowerCase().trim()
                                        }

                                        ListView {
                                            id: propList
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.min(180, count * 24)
                                            clip: true
                                            model: {
                                                var all = (root.availableProperties && root.availableProperties.length > 0) ? root.availableProperties : Object.keys(root.fallbackDescriptors).map(k => root.getDescriptor(k));

                                                var q = propPopup.filterText;
                                                if (!q)
                                                    return all;
                                                return all.filter(p => p.displayName.toLowerCase().indexOf(q) !== -1 || p.propertyId.toLowerCase().indexOf(q) !== -1);
                                            }

                                            delegate: Rectangle {
                                                width: propList.width
                                                height: 24
                                                radius: 2
                                                color: pItemMouse.containsMouse ? "#262626" : "transparent"

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 6

                                                    Text {
                                                        text: modelData.displayName
                                                        color: "#ffffff"
                                                        font.pixelSize: 10
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        text: modelData.unit ? ("[" + modelData.unit + "]") : ""
                                                        color: "#666666"
                                                        font.pixelSize: 9
                                                    }
                                                }

                                                MouseArea {
                                                    id: pItemMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        modifierCard.addDelta(modelData.propertyId, modelData.defaultValue);
                                                        propPopup.close();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Placeholder when no deltas are present
                        Item {
                            visible: (!modifierCard.animData?.deltas || modifierCard.animData.deltas.length === 0)
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Text {
                                anchors.centerIn: parent
                                text: "No properties added. Click '+ Add Property'"
                                color: "#555555"
                                font.pixelSize: 10
                            }
                        }

                        // Active Dynamic Delta Rows
                        Repeater {
                            model: modifierCard.animData?.deltas ?? []

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                property var desc: root.getDescriptor(modelData.propertyId)

                                Text {
                                    text: desc.displayName
                                    color: "#888888"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 80
                                    elide: Text.ElideRight
                                }

                                XylaFloatInput {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 26
                                    minValue: desc.minValue
                                    maxValue: desc.maxValue
                                    stepSize: desc.stepSize
                                    decimals: desc.decimals
                                    unit: desc.unit
                                    value: Number(modelData.value ?? 0.0)
                                    onValueCommitted: newVal => modifierCard.commitDelta(modelData.propertyId, newVal)
                                }

                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 3
                                    color: rmMouse.containsMouse ? "#242424" : "transparent"

                                    Image {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        source: "qrc:/assets/icons/x.svg"
                                        sourceSize: Qt.size(10, 10)
                                        opacity: rmMouse.containsMouse ? 1.0 : 0.5
                                    }

                                    MouseArea {
                                        id: rmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modifierCard.removeDelta(modelData.propertyId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
