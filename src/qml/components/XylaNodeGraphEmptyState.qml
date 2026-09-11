import QtQuick
import QtQuick.Controls

Item {
    id: nodeEmptyState

    anchors.centerIn: parent
    width: 380
    height: 270

    // Callback when user clicks to create a new graph
    signal createRequested()

    // Title and description can be customized if used for other states
    property string title: "Default In/Out Pipeline"
    property string description: "The base video pass-through is locked.\nCreate an editable node graph to build custom effects."
    property string buttonText: "Create Node Graph"

    // ============================================================
    // ILLUSTRATION: PURE QML NODE GRAPH MINI-PIPELINE
    // ============================================================

    Item {
        id: illustration

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: 190
        height: 125

        // Soft floating circular ambient glow behind the main node
        Rectangle {
            anchors.centerIn: mainNodeCard
            width: 110
            height: 110
            radius: 55
            color: "#181818"
            opacity: 0.8
        }

        // --------------------------------------------------------
        // BEZIER WIRE CONNECTION (CANVAS)
        // --------------------------------------------------------
        Canvas {
            anchors.fill: parent
            z: 1

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Wire 1: leftNode (x: 20, y: 55) -> mainNode (x: 65, y: 72)
                ctx.beginPath();
                ctx.moveTo(38, 55);
                ctx.bezierCurveTo(48, 55, 52, 72, 65, 72);
                ctx.strokeStyle = "#404040";
                ctx.lineWidth = 1.5;
                ctx.stroke();

                // Wire 2: mainNode (x: 147, y: 72) -> rightNode (x: 158, y: 45)
                ctx.beginPath();
                ctx.moveTo(147, 72);
                ctx.bezierCurveTo(152, 72, 154, 45, 158, 45);
                ctx.strokeStyle = "#404040";
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }

        // --------------------------------------------------------
        // FLOATING LEFT NODE (INPUT SOURCE)
        // --------------------------------------------------------
        Rectangle {
            id: leftNodeCard

            x: 10
            y: 35

            width: 44
            height: 40

            radius: 7
            color: "#242424"
            border.width: 1
            border.color: "#363636"

            rotation: -6

            // Header stripe
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 10
                radius: 6
                color: "#2E3A4E"
            }

            // Mock socket on right
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
        // MAIN CENTER NODE CARD
        // --------------------------------------------------------
        Item {
            id: mainNodeCard

            x: 65
            y: 30

            width: 82
            height: 68

            // Main body
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "#303030"
                border.width: 1
                border.color: "#464646"

                // Header bar
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 16
                    radius: 9
                    color: "#383838"

                    // Inner title bar line
                    Rectangle {
                        x: 8
                        y: 6
                        width: 32
                        height: 4
                        radius: 2
                        color: "#555555"
                    }
                }

                // Inner parameter card
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: 62
                    height: 32
                    radius: 6
                    color: "#252525"
                    border.width: 1
                    border.color: "#3A3A3A"

                    // Slider bar
                    Rectangle {
                        x: 7
                        y: 8
                        width: 48
                        height: 4
                        radius: 2
                        color: "#383838"

                        Rectangle {
                            width: 24
                            height: parent.height
                            radius: 2
                            color: "#4B5563"
                        }
                    }

                    // Dots row
                    Row {
                        x: 7
                        y: 18
                        spacing: 4

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: "#4B4B4B"
                            }
                        }
                    }
                }

                // Left socket (Input)
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: -3
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 6
                    width: 6
                    height: 6
                    radius: 3
                    color: "#60A5FA"
                    border.width: 1
                    border.color: "#303030"
                }

                // Right socket (Output)
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -3
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 6
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
        // FLOATING RIGHT NODE (OUTPUT SINK)
        // --------------------------------------------------------
        Rectangle {
            id: rightNodeCard

            x: 154
            y: 28

            width: 42
            height: 36

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
                height: 9
                radius: 6
                color: "#1E3A2F"
            }

            // Mock socket on left
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
        // LITTLE ACCENT DOTS
        // --------------------------------------------------------
        Rectangle {
            x: 18
            y: 92
            width: 8
            height: 8
            radius: 4
            color: "#454545"
        }

        Rectangle {
            x: 172
            y: 78
            width: 6
            height: 6
            radius: 3
            color: "#404040"
        }
    }

    // ============================================================
    // TYPOGRAPHY & CALL TO ACTION
    // ============================================================

    Column {
        anchors.top: illustration.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: nodeEmptyState.title
            color: "#DDDDDD"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: nodeEmptyState.description
            color: "#777777"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.3
        }

        Item { width: 1; height: 4 }

        // Sleek Action Button
        // Sleek Action Button in Dark Grey Theme
Button {
    id: actionBtn
    anchors.horizontalCenter: parent.horizontalCenter
    implicitHeight: 32
    implicitWidth: btnContentRow.implicitWidth + 28

    background: Rectangle {
        radius: 8
        color: actionBtn.pressed ? "#202022" : (actionBtn.hovered ? "#2C2C2E" : "#242426")
        border.color: actionBtn.hovered ? "#48484B" : "#363638"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

    contentItem: Item {
        // Use an Item wrapper to safely center the Row inside the button's content area
        Row {
            id: btnContentRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "+"
                color: actionBtn.hovered ? "#FFFFFF" : "#DDDDDD"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: nodeEmptyState.buttonText
                color: actionBtn.hovered ? "#FFFFFF" : "#D4D4D8"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    onClicked: {
        nodeEmptyState.createRequested();
    }
}
    }
}
