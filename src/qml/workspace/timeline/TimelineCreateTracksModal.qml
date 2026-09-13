import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: createTracksModal
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 320
    padding: 16
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    signal confirmed(int videoCount, int audioCount)

    background: Rectangle {
        color: "#181818"
        border.color: "#303030"
        border.width: 1
        radius: 12

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.75
            shadowVerticalOffset: 8
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
    }

    contentItem: ColumnLayout {
        spacing: 16

        ColumnLayout {
            spacing: 4
            Text {
                text: "Create Timeline Tracks"
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: "Select initial number of video and audio tracks"
                color: "#888888"
                font.pixelSize: 11
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#282828"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Video Tracks"
                    color: "#cccccc"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                XylaFloatInput {
                    id: videoTrackInput
                    value: 2
                    minValue: 0
                    maxValue: 32
                    stepSize: 1.0
                    decimals: 0
                    Layout.preferredWidth: 80
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Audio Tracks"
                    color: "#cccccc"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                XylaFloatInput {
                    id: audioTrackInput
                    value: 2
                    minValue: 0
                    maxValue: 32
                    stepSize: 1.0
                    decimals: 0
                    Layout.preferredWidth: 80
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#282828"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            layoutDirection: Qt.RightToLeft

            XylaTextButton {
                text: "Create"
                primary: true
                onClicked: {
                    var vCount = Math.max(0, Math.round(videoTrackInput.value));
                    var aCount = Math.max(0, Math.round(audioTrackInput.value));
                    createTracksModal.confirmed(vCount, aCount);
                    createTracksModal.close();
                }
            }

            XylaTextButton {
                text: "Cancel"
                outline: true
                onClicked: createTracksModal.close()
            }
        }
    }
}
