import QtQuick 2.15
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TabBarBase {
    id: root

    implicitHeight: 36
    currentTabIndex: 0

    function getTabAtIndex(index) {
        return tabBarRow.children[index];
    }

    function getTabIndexAtPosition(globalPoint) {
        for (var i = 0; i < tabBarRow.children.length; ++i) {
            var tab = tabBarRow.children[i];
            var localPt = tab.mapFromGlobal(globalPoint.x, globalPoint.y);
            if (tab.contains(localPt)) {
                return i;
            }
        }
        return -1;
    }

    Rectangle {
        id: tabBarBackground
        anchors.fill: parent
        color: "#191919"

        // Bottom border
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#2d2d2d"
        }

        Row {
            id: tabBarRow
            z: root.mouseAreaZ.z + 1
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 4

            property int hoveredIndex: -1

            Repeater {
                model: root.groupCpp ? root.groupCpp.tabBar.dockWidgetModel : 0

                Rectangle {
                    id: tab
                    height: parent.height
                    implicitWidth: Math.max(110, tabText.implicitWidth + 38)

                    readonly property bool isCurrent: index == root.groupCpp.currentIndex
                    readonly property int tabIndex: index

                    // #252526 active, #181818 hovered, #0d0d0d inactive
                    color: isCurrent ? "#252526" : (tabBarRow.hoveredIndex == index ? "#181818" : "#0d0d0d")
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 5 // 5px tab radius

                    // Smooth tab color transition (warning-free)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        id: tabText
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: tabCloseBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: title
                        color: isCurrent ? "#ffffff" : "#888888"
                        font.pixelSize: 12
                        font.weight: isCurrent ? Font.Medium : Font.Normal
                        elide: Text.ElideRight

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // Per-Tab Close Button
                    Rectangle {
                        id: tabCloseBtn
                        width: 18
                        height: 18
                        radius: 3
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: tabCloseArea.containsMouse ? "#e81123" : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: tabCloseArea.containsMouse ? "#ffffff" : "#666666"
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: tabCloseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.tabBarCpp) {
                                    root.tabBarCpp.closeAtIndex(index);
                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: root.tabBarCpp

                function onHoveredTabIndexChanged(index) {
                    tabBarRow.hoveredIndex = index;
                }
            }
        }
    }
}
