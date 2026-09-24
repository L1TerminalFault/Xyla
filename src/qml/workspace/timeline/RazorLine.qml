// import QtQuick
//
// Item {
//     id: root
//
//     property real frame: -1
//     property real zoomFactor: 1.0
//     property real horizontalOffset: 0.0
//     property real playheadMargin: 0.0
//
//     // Customizable styling properties
//     property color lineColor: "#a855f7"          // Vibrant purple
//     property real lineWidth: 1.0
//     property real lineOpacity: 0.95
//     property bool showGlow: true
//     property color glowColor: "#40a855f7"
//
//     opacity: frame >= 0
//
//     Behavior on opacity {
//         NumberAnimation {
//             duration: 220
//             easing.type: Easing.OutCubic
//         }
//     }
//
//     // X coordinate maps exactly like the playhead across the timeline canvas
//     x: Math.round(playheadMargin + (frame * zoomFactor) - horizontalOffset) - Math.floor(lineWidth / 2)
//     width: Math.max(1, lineWidth)
//     anchors.top: parent.top
//     anchors.bottom: parent.bottom
//
//     // Optional subtle purple laser glow
//     Rectangle {
//         visible: root.showGlow
//         anchors.horizontalCenter: parent.horizontalCenter
//         anchors.top: parent.top
//         anchors.bottom: parent.bottom
//         width: 3
//         color: root.glowColor
//         opacity: 0.6
//     }
//
//     // Clean purple 1px razor vertical cut line (no top bubble)
//     Rectangle {
//         anchors.horizontalCenter: parent.horizontalCenter
//         anchors.top: parent.top
//         anchors.bottom: parent.bottom
//         width: root.lineWidth
//         color: root.lineColor
//         opacity: root.lineOpacity
//     }
// }


import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real frame: -1
    property real zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real playheadMargin: 0.0

    // Customizable styling properties
    property color lineColor: "#a855f7"         // Vibrant purple
    property real lineWidth: 1.0
    property real lineOpacity: 0.95
    property bool showGlow: true
    property color glowColor: "#40a855f7"

    opacity: frame >= 0

    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // X coordinate maps exactly like the playhead across the timeline canvas
    x: Math.round(playheadMargin + (frame * zoomFactor) - horizontalOffset) - Math.floor(lineWidth / 2)
    width: Math.max(1, lineWidth)
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    // Optional subtle purple laser glow
    Rectangle {
        visible: root.showGlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.glowColor
        opacity: 0.6
    }

    // Clean purple 1px razor vertical cut line (no top bubble)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.lineWidth
        color: root.lineColor
        opacity: root.lineOpacity
    }

    // Scissors icon anchored to top center with a small margin, colorized to match the line
    Image {
        id: scissorsIcon
        source: "qrc:/assets/icons/scissors.svg"
        width: 24
        height: 24
        anchors.right: parent.right // horizontalCenter
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 12
        rotation: 180

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.lineColor
        }
    }
}
