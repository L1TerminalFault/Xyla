import QtQuick 2.15

Rectangle {
    id: root
    anchors.fill: parent
    color: "#141313"

    readonly property QtObject kddwSeparator: parent
    readonly property bool isVert: kddwSeparator ? kddwSeparator.isVertical : false

    // Top & Bottom 1px borders for horizontal splitter bars
    Rectangle {
        visible: root.isVert
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#2d2d2d"
    }

    Rectangle {
        visible: root.isVert
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#2d2d2d"
    }

    // Left & Right 1px borders for vertical splitter bars
    Rectangle {
        visible: !root.isVert
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#2d2d2d"
    }

    Rectangle {
        visible: !root.isVert
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#2d2d2d"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.kddwSeparator ? (root.kddwSeparator.isVertical ? Qt.SizeVerCursor : Qt.SizeHorCursor) : Qt.SizeHorCursor

        onPressed: {
            if (root.kddwSeparator)
                root.kddwSeparator.onMousePressed();
        }

        onReleased: {
            if (root.kddwSeparator)
                root.kddwSeparator.onMouseReleased();
        }

        onPositionChanged: mouse => {
            if (root.kddwSeparator)
                root.kddwSeparator.onMouseMoved(Qt.point(mouse.x, mouse.y));
        }

        onDoubleClicked: {
            if (root.kddwSeparator)
                root.kddwSeparator.onMouseDoubleClicked();
        }
    }
}
