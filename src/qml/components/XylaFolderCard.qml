import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

ItemDelegate {
    id: control

    property string folderName: "Onboarding"
    property string folderPath: ""
    property int fileCount: 15
    property bool selected: false

    property bool isFolder: true
    property string fileExtension: ""
    property real fileSize: 0

    implicitWidth: 180
    implicitHeight: 210

    background: Rectangle {
        color: control.down ? "#141414" : control.hovered ? "#222222" : "#181818"

        border.color: control.selected ? "#2555D3" : "#2a2a2a"
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

        // Icons start here

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: "#121212"
                radius: 12
            }

            // ========================================================
            // FOLDER
            // ========================================================

            Item {
                anchors.fill: parent
                visible: control.isFolder

                // Back documents
                Rectangle {
                    width: parent.width * 0.42
                    height: parent.height * 0.60
                    radius: 6
                    color: "#b0b0b0"
                    x: parent.width * 0.48
                    y: 16
                    rotation: 10
                }

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

                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 10
                //
                //     spacing: -6
                //     z: 10
                //
                //     Rectangle {
                //         width: 22
                //         height: 22
                //         radius: 11
                //
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Image {
                //             anchors.centerIn: parent
                //
                //             source: "qrc:/assets/icons/folder.svg"
                //
                //             sourceSize.width: 12
                //             sourceSize.height: 12
                //         }
                //     }
                //
                //     Rectangle {
                //         width: 22
                //         height: 22
                //         radius: 11
                //
                //         color: "#181818"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Text {
                //             anchors.centerIn: parent
                //
                //             text: "N"
                //
                //             color: "#ffffff"
                //             font.pixelSize: 10
                //             font.bold: true
                //         }
                //     }
                // }
            }

            // ========================================================
            // FILES
            // ========================================================

            Item {
                anchors.fill: parent
                visible: ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg"].includes(control.fileExtension.toLowerCase())

                // Soft ambient glow behind everything
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.6
                }

                // ===== BACK POLAROID =====
                Rectangle {
                    width: parent.width * 0.58
                    height: parent.height * 0.68
                    radius: 8
                    color: "#d0d0d0"
                    x: parent.width * 0.32
                    y: parent.height * 0.18
                    rotation: 9

                    // photo area
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 7
                        anchors.bottomMargin: 18
                        radius: 4
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: "#b8c8d4"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#8fa4b3"
                            }
                        }
                    }
                }

                // ===== FRONT POLAROID =====
                Rectangle {
                    width: parent.width * 0.60
                    height: parent.height * 0.70
                    radius: 8
                    color: "#f4f4f4"
                    x: parent.width * 0.12
                    y: parent.height * 0.14
                    rotation: -5

                    // actual photo
                    Rectangle {
                        id: photo
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.bottomMargin: 20
                        radius: 5
                        clip: true

                        // sky
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: "#7eb6d9"
                                }
                                GradientStop {
                                    position: 0.55
                                    color: "#a8d0e8"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#c8e0f0"
                                }
                            }
                        }

                        // mountains
                        // Shape {
                        //     anchors.fill: parent
                        //     ShapePath {
                        //         fillColor: "#5a7a68"
                        //         strokeWidth: 0
                        //         startX: 0
                        //         startY: parent.height
                        //         PathLine { x: parent.width * 0.28; y: parent.height * 0.48 }
                        //         PathLine { x: parent.width * 0.48; y: parent.height * 0.62 }
                        //         PathLine { x: parent.width * 0.72; y: parent.height * 0.38 }
                        //         PathLine { x: parent.width; y: parent.height * 0.58 }
                        //         PathLine { x: parent.width; y: parent.height }
                        //         PathLine { x: 0; y: parent.height }
                        //     }
                        // }

                        // sun
                        Rectangle {
                            width: 13
                            height: 13
                            radius: 6.5
                            color: "#f0c95a"
                            x: parent.width - 26
                            y: 11
                        }
                    }

                    // bottom caption bar of polaroid
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 18
                        color: "#f4f4f4"
                        radius: 8

                        // tiny text lines
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                width: 18
                                height: 2
                                radius: 1
                                color: "#ccc"
                            }
                            Rectangle {
                                width: 12
                                height: 2
                                radius: 1
                                color: "#ccc"
                            }
                        }
                    }
                }

                // ===== BADGES =====
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/image.svg"
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Text {
                //             anchors.centerIn: parent
                //             text: "IMG"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["mp4", "mov", "avi", "mkv", "webm", "m4v"].includes(control.fileExtension.toLowerCase())

                // Soft ambient glow
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.7
                }

                // ===== BACK FRAME =====
                Rectangle {
                    width: parent.width * 0.58
                    height: parent.height * 0.62
                    radius: 9
                    color: "#1e1e1e"
                    x: parent.width * 0.30
                    y: parent.height * 0.20
                    rotation: 8
                    border.color: "#333"
                    border.width: 1

                    // film perforations
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 6
                        spacing: 5
                        Repeater {
                            model: 6
                            Rectangle {
                                width: 3.5
                                height: 3.5
                                radius: 1
                                color: "#3a3a3a"
                            }
                        }
                    }
                }

                // ===== FRONT FRAME =====
                Rectangle {
                    width: parent.width * 0.62
                    height: parent.height * 0.66
                    radius: 9
                    color: "#111111"
                    x: parent.width * 0.12
                    y: parent.height * 0.15
                    rotation: -4
                    border.color: "#2a2a2a"
                    border.width: 1

                    // subtle inner screen
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 5
                        color: "#0a0a0a"

                        // very soft vignette / gradient
                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: "#151515"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#0a0a0a"
                                }
                            }
                        }
                    }

                    // Play button
                    Item {
                        anchors.centerIn: parent
                        width: 32
                        height: 32

                        // soft halo
                        Rectangle {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            radius: 18
                            color: "#ffffff"
                            opacity: 0.08
                        }

                        // main circle
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: "#ffffff"
                            opacity: 0.15
                        }

                        // triangle
                        Shape {
                            anchors.centerIn: parent
                            width: 14
                            height: 16
                            ShapePath {
                                fillColor: "#ffffff"
                                strokeWidth: 0
                                startX: 3
                                startY: 1
                                PathLine {
                                    x: 3
                                    y: 15
                                }
                                PathLine {
                                    x: 13
                                    y: 8
                                }
                                PathLine {
                                    x: 3
                                    y: 1
                                }
                            }
                        }
                    }

                    // tiny progress bar at bottom of screen
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 11
                        height: 2
                        radius: 1
                        color: "#333"

                        Rectangle {
                            width: parent.width * 0.35
                            height: parent.height
                            radius: 1
                            color: "#6a9eff"
                        }
                    }
                }

                // ===== BADGES =====
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/video.svg"
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"
                //         border.width: 2
                //
                //         Text {
                //             anchors.centerIn: parent
                //             text: "VID"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["mp3", "wav", "flac", "ogg", "aac", "m4a", "opus"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.65
                }

                // Back disc
                Rectangle {
                    width: parent.width * 0.52
                    height: parent.height * 0.52
                    radius: width / 2
                    color: "#2a2a2a"
                    x: parent.width * 0.36
                    y: parent.height * 0.22
                    rotation: 12
                    border.color: "#3a3a3a"
                    border.width: 1
                }

                // Front disc
                Rectangle {
                    width: parent.width * 0.56
                    height: parent.height * 0.56
                    radius: width / 2
                    color: "#181818"
                    x: parent.width * 0.14
                    y: parent.height * 0.18
                    rotation: -6
                    border.color: "#2f2f2f"
                    border.width: 1

                    // vinyl grooves
                    Repeater {
                        model: 4
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * (0.75 - index * 0.12)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: "#252525"
                            border.width: 1.5
                        }
                    }

                    // center label
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: "#6a9eff"
                    }
                }

                // Waveform bars
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * 0.22
                    spacing: 3
                    Repeater {
                        model: [0.4, 0.7, 1.0, 0.6, 0.85, 0.5, 0.9]
                        Rectangle {
                            width: 3
                            height: 16 * modelData
                            radius: 1.5
                            color: "#6a9eff"
                            anchors.bottom: parent.bottom
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/music.svg"
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "AUD"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["pdf"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.6
                }

                // Back page
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height * 0.64
                    radius: 6
                    color: "#d8d8d8"
                    x: parent.width * 0.38
                    y: parent.height * 0.16
                    rotation: 8
                }

                // Front page
                Rectangle {
                    width: parent.width * 0.50
                    height: parent.height * 0.66
                    radius: 6
                    color: "#ffffff"
                    x: parent.width * 0.16
                    y: parent.height * 0.14
                    rotation: -4

                    // red header bar
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 18
                        radius: 6
                        color: "#e53935"

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 8
                            color: "#e53935"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "PDF"
                            color: "#ffffff"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    // text lines
                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Repeater {
                            model: 5
                            Rectangle {
                                width: index % 2 === 0 ? 28 : 22
                                height: 2.5
                                radius: 1
                                color: "#ddd"
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "P"
                //             color: "#e53935"
                //             font.pixelSize: 12
                //             font.bold: true
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "PDF"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["doc", "docx", "odt", "rtf"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.6
                }

                // Back page
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height * 0.64
                    radius: 6
                    color: "#c8d4e8"
                    x: parent.width * 0.38
                    y: parent.height * 0.16
                    rotation: 7
                }

                // Front page
                Rectangle {
                    width: parent.width * 0.50
                    height: parent.height * 0.66
                    radius: 6
                    color: "#ffffff"
                    x: parent.width * 0.16
                    y: parent.height * 0.14
                    rotation: -5

                    // blue accent bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 6
                        radius: 6
                        color: "#2b579a"
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 6
                        Rectangle {
                            width: 26
                            height: 3
                            radius: 1.5
                            color: "#2b579a"
                        }
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 24 - index * 2
                                height: 2
                                radius: 1
                                color: "#ddd"
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "W"
                //             color: "#2b579a"
                //             font.pixelSize: 12
                //             font.bold: true
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "DOC"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["xls", "xlsx", "csv", "ods"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.6
                }

                // Back sheet
                Rectangle {
                    width: parent.width * 0.50
                    height: parent.height * 0.58
                    radius: 6
                    color: "#c8e0c8"
                    x: parent.width * 0.36
                    y: parent.height * 0.18
                    rotation: 8
                }

                // Front sheet
                Rectangle {
                    width: parent.width * 0.52
                    height: parent.height * 0.60
                    radius: 6
                    color: "#ffffff"
                    x: parent.width * 0.14
                    y: parent.height * 0.16
                    rotation: -4

                    // green header
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 14
                        radius: 6
                        color: "#217346"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 6
                            color: "#217346"
                        }
                    }

                    // grid
                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Repeater {
                            model: 4
                            Row {
                                spacing: 0
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: 14
                                        height: 10
                                        color: "transparent"
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                    }
                                }
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "X"
                //             color: "#217346"
                //             font.pixelSize: 12
                //             font.bold: true
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "XLS"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["ppt", "pptx", "odp"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.6
                }

                // Back slide
                Rectangle {
                    width: parent.width * 0.52
                    height: parent.height * 0.40
                    radius: 5
                    color: "#e8d0b0"
                    x: parent.width * 0.34
                    y: parent.height * 0.28
                    rotation: 9
                }

                // Front slide
                Rectangle {
                    width: parent.width * 0.56
                    height: parent.height * 0.42
                    radius: 5
                    color: "#ffffff"
                    x: parent.width * 0.14
                    y: parent.height * 0.24
                    rotation: -5

                    // orange accent
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 5
                        radius: 5
                        color: "#c43e1c"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            width: 28
                            height: 3
                            radius: 1.5
                            color: "#c43e1c"
                        }
                        Rectangle {
                            width: 22
                            height: 2
                            radius: 1
                            color: "#ddd"
                        }
                        Rectangle {
                            width: 18
                            height: 2
                            radius: 1
                            color: "#ddd"
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "P"
                //             color: "#c43e1c"
                //             font.pixelSize: 12
                //             font.bold: true
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "PPT"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["zip", "rar", "7z", "tar", "gz"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.65
                }

                // Back box
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height * 0.50
                    radius: 6
                    color: "#3a3228"
                    x: parent.width * 0.38
                    y: parent.height * 0.24
                    rotation: 8
                }

                // Front box
                Rectangle {
                    width: parent.width * 0.52
                    height: parent.height * 0.54
                    radius: 6
                    color: "#4a3f32"
                    x: parent.width * 0.16
                    y: parent.height * 0.20
                    rotation: -4

                    // lid line
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 14
                        radius: 6
                        color: "#5c4f3e"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 6
                            color: "#5c4f3e"
                        }
                    }

                    // zipper
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        width: 4
                        height: parent.height * 0.45
                        radius: 2
                        color: "#c9a227"
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/archive.svg"   // or zip icon
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "ZIP"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["js", "qml", "cpp", "hpp", "h", "c", "py", "java", "rs"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.7
                }

                // Back terminal
                Rectangle {
                    width: parent.width * 0.54
                    height: parent.height * 0.48
                    radius: 7
                    color: "#1e1e1e"
                    x: parent.width * 0.34
                    y: parent.height * 0.26
                    rotation: 7
                    border.color: "#333"
                    border.width: 1
                }

                // Front terminal
                Rectangle {
                    width: parent.width * 0.58
                    height: parent.height * 0.52
                    radius: 7
                    color: "#121212"
                    x: parent.width * 0.12
                    y: parent.height * 0.20
                    rotation: -4
                    border.color: "#2a2a2a"
                    border.width: 1

                    // title bar dots
                    Row {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        spacing: 4
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#ff5f56"
                        }
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#ffbd2e"
                        }
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#27c93f"
                        }
                    }

                    // code lines
                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        spacing: 5
                        Row {
                            spacing: 4
                            Rectangle {
                                width: 10
                                height: 2.5
                                radius: 1
                                color: "#c678dd"
                            }
                            Rectangle {
                                width: 18
                                height: 2.5
                                radius: 1
                                color: "#61afef"
                            }
                        }
                        Row {
                            spacing: 4
                            Rectangle {
                                width: 8
                                height: 2.5
                                radius: 1
                                color: "#e5c07b"
                            }
                            Rectangle {
                                width: 22
                                height: 2.5
                                radius: 1
                                color: "#98c379"
                            }
                        }
                        Row {
                            spacing: 4
                            Rectangle {
                                width: 14
                                height: 2.5
                                radius: 1
                                color: "#56b6c2"
                            }
                            Rectangle {
                                width: 12
                                height: 2.5
                                radius: 1
                                color: "#e06c75"
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "</>"
                //             color: "#61afef"
                //             font.pixelSize: 9
                //             font.bold: true
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "CODE"
                //             color: "#ffffff"
                //             font.pixelSize: 7
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: ["txt", "md", "log"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.55
                }

                // Back page
                Rectangle {
                    width: parent.width * 0.46
                    height: parent.height * 0.62
                    radius: 5
                    color: "#e0e0e0"
                    x: parent.width * 0.38
                    y: parent.height * 0.16
                    rotation: 6
                }

                // Front page
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height * 0.64
                    radius: 5
                    color: "#f8f8f8"
                    x: parent.width * 0.16
                    y: parent.height * 0.14
                    rotation: -4

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Repeater {
                            model: 6
                            Rectangle {
                                width: index === 0 ? 26 : (index % 2 === 0 ? 24 : 18)
                                height: 2
                                radius: 1
                                color: "#ccc"
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/file-text.svg"
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "TXT"
                //             color: "#ffffff"
                //             font.pixelSize: 8
                //             font.bold: true
                //         }
                //     }
                // }
            }

            Item {
                anchors.fill: parent
                visible: !control.isFolder && !["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "mp4", "mkv", "avi", "mov", "webm", "m4v", "mp3", "wav", "flac", "ogg", "aac", "m4a", "opus", "pdf", "doc", "docx", "odt", "rtf", "xls", "xlsx", "csv", "ods", "ppt", "pptx", "odp", "zip", "rar", "7z", "tar", "gz", "js", "qml", "cpp", "hpp", "h", "c", "py", "java", "rs", "txt", "md", "log"].includes(control.fileExtension.toLowerCase())

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: parent.height * 0.78
                    radius: 18
                    color: "#1a1a1a"
                    opacity: 0.5
                }

                // Back page
                Rectangle {
                    width: parent.width * 0.46
                    height: parent.height * 0.60
                    radius: 5
                    color: "#3a3a3a"
                    x: parent.width * 0.38
                    y: parent.height * 0.18
                    rotation: 7
                }

                // Front page
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height * 0.62
                    radius: 5
                    color: "#2c2c2f"
                    x: parent.width * 0.16
                    y: parent.height * 0.16
                    rotation: -4

                    // folded corner
                    Shape {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 16
                        height: 16
                        ShapePath {
                            fillColor: "#3a3a3e"
                            strokeWidth: 0
                            startX: 0
                            startY: 0
                            PathLine {
                                x: 16
                                y: 0
                            }
                            PathLine {
                                x: 16
                                y: 16
                            }
                            PathLine {
                                x: 0
                                y: 0
                            }
                        }
                    }
                }

                // Badges
                // Row {
                //     anchors.left: parent.left
                //     anchors.bottom: parent.bottom
                //     anchors.margins: 12
                //     spacing: -6
                //     z: 10
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#ffffff"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Image {
                //             anchors.centerIn: parent
                //             source: "qrc:/assets/icons/file.svg"
                //             sourceSize: Qt.size(12, 12)
                //         }
                //     }
                //     Rectangle {
                //         width: 22; height: 22; radius: 11
                //         color: "#181818"
                //         border.color: "#2c2c2f"; border.width: 2
                //         Text {
                //             anchors.centerIn: parent
                //             text: "FILE"
                //             color: "#ffffff"
                //             font.pixelSize: 7
                //             font.bold: true
                //         }
                //     }
                // }
            }
        }

        // ============================================================
        // TITLE / INFORMATION
        // ============================================================

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true

                text: control.folderName

                color: "#ffffff"

                font.pixelSize: 13
                font.bold: true

                horizontalAlignment: Text.AlignHCenter

                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true

                text: control.isFolder ? control.fileCount + " Files" : control.formattedSize

                color: "#888888"

                font.pixelSize: 11

                horizontalAlignment: Text.AlignHCenter

                elide: Text.ElideRight
            }
        }
    }

    property string formattedSize: {
        var size = control.fileSize;

        if (size < 1024)
            return size + " B";

        if (size < 1024 * 1024)
            return (size / 1024).toFixed(1) + " KB";

        if (size < 1024 * 1024 * 1024)
            return (size / (1024 * 1024)).toFixed(1) + " MB";

        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }
}
