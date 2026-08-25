import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Xyla 1.0
import "../components"
import "./timeline"

Item {
    id: root

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    // 1. Sidebar Width State & Limits
    property int headerWidth: 350
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    // Unified Horizontal Scroll State
    property real horizontalOffset: 0.0
    property real contentWidth: 3600 // 3600px initial canvas length

    readonly property color bgDark: "#1a1a1a"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"

    // Background
    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Tools Bar (40px)
        Rectangle {
            id: topToolBar
            color: root.bgDark
            Layout.fillWidth: true
            height: 40

            // Bottom border separating tools bar from tracks
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.borderDark
            }
        }

        // Main Unified Tracks Area
        ListView {
            id: trackListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.activeTimelineModel

            delegate: Item {
                id: delegateRow
                width: trackListView.width
                height: trackHeader.implicitHeight

                Row {
                    anchors.fill: parent
                    spacing: 0

                    // 1. Fixed Left Track Header (Dynamic Width)
                    XylaTrackHeader {
                        id: trackHeader
                        width: root.headerWidth
                        trackId: model.trackId || ""
                        trackName: model.trackName || ""
                        trackKind: model.trackKind !== undefined ? model.trackKind : 0

                        onTrackRenamed: function (newName) {
                        // console.log("[Timeline] Track renamed:", trackId, "->", newName);
                        }

                        onLockToggled: function (locked) {
                        // console.log("[Timeline] Track lock toggled:", trackId, "locked:", locked);
                        }

                        onTrackHeightChanged: function (newHeight) {
                        // console.log("[Timeline] Track height changed:", trackId, "height:", newHeight);
                        }
                    }

                    // 2. Horizontally Scrolled Track Canvas Lane
                    Item {
                        width: delegateRow.width - root.headerWidth
                        height: parent.height
                        clip: true

                        Item {
                            x: -root.horizontalOffset
                            width: root.contentWidth
                            height: parent.height

                            // Track Lane Background
                            Rectangle {
                                anchors.fill: parent
                                color: index % 2 === 0 ? "#151515" : "#121212"

                                Rectangle {
                                    height: 1
                                    color: root.borderDark
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: (model.trackKind === 0 ? "Video Track Lane (" : "Audio Track Lane (") + (model.trackName || "") + ")"
                                    color: "#333333"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        // Horizontal Wheel / Shift-Scroll Handler on Canvas Lane
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false

                            onWheel: function (wheel) {
                                var maxOffset = Math.max(0, root.contentWidth - (delegateRow.width - root.headerWidth));

                                if (wheel.angleDelta.x !== 0) {
                                    var deltaX = -wheel.angleDelta.x;
                                    root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                                } else if (wheel.modifiers & Qt.ShiftModifier) {
                                    var deltaShift = -wheel.angleDelta.y;
                                    root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaShift));
                                } else {
                                    wheel.accepted = false; // Pass vertical wheel event to ListView for vertical scrolling
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "No Tracks Available\n(Create or open a project)"
                horizontalAlignment: Text.AlignHCenter
                color: "#555555"
                font.pixelSize: 13
                visible: trackListView.count === 0
            }
        }
    }

    // Full-Height Sidebar Horizontal Resizer (Positioned cleanly below top 40px bar)
    Item {
        id: sidebarResizer
        width: 8
        x: root.headerWidth - 4
        y: topToolBar.height // Starts cleanly below topToolBar (40px down)
        height: parent.height - y // Extends to bottom of timeline
        z: 100

        // 1px / 2px visible divider line
        Rectangle {
            anchors.centerIn: parent
            width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
            height: parent.height
            color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"

            Behavior on width {
                NumberAnimation {
                    duration: 80
                }
            }
        }

        MouseArea {
            id: resizerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property int startMouseX: 0
            property int startWidth: 0

            onPressed: function (mouse) {
                var pt = mapToItem(root, mouse.x, mouse.y);
                startMouseX = pt.x;
                startWidth = root.headerWidth;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(root, mouse.x, mouse.y);
                    var deltaX = pt.x - startMouseX;
                    var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
                    root.headerWidth = newW;
                }
            }
        }
    }
}
