import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Xyla 1.0
import "../components"

Item {
    id: root

    property var activeMixerModel: typeof mixerModel !== "undefined" ? mixerModel : null
    property int minDefaultTracks: 10

    // Model track counting
    readonly property int totalModelCount: {
        if (!activeMixerModel) return 0
        if (typeof activeMixerModel.count !== "undefined") return activeMixerModel.count
        if (typeof activeMixerModel.rowCount === "function") return activeMixerModel.rowCount()
        return 0
    }

    readonly property int activeTrackCount: Math.max(0, totalModelCount - 1)
    readonly property int emptyTrackSlots: Math.max(0, minDefaultTracks - activeTrackCount)

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // --- REUSABLE CHANNEL STRIP COMPONENT ---
    component MixerStrip: Rectangle {
        id: stripRoot

        property bool isMaster: false
        property bool isDummy: false
        property int trackIndex: -1
        property string trackTitle: ""
        property real volumeVal: 1.0
        property real panVal: 0.0
        property real peakL: 0.0
        property real peakR: 0.0
        property bool isMuted: false
        property bool isSolo: false

        // DYNAMICALLY CALCULATED WIDTH — no hardcoded values
        implicitWidth: contentCol.implicitWidth + 12
        width: implicitWidth
        height: parent ? parent.height : 0

        color: isMaster ? "#181818" : (isDummy ? "#111111" : "#151515")
        border.color: isMaster ? "#333333" : "#242424"
        border.width: 1

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6

            // 1. Header (No index numbers)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: stripRoot.isMaster ? "#222222" : "#1e1e1e"
                border.color: "#333333"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: stripRoot.isMaster ? "Master" : stripRoot.trackTitle
                    color: stripRoot.isDummy ? "#555555" : "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // 2. Mute / Solo (Hidden on Master)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                visible: !stripRoot.isMaster

                Button {
                    text: "M"
                    implicitWidth: 26
                    implicitHeight: 20
                    enabled: !stripRoot.isDummy
                    background: Rectangle {
                        color: stripRoot.isMuted ? "#dc2626" : "#222222"
                        radius: 2
                        border.color: "#333333"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: stripRoot.isDummy ? "#444444" : "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 9
                        font.bold: true
                    }
                    onClicked: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setMuted(stripRoot.trackIndex, !stripRoot.isMuted)
                    }
                }

                Button {
                    text: "S"
                    implicitWidth: 26
                    implicitHeight: 20
                    enabled: !stripRoot.isDummy
                    background: Rectangle {
                        color: stripRoot.isSolo ? "#d97706" : "#222222"
                        radius: 2
                        border.color: "#333333"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: stripRoot.isDummy ? "#444444" : "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 9
                        font.bold: true
                    }
                    onClicked: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setSolo(stripRoot.trackIndex, !stripRoot.isSolo)
                    }
                }
            }

            // 3. Peak Meter & Fader
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                spacing: 2

                XylaPeakMeter {
                    Layout.fillHeight: true
                    itemWidth: 10
                    peakLeft: stripRoot.isDummy ? 0.0 : stripRoot.peakL
                    peakRight: stripRoot.isDummy ? 0.0 : stripRoot.peakR
                }

                XylaFader {
                    id: volumeFader
                    Layout.fillHeight: true
                    Layout.preferredWidth: 32
                    value: stripRoot.volumeVal
                    minValue: 0.0
                    maxValue: 2.0
                    enabled: !stripRoot.isDummy
                    onValueChanged: {
                        if (root.activeMixerModel && !stripRoot.isDummy)
                            root.activeMixerModel.setVolume(stripRoot.trackIndex, value)
                    }
                }
            }

            // 4. Pan Knob
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                opacity: stripRoot.isMaster ? 0.3 : 1.0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "PAN"
                        color: "#666666"
                        font.pixelSize: 8
                        font.bold: true
                    }

                    XylaKnob {
                        id: panKnob
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        value: stripRoot.isMaster ? 0.0 : stripRoot.panVal
                        minValue: -1.0
                        maxValue: 1.0
                        enabled: !stripRoot.isMaster && !stripRoot.isDummy
                        onValueChanged: {
                            if (root.activeMixerModel && !stripRoot.isMaster && !stripRoot.isDummy)
                                root.activeMixerModel.setPan(stripRoot.trackIndex, value)
                        }
                    }
                }
            }

            // 5. Float dB Input
            XylaFloatInput {
                id: dbInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 20
                enabled: !stripRoot.isDummy
                value: volumeFader.value <= 0.0001 ? -60.0 : (20.0 * Math.log10(volumeFader.value))
                minValue: -60.0
                maxValue: 6.0
                stepSize: 0.1
                decimals: 1
                onValueCommitted: function(newValue) {
                    if (stripRoot.isDummy) return
                    var linearVal = Math.pow(10.0, newValue / 20.0)
                    if (newValue <= -60.0) linearVal = 0.0
                    if (root.activeMixerModel)
                        root.activeMixerModel.setVolume(stripRoot.trackIndex, linearVal)
                }
            }
        }

        // Overlay for empty/unused default tracks
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            visible: stripRoot.isDummy
            z: 99
        }
    }

    // --- MAIN MIXER VIEWPORT ---
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. PINNED MASTER DOCK (Far Left, self-calculates its own width)
        Row {
            id: masterDock
            Layout.fillHeight: true

            Repeater {
                model: root.activeMixerModel
                delegate: MixerStrip {
                    visible: model.isMaster === true
                    isMaster: true
                    trackIndex: index
                    trackTitle: "Master"
                    volumeVal: model.volume !== undefined ? model.volume : 1.0
                    panVal: 0.0
                    peakL: model.peakL !== undefined ? model.peakL : 0.0
                    peakR: model.peakR !== undefined ? model.peakR : 0.0
                }
            }
        }

        // Divider
        Rectangle {
            Layout.preferredWidth: 2
            Layout.fillHeight: parent.height
            color: "#282828"
        }

        // 2. SCROLLVIEW (Tracks start on the right and move left)
        Flickable {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            contentWidth: Math.max(width, channelRow.width)
            contentHeight: height

            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                height: 6
                anchors.bottom: parent.bottom
            }

            // Viewport container allowing items to dock to the right
            Item {
                width: Math.max(scrollView.width, channelRow.width)
                height: scrollView.height

                Row {
                    id: channelRow
                    height: parent.height
                    spacing: 2

                    // Anchors the row to the right edge of the viewport
                    anchors.right: parent.right

                    // Elements flow right-to-left: Track 1 on far right, next to it Track 2...
                    layoutDirection: Qt.RightToLeft

                    // A. Active Tracks (Master ignored in this row)
                    Repeater {
                        model: root.activeMixerModel
                        delegate: MixerStrip {
                            visible: model.isMaster !== true
                            isMaster: false
                            isDummy: false
                            trackIndex: index
                            trackTitle: model.trackName ?? ""
                            volumeVal: model.volume ?? 1.0
                            panVal: model.pan ?? 0.0
                            peakL: model.peakL ?? 0.0
                            peakR: model.peakR ?? 0.0
                            isMuted: model.muted ?? false
                            isSolo: model.solo ?? false
                        }
                    }

                    // B. Default Empty Grayed-Out Tracks
                    Repeater {
                        model: root.emptyTrackSlots
                        delegate: MixerStrip {
                            isMaster: false
                            isDummy: true
                            trackIndex: -1
                            trackTitle: "Track " + (root.activeTrackCount + index + 1)
                            volumeVal: 0.0
                        }
                    }
                }
            }
        }
    }
}
