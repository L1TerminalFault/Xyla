import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: ceRoot

    property string nodeId: ""
    property string clipId: ""
    property var activeTimelineModel: null

    // --- Top Bar Parameters ---
    property real temperature: 0.0
    property real tint: 0.0
    property real contrast: 1.000
    property real pivot: 0.435
    property real midDetail: 0.00

    // --- Bottom Footer Parameters ---
    property real colorBoost: 0.00
    property real shadows: 0.00
    property real highlights: 0.00
    property real saturation: 50.00
    property real hue: 50.00
    property real lumMix: 100.00

    function commitSocket(socketId, val) {
        if (activeTimelineModel && clipId !== "" && nodeId !== "") {
            activeTimelineModel.updateSocketValue(clipId, nodeId, socketId, val);
        }
    }

    function resetAllParameters() {
        temperature = 0.0;
        tint = 0.0;
        contrast = 1.000;
        pivot = 0.435;
        midDetail = 0.00;

        colorBoost = 0.00;
        shadows = 0.00;
        highlights = 0.00;
        saturation = 50.00;
        hue = 50.00;
        lumMix = 100.00;

        liftWheel.resetAll();
        gammaWheel.resetAll();
        gainWheel.resetAll();
        offsetWheel.resetAll();

        commitSocket("temperature", 0.0);
        commitSocket("tint", 0.0);
        commitSocket("contrast", 1.000);
        commitSocket("pivot", 0.435);
        commitSocket("midDetail", 0.00);

        commitSocket("colorBoost", 0.00);
        commitSocket("shadows", 0.00);
        commitSocket("highlights", 0.00);
        commitSocket("saturation", 50.00);
        commitSocket("hue", 50.00);
        commitSocket("lumMix", 100.00);
    }

    function applyPreset(index) {
        resetAllParameters();
        switch (index) {
        case 0:
            break;
        case 1: // Teal & Orange
            contrast = 1.15;
            commitSocket("contrast", 1.15);
            saturation = 58.0;
            commitSocket("saturation", 58.0);
            temperature = 0.15;
            commitSocket("temperature", 0.15);
            liftWheel.updateFromHandle(-0.25, -0.3);
            gainWheel.updateFromHandle(0.28, 0.22);
            break;
        case 2: // Warm Film
            temperature = 0.35;
            commitSocket("temperature", 0.35);
            tint = -0.05;
            commitSocket("tint", -0.05);
            contrast = 1.10;
            commitSocket("contrast", 1.10);
            saturation = 52.0;
            commitSocket("saturation", 52.0);
            gainWheel.updateFromHandle(0.18, 0.12);
            break;
        case 3: // Cool Cinematic
            temperature = -0.35;
            commitSocket("temperature", -0.35);
            contrast = 1.18;
            commitSocket("contrast", 1.18);
            saturation = 44.0;
            commitSocket("saturation", 44.0);
            liftWheel.updateFromHandle(-0.15, -0.2);
            break;
        case 4: // Bleach Bypass
            contrast = 1.45;
            commitSocket("contrast", 1.45);
            saturation = 24.0;
            commitSocket("saturation", 24.0);
            colorBoost = -12.0;
            commitSocket("colorBoost", -12.0);
            break;
        case 5: // High Contrast B&W
            saturation = 0.0;
            commitSocket("saturation", 0.0);
            contrast = 1.40;
            commitSocket("contrast", 1.40);
            pivot = 0.45;
            commitSocket("pivot", 0.45);
            break;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =========================================================
        // 1. TOP HEADER (Clipped, Integrated Accent Colors)
        // =========================================================
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#181818"
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#2d2d2d"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                // Temp
                RowLayout {
                    spacing: 4
                    Text {
                        text: "Temp"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    XylaFloatInput {
                        width: 56
                        value: ceRoot.temperature
                        accentColor: "#F97316"
                        stepSize: 0.1
                        onValueCommitted: function (val) {
                            ceRoot.temperature = val;
                            ceRoot.commitSocket("temperature", val);
                        }
                    }
                }

                // Tint
                RowLayout {
                    spacing: 4
                    Text {
                        text: "Tint"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    XylaFloatInput {
                        width: 56
                        value: ceRoot.tint
                        accentColor: "#EC4899"
                        stepSize: 0.1
                        onValueCommitted: function (val) {
                            ceRoot.tint = val;
                            ceRoot.commitSocket("tint", val);
                        }
                    }
                }

                // Contrast
                RowLayout {
                    spacing: 4
                    Text {
                        text: "Contrast"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    XylaFloatInput {
                        width: 56
                        value: ceRoot.contrast
                        accentColor: "#ffffff"
                        stepSize: 0.05
                        onValueCommitted: function (val) {
                            ceRoot.contrast = val;
                            ceRoot.commitSocket("contrast", val);
                        }
                    }
                }

                // Pivot
                RowLayout {
                    spacing: 4
                    Text {
                        text: "Pivot"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    XylaFloatInput {
                        width: 56
                        value: ceRoot.pivot
                        accentColor: "#777788"
                        stepSize: 0.01
                        onValueCommitted: function (val) {
                            ceRoot.pivot = val;
                            ceRoot.commitSocket("pivot", val);
                        }
                    }
                }

                // Mid/Detail
                RowLayout {
                    spacing: 4
                    Text {
                        text: "Mid/Detail"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    XylaFloatInput {
                        width: 56
                        value: ceRoot.midDetail
                        accentColor: "#777788"
                        stepSize: 0.1
                        onValueCommitted: function (val) {
                            ceRoot.midDetail = val;
                            ceRoot.commitSocket("midDetail", val);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                XylaSelect {
                    id: presetSelect
                    implicitWidth: 125
                    implicitHeight: 22
                    model: ["Default", "Teal & Orange", "Warm Film", "Cool Cinematic", "Bleach Bypass", "B&W Contrast"]
                    onActivated: function (index) {
                        ceRoot.applyPreset(index);
                    }
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/rotate.svg"
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    onClicked: {
                        ceRoot.resetAllParameters();
                        presetSelect.currentIndex = 0;
                    }
                }
            }
        }

        // =========================================================
        // 2. CENTER: 4 EXPANDING COLOR WHEELS (Lift, Gamma, Gain, Offset)
        // =========================================================
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
                    onColorChanged: function (r, g, b, master) {
                        ceRoot.commitSocket("lift", [r, g, b, master]);
                    }
                }

                XylaColorWheel {
                    id: gammaWheel
                    title: "Gamma"
                    defaultBase: 1.0
                    onColorChanged: function (r, g, b, master) {
                        ceRoot.commitSocket("gamma", [r, g, b, master]);
                    }
                }

                XylaColorWheel {
                    id: gainWheel
                    title: "Gain"
                    defaultBase: 1.0
                    onColorChanged: function (r, g, b, master) {
                        ceRoot.commitSocket("gain", [r, g, b, master]);
                    }
                }

                XylaColorWheel {
                    id: offsetWheel
                    title: "Offset"
                    defaultBase: 0.0
                    onColorChanged: function (r, g, b, master) {
                        ceRoot.commitSocket("offset", [r, g, b, master]);
                    }
                }
            }
        }

        // =========================================================
        // 3. FULL-WIDTH DOCKED FOOTER STRIP (Clipped)
        // =========================================================
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#1a1a1a"
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#2d2d2d"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Color Boost"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.colorBoost
                        stepSize: 0.5
                        onValueCommitted: function (val) {
                            ceRoot.colorBoost = val;
                            ceRoot.commitSocket("colorBoost", val);
                        }
                    }
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Shadows"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.shadows
                        stepSize: 0.5
                        onValueCommitted: function (val) {
                            ceRoot.shadows = val;
                            ceRoot.commitSocket("shadows", val);
                        }
                    }
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Highlights"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.highlights
                        stepSize: 0.5
                        onValueCommitted: function (val) {
                            ceRoot.highlights = val;
                            ceRoot.commitSocket("highlights", val);
                        }
                    }
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Saturation"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.saturation
                        stepSize: 0.5
                        onValueCommitted: function (val) {
                            ceRoot.saturation = val;
                            ceRoot.commitSocket("saturation", val);
                        }
                    }
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Hue"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.hue
                        stepSize: 0.5
                        onValueCommitted: function (val) {
                            ceRoot.hue = val;
                            ceRoot.commitSocket("hue", val);
                        }
                    }
                }

                RowLayout {
                    spacing: 4
                    Text {
                        text: "Lum Mix"
                        color: "#888888"
                        font.pixelSize: 10
                    }
                    XylaFloatInput {
                        width: 44
                        value: ceRoot.lumMix
                        stepSize: 1.0
                        onValueCommitted: function (val) {
                            ceRoot.lumMix = val;
                            ceRoot.commitSocket("lumMix", val);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
