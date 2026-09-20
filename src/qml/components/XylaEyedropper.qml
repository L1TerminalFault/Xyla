import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// In-app eyedropper.
//
// startPicking() snapshots the window, opens a full-window modal overlay with a
// magnifier loupe that follows the cursor, and emits colorPicked() on left click.
// Right click or Esc cancels (canceled()).
//
// Only pixels inside this application's window can be sampled.
Item {
    id: root
    width: 0
    height: 0

    signal colorHovered(color c)
    signal colorPicked(color c)
    signal canceled

    // Magnification of the loupe, in screen pixels per sampled pixel.
    property int zoom: 10
    readonly property bool picking: _pending || overlay.opened

    // The item to snapshot. Must be created from QML (has a QML engine), so
    // NOT Window.contentItem, which is a C++ root item. Point this at the
    // top-level Item of your main window content.
    property Item grabTarget: null

    property Item _target: null
    property var _grab: null
    property bool _pending: false
    property bool _drawn: false
    property bool _committed: false
    property int _px: 0
    property int _py: 0
    property color _hover: "#000000"

    function startPicking() {
        if (picking)
            return;
        var target = grabTarget;
        if (!target) {
            console.warn("XylaEyedropper: set grabTarget to a QML-created item");
            return;
        }

        _target = target;
        _committed = false;
        _drawn = false;
        _pending = true;

        var ok = target.grabToImage(function (result) {
            root._grab = result;
            sampler.width = target.width;
            sampler.height = target.height;
            sampler.src = result.url.toString();
            sampler.loadImage(sampler.src);
        });
        if (!ok)
            _pending = false;
    }

    function _sample(x, y) {
        if (!_target)
            return;
        var p = _target.mapFromItem(area, x, y);
        _px = Math.max(0, Math.min(sampler.width - 1, Math.floor(p.x)));
        _py = Math.max(0, Math.min(sampler.height - 1, Math.floor(p.y)));
        _hover = sampler.pixelAt(_px, _py);
        colorHovered(_hover);
    }

    function _release() {
        if (sampler.src !== "")
            sampler.unloadImage(sampler.src);
        sampler.src = "";
        sampler.width = 0;
        sampler.height = 0;
        _grab = null;
        _target = null;
        _drawn = false;
    }

    // Off-screen pixel reader for the window snapshot.
    Canvas {
        id: sampler
        opacity: 0
        enabled: false
        renderTarget: Canvas.Image

        property string src: ""

        onImageLoaded: requestPaint()

        onPaint: {
            if (src === "" || !isImageLoaded(src))
                return;
            var ctx = getContext("2d");
            ctx.drawImage(src, 0, 0, width, height);
            root._drawn = true;
        }

        // Only open the overlay once the snapshot has actually been drawn,
        // otherwise the first getImageData() would read an empty canvas.
        onPainted: {
            if (root._pending && root._drawn) {
                root._pending = false;
                overlay.open();
            }
        }

        function pixelAt(x, y) {
            var d = getContext("2d").getImageData(x, y, 1, 1).data;
            return Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1.0);
        }
    }

    Popup {
        id: overlay
        parent: Overlay.overlay
        x: 0
        y: 0
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        padding: 0
        modal: true
        dim: false
        focus: true
        closePolicy: Popup.CloseOnEscape

        background: null
        enter: null
        exit: null

        onClosed: {
            if (!root._committed)
                root.canceled();
            root._release();
        }

        contentItem: Item {
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.BlankCursor

                onPositionChanged: mouse => root._sample(mouse.x, mouse.y)
                onContainsMouseChanged: {
                    if (containsMouse)
                        root._sample(mouseX, mouseY);
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        root._sample(mouse.x, mouse.y);
                        root._committed = true;
                        root.colorPicked(root._hover);
                    }
                    overlay.close();
                }
            }

            // Loupe + hex readout, flips to the other side of the cursor near edges.
            Item {
                id: hud
                readonly property int loupeSize: 132

                width: loupeSize
                height: loupeSize + 30
                visible: area.containsMouse

                // Loupe centre sits exactly on the cursor hotspot.
                x: area.mouseX - loupeSize / 2
                y: area.mouseY - loupeSize / 2

                Item {
                    id: loupeMask
                    width: hud.loupeSize
                    height: hud.loupeSize
                    layer.enabled: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                    }
                }

                Item {
                    id: loupe
                    width: hud.loupeSize
                    height: hud.loupeSize

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: loupeMask
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                    }

                    Image {
                        source: root._grab ? root._grab.url : ""
                        smooth: false
                        cache: false
                        width: sampler.width * root.zoom
                        height: sampler.height * root.zoom
                        // Put the centre of the sampled pixel at the centre of the loupe.
                        x: loupe.width / 2 - (root._px + 0.5) * root.zoom
                        y: loupe.height / 2 - (root._py + 0.5) * root.zoom
                    }
                }

                // Ring
                Rectangle {
                    anchors.fill: loupe
                    radius: width / 2
                    color: "transparent"
                    border.color: "#303030"
                    border.width: 3
                }

                // Sampled-pixel reticle
                Rectangle {
                    anchors.centerIn: loupe
                    width: root.zoom + 4
                    height: root.zoom + 4
                    color: "transparent"
                    border.color: "#000000"
                    border.width: 1
                }
                Rectangle {
                    anchors.centerIn: loupe
                    width: root.zoom + 2
                    height: root.zoom + 2
                    color: "transparent"
                    border.color: "#ffffff"
                    border.width: 1
                }

                // Hex readout
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: area.mouseY + hud.loupeSize / 2 + 36 > overlay.height ? -30 : hud.loupeSize + 6
                    width: 94
                    height: 24
                    radius: 6
                    color: "#181818"
                    border.color: "#303030"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 3
                            color: root._hover
                            border.color: "#2d2d2d"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root._hover.toString().toUpperCase()
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.family: "Monospace"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
