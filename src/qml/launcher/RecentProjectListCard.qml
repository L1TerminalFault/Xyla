import QtQuick
import QtQuick.Layouts

Rectangle {
    id: cardRoot

    signal clicked

    property string projectName: ""
    property string projectPath: ""
    property string lastModifiedDate: ""

    Layout.fillWidth: true
    implicitHeight: 74

    color: mouseArea.containsMouse ? "#1F1F1F" : "#191919"
    radius: 12

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 180
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 12

        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: cardRoot.projectName
                color: "#e1e1e1"
                font.pixelSize: 18
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                Layout.alignment: Qt.AlignBottom
                text: cardRoot.projectPath
                color: "#6e6e6e"
                font.pixelSize: 10
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
    }

    Rectangle {
        id: dateBadge
        anchors.right: cardRoot.right
        anchors.rightMargin: 16
        anchors.bottom: cardRoot.bottom
        anchors.bottomMargin: 10

        property bool hovered: mouseArea.containsMouse
        property bool showTime: false

        Timer {
            id: hoverTimer
            interval: 700
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

        height: mainCol.implicitHeight + 6

        radius: 10
        color: "#0e0e0e"
        clip: true

        width: Math.max(rowLayout.implicitWidth, timeWrapper.implicitWidth) + 14

        readonly property var dateParts: {
            var s = cardRoot.lastModifiedDate;
            var parts = s.split(",");
            if (parts.length >= 4) {
                return {
                    base: parts[0].trim() + ", " + parts[1].trim(),
                    extra: parts[2].trim(),
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
                    color: "#6e6e6e"
                    font.pixelSize: 11
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
                        color: "#6e6e6e"
                        font.pixelSize: 11
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
                    color: "#6e6e6e"
                    font.pixelSize: 11
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
}
