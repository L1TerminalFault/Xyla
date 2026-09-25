import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../components/"

Rectangle {
    id: cardRoot

    signal clicked

    property string projectName: ""
    property string projectPath: ""
    property string lastModifiedDate: ""
    property string thumbnail: ""

    Layout.fillWidth: true
    implicitHeight: 74

    color: mouseArea.containsMouse ? "#1c1c1c" : "#161616"
    radius: 35

RectangularShadow {
        // Use negative margins to allow the shadow to render OUTSIDE the card
        anchors.fill: cardRoot
        anchors.topMargin: -4
        anchors.bottomMargin: -8
        anchors.leftMargin: -4
        anchors.rightMargin: -4

        z: -1
        radius: cardRoot.radius + 4 // Match the card's rounded corners
        blur: 24                    // Softness of the shadow
        spread: 2                   // Makes the shadow slightly bolder
        offset.x: 0
        offset.y: 4                 // Shift downward
        color: "#26000000"          // Darker opacity so it's clearly visible on dark UI
    }

    border.width: 3
    border.color: mouseArea.containsMouse ? "#222222" : "#191919"
    scale: mouseArea.containsMouse ? 1.9 : 1.0
    clip: false

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }

    Rectangle {
        id: imageContainer
        anchors.fill: parent
        anchors.margins: 5
        radius: cardRoot.radius - 5
        color: "#121213"

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: imageContainer.width
                    height: imageContainer.height
                    radius: imageContainer.radius
                }
            }
        }

        EmptyThumb {
            anchors.fill: parent
            visible: thumbnail === ""
        }

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            visible: thumbnail !== ""
            source: "qrc:/assets/splash_banner.png" // panelRoot.dragPreviewPath ? "image://thumbnails/" + panelRoot.dragPreviewPath + "?width=120" : ""
            // asynchronous: true
        }
    }

    // Main RowLayout for text content (with right margin so it doesn't overlap the badge)
    // RowLayout {
    Rectangle {
        id: innerCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        property double margin_: 5 // 4.5
        anchors.leftMargin: margin_
        anchors.rightMargin: margin_
        anchors.bottomMargin: margin_

        // Point this at whatever sits behind the card in the same window —
        // your content root, a canvas, another panel, etc. It must NOT be
        // a child of innerCard, or you get a feedback loop.
        property Item backdropSource: imageContainer // null

        color: "transparent"   // the blur + gradient below replace the flat fill
        // color: "red"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 30
        bottomRightRadius: 30

        property int padding: 17

        implicitHeight: Math.max(textCol.implicitHeight, dateBadge.implicitHeight) + padding * 2

        // --- corner mask, shared by blur and gradient layers ---
        Item {
            id: cardMask
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                topLeftRadius: innerCard.topLeftRadius
                topRightRadius: innerCard.topRightRadius
                bottomLeftRadius: innerCard.bottomLeftRadius
                bottomRightRadius: innerCard.bottomRightRadius
                color: "white"
            }
        }

        Item {
            id: blurredStack
            anchors.fill: parent

            // Reuse the corrected sourceRect logic from before, once.
            ShaderEffectSource {
                id: backdropGrab
                sourceItem: innerCard.backdropSource
                sourceRect: innerCard.backdropSource ? Qt.rect(innerCard.x - imageContainer.x - blurredStack.maxBlurMargin, innerCard.y - imageContainer.y - blurredStack.maxBlurMargin, innerCard.width + blurredStack.maxBlurMargin * 2, innerCard.height + blurredStack.maxBlurMargin * 2) : Qt.rect(0, 0, 0, 0)
                live: true
                hideSource: false
                visible: false
            }
            readonly property int maxBlurMargin: 48   // matches the top layer's blurMax

            // One layer per blur step. Each is masked by its own vertical gradient,
            // so it only becomes visible in the band where it should dominate.
            Repeater {
                model: [
                    {
                        blur: 1,
                        from: 0.00,
                        to: 0.04
                    },
                    {
                        blur: 2,
                        from: 0.03,
                        to: 0.08
                    },
                    {
                        blur: 4,
                        from: 0.06,
                        to: 0.12
                    },
                    {
                        blur: 7,
                        from: 0.09,
                        to: 0.16
                    },
                    {
                        blur: 11,
                        from: 0.12,
                        to: 0.20
                    },
                    {
                        blur: 16,
                        from: 0.15,
                        to: 0.25
                    },
                    {
                        blur: 22,
                        from: 0.19,
                        to: 0.30
                    },
                    {
                        blur: 28,
                        from: 0.23,
                        to: 0.36
                    },
                    {
                        blur: 34,
                        from: 0.28,
                        to: 0.43
                    },
                    {
                        blur: 40,
                        from: 0.34,
                        to: 0.52
                    },
                    {
                        blur: 45,
                        from: 0.42,
                        to: 0.63
                    },
                    {
                        blur: 50,
                        from: 0.52,
                        to: 0.76
                    },
                    {
                        blur: 55,
                        from: 0.64,
                        to: 0.88
                    },
                    {
                        blur: 60,
                        from: 0.78,
                        to: 1.00
                    }
                // { blur: 8,  from: 0.0, to: 0.35 },
                // { blur: 20, from: 0.2, to: 0.65 },
                // { blur: 36, from: 0.5, to: 0.85 },
                // { blur: 56, from: 0.75, to: 1.0 }
                ]

                Item {
                    required property var modelData
                    anchors.fill: parent

                    // Per-layer alpha mask: transparent -> opaque over [from, to],
                    // so this layer fades in as you move down the card.
                    Item {
                        id: stepMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: modelData.from
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: modelData.to
                                    color: "white"
                                }
                            }
                        }
                    }

                    MultiEffect {
                        x: -blurredStack.maxBlurMargin
                        y: -blurredStack.maxBlurMargin
                        width: parent.width + blurredStack.maxBlurMargin * 2
                        height: parent.height + blurredStack.maxBlurMargin * 2
                        source: backdropGrab
                        blurEnabled: true
                        blur: 1.0
                        blurMax: modelData.blur
                        autoPaddingEnabled: false
                        maskEnabled: true
                        maskSource: stepMask
                    }
                }
            }

            // Clip the whole stack to the card's rounded shape, same as before.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }
        }
        // --- 1. backdrop blur ---
        // ShaderEffectSource {
        //     id: backdropGrab
        //     sourceItem: innerCard.backdropSource
        // sourceRect: innerCard.backdropSource
        //             ? Qt.rect(innerCard.x, innerCard.y, innerCard.width, innerCard.height)
        //             : Qt.rect(0, 0, 0, 0)
        //     live: true
        //     hideSource: false
        //     visible: false
        // }
        //
        //     MultiEffect {
        //         id: blurred
        //         anchors.fill: parent
        //         source: backdropGrab
        //         blurEnabled: true
        //         blur: 1.0
        //         blurMax: 48
        //         autoPaddingEnabled: false
        //         maskEnabled: true
        //         maskSource: cardMask
        //     }

        // --- 2. gradient overlay: transparent top -> dark grey bottom ---
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            Rectangle {
                anchors.fill: parent
                // color: "#1A1A1A1A"
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#800A0A0A"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#FF0A0A0A"
                    }
                }
            }
        }

        ColumnLayout {
            id: textCol

            anchors.left: parent.left
            anchors.right: dateBadge.left

            anchors.leftMargin: innerCard.padding
            anchors.rightMargin: innerCard.padding

            anchors.top: parent.top
            anchors.topMargin: innerCard.padding

            spacing: 4

            Text {
                text: cardRoot.projectName
                color: "#e1e1e1"
                font.pixelSize: 18
                elide: Text.ElideRight
                font.family: "Inter"
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Text {
                id: pathText
                Layout.alignment: Qt.AlignBottom

                HoverHandler {
                    id: pathHover
                }

                XylaToolTip {
                    visible: pathHover.hovered
                    text: cardRoot.projectPath.toString()
                    delay: 600
                }

                function displayProjectPath(path) {
                    if (!path)
                        return "";

                    var p = path.toString();

                    // Remove file:// prefix if present
                    p = p.replace(/^file:\/\//, "");

                    var parts = p.split("/").filter(function (part) {
                        return part !== "";
                    });

                    // Remove filename
                    if (parts.length > 0)
                        parts.pop();

                    // Remove /home/<username>/
                    if (parts.length >= 2 && parts[0] === "home")
                        parts = parts.slice(2);

                    return parts.join(" › ");
                }

                text: displayProjectPath(cardRoot.projectPath)
                color: "#6e6e6e"
                font.pixelSize: 10
                font.family: "Inter"
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
        // }

        Rectangle {
            id: dateBadge
            anchors.right: parent.right
            anchors.rightMargin: innerCard.padding
            anchors.verticalCenter: parent.verticalCenter
            // Layout.alignment: Qt.AlignVCenter
            //         anchors.right: cardRoot.right
            //         anchors.rightMargin: 16
            //         // anchors.bottom: cardRoot.bottom
            //         anchors.bottomMargin: 10
            // anchors.top: cardRoot.type === "palette" ? cardRoot.top : undefined
            //         anchors.topMargin: cardRoot.type === "palette" ? 10 : undefined
            //         anchors.bottom: cardRoot.type === "palette" ? undefined : cardRoot.bottom

            property bool hovered: mouseArea.containsMouse
            property bool showTime: false

            // 3-second hover timer for the time detail
            Timer {
                id: hoverTimer
                interval: 620
                running: dateBadge.hovered
                repeat: false
                onTriggered: dateBadge.showTime = true
            }

            onHoveredChanged: {
                if (!dateBadge.hovered) {
                    hoverTimer.stop();
                    dateBadge.showTime = false;
                }
            }

            // Dynamically track content height with smooth animation
            height: mainCol.implicitHeight + 8
            // Behavior on height {
            //     NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            // }
            width: Math.max(rowLayout.implicitWidth, timeWrapper.implicitWidth) + 16
            // Behavior on width {
            //     NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            // }

            radius: 11 // height / 2 // 10
            color: "#282828"
            clip: true

            readonly property var dateParts: {
                var s = cardRoot.lastModifiedDate;
                var parts = s.split(",");
                if (parts.length >= 4) {
                    return {
                        base: parts[0].trim() + ", " + parts[1].trim() // Static (e.g., "Mon, Oct 12")
                        ,
                        extra: parts[2].trim()                         // Expandable year on hover
                        ,
                        time: parts[3].trim()                           // Time detail after 3s hover
                    };
                }
                return {
                    base: s,
                    extra: "",
                    time: ""
                };
            }

            ColumnLayout {
                id: mainCol
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                spacing: 2

                // Top Row (Base text + Expandable Year)
                RowLayout {
                    id: rowLayout
                    Layout.alignment: Qt.AlignRight
                    spacing: 0

                    Text {
                        id: baseText
                        Layout.alignment: Qt.AlignVCenter
                        text: dateBadge.dateParts.base.replace(",", "")
                        color: "#cecece"
                        font.family: "Inter"
                        font.weight: animWeight // !dateBadge.hovered ? Font.DemiBold : Font.Medium
                        font.pixelSize: 10
                        // 1. Intermediary property to hold and animate the weight value
                        property int animWeight: 600 // Starts at DemiBold

                        Behavior on animWeight {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        // 2. Change the target weight when hover state changes
                        Connections {
                            target: dateBadge
                            function onHoveredChanged() {
                                baseText.animWeight = dateBadge.hovered ? 500 : 600; // Animates between 550 and 600
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: dateBadge.hovered ? extraText.implicitWidth + 2 : 0
                        Layout.fillHeight: true
                        clip: true

                        Behavior on Layout.preferredWidth {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            id: extraText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            text: (dateBadge.hovered ? ", " : "") + dateBadge.dateParts.extra.replace(",", "")
                            color: "#cecece"
                            font.pixelSize: 10
                        }
                    }
                }

                // Bottom Row for Time Detail (Expands upwards after 3s hover)
                Item {
                    id: timeWrapper
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: timeText.implicitWidth
                    Layout.preferredHeight: dateBadge.showTime ? timeText.implicitHeight : 0
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: timeText
                        anchors.right: parent.right
                        text: dateBadge.dateParts.time.toUpperCase()
                        color: "#cecece"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cardRoot.clicked()
    }

    component EmptyThumb: Item {
        id: root

        width: 403
        height: 257

        // Transparent canvas — the surrounding background is not part of the component.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        // Back palette
        Rectangle {
            id: backCard
            x: 20
            y: 45
            width: 290
            height: 175
            radius: 11
            color: "#151515"
            border.color: "#282828"
            border.width: 1
            rotation: -8

            // Header
            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 31
                color: "transparent"

                Rectangle {
                    x: 11
                    y: 10
                    width: 7
                    height: 7
                    radius: 3.5
                    color: "#292929"
                }

                Rectangle {
                    x: 25
                    y: 9
                    width: 8
                    height: 8
                    radius: 4
                    color: "#292929"
                }

                Rectangle {
                    x: 40
                    y: 8
                    width: 8
                    height: 8
                    radius: 4
                    color: "#292929"
                }

                Rectangle {
                    x: 0
                    y: 30
                    width: parent.width
                    height: 1
                    color: "#222222"
                }
            }

            // Small video indicator
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 17
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 5
                opacity: 0.55

                Rectangle {
                    width: 16
                    height: 3
                    radius: 1.5
                    color: "#343434"
                }

                Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: "#404040"
                }
            }
        }

        // Middle palette
        Rectangle {
            id: middleCard
            x: 83
            y: 16
            width: 250
            height: 157
            radius: 11
            color: "#181818"
            border.color: "#292929"
            border.width: 1
            rotation: 2.5

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 31
                color: "transparent"

                Rectangle {
                    x: 11
                    y: 10
                    width: 8
                    height: 8
                    radius: 4
                    color: "#2b2b2b"
                }

                Rectangle {
                    x: 25
                    y: 9
                    width: 8
                    height: 8
                    radius: 4
                    color: "#2b2b2b"
                }

                Rectangle {
                    x: 40
                    y: 8
                    width: 8
                    height: 8
                    radius: 4
                    color: "#2b2b2b"
                }

                Rectangle {
                    x: 0
                    y: 30
                    width: parent.width
                    height: 1
                    color: "#222222"
                }
            }

            // Minimal video/timeline indicators
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 13
                spacing: 4
                opacity: 0.48

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: "#454545"
                }

                Rectangle {
                    width: 11
                    height: 3
                    radius: 1.5
                    color: "#353535"
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: "#454545"
                }
            }
        }

        // Foreground palette
        Rectangle {
            id: frontCard
            x: 141
            y: 59
            width: 245
            height: 170
            radius: 11
            color: "#1d1d1d"
            border.color: "#292929"
            border.width: 1
            rotation: -2.8

            // Header
            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 31
                color: "transparent"

                Rectangle {
                    x: 11
                    y: 10
                    width: 8
                    height: 8
                    radius: 4
                    color: "#292929"
                }

                Rectangle {
                    x: 25
                    y: 9
                    width: 8
                    height: 8
                    radius: 4
                    color: "#292929"
                }

                Rectangle {
                    x: 40
                    y: 8
                    width: 8
                    height: 8
                    radius: 4
                    color: "#292929"
                }

                Rectangle {
                    x: 0
                    y: 30
                    width: parent.width
                    height: 1
                    color: "#242424"
                }
            }

            // Sleek video controls / indicators
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 7
                opacity: 0.52

                // Play glyph
                Canvas {
                    width: 8
                    height: 9

                    onPaint: {
                        var p = getContext("2d");
                        p.clearRect(0, 0, width, height);
                        p.fillStyle = "#4a4a4a";
                        p.beginPath();
                        p.moveTo(1, 0);
                        p.lineTo(8, 4.5);
                        p.lineTo(1, 9);
                        p.closePath();
                        p.fill();
                    }
                }

                // Timeline
                Rectangle {
                    width: 32
                    height: 3
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#333333"

                    Rectangle {
                        width: 10
                        height: parent.height
                        radius: height / 2
                        color: "#494949"
                    }
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#414141"
                }
            }

            // Tiny right-side video status marks
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 4
                opacity: 0.42

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: "#505050"
                }

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: "#424242"
                }

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: "#343434"
                }
            }
        }
    }
}
