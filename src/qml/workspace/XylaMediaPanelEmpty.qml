import QtQuick

Item {
    id: emptyState

    anchors.centerIn: parent

    width: 380
    height: 250

    // visible: listView.count === 0

    // ============================================================
    // ILLUSTRATION
    // ============================================================

    Item {
        id: illustration

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: 150
        height: 125

        // Soft floating glow
        Rectangle {
            anchors.centerIn: folderShape

            width: 100
            height: 100

            radius: 50

            color: "#181818"
            opacity: 0.8
        }

        // --------------------------------------------------------
        // BACK FILE
        // --------------------------------------------------------

        Rectangle {
            id: backFile

            x: 25
            y: 22

            width: 58
            height: 72

            radius: 9

            color: "#242424"
            border.width: 1
            border.color: "#363636"

            rotation: -8

            Rectangle {
                x: 11
                y: 19

                width: 30
                height: 4

                radius: 2
                color: "#404040"
            }

            Rectangle {
                x: 11
                y: 29

                width: 23
                height: 4

                radius: 2
                color: "#353535"
            }

            Rectangle {
                x: 11
                y: 39

                width: 27
                height: 4

                radius: 2
                color: "#353535"
            }
        }

        // --------------------------------------------------------
        // MAIN FOLDER
        // --------------------------------------------------------

        Item {
            id: folderShape

            x: 38
            y: 32

            width: 82
            height: 66

            // Folder tab
            Rectangle {
                x: 5
                y: 0

                width: 32
                height: 18

                radius: 6

                color: "#343434"
                border.width: 1
                border.color: "#454545"
            }

            // Folder body
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 55

                radius: 10

                color: "#303030"
                border.width: 1
                border.color: "#464646"

                // Inner empty area
                Rectangle {
                    anchors.centerIn: parent

                    width: 48
                    height: 32

                    radius: 7

                    color: "#252525"

                    border.width: 1
                    border.color: "#3a3a3a"

                    // Tiny empty-dots pattern
                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Repeater {
                            model: 3

                            delegate: Rectangle {
                                width: 5
                                height: 5

                                radius: 2.5
                                color: "#4b4b4b"
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------
        // FLOATING IMAGE CARD
        // --------------------------------------------------------

        Rectangle {
            id: imageCard

            x: 91
            y: 10

            width: 38
            height: 38

            radius: 9

            color: "#292929"
            border.width: 1
            border.color: "#454545"

            rotation: 8

            // Mountain/image icon drawn entirely in QML
            Item {
                anchors.centerIn: parent

                width: 23
                height: 23

                // Sun
                Rectangle {
                    x: 14
                    y: 3

                    width: 5
                    height: 5

                    radius: 2.5

                    color: "#777777"
                }

                // Mountain 1
                Canvas {
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d");

                        ctx.clearRect(0, 0, width, height);

                        ctx.beginPath();
                        ctx.moveTo(2, 19);
                        ctx.lineTo(9, 11);
                        ctx.lineTo(13, 15);
                        ctx.lineTo(17, 9);
                        ctx.lineTo(22, 19);
                        ctx.closePath();

                        ctx.fillStyle = "#696969";
                        ctx.fill();
                    }
                }
            }
        }

        // --------------------------------------------------------
        // FLOATING VIDEO CARD
        // --------------------------------------------------------

        Rectangle {
            id: videoCard

            x: 104
            y: 69

            width: 40
            height: 30

            radius: 8

            color: "#292929"
            border.width: 1
            border.color: "#454545"

            rotation: -5

            // Video play icon
            Canvas {
                anchors.centerIn: parent

                width: 14
                height: 14

                onPaint: {
                    var ctx = getContext("2d");

                    ctx.clearRect(0, 0, width, height);

                    ctx.beginPath();
                    ctx.moveTo(4, 2);
                    ctx.lineTo(12, 7);
                    ctx.lineTo(4, 12);
                    ctx.closePath();

                    ctx.fillStyle = "#777777";
                    ctx.fill();
                }
            }
        }

        // --------------------------------------------------------
        // LITTLE FILE DOT
        // --------------------------------------------------------

        Rectangle {
            x: 16
            y: 91

            width: 8
            height: 8

            radius: 4

            color: "#555555"
        }

        Rectangle {
            x: 131
            y: 48

            width: 6
            height: 6

            radius: 3

            color: "#505050"
        }
    }

    // ============================================================
    // TEXT
    // ============================================================

    Column {
        anchors.top: illustration.bottom
        anchors.topMargin: 5

        anchors.horizontalCenter: parent.horizontalCenter

        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: "This folder is empty"
            // text: "No media assets loaded"

            color: "#dddddd"

            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: "Drop your media here to get started"

            color: "#777777"

            font.pixelSize: 12

            horizontalAlignment: Text.AlignHCenter
        }

        // Supported media hint
        // Row {
        //     anchors.horizontalCenter: parent.horizontalCenter

        //     spacing: 12

        //     Item {
        //         width: 62
        //         height: 22

        //         Row {
        //             anchors.centerIn: parent
        //             spacing: 5

        //             // Image symbol
        //             Rectangle {
        //                 width: 16
        //                 height: 14

        //                 radius: 3

        //                 color: "#303030"
        //                 border.width: 1
        //                 border.color: "#454545"

        //                 Canvas {
        //                     anchors.fill: parent

        //                     onPaint: {
        //                         var ctx = getContext("2d");

        //                         ctx.clearRect(0, 0, width, height);

        //                         ctx.beginPath();
        //                         ctx.arc(11, 4, 2, 0, Math.PI * 2);

        //                         ctx.fillStyle = "#707070";
        //                         ctx.fill();

        //                         ctx.beginPath();
        //                         ctx.moveTo(2, 12);
        //                         ctx.lineTo(6, 8);
        //                         ctx.lineTo(9, 11);
        //                         ctx.lineTo(12, 7);
        //                         ctx.lineTo(15, 12);
        //                         ctx.closePath();

        //                         ctx.fillStyle = "#707070";
        //                         ctx.fill();
        //                     }
        //                 }
        //             }

        //             Text {
        //                 text: "Images"

        //                 color: "#666666"
        //                 font.pixelSize: 10

        //                 anchors.verticalCenter: parent.verticalCenter
        //             }
        //         }
        //     }

        //     Item {
        //         width: 62
        //         height: 22

        //         Row {
        //             anchors.centerIn: parent
        //             spacing: 5

        //             // Video symbol
        //             Rectangle {
        //                 width: 16
        //                 height: 14

        //                 radius: 3

        //                 color: "#303030"
        //                 border.width: 1
        //                 border.color: "#454545"

        //                 Canvas {
        //                     anchors.centerIn: parent

        //                     width: 7
        //                     height: 8

        //                     onPaint: {
        //                         var ctx = getContext("2d");

        //                         ctx.clearRect(0, 0, width, height);

        //                         ctx.beginPath();
        //                         ctx.moveTo(1, 1);
        //                         ctx.lineTo(7, 4);
        //                         ctx.lineTo(1, 7);
        //                         ctx.closePath();

        //                         ctx.fillStyle = "#707070";
        //                         ctx.fill();
        //                     }
        //                 }
        //             }

        //             Text {
        //                 text: "Videos"

        //                 color: "#666666"
        //                 font.pixelSize: 10

        //                 anchors.verticalCenter: parent.verticalCenter
        //             }
        //         }
        //     }
        // }
    }
}
