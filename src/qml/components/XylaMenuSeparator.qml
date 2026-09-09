import QtQuick
import QtQuick.Controls

MenuSeparator {
    id: control
    padding: 0                    // we control spacing ourselves

    contentItem: Item {
        implicitWidth: 180
        implicitHeight: 13        // 1px line + 6px top + 6px bottom

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            height: 1
            color: "#2d2d2d"
        }
    }
}
