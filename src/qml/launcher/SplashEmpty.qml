import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtQml.Models

Item {
    id: emptyState

    width: 220
    height: 165

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 12

Item {
    id: illustration

    // anchors.horizontalCenter: parent.horizontalCenter
    // anchors.top: parent.top

    width: 190
    height: 125

    // --------------------------------------------------------
    // SOFT AMBIENT GLOW
    // --------------------------------------------------------
    Rectangle {
        anchors.centerIn: projectCard
        width: 112
        height: 112
        radius: 56
        color: "#181818"
        opacity: 0.8
    }

    // --------------------------------------------------------
    // SUBTLE FLOATING CONNECTION / TIMELINE LINES
    // --------------------------------------------------------
    Canvas {
        anchors.fill: parent
        z: 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Left media card -> project
            ctx.beginPath();
            ctx.moveTo(45, 58);
            ctx.bezierCurveTo(53, 58, 55, 64, 64, 66);
            ctx.strokeStyle = "#3B3B3B";
            ctx.lineWidth = 1.5;
            ctx.stroke();

            // Project -> right media card
            ctx.beginPath();
            ctx.moveTo(145, 66);
            ctx.bezierCurveTo(153, 65, 155, 54, 161, 52);
            ctx.strokeStyle = "#3B3B3B";
            ctx.lineWidth = 1.5;
            ctx.stroke();

            // Small timeline line underneath
            ctx.beginPath();
            ctx.moveTo(57, 92);
            ctx.lineTo(136, 92);
            ctx.strokeStyle = "#303030";
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    // --------------------------------------------------------
    // FLOATING LEFT MEDIA CLIP
    // --------------------------------------------------------
    Rectangle {
        id: leftMediaCard

        x: 12
        y: 39

        width: 42
        height: 34

        radius: 7
        color: "#242424"
        border.width: 1
        border.color: "#363636"

        rotation: -7

        // Video thumbnail area
        Rectangle {
            x: 5
            y: 5
            width: 32
            height: 18

            radius: 4
            color: "#2E3A4E"

            // Tiny play triangle
            Canvas {
                anchors.centerIn: parent
                width: 10
                height: 10

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.beginPath();
                    ctx.moveTo(3, 2);
                    ctx.lineTo(8, 5);
                    ctx.lineTo(3, 8);
                    ctx.closePath();

                    ctx.fillStyle = "#60A5FA";
                    ctx.fill();
                }
            }
        }

        // Clip metadata
        Rectangle {
            x: 6
            y: 27
            width: 18
            height: 3
            radius: 1.5
            color: "#464646"
        }

        Rectangle {
            x: 28
            y: 27
            width: 7
            height: 3
            radius: 1.5
            color: "#383838"
        }

        // Media socket
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -3
            anchors.verticalCenter: parent.verticalCenter

            width: 6
            height: 6
            radius: 3

            color: "#60A5FA"

            border.width: 1
            border.color: "#242424"
        }
    }

    // --------------------------------------------------------
    // MAIN PROJECT CARD
    // --------------------------------------------------------
    Item {
        id: projectCard

        x: 61
        y: 25

        width: 84
        height: 70

        // ----------------------------------------------------
        // PROJECT WINDOW
        // ----------------------------------------------------
        Rectangle {
            anchors.fill: parent

            radius: 10
            color: "#303030"

            border.width: 1
            border.color: "#464646"

            // ------------------------------------------------
            // WINDOW HEADER
            // ------------------------------------------------
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                height: 17

                radius: 9
                color: "#383838"

                // Window title
                Rectangle {
                    x: 9
                    y: 6

                    width: 27
                    height: 4

                    radius: 2
                    color: "#555555"
                }

                // Small window controls
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 3

                    Repeater {
                        model: 2

                        delegate: Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: "#4A4A4A"
                        }
                    }
                }
            }

            // ------------------------------------------------
            // EMPTY PREVIEW AREA
            // ------------------------------------------------
            Rectangle {
                x: 7
                y: 23

                width: 70
                height: 28

                radius: 6
                color: "#252525"

                border.width: 1
                border.color: "#3A3A3A"

                // Center play / add-project mark
                Rectangle {
                    anchors.centerIn: parent

                    width: 18
                    height: 18

                    radius: 9

                    color: "#303030"

                    border.width: 1
                    border.color: "#414141"

                    // Plus
                    Rectangle {
                        anchors.centerIn: parent

                        width: 7
                        height: 2

                        radius: 1
                        color: "#60A5FA"
                    }

                    Rectangle {
                        anchors.centerIn: parent

                        width: 2
                        height: 7

                        radius: 1
                        color: "#60A5FA"
                    }
                }

                // Tiny preview indicators
                Rectangle {
                    x: 7
                    y: 7

                    width: 3
                    height: 3

                    radius: 1.5
                    color: "#3D3D3D"
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    y: 7

                    width: 3
                    height: 3

                    radius: 1.5
                    color: "#3D3D3D"
                }
            }

            // ------------------------------------------------
            // EMPTY TIMELINE
            // ------------------------------------------------
            Rectangle {
                x: 7
                y: 56

                width: 70
                height: 8

                radius: 3

                color: "#272727"

                // Timeline track
                Rectangle {
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter

                    width: 60
                    height: 2

                    radius: 1
                    color: "#3B3B3B"
                }

                // Empty clip marker
                Rectangle {
                    x: 17
                    anchors.verticalCenter: parent.verticalCenter

                    width: 12
                    height: 4

                    radius: 2
                    color: "#343434"
                }

                Rectangle {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter

                    width: 8
                    height: 4

                    radius: 2
                    color: "#303030"
                }
            }

            // ------------------------------------------------
            // INPUT SOCKET
            // ------------------------------------------------
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: -3
                anchors.verticalCenter: parent.verticalCenter

                width: 6
                height: 6

                radius: 3

                color: "#60A5FA"

                border.width: 1
                border.color: "#303030"
            }

            // ------------------------------------------------
            // OUTPUT SOCKET
            // ------------------------------------------------
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -3
                anchors.verticalCenter: parent.verticalCenter

                width: 6
                height: 6

                radius: 3

                color: "#34D399"

                border.width: 1
                border.color: "#303030"
            }
        }
    }

    // --------------------------------------------------------
    // FLOATING RIGHT MEDIA / EXPORT CARD
    // --------------------------------------------------------
    Rectangle {
        id: rightMediaCard

        x: 153
        y: 31

        width: 39
        height: 32

        radius: 7

        color: "#292929"

        border.width: 1
        border.color: "#454545"

        rotation: 7

        // Header stripe
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            height: 8

            radius: 6

            color: "#1E3A2F"
        }

        // Small export/video bars
        Rectangle {
            x: 7
            y: 15

            width: 25
            height: 4

            radius: 2
            color: "#363636"
        }

        Rectangle {
            x: 7
            y: 22

            width: 17
            height: 3

            radius: 1.5
            color: "#333333"
        }

        // Green output indicator
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -3
            anchors.verticalCenter: parent.verticalCenter

            width: 6
            height: 6

            radius: 3

            color: "#34D399"

            border.width: 1
            border.color: "#292929"
        }
    }

    // --------------------------------------------------------
    // FLOATING TIMELINE BLOCK
    // --------------------------------------------------------
    Rectangle {
        x: 47
        y: 98

        width: 31
        height: 7

        radius: 3.5

        color: "#292929"
        border.width: 1
        border.color: "#393939"

        Rectangle {
            x: 5
            anchors.verticalCenter: parent.verticalCenter

            width: 9
            height: 3

            radius: 1.5
            color: "#3E3E3E"
        }

        Rectangle {
            x: 18
            anchors.verticalCenter: parent.verticalCenter

            width: 7
            height: 3

            radius: 1.5
            color: "#303030"
        }
    }

    // --------------------------------------------------------
    // LITTLE AMBIENT ACCENTS
    // --------------------------------------------------------
    Rectangle {
        x: 18
        y: 88

        width: 7
        height: 7

        radius: 3.5
        color: "#454545"
    }

    Rectangle {
        x: 165
        y: 79

        width: 6
        height: 6

        radius: 3
        color: "#404040"
    }

    Rectangle {
        x: 145
        y: 102

        width: 4
        height: 4

        radius: 2
        color: "#383838"
    }
}

        Text {
            width: 190

            text: "No recent projects"

            horizontalAlignment: Text.AlignHCenter

            color: "#A3A3A3"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
