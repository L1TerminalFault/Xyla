import QtQuick
import QtQuick.Controls

Menu {
    id: customMenu

    property string menuIcon: ""
    property string menuDescription: ""

    padding: 6
    overlap: 1
    transformOrigin: Item.TopLeft
    implicitWidth: 200

    delegate: XylaMenuItem {}

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 32
        color: "#181818"
        border.color: "#282828"
        border.width: 1
        radius: 8
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 100
            easing.type: Easing.OutCubic
        }
    }
}
