import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

ItemDelegate {
    id: control

    property string folderName: "Onboarding"
    property string folderPath: ""
    property int fileCount: 15

    implicitWidth: 180
    implicitHeight: 210

    background: Rectangle {
        color: control.down ? "#141414" : (control.hovered ? "#222222" : "#181818")
        border.color: control.hovered ? "#2555D3" : "#2a2a2a"
        border.width: 1
        radius: 16

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
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Folder Visual Artwork
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Dark Recess Background
            Rectangle {
                anchors.fill: parent
                color: "#121212"
                radius: 12
            }

            // Document 1 (Back Right)
            Rectangle {
                width: parent.width * 0.42
                height: parent.height * 0.60
                radius: 6
                color: "#b0b0b0"
                x: parent.width * 0.48
                y: 16
                rotation: 10
            }

            // Document 2 (Back Middle - PDF)
            Rectangle {
                width: parent.width * 0.45
                height: parent.height * 0.65
                radius: 6
                color: "#e0e0e0"
                x: parent.width * 0.28
                y: 10
                rotation: 3

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 14
                    color: "#cc0000"
                    radius: 3
                    Text {
                        anchors.centerIn: parent
                        text: "PDF"
                        color: "#ffffff"
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
            }

            // Document 3 (Back Left)
            Rectangle {
                width: parent.width * 0.42
                height: parent.height * 0.60
                radius: 6
                color: "#ffffff"
                x: parent.width * 0.10
                y: 14
                rotation: -6

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle {
                        width: 24
                        height: 2
                        color: "#cccccc"
                    }
                    Rectangle {
                        width: 18
                        height: 2
                        color: "#cccccc"
                    }
                    Rectangle {
                        width: 22
                        height: 2
                        color: "#cccccc"
                    }
                }
            }

            // Custom Vector Folder Cover Shape
            Shape {
                id: folderCover
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: "#2c2c2f"
                    strokeColor: "#3a3a3e"
                    strokeWidth: 1

                    startX: 0
                    startY: 32

                    PathLine {
                        x: 0
                        y: folderCover.height - 8
                    }
                    PathQuad {
                        x: 8
                        y: folderCover.height
                        controlX: 0
                        controlY: folderCover.height
                    }
                    PathLine {
                        x: folderCover.width - 8
                        y: folderCover.height
                    }
                    PathQuad {
                        x: folderCover.width
                        y: folderCover.height - 8
                        controlX: folderCover.width
                        controlY: folderCover.height
                    }
                    PathLine {
                        x: folderCover.width
                        y: 44
                    }
                    PathQuad {
                        x: folderCover.width - 6
                        y: 38
                        controlX: folderCover.width
                        controlY: 38
                    }
                    PathLine {
                        x: folderCover.width * 0.62
                        y: 38
                    }

                    PathCubic {
                        x: folderCover.width * 0.48
                        y: 26
                        control1X: folderCover.width * 0.58
                        control1Y: 38
                        control2X: folderCover.width * 0.54
                        control2Y: 26
                    }

                    PathLine {
                        x: 8
                        y: 26
                    }
                    PathQuad {
                        x: 0
                        y: 32
                        controlX: 0
                        controlY: 26
                    }
                }
            }

            // Badges on Front Cover
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10
                spacing: -6
                z: 10

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#ffffff"
                    border.color: "#2c2c2f"
                    border.width: 2

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/assets/icons/folder.svg"
                        sourceSize.width: 12
                        sourceSize.height: 12
                    }
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#181818"
                    border.color: "#2c2c2f"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "N"
                        color: "#ffffff"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }

        // Folder Title & File Count
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: control.folderName
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: control.fileCount + " Files"
                color: "#888888"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
