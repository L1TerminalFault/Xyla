import QtQuick
import QtQuick.Controls
import QtQuick.Layouts


    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 7
        color: "transparent"
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: "#2d2d2d"
        }
    }
