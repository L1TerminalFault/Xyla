import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool hasClip: false
    property string clipName: ""

    anchors.fill: parent

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: !root.hasClip ? "No Clip Selected" : "No Keyframed Properties"
            color: "#e0e0e0"
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: !root.hasClip ? "Select a clip on the timeline to inspect and edit its keyframes." : ("Keyframe any parameter in the Inspector to animate " + (root.clipName !== "" ? "\"" + root.clipName + "\"." : "this clip."))
            color: "#666666"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
