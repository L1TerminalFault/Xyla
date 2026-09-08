import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    property string clipName: ""
    property int durationFrames: 0
    property string assetId: ""

    RowLayout {
        Text {
            text: "Name:"
            color: "#666666"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }
        Text {
            text: root.clipName
            color: "#cccccc"
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Text {
            text: "Duration:"
            color: "#666666"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }
        Text {
            text: root.durationFrames > 0 ? (root.durationFrames + " frames") : ""
            color: "#cccccc"
            font.pixelSize: 11
        }
    }

    RowLayout {
        Text {
            text: "Asset ID:"
            color: "#666666"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }
        Text {
            text: root.assetId
            color: "#888888"
            font.pixelSize: 10
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
    }
}
