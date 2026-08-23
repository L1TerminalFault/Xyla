import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: cardRoot

    signal clicked()

    property string projectName: ""
    property string projectPath: ""
    property string lastModifiedDate: ""

    Layout.fillWidth: true
    implicitHeight: 64

    color: mouseArea.containsMouse ? "#1c1c1c" : "#141414"
    radius: 6
    border.color: mouseArea.containsMouse ? "#383838" : "#262626"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: cardRoot.projectName
                color: "#e1e1e1"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: cardRoot.projectPath
                color: "#6e6e6e"
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }

        Text {
            text: cardRoot.lastModifiedDate
            color: "#6e6e6e"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cardRoot.clicked()
    }
}
