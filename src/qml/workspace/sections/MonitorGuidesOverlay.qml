import QtQuick

Item {
    id: overlayRoot

    property var horizontalGuides: []
    property var verticalGuides: []
    property bool guidesLocked: false
    property bool guidesVisible: true

    property real nativeWidth: 1920
    property real nativeHeight: 1080
    property var snapFunction: null

    signal guideMoved(string orientation, int index, real newPos)
    signal guideDeleted(string orientation, int index)

    visible: guidesVisible

    // --- Horizontal Guide Lines ---
    Repeater {
        model: overlayRoot.horizontalGuides

        Item {
            id: hGuide
            property real nativeY: Number(modelData)
            property bool isDragging: false

            width: overlayRoot.width
            height: 1
            y: Math.round((nativeY / overlayRoot.nativeHeight) * overlayRoot.height)

            Rectangle {
                anchors.fill: parent
                height: 1
                color: (hMouse.containsMouse || hGuide.isDragging) && !overlayRoot.guidesLocked ? "#60a5fa" : "#38bdf8"
                opacity: 0.85
            }

            Rectangle {
                visible: hGuide.isDragging
                x: 10
                y: -18
                width: badgeTextH.implicitWidth + 8
                height: 16
                radius: 3
                color: "#18181b"
                border.color: "#3b82f6"
                border.width: 1

                Text {
                    id: badgeTextH
                    anchors.centerIn: parent
                    text: "Y: " + Math.round(hGuide.nativeY) + "px"
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.family: "Monospace"
                }
            }

            MouseArea {
                id: hMouse
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                hoverEnabled: !overlayRoot.guidesLocked
                enabled: !overlayRoot.guidesLocked
                cursorShape: Qt.SplitVCursor

                onPressed: function (mouse) {
                    hGuide.isDragging = true;
                }

                onPositionChanged: function (mouse) {
                    if (pressed && hGuide.isDragging) {
                        var pt = mapToItem(overlayRoot, mouse.x, mouse.y);
                        var rawNativeY = (pt.y / overlayRoot.height) * overlayRoot.nativeHeight;
                        var snappedY = overlayRoot.snapFunction ? overlayRoot.snapFunction("horizontal", rawNativeY, index) : rawNativeY;
                        hGuide.nativeY = snappedY;
                    }
                }

                onReleased: function (mouse) {
                    hGuide.isDragging = false;
                    var pt = mapToItem(overlayRoot, mouse.x, mouse.y);
                    if (pt.y < -20 || pt.y > overlayRoot.height + 20) {
                        overlayRoot.guideDeleted("horizontal", index);
                    } else {
                        var rawNativeY = (pt.y / overlayRoot.height) * overlayRoot.nativeHeight;
                        var snappedY = overlayRoot.snapFunction ? overlayRoot.snapFunction("horizontal", rawNativeY, index) : rawNativeY;
                        hGuide.nativeY = snappedY;
                        overlayRoot.guideMoved("horizontal", index, Math.round(snappedY));
                    }
                }
            }
        }
    }

    // --- Vertical Guide Lines ---
    Repeater {
        model: overlayRoot.verticalGuides

        Item {
            id: vGuide
            property real nativeX: Number(modelData)
            property bool isDragging: false

            width: 1
            height: overlayRoot.height
            x: Math.round((nativeX / overlayRoot.nativeWidth) * overlayRoot.width)

            Rectangle {
                anchors.fill: parent
                width: 1
                color: (vMouse.containsMouse || vGuide.isDragging) && !overlayRoot.guidesLocked ? "#60a5fa" : "#38bdf8"
                opacity: 0.85
            }

            Rectangle {
                visible: vGuide.isDragging
                x: 4
                y: 10
                width: badgeTextV.implicitWidth + 8
                height: 16
                radius: 3
                color: "#18181b"
                border.color: "#3b82f6"
                border.width: 1

                Text {
                    id: badgeTextV
                    anchors.centerIn: parent
                    text: "X: " + Math.round(vGuide.nativeX) + "px"
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.family: "Monospace"
                }
            }

            MouseArea {
                id: vMouse
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 10
                hoverEnabled: !overlayRoot.guidesLocked
                enabled: !overlayRoot.guidesLocked
                cursorShape: Qt.SplitHCursor

                onPressed: function (mouse) {
                    vGuide.isDragging = true;
                }

                onPositionChanged: function (mouse) {
                    if (pressed && vGuide.isDragging) {
                        var pt = mapToItem(overlayRoot, mouse.x, mouse.y);
                        var rawNativeX = (pt.x / overlayRoot.width) * overlayRoot.nativeWidth;
                        var snappedX = overlayRoot.snapFunction ? overlayRoot.snapFunction("vertical", rawNativeX, index) : rawNativeX;
                        vGuide.nativeX = snappedX;
                    }
                }

                onReleased: function (mouse) {
                    vGuide.isDragging = false;
                    var pt = mapToItem(overlayRoot, mouse.x, mouse.y);
                    if (pt.x < -20 || pt.x > overlayRoot.width + 20) {
                        overlayRoot.guideDeleted("vertical", index);
                    } else {
                        var rawNativeX = (pt.x / overlayRoot.width) * overlayRoot.nativeWidth;
                        var snappedX = overlayRoot.snapFunction ? overlayRoot.snapFunction("vertical", rawNativeX, index) : rawNativeX;
                        vGuide.nativeX = snappedX;
                        overlayRoot.guideMoved("vertical", index, Math.round(snappedX));
                    }
                }
            }
        }
    }
}
