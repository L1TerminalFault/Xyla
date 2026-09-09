import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var treeRows: []
    property int headerWidth: 200

    signal toggleRowExpansion(int rowIndex)

    Layout.fillHeight: true
    Layout.preferredWidth: root.headerWidth
    color: "#161616"

    // Right 1px divider
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#242424"
        z: 2
    }

    Column {
        anchors.fill: parent
        anchors.rightMargin: 1 // Keep clear of the 1px separator line

        Repeater {
            model: root.treeRows

            delegate: Rectangle {
                id: rowRect
                width: root.headerWidth - 1
                height: 24
                color: rowMouse.containsMouse ? "#202020" : (modelData.type === "clip" ? "#191919" : "transparent")

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: modelData.isExpandable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (modelData.isExpandable)
                            root.toggleRowExpansion(index);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    // 5px base padding + indent
                    anchors.leftMargin: 5 + (modelData.indent * 12)
                    anchors.rightMargin: 8
                    spacing: 6

                    // Tabler chevron icon with rotation
                    Item {
                        width: 14
                        height: 14
                        visible: modelData.isExpandable
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: "qrc:/assets/icons/chevron-down.svg"
                            sourceSize.width: 12
                            sourceSize.height: 12
                            opacity: rowMouse.containsMouse ? 0.9 : 0.6
                            rotation: modelData.expanded ? 0 : -90

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    // Dot indicator for channel leaves
                    Rectangle {
                        visible: modelData.type === "channel"
                        width: 6
                        height: 6
                        radius: 3
                        color: modelData.color || "#3b82f6"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Label with right-side safety margin
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: modelData.type === "clip" ? "#ffffff" : (modelData.type === "group" ? "#bbbbbb" : "#999999")
                        font.pixelSize: modelData.type === "clip" ? 11 : 10
                        font.bold: modelData.type === "clip" || modelData.type === "group"
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Key count badge
                    Text {
                        visible: modelData.keyCount > 0
                        text: "" + modelData.keyCount
                        color: "#555555"
                        font.pixelSize: 9
                        font.family: "Monospace"
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
