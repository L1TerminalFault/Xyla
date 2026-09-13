import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Rectangle {
    id: footerRoot

    property bool isCurrentlyPlaying: false
    property int currentFrame: 0
    property int totalFrames: 0
    property real activeFps: 30.0

    property int inPoint: 0
    property int outPoint: Math.max(0, totalFrames - 1)

    signal seekRequested(int frame)
    signal stepBackward
    signal togglePlay
    signal stepForward
    signal insertRequested
    signal overwriteRequested

    height: 52
    color: "#131315"

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#202024"
    }

    onTotalFramesChanged: {
        if (outPoint <= 0 || outPoint >= totalFrames - 2) {
            outPoint = Math.max(0, totalFrames - 1);
        }
    }

    function markIn() {
        inPoint = Math.min(currentFrame, outPoint);
    }

    function markOut() {
        outPoint = Math.max(currentFrame, inPoint);
    }

    function jumpToIn() {
        seekRequested(inPoint);
    }

    function jumpToOut() {
        seekRequested(outPoint);
    }

    function formatSMPTE(frames, fps) {
        var f = (typeof frames === "number" && !isNaN(frames)) ? Math.max(0, Math.floor(frames)) : 0;
        var rate = (typeof fps === "number" && fps > 0) ? Math.round(fps) : 30;

        var frameNum = f % rate;
        var totalSecs = Math.floor(f / rate);
        var sec = totalSecs % 60;
        var min = Math.floor(totalSecs / 60) % 60;
        var hrs = Math.floor(totalSecs / 3600);

        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        return pad(hrs) + ":" + pad(min) + ":" + pad(sec) + ":" + pad(frameNum);
    }

    Item {
        id: scrubArea
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: 12

        Rectangle {
            id: trackBg
            anchors.centerIn: parent
            width: parent.width - 24
            height: 4
            radius: 2
            color: "#1f1f24"

            readonly property real pxPerFrame: width / Math.max(1, footerRoot.totalFrames - 1)

            Rectangle {
                id: inOutRegion
                x: Math.max(0, footerRoot.inPoint * trackBg.pxPerFrame)
                width: Math.max(2, (footerRoot.outPoint - footerRoot.inPoint) * trackBg.pxPerFrame)
                height: parent.height
                radius: 1
                color: "#3a6fb0"
                opacity: 0.85

                Rectangle {
                    width: 2
                    height: 8
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#60a5fa"
                }

                Rectangle {
                    width: 2
                    height: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#60a5fa"
                }
            }

            Rectangle {
                id: playheadCursor
                x: Math.min(trackBg.width - 2, Math.max(0, footerRoot.currentFrame * trackBg.pxPerFrame)) - 1
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 10
                radius: 1.5
                color: "#ffffff"
                z: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function handleScrub(mouseX) {
                var localX = Math.max(0, Math.min(mouseX - 12, trackBg.width));
                var fraction = localX / Math.max(1, trackBg.width);
                var targetFrame = Math.round(fraction * Math.max(0, footerRoot.totalFrames - 1));
                footerRoot.seekRequested(targetFrame);
            }

            onPressed: function (mouse) {
                handleScrub(mouse.x);
            }
            onPositionChanged: function (mouse) {
                if (pressed)
                    handleScrub(mouse.x);
            }
        }
    }

    RowLayout {
        anchors.top: scrubArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 0

        Text {
            id: currentTimeText
            text: footerRoot.formatSMPTE(footerRoot.currentFrame, footerRoot.activeFps)
            color: "#ffffff"
            font.family: "JetBrains Mono, Roboto Mono, Consolas, monospace"
            font.pixelSize: 12
            font.weight: Font.Normal
            font.letterSpacing: 0.5
            font.features: {
                "tnum": 1
            }

            Layout.preferredWidth: 95
            Layout.minimumWidth: 95
            Layout.maximumWidth: 95
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }

        Row {
            spacing: 3
            Layout.alignment: Qt.AlignVCenter

            FooterIconButton {
                iconSource: "qrc:/assets/icons/player-skip-back.svg"
                toolTipText: "Jump to In (Shift+I)"
                onClicked: footerRoot.jumpToIn()
            }

            FooterIconButton {
                iconSource: "qrc:/assets/icons/arrow-bar-right.svg"
                toolTipText: "Mark In (I)"
                onClicked: footerRoot.markIn()
            }

            FooterIconButton {
                iconSource: "qrc:/assets/icons/arrow-bar-left.svg"
                toolTipText: "Mark Out (O)"
                onClicked: footerRoot.markOut()
            }

            FooterIconButton {
                iconSource: "qrc:/assets/icons/player-skip-forward.svg"
                toolTipText: "Jump to Out (Shift+O)"
                onClicked: footerRoot.jumpToOut()
            }

            SectionDivider {}

            FooterIconButton {
                iconSource: "qrc:/assets/icons/arrow-down-bar.svg"
                toolTipText: "Insert (,)"
                onClicked: footerRoot.insertRequested()
            }

            FooterIconButton {
                iconSource: "qrc:/assets/icons/arrow-down.svg"
                toolTipText: "Overwrite (.)"
                onClicked: footerRoot.overwriteRequested()
            }

            SectionDivider {}

            FooterIconButton {
                iconSource: "qrc:/assets/icons/player-track-prev.svg"
                toolTipText: "Previous Frame (Left)"
                onClicked: footerRoot.stepBackward()
            }

            FooterIconButton {
                iconSource: footerRoot.isCurrentlyPlaying ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
                activeState: footerRoot.isCurrentlyPlaying
                toolTipText: footerRoot.isCurrentlyPlaying ? "Stop (Space)" : "Play (Space)"
                onClicked: footerRoot.togglePlay()
            }

            FooterIconButton {
                iconSource: "qrc:/assets/icons/player-track-next.svg"
                toolTipText: "Next Frame (Right)"
                onClicked: footerRoot.stepForward()
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            id: durationText
            text: footerRoot.formatSMPTE(footerRoot.totalFrames, footerRoot.activeFps)
            color: "#6b6b72"
            font.family: "JetBrains Mono, Roboto Mono, Consolas, monospace"
            font.pixelSize: 12
            font.weight: Font.Normal
            font.letterSpacing: 0.5
            font.features: {
                "tnum": 1
            }

            Layout.preferredWidth: 95
            Layout.minimumWidth: 95
            Layout.maximumWidth: 95
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }

    component SectionDivider: Item {
        width: 10
        height: 14
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: 14
            color: "#25252b"
        }
    }

    component FooterIconButton: Rectangle {
        id: fBtn
        property string iconSource: ""
        property string toolTipText: ""
        property bool activeState: false
        property color activeColor: "#4daafc"
        property color normalColor: "#95959c"
        property color hoverColor: "#ffffff"
        signal clicked

        implicitWidth: 28
        implicitHeight: 24
        radius: 4
        color: btnMouse.pressed ? "#28282c" : (btnMouse.containsMouse ? "#1c1c20" : "transparent")

        Image {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: fBtn.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true

            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: fBtn.activeState ? fBtn.activeColor : (btnMouse.containsMouse ? fBtn.hoverColor : fBtn.normalColor)

                Behavior on colorizationColor {
                    ColorAnimation {
                        duration: 90
                    }
                }
            }
        }

        XylaToolTip {
            visible: btnMouse.containsMouse && fBtn.toolTipText !== ""
            text: fBtn.toolTipText
            position: "top"
            offset: 6
            delay: 400
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fBtn.clicked()
        }
    }
}
