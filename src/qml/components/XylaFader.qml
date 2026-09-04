import QtQuick
import QtQuick.Controls

Item {
    id: root

    property real value: 1.0
    property real minValue: 0.0
    property real maxValue: 2.0
    property real stepSize: 0.01
    property color accentColor: "#3b82f6"

    // Controlled by the DragHandler state
    readonly property bool isDragging: dragHandler.active

    implicitWidth: 32
    implicitHeight: 220

    Rectangle {
        id: outerTrack
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 8
        radius: 4
        color: "#0a0a0a"
        border.color: "#1f1f1f"
        border.width: 1

        Rectangle {
            id: trackGroove
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: "#181818"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: {
                    var range = root.maxValue - root.minValue;
                    var norm = (Math.max(root.minValue, Math.min(root.maxValue, root.value)) - root.minValue) / range;
                    return parent.height * norm;
                }
                color: root.accentColor
            }
        }
    }

    Rectangle {
        id: handle
        width: 18
        height: 38
        radius: 4
        color: root.isDragging ? "#2a2d32" : "#1e2124"
        border.color: root.isDragging ? "#666666" : "#3d4148"
        border.width: 1

        anchors.horizontalCenter: parent.horizontalCenter
        y: {
            var trackH = root.height - height;
            var range = root.maxValue - root.minValue;
            var norm = (Math.max(root.minValue, Math.min(root.maxValue, root.value)) - root.minValue) / range;
            return trackH * (1.0 - norm);
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 6
            height: 2
            color: root.accentColor
        }
    }

    // Helper function to process coordinates cleanly
    function updateValueFromMouse(mouseY) {
        var trackH = root.height - handle.height;
        var clampedY = Math.max(0, Math.min(trackH, mouseY - handle.height / 2));
        var norm = 1.0 - (clampedY / trackH);
        var range = root.maxValue - root.minValue;
        var newValue = root.minValue + (norm * range);
        if (root.stepSize > 0)
            newValue = Math.round(newValue / root.stepSize) * root.stepSize;
        root.value = Math.max(root.minValue, Math.min(root.maxValue, newValue));
    }

    // Handles absolute jumping clicks along the track length
    TapHandler {
        id: trackTap
        target: null
        onTapped: {
            var point = trackTap.point.position;
            root.updateValueFromMouse(point.y);
        }
        onDoubleTapped: root.value = 1.0
    }

    // Handles locked global dragging tracking behavior
    DragHandler {
        id: dragHandler
        target: null // Keeps the element visually bound to our custom 'y' logic
        xAxis.enabled: false
        yAxis.enabled: true

        onCentroidChanged: {
            if (active) {
                // Map the active position coordinate cleanly to the root coordinate framework
                var scenePoint = dragHandler.centroid.scenePosition;
                var localPoint = root.mapFromItem(null, scenePoint.x, scenePoint.y);
                root.updateValueFromMouse(localPoint.y);
            }
        }
    }
}
