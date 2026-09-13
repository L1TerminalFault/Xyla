import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Popup {
    id: addTrackModal
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 320
    padding: 16
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    property int pendingKind: 0
    signal confirmed(int kind)

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

    contentItem: ColumnLayout {
        spacing: 14

        ColumnLayout {
            spacing: 4
            Text {
                text: addTrackModal.pendingKind === 0 ? "Add Video Track" : "Add Audio Track"
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: addTrackModal.pendingKind === 0 ? "Insert a new video track into the timeline?" : "Append a new audio track into the timeline?"
                color: "#888888"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
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
                text: "Add Track"
                primary: true
                onClicked: {
                    addTrackModal.confirmed(addTrackModal.pendingKind);
                    addTrackModal.close();
                }
            }

            XylaTextButton {
                text: "Cancel"
                outline: true
                onClicked: addTrackModal.close()
            }
        }
    }
}
