import QtQuick
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
    
    // EXPLICIT HEIGHT: 5 (top margin) + 150 (image) + 70 (bottom row) + 5 (bottom margin) = 230
    // This prevents parent layouts from guessing the height and causing overflow.
    // implicitHeight: 230

    color: mouseArea.containsMouse ? "#181818" : "#0A0A0A" // "#181818"
    radius: 22
    clip: false

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }

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
        color: "#46000000"
    }

    MouseArea {
        id: mouseArea
        z: 0

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onClicked: cardRoot.clicked()
    }

    // CHANGED: Column to ColumnLayout for robust, bounded height distribution
    ColumnLayout {
        id: cardColumn

        // CHANGED: Strictly fill the parent bounds with margins, preventing any overflow
        anchors.fill: parent
        anchors.margins: 7
        z: 1

        spacing: 0

        Item {
            id: imageContainer

            // CHANGED: Use Layout properties. fillHeight allows it to "push" and shrink 
            // if the card is constrained, guaranteeing the bottom row always fits inside.
            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true

            Rectangle {
                anchors.fill: parent

                color: "#121213"
                radius: 15

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0

                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: imageContainer.width
                            height: imageContainer.height
                            radius: 15
                        }
                    }
                }

                Image {
                    anchors.fill: parent

                    fillMode: Image.PreserveAspectCrop

                    visible: cardRoot.thumbnail !== ""

                    source: cardRoot.thumbnail !== "" ? "image://thumbnails/" + cardRoot.thumbnail + "?width=120" : ""

                    asynchronous: true
                    cache: true
                }
            }
        }

        RowLayout {
            id: bottomRow

            Layout.fillWidth: true
            // Layout.preferredHeight: 50
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.topMargin: 7
            Layout.bottomMargin: 9

            spacing: 10

            Column {
                id: textColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                spacing: 3.5

                Text {
                    id: projectNameText

                    width: parent.width

                    text: cardRoot.projectName

                    color: "#e1e1e1"

                    font.family: "Inter"
                    font.pixelSize: 15

                    elide: Text.ElideRight
                }

                Text {
                    id: dateText

                    width: parent.width

                    text: cardRoot.lastModifiedDate

                    color: "#6e6e6e"

                    font.family: "Inter"
                    font.pixelSize: 9

                    elide: Text.ElideRight
                }
            }

            Item {
                id: info

                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: infoBg

                    anchors.fill: parent

                    radius: 10
                    color: "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2

                        fillMode: Image.PreserveAspectFit

                        source: "qrc:/assets/icons/info.svg"
                        sourceSize: Qt.size(30, 30)

                        opacity: infoMouse.containsMouse
                                 ? 1.0
                                 : 0.65

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }
                    }

                    XylaToolTip {
                        visible: infoMouse.containsMouse
                        text: cardRoot.projectPath.toString()
                        delay: 400
                    }
                }

                MouseArea {
                    id: infoMouse
                    z: 10

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        // Prevent the card click if necessary.
                    }
                }
            }
        }
    }

}
