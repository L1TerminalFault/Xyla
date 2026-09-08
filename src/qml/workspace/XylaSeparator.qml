import QtQuick

Rectangle {
    id: root
    anchors.fill: parent
    color: "#2d2d2d"
    width: 1

    readonly property QtObject kddwSeparator: parent
    readonly property bool isVert: kddwSeparator ? kddwSeparator.isVertical : false

    MouseArea {
        anchors.centerIn: parent
        width: root.isVert ? parent.width : 6
        height: root.isVert ? 6 : parent.height
        cursorShape: root.isVert ? Qt.SizeVerCursor : Qt.SizeHorCursor

        onPressed: if (root.kddwSeparator) root.kddwSeparator.onMousePressed();
        onReleased: if (root.kddwSeparator) root.kddwSeparator.onMouseReleased();
        onPositionChanged: mouse => {
            if (root.kddwSeparator)
                root.kddwSeparator.onMouseMoved(Qt.point(mouse.x, mouse.y));
        }
        onDoubleClicked: if (root.kddwSeparator) root.kddwSeparator.onMouseDoubleClicked();
    }
}
