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
    // readonly property bool picking: _pending || overlay.opened
    property bool picking: false

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
        picking = true;

        var ok = target.grabToImage(function (result) {
            root._grab = result;
            sampler.width = target.width;
            sampler.height = target.height;
            sampler.src = result.url.toString();
            sampler.loadImage(sampler.src);
        });
        if (!ok) {
            _pending = false;
            picking = false;
        }
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

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        onClosed: {
            root.picking = false;

            if (!root._committed)
                root.canceled();

            root._release();
        }

        contentItem: Item {
            id: content
            focus: true

            property real sampleX: area.mouseX
            property real sampleY: area.mouseY

            Keys.onPressed: event => {
                var x = sampleX;
                var y = sampleY;

                if (event.key === Qt.Key_Left)
                    x -= 1;
                else if (event.key === Qt.Key_Right)
                    x += 1;
                else if (event.key === Qt.Key_Up)
                    y -= 1;
                else if (event.key === Qt.Key_Down)
                    y += 1;
                else
                    return;

                x = Math.max(0, Math.min(overlay.width - 1, x));
                y = Math.max(0, Math.min(overlay.height - 1, y));

                sampleX = x;
                sampleY = y;

                root._sample(x, y);
                event.accepted = true;
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.BlankCursor

                onPositionChanged: mouse => {
                    content.sampleX = mouse.x;
                    content.sampleY = mouse.y;
                    root._sample(mouse.x, mouse.y);
                }

                onContainsMouseChanged: {
                    if (containsMouse) {
                        content.sampleX = mouseX;
                        content.sampleY = mouseY;
                        root._sample(mouseX, mouseY);
                        content.forceActiveFocus();
                    }
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        root._sample(content.sampleX, content.sampleY);
                        root._committed = true;
                        root.colorPicked(root._hover);
                    }

                    overlay.close();
                }
            }

            Item {
                id: mouseIndicator
                visible: area.containsMouse

                width: 24
                height: 24

                x: content.sampleX - width / 2
                y: content.sampleY - height / 2

                z: 20

                Item {
                    anchors.centerIn: parent
                    width: 14
                    height: 14

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#90000000"
                        shadowBlur: 0.65
                        shadowVerticalOffset: 2
                    }

                    // Horizontal line of the crosshair
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 2
                        color: "#ffffff"
                        border.color: "#ffffff"
                        border.width: 1
                    }

                    // Vertical line of the crosshair
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: "#ffffff"
                        border.color: "#ffffff"
                        border.width: 1
                    }
                }
            }

            Item {
                id: hud

                readonly property int panelWidth: 240
                readonly property int panelHeight: 86
                readonly property int panelPadding: 10
                readonly property int previewSize: panelHeight - panelPadding * 2
                readonly property int gap: 16
                readonly property int verticalGap: 16

                width: panelWidth
                height: panelHeight

                visible: area.containsMouse

                property bool placeLeft: content.sampleX + width + gap > overlay.width

                property bool placeAbove: content.sampleY + height + verticalGap > overlay.height

                x: placeLeft ? content.sampleX - width - gap : content.sampleX + gap

                y: placeAbove ? content.sampleY - height - verticalGap : content.sampleY + verticalGap

                z: 10

                Rectangle {
                    anchors.fill: parent
                    color: "#181818"
                    border.color: "#303030"
                    border.width: 1
                    radius: 12

                    layer.enabled: true

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#90000000"
                        shadowBlur: 0.65
                        shadowVerticalOffset: 6
                        shadowHorizontalOffset: 0
                    }
                }

                Rectangle {
                    id: preview
                    x: hud.panelPadding
                    y: hud.panelPadding
                    width: hud.previewSize
                    height: hud.previewSize
                    radius: 6
                    color: "#141414"
                    border.width: 1.5
                    border.color: "#202020"

                    // Mask: must be in the scene, layered, and hidden
                    Item {
                        id: previewMask
                        anchors.fill: parent
                        anchors.margins: preview.border.width
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: preview.radius
                            color: "white"
                        }
                    }

                    Item {
                        id: imageContainer
                        anchors.fill: parent
                        anchors.margins: preview.border.width

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: previewMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }

                        Image {
                            source: root._grab ? root._grab.url : ""
                            smooth: false
                            cache: false

                            width: sampler.width * root.zoom
                            height: sampler.height * root.zoom

                            x: imageContainer.width / 2 - (root._px + 0.5) * root.zoom

                            y: imageContainer.height / 2 - (root._py + 0.5) * root.zoom
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.zoom + 5
                        height: root.zoom + 5
                        radius: 2
                        color: "transparent"
                        border.color: "#ffffff"
                        border.width: 0.5
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.zoom + 3
                        height: root.zoom + 3
                        radius: 2
                        color: "transparent"
                        border.color: "#ffffff"
                        border.width: 0.5
                    }

                }

                Rectangle {
                    id: colorSwatch

                    x: preview.x + preview.width + 12
                    y: 19

                    width: 21
                    height: 21

                    radius: 4
                    color: root._hover

                    border.color: "#151515"
                    border.width: 1
                }

                Text {
                    x: preview.x + preview.width + 43
                    y: 19

                    text: root._hover.toString().toUpperCase()

                    color: "#c8c8c8"

                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    font.family: "Inter"
                }

                Item {
                    x: preview.x + preview.width + 12
                    y: 53

                    width: hud.width - x - hud.panelPadding
                    height: 24

                    // Text {
                    //     anchors.left: parent.left
                    //     anchors.verticalCenter: parent.verticalCenter
                    //
                    //     text: "✧"
                    //
                    //     color: "#858585"
                    //
                    //     font.pixelSize: 22
                    //     font.family: "Sans"
                    // }

                    Text {
                        anchors.left: parent.left
                        // anchors.leftMargin: 31
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Click to sample"

                        color: "#999999"

                        font.pixelSize: 14
                        font.family: "Inter"
                    }
                }
            }
        }
    }
}
