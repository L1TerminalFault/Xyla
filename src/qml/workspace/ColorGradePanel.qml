import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: panelRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property string activeClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var activeClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null
    property var clipColorData: (activeClipData && activeClipData.color) ? activeClipData.color : null

    property bool hasClip: activeClipId !== "" && activeClipData !== null
    property int currentTab: 0

    property real temperature: 0.0
    property real tint: 0.0
    property real contrast: 1.000
    property real pivot: 0.435
    property real midDetail: 0.00

    property real colorBoost: 0.00
    property real shadows: 0.00
    property real highlights: 0.00
    property real saturation: 50.00
    property real hue: 50.00
    property real lumMix: 100.00

    onClipColorDataChanged: {
        if (!clipColorData) {
            resetLocalUi();
            return;
        }

        temperature = clipColorData.temperature ?? 0.0;
        tint = clipColorData.tint ?? 0.0;
        contrast = clipColorData.contrast ?? 1.0;
        pivot = clipColorData.pivot ?? 0.435;
        midDetail = clipColorData.midDetail ?? 0.0;

        colorBoost = clipColorData.colorBoost ?? 0.0;
        shadows = clipColorData.shadows ?? 0.0;
        highlights = clipColorData.highlights ?? 0.0;
        saturation = clipColorData.saturation ?? 50.0;
        hue = clipColorData.hue ?? 50.0;
        lumMix = clipColorData.lumMix ?? 100.0;

        if (clipColorData.lift && clipColorData.lift.length >= 4) {
            liftWheel.setColor(clipColorData.lift[0], clipColorData.lift[1], clipColorData.lift[2], clipColorData.lift[3]);
        }
        if (clipColorData.gamma && clipColorData.gamma.length >= 4) {
            gammaWheel.setColor(clipColorData.gamma[0], clipColorData.gamma[1], clipColorData.gamma[2], clipColorData.gamma[3]);
        }
        if (clipColorData.gain && clipColorData.gain.length >= 4) {
            gainWheel.setColor(clipColorData.gain[0], clipColorData.gain[1], clipColorData.gain[2], clipColorData.gain[3]);
        }
        if (clipColorData.offset && clipColorData.offset.length >= 4) {
            offsetWheel.setColor(clipColorData.offset[0], clipColorData.offset[1], clipColorData.offset[2], clipColorData.offset[3]);
        }
    }

    function resetLocalUi() {
        temperature = 0.0;
        tint = 0.0;
        contrast = 1.0;
        pivot = 0.435;
        midDetail = 0.0;
        colorBoost = 0.0;
        shadows = 0.0;
        highlights = 0.0;
        saturation = 50.0;
        hue = 50.0;
        lumMix = 100.0;
        liftWheel.resetAll();
        gammaWheel.resetAll();
        gainWheel.resetAll();
        offsetWheel.resetAll();
    }

    function commitProperty(key, val) {
        if (activeTimelineModel && hasClip) {
            activeTimelineModel.updateClipColorProperty(activeClipId, key, val);
        }
    }

    function applyPreset(index) {
        if (!hasClip)
            return;
        switch (index) {
        case 0:
            resetLocalUi();
            commitProperty("temperature", 0.0);
            commitProperty("tint", 0.0);
            commitProperty("contrast", 1.0);
            commitProperty("pivot", 0.435);
            commitProperty("midDetail", 0.0);
            commitProperty("colorBoost", 0.0);
            commitProperty("shadows", 0.0);
            commitProperty("highlights", 0.0);
            commitProperty("saturation", 50.0);
            commitProperty("hue", 50.0);
            commitProperty("lumMix", 100.0);
            commitProperty("lift", [0.0, 0.0, 0.0, 0.0]);
            commitProperty("gamma", [1.0, 1.0, 1.0, 0.0]);
            commitProperty("gain", [1.0, 1.0, 1.0, 0.0]);
            commitProperty("offset", [0.0, 0.0, 0.0, 0.0]);
            break;
        case 1:
            contrast = 1.15;
            commitProperty("contrast", 1.15);
            saturation = 58.0;
            commitProperty("saturation", 58.0);
            temperature = 0.15;
            commitProperty("temperature", 0.15);
            liftWheel.updateFromHandle(-0.25, -0.3);
            gainWheel.updateFromHandle(0.28, 0.22);
            break;
        case 2:
            temperature = 0.35;
            commitProperty("temperature", 0.35);
            tint = -0.05;
            commitProperty("tint", -0.05);
            contrast = 1.10;
            commitProperty("contrast", 1.10);
            saturation = 52.0;
            commitProperty("saturation", 52.0);
            gainWheel.updateFromHandle(0.18, 0.12);
            break;
        case 3:
            temperature = -0.35;
            commitProperty("temperature", -0.35);
            contrast = 1.18;
            commitProperty("contrast", 1.18);
            saturation = 44.0;
            commitProperty("saturation", 44.0);
            liftWheel.updateFromHandle(-0.15, -0.2);
            break;
        case 4:
            contrast = 1.45;
            commitProperty("contrast", 1.45);
            saturation = 24.0;
            commitProperty("saturation", 24.0);
            colorBoost = -12.0;
            commitProperty("colorBoost", -12.0);
            break;
        case 5:
            saturation = 0.0;
            commitProperty("saturation", 0.0);
            contrast = 1.40;
            commitProperty("contrast", 1.40);
            pivot = 0.45;
            commitProperty("pivot", 0.45);
            break;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#161616"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        opacity: panelRoot.hasClip ? 1.0 : 0.18
        enabled: panelRoot.hasClip

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // =========================================================
        // 1. TOP TOOLBAR & TABS
        // =========================================================
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: "#181818"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#282828"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                Row {
                    spacing: 2
                    Repeater {
                        model: ["Primaries", "Curves", "Management"]
                        delegate: Rectangle {
                            width: tabText.implicitWidth + 16
                            height: 24
                            radius: 4
                            color: panelRoot.currentTab === index ? "#262626" : (tabMouse.containsMouse ? "#1e1e1e" : "transparent")

                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData
                                color: panelRoot.currentTab === index ? "#ffffff" : "#888888"
                                font.pixelSize: 11
                                font.bold: panelRoot.currentTab === index
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panelRoot.currentTab = index
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                XylaSelect {
                    id: presetSelect
                    implicitWidth: 120
                    implicitHeight: 22
                    model: ["Default", "Teal & Orange", "Warm Film", "Cool Cinematic", "Bleach Bypass", "B&W Contrast"]
                    onActivated: index => panelRoot.applyPreset(index)
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/rotate.svg"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    onClicked: {
                        panelRoot.applyPreset(0);
                        presetSelect.currentIndex = 0;
                    }
                }
            }
        }

        // =========================================================
        // 2. STACKED TAB CONTENT
        // =========================================================
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: panelRoot.currentTab

            // TAB 0: Primaries
            ColumnLayout {
                spacing: 0

                // Single Row Header Strip
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    color: "#181818"
                    clip: true

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#282828"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "Temp"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 50
                                value: panelRoot.temperature
                                accentColor: "#F97316"
                                stepSize: 0.1
                                onValueCommitted: val => {
                                    panelRoot.temperature = val;
                                    panelRoot.commitProperty("temperature", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "Tint"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 50
                                value: panelRoot.tint
                                accentColor: "#EC4899"
                                stepSize: 0.1
                                onValueCommitted: val => {
                                    panelRoot.tint = val;
                                    panelRoot.commitProperty("tint", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "Contrast"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 50
                                value: panelRoot.contrast
                                accentColor: "#ffffff"
                                stepSize: 0.05
                                onValueCommitted: val => {
                                    panelRoot.contrast = val;
                                    panelRoot.commitProperty("contrast", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "Pivot"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 50
                                value: panelRoot.pivot
                                accentColor: "#777788"
                                stepSize: 0.01
                                onValueCommitted: val => {
                                    panelRoot.pivot = val;
                                    panelRoot.commitProperty("pivot", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "Mid/Detail"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 50
                                value: panelRoot.midDetail
                                accentColor: "#777788"
                                stepSize: 0.1
                                onValueCommitted: val => {
                                    panelRoot.midDetail = val;
                                    panelRoot.commitProperty("midDetail", val);
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                // 4 Color Wheels Area
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        XylaColorWheel {
                            id: liftWheel
                            title: "Lift"
                            defaultBase: 0.0
                            onColorChanged: (r, g, b, master) => panelRoot.commitProperty("lift", [r, g, b, master])
                        }

                        XylaColorWheel {
                            id: gammaWheel
                            title: "Gamma"
                            defaultBase: 1.0
                            onColorChanged: (r, g, b, master) => panelRoot.commitProperty("gamma", [r, g, b, master])
                        }

                        XylaColorWheel {
                            id: gainWheel
                            title: "Gain"
                            defaultBase: 1.0
                            onColorChanged: (r, g, b, master) => panelRoot.commitProperty("gain", [r, g, b, master])
                        }

                        XylaColorWheel {
                            id: offsetWheel
                            title: "Offset"
                            defaultBase: 0.0
                            onColorChanged: (r, g, b, master) => panelRoot.commitProperty("offset", [r, g, b, master])
                        }
                    }
                }

                // Footer Controls
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    color: "#181818"
                    clip: true

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#282828"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Boost"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.colorBoost
                                stepSize: 0.5
                                onValueCommitted: val => {
                                    panelRoot.colorBoost = val;
                                    panelRoot.commitProperty("colorBoost", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Shadows"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.shadows
                                stepSize: 0.5
                                onValueCommitted: val => {
                                    panelRoot.shadows = val;
                                    panelRoot.commitProperty("shadows", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Highlights"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.highlights
                                stepSize: 0.5
                                onValueCommitted: val => {
                                    panelRoot.highlights = val;
                                    panelRoot.commitProperty("highlights", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Sat"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.saturation
                                stepSize: 0.5
                                onValueCommitted: val => {
                                    panelRoot.saturation = val;
                                    panelRoot.commitProperty("saturation", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Hue"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.hue
                                stepSize: 0.5
                                onValueCommitted: val => {
                                    panelRoot.hue = val;
                                    panelRoot.commitProperty("hue", val);
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "Lum Mix"
                                color: "#888888"
                                font.pixelSize: 10
                            }
                            XylaFloatInput {
                                width: 44
                                value: panelRoot.lumMix
                                stepSize: 1.0
                                onValueCommitted: val => {
                                    panelRoot.lumMix = val;
                                    panelRoot.commitProperty("lumMix", val);
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // TAB 1: Curves
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: "qrc:/assets/icons/chart-line.svg"
                        sourceSize.width: 28
                        sourceSize.height: 28
                        opacity: 0.25
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Custom RGB Curves"
                        color: "#666666"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // TAB 2: LUTs / Management
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: "qrc:/assets/icons/settings.svg"
                        sourceSize.width: 28
                        sourceSize.height: 28
                        opacity: 0.25
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Color Space & LUT Management"
                        color: "#666666"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
