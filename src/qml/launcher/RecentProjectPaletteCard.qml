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
    implicitHeight: 50

    color: mouseArea.containsMouse ? "#1c1c1c" : "#161616"
    radius: 30

RectangularShadow {
        anchors.fill: cardRoot
        anchors.topMargin: -4
        anchors.bottomMargin: -8
        anchors.leftMargin: -4
        anchors.rightMargin: -4

        z: -1
        radius: cardRoot.radius + 4
        blur: 24
        spread: 2
        offset.x: 0
        offset.y: 4
        color: "#26000000" 
    }

    border.width: 3
    border.color: mouseArea.containsMouse ? "#252525" : "#191919"
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

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            visible: thumbnail !== ""
            source: panelRoot.dragPreviewPath ? "image://thumbnails/" + panelRoot.dragPreviewPath + "?width=120" : ""
        }
    }


Item {
    id: info
    width: 20
    height: 20
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.rightMargin: innerCard.padding
    anchors.topMargin: innerCard.padding
        z: 100

    Rectangle {
        id: infoBg
        anchors.fill: parent
        radius: 10
        color: infoMouse.containsMouse ? "#202020" : "#2d2d2d"

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
                XylaToolTip {
                    visible: infoMouse.containsMouse
                    text: cardRoot.projectPath.toString()
                    delay: 400
                }

        Image {
            anchors.fill: parent
            anchors.margins: 2
            fillMode: Image.PreserveAspectFit
            source: "qrc:/assets/icons/info.svg"
            sourceSize: Qt.size(30, 30)
            opacity: infoMouse.containsMouse ? 1.0 : 0.65

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
        }
    }

    MouseArea {
        id: infoMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
        }
    }
}


    Rectangle {
        id: innerCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        property double margin_: 5
        anchors.leftMargin: margin_
        anchors.rightMargin: margin_
        anchors.bottomMargin: margin_

        property Item backdropSource: imageContainer

        color: "transparent"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 25
        bottomRightRadius: 25

        property int padding: 17

        implicitHeight: Math.max(textCol.implicitHeight, dateBadge.implicitHeight) + padding * 2

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

            ShaderEffectSource {
                id: backdropGrab
                sourceItem: innerCard.backdropSource
                sourceRect: innerCard.backdropSource ? Qt.rect(innerCard.x - imageContainer.x - blurredStack.maxBlurMargin, innerCard.y - imageContainer.y - blurredStack.maxBlurMargin, innerCard.width + blurredStack.maxBlurMargin * 2, innerCard.height + blurredStack.maxBlurMargin * 2) : Qt.rect(0, 0, 0, 0)
                live: true
                hideSource: false
                visible: false
            }
            readonly property int maxBlurMargin: 48 

            Repeater {
                model: [
                    { blur: 1, from: 0.00, to: 0.04 },
                    { blur: 2, from: 0.03, to: 0.08 },
                    { blur: 4, from: 0.06, to: 0.12 },
                    { blur: 7, from: 0.09, to: 0.16 },
                    { blur: 11, from: 0.12, to: 0.20 },
                    { blur: 16, from: 0.15, to: 0.25 },
                    { blur: 22, from: 0.19, to: 0.30 },
                    { blur: 28, from: 0.23, to: 0.36 },
                    { blur: 34, from: 0.28, to: 0.43 },
                    { blur: 40, from: 0.34, to: 0.52 },
                    { blur: 45, from: 0.42, to: 0.63 },
                    { blur: 50, from: 0.52, to: 0.76 },
                    { blur: 55, from: 0.64, to: 0.88 },
                    { blur: 60, from: 0.78, to: 1.00 }
                ]

                Item {
                    required property var modelData
                    anchors.fill: parent

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

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#D00A0A0A"
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
                visible: false
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

                    p = p.replace(/^file:\/\//, "");

                    var parts = p.split("/").filter(function (part) {
                        return part !== "";
                    });

                    if (parts.length > 0)
                        parts.pop();

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

        Rectangle {
            id: dateBadge
            anchors.right: parent.right
            anchors.rightMargin: innerCard.padding
            anchors.verticalCenter: parent.verticalCenter

            property bool hovered: mouseArea.containsMouse
            property bool showTime: false

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

            height: mainCol.implicitHeight + 8
            width: Math.max(rowLayout.implicitWidth, timeWrapper.implicitWidth) + 16

            radius: 11
            color: "#282828"
            clip: true

            readonly property var dateParts: {
                var s = cardRoot.lastModifiedDate;
                var parts = s.split(",");
                if (parts.length >= 4) {
                    return {
                        base: parts[0].trim() + ", " + parts[1].trim()
                        ,
                        extra: parts[2].trim()
                        ,
                        time: parts[3].trim()
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
                        font.weight: animWeight
                        font.pixelSize: 10
                        property int animWeight: 600

                        Behavior on animWeight {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Connections {
                            target: dateBadge
                            function onHoveredChanged() {
                                baseText.animWeight = dateBadge.hovered ? 500 : 600;
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

    width: 270
    height: 168

    readonly property bool hovered: mouseArea.containsMouse

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    Rectangle {
        id: backCard

        x: 15
        y: 35
        width: 177
        height: 101

        radius: 9
        color: "#151515"
        border.color: "#242424"
        border.width: 1

        rotation: root.hovered ? -6 : -9

        Behavior on rotation {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: backPalette

            x: 9
            y: 8

            width: 34
            height: 4

            radius: 2
            color: root.hovered ? "#303030" : "#262626"

            scale: root.hovered ? 1.05 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutBack
                }
            }
        }
    }


    Rectangle {
        id: middleCard

        x: 57
        y: 14
        width: 158
        height: 98

        radius: 9
        color: "#181818"
        border.color: "#292929"
        border.width: 1

        rotation: root.hovered ? 1.3 : 3

        Behavior on rotation {
            NumberAnimation {
                duration: 430
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: middlePalette

            x: 9
            y: 8

            width: 34
            height: 4

            radius: 2
            color: root.hovered ? "#353535" : "#292929"

            scale: root.hovered ? 1.06 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 370
                    easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            id: middleTimeline

            x: 10
            y: 57

            width: parent.width - 20
            height: 28

            radius: 6
            color: "#202020"

            scale: root.hovered ? 1.015 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutBack
                }
            }

            Rectangle {
                x: 4
                y: 5

                width: 29
                height: 8

                radius: 3

                color: "#333333"
            }

            Rectangle {
                x: 36
                y: 5

                width: 21
                height: 8

                radius: 3

                color: "#2c2c2c"
            }

            Rectangle {
                x: 60
                y: 5

                width: 33
                height: 8

                radius: 3

                color: "#373737"
            }

            Rectangle {
                x: 4
                y: 17

                width: 42
                height: 5

                radius: 2.5

                color: "#292929"
            }

            Rectangle {
                x: 49
                y: 17

                width: 27
                height: 5

                radius: 2.5

                color: "#252525"
            }

            Rectangle {
                id: middlePlayhead

                x: 57
                y: 2

                width: 1
                height: 24

                color: root.hovered ? "#626262" : "#454545"

                scale: root.hovered ? 1.12 : 1

                transformOrigin: Item.Top

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top

                    width: 5
                    height: 4

                    radius: 2

                    color: root.hovered ? "#6d6d6d" : "#4a4a4a"
                }
            }
        }
    }


    Rectangle {
        id: frontCard

        x: 92
        y: 48
        width: 158
        height: 105

        radius: 9
        color: "#1c1c1c"
        border.color: "#2a2a2a"
        border.width: 1

        rotation: root.hovered ? -1.1 : -3

        Behavior on rotation {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: frontPalette

            x: 9
            y: 8

            width: 34
            height: 4

            radius: 2

            color: root.hovered ? "#3a3a3a" : "#2b2b2b"

            scale: root.hovered ? 1.07 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            id: frontTimeline

            x: 10
            y: 58

            width: parent.width - 20
            height: 31

            radius: 6

            color: "#202020"

            scale: root.hovered ? 1.018 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 330
                    easing.type: Easing.OutBack
                }
            }

            Rectangle {
                x: 4
                y: 5

                width: 27
                height: 9

                radius: 3

                color: "#303030"
            }

            Rectangle {
                x: 34
                y: 5

                width: 21
                height: 9

                radius: 3

                color: "#393939"
            }

            Rectangle {
                x: 58
                y: 5

                width: 34
                height: 9

                radius: 3

                color: "#2d2d2d"
            }

            Rectangle {
                x: 95
                y: 5

                width: 24
                height: 9

                radius: 3

                color: "#363636"
            }

            Rectangle {
                x: 4
                y: 19

                width: 47
                height: 5

                radius: 2.5

                color: "#2a2a2a"
            }

            Rectangle {
                x: 55
                y: 19

                width: 31
                height: 5

                radius: 2.5

                color: "#242424"
            }

            Rectangle {
                x: 90
                y: 19

                width: 28
                height: 5

                radius: 2.5

                color: "#292929"
            }

            Rectangle {
                id: frontPlayhead

                x: 65
                y: 1

                width: 1
                height: 28

                color: root.hovered ? "#777777" : "#494949"

                scale: root.hovered ? 1.35 : 1

                transformOrigin: Item.Top

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }

                Rectangle {
                    id: frontPlayheadHead

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top

                    width: root.hovered ? 6.5 : 6
                    height: root.hovered ? 4.5 : 4

                    radius: 2

                    color: root.hovered ? "#888888" : "#555555"

                    Behavior on width {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                        }
                    }

                    SequentialAnimation {
                        running: root.hovered
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: frontPlayheadHead
                            property: "scale"
                            to: 1.01
                            duration: 500
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            target: frontPlayheadHead
                            property: "scale"
                            to: 1
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        running: root.hovered
        loops: Animation.Infinite

        NumberAnimation {
            target: middlePlayhead
            property: "x"
            to: 68
            duration: 1200
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: 300
        }

        NumberAnimation {
            target: middlePlayhead
            property: "x"
            to: 48
            duration: 1100
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: 300
        }
    }

    SequentialAnimation {
        running: root.hovered
        loops: Animation.Infinite

        NumberAnimation {
            target: frontPlayhead
            property: "x"
            to: 80
            duration: 15300
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: 320
        }

        NumberAnimation {
            target: frontPlayhead
            property: "x"
            to: 35
            duration: 2200
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: 320
        }
    }
}

}
