import QtQuick
import QtQuick.Controls
import Xyla.Render 1.0

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    XylaVideoSurface {
        id: videoSurface
        anchors.fill: parent

        Connections {
            target: typeof timelineCompositor !== "undefined" ? timelineCompositor : null
            function onFrameComposited() {
                videoSurface.onFrameComposited();
            }
        }
    }
}
